import SwiftUI

enum Face: String, Codable { case Heads, Tails }

struct FlipEvent: Codable, Identifiable, Equatable {
    let id = UUID()
    let face: Face
    let date: Date
}

final class FlipStore: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var chosenFace: Face? {
        didSet { defaults.set(chosenFace?.rawValue, forKey: "chosenFace_raw") }
    }

    @Published var currentStreak: Int {
        didSet { defaults.set(currentStreak, forKey: "currentStreak") }
    }

    @Published private(set) var recent: [FlipEvent] = []
    private let historyLimit = 10
    private let recentKey = "recentFlipsData" // store as Data

    init() {
        if let raw = defaults.string(forKey: "chosenFace_raw") {
            chosenFace = Face(rawValue: raw)
        } else {
            chosenFace = nil
        }
        currentStreak = defaults.integer(forKey: "currentStreak")
        loadRecent()
    }

    private func loadRecent() {
        if let data = defaults.data(forKey: recentKey),
           let decoded = try? JSONDecoder().decode([FlipEvent].self, from: data) {
            recent = decoded
        } else {
            recent = []
        }
    }

    private func saveRecent() {
        if let data = try? JSONEncoder().encode(recent) {
            defaults.set(data, forKey: recentKey)
        }
    }
    
    func clearRecent() {
        recent.removeAll()
        saveRecent()
    }


    /// Call after each completed flip
    func recordFlip(result: Face) {
        // history
        recent.insert(FlipEvent(face: result, date: Date()), at: 0)
        if recent.count > historyLimit { recent.removeLast(recent.count - historyLimit) }
        saveRecent()

        // streak (only counts if player has chosen)
        guard let pick = chosenFace else {
            currentStreak = 0
            return
        }
        if result == pick {
            currentStreak += 1
        } else {
            currentStreak = 0
        }
    }
}
