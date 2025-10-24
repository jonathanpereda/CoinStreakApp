import Foundation

enum ScoreboardAPI {
    // Replace with your deployed Worker base URL if different
    private static let base = URL(string: "https://coinstreak-scoreboard.jonathanp.workers.dev")!

    struct RetireResponse: Decodable {
        let ok: Bool
        let retired: Bool?
        let removed: Int?
        let reason: String?
    }

    static func retireKeepingSide(installId: String) async {
        
        #if DEBUG
        print("[DEBUG] Skipping retireKeepingSide() write")
        return
        #endif
        
        let url = base.appendingPathComponent("/v1/retire-and-keep-side")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["installId": installId])

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse {
                // Optional: log once for your own debugging
                let body = String(data: data, encoding: .utf8) ?? ""
                print("retire status \(http.statusCode) body \(body)")
            }
        } catch {
            // If offline, no worries—this is safe to skip
            print("retire call failed: \(error.localizedDescription)")
        }
    }
    struct RegisterResponse: Decodable {
        let ok: Bool
        let created: Bool?
        let error: String?
    }

    static func register(installId: String, side: Face) async {
        
        #if DEBUG
        print("[DEBUG] Skipping register() write")
        return
        #endif
        
        let url = base.appendingPathComponent("/v1/register")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "installId": installId,
            "side": side.apiCode
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse {
                print("register status \(http.statusCode) body \(String(data: data, encoding: .utf8) ?? "")")
            }
        } catch {
            print("register call failed: \(error.localizedDescription)")
        }
    }
}

extension ScoreboardAPI {
    struct BootstrapResponse: Decodable {
        let ok: Bool
        let created: Bool?
        let delta: Int?
        let error: String?
    }

    static func bootstrap(installId: String, side: Face, currentStreak: Int) async {
        
        #if DEBUG
        print("[DEBUG] Skipping bootstrap() write")
        return
        #endif
        
        let url = base.appendingPathComponent("/v1/bootstrap")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "installId": installId,
            "side": side.apiCode,
            "currentStreak": currentStreak
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse {
                print("bootstrap status \(http.statusCode) body \(String(data: data, encoding: .utf8) ?? "")")
            }
        } catch {
            // If offline, we’ll try again next launch (since the marker won’t be set)
            print("bootstrap failed: \(error.localizedDescription)")
        }
    }
}

extension ScoreboardAPI {
    @discardableResult
    static func streak(installId: String, newCurrentStreak: Int) async -> Bool {
        
        #if DEBUG
        print("[DEBUG] Skipping streak() write")
        return true   // treat as success locally
        #endif
        
        let url = base.appendingPathComponent("/v1/streak")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "installId": installId,
            "newCurrentStreak": newCurrentStreak
        ])
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse {
                let body = String(data: data, encoding: .utf8) ?? ""
                print("streak status \(http.statusCode) body \(body)")
                return (200...299).contains(http.statusCode)
            }
        } catch {
            print("streak call failed: \(error.localizedDescription)")
        }
        return false
    }
}

// MARK: - Data model for /v1/scoreboard
struct TotalsDTO: Decodable {
    let heads: Int
    let tails: Int
    let headsCount: Int?
    let tailsCount: Int?
    let asOf: String?
}

extension ScoreboardAPI {
    static func fetchTotals() async -> TotalsDTO? {
        let url = base.appendingPathComponent("/v1/scoreboard")
        do {
            let (data, resp) = try await URLSession.shared.data(from: url)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return try JSONDecoder().decode(TotalsDTO.self, from: data)
        } catch {
            print("scoreboard fetch failed:", error.localizedDescription)
            return nil
        }
    }
}

extension ScoreboardAPI {
    static func fetchLockedSide(installId: String) async -> Face? {
        let url = base.appendingPathComponent("/v1/side")
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "installId", value: installId)]
        guard let final = comps.url else { return nil }

        do {
            let (data, resp) = try await URLSession.shared.data(from: final)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            struct Resp: Decodable { let side: String? }
            let r = try JSONDecoder().decode(Resp.self, from: data)
            switch r.side {
            case "H": return .Heads
            case "T": return .Tails
            default:  return nil
            }
        } catch { return nil }
    }
}

struct InstallState: Decodable {
    let side: String?
    let currentStreak: Int
}

extension ScoreboardAPI {
    static func fetchState(installId: String) async -> InstallState? {
        let url = base.appendingPathComponent("/v1/state")
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "installId", value: installId)]
        guard let final = comps.url else { return nil }

        do {
            let (data, resp) = try await URLSession.shared.data(from: final)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return try JSONDecoder().decode(InstallState.self, from: data)
        } catch {
            print("fetchState failed:", error.localizedDescription)
            return nil
        }
    }
}
