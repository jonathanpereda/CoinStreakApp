// BattleModels.swift
import Foundation

// MARK: - User search
struct UserSearchItem: Decodable, Identifiable {
    let installId: String
    let displayName: String
    let currentStreak: Int
    var id: String { installId }

    private enum CodingKeys: String, CodingKey {
        case installId
        case displayName = "name"   // server sends 'name'
        case currentStreak
    }
}

// MARK: - Challenge status
enum ChallengeStatus: String, Decodable {
    case pending
    case declined
    case canceled    // NOTE: single “l” (server)
    case expired
    case accepted
}

// MARK: - Participants nested like the server
struct BattleParticipant: Decodable {
    let installId: String
    let name: String
    let currentStreak: Int
}

// MARK: - Unified Challenge model (works for both incoming & outgoing)
struct ChallengeDTO: Decodable, Identifiable {
    let id: String
    let status: ChallengeStatus?
    let stake: String?
    let createdAt: String
    let updatedAt: String?

    // Either (incoming) has challenger {...}, or (outgoing) has target {...}
    let challenger: BattleParticipant?
    let target: BattleParticipant?

    var idString: String { id }

    // Convenience accessors for UI
    var challengerName: String { challenger?.name ?? "" }
    var challengerStreakCurrent: Int { challenger?.currentStreak ?? 0 }
    var targetName: String { target?.name ?? "" }
    var targetStreakCurrent: Int { target?.currentStreak ?? 0 }

    var createdAtISO: String { createdAt }
    var expiresAtISO: String { "" } // server doesn’t return; keep for BC
    var statusOrPending: ChallengeStatus { status ?? .pending }

    var installIds: (challenger: String?, target: String?) {
        (challenger?.installId, target?.installId)
    }
}

// MARK: - Accept → Battle reveal
struct BattleAcceptResponse: Decodable {
    // Server returns these on 200
    let battleId: String?
    let winnerInstallId: String?
    let loserInstallId: String?
    let animationSeed: String?   // HEX string from server
    let decidedAt: String?

    // When not 200, we parse separately in API and synthesize error
    let error: String?
}

struct BattleRevealOpponent: Decodable {
    let installId: String
    let name: String
}

// Server-pushed reveal (first unseen)
struct BattleRevealEvent: Decodable, Identifiable, Equatable {
    let eventId: String
    let battleId: String
    let winnerInstallId: String
    let loserInstallId: String
    let animationSeed: String
    let decidedAt: String

    struct Opponent: Decodable, Equatable {   // ← add Equatable too
        let installId: String
        let name: String
    }
    let opponent: Opponent?                   // already optional; fine

    var id: String { eventId }
    var createdAtISO: String { decidedAt }
}

