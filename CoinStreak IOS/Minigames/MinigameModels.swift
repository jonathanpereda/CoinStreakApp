import Foundation

enum MinigameId: String, Codable, CaseIterable {
    case callIt = "call_it"
    case coinRun = "coin_run"
    // add more as you build them
}

struct MinigamePeriod: Codable, Identifiable {
    let id: String            // e.g. "2025-W48" or some UUID
    let minigameId: MinigameId
    let startsAt: Date
    let endsAt: Date
}

struct MinigameLeaderboardEntry: Codable, Identifiable {
    var id: String { installId }

    let installId: String
    let displayName: String
    let score: Int
    let rank: Int
}

struct MinigameMyStatus: Codable {
    let bestScore: Int?
    let rank: Int?
}

/// Describes the actual rewards a player can receive for a given rank bracket
/// in a weekly minigame. Rewards can include tokens and/or unlocked shop assets.
struct MinigameReward: Codable {
    /// Optional number of tokens to award for this bracket.
    /// When nil or zero, no tokens are granted.
    let tokenAmount: Int?

    /// Zero or more asset keys that should be unlocked for the player.
    /// These keys are expected to line up with the shop's asset identifiers,
    /// e.g. "table_crate", "coin_callit_special", etc.
    let assetKeys: [String]
}

/// A rank bracket and its associated rewards for a minigame period.
/// For example, ranks 1–1 might receive reward tier "A", 2–2 tier "B",
/// and 3–5 tier "C".
struct MinigameRewardBracket: Codable, Identifiable {
    /// Identifier derived from the rank range, convenient for SwiftUI lists.
    var id: String { "\(minRank)-\(maxRank)" }

    /// Inclusive lower bound of the rank range (e.g. 1 for first place).
    let minRank: Int

    /// Inclusive upper bound of the rank range (e.g. 1 for exactly first, 5 for 1–5).
    let maxRank: Int

    /// Concrete rewards (tokens and/or asset keys) for players whose final
    /// rank falls inside this bracket.
    let reward: MinigameReward
}

struct MinigameSnapshot: Codable {
    let period: MinigamePeriod
    let leaderboard: [MinigameLeaderboardEntry]
    let me: MinigameMyStatus

    /// Optional reward schedule for this minigame period. When present, the
    /// client can determine what tokens and/or assets a given final rank
    /// should receive at the end of the period.
    let rewardBrackets: [MinigameRewardBracket]?
}

extension MinigameSnapshot {
    /// Returns the rewards (if any) that apply to the given final rank
    /// according to this snapshot's reward schedule.
    func rewards(forRank rank: Int) -> MinigameReward? {
        guard let brackets = rewardBrackets else { return nil }
        return brackets.first(where: { rank >= $0.minRank && rank <= $0.maxRank })?.reward
    }
}

protocol MinigameAPI {
    func fetchCurrentSnapshot(installId: String) async throws -> MinigameSnapshot

    /// Fetch the snapshot for the most recently finished minigame period, if any.
    /// Returns nil if there is no finished period yet.
    func fetchLastFinishedSnapshot(installId: String) async throws -> MinigameSnapshot?
    
    func submitScore(
        installId: String,
        periodId: String,
        score: Int
    ) async throws -> MinigameSnapshot
}

// MARK: - Minigame hosting configuration

/// Describes how a minigame wants to be hosted inside the app.
/// Some minigames are lightweight overlays, others want a dedicated “mode”
/// similar to the shop or a full-screen screen transition.
enum MinigameHostMode: String, Codable {
    /// Rendered as an overlay on top of the main game (like the stats screen).
    case overlay

    /// Hosted in a dedicated screen / mode (like the shop or a call-it screen),
    /// where the main HUD and other UI can be hidden as needed.
    case dedicatedScreen
}

/// Fine-grained configuration for how the app should adjust its UI
/// while a particular minigame is active.
struct MinigameHostConfig: Codable {
    /// High-level host mode (overlay vs dedicated screen).
    let mode: MinigameHostMode

    /// Whether the bottom HUD / menu should be hidden while this minigame runs.
    let hidesBottomMenu: Bool

    /// Whether the main streak HUD (streak counter, progress bar, recent flips, etc.)
    /// should be hidden while this minigame runs.
    let hidesStreakHUD: Bool

    /// Whether this minigame “borrows” the main gameplay coin.
    /// When true, the host can pause normal gameplay logic and let the minigame
    /// use the coin for its own flips/animations.
    let hijacksGameplayCoin: Bool
}

/// Describes a minigame in a registry-friendly way: an identifier, display
/// metadata, host configuration, and a factory for creating its SwiftUI view.
struct MinigameDescriptor {
    let id: MinigameId
    let displayName: String
    let hostConfig: MinigameHostConfig
}
