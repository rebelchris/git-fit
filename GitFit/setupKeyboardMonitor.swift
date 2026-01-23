//
//  VibeDetector.swift
//  Git-Fit
//
//  Monitors active applications and detects when the user is WAITING
//  for AI generation (idle in an AI tool).
//

import AppKit
import Combine

// MARK: - Detected App (AI-native apps that always trigger)
enum DetectedApp: String, CaseIterable {
    case claude = "Claude"
    case chatGPT = "ChatGPT"

    var emoji: String {
        switch self {
        case .claude: return "🤖"
        case .chatGPT: return "💬"
        }
    }

    static var allAppNames: Set<String> {
        Set(allCases.map { $0.rawValue })
    }
}

// MARK: - IDE Apps (require Claude CLI check)
enum IDEApp: String, CaseIterable {
    case vscode = "Code"
    case vscodeAlt = "Visual Studio Code"
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
    case zed = "Zed"
    case nova = "Nova"
    case antigravity = "Antigravity"

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
    var claudeCPUThreshold: Double = 5.0   // CPU % to consider Claude "active"
    var claudeCPUSustainedSeconds: TimeInterval = 2.0 // How long CPU must stay high

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

    // CPU-based activity detection
    private var highCPUStartTime: Date?

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
        print("📊 [VibeDetector] CPU detection: >\(claudeCPUThreshold)% for \(claudeCPUSustainedSeconds)s")
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

    // MARK: - Claude CLI Detection (via XPC Service)
    private var lastCPUValue: Double = 0.0

    private func checkClaudeCLIRunning() -> Bool {
        // Check every 1 second to stay responsive
        guard Date().timeIntervalSince(lastClaudeCheck) > 1.0 else {
            return isClaudeCLIRunning
        }

        lastClaudeCheck = Date()

        // Request CPU from XPC service (async, updates lastCPUValue)
        ProcessMonitorClient.shared.getClaudeCPUUsage { [weak self] cpuUsage in
            DispatchQueue.main.async {
                self?.handleCPUUpdate(cpuUsage)
            }
        }

        return isClaudeCLIRunning
    }

    private func handleCPUUpdate(_ cpuUsage: Double) {
        lastCPUValue = cpuUsage
        let wasRunning = isClaudeCLIRunning
        let isHighCPU = cpuUsage >= claudeCPUThreshold

        // Get current app for logging
        let appName = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"
        let isSupportedApp = matchesAppSet(appName, targetApps) ||
                             matchesAppSet(appName, ideApps) ||
                             matchesAppSet(appName, terminalApps)

        // Always log current state for debugging
        let sustainedTime = highCPUStartTime != nil ? Date().timeIntervalSince(highCPUStartTime!) : 0.0
        print("🔍 [CPU] \(String(format: "%5.1f", cpuUsage))% | threshold: \(claudeCPUThreshold)% | sustained: \(String(format: "%.1f", sustainedTime))s/\(claudeCPUSustainedSeconds)s | app: \(appName) | supported: \(isSupportedApp) | active: \(isClaudeCLIRunning)")

        // Track sustained high CPU
        if isHighCPU {
            if highCPUStartTime == nil {
                highCPUStartTime = Date()
                print("📈 [VibeDetector] Claude CPU spike started")
            }

            let newSustainedTime = Date().timeIntervalSince(highCPUStartTime!)
            if newSustainedTime >= claudeCPUSustainedSeconds {
                // Claude is actively working (sustained high CPU)
                isClaudeCLIRunning = true
            }
        } else {
            // CPU dropped below threshold
            if highCPUStartTime != nil {
                print("📉 [VibeDetector] Claude CPU dropped below threshold")
            }
            highCPUStartTime = nil
            isClaudeCLIRunning = false
        }

        // Log state changes
        if isClaudeCLIRunning != wasRunning {
            if isClaudeCLIRunning {
                print("🔍 [VibeDetector] Claude ACTIVELY WORKING (CPU: \(String(format: "%.1f", cpuUsage))%)")
            } else {
                print("🔍 [VibeDetector] Claude IDLE or stopped")
            }

            // Trigger app check to update state immediately
            checkFrontmostApp()
        }
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

    // MARK: - App Matching Helper
    private func matchesAppSet(_ appName: String, _ appSet: Set<String>) -> Bool {
        let lowercasedAppName = appName.lowercased()
        return appSet.contains { $0.lowercased() == lowercasedAppName }
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

        // All app types require Claude CLI to be actively working (CPU > threshold)
        let isClaudeActive = checkClaudeCLIRunning()

        // Check if this is any supported app (AI app, IDE, or terminal)
        let isSupportedApp = matchesAppSet(appName, targetApps) ||
                             matchesAppSet(appName, ideApps) ||
                             matchesAppSet(appName, terminalApps)

        isInAITool = isSupportedApp && isClaudeActive

        // App changed or Claude state changed
        if appName != previousApp || isInAITool != wasInAITool {
            if isInAITool && !wasInAITool {
                // Entered AI tool (Claude actively working)
                currentState = .inAIApp(app: appName)
                lastKeyboardActivity = Date()
                lastTypingEnd = Date()  // Reset grace period on app switch
                printAppSwitch(appName: appName, entering: true, reason: "(Claude active)")

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
