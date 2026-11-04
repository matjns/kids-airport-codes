import Foundation

/// One airport from OurAirports (public domain).
public struct Airport: Codable, Equatable, Sendable {
    public var code: String
    public var name: String
    public var city: String
    public var country: String
    public var tier: Tier
    /// Other accepted answers for the city (old names, nearby towns, the airport's own name).
    public var aliases: [String]
    /// A true "why is it called that?" story, or empty.
    public var fact: String

    enum CodingKeys: String, CodingKey { case code, name, city, country, tier, aliases, fact }

    public init(code: String, name: String, city: String, country: String, tier: Tier, aliases: [String] = [], fact: String = "") {
        self.code = code; self.name = name; self.city = city; self.country = country
        self.tier = tier; self.aliases = aliases; self.fact = fact
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code = try c.decode(String.self, forKey: .code)
        name = try c.decode(String.self, forKey: .name)
        city = try c.decode(String.self, forKey: .city)
        country = try c.decode(String.self, forKey: .country)
        switch try c.decode(String.self, forKey: .tier) {
        case "medium": tier = .medium
        case "advanced", "hard": tier = .advanced
        default: tier = .easy
        }
        aliases = try c.decodeIfPresent([String].self, forKey: .aliases) ?? []
        fact = try c.decodeIfPresent(String.self, forKey: .fact) ?? ""
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(code, forKey: .code)
        try c.encode(name, forKey: .name)
        try c.encode(city, forKey: .city)
        try c.encode(country, forKey: .country)
        try c.encode(tier == .advanced ? "advanced" : tier == .medium ? "medium" : "easy", forKey: .tier)
        try c.encode(aliases, forKey: .aliases)
        try c.encode(fact, forKey: .fact)
    }
}

public enum AirportData {
    public static let all: [Airport] =
        (try? JSONDecoder().decode([Airport].self, from: Data(AirportListData.json.utf8))) ?? []

    public static let attribution = "Airport data from OurAirports (ourairports.com), public domain."

    public static func airport(code: String) -> Airport? {
        let c = code.uppercased()
        return all.first { $0.code == c }
    }
}

public enum CodeChecker {
    /// Keep letters only, uppercase: " sea " -> "SEA".
    public static func normalize(_ typed: String) -> String {
        String(typed.uppercased().filter { $0.isLetter && $0.isASCII })
    }

    public static func isValidCode(_ code: String) -> Bool {
        code.count == 3 && code.allSatisfy { $0.isASCII && $0.isUppercase && $0.isLetter }
    }

    public static func matches(_ typed: String, code: String) -> Bool {
        normalize(typed) == code
    }
}
