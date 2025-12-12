import Foundation
import CryptoKit

// MARK: - Lightweight Request Signing

/// Helper for generating a lightweight HMAC-style signature for minigame
/// score submissions. The same key and canonicalization logic must be
/// implemented on the backend to verify requests.
private struct MinigameRequestSigner {
    /// Shared secret used for signing. In production you should obfuscate
    /// this and mirror the same value in your Worker environment.
    private static let secretKey = "MINIGAME_CLIENT_SECRET_CHANGE_ME"

    struct SignedBody: Encodable {
        let installId: String
        let periodId: String
        let score: Int
        let clientTimestamp: Int
        let clientNonce: String

        /// Canonical string used for signing. The backend must reconstruct
        /// this exact string from the JSON body when verifying.
        var canonicalString: String {
            "\(installId)|\(periodId)|\(score)|\(clientTimestamp)|\(clientNonce)"
        }
    }

    /// Compute a hex-encoded HMAC-SHA256 signature for the given body.
    static func signature(for body: SignedBody) -> String {
        let keyData = Data(secretKey.utf8)
        let symmetricKey = SymmetricKey(data: keyData)
        let messageData = Data(body.canonicalString.utf8)
        let mac = HMAC<SHA256>.authenticationCode(for: messageData, using: symmetricKey)
        return mac.map { String(format: "%02x", $0) }.joined()
    }
}

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

private struct MinigameRewardDTO: Decodable {
    let tokenAmount: Int?
    let assetKeys: [String]
}

private struct MinigameRewardBracketDTO: Decodable {
    let minRank: Int
    let maxRank: Int
    let reward: MinigameRewardDTO
}

private struct MinigameSnapshotDTO: Decodable {
    let period: MinigamePeriodDTO
    let leaderboard: [MinigameLeaderboardEntryDTO]
    let me: MinigameMyStatusDTO
    let rewardBrackets: [MinigameRewardBracketDTO]?
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
        // High-level sanity log so we can see what came over the wire
        /*print("MinigameSnapshotDTO period:",
              "id=\(dto.period.id)",
              "minigameId=\(dto.period.minigameId)",
              "startsAt=\(dto.period.startsAt)",
              "endsAt=\(dto.period.endsAt)",
              "leaderboardCount=\(dto.leaderboard.count)",
              "rewardBracketsCount=\(dto.rewardBrackets?.count ?? 0)")*/

        // Primary formatter: internet datetime + fractional seconds
        let formatterWithMillis = ISO8601DateFormatter()
        formatterWithMillis.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Fallback formatter: internet datetime without fractional seconds
        let formatterNoMillis = ISO8601DateFormatter()
        formatterNoMillis.formatOptions = [.withInternetDateTime]

        func parseDate(_ s: String) throws -> Date {
            if let d = formatterWithMillis.date(from: s) {
                return d
            }
            if let d = formatterNoMillis.date(from: s) {
                return d
            }
            //print("Minigame invalidData: failed to parse date string:", s)
            throw MinigameServiceError.invalidData
        }

        guard let gameId = MinigameId(rawValue: dto.period.minigameId) else {
            //print("Minigame invalidData: unknown minigameId:", dto.period.minigameId)
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

        let brackets: [MinigameRewardBracket]? = dto.rewardBrackets?.map { bracketDTO in
            MinigameRewardBracket(
                minRank: bracketDTO.minRank,
                maxRank: bracketDTO.maxRank,
                reward: MinigameReward(
                    tokenAmount: bracketDTO.reward.tokenAmount,
                    assetKeys: bracketDTO.reward.assetKeys
                )
            )
        }

        self.init(
            period: period,
            leaderboard: entries,
            me: me,
            rewardBrackets: brackets
        )
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
    
    func fetchLastFinishedSnapshot(installId: String) async throws -> MinigameSnapshot? {
        guard var comps = URLComponents(
            url: Self.base.appendingPathComponent("/v1/minigame/last-finished"),
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

        // 404 means: there is no finished period yet.
        if http.statusCode == 404 {
            return nil
        }

        guard http.statusCode == 200 else {
            throw MinigameServiceError.badStatusCode(http.statusCode)
        }

        do {
            let dto = try JSONDecoder().decode(MinigameSnapshotDTO.self, from: data)
            return try MinigameSnapshot(from: dto)
        } catch {
            print("Minigame last-finished decode error:", error)
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

        // Prepare a signed body with a client timestamp and nonce so the
        // backend can verify authenticity and optionally guard against
        // simple replay attacks.
        let timestamp = Int(Date().timeIntervalSince1970)
        let nonce = UUID().uuidString

        let body = MinigameRequestSigner.SignedBody(
            installId: installId,
            periodId: periodId,
            score: score,
            clientTimestamp: timestamp,
            clientNonce: nonce
        )

        let signature = MinigameRequestSigner.signature(for: body)
        req.addValue(signature, forHTTPHeaderField: "X-MinGame-Signature")

        req.httpBody = try JSONEncoder().encode(body)

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
