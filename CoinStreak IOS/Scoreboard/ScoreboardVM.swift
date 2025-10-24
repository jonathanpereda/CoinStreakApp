import Foundation

@MainActor
final class ScoreboardVM: ObservableObject {
    @Published var heads = 0
    @Published var tails = 0
    @Published var headsPlayers = 0
    @Published var tailsPlayers = 0
    
    @Published var isOnline = true {
        didSet {
            if isOnline {
                let installId = InstallIdentity.getOrCreateInstallId()
                StreakSync.shared.replayIfNeeded(installId: installId)
            }
        }
    }

    private var pollTask: Task<Void, Never>?   // <-- keep a handle

    func startPolling() {
        // don’t stack multiple tasks
        if pollTask != nil { return }
        pollTask = Task { [weak self] in
            guard let self else { return }
            // immediate fetch on start
            await self.refresh()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5s
                await self.refresh()
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    deinit { pollTask?.cancel() }

    func refresh() async {
        if let t = await ScoreboardAPI.fetchTotals() {
            heads = max(0, t.heads)
            tails = max(0, t.tails)
            
            headsPlayers = max(0, t.headsCount ?? 0)
            tailsPlayers = max(0, t.tailsCount ?? 0)
            
            isOnline = true
        } else {
            isOnline = false
        }
    }
}
