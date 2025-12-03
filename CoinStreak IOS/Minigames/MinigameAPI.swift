import Foundation

// MARK: - Service Errors

enum MinigameServiceError: Error {
    case invalidURL
    case badStatusCode(Int)
    case decodingFailed
    case invalidData
}

// MARK: - DTOs (network formats)

private struct MinigamePeriodDTO: Decodable {
    let id: String
    let minigameId: String
    let startsAt: String   // ISO8601 date string from backend
    let endsAt: String
}

private struct MinigameLeaderboardEntryDTO: Decodable {
    let installId: String
    let displayName: String
    let score: Int
    let rank: Int
}

private struct MinigameMyStatusDTO: Decodable {
    let bestScore: Int?
    let rank: Int?
}

private struct MinigameSnapshotDTO: Decodable {
    let period: MinigamePeriodDTO
    let leaderboard: [MinigameLeaderboardEntryDTO]
    let me: MinigameMyStatusDTO
}

// If you decide to wrap responses later (e.g. { ok, error, snapshot }),
// you can add another DTO like:
//
// private struct MinigameSubmitResponseDTO: Decodable {
//     let ok: Bool
//     let error: String?
//     let snapshot: MinigameSnapshotDTO?
// }

// MARK: - Mapping DTO -> App Models

private extension MinigameSnapshot {
    init(from dto: MinigameSnapshotDTO) throws {
        func parseDate(_ s: String) throws -> Date {
            let formatter = ISO8601DateFormatter()
            if let d = formatter.date(from: s) {
                return d
            }
            throw MinigameServiceError.invalidData
        }

        guard let gameId = MinigameId(rawValue: dto.period.minigameId) else {
            // You can change this to throw if you want to be strict:
            // throw MinigameServiceError.invalidData
            throw MinigameServiceError.invalidData
        }

        let period = MinigamePeriod(
            id: dto.period.id,
            minigameId: gameId,
            startsAt: try parseDate(dto.period.startsAt),
            endsAt: try parseDate(dto.period.endsAt)
        )

        let entries = dto.leaderboard.map {
            MinigameLeaderboardEntry(
                installId: $0.installId,
                displayName: $0.displayName,
                score: $0.score,
                rank: $0.rank
            )
        }

        let me = MinigameMyStatus(
            bestScore: dto.me.bestScore,
            rank: dto.me.rank
        )

        self.init(period: period, leaderboard: entries, me: me)
    }
}

// MARK: - Concrete API Implementation

/// Concrete implementation of `MinigameAPI` that talks to your Cloudflare Worker.
struct CloudflareMinigameAPI: MinigameAPI {

    // Adjust this to match whatever domain you're actually deploying to.
    // I’m mirroring your ScoreboardAPI base pattern here.
    private static let base: URL = {
        // If you want simulator vs device branches, you can re-add them:
        //
        // #if targetEnvironment(simulator)
        // return URL(string: "http://127.0.0.1:8787")!
        // #else
        return URL(string: "https://coinstreak-scoreboard.jonathanp.workers.dev")!
        // #endif
    }()

    private let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    // MARK: - MinigameAPI

    func fetchCurrentSnapshot(installId: String) async throws -> MinigameSnapshot {
        guard var comps = URLComponents(
            url: Self.base.appendingPathComponent("/v1/minigame/current"),
            resolvingAgainstBaseURL: false
        ) else {
            throw MinigameServiceError.invalidURL
        }

        comps.queryItems = [
            URLQueryItem(name: "installId", value: installId)
        ]

        guard let url = comps.url else {
            throw MinigameServiceError.invalidURL
        }

        let (data, response) = try await urlSession.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw MinigameServiceError.badStatusCode(-1)
        }
        guard http.statusCode == 200 else {
            throw MinigameServiceError.badStatusCode(http.statusCode)
        }

        do {
            let dto = try JSONDecoder().decode(MinigameSnapshotDTO.self, from: data)
            return try MinigameSnapshot(from: dto)
        } catch {
            print("Minigame fetch decode error:", error)
            throw MinigameServiceError.decodingFailed
        }
    }

    func submitScore(
        installId: String,
        periodId: String,
        score: Int
    ) async throws -> MinigameSnapshot {
        let url = Self.base.appendingPathComponent("/v1/minigame/submit-score")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")

        struct Body: Encodable {
            let installId: String
            let periodId: String
            let score: Int
        }

        req.httpBody = try JSONEncoder().encode(Body(
            installId: installId,
            periodId: periodId,
            score: score
        ))

        let (data, response) = try await urlSession.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw MinigameServiceError.badStatusCode(-1)
        }
        guard http.statusCode == 200 else {
            throw MinigameServiceError.badStatusCode(http.statusCode)
        }

        do {
            let dto = try JSONDecoder().decode(MinigameSnapshotDTO.self, from: data)
            return try MinigameSnapshot(from: dto)
        } catch {
            print("Minigame submit decode error:", error)
            throw MinigameServiceError.decodingFailed
        }
    }
}
