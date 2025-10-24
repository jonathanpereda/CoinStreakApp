
import Foundation
import Combine

final class AchievementsStore: ObservableObject {
    @Published private(set) var unlocked: Set<AchievementID> = []

    private let key = "achievements.unlocked.v1"
    private let defaults = UserDefaults.standard

    init() {
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([AchievementID].self, from: data) {
            unlocked = Set(decoded)
        }
    }

    private func persist() {
        let arr = Array(unlocked)
        if let data = try? JSONEncoder().encode(arr) {
            defaults.set(data, forKey: key)
        }
    }

    @discardableResult
    func unlock(_ id: AchievementID) -> Bool {
        if unlocked.contains(id) { return false }
        unlocked.insert(id)
        persist()
        return true
    }

    func isUnlocked(_ id: AchievementID) -> Bool {
        unlocked.contains(id)
    }
    
    func lock(_ id: AchievementID) {
        if unlocked.remove(id) != nil {
            persist()
        }
    }

    func resetAll() {
        unlocked.removeAll()
        persist()
    }
    
}

