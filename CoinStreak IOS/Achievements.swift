
import Foundation

enum AchievementID: String, CaseIterable, Codable, Hashable {
    case highFlyer // “breaks threshold super swipe + thud”
    // add more here later…
}

struct Achievement: Identifiable, Codable, Hashable {
    let id: AchievementID
    let name: String
    let shortBlurb: String    // tooltip text
    let thumbName: String     // static PNG for unlocked state
    let silhouetteName: String // static PNG for locked state
}

enum AchievementsCatalog {
    static let all: [Achievement] = [
        .init(
            id: .highFlyer,
            name: "High Flyer",
            shortBlurb: "Flip the coin off the screen",
            thumbName: "trophy_highflyer_thumb", // export a simple PNG; placeholder ok
            silhouetteName: "trophy_highflyer_sil"
        ),
    ]

    static func byID(_ id: AchievementID) -> Achievement {
        all.first(where: { $0.id == id })!
    }
}
