import Foundation

enum InstallMarker {
    private static let key = "coinstreak.installMarker"

    static func isFreshInstall() -> Bool {
        UserDefaults.standard.string(forKey: key) == nil
    }

    static func markInstalled() {
        UserDefaults.standard.set(Date().iso8601String, forKey: key)
    }
}

private extension Date {
    var iso8601String: String { ISO8601DateFormatter().string(from: self) }
}
