#if os(macOS)
import Foundation
import SwiftUI
import AirportCodesCore

struct Feedback: Equatable {
    var correct: Bool
    var points: Int
    var guess: String
    var typedAirport: Airport?
}

@MainActor
final class AirportModel: ObservableObject {
    enum Screen { case home, playing }

    @Published var screen: Screen = .home
    @Published private(set) var progress: AirportProgress
    @Published private(set) var session: QuizSession?
    @Published private(set) var question: Question?
    @Published private(set) var feedback: Feedback?
    @Published var typed = ""
    @Published var showConfetti = false
    @Published var levelUp: Tier?
    @Published var steppedDown: Tier?

    private let store: ProgressStore

    init() {
        store = ProgressStore(directory: SupportFolder.url(named: AirportCodesRelease.supportFolder))
        progress = store.load()
    }

    func start(_ mode: QuizMode) {
        session = QuizSession(mode: mode, progress: progress)
        steppedDown = nil
        screen = .playing
        nextQuestion()
    }

    func nextQuestion() {
        guard var s = session else { return }
        feedback = nil
        typed = ""
        showConfetti = false
        question = s.next()
        session = s
    }

    func hint() {
        guard var s = session, feedback == nil else { return }
        s.useHint()
        session = s
    }

    /// Code answers are at most 3 letters, shown in capitals.
    func setTypedCode(_ text: String) {
        typed = String(CodeChecker.normalize(text).prefix(3))
    }

    func submit(_ answer: String) {
        guard var s = session, feedback == nil else { return }
        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        let outcome = s.answer(trimmed)
        session = s
        progress = s.progress
        feedback = Feedback(correct: outcome.correct, points: outcome.points, guess: trimmed, typedAirport: outcome.typedAirport)
        if outcome.correct {
            showConfetti = true
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                self?.showConfetti = false
            }
        }
        switch outcome.levelChange {
        case .levelUp(let tier)?:
            steppedDown = nil
            levelUp = tier
        case .stepDown(let tier)?:
            steppedDown = tier
        case nil:
            break
        }
        persist()
    }

    func giveUp() { submit("") }

    func goHome() {
        if let s = session { progress = s.progress }
        session = nil
        question = nil
        feedback = nil
        screen = .home
        persist()
    }

    func persist() {
        if let s = session { progress = s.progress }
        try? store.save(progress)
    }
}
#endif
