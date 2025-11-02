// BattleMenuVM.swift
import Foundation
import Combine
import SwiftUI

@MainActor
final class BattleMenuVM: ObservableObject {
    // Top “YOU” strip
    @Published var myName: String = ""
    @Published var myStreak: Int = 0

    // Lists
    @Published var outgoing: [ChallengeDTO] = []   // currently 0..1 but future-proof
    @Published var incoming: [ChallengeDTO] = []

    enum SortMode { case recent, highest }
    @Published var sortMode: SortMode = .recent

    // Search/create overlay
    @Published var query: String = ""
    @Published var searchResults: [UserSearchItem] = []
    @Published var isSearching: Bool = false
    @Published var createErrorBanner: String? = nil

    // Attention / state
    @Published var hasAttention: Bool = false
    @Published var isLoading: Bool = false
    @Published var revealPending: BattleRevealEvent? = nil // triggers cinematic
    @Published var lastResult: (opponentInstallId: String, opponentName: String, outcome: String)? = nil

    private var bag = Set<AnyCancellable>()
    private var lastOpenedISO: String = "1970-01-01T00:00:00.000Z" // server fills this in when we fetch incoming (optional)
    
    private var handledBattleIds = Set<String>()

    @MainActor @Published var maskStreakUntilReveal: Bool = false
    @MainActor @Published var streakValueBeforeReveal: Int? = nil
    @MainActor
    func beginStreakMask(currentVisibleStreak: Int) {
        maskStreakUntilReveal = true
        streakValueBeforeReveal = currentVisibleStreak
    }

    @MainActor
    func endStreakMask() {
        maskStreakUntilReveal = false
        streakValueBeforeReveal = nil
    }

    init() {
        // Debounce search box
        $query
            .removeDuplicates()
            .debounce(for: .milliseconds(180), scheduler: DispatchQueue.main)
            .sink { [weak self] q in
                Task { await self?.performSearch(q: q) }
            }
            .store(in: &bag)
    }

    // MARK: - Initial load
    func loadInitial(installId: String) async {
        isLoading = true
        defer { isLoading = false }

        // Profile + streak
        if let p = await ScoreboardAPI.fetchProfile(installId: installId) {
            myName = p.displayName
        }
        if let s = await ScoreboardAPI.fetchState(installId: installId) {
            myStreak = s.currentStreak
        }

        await refreshLists(installId: installId)
        await pollForRevealIfNeeded(installId: installId)
    }

    // MARK: - Lists
    func refreshLists(installId: String) async {
        let sort = (sortMode == .recent) ? "recent" : "streak"
        async let inc = BattleAPI.listIncoming(installId: installId, limit: 50, sort: sort)
        async let out = BattleAPI.listOutgoing(installId: installId)

        let prevLocal = self.outgoing
        let (incomingList, outgoingList) = await (inc, out)

        self.incoming = incomingList
        self.outgoing = mergeOutgoing(server: outgoingList, localKept: prevLocal)
        computeAttention(installId: installId)


    }




    private func computeAttention(installId: String) {
        // Attention if any incoming newer than lastOpened OR any of my outgoing has status DECLINED
        let declined = outgoing.contains { ($0.status ?? .pending) == .declined }
        // If server returns createdAt-exceeds-last-opened, you can compute here.
        // For now, if there is at least one incoming, highlight; the badge clears on markOpened().
        let unseenIncoming = !incoming.isEmpty
        hasAttention = declined || unseenIncoming
    }

    // MARK: - Mark opened (clears “!”)
    func markOpened(installId: String) async {
        await BattleAPI.markOpened(installId: installId)
        hasAttention = false
    }

    // MARK: - Search
    private func performSearch(q: String) async {
        isSearching = true
        defer { isSearching = false }
        searchResults = await BattleAPI.searchUsers(q: q, limit: 12)
    }

    // MARK: - Create / cancel / accept / decline
    func create(installId: String, targetInstallId: String) async -> Bool {
        let res = await BattleAPI.createChallenge(challengerInstallId: installId, targetInstallId: targetInstallId)
        switch res {
        case .success(let ch):
            outgoing = [ch]
            return true
        case .failure(let apiErr):
            switch apiErr {
            case .message(let msg):
                createErrorBanner = humanize(msg)
            }
            return false
        }
    }


    func cancel(installId: String, challengeId: String) async -> Bool {
        guard let item = outgoing.first(where: { $0.id == challengeId }) else { return false }

        switch item.statusOrPending {
        case .pending, .declined:
            // Server transition to 'canceled' ensures it never returns in outgoing
            let ok = await BattleAPI.cancelChallenge(challengerInstallId: installId, challengeId: challengeId)
            if ok { outgoing.removeAll { $0.id == challengeId } }
            return ok

        case .accepted:
            // Local-only result card (server doesn't return accepted in outgoing)
            outgoing.removeAll { $0.id == challengeId }
            return true

        case .canceled, .expired:
            // Already terminal; nothing to tell the server
            outgoing.removeAll { $0.id == challengeId }
            return true
        }
    }





    func accept(installId: String, challengeId: String) async -> BattleAcceptResponse? {
        let resp = await BattleAPI.acceptChallenge(targetInstallId: installId, challengeId: challengeId)

        if let resp,
            resp.error == nil,
            let seedHex = resp.animationSeed,
            let battleId = resp.battleId,
            let win = resp.winnerInstallId,
            let lose = resp.loserInstallId,
            let decided = resp.decidedAt {
            
                handledBattleIds.insert(battleId)

                // Drive the cinematic immediately
                revealPending = BattleRevealEvent(
                    eventId: "local-\(battleId)",
                    battleId: battleId,
                    winnerInstallId: win,
                    loserInstallId: lose,
                    animationSeed: seedHex,
                    decidedAt: decided,
                    opponent: nil
                )
                
                if lose == installId {
                    self.myStreak = 0
                }

                await refreshLists(installId: installId)
                return resp
            }

        // Error case (e.g., STREAKS_CHANGED)
        if let resp, let err = resp.error {
            createErrorBanner = humanize(err)
            await refreshLists(installId: installId)
        }
        return resp
    }

    func decline(installId: String, challengeId: String) async -> Bool {
        let ok = await BattleAPI.declineChallenge(targetInstallId: installId, challengeId: challengeId)
        if ok { incoming.removeAll(where: { $0.id == challengeId }) }
        return ok
    }

    // MARK: - Reveal polling
    func pollForRevealIfNeeded(installId: String) async {
        if let ev = await BattleAPI.pollNextReveal(installId: installId) {
            if handledBattleIds.contains(ev.battleId) {
                _ = await BattleAPI.ackReveal(installId: installId, eventId: ev.eventId)
                handledBattleIds.remove(ev.battleId)
                return
            }
            revealPending = ev
        }
    }

    func ackReveal(installId: String, eventId: String) async {
        // Tell server we showed it
        _ = await BattleAPI.ackReveal(installId: installId, eventId: eventId)

        // Refresh my streak so UI shows 0 if I lost
        if let s = await ScoreboardAPI.fetchState(installId: installId) {
            myStreak = s.currentStreak
        }
    }
    
    func recordRevealResult(event ev: BattleRevealEvent,
                            myInstallId: String,
                            myName: String,
                            myOpponentName: String?) {

        let iWon = (ev.winnerInstallId == myInstallId)
        let outcome = iWon ? "WON" : "LOST"

        let oppId   = ev.opponent?.installId
        let oppName = ev.opponent?.name ?? myOpponentName ?? "Opponent"

        // 1) Strict match: upgrade my pending SENT row (the sender path)
        if let idx = self.outgoing.firstIndex(where: { row in
            (row.statusOrPending == .pending) &&
            (row.target?.installId == oppId || row.targetName == oppName)
        }) {
            let old = self.outgoing[idx]
            let updated = ChallengeDTO(
                id: old.id,
                status: .accepted,
                stake: old.stake,
                createdAt: old.createdAt,
                updatedAt: ev.decidedAt,
                challenger: old.challenger,
                target: old.target
            )
            self.outgoing[idx] = updated
            self.lastResult = (opponentInstallId: oppId ?? "", opponentName: oppName, outcome: outcome)
            computeAttention(installId: myInstallId)
            return
        }

        // 2) Fallback: if I truly had exactly one pending outgoing (rare race), upgrade that one
        if let idx = self.outgoing.firstIndex(where: { $0.statusOrPending == .pending }) {
            let old = self.outgoing[idx]
            let updated = ChallengeDTO(
                id: old.id,
                status: .accepted,
                stake: old.stake,
                createdAt: old.createdAt,
                updatedAt: ev.decidedAt,
                challenger: old.challenger,
                target: old.target
            )
            self.outgoing[idx] = updated
            self.lastResult = (opponentInstallId: oppId ?? "", opponentName: oppName, outcome: outcome)
            computeAttention(installId: myInstallId)
            return
        }

        // 3) Otherwise: I wasn’t the sender → do NOT synthesize into outgoing.
        //    (Receiver path: no Sent card.)
        self.lastResult = (opponentInstallId: oppId ?? "", opponentName: oppName, outcome: outcome)
        computeAttention(installId: myInstallId)
    }



    
    // MARK: - Helpers

    func mergeOutgoing(server: [ChallengeDTO], localKept: [ChallengeDTO]) -> [ChallengeDTO] {
        // Keep non-pending rows (accepted/declined) and also the ONE pending row tied to the in-flight reveal.
        let kept = localKept.filter {
            $0.statusOrPending != .pending || shouldKeepPendingForReveal($0)
        }
        let serverIds = Set(server.map { $0.id })
        let extras = kept.filter { !serverIds.contains($0.id) }
        return extras + server
    }
    
    private func shouldKeepPendingForReveal(_ row: ChallengeDTO) -> Bool {
        guard let ev = revealPending else { return false }
        if let opp = ev.opponent {
            if let tid = row.target?.installId, tid == opp.installId { return true }
            if !row.targetName.isEmpty, row.targetName == opp.name { return true }
        }
        return false
    }


    private func humanize(_ err: String) -> String {
        switch err.uppercased() {
        case "NOT_ELIGIBLE":        return "Your streak must be within 5 of opponent."
        case "HAS_PENDING":         return "Max sent challenges reached."
        case "STREAKS_CHANGED":     return "Players’ streaks changed—challenge cancelled."
        case "EXPIRED":             return "This request expired."
        default:                    return "Something went wrong."
        }
    }

}


