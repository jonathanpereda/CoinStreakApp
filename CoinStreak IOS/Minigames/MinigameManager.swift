import Foundation
import Combine
import SwiftUI
import Network

/// Payload describing a full-screen minigame overlay that should be presented
/// above the core game (coin, table, HUD, etc.). The actual content is supplied
/// by the current minigame and rendered generically by the host.
struct MinigameOverlayPayload {
    let dimOpacity: Double
    let dismissOnBackgroundTap: Bool
    let content: AnyView
}

final class MinigameManager: ObservableObject {

    // MARK: - Connectivity state

    /// Reflects whether the device currently has general network connectivity.
    /// Backed by an NWPathMonitor so we can quickly react to the user going
    /// offline while a minigame session is active.
    @Published private(set) var isNetworkOnline: Bool = true

    /// Reflects whether the backend scoreboard/minigame API appears reachable
    /// based on recent requests. When false, we treat the minigame as effectively
    /// offline even if the device has general network connectivity.
    /// offline even if the device has general network connectivity.
    @Published private(set) var isBackendReachable: Bool = true

    /// Convenience flag for views: the minigame should be considered playable
    /// only when both the device is online and the backend appears reachable.
    var isOnlineForMinigame: Bool { isNetworkOnline && isBackendReachable }

    private let networkMonitor = NWPathMonitor()
    private let networkMonitorQueue = DispatchQueue(label: "MinigameNetworkMonitor")

    // MARK: - Published state

    @Published private(set) var activePeriod: MinigamePeriod?
    @Published private(set) var leaderboard: [MinigameLeaderboardEntry] = []
    @Published private(set) var myStatus: MinigameMyStatus = .init(bestScore: nil, rank: nil)

    /// Reward schedule for the current minigame period, if the backend provided one.
    /// When empty, either no rewards are configured or we haven't fetched a snapshot yet.
    @Published private(set) var rewardBrackets: [MinigameRewardBracket] = []

    /// Snapshot for the most recently finished minigame period, if the backend
    /// reports one. Used to drive the post-period rewards/results popup.
    @Published private(set) var lastFinishedSnapshot: MinigameSnapshot?

    @Published private(set) var isLoading: Bool = false
    @Published private(set) var lastError: String?

    /// Whether a minigame session is currently active. When true, the host
    /// (ContentView) can adjust its UI according to the current hostConfig.
    @Published private(set) var isSessionActive: Bool = false

    /// Optional full-screen overlay provided by the active minigame. When non-nil,
    /// the host should render this content above the core game, using the provided
    /// dimming and dismissal semantics.
    @Published var activeOverlay: MinigameOverlayPayload?

    /// Optional callback used when a minigame hijacks the gameplay coin and
    /// needs to be notified of visual-only flip outcomes (e.g. Heads/Tails).
    var onVisualFlipResolved: ((String) -> Void)?

    var onVisualFlipBegan: (() -> Void)?

    
    // Optional: simple computed helpers
    var activeMinigameId: MinigameId? {
        activePeriod?.minigameId
    }

    var timeRemaining: TimeInterval? {
        guard let end = activePeriod?.endsAt else { return nil }
        return max(0, end.timeIntervalSinceNow)
    }

    /// True when the current snapshot includes a reward schedule.
    var hasRewardSchedule: Bool {
        !rewardBrackets.isEmpty
    }

    /// Look up the rewards (if any) for a given final rank according to
    /// the current period's reward schedule.
    func reward(forRank rank: Int) -> MinigameReward? {
        guard !rewardBrackets.isEmpty else { return nil }
        return rewardBrackets.first(where: { rank >= $0.minRank && rank <= $0.maxRank })?.reward
    }

    /// Convenience accessor for the rewards the current player would receive
    /// based on their latest known rank in the leaderboard.
    var myPotentialReward: MinigameReward? {
        guard let rank = myStatus.rank else { return nil }
        return reward(forRank: rank)
    }

    /// The fully-registered minigame (descriptor + view factory), if any,
    /// for the currently active period.
    var currentRegisteredMinigame: RegisteredMinigame? {
        guard let id = activeMinigameId else { return nil }
        return MinigameRegistry.registeredMinigame(for: id)
    }

    /// Convenience accessor for just the descriptor of the current minigame.
    var currentDescriptor: MinigameDescriptor? {
        currentRegisteredMinigame?.descriptor
    }

    /// Convenience accessor for the current minigame's host configuration.
    var currentHostConfig: MinigameHostConfig? {
        currentDescriptor?.hostConfig
    }

    // MARK: - Dependencies

    private let api: MinigameAPI
    private let installId: String

    private var refreshTimer: Timer?

    init(api: MinigameAPI, installId: String) {
        self.api = api
        self.installId = installId

        // Begin monitoring network reachability so we can react if the player
        // goes offline while in a minigame.
        startNetworkMonitoring()

        startPeriodicRefresh()
    }

    deinit {
        refreshTimer?.invalidate()
    }

    // MARK: - Public API

    /// Called when the user taps the Weekly Minigame button.
    /// If there is an active period and a registered minigame for that id,
    /// we mark the session as active so the host can present it.
    func beginSession() {
        guard let id = activeMinigameId else { return }
        guard MinigameRegistry.registeredMinigame(for: id) != nil else {
            // No registered minigame for this id; nothing to launch yet.
            return
        }
        isSessionActive = true
    }

    /// Called by the host or the minigame when the session should end.
    func endSession() {
        isSessionActive = false
        onVisualFlipResolved = nil
        activeOverlay = nil
    }

    /// Fetch the snapshot for the most recently finished minigame period, if any.
    /// This does not affect the current activePeriod; it only updates
    /// `lastFinishedSnapshot` which can be used by the UI to present a
    /// one-time results/rewards popup.
    func refreshLastFinished() {
        Task { @MainActor in
            print("DEBUG refreshLastFinished() called")
            do {
                let snapshot = try await api.fetchLastFinishedSnapshot(installId: installId)
                print("DEBUG fetchLastFinishedSnapshot ->", snapshot?.period.id ?? "nil")
                self.lastFinishedSnapshot = snapshot
                // A successful response (even if there is no finished period yet)
                // confirms the backend is reachable.
                self.isBackendReachable = true
            } catch {
                print("DEBUG fetchLastFinishedSnapshot error:", error)
                // Treat this similarly to other minigame calls: record the error
                // and pessimistically mark the backend as unreachable.
                self.lastError = error.localizedDescription
                self.isBackendReachable = false
            }
        }
    }

    func refresh() {
        isLoading = true
        lastError = nil

        Task { @MainActor in
            do {
                let snapshot = try await api.fetchCurrentSnapshot(installId: installId)
                apply(snapshot: snapshot)
                isLoading = false
                // If we successfully fetched a snapshot, consider the backend reachable.
                isBackendReachable = true
            } catch {
                lastError = error.localizedDescription
                isLoading = false
                // On any fetch failure, treat the backend as unreachable for now.
                isBackendReachable = false
            }
        }
    }

    /// Called by minigames when they finish a run and get a score.
    func submitRun(score: Int) {
        guard let period = activePeriod else { return }

        // Optimistic early-out on client: if we clearly didn't beat our best, skip.
        if let best = myStatus.bestScore, score <= best {
            return
        }

        Task { @MainActor in
            do {
                let updated = try await api.submitScore(
                    installId: installId,
                    periodId: period.id,
                    score: score
                )
                apply(snapshot: updated)
                // Successful submission confirms the backend is reachable.
                isBackendReachable = true
            } catch {
                // If the period is closed, end the session and fetch the last-finished snapshot
                if let err = error as? MinigameServiceError {
                    switch err {
                    case .badStatusCode(let code) where code == 409:
                        // Backend says the period is closed.
                        // Shut down the session and pull the last-finished snapshot
                        // so ContentView can show the results popup.
                        endSession()
                        refreshLastFinished()

                    default:
                        break
                    }
                }

                // Non-fatal: networking, other server issues, etc.
                lastError = error.localizedDescription
                isBackendReachable = false
            }
        }
    }

    // MARK: - Private

    @MainActor
    private func apply(snapshot: MinigameSnapshot) {
        // Capture the previous active period id so we can detect when the
        // backend has rolled over to a new minigame period.
        let previousId = activePeriod?.id

        self.activePeriod = snapshot.period
        self.leaderboard = snapshot.leaderboard
        self.myStatus = snapshot.me
        self.rewardBrackets = snapshot.rewardBrackets ?? []

        // Detect period rollover
        if let prevId = previousId,
           prevId != snapshot.period.id {
            // We just moved from prevId → new active period.
            // If the player was in a minigame when the period flipped,
            // end the session so they can't keep playing an expired period.
            if isSessionActive {
                endSession()
            }
            // Fetch the snapshot for the last finished period (which should
            // correspond to prevId) so the UI can show the results/rewards
            // popup exactly once.
            refreshLastFinished()
        }
    }

    // MARK: - Connectivity helpers

    /// Start monitoring general network connectivity for minigames.
    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isNetworkOnline = (path.status == .satisfied)
            }
        }
        networkMonitor.start(queue: networkMonitorQueue)
    }

    private func startPeriodicRefresh() {
        // You can swap this with your existing global ticker if you prefer.
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        refresh()
    }
}
