//
//  WorkoutView.swift
//  Git-Fit
//
//  Displays micro-workouts and stretches for developers.
//

import SwiftUI
import Combine

// MARK: - Exercise Model
struct Exercise: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let duration: Int // seconds
    let icon: String
    let category: ExerciseCategory

    enum ExerciseCategory: String, CaseIterable {
        case stretch = "Stretch"
        case strength = "Strength"
        case eyeCare = "Eye Care"
        case posture = "Posture"

        var color: Color {
            switch self {
            case .stretch: return VibeColors.neonCyan
            case .strength: return VibeColors.neonMagenta
            case .eyeCare: return Color.green
            case .posture: return VibeColors.neonPurple
            }
        }
    }
}

// MARK: - Exercise Library
enum ExerciseLibrary {
    static let allExercises: [Exercise] = [
        // MARK: Stretches
        Exercise(
            name: "Chest Opener",
            description: "Clasp hands behind back, lift arms, open chest. Hold 15s.",
            duration: 20,
            icon: "figure.arms.open",
            category: .stretch
        ),
        Exercise(
            name: "Neck Rolls",
            description: "Slowly roll your head in a circle. 5 times each direction.",
            duration: 20,
            icon: "arrow.triangle.2.circlepath",
            category: .stretch
        ),
        Exercise(
            name: "Shoulder Shrugs",
            description: "Raise shoulders to ears, hold 3s, release. Repeat 5 times.",
            duration: 20,
            icon: "arrow.up.and.down",
            category: .stretch
        ),
        Exercise(
            name: "Wrist Circles",
            description: "Rotate wrists slowly. 10 circles each direction.",
            duration: 15,
            icon: "rotate.3d",
            category: .stretch
        ),
        Exercise(
            name: "Hip Flexor Stretch",
            description: "Step forward into lunge, push hips forward. Hold 15s each side.",
            duration: 30,
            icon: "figure.cooldown",
            category: .stretch
        ),

        // MARK: Strength
        Exercise(
            name: "Chair Squats",
            description: "Stand up from chair, sit back down slowly. 10 reps.",
            duration: 30,
            icon: "figure.stand",
            category: .strength
        ),
        Exercise(
            name: "Calf Raises",
            description: "Rise onto toes, hold 2s, lower. 15 reps.",
            duration: 25,
            icon: "figure.walk",
            category: .strength
        ),
        Exercise(
            name: "Desk Push-Ups",
            description: "Hands on desk, do 10 push-ups at an angle.",
            duration: 25,
            icon: "figure.strengthtraining.traditional",
            category: .strength
        ),
        Exercise(
            name: "Wall Sits",
            description: "Back against wall, slide down to 90° knee bend. Hold 30s.",
            duration: 35,
            icon: "figure.stand",
            category: .strength
        ),
        Exercise(
            name: "Tricep Dips",
            description: "Hands on chair edge, lower body, push back up. 10 reps.",
            duration: 30,
            icon: "figure.strengthtraining.functional",
            category: .strength
        ),

        // MARK: Eye Care
        Exercise(
            name: "20-20-20 Rule",
            description: "Look at something 20 feet away for 20 seconds.",
            duration: 20,
            icon: "eye",
            category: .eyeCare
        ),
        Exercise(
            name: "Eye Circles",
            description: "Roll eyes slowly in circles. 5 times each direction.",
            duration: 15,
            icon: "circle.dashed",
            category: .eyeCare
        ),
        Exercise(
            name: "Palming",
            description: "Cup warm palms over closed eyes. Breathe deeply for 20s.",
            duration: 25,
            icon: "hand.raised.fill",
            category: .eyeCare
        ),
        Exercise(
            name: "Focus Shifts",
            description: "Focus on finger close to face, then far object. Repeat 10x.",
            duration: 20,
            icon: "eye.trianglebadge.exclamationmark",
            category: .eyeCare
        ),
        Exercise(
            name: "Blinking Breaks",
            description: "Blink rapidly 20 times, then close eyes and relax for 10s.",
            duration: 15,
            icon: "eye.slash",
            category: .eyeCare
        ),

        // MARK: Posture
        Exercise(
            name: "Wall Angels",
            description: "Back against wall, slide arms up and down like snow angel. 10 reps.",
            duration: 30,
            icon: "figure.wave",
            category: .posture
        ),
        Exercise(
            name: "Chin Tucks",
            description: "Pull chin back, creating a double chin. Hold 5s. 8 reps.",
            duration: 25,
            icon: "face.smiling",
            category: .posture
        ),
        Exercise(
            name: "Thoracic Extension",
            description: "Hands behind head, arch upper back over chair. Hold 10s. 5 reps.",
            duration: 25,
            icon: "figure.flexibility",
            category: .posture
        ),
        Exercise(
            name: "Shoulder Blade Squeeze",
            description: "Squeeze shoulder blades together, hold 5s. Repeat 10 times.",
            duration: 25,
            icon: "arrow.left.and.right",
            category: .posture
        ),
        Exercise(
            name: "Cat-Cow Stretch",
            description: "Arch back up (cat), then dip down (cow). Alternate 10 times.",
            duration: 30,
            icon: "arrow.up.arrow.down",
            category: .posture
        ),
    ]

    static func randomExercise() -> Exercise {
        guard let exercise = allExercises.randomElement() else {
            // Fallback if allExercises is somehow empty
            return Exercise(
                name: "Quick Stretch",
                description: "Stand up, stretch your arms overhead, and breathe deeply.",
                duration: 15,
                icon: "figure.stand",
                category: .stretch
            )
        }
        return exercise
    }

    static func randomExercise(category: Exercise.ExerciseCategory) -> Exercise {
        allExercises.filter { $0.category == category }.randomElement() ?? randomExercise()
    }
}

// MARK: - Workout View Model
final class WorkoutViewModel: ObservableObject {
    @Published var currentExercise: Exercise
    @Published var timeRemaining: Int
    @Published var isActive: Bool = false
    @Published var isComplete: Bool = false

    private var timer: Timer?
    var onWorkoutComplete: (() -> Void)?

    init() {
        let exercise = ExerciseLibrary.randomExercise()
        self.currentExercise = exercise
        self.timeRemaining = exercise.duration
    }

    func startWorkout() {
        isActive = true
        isComplete = false
        timeRemaining = currentExercise.duration

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
            } else {
                self.completeWorkout()
            }
        }
    }

    func skipExercise() {
        timer?.invalidate()
        nextExercise()
    }

    func completeWorkout() {
        timer?.invalidate()
        isActive = false
        isComplete = true
        print("✅ [Workout] Completed: \(currentExercise.name)")

        // Auto-return to home after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.onWorkoutComplete?()
        }
    }

    func nextExercise() {
        currentExercise = ExerciseLibrary.randomExercise()
        timeRemaining = currentExercise.duration
        isComplete = false
        isActive = false
    }

    func reset() {
        timer?.invalidate()
        nextExercise()
    }

    deinit {
        timer?.invalidate()
    }
}

// MARK: - Workout View
struct WorkoutView: View {
    @StateObject private var viewModel = WorkoutViewModel()
    var onClose: (() -> Void)?
    var onComplete: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            // Header
            headerView

            // Exercise Card
            exerciseCard

            Spacer()

            // Timer / Progress
            if viewModel.isActive || viewModel.isComplete {
                timerView
            }

            // Completion message
            if viewModel.isComplete {
                completionView
            }

            // Action Buttons
            if !viewModel.isComplete {
                actionButtons
            }

            // Quick category buttons
            if !viewModel.isActive && !viewModel.isComplete {
                categoryButtons
            }
        }
        .padding(20)
        .frame(width: GitFitLayout.panelWidth, height: GitFitLayout.panelHeight)
        .onAppear {
            viewModel.onWorkoutComplete = onComplete
        }
    }

    // MARK: - Completion View
    private var completionView: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.green)

            Text("NICE WORK!")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            Text("Returning to monitor...")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.gray)
        }
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Header
    private var headerView: some View {
        HStack {
            // Back button
            Button(action: { onClose?() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(VibeColors.neonCyan)
            }
            .buttonStyle(.plain)

            Text("MICRO-WORKOUT")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(VibeColors.neonGradient)

            Spacer()
        }
    }

    // MARK: - Exercise Card
    private var exerciseCard: some View {
        VStack(spacing: 10) {
            // Category badge
            Text(viewModel.currentExercise.category.rawValue.uppercased())
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(viewModel.currentExercise.category.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(viewModel.currentExercise.category.color.opacity(0.2))
                .clipShape(Capsule())

            // Icon
            ZStack {
                Circle()
                    .fill(viewModel.currentExercise.category.color.opacity(0.2))
                    .frame(width: 70, height: 70)

                Image(systemName: viewModel.currentExercise.icon)
                    .font(.system(size: 28))
                    .foregroundColor(viewModel.currentExercise.category.color)
            }

            // Exercise name
            Text(viewModel.currentExercise.name)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            // Description
            Text(viewModel.currentExercise.description)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 10)

            // Duration badge
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 9))
                Text("\(viewModel.currentExercise.duration)s")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
            }
            .foregroundColor(VibeColors.neonCyan.opacity(0.8))
        }
    }

    // MARK: - Timer View
    private var timerView: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 4)
                .frame(width: 50, height: 50)

            Circle()
                .trim(from: 0, to: CGFloat(viewModel.timeRemaining) / CGFloat(viewModel.currentExercise.duration))
                .stroke(
                    viewModel.currentExercise.category.color,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 50, height: 50)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: viewModel.timeRemaining)

            Text("\(viewModel.timeRemaining)")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
    }

    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 12) {
            if viewModel.isActive {
                // Active workout - can skip
                ActionButton(title: "SKIP", icon: "forward.fill", color: .gray) {
                    viewModel.skipExercise()
                }
            } else {
                // Ready to start
                ActionButton(title: "START", icon: "play.fill", color: VibeColors.neonMagenta) {
                    viewModel.startWorkout()
                }

                ActionButton(title: "SHUFFLE", icon: "shuffle", color: VibeColors.neonCyan) {
                    viewModel.nextExercise()
                }
            }
        }
    }

    // MARK: - Category Buttons
    private var categoryButtons: some View {
        HStack(spacing: 6) {
            ForEach(Exercise.ExerciseCategory.allCases, id: \.self) { category in
                Button(action: {
                    viewModel.currentExercise = ExerciseLibrary.randomExercise(category: category)
                    viewModel.timeRemaining = viewModel.currentExercise.duration
                    viewModel.isComplete = false
                    viewModel.isActive = false
                }) {
                    Text(category.rawValue)
                        .font(.system(size: 7, weight: .medium, design: .monospaced))
                        .foregroundColor(category.color)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .background(category.color.opacity(0.15))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    WorkoutView()
        .frame(width: 300, height: 400)
        .background(VibeColors.darkBackground)
}
