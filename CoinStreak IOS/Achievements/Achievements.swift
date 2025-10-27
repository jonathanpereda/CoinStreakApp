
import Foundation

enum AchievementID: String, CaseIterable, Codable, Hashable {
    case highFlyer
    case nightowl
    case unlucky
    case _balanced
    case harmony
    case gold
    case silver
    case bronze
    case steady
    case dedicated
    case devoted
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
            thumbName: "trophy_highflyer_thumb",
            silhouetteName: "trophy_highflyer_sil"
        ),
        .init(
            id: .nightowl,
            name: "Night Owl",
            shortBlurb: "Flip the coin late at night",
            thumbName: "trophy_nightowl_thumb",
            silhouetteName: "trophy_nightowl_sil"
        ),
        .init(
            id: .unlucky,
            name: "Tough Luck",
            shortBlurb: "Lose 10 times in a row",
            thumbName: "trophy_unlucky_thumb",
            silhouetteName: "trophy_unlucky_sil"
        ),
        .init(
            id: ._balanced,
            name: "Balanced",
            shortBlurb: "Flip alternating sides 10 times",
            thumbName: "trophy_balanced_thumb",
            silhouetteName: "trophy_balanced_sil"
        ),
        .init(
            id: .harmony,
            name: "Harmony",
            shortBlurb: "Flip alternating sides 15 times",
            thumbName: "trophy_harmony_thumb",
            silhouetteName: "trophy_harmony_sil"
        ),
        .init(
            id: .bronze,
            name: "Bronze Ribbon",
            shortBlurb: "Place 3rd on the leader-\nboard",
            thumbName: "trophy_bronze_thumb",
            silhouetteName: "trophy_ribbon_sil"
        ),
        .init(
            id: .silver,
            name: "Silver Ribbon",
            shortBlurb: "Place 2nd on the leader-\nboard",
            thumbName: "trophy_silver_thumb",
            silhouetteName: "trophy_ribbon_sil"
        ),
        .init(
            id: .gold,
            name: "Gold Ribbon",
            shortBlurb: "Place 1st on the leader-\nboard",
            thumbName: "trophy_gold_thumb",
            silhouetteName: "trophy_ribbon_sil"
        ),
        .init(
            id: .steady,
            name: "Steady",
            shortBlurb: "Flip 1000 times",
            thumbName: "trophy_steady_thumb",
            silhouetteName: "trophy_steady_sil"
        ),
        .init(
            id: .dedicated,
            name: "Dedicated",
            shortBlurb: "Flip 10000 times",
            thumbName: "trophy_dedicated_thumb",
            silhouetteName: "trophy_dedicated_sil"
        ),
        .init(
            id: .devoted,
            name: "Devoted",
            shortBlurb: "Flip 35000 times",
            thumbName: "trophy_devoted_thumb",
            silhouetteName: "trophy_devoted_sil"
        ),
    ]

    static func byID(_ id: AchievementID) -> Achievement {
        all.first(where: { $0.id == id })!
    }
}
