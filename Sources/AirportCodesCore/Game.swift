import Foundation

public enum QuizMode: String, Codable, CaseIterable, Sendable {
    case nameToCode
    case codeToCity
    case mixed

    public var title: String {
        switch self {
        case .nameToCode: return "Find the code"
        case .codeToCity: return "Where does it go?"
        case .mixed: return "Mixed"
        }
    }

    public var kinds: [QuestionKind] {
        switch self {
        case .nameToCode: return [.nameToCode]
        case .codeToCity: return [.codeToCity]
        case .mixed: return [.nameToCode, .codeToCity]
        }
    }
}

public enum QuestionKind: String, Codable, Sendable {
    /// See the city and airport, type the 3 letters.
    case nameToCode
    /// See the 3 letters, name the city.
    case codeToCity
}

public enum AnswerStyle: Equatable, Sendable {
    case typeCode
    case choices([String])
    case typeCity
}

public struct Question: Equatable, Sendable {
    public var kind: QuestionKind
    public var airport: Airport
    public var style: AnswerStyle
    public var serial: Int
}

public struct AirportProgress: Codable, Equatable, Sendable {
    public var ladder = LevelLadder()
    public var stars = 0
    public var answered = 0
    public var correct = 0
    public var bestStreak = 0
    /// Codes answered right at least once, for the "codes collected" count.
    public var learned: [String] = []

    public init() {}
    public static let fresh = AirportProgress()
}

public struct QuestionMaker {
    public var airports: [Airport]
    private var rng: SplitMix64
    private var recent: [String] = []
    private var serial = 0

    public init(airports: [Airport] = AirportData.all, seed: UInt64 = UInt64.random(in: 1...UInt64.max)) {
        self.airports = airports
        rng = SplitMix64(seed: seed)
    }

    public static func tiers(for level: Tier) -> [Tier] {
        switch level {
        case .easy: return [.easy]
        case .medium: return [.medium, .medium, .easy]
        case .advanced: return [.advanced, .advanced, .medium, .easy]
        }
    }

    public mutating func next(level: Tier, kinds: [QuestionKind]) -> Question {
        serial += 1
        let kind = rng.pick(kinds)
        let want = rng.pick(Self.tiers(for: level))
        var candidates = airports.indices.filter { airports[$0].tier == want }
        if candidates.isEmpty { candidates = Array(airports.indices) }
        let avoid = Set(recent.suffix(max(1, min(30, candidates.count * 2 / 3))))
        var pool = candidates.filter { !avoid.contains(airports[$0].code) }
        if pool.isEmpty { pool = candidates }
        let airport = airports[rng.pick(pool)]
        recent.append(airport.code)
        if recent.count > 60 { recent.removeFirst() }

        let style: AnswerStyle
        switch kind {
        case .nameToCode:
            style = .typeCode
        case .codeToCity:
            style = level == .advanced ? .typeCity : .choices(cityChoices(for: airport, level: level))
        }
        return Question(kind: kind, airport: airport, style: style, serial: serial)
    }

    /// Four different cities. On medium, the wrong ones come from the same country when possible.
    private mutating func cityChoices(for airport: Airport, level: Tier) -> [String] {
        let others = airports.filter { $0.city != airport.city }
        var pool: [Airport]
        if level == .easy {
            pool = others.filter { $0.tier == .easy }
        } else {
            pool = others.filter { $0.country == airport.country && $0.tier <= .medium }
            if Set(pool.map(\.city)).count < 3 { pool = others.filter { $0.tier <= .medium } }
        }
        var cities = Array(Set(pool.map(\.city))).sorted()
        var picks = [airport.city]
        while picks.count < 4 && !cities.isEmpty {
            picks.append(cities.remove(at: rng.int(0...(cities.count - 1))))
        }
        picks.shuffle(using: &rng)
        return picks
    }
}

public struct AnswerOutcome: Equatable, Sendable {
    public var correct: Bool
    public var points: Int
    public var levelChange: LevelChange?
    /// When a typed code is a different real airport, which one (to explain the mix-up).
    public var typedAirport: Airport?
}

public struct QuizSession {
    public private(set) var progress: AirportProgress
    public private(set) var question: Question?
    public private(set) var hintsUsed = 0
    public private(set) var score = 0
    public private(set) var streak = 0
    public let mode: QuizMode
    private var maker: QuestionMaker

    public static let maxHints = 2

    public init(mode: QuizMode, progress: AirportProgress, maker: QuestionMaker = QuestionMaker()) {
        self.mode = mode
        self.progress = progress
        self.maker = maker
    }

    public mutating func next() -> Question {
        hintsUsed = 0
        let q = maker.next(level: progress.ladder.tier, kinds: mode.kinds)
        question = q
        return q
    }

    public var pointsAvailable: Int { max(1, 3 - hintsUsed) }

    /// The hints shown so far, in order.
    public var hints: [String] {
        guard let q = question else { return [] }
        return Array(Self.hintTexts(for: q).prefix(hintsUsed))
    }

    public static func hintTexts(for q: Question) -> [String] {
        let a = q.airport
        switch q.kind {
        case .nameToCode:
            let letters = Array(a.code)
            return ["It starts with \(letters[0]).", "It's \(letters[0]) \(letters[1]) _"]
        case .codeToCity:
            let first = a.city.prefix(1)
            let blanks = String(repeating: "_", count: max(0, min(10, a.city.count - 1)))
            return ["It's in \(a.country).", "The city is \(first)\(blanks)"]
        }
    }

    @discardableResult
    public mutating func useHint() -> String? {
        guard let q = question, hintsUsed < Self.maxHints else { return nil }
        hintsUsed += 1
        return Self.hintTexts(for: q)[hintsUsed - 1]
    }

    public func isRight(_ answer: String) -> Bool {
        guard let q = question else { return false }
        switch q.style {
        case .typeCode:
            return CodeChecker.matches(answer, code: q.airport.code)
        case .choices:
            return answer == q.airport.city
        case .typeCity:
            let otherCities = maker.airports.map(\.city).filter { $0 != q.airport.city }
            return AnswerMatcher.matches(answer, name: q.airport.city, aliases: q.airport.aliases, otherNames: otherCities)
        }
    }

    public mutating func answer(_ answer: String) -> AnswerOutcome {
        guard let q = question else { return AnswerOutcome(correct: false, points: 0, levelChange: nil, typedAirport: nil) }
        let right = isRight(answer)
        var typed: Airport?
        if !right, q.style == .typeCode {
            let code = CodeChecker.normalize(answer)
            typed = maker.airports.first { $0.code == code }
        }
        let points = right ? pointsAvailable : 0
        progress.answered += 1
        if right {
            progress.correct += 1
            progress.stars += points
            score += points
            streak += 1
            progress.bestStreak = max(progress.bestStreak, streak)
            if !progress.learned.contains(q.airport.code) { progress.learned.append(q.airport.code) }
        } else {
            streak = 0
        }
        // Using every hint still earns a star, but only counts toward leveling up with 0 or 1 hints.
        let change = progress.ladder.record(correct: right && hintsUsed < Self.maxHints)
        return AnswerOutcome(correct: right, points: points, levelChange: change, typedAirport: typed)
    }
}
