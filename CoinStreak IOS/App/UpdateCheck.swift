import Foundation
import UIKit

enum UpdateCheck {
    static let lookupURL = URL(string: "https://itunes.apple.com/lookup?id=6753908572")! // or ?id=YOUR_APP_ID
    static let lastPromptKey = "update.lastPromptedStoreVersion"

    static var localVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    static func shouldPrompt(for storeVersion: String) -> Bool {
        let last = UserDefaults.standard.string(forKey: lastPromptKey)
        return isStoreVersionNewer(storeVersion, than: localVersion) && last != storeVersion
    }

    static func markPrompted(storeVersion: String) {
        UserDefaults.standard.set(storeVersion, forKey: lastPromptKey)
    }

    // Semver-ish compare: 1.9 < 1.10, etc.
    static func isStoreVersionNewer(_ a: String, than b: String) -> Bool {
        func comps(_ s: String) -> [Int] { s.split(separator: ".").map { Int($0) ?? 0 } }
        let A = comps(a), B = comps(b)
        let n = max(A.count, B.count)
        for i in 0..<n {
            let ai = i < A.count ? A[i] : 0
            let bi = i < B.count ? B[i] : 0
            if ai != bi { return ai > bi }
        }
        return false
    }

    struct LookupResponse: Decodable {
        struct Item: Decodable { let version: String }
        let resultCount: Int
        let results: [Item]
    }

    #if DEBUG
    // Set to nil to use real network; set to "999.0" to force the prompt.
    static var debugForceStoreVersion: String? = "999.0"
    #endif

    static func fetchStoreVersion(timeout: TimeInterval = 2.0) async -> String? {
        #if DEBUG
        if let forced = debugForceStoreVersion { return forced }
        #endif
        var req = URLRequest(url: lookupURL)
        req.timeoutInterval = timeout
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let decoded = try JSONDecoder().decode(LookupResponse.self, from: data)
            return decoded.results.first?.version
        } catch {
            return nil
        }
    }
}
