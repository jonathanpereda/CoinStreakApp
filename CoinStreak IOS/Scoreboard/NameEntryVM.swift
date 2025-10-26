import Foundation
import SwiftUI

@MainActor
final class NameEntryVM: ObservableObject {
    // MARK: - Published state for the view
    @Published var currentName: String = ""      // what’s in the text field
    @Published var displayName: String = ""      // last saved server name
    @Published var canChange: Bool = true
    @Published var cooldownRemaining: TimeInterval = 0   // seconds
    @Published var isSaving: Bool = false
    @Published var requiresRename: Bool = false


    // MARK: - Internals
    private var timer: Timer?
    private var installId: String { InstallIdentity.getOrCreateInstallId() }

    // Typed errors the UI can branch on
    enum SubmitError: Error {
        case invalidLocal          // fails client-side checks
        case taken                 // server says name is taken
        case cooldown              // server says still on cooldown
        case server(String)        // fallback/server failure
    }

    deinit { timer?.invalidate() }

    // MARK: - Public API (called by the view)

    /// Loads profile from /v1/profile and primes UI.
    func loadProfile() async {
        guard let p = await ScoreboardAPI.fetchProfile(installId: installId) else { return }

        // Keep the last saved server name around for display
        displayName = p.displayName

        // store server flag
        requiresRename = (p.requiresRename ?? false)

        if requiresRename {
            // Force-rename flow: unlock immediately and prompt user
            currentName = p.displayName
            cooldownRemaining = 0
            canChange = true
        } else {
            // Normal flow: use current server name as editable text
            currentName = p.displayName

            // canChangeAt is ms until unlocked (0 means unlocked)
            let seconds = max(0, TimeInterval(p.canChangeAt) / 1000.0)
            cooldownRemaining = seconds
            canChange = (seconds <= 0)
            startTimerIfNeeded()
        }
    }


    /// Client-side validation aligned with server rules: 3–7 chars, A–Z a–z 0–9 space _ -
    func prevalidate(_ raw: String) -> Bool {
        // Trim and collapse multiple spaces to one, like the server does
        let collapsed = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        guard (3...7).contains(collapsed.count) else { return false }
        return collapsed.range(of: "^[A-Za-z0-9 _-]{3,7}$", options: .regularExpression) != nil
    }


    /// Tries to set the new name on the server. Returns a typed result so the view
    /// can decide which overlay message to show.
    func submitName() async -> Result<Void, SubmitError> {
        let name = currentName.trimmingCharacters(in: .whitespaces)
        guard prevalidate(name) else { return .failure(.invalidLocal) }

        isSaving = true
        defer { isSaving = false }

        do {
            let resp = try await ScoreboardAPI.setDisplayName(installId: installId, name: name)

            if resp.ok {
                // 1) Update names
                displayName = resp.displayName ?? name
                currentName = displayName

                // 2) Instantly “lock” the field by applying cooldown now
                if let ms = resp.remainingMs, ms > 0 {
                    applyCooldown(msRemaining: ms)
                } else {
                    // Only apply the local default if this was NOT a forced-rename flow.
                    // When requiresRename was true, server lets them set a new name immediately.
                    if !requiresRename {
                        let defaultCooldownMs = 43_200_000 // 12h
                        applyCooldown(msRemaining: defaultCooldownMs)
                    } else {
                        cooldownRemaining = 0
                        canChange = true
                        requiresRename = false   // clear the flag; they’ve set a compliant name
                    }
                }

                return .success(())
            }

            // Map server errors
            switch (resp.error ?? "").lowercased() {
            case "invalid-chars", "invalid-length":
                return .failure(.invalidLocal)
            case "invalid-contact", "invalid-repeats", "invalid-reserved", "invalid-blocked":
                return .failure(.server(resp.error ?? "invalid"))   // let UI show a specific message
            case "taken", "name-taken":
                return .failure(.taken)
            case "cooldown":
                if let ms = resp.remainingMs { applyCooldown(msRemaining: ms) }
                return .failure(.cooldown)
            default:
                return .failure(.server(resp.error ?? "unknown"))
            }

        } catch {
            return .failure(.server(error.localizedDescription))
        }
    }

    // MARK: - Timer / cooldown helpers

    private func startTimerIfNeeded() {
        timer?.invalidate()
        guard cooldownRemaining > 0 else { return }

        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            cooldownRemaining = max(0, cooldownRemaining - 1)
            if cooldownRemaining <= 0 {
                canChange = true
                timer?.invalidate()
                timer = nil
            }
        }
        t.tolerance = 0.25
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func applyCooldown(msRemaining: Int) {
        let secs = max(0, TimeInterval(msRemaining) / 1000.0)
        cooldownRemaining = secs
        canChange = (secs <= 0)
        startTimerIfNeeded()
    }
}

// MARK: - Convenience
extension NameEntryVM {
    var cooldownMinutesRounded: Int {
        Int(ceil(max(0, cooldownRemaining) / 60))
    }
}
