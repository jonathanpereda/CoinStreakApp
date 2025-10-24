import Foundation

final class StreakSync {
    static let shared = StreakSync()
    private init() {}

    private let lastAckKey = "coinstreak.lastAckedStreak"
    private let pendingKey = "coinstreak.pendingTargetStreak"

    private var lastAcked: Int {
        get { UserDefaults.standard.integer(forKey: lastAckKey) }
        set { UserDefaults.standard.set(newValue, forKey: lastAckKey) }
    }

    private var pendingTarget: Int? {
        get {
            let v = UserDefaults.standard.object(forKey: pendingKey) as? Int
            return v
        }
        set {
            if let v = newValue {
                UserDefaults.standard.set(v, forKey: pendingKey)
            } else {
                UserDefaults.standard.removeObject(forKey: pendingKey)
            }
        }
    }

    /// Call this once after bootstrap succeeds to seed lastAcked.
    func seedAcked(to current: Int) {
        lastAcked = max(0, current)
    }

    /// Call this right after you update `store.currentStreak` locally for a flip.
    func handleLocalFlip(installId: String, current: Int, isOnline: Bool) {
        if isOnline {
            Task { await sendOrQueue(installId: installId, target: current) }
        } else {
            // offline: just record the target we want to reach later
            pendingTarget = current
        }
    }

    /// Call this when you detect you're back online (e.g. vm.isOnline became true, or on foreground).
    func replayIfNeeded(installId: String) {
        guard let target = pendingTarget else { return }
        Task { await catchUp(installId: installId, target: target) }
    }

    // MARK: - Internals

    private func sendOrQueue(installId: String, target: Int) async {
        // Legal immediate transitions:
        // +1 from lastAcked, or -> 0 from >0
        if target == 0 && lastAcked > 0 {
            if await ScoreboardAPI.streak(installId: installId, newCurrentStreak: 0) {
                lastAcked = 0
                pendingTarget = nil
                return
            }
        } else if target == lastAcked + 1 {
            if await ScoreboardAPI.streak(installId: installId, newCurrentStreak: target) {
                lastAcked = target
                pendingTarget = nil
                return
            }
        }

        // Otherwise queue to catch up later (maybe due to brief outage)
        pendingTarget = target
    }

    private func catchUp(installId: String, target: Int) async {
        var current = lastAcked

        // Simple cases
        if target == 0 {
            if current > 0 {
                if await ScoreboardAPI.streak(installId: installId, newCurrentStreak: 0) {
                    lastAcked = 0
                    pendingTarget = nil
                }
            } else {
                pendingTarget = nil
            }
            return
        }

        // Try to step from current -> target
        while current < target {
            let next = current + 1
            let ok = await ScoreboardAPI.streak(installId: installId, newCurrentStreak: next)
            if !ok {
                // Fallback: server thinks we're out-of-sync. Reset to 0, then count up.
                let resetOK = await ScoreboardAPI.streak(installId: installId, newCurrentStreak: 0)
                guard resetOK else { break }
                lastAcked = 0
                current = 0
                continue
            }
            current = next
            lastAcked = next
        }

        if current == target {
            pendingTarget = nil
        } else {
            pendingTarget = target // keep for next attempt
        }
    }
}

extension StreakSync {
    func debugReset() {
        UserDefaults.standard.removeObject(forKey: "coinstreak.lastAckedStreak")
        UserDefaults.standard.removeObject(forKey: "coinstreak.pendingTargetStreak")
    }
}
