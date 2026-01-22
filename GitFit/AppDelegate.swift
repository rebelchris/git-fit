//
//  AppDelegate.swift
//  Git-Fit
//
//  Main application delegate that manages the floating panel and system integration.
//

import AppKit
import SwiftUI
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Properties
    private var panelController: FloatingPanelController?
    private var vibeDetector: VibeDetector?
    private var statusItem: NSStatusItem?
    private var snoozeTimer: Timer?
    private var snoozeEndTime: Date?

    // MARK: - App Lifecycle
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("""

        ╔══════════════════════════════════════════════════════════════╗
        ║                                                              ║
        ║    ██████╗ ██╗████████╗    ███████╗██╗████████╗             ║
        ║   ██╔════╝ ██║╚══██╔══╝    ██╔════╝██║╚══██╔══╝             ║
        ║   ██║  ███╗██║   ██║ █████╗█████╗  ██║   ██║                ║
        ║   ██║   ██║██║   ██║ ╚════╝██╔══╝  ██║   ██║                ║
        ║   ╚██████╔╝██║   ██║       ██║     ██║   ██║                ║
        ║    ╚═════╝ ╚═╝   ╚═╝       ╚═╝     ╚═╝   ╚═╝                ║
        ║                                                              ║
        ║   🏋️ Developer Fitness for the Vibe Coding Era              ║
        ╚══════════════════════════════════════════════════════════════╝

        """)
        
        NSApp.setActivationPolicy(.accessory)

        // Check accessibility permissions first
        if !checkAccessibilityPermissions() {
            showAccessibilityAlert()
            return
        }

        print("🔧 [Git-Fit] Setting up VibeDetector...")
        setupVibeDetector()
        
        print("🔧 [Git-Fit] Setting up FloatingPanel...")
        setupFloatingPanel()
        
        print("🔧 [Git-Fit] Setting up MenuBar...")
        setupMenuBar()
        
        print("🔧 [Git-Fit] Setting up Notifications...")
        setupNotifications()

        // Start monitoring
        print("🔧 [Git-Fit] Starting monitoring...")
        vibeDetector?.startMonitoring()

        print("✅ [Git-Fit] App initialized successfully")
        if let apps = vibeDetector?.targetApps {
            print("🎯 [Git-Fit] Monitoring: \(apps.joined(separator: ", "))")
        }
            }
    

    func applicationWillTerminate(_ notification: Notification) {
        vibeDetector?.stopMonitoring()
        snoozeTimer?.invalidate()
        print("👋 [Git-Fit] App terminated")
    }

    // MARK: - Permissions
    private func checkAccessibilityPermissions() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
            let options = [key: true] as CFDictionary
            let accessEnabled = AXIsProcessTrustedWithOptions(options)

            if !accessEnabled {
                // 1. Show the Floating Panel with a "Setup" message
                panelController?.showManual()
                
                // 2. You could update your TrainerVibeView to show a
                // "Permissions Required" state with a button that calls openAccessibilitySettings()
                print("📥 App is waiting for user to toggle Accessibility switch")
            }
        
        return accessEnabled
    }
    
    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "Git-Fit Needs Accessibility Permissions"
        alert.informativeText = """
        Git-Fit monitors your keyboard activity to detect when you're waiting for AI tools.
        
        Please grant accessibility permissions in System Settings:
        1. Open System Settings
        2. Go to Privacy & Security → Accessibility
        3. Add Git-Fit and enable it
        4. Restart Git-Fit
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Quit")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Open System Settings
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
        
        // Quit the app - user needs to restart after granting permissions
        NSApp.terminate(nil)
    }

    // MARK: - Setup Methods
    private func setupVibeDetector() {
        let detector = VibeDetector()
        vibeDetector = detector

        // Configure callbacks - only show panel when WAITING (idle in AI app)
        detector.onWaitingStarted = { [weak self] appName in
            DispatchQueue.main.async { // <--- ADD THIS
                    self?.handleWaitingStarted(appName)
                }
        }

        detector.onWaitingStopped = { [weak self] in
            DispatchQueue.main.async {
                self?.handleWaitingStopped()
            }
        }

        detector.onAppExited = { [weak self] in
            DispatchQueue.main.async {
                self?.handleAppExited()
            }
        }

        detector.onWorkoutTriggered = { [weak self] in
            DispatchQueue.main.async {
                self?.triggerWorkout()
            }
        }
    }

    private func setupFloatingPanel() {
        guard let vibeDetector = vibeDetector else { 
            print("⚠️ [Git-Fit] Cannot setup panel - vibeDetector is nil")
            return 
        }
        
        panelController = FloatingPanelController()

        let trainerView = TrainerVibeView(
            detector: vibeDetector,
            onDismissSession: { [weak self] in
                self?.panelController?.dismissForSession(animated: true)
            },
            onEnterWorkout: { [weak self] in
                self?.panelController?.enterWorkoutMode()
            },
            onExitWorkout: { [weak self] in
                self?.panelController?.exitWorkoutMode()
            }
        )
        panelController?.createPanel(
            with: trainerView,
            size: NSSize(width: GitFitLayout.panelWidth, height: GitFitLayout.panelHeight)
        )
        
        print("✅ [Git-Fit] Floating panel created successfully")
    }

    private func setupMenuBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = item // Assign to optional
        
        guard let button = item.button else {
            print("❌ FATAL: Menu Bar Button is nil. This usually means the App Sandbox is ON.")
            return
        }
        
        button.image = NSImage(systemSymbolName: "dumbbell.fill", accessibilityDescription: "Git-Fit")
        updateMenu()
    }

    private func updateMenu() {
        let menu = NSMenu()

        // Title
        let titleItem = NSMenuItem(title: "Git-Fit", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())

        // Show/Hide
        menu.addItem(NSMenuItem(title: "Show Trainer", action: #selector(showPanel), keyEquivalent: "t"))
        menu.addItem(NSMenuItem(title: "Hide Trainer", action: #selector(hidePanel), keyEquivalent: "h"))
        menu.addItem(NSMenuItem.separator())

        // Status
        let statusMenuItem = NSMenuItem(title: "Status: Idle", action: nil, keyEquivalent: "")
        statusMenuItem.tag = 100
        menu.addItem(statusMenuItem)
        menu.addItem(NSMenuItem.separator())

        // Snooze submenu
        let snoozeMenu = NSMenu()
        snoozeMenu.addItem(NSMenuItem(title: "15 minutes", action: #selector(snooze15), keyEquivalent: ""))
        snoozeMenu.addItem(NSMenuItem(title: "30 minutes", action: #selector(snooze30), keyEquivalent: ""))
        snoozeMenu.addItem(NSMenuItem(title: "1 hour", action: #selector(snooze60), keyEquivalent: ""))
        snoozeMenu.addItem(NSMenuItem(title: "2 hours", action: #selector(snooze120), keyEquivalent: ""))
        snoozeMenu.addItem(NSMenuItem.separator())
        snoozeMenu.addItem(NSMenuItem(title: "Until tomorrow", action: #selector(snoozeUntilTomorrow), keyEquivalent: ""))

        let snoozeItem = NSMenuItem(title: "Snooze", action: nil, keyEquivalent: "")
        snoozeItem.submenu = snoozeMenu
        menu.addItem(snoozeItem)

        // Resume if snoozed
        if snoozeEndTime != nil {
            let resumeItem = NSMenuItem(title: "Resume Now", action: #selector(resumeFromSnooze), keyEquivalent: "")
            menu.addItem(resumeItem)

            // Show snooze status
            if let endTime = snoozeEndTime {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                let snoozeStatusItem = NSMenuItem(title: "Snoozed until \(formatter.string(from: endTime))", action: nil, keyEquivalent: "")
                snoozeStatusItem.isEnabled = false
                menu.addItem(snoozeStatusItem)
            }
        }

        menu.addItem(NSMenuItem.separator())

        // Workout trigger duration (auto-respond after X seconds)
        let durationMenu = NSMenu()
        for duration in [15, 30, 45, 60, 90, 120] {
            let item = NSMenuItem(title: "\(duration) seconds", action: #selector(setWorkoutDuration(_:)), keyEquivalent: "")
            item.tag = duration
            if let currentDuration = vibeDetector?.workoutTriggerDuration, Int(currentDuration) == duration {
                item.state = .on
            }
            durationMenu.addItem(item)
        }

        let currentDuration = Int(vibeDetector?.workoutTriggerDuration ?? 30)
        let durationItem = NSMenuItem(title: "Auto-Respond After (\(currentDuration)s)", action: nil, keyEquivalent: "")
        durationItem.submenu = durationMenu
        menu.addItem(durationItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Git-Fit", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    // MARK: - Event Handlers
    private func handleWaitingStarted(_ appName: String) {
        // Don't show if snoozed
        guard snoozeEndTime == nil else {
            print("😴 [Git-Fit] Snoozed - not showing panel")
            return
        }

        updateStatusMenu(text: "Waiting: \(appName)...")

        // Show panel when user is WAITING (idle) in an AI tool
        DispatchQueue.main.async { [weak self] in
            self?.panelController?.showAutomatic(animated: true)
        }
    }

    private func handleWaitingStopped() {
        if let app = vibeDetector?.currentApp, vibeDetector?.isInAITool == true {
            updateStatusMenu(text: "In: \(app)")
        } else {
            updateStatusMenu(text: "Status: Idle")
        }

        // Hide panel when user resumes typing (unless manually opened or in workout)
        DispatchQueue.main.async { [weak self] in
            self?.panelController?.hideAutomatic(animated: true)
        }
    }

    private func handleAppExited() {
        updateStatusMenu(text: "Status: Idle")

        // Auto-hide panel when exiting AI app (unless manually opened or in workout)
        DispatchQueue.main.async { [weak self] in
            self?.panelController?.hideAutomatic(animated: true)
        }
    }

    private func triggerWorkout() {
        // Don't trigger if snoozed
        guard snoozeEndTime == nil else { return }

        print("""

        🏋️ ═══════════════════════════════════════════════════════════════
        ║                    TIME FOR A MICRO-WORKOUT!                   ║
        ║                                                                ║
        ║   You've been waiting in an AI tool for a while.               ║
        ║   Let's do a quick stretch!                                    ║
        ╚═══════════════════════════════════════════════════════════════

        """)

        // Show workout notification
        showWorkoutNotification()

        // Enter workout mode and show panel
        DispatchQueue.main.async { [weak self] in
            self?.panelController?.enterWorkoutMode()
            self?.panelController?.showAutomatic(animated: true)
        }
    }

    // MARK: - Snooze
    private func snooze(minutes: Int) {
        snoozeTimer?.invalidate()

        let endTime = Date().addingTimeInterval(TimeInterval(minutes * 60))
        snoozeEndTime = endTime

        snoozeTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(minutes * 60), repeats: false) { [weak self] _ in
            self?.resumeFromSnooze()
        }

        // Hide panel when snoozing
        panelController?.hideManual(animated: true)

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        print("😴 [Git-Fit] Snoozed until \(formatter.string(from: endTime))")

        updateMenu()
        updateStatusMenu(text: "Snoozed until \(formatter.string(from: endTime))")
    }

    @objc private func snooze15() { snooze(minutes: 15) }
    @objc private func snooze30() { snooze(minutes: 30) }
    @objc private func snooze60() { snooze(minutes: 60) }
    @objc private func snooze120() { snooze(minutes: 120) }

    @objc private func snoozeUntilTomorrow() {
        let calendar = Calendar.current
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()),
           let startOfTomorrow = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) {
            let minutes = Int(startOfTomorrow.timeIntervalSince(Date()) / 60)
            snooze(minutes: minutes)
        }
    }

    @objc private func resumeFromSnooze() {
        snoozeTimer?.invalidate()
        snoozeTimer = nil
        snoozeEndTime = nil

        print("☀️ [Git-Fit] Resumed from snooze")
        updateMenu()
        updateStatusMenu(text: "Status: Active")
    }

    @objc private func setWorkoutDuration(_ sender: NSMenuItem) {
        vibeDetector?.workoutTriggerDuration = TimeInterval(sender.tag)
        print("⏱ [Git-Fit] Workout trigger set to \(sender.tag) seconds")
        updateMenu()
    }

    // MARK: - Notifications
    private func setupNotifications() {
        guard Bundle.main.bundleIdentifier != nil else {
            print("⚠️ [Git-Fit] Running without bundle - notifications disabled")
            return
        }

        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("🔔 [Git-Fit] Notification permission granted")
            } else if let error = error {
                print("⚠️ [Git-Fit] Notification permission error: \(error)")
            }
        }
    }

    private func showWorkoutNotification() {
        guard Bundle.main.bundleIdentifier != nil else {
            print("🔔 [Git-Fit] Workout notification (notifications disabled in CLI mode)")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Git-Fit"
        content.subtitle = "Time for a micro-workout!"
        content.body = "You've been waiting on AI for a while. Let's stretch!"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("⚠️ [Git-Fit] Failed to show notification: \(error)")
            }
        }
    }

    private func updateStatusMenu(text: String) {
        // Ensure the entire block is on the main thread
        DispatchQueue.main.async { [weak self] in
            guard let item = self?.statusItem,
                  let menu = item.menu,
                  let statusMenuItem = menu.item(withTag: 100) else { return }
            
            statusMenuItem.title = text
        }
    }

    // MARK: - Actions
    @objc private func showPanel() {
        panelController?.showManual(animated: true)
    }

    @objc private func hidePanel() {
        panelController?.hideManual(animated: true)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

// MARK: - User Notification Center Delegate
extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
