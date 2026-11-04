import XCTest
@testable import AirportCodesCore

final class DatasetTests: XCTestCase {
    let all = AirportData.all

    func testLoadsAndTierSizes() {
        XCTAssertEqual(all.filter { $0.tier == .easy }.count, 40)
        XCTAssertGreaterThanOrEqual(all.filter { $0.tier == .medium }.count, 140)
        XCTAssertGreaterThanOrEqual(all.filter { $0.tier == .advanced }.count, 380)
    }

    func testCodesAreUniqueThreeLetters() {
        let codes = all.map(\.code)
        XCTAssertEqual(Set(codes).count, codes.count, "duplicate codes")
        for c in codes { XCTAssertTrue(CodeChecker.isValidCode(c), c) }
    }

    func testEveryAirportIsComplete() {
        for a in all {
            XCTAssertFalse(a.name.isEmpty, a.code)
            XCTAssertFalse(a.city.isEmpty, a.code)
            XCTAssertFalse(a.country.isEmpty, a.code)
        }
    }

    func testKnownHubs() {
        let expected = ["SEA": "Seattle", "LAX": "Los Angeles", "JFK": "New York", "LHR": "London",
                        "ORD": "Chicago", "CDG": "Paris", "HND": "Tokyo", "SYD": "Sydney"]
        for (code, city) in expected {
            let a = AirportData.airport(code: code)
            XCTAssertEqual(a?.city, city, code)
            XCTAssertEqual(a?.tier, .easy, code)
        }
        XCTAssertEqual(AirportData.airport(code: "YVR")?.country, "Canada")
        XCTAssertEqual(AirportData.airport(code: "ord")?.code, "ORD")
    }

    func testCodeStoriesAreAttachedToTheRightAirports() {
        XCTAssertTrue(AirportData.airport(code: "ORD")!.fact.contains("Orchard"))
        XCTAssertTrue(AirportData.airport(code: "MCO")!.fact.contains("McCoy"))
        XCTAssertTrue(AirportData.airport(code: "YVR")!.fact.contains("Y"))
        XCTAssertTrue(AirportData.airport(code: "LAX")!.fact.contains("X"))
        XCTAssertGreaterThanOrEqual(all.filter { !$0.fact.isEmpty }.count, 40)
    }
}

final class CheckingTests: XCTestCase {
    func testCodeChecking() {
        XCTAssertTrue(CodeChecker.matches("sea", code: "SEA"))
        XCTAssertTrue(CodeChecker.matches(" S E A ", code: "SEA"))
        XCTAssertFalse(CodeChecker.matches("SEE", code: "SEA"))
        XCTAssertFalse(CodeChecker.matches("SEAT", code: "SEA"))
        XCTAssertFalse(CodeChecker.matches("", code: "SEA"))
    }

    private func session(_ mode: QuizMode, level: Tier, seed: UInt64) -> QuizSession {
        var p = AirportProgress()
        p.ladder.setTierForTesting(level)
        return QuizSession(mode: mode, progress: p, maker: QuestionMaker(seed: seed))
    }

    func testTypedCityAcceptsAliasesAndTypos() {
        var s = session(.codeToCity, level: .advanced, seed: 3)
        var q = s.next()
        while q.airport.code != "PEK" && q.serial < 3000 { q = s.next() }
        guard q.airport.code == "PEK" else { return XCTFail("PEK never came up") }
        XCTAssertEqual(q.style, .typeCity)
        XCTAssertTrue(s.isRight("beijing"))
        XCTAssertTrue(s.isRight("Peking"))
        XCTAssertTrue(s.isRight("Bejing"))
        XCTAssertFalse(s.isRight("Shanghai"))
    }

    func testWrongRealCodeIsExplained() {
        var s = session(.nameToCode, level: .easy, seed: 5)
        let q = s.next()
        let other = AirportData.all.first { $0.code != q.airport.code && $0.tier == .easy }!
        let r = s.answer(other.code.lowercased())
        XCTAssertFalse(r.correct)
        XCTAssertEqual(r.typedAirport?.code, other.code)
    }
}

final class QuestionTests: XCTestCase {
    func testEasyCodeToCityIsFourEasyChoices() {
        var m = QuestionMaker(seed: 1)
        for _ in 0..<50 {
            let q = m.next(level: .easy, kinds: [.codeToCity])
            XCTAssertEqual(q.airport.tier, .easy)
            guard case .choices(let c) = q.style else { return XCTFail() }
            XCTAssertEqual(c.count, 4)
            XCTAssertEqual(Set(c).count, 4)
            XCTAssertTrue(c.contains(q.airport.city))
        }
    }

    func testNameToCodeIsAlwaysTyped() {
        var m = QuestionMaker(seed: 2)
        for level in Tier.allCases {
            XCTAssertEqual(m.next(level: level, kinds: [.nameToCode]).style, .typeCode)
        }
    }

    func testAdvancedCodeToCityIsTyped() {
        var m = QuestionMaker(seed: 3)
        XCTAssertEqual(m.next(level: .advanced, kinds: [.codeToCity]).style, .typeCity)
    }

    func testMediumChoicesPreferSameCountry() {
        var m = QuestionMaker(seed: 4)
        var same = 0, total = 0
        for _ in 0..<60 {
            let q = m.next(level: .medium, kinds: [.codeToCity])
            guard case .choices(let c) = q.style, q.airport.country == "United States" else { continue }
            for city in c where city != q.airport.city {
                total += 1
                if AirportData.all.contains(where: { $0.city == city && $0.country == "United States" }) { same += 1 }
            }
        }
        XCTAssertGreaterThan(total, 0)
        XCTAssertEqual(same, total)
    }

    func testNoQuickRepeats() {
        var m = QuestionMaker(seed: 6)
        let codes = (0..<20).map { _ in m.next(level: .easy, kinds: [.nameToCode]).airport.code }
        XCTAssertEqual(Set(codes).count, codes.count)
    }

    func testMixedUsesBothKinds() {
        var m = QuestionMaker(seed: 7)
        let kinds = Set((0..<30).map { _ in m.next(level: .easy, kinds: QuizMode.mixed.kinds).kind })
        XCTAssertEqual(kinds, [.nameToCode, .codeToCity])
    }
}

final class SessionTests: XCTestCase {
    func testHintsAndPoints() {
        var s = QuizSession(mode: .nameToCode, progress: .fresh, maker: QuestionMaker(seed: 8))
        let q = s.next()
        XCTAssertEqual(s.pointsAvailable, 3)
        XCTAssertEqual(s.useHint(), "It starts with \(q.airport.code.prefix(1)).")
        XCTAssertEqual(s.pointsAvailable, 2)
        XCTAssertNotNil(s.useHint())
        XCTAssertNil(s.useHint())
        XCTAssertEqual(s.hints.count, 2)
        let r = s.answer(q.airport.code)
        XCTAssertTrue(r.correct)
        XCTAssertEqual(r.points, 1)
    }

    func testCityHintShowsFirstLetter() {
        let a = AirportData.airport(code: "SEA")!
        let q = Question(kind: .codeToCity, airport: a, style: .choices([]), serial: 1)
        let hints = QuizSession.hintTexts(for: q)
        XCTAssertEqual(hints[0], "It's in United States.")
        XCTAssertTrue(hints[1].hasPrefix("The city is S_"))
    }

    func testLevelUpAfterMastery() {
        var s = QuizSession(mode: .mixed, progress: .fresh, maker: QuestionMaker(seed: 9))
        XCTAssertEqual(s.progress.ladder.tier, .easy)
        var change: LevelChange?
        for _ in 0..<10 {
            let q = s.next()
            let answer = q.style == .typeCode ? q.airport.code : q.airport.city
            change = s.answer(answer).levelChange ?? change
        }
        XCTAssertEqual(change, .levelUp(.medium))
        XCTAssertEqual(s.streak, 10)
        XCTAssertEqual(s.progress.learned.count, 10)
        XCTAssertEqual(s.progress.stars, 30)
    }

    func testAllHintsDoNotCountForLevelUp() {
        var s = QuizSession(mode: .nameToCode, progress: .fresh, maker: QuestionMaker(seed: 10))
        for _ in 0..<12 {
            let q = s.next()
            s.useHint(); s.useHint()
            XCTAssertNil(s.answer(q.airport.code).levelChange)
        }
        XCTAssertEqual(s.progress.ladder.tier, .easy)
    }

    func testGentleStepDown() {
        var p = AirportProgress()
        p.ladder.setTierForTesting(.advanced)
        var s = QuizSession(mode: .nameToCode, progress: p, maker: QuestionMaker(seed: 11))
        var change: LevelChange?
        for _ in 0..<9 { _ = s.next(); change = s.answer("zzz").levelChange ?? change }
        XCTAssertNil(change, "not after only 9")
        _ = s.next()
        XCTAssertEqual(s.answer("zzz").levelChange, .stepDown(.medium))
    }

    func testSaveAndLoad() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = ProgressStore(directory: dir)
        XCTAssertEqual(store.load(), .fresh)
        var p = AirportProgress()
        p.stars = 7
        p.learned = ["SEA", "LAX"]
        p.ladder.setTierForTesting(.medium)
        try store.save(p)
        XCTAssertEqual(store.load(), p)
    }
}
