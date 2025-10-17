import Foundation

enum BootstrapMarker {
    private static let key = "coinstreak.didBootstrap"

    static func needsBootstrap() -> Bool {
        // default false → needs bootstrap
        return UserDefaults.standard.bool(forKey: key) == false
    }

    static func markBootstrapped() {
        UserDefaults.standard.set(true, forKey: key)
    }
}

extension BootstrapMarker {
    static func clear() {
        UserDefaults.standard.removeObject(forKey: "coinstreak.bootstrap.done")
    }
}
