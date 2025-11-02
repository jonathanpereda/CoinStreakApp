// BattleAPI.swift
import Foundation

enum BattleAPIError: Error {
    case message(String)
}


enum BattleAPI {
    private static let base = URL(string: "https://coinstreak-scoreboard.jonathanp.workers.dev")!

    // MARK: - Search users
    static func searchUsers(q: String, limit: Int = 12) async -> [UserSearchItem] {
        guard !q.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        var comps = URLComponents(url: base.appendingPathComponent("/v1/users/search"), resolvingAgainstBaseURL: false)! // <-- fixed
        comps.queryItems = [
            URLQueryItem(name: "q", value: q),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        guard let url = comps.url else { return [] }
        do {
            let (data, resp) = try await URLSession.shared.data(from: url)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return [] }
            return try JSONDecoder().decode([UserSearchItem].self, from: data)
        } catch { return [] }
    }

    // MARK: - Lists
    static func listIncoming(installId: String, limit: Int = 50, sort: String = "recent") async -> [ChallengeDTO] {
        var comps = URLComponents(url: base.appendingPathComponent("/v1/challenges/incoming"), resolvingAgainstBaseURL: false)! // <-- fixed
        comps.queryItems = [
            URLQueryItem(name: "installId", value: installId),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "sort", value: sort) // server expects "recent" or "streak"
        ]
        guard let url = comps.url else { return [] }
        do {
            let (data, resp) = try await URLSession.shared.data(from: url)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return [] }
            return try JSONDecoder().decode([ChallengeDTO].self, from: data)
        } catch { return [] }
    }

    static func listOutgoing(installId: String) async -> [ChallengeDTO] {
        var comps = URLComponents(url: base.appendingPathComponent("/v1/challenges/outgoing"), resolvingAgainstBaseURL: false)! // <-- fixed
        comps.queryItems = [URLQueryItem(name: "installId", value: installId)]
        guard let url = comps.url else { return [] }
        do {
            let (data, resp) = try await URLSession.shared.data(from: url)
            guard let http = resp as? HTTPURLResponse else { return [] }
            guard http.statusCode == 200 else { return [] }
            // Server returns ONE object or null → normalize to array
            if data.isEmpty { return [] }
            if let obj = try? JSONDecoder().decode(ChallengeDTO.self, from: data) {
                return [obj]
            }
            // If server returned null
            if String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) == "null" {
                return []
            }
            return []
        } catch { return [] }
    }

    // MARK: - Create / cancel / accept / decline
    static func createChallenge(
        challengerInstallId: String,
        targetInstallId: String
    ) async -> Result<ChallengeDTO, BattleAPIError> {
        let url = base.appendingPathComponent("/v1/challenges") // <-- fixed
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "challengerInstallId": challengerInstallId,
            "targetInstallId": targetInstallId
        ])

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { return .failure(.message("network")) }
            if (200...299).contains(http.statusCode) {
                let ch = try JSONDecoder().decode(ChallengeDTO.self, from: data)
                return .success(ch)
            } else {
                let err = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
                return .failure(.message(err ?? "error"))
            }
        } catch {
            return .failure(.message(error.localizedDescription))
        }
    }

    static func cancelChallenge(challengerInstallId: String, challengeId: String) async -> Bool {
        let url = base.appendingPathComponent("/v1/challenges/cancel") // <-- fixed
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "challengerInstallId": challengerInstallId,
            "challengeId": challengeId
        ])
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            return (resp as? HTTPURLResponse)?.statusCode == 200
        } catch { return false }
    }

    static func declineChallenge(targetInstallId: String, challengeId: String) async -> Bool {
        let url = base.appendingPathComponent("/v1/challenges/decline") // <-- fixed
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "targetInstallId": targetInstallId,
            "challengeId": challengeId
        ])
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            return (resp as? HTTPURLResponse)?.statusCode == 200
        } catch { return false }
    }

    static func acceptChallenge(targetInstallId: String, challengeId: String) async -> BattleAcceptResponse? {
        let url = base.appendingPathComponent("/v1/challenges/accept") // <-- fixed
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "targetInstallId": targetInstallId,
            "challengeId": challengeId
        ])
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { return nil }
            if http.statusCode == 200 {
                // Success payload
                var ok = try JSONDecoder().decode(BattleAcceptResponse.self, from: data)
                ok = BattleAcceptResponse(
                    battleId: ok.battleId,
                    winnerInstallId: ok.winnerInstallId,
                    loserInstallId: ok.loserInstallId,
                    animationSeed: ok.animationSeed,
                    decidedAt: ok.decidedAt,
                    error: nil
                )
                return ok
            } else {
                // Error payload (e.g., 409 with "STREAKS_CHANGED")
                let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
                let e = obj?["error"] as? String ?? "error"
                return BattleAcceptResponse(battleId: nil, winnerInstallId: nil, loserInstallId: nil, animationSeed: nil, decidedAt: nil, error: e)
            }
        } catch { return nil }
    }

    // MARK: - Reveals
    static func pollNextReveal(installId: String) async -> BattleRevealEvent? {
        var comps = URLComponents(url: base.appendingPathComponent("/v1/battle-events/next"), resolvingAgainstBaseURL: false)! // <-- fixed
        comps.queryItems = [URLQueryItem(name: "installId", value: installId)]
        guard let url = comps.url else { return nil }
        do {
            let (data, resp) = try await URLSession.shared.data(from: url)
            guard let http = resp as? HTTPURLResponse else { return nil }
            if http.statusCode == 204 { return nil }
            if http.statusCode != 200 { return nil }
            return try JSONDecoder().decode(BattleRevealEvent.self, from: data)
        } catch { return nil }
    }

    static func ackReveal(installId: String, eventId: String) async -> Bool {
        let url = base.appendingPathComponent("/v1/battle-events/ack") // <-- fixed
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "installId": installId,
            "eventId": eventId
        ])
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            return (resp as? HTTPURLResponse)?.statusCode == 200
        } catch { return false }
    }

    // MARK: - Attention badge (“!”)
    static func markOpened(installId: String) async {
        let url = base.appendingPathComponent("/v1/battles/opened") // already matches server
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["installId": installId])
        _ = try? await URLSession.shared.data(for: req)
    }
}

