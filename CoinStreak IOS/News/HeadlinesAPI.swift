import Foundation

/// What the rest of the app should use: the 3 headlines + an asOf stamp.
struct NewsHeadlines: Codable, Equatable {
    var asOf: String
    var top: String
    var middle: String
    var bottom: String
}

/// Raw payload from the Worker.
/// This is flexible enough to handle either:
/// { "asOf": "...", "headline1": "...", "headline2": "...", "headline3": "..." }
/// or { "asOf": "...", "h1": "...", "h2": "...", "h3": "..." }
/// or { "asOf": "...", "slot1": "...", "slot2": "...", "slot3": "..." }.
private struct HeadlinesDTO: Decodable {
    let asOf: String?
    let headline1: String?
    let headline2: String?
    let headline3: String?

    enum CodingKeys: String, CodingKey {
        case asOf
        case headline1, headline2, headline3
        case h1, h2, h3
        case slot1, slot2, slot3
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        asOf = try c.decodeIfPresent(String.self, forKey: .asOf)

        let h1 = try c.decodeIfPresent(String.self, forKey: .headline1)
            ?? c.decodeIfPresent(String.self, forKey: .h1)
            ?? c.decodeIfPresent(String.self, forKey: .slot1)

        let h2 = try c.decodeIfPresent(String.self, forKey: .headline2)
            ?? c.decodeIfPresent(String.self, forKey: .h2)
            ?? c.decodeIfPresent(String.self, forKey: .slot2)

        let h3 = try c.decodeIfPresent(String.self, forKey: .headline3)
            ?? c.decodeIfPresent(String.self, forKey: .h3)
            ?? c.decodeIfPresent(String.self, forKey: .slot3)

        headline1 = h1
        headline2 = h2
        headline3 = h3
    }
}

/// API + local caching for the News Stand headlines.
enum HeadlinesAPI {
    /// UserDefaults key – bump the suffix if we ever change the format.
    private static let cacheKey = "news_headlines_cache_v1"

    /// Fallback if we have no network + no cached data yet.
    /// (You can tweak these to whatever “default headlines” you want.)
    static let fallback = NewsHeadlines(
        asOf: "local-default",
        top: "FLIP STREAK DAILY",
        middle: "HEADS AND TAILS AT WAR",
        bottom: "BREAKING: THE SKY IS BLUE"
    )

    // MARK: - Public API

    /// Load whatever we *currently* think the headlines are.
    /// Uses cache if present, otherwise the hard-coded fallback.
    static func loadCached() -> NewsHeadlines {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: cacheKey),
           let decoded = try? JSONDecoder().decode(NewsHeadlines.self, from: data) {
            return decoded
        }
        return fallback
    }

    /// Fetch the latest headlines from the backend.
    ///
    /// - Returns: The best headlines we have:
    ///   - If network succeeds and JSON is valid → decoded + stored to cache.
    ///   - If anything fails → returns the cached value (or fallback if none).
    static func fetchLatest() async -> NewsHeadlines {
        let cached = loadCached()

        // Build URL: ScoreboardAPI.base + "/v1/news-headlines"
        guard let url = URL(string: "/v1/news-headlines", relativeTo: ScoreboardAPI.base) else {
            return cached
        }

        var req = URLRequest(url: url)
        req.timeoutInterval = 8
        req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
                return cached
            }

            let dto = try JSONDecoder().decode(HeadlinesDTO.self, from: data)

            let new = NewsHeadlines(
                asOf: dto.asOf ?? cached.asOf,
                top: pick(dto.headline1, fallback: cached.top),
                middle: pick(dto.headline2, fallback: cached.middle),
                bottom: pick(dto.headline3, fallback: cached.bottom)
            )

            store(new)
            return new
        } catch {
            print("news headlines fetch failed:", error.localizedDescription)
            return cached
        }
    }

    // MARK: - Helpers

    /// Store the current headlines to UserDefaults.
    private static func store(_ headlines: NewsHeadlines) {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(headlines) {
            defaults.set(data, forKey: cacheKey)
        }
    }

    /// Use a non-empty trimmed string if present, otherwise keep the existing value.
    private static func pick(_ candidate: String?, fallback: String) -> String {
        guard let raw = candidate?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return fallback
        }
        return raw
    }
}
