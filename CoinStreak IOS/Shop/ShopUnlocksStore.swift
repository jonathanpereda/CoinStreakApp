import Foundation
import SwiftUI

/// Central store for tracking which shop / cosmetic assets a player has unlocked.
/// Keys are string identifiers that come from the backend (e.g. "callit_coin", "callit_table").
/// This keeps unlock logic in one place instead of scattering booleans around the app.
final class ShopUnlocksStore: ObservableObject {

    /// The set of asset keys this player has unlocked.
    /// Backed by UserDefaults so unlocks persist across launches.
    @Published private(set) var unlockedAssetKeys: Set<String> = []

    private let defaultsKey = "ShopUnlockedAssetKeys"

    init() {
        loadFromDefaults()
    }

    // MARK: - Public API

    /// Returns true if the given asset key is currently unlocked.
    func isUnlocked(_ key: String) -> Bool {
        unlockedAssetKeys.contains(key)
    }

    /// Unlock a single asset key, persisting the change.
    /// Safe to call multiple times; redundant calls are ignored.
    func unlock(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !unlockedAssetKeys.contains(trimmed) else { return }

        unlockedAssetKeys.insert(trimmed)
        persistToDefaults()
    }

    /// Unlock multiple asset keys at once, persisting only if something changed.
    func unlock(_ keys: [String]) {
        var changed = false
        for raw in keys {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if !unlockedAssetKeys.contains(trimmed) {
                unlockedAssetKeys.insert(trimmed)
                changed = true
            }
        }
        if changed {
            persistToDefaults()
        }
    }

    /// Optional helper for debugging or admin use to wipe all unlocks.
    func resetAllUnlocks() {
        unlockedAssetKeys.removeAll()
        persistToDefaults()
    }

    // MARK: - Persistence

    private func loadFromDefaults() {
        let defaults = UserDefaults.standard
        if let stored = defaults.array(forKey: defaultsKey) as? [String] {
            unlockedAssetKeys = Set(stored)
        } else {
            unlockedAssetKeys = []
        }
    }

    private func persistToDefaults() {
        let defaults = UserDefaults.standard
        let array = Array(unlockedAssetKeys)
        defaults.set(array, forKey: defaultsKey)
    }
}
