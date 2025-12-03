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

struct MinigameSnapshot: Codable {
    let period: MinigamePeriod
    let leaderboard: [MinigameLeaderboardEntry]
    let me: MinigameMyStatus
}

protocol MinigameAPI {
    func fetchCurrentSnapshot(installId: String) async throws -> MinigameSnapshot

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
