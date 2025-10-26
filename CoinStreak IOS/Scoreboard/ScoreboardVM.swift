import Foundation

@MainActor
final class ScoreboardVM: ObservableObject {
    @Published var heads = 0
    @Published var tails = 0
    @Published var headsPlayers = 0
    @Published var tailsPlayers = 0

    // Piggybacked leaderboard slices (only filled when requested)
    @Published var headsTop: [LeaderboardEntryDTO] = []
    @Published var tailsTop: [LeaderboardEntryDTO] = []

    @Published var isOnline = true {
        didSet {
            if isOnline {
                let installId = InstallIdentity.getOrCreateInstallId()
                StreakSync.shared.replayIfNeeded(installId: installId)
            }
        }
    }

    private var pollTask: Task<Void, Never>?

    func startPolling(includeLeaderboard: @escaping () -> Bool) {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            guard let self else { return }

            await self.refresh(includeLeaderboard: includeLeaderboard())

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5s
                await self.refresh(includeLeaderboard: includeLeaderboard())
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    deinit { pollTask?.cancel() }

    private struct CombinedScoreboardDTO: Decodable {
        let heads: Int
        let tails: Int
        let headsCount: Int?
        let tailsCount: Int?
        let asOf: String?
        let leaderboard: PiggybackDTO?
    }

    private struct PiggybackDTO: Decodable {
        let side: String
        let limit: Int
        let heads: [LBItemDTO]
        let tails: [LBItemDTO]
    }

    private struct LBItemDTO: Decodable {
        let installId: String
        let side: String
        let currentStreak: Int
        let name: String     // NOTE: server uses `name`, not `displayName`
    }

    @MainActor
    func refresh(includeLeaderboard: Bool = false) async {
        do {
            let url = ScoreboardAPI.scoreboardURL(includeLeaderboard: includeLeaderboard, limit: 5)
            let (data, resp) = try await URLSession.shared.data(from: url)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }

            let dto = try JSONDecoder().decode(CombinedScoreboardDTO.self, from: data)

            heads = max(0, dto.heads)
            tails = max(0, dto.tails)
            headsPlayers = max(0, dto.headsCount ?? 0)
            tailsPlayers = max(0, dto.tailsCount ?? 0)
            isOnline = true

            // NEW: forward leaderboard if present
            if includeLeaderboard, let lb = dto.leaderboard {
                self.headsTop = lb.heads.map {
                    LeaderboardEntryDTO(
                        installId: $0.installId,
                        side: $0.side,
                        currentStreak: $0.currentStreak,
                        displayName: $0.name          // map `name` -> `displayName`
                    )
                }
                self.tailsTop = lb.tails.map {
                    LeaderboardEntryDTO(
                        installId: $0.installId,
                        side: $0.side,
                        currentStreak: $0.currentStreak,
                        displayName: $0.name
                    )
                }
            }
        } catch {
            isOnline = false
        }
    }
}
