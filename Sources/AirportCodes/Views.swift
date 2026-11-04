#if os(macOS)
import SwiftUI
import AirportCodesCore

struct RootView: View {
    @ObservedObject var model: AirportModel

    var body: some View {
        ZStack {
            Palette.paper.ignoresSafeArea()
            switch model.screen {
            case .home: HomeView(model: model)
            case .playing: PlayView(model: model)
            }
            if model.showConfetti {
                ConfettiView().ignoresSafeArea()
            }
            if let tier = model.levelUp {
                LevelUpOverlay(
                    title: "Now boarding: \(tier.title)!",
                    message: tier == .advanced
                        ? "Airports all over the world, and you type the city yourself."
                        : "More airports, and trickier choices from the same country.",
                    dismiss: { model.levelUp = nil }
                )
            }
        }
        .frame(minWidth: 940, minHeight: 700)
        .sheet(isPresented: $model.showParentGate) {
            ParentGate(
                onPass: {
                    model.showParentGate = false
                    model.showParentScreen = true
                },
                onCancel: { model.showParentGate = false }
            )
        }
        .sheet(isPresented: $model.showParentScreen) {
            ParentView(model: model)
        }
    }
}

struct HomeView: View {
    @ObservedObject var model: AirportModel

    var body: some View {
        VStack(spacing: 24) {
            Text("✈️ Airport Codes")
                .font(.system(size: 60, weight: .heavy, design: .rounded))
                .foregroundStyle(Palette.ink)
                // Hidden grown-ups door: press and hold the title for 3 seconds.
                .onLongPressGesture(minimumDuration: 3) { model.showParentGate = true }
            VStack(spacing: 10) {
                FlapText(text: "SEA LAX JFK LHR", size: 34)
                Text("Every airport has a 3-letter code. How many can you learn?")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(22)
            .background(Board.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

            LevelBadge(
                levelName: model.progress.ladder.tier.title,
                progress: model.progress.ladder.progressToNext,
                isTop: model.progress.ladder.tier.next == nil
            )
            .padding(20)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

            HStack(spacing: 20) {
                BigButton(title: "Find the code", subtitle: "Seattle → type SEA", fill: Palette.blue) { model.start(.nameToCode) }
                BigButton(title: "Where does it go?", subtitle: "SEA → Seattle", fill: Palette.leaf) { model.start(.codeToCity) }
                BigButton(title: "Mixed", subtitle: "Both kinds", fill: Palette.sun, ink: Palette.ink) { model.start(.mixed) }
            }
            .frame(maxWidth: 860)

            HStack(spacing: 30) {
                stat("⭐️", "\(model.progress.stars)", "stars")
                stat("🔥", "\(model.progress.bestStreak)", "best streak")
                stat("🎫", "\(model.progress.learned.count) of \(AirportData.all.count)", "codes collected")
            }
            Spacer(minLength: 0)
            Text("Airport data: OurAirports (public domain).")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Palette.ink.opacity(0.5))
        }
        .padding(36)
    }

    private func stat(_ icon: String, _ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(icon) \(value)").font(.system(size: 26, weight: .bold, design: .rounded))
            Text(label).font(.system(size: 15, weight: .medium, design: .rounded)).foregroundStyle(Palette.ink.opacity(0.7))
        }
        .foregroundStyle(Palette.ink)
        .accessibilityElement(children: .combine)
    }
}

struct PlayView: View {
    @ObservedObject var model: AirportModel
    @FocusState private var typing: Bool

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                PillButton(title: "Home", systemImage: "house.fill") { model.goHome() }
                Spacer()
                if let s = model.session {
                    Text("Level: \(s.progress.ladder.tier.title)  •  Score \(s.score)  •  Streak \(s.streak) 🔥")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                }
            }
            .foregroundStyle(Palette.ink)
            if let tier = model.steppedDown {
                StepDownBanner(levelName: tier.title)
            }
            if let q = model.question, let s = model.session {
                board(q, s)
                if let fb = model.feedback {
                    FeedbackCard(feedback: fb, question: q) { model.nextQuestion() }
                } else {
                    controls(q, s)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(28)
    }

    @ViewBuilder
    private func board(_ q: Question, _ s: QuizSession) -> some View {
        let a = q.airport
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("DEPARTURES")
                    .font(.system(size: 18, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white)
                Spacer()
                Text("WORTH \(s.pointsAvailable) ★")
                    .font(.system(size: 16, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Board.amber)
            }
            Divider().overlay(Color.white.opacity(0.2))
            switch q.kind {
            case .nameToCode:
                BoardRow(label: "TO", value: "\(a.city), \(a.country)", size: 30)
                BoardRow(label: "AIRPORT", value: a.name, size: 20)
                HStack(spacing: 16) {
                    Text("CODE")
                        .font(.system(size: 15, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.55))
                        .frame(width: 90, alignment: .leading)
                    if let fb = model.feedback {
                        FlapText(text: a.code, size: 70, color: fb.correct ? Board.green : Board.amber)
                    } else {
                        let letters = Array(model.typed)
                        HStack(spacing: 6) {
                            ForEach(0..<3, id: \.self) { i in
                                FlapTile(character: i < letters.count ? letters[i] : "?", size: 70,
                                         color: i < letters.count ? Board.amber : Color.white.opacity(0.25))
                            }
                        }
                    }
                }
            case .codeToCity:
                HStack(spacing: 16) {
                    Text("CODE")
                        .font(.system(size: 15, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.55))
                        .frame(width: 90, alignment: .leading)
                    FlapText(text: a.code, size: 80)
                }
                BoardRow(label: "TO", value: model.feedback == nil ? "? ? ?" : "\(a.city), \(a.country)", size: 30)
                if model.feedback != nil {
                    BoardRow(label: "AIRPORT", value: a.name, size: 20)
                }
            }
            ForEach(s.hints, id: \.self) { hint in
                Text("💡 \(hint)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .padding(26)
        .background(Board.background, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    @ViewBuilder
    private func controls(_ q: Question, _ s: QuizSession) -> some View {
        switch q.style {
        case .typeCode:
            HStack(spacing: 14) {
                TextField("Type 3 letters", text: Binding(get: { model.typed }, set: { model.setTypedCode($0) }))
                    .textFieldStyle(.plain)
                    .font(.system(size: 30, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .frame(width: 260)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Palette.blue.opacity(0.4), lineWidth: 2))
                    .focused($typing)
                    .autocorrectionDisabled()
                    .onSubmit { if model.typed.count == 3 { model.submit(model.typed) } }
                    .onAppear { typing = true }
                BigButton(title: "Check", fill: model.typed.count == 3 ? Palette.leaf : Palette.ink.opacity(0.3)) {
                    if model.typed.count == 3 { model.submit(model.typed) }
                }
                .frame(width: 160)
                hintButton(s)
                PillButton(title: "I don't know") { model.giveUp() }
            }
        case .choices(let options):
            VStack(spacing: 14) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 14) {
                    ForEach(Array(options.enumerated()), id: \.offset) { i, option in
                        BigButton(title: option, fill: [Palette.blue, Palette.leaf, Palette.coral, Palette.sun][i % 4],
                                  ink: i % 4 == 3 ? Palette.ink : .white) {
                            model.submit(option)
                        }
                        .keyboardShortcut(KeyEquivalent(Character("\(i + 1)")), modifiers: [])
                    }
                }
                HStack { hintButton(s); Spacer() }
            }
        case .typeCity:
            HStack(spacing: 14) {
                TextField("Type the city", text: $model.typed)
                    .textFieldStyle(.plain)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Palette.blue.opacity(0.4), lineWidth: 2))
                    .focused($typing)
                    .autocorrectionDisabled()
                    .onSubmit { model.submit(model.typed) }
                    .onAppear { typing = true }
                BigButton(title: "Check", fill: Palette.leaf) { model.submit(model.typed) }
                    .frame(width: 160)
                hintButton(s)
                PillButton(title: "I don't know") { model.giveUp() }
            }
        }
    }

    private func hintButton(_ s: QuizSession) -> some View {
        PillButton(title: s.hintsUsed < QuizSession.maxHints ? "Hint" : "No more hints", systemImage: "lightbulb.fill") {
            model.hint()
        }
        .disabled(s.hintsUsed >= QuizSession.maxHints)
    }
}

struct FeedbackCard: View {
    var feedback: Feedback
    var question: Question
    var next: () -> Void

    var body: some View {
        let a = question.airport
        HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(feedback.correct ? "On time! \(a.code) is \(a.city). +\(feedback.points) ⭐️" : "Not quite: \(a.code) is \(a.city).")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(feedback.correct ? Palette.leaf : Palette.coral)
                if let other = feedback.typedAirport {
                    Text("\(other.code) is a real airport too: \(other.city), \(other.country).")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                }
                if !a.fact.isEmpty {
                    Text("Why \(a.code)? \(a.fact)")
                        .font(.system(size: 19, weight: .medium, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .foregroundStyle(Palette.ink)
            Spacer()
            BigButton(title: "Next ▶︎", fill: Palette.blue, action: next)
                .frame(width: 180)
                .keyboardShortcut(.defaultAction)
        }
        .padding(20)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct ParentView: View {
    @ObservedObject var model: AirportModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Grown-ups").font(.system(size: 28, weight: .bold, design: .rounded))
            Text("Levels change on their own: 8 right out of the last 10 moves up, and only 2 or fewer right out of 10 steps back down. You can set the level here if needed.")
                .fixedSize(horizontal: false, vertical: true)
            Picker("Level", selection: Binding(
                get: { model.progress.ladder.tier },
                set: { model.parentSetLevel($0) })) {
                ForEach(Tier.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            Text("Answered \(model.progress.answered), right \(model.progress.correct), stars \(model.progress.stars), codes collected \(model.progress.learned.count), highest level \(model.progress.ladder.best.title).")
                .foregroundStyle(.secondary)
            HStack {
                Button("Reset progress…") { confirmReset = true }
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 520)
        .confirmationDialog("Start over from Easy and clear stars?", isPresented: $confirmReset) {
            Button("Reset", role: .destructive) { model.parentReset() }
        }
    }
}
#endif
