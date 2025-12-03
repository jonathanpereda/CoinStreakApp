import Foundation
import Combine
import SwiftUI

/// Payload describing a full-screen minigame overlay that should be presented
/// above the core game (coin, table, HUD, etc.). The actual content is supplied
/// by the current minigame and rendered generically by the host.
struct MinigameOverlayPayload {
    let dimOpacity: Double
    let dismissOnBackgroundTap: Bool
    let content: AnyView
}

final class MinigameManager: ObservableObject {

    // MARK: - Published state

    @Published private(set) var activePeriod: MinigamePeriod?
    @Published private(set) var leaderboard: [MinigameLeaderboardEntry] = []
    @Published private(set) var myStatus: MinigameMyStatus = .init(bestScore: nil, rank: nil)
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
        //activePeriod?.minigameId
        return .callIt
    }

    var timeRemaining: TimeInterval? {
        guard let end = activePeriod?.endsAt else { return nil }
        return max(0, end.timeIntervalSinceNow)
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

    func refresh() {
        isLoading = true
        lastError = nil

        Task { @MainActor in
            do {
                let snapshot = try await api.fetchCurrentSnapshot(installId: installId)
                apply(snapshot: snapshot)
                isLoading = false
            } catch {
                lastError = error.localizedDescription
                isLoading = false
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
            } catch {
                // Non-fatal: game already ended, networking, etc.
                lastError = error.localizedDescription
            }
        }
    }

    // MARK: - Private

    @MainActor
    private func apply(snapshot: MinigameSnapshot) {
        self.activePeriod = snapshot.period
        self.leaderboard = snapshot.leaderboard
        self.myStatus = snapshot.me
    }

    private func startPeriodicRefresh() {
        // You can swap this with your existing global ticker if you prefer.
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        refresh()
    }
}
