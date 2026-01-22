//
//  FloatingPanel.swift
//  Git-Fit
//
//  A custom NSPanel that floats above all windows without stealing focus.
//

import AppKit
import SwiftUI
import Combine

// MARK: - Floating Panel
/// A borderless, transparent panel that floats above all windows
/// and does not steal keyboard focus from other applications.
final class FloatingPanel: NSPanel {

    init(contentRect: NSRect, styleMask: NSWindow.StyleMask = [.borderless, .nonactivatingPanel]) {
        super.init(
            contentRect: contentRect,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )

        configurePanel()
    }

    private func configurePanel() {
        // Transparency & appearance
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true

        // Floating behavior - stays above all windows including IDEs
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        // Non-activating: doesn't steal focus from other apps
        isMovableByWindowBackground = true
        hidesOnDeactivate = false

        // Ignore mouse events for passthrough when needed
        ignoresMouseEvents = false

        // Animation
        animationBehavior = .utilityWindow
    }

    // MARK: - Key Window Behavior
    // Prevent the panel from becoming key window (stealing focus)
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    // MARK: - Positioning
    func positionInBottomRight(padding: CGFloat = 20) {
        guard let screen = NSScreen.main else { return }

        let screenFrame = screen.visibleFrame
        let panelSize = frame.size

        let newOrigin = NSPoint(
            x: screenFrame.maxX - panelSize.width - padding,
            y: screenFrame.minY + padding
        )

        setFrameOrigin(newOrigin)
    }

    func positionInCenter() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let panelSize = frame.size

        let newOrigin = NSPoint(
            x: screenFrame.midX - panelSize.width / 2,
            y: screenFrame.midY - panelSize.height / 2
        )

        setFrameOrigin(newOrigin)
    }
}

// MARK: - Panel Controller
/// Manages the lifecycle and content of the floating panel.
/// 
/// **Show/Hide Behavior:**
/// - `showAutomatic`: Shows panel when waiting is detected (unless snoozed in AppDelegate)
/// - `hideAutomatic`: Hides panel when user resumes typing or exits AI app
/// - `showManual`: User explicitly shows via menu - panel stays visible until manually hidden
/// - `hideManual`: User explicitly hides via menu - panel can still auto-show on next event
/// - `dismissForSession`: User clicks X button - hides current notification but allows next auto-show
/// 
/// **Snooze Mode:** Handled in AppDelegate - prevents all automatic shows until resumed
final class FloatingPanelController: ObservableObject {
    private var panel: FloatingPanel?
    @Published var isVisible: Bool = false
    @Published var wasManuallyOpened: Bool = false  // Track if user opened via menu
    @Published var isDismissedForSession: Bool = false  // Track if user dismissed for session
    @Published var isInWorkoutMode: Bool = false  // Track if actively doing a workout

    func createPanel<Content: View>(with content: Content, size: NSSize = NSSize(width: 320, height: 400)) {
        let contentRect = NSRect(origin: .zero, size: size)
        panel = FloatingPanel(contentRect: contentRect)

        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = contentRect
        panel?.contentView = hostingView

        panel?.positionInBottomRight()
    }

    /// Show panel automatically (triggered by waiting detection)
    func showAutomatic(animated: Bool = true) {
        // Clear the dismissal flag when a new waiting state is detected
        // This allows the panel to show for new events, even if user dismissed previous ones
        isDismissedForSession = false
        
        guard !wasManuallyOpened else { return } // Don't override manual state
        
        showInternal(animated: animated, manual: false)
    }

    /// Show panel manually (triggered by menu bar)
    func showManual(animated: Bool = true) {
        wasManuallyOpened = true
        isDismissedForSession = false  // Clear session dismissal when manually showing
        showInternal(animated: animated, manual: true)
    }

    /// Dismiss the current panel notification (will allow future auto-shows)
    func dismissForSession(animated: Bool = true) {
        isDismissedForSession = true  // Temporarily mark as dismissed
        wasManuallyOpened = false
        isInWorkoutMode = false
        hideInternal(animated: animated)
        print("🚫 [Git-Fit] Panel dismissed - will re-appear on next waiting event")
    }

    /// Enter workout mode - panel stays visible until workout is done
    func enterWorkoutMode() {
        isInWorkoutMode = true
        print("🏋️ [Git-Fit] Entered workout mode - panel locked")
    }

    /// Exit workout mode - panel can auto-hide again
    func exitWorkoutMode() {
        isInWorkoutMode = false
        print("✅ [Git-Fit] Exited workout mode")
    }

    private func showInternal(animated: Bool, manual: Bool) {
        guard let panel = panel else { return }
        guard !isVisible else { return }  // Prevent re-showing if already visible

        if animated {
            panel.alphaValue = 0
            panel.orderFront(nil)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
            }
        } else {
            panel.orderFront(nil)
            panel.alphaValue = 1
        }

        isVisible = true
        let mode = manual ? "manually" : "automatically"
        print("⚡️ [Git-Fit] Trainer panel activated (\(mode))")
    }

    /// Hide panel automatically (when exiting AI app)
    func hideAutomatic(animated: Bool = true) {
        // Don't auto-hide if manually opened, in workout mode, or already hidden
        guard !wasManuallyOpened else {
            print("📌 [Git-Fit] Panel pinned (manually opened) - not auto-hiding")
            return
        }
        guard !isInWorkoutMode else {
            print("🏋️ [Git-Fit] In workout mode - not auto-hiding")
            return
        }
        guard isVisible else { return }  // Don't hide if already hidden

        hideInternal(animated: animated)
    }

    /// Hide panel manually (via menu bar)
    func hideManual(animated: Bool = true) {
        wasManuallyOpened = false
        isInWorkoutMode = false
        hideInternal(animated: animated)
    }

    private func hideInternal(animated: Bool) {
        guard let panel = panel else { return }
        guard isVisible else { return }  // Prevent double-hide

        if animated {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                panel.animator().alphaValue = 0
            }, completionHandler: {
                panel.orderOut(nil)
            })
        } else {
            panel.orderOut(nil)
        }

        isVisible = false
        print("💤 [Git-Fit] Trainer panel deactivated")
    }

    func toggle() {
        if isVisible {
            hideManual()
        } else {
            showManual()
        }
    }

    func updatePosition() {
        panel?.positionInBottomRight()
    }
}
