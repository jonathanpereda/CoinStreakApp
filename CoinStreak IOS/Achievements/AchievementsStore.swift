import Foundation
import Combine

final class AchievementsStore: ObservableObject {
    @Published private(set) var unlocked: Set<AchievementID> = []
    @Published private(set) var unseen:   Set<AchievementID> = []

    private let key = "achievements.unlocked.v1"
    private let unseenKey = "achievements.unseen.v1"
    private let defaults = UserDefaults.standard

    init() {
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([AchievementID].self, from: data) {
            unlocked = Set(decoded)
        }
        if let data2 = defaults.data(forKey: unseenKey),
           let decoded2 = try? JSONDecoder().decode([AchievementID].self, from: data2) {
            unseen = Set(decoded2)
        }
    }

    private func persistUnlocked() {
        let arr = Array(unlocked)
        if let data = try? JSONEncoder().encode(arr) {
            defaults.set(data, forKey: key)
        }
    }
    private func persistUnseen() {
        let arr = Array(unseen)
        if let data = try? JSONEncoder().encode(arr) {
            defaults.set(data, forKey: unseenKey)
        }
    }

    @discardableResult
    func unlock(_ id: AchievementID) -> Bool {
        if unlocked.contains(id) { return false }
        unlocked.insert(id)
        persistUnlocked()
        // mark as unseen so the tile glows in the menu until viewed
        unseen.insert(id)
        persistUnseen()
        return true
    }

    func isUnlocked(_ id: AchievementID) -> Bool { unlocked.contains(id) }

    // MARK: - Unseen helpers (NEW)
    func isUnseen(_ id: AchievementID) -> Bool { unseen.contains(id) }

    func markSeen(_ id: AchievementID) {
        if unseen.remove(id) != nil { persistUnseen() }
    }

    func markAllSeen() {
        if !unseen.isEmpty {
            unseen.removeAll()
            persistUnseen()
        }
    }

    func lock(_ id: AchievementID) {
        if unlocked.remove(id) != nil {
            persistUnlocked()
        }
        // If you ever re-lock, also clear its unseen flag.
        if unseen.remove(id) != nil { persistUnseen() }
    }

    func resetAll() {
        unlocked.removeAll()
        unseen.removeAll()                                          
        persistUnlocked()
        persistUnseen()
    }
}
