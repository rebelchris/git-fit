//
//  VibeDetector.swift
//  Git-Fit
//
//  Monitors active applications and detects when the user is WAITING
//  for AI generation (idle in an AI tool).
//

import AppKit
import Combine

// MARK: - Detected App
enum DetectedApp: String, CaseIterable {
    case claude = "Claude"
    case chatGPT = "ChatGPT"
    case cursor = "Cursor"
    case webstorm = "WebStorm"
    case intellij = "IntelliJ IDEA"

    var emoji: String {
        switch self {
        case .claude: return "🤖"
        case .chatGPT: return "💬"
        case .cursor: return "⚡️"
        case .webstorm: return "🌪️"
        case .intellij: return "💡"
        }
    }

    static var allAppNames: Set<String> {
        Set(allCases.map { $0.rawValue })
    }
}

// MARK: - IDE Apps (require Claude CLI check)
enum IDEApp: String, CaseIterable {
    case vscode = "Code"
    case vscodium = "VSCodium"
    case cursor = "Cursor"  // Cursor is both AI app and IDE
    case intellij = "IntelliJ IDEA"
    case webstorm = "WebStorm"
    case phpstorm = "PhpStorm"
    case pycharm = "PyCharm"
    case rubymine = "RubyMine"
    case goland = "GoLand"
    case rider = "Rider"
    case clion = "CLion"
    case datagrip = "DataGrip"
    case androidStudio = "Android Studio"
    case fleet = "Fleet"

    static var allAppNames: Set<String> {
        Set(allCases.map { $0.rawValue })
    }
}

// MARK: - Terminal Apps (require Claude CLI check)
enum TerminalApp: String, CaseIterable {
    case terminal = "Terminal"
    case iterm = "iTerm2"
    case ghostty = "Ghostty"
    case warp = "Warp"
    case alacritty = "Alacritty"
    case kitty = "kitty"
    case hyper = "Hyper"
    case wezterm = "WezTerm"
    case rio = "Rio"
    case tabby = "Tabby"

    static var allAppNames: Set<String> {
        Set(allCases.map { $0.rawValue })
    }
}

// MARK: - Vibe State
enum VibeState: Equatable {
    case idle
    case inAIApp(app: String)
    case waitingForGeneration(app: String, idleTime: TimeInterval)
    case workout

    var description: String {
        switch self {
        case .idle:
            return "Scanning for vibe..."
        case .inAIApp(let app):
            return "In \(app) - type or wait..."
        case .waitingForGeneration(let app, let idleTime):
            return "Waiting in \(app)... \(Int(idleTime))s"
        case .workout:
            return "Time to move!"
        }
    }

    var isWaiting: Bool {
        if case .waitingForGeneration = self { return true }
        return false
    }
}

// MARK: - Vibe Detector
/// Monitors the frontmost application and detects when user is WAITING
/// for AI generation (idle keyboard + in AI app).
final class VibeDetector: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var currentState: VibeState = .idle
    @Published private(set) var currentApp: String?
    @Published private(set) var isInAITool: Bool = false
    @Published private(set) var isWaitingForGeneration: Bool = false
    @Published private(set) var waitingDuration: TimeInterval = 0

    // MARK: - Configuration
    var targetApps: Set<String> = DetectedApp.allAppNames
    var ideApps: Set<String> = IDEApp.allAppNames
    var terminalApps: Set<String> = TerminalApp.allAppNames
    var idleThreshold: TimeInterval = 3.0  // Seconds of idle before "waiting" state
    var gracePeriod: TimeInterval = 1.5    // Seconds after typing before detection can start
    var workoutTriggerDuration: TimeInterval = 30 // Seconds of waiting to trigger workout

    // MARK: - Private Properties
    private var pollingTimer: Timer?
    private var idleCheckTimer: Timer?
    private var lastKeyboardActivity: Date = Date()
    private var lastTypingEnd: Date = Date()  // Track when user stopped typing
    private var waitingStartTime: Date?
    private var eventMonitor: Any?
    private var cancellables = Set<AnyCancellable>()
    private var isClaudeCLIRunning: Bool = false
    private var lastClaudeCheck: Date = Date.distantPast

    // MARK: - Callbacks
    var onWaitingStarted: ((String) -> Void)?
    var onWaitingStopped: (() -> Void)?
    var onWorkoutTriggered: (() -> Void)?
    var onAppExited: (() -> Void)?

    // MARK: - Lifecycle
    init() {
        setupKeyboardMonitor()
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Public Methods
    func startMonitoring(interval: TimeInterval = 0.5) {
        stopMonitoring()

        // Poll for frontmost app
        pollingTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.checkFrontmostApp()
        }

        // Check idle state more frequently
        idleCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkIdleState()
        }

        checkFrontmostApp()

        print("🔍 [VibeDetector] Started monitoring for AI generation waiting")
        print("📱 [VibeDetector] AI apps: \(targetApps.joined(separator: ", "))")
        print("💻 [VibeDetector] IDE apps (with Claude CLI): \(ideApps.joined(separator: ", "))")
        print("🖥️ [VibeDetector] Terminal apps (with Claude CLI): \(terminalApps.joined(separator: ", "))")
        print("⏱ [VibeDetector] Idle threshold: \(idleThreshold)s, Grace period: \(gracePeriod)s")
    }

    func stopMonitoring() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        idleCheckTimer?.invalidate()
        idleCheckTimer = nil

        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }

        print("⏹ [VibeDetector] Stopped monitoring")
    }

    func resetWaiting() {
        waitingStartTime = nil
        waitingDuration = 0
        isWaitingForGeneration = false
        lastTypingEnd = Date()  // Reset grace period

        if isInAITool, let app = currentApp {
            currentState = .inAIApp(app: app)
        } else {
            currentState = .idle
        }
    }

    // MARK: - Claude CLI Detection
    private func checkClaudeCLIRunning() -> Bool {
        // Check every 1 second to stay responsive
        guard Date().timeIntervalSince(lastClaudeCheck) > 1.0 else {
            return isClaudeCLIRunning
        }

        lastClaudeCheck = Date()
        let wasRunning = isClaudeCLIRunning

        // Method 1: Check for exact process name "claude" using pgrep -x
        let task = Process()
        task.launchPath = "/usr/bin/pgrep"
        task.arguments = ["-x", "claude"]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice

        var found = false
        do {
            try task.run()
            task.waitUntilExit()
            found = task.terminationStatus == 0
        } catch {
            found = false
        }

        // Method 2: If not found, also check for node running claude
        if !found {
            let task2 = Process()
            task2.launchPath = "/bin/bash"
            task2.arguments = ["-c", "pgrep -f 'node.*@anthropic.*claude' 2>/dev/null"]
            task2.standardOutput = FileHandle.nullDevice
            task2.standardError = FileHandle.nullDevice

            do {
                try task2.run()
                task2.waitUntilExit()
                found = task2.terminationStatus == 0
            } catch {
                // ignore
            }
        }

        isClaudeCLIRunning = found

        // Log state changes
        if isClaudeCLIRunning != wasRunning {
            if isClaudeCLIRunning {
                print("🔍 [VibeDetector] Claude CLI process STARTED")
            } else {
                print("🔍 [VibeDetector] Claude CLI process STOPPED")
            }
        }

        return isClaudeCLIRunning
    }

    // MARK: - Keyboard Monitoring
    private func setupKeyboardMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            // Bounce to main thread immediately
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.lastKeyboardActivity = Date()
                self.lastTypingEnd = Date()
                self.handleUserActivity()
            }
        }
        
        if eventMonitor == nil {
                print("⚠️ [VibeDetector] Global monitor returned nil. Accessibility permissions likely missing.")
            }

        NSEvent.addGlobalMonitorForEvents(matching: [.scrollWheel]) { [weak self] _ in
            DispatchQueue.main.async {
                self?.lastKeyboardActivity = Date()
            }
        }
    }

    private func handleUserActivity() {
        // Reset if waiting for generation
        if isWaitingForGeneration {
            print("⌨️ [VibeDetector] User typing detected - stopping wait timer")
            isWaitingForGeneration = false
            waitingStartTime = nil
            waitingDuration = 0
            onWaitingStopped?()

            if let app = currentApp, isInAITool {
                currentState = .inAIApp(app: app)
            }
        }

        // Also reset if in workout prompt state (user typed instead of doing workout)
        if case .workout = currentState {
            print("⌨️ [VibeDetector] User typing detected - canceling workout prompt")
            if let app = currentApp, isInAITool {
                currentState = .inAIApp(app: app)
            } else {
                currentState = .idle
            }
            onWaitingStopped?()
        }
    }

    // MARK: - App Monitoring
    private func checkFrontmostApp() {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
              let appName = frontmostApp.localizedName else {
            return
        }

        let wasInAITool = isInAITool
        let previousApp = currentApp

        currentApp = appName

        // Check if this is a direct AI app
        let isDirectAIApp = targetApps.contains(appName)

        // Check if this is an IDE with Claude CLI running
        // Detection activates when Claude process is found (user ran "claude" command)
        let isIDEWithClaude = ideApps.contains(appName) && checkClaudeCLIRunning()

        // Check if this is a terminal with Claude CLI running
        let isTerminalWithClaude = terminalApps.contains(appName) && checkClaudeCLIRunning()

        isInAITool = isDirectAIApp || isIDEWithClaude || isTerminalWithClaude

        // App changed
        if appName != previousApp {
            if isInAITool && !wasInAITool {
                // Entered AI tool
                let reason = (isIDEWithClaude || isTerminalWithClaude) ? "(Claude CLI detected)" : ""
                currentState = .inAIApp(app: appName)
                lastKeyboardActivity = Date()
                lastTypingEnd = Date()  // Reset grace period on app switch
                printAppSwitch(appName: appName, entering: true, reason: reason)

            } else if !isInAITool && wasInAITool {
                // Exited AI tool
                stopWaitingState()
                currentState = .idle
                onAppExited?()
                printAppSwitch(appName: appName, entering: false, reason: "")

            } else if isInAITool {
                // Switched between AI tools
                resetWaiting()
                currentState = .inAIApp(app: appName)
                lastKeyboardActivity = Date()
                lastTypingEnd = Date()
            }
        }
    }

    private func checkIdleState() {
        guard isInAITool, let app = currentApp else { return }

        let now = Date()
        let idleTime = now.timeIntervalSince(lastKeyboardActivity)
        let timeSinceTyping = now.timeIntervalSince(lastTypingEnd)

        // Grace period: don't start waiting immediately after typing stops
        // This prevents false triggers when user just finished typing and AI is starting
        guard timeSinceTyping >= gracePeriod else { return }

        if idleTime >= idleThreshold {
            // User is idle in AI app = likely waiting for generation
            if !isWaitingForGeneration {
                startWaitingState(for: app)
            } else {
                updateWaitingDuration()
            }
        }
    }

    private func startWaitingState(for app: String) {
        isWaitingForGeneration = true
        waitingStartTime = Date()
        waitingDuration = 0

        currentState = .waitingForGeneration(app: app, idleTime: 0)

        print("""
        ⏳ ═══════════════════════════════════════
        │ WAITING STATE DETECTED
        │ App: \(app)
        │ User idle for \(idleThreshold)s (grace: \(gracePeriod)s)
        │ Starting generation wait timer...
        ═══════════════════════════════════════
        """)

        onWaitingStarted?(app)
    }

    private func updateWaitingDuration() {
        guard let start = waitingStartTime, let app = currentApp else { return }

        let newDuration = Date().timeIntervalSince(start)
        
        // Jump to main thread BEFORE updating @Published properties
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.waitingDuration = newDuration
            self.currentState = .waitingForGeneration(app: app, idleTime: newDuration)

            // Check workout trigger
            if self.waitingDuration >= self.workoutTriggerDuration {
                self.triggerWorkout()
            }
        }
    }

    private func stopWaitingState() {
        if isWaitingForGeneration {
            print("💤 [VibeDetector] Waiting state ended after \(Int(waitingDuration))s")
            onWaitingStopped?()
        }

        isWaitingForGeneration = false
        waitingStartTime = nil
        waitingDuration = 0
    }

    private func triggerWorkout() {
        currentState = .workout
        print("""

        🏋️ ═══════════════════════════════════════
        ║     WORKOUT TRIGGERED!
        ║     Waited \(Int(waitingDuration)) seconds
        ╚═══════════════════════════════════════

        """)

        // Stop the waiting timer but keep state as .workout
        // The UI will handle returning to monitoring
        isWaitingForGeneration = false
        waitingStartTime = nil
        waitingDuration = 0

        onWorkoutTriggered?()
    }

    private func printAppSwitch(appName: String, entering: Bool, reason: String) {
        let emoji = DetectedApp(rawValue: appName)?.emoji ?? "📱"
        let action = entering ? "ENTERED" : "EXITED"
        let reasonStr = reason.isEmpty ? "" : " \(reason)"

        print("""
        ┌─────────────────────────────────────────
        │ \(emoji) \(action): \(appName)\(reasonStr)
        │ Time: \(formattedTime())
        └─────────────────────────────────────────
        """)
    }

    private func formattedTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }
}

// MARK: - Preview Helper
extension VibeDetector {
    static var preview: VibeDetector {
        let detector = VibeDetector()
        detector.currentApp = "Claude"
        detector.isInAITool = true
        detector.isWaitingForGeneration = true
        detector.waitingDuration = 45
        return detector
    }
}
