//
//  TrainerVibeView.swift
//  Git-Fit
//
//  The main trainer view with cyberpunk aesthetics and pulsing avatar.
//

import SwiftUI

// MARK: - Constants
enum GitFitLayout {
    static let panelWidth: CGFloat = 300
    static let panelHeight: CGFloat = 400
}

// MARK: - Design System
enum VibeColors {
    static let neonCyan = Color(red: 0, green: 1, blue: 1)
    static let neonMagenta = Color(red: 1, green: 0, blue: 0.8)
    static let neonPurple = Color(red: 0.6, green: 0.2, blue: 1)
    static let darkBackground = Color(red: 0.05, green: 0.05, blue: 0.1)
    static let cardBackground = Color(red: 0.1, green: 0.1, blue: 0.15)

    static var neonGradient: LinearGradient {
        LinearGradient(
            colors: [neonCyan, neonMagenta],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var pulseGradient: RadialGradient {
        RadialGradient(
            colors: [neonCyan.opacity(0.8), neonPurple.opacity(0.3), .clear],
            center: .center,
            startRadius: 0,
            endRadius: 100
        )
    }
}

// MARK: - View Mode
enum TrainerViewMode: Equatable {
    case monitoring
    case workoutPrompt  // Pulsing "START" prompt
    case workout
}

// MARK: - Trainer Vibe View
struct TrainerVibeView: View {
    @ObservedObject var detector: VibeDetector
    var onDismiss: (() -> Void)?
    var onDismissSession: (() -> Void)?
    var onEnterWorkout: (() -> Void)?
    var onExitWorkout: (() -> Void)?

    @State private var viewMode: TrainerViewMode = .monitoring
    @State private var isPulsing = false
    @State private var glowIntensity: CGFloat = 0.5
    @State private var rotationAngle: Double = 0
    @State private var promptPulse = false

    var body: some View {
        ZStack {
            // Background - always visible
            backgroundView
                .frame(width: GitFitLayout.panelWidth, height: GitFitLayout.panelHeight)

            // Content
            Group {
                switch viewMode {
                case .monitoring:
                    monitoringContent
                case .workoutPrompt:
                    workoutPromptContent
                case .workout:
                    WorkoutView(onClose: {
                        viewMode = .monitoring
                        onExitWorkout?()
                    }, onComplete: {
                        // Return home after workout completes
                        viewMode = .monitoring
                        onExitWorkout?()
                    })
                }
            }
        }
        .frame(width: GitFitLayout.panelWidth, height: GitFitLayout.panelHeight)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(borderOverlay)
        .onAppear {
            startAnimations()
        }
        .onChange(of: detector.currentState) { oldState, newState in
            // Auto-trigger workout prompt when timer completes
            if case .workout = newState {
                withAnimation {
                    viewMode = .workoutPrompt
                    onEnterWorkout?()
                }
            }

            // Reset to monitoring if user starts typing (exits waiting state)
            if case .inAIApp = newState, viewMode == .workoutPrompt {
                withAnimation {
                    viewMode = .monitoring
                    promptPulse = false
                    onExitWorkout?()
                }
            }

            // Also reset if user leaves AI app entirely
            if case .idle = newState, viewMode == .workoutPrompt {
                withAnimation {
                    viewMode = .monitoring
                    promptPulse = false
                    onExitWorkout?()
                }
            }
        }
    }

    // MARK: - Workout Prompt Content
    private var workoutPromptContent: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("GIT-FIT")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(VibeColors.neonGradient)
                Spacer()
                Button(action: { onDismissSession?() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                        .padding(6)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Message about waiting
            VStack(spacing: 12) {
                // Hourglass icon
                Image(systemName: "hourglass.tophalf.filled")
                    .font(.system(size: 36))
                    .foregroundStyle(VibeColors.neonGradient)
                    .scaleEffect(promptPulse ? 1.1 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                        value: promptPulse
                    )

                Text("You've been waiting a while...")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)

                Text("Perfect time for a quick stretch!")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(VibeColors.neonCyan.opacity(0.8))
            }

            Spacer()

            // Big pulsing START button
            Button(action: {
                viewMode = .workout
            }) {
                ZStack {
                    // Outer pulse rings
                    ForEach(0..<3) { index in
                        Circle()
                            .stroke(VibeColors.neonMagenta.opacity(0.3 - Double(index) * 0.1), lineWidth: 2)
                            .frame(width: 110 + CGFloat(index) * 15, height: 110 + CGFloat(index) * 15)
                            .scaleEffect(promptPulse ? 1.3 : 1.0)
                            .opacity(promptPulse ? 0 : 1)
                            .animation(
                                .easeOut(duration: 1.5)
                                .repeatForever(autoreverses: false)
                                .delay(Double(index) * 0.3),
                                value: promptPulse
                            )
                    }

                    // Main button
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [VibeColors.neonMagenta, VibeColors.neonPurple],
                                center: .center,
                                startRadius: 0,
                                endRadius: 50
                            )
                        )
                        .frame(width: 100, height: 100)
                        .shadow(color: VibeColors.neonMagenta.opacity(0.8), radius: 15)
                        .scaleEffect(promptPulse ? 1.05 : 1.0)
                        .animation(
                            .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                            value: promptPulse
                        )

                    VStack(spacing: 2) {
                        Image(systemName: "figure.run")
                            .font(.system(size: 24))
                        Text("LET'S GO")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                    }
                    .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
            .onAppear {
                promptPulse = true
            }

            Spacer()

            // Skip button
            Button(action: {
                viewMode = .monitoring
                detector.resetWaiting()
                onExitWorkout?()
            }) {
                Text("NOT NOW")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.05))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(20)
    }

    // MARK: - Monitoring Content
    private var monitoringContent: some View {
        VStack(spacing: 0) {
            // Header with dismiss
            headerView

            Spacer()

            // Avatar placeholder (for future 3D Spline scene)
            avatarView

            Spacer()

            // Status display
            statusView

            // Action buttons
            actionButtons
        }
        .padding(20)
    }

    // MARK: - Header
    private var headerView: some View {
        HStack {
            Text("GIT-FIT")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(VibeColors.neonGradient)

            Spacer()

            // Status indicator
            Circle()
                .fill(detector.isWaitingForGeneration ? VibeColors.neonCyan : (detector.isInAITool ? VibeColors.neonPurple : Color.gray))
                .frame(width: 8, height: 8)
                .shadow(color: detector.isWaitingForGeneration ? VibeColors.neonCyan : .clear, radius: 4)

            // Dismiss button (X)
            Button(action: { onDismissSession?() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gray)
                    .padding(6)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Dismiss for this session")
        }
        .padding(.bottom, 10)
    }

    // MARK: - Avatar View (Placeholder for 3D Spline)
    private var avatarView: some View {
        ZStack {
            // Outer glow rings
            ForEach(0..<3) { index in
                Circle()
                    .stroke(
                        VibeColors.neonCyan.opacity(0.3 - Double(index) * 0.1),
                        lineWidth: 2
                    )
                    .frame(width: 120 + CGFloat(index) * 25, height: 120 + CGFloat(index) * 25)
                    .scaleEffect(isPulsing ? 1.1 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.2),
                        value: isPulsing
                    )
            }

            // Main avatar circle
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            VibeColors.neonCyan.opacity(0.6),
                            VibeColors.neonPurple.opacity(0.4),
                            VibeColors.darkBackground
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 50
                    )
                )
                .frame(width: 100, height: 100)
                .overlay(avatarOverlay)
                .shadow(color: VibeColors.neonCyan.opacity(glowIntensity), radius: 20)
                .shadow(color: VibeColors.neonMagenta.opacity(glowIntensity * 0.5), radius: 40)
                .scaleEffect(isPulsing ? 1.05 : 1.0)
                .animation(
                    .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                    value: isPulsing
                )

            // Rotating ring
            Circle()
                .trim(from: 0, to: 0.3)
                .stroke(
                    VibeColors.neonGradient,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 110, height: 110)
                .rotationEffect(.degrees(rotationAngle))
        }
    }

    private var avatarOverlay: some View {
        ZStack {
            // Inner glow
            Circle()
                .stroke(VibeColors.neonCyan, lineWidth: 2)
                .blur(radius: 4)

            // Placeholder icon
            Image(systemName: "figure.run")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(VibeColors.neonGradient)

            // "3D" label placeholder
            VStack {
                Spacer()
                Text("SPLINE")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundColor(VibeColors.neonCyan.opacity(0.5))
                    .padding(.bottom, 6)
            }
        }
    }

    // MARK: - Status View
    private var statusView: some View {
        VStack(spacing: 6) {
            // Current app
            if let app = detector.currentApp {
                HStack(spacing: 6) {
                    Image(systemName: detector.isWaitingForGeneration ? "hourglass" : (detector.isInAITool ? "sparkles" : "app.fill"))
                        .foregroundColor(detector.isWaitingForGeneration ? VibeColors.neonCyan : (detector.isInAITool ? VibeColors.neonPurple : .gray))
                        .font(.system(size: 11))

                    Text(app)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                }
            }

            // State description
            Text(detector.currentState.description)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(VibeColors.neonCyan.opacity(0.8))

            // Waiting duration bar (only when waiting)
            if detector.isWaitingForGeneration {
                waitingDurationBar
            }
        }
        .padding(.vertical, 8)
    }

    private var waitingDurationBar: some View {
        VStack(spacing: 3) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.1))

                    // Progress
                    RoundedRectangle(cornerRadius: 3)
                        .fill(VibeColors.neonGradient)
                        .frame(width: geo.size.width * min(detector.waitingDuration / detector.workoutTriggerDuration, 1.0))
                        .animation(.linear(duration: 0.5), value: detector.waitingDuration)
                }
            }
            .frame(height: 5)

            Text("\(Int(detector.waitingDuration))s / \(Int(detector.workoutTriggerDuration))s until workout")
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 12) {
            ActionButton(
                title: "SKIP",
                icon: "forward.fill",
                color: .gray
            ) {
                detector.resetWaiting()
            }

            ActionButton(
                title: "WORKOUT",
                icon: "flame.fill",
                color: VibeColors.neonMagenta
            ) {
                onEnterWorkout?()
                viewMode = .workout
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Background
    private var backgroundView: some View {
        ZStack {
            VibeColors.darkBackground

            // Subtle grid pattern
            GridPattern()
                .opacity(0.1)

            // Gradient overlay
            LinearGradient(
                colors: [
                    VibeColors.neonPurple.opacity(0.1),
                    .clear,
                    VibeColors.neonCyan.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: 20)
            .stroke(
                LinearGradient(
                    colors: [
                        VibeColors.neonCyan.opacity(0.5),
                        VibeColors.neonPurple.opacity(0.3),
                        VibeColors.neonMagenta.opacity(0.5)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }

    // MARK: - Animations
    private func startAnimations() {
        isPulsing = true

        // Rotating ring animation
        withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }

        // Glow intensity animation
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.1)) {
                glowIntensity = detector.isWaitingForGeneration ? 0.7 + 0.3 * sin(Date().timeIntervalSince1970 * 3) : 0.3
            }
        }
    }
}

// MARK: - Action Button
struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text(title)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
            }
            .foregroundColor(isHovered ? .black : color)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? color : color.opacity(0.2))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(color.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Grid Pattern
struct GridPattern: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 20
            let lineWidth: CGFloat = 0.5

            // Vertical lines
            for x in stride(from: 0, through: size.width, by: spacing) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(.white), lineWidth: lineWidth)
            }

            // Horizontal lines
            for y in stride(from: 0, through: size.height, by: spacing) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(.white), lineWidth: lineWidth)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    TrainerVibeView(detector: VibeDetector.preview)
}
