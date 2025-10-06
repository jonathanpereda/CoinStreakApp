//
//  ProgressionManager.swift
//  CoinStreak
//
//  Created by Jonathan Pereda on 10/4/25.
//
import SwiftUI

/// Manages tiered progress bars and end-of-streak awards.
final class ProgressionManager: ObservableObject {

    // MARK: - Public, bindable state
    @Published private(set) var tierIndex: Int {
        didSet { UserDefaults.standard.set(tierIndex, forKey: Self.kTierIndex) }
    }
    @Published private(set) var currentProgress: Double {   // keep fractional to avoid rounding bias
        didSet { UserDefaults.standard.set(currentProgress, forKey: Self.kCurProgress) }
    }

    // MARK: - Configuration
    let tiers: [ProgressTier]            // immutable list for this app version
    let tuning: ProgressTuning           // provides r(s)
    
    // Theme hook for later (background per tier)
    var currentTierName: String { tiers[min(tierIndex, tiers.count - 1)].name }
    var currentBarTotal: Int { tiers[min(tierIndex, tiers.count - 1)].barTotal }
    var progressFraction: Double {
        guard currentBarTotal > 0 else { return 0 }
        return min(1.0, currentProgress / Double(currentBarTotal))
    }
    
    // Applies award with NO spillover. Returns true if this fills the current bar.
    @discardableResult
    func applyAward(len: Int) -> Bool {
        guard len > 0, !tiers.isEmpty, tierIndex < tiers.count else { return false }
        let award = tuning.r(len)
        let needed = max(0.0, Double(currentBarTotal) - currentProgress)
        if needed > 0, award >= needed {
            // Fill to the brim, but DO NOT advance tier yet (UI will animate it first)
            currentProgress += needed
            return true
        } else if award > 0 {
            currentProgress = min(Double(currentBarTotal), currentProgress + award)
        }
        return false
    }

    /// Call AFTER the fill animation completes to advance/reset (still no spillover).
    func advanceTierAfterFill() {
        guard tierIndex < tiers.count else { return }
        // Only act if we’re actually full
        guard currentProgress >= Double(currentBarTotal) else { return }
        if tierIndex + 1 < tiers.count {
            // Reset then move to next tier
            currentProgress = 0.0
            tierIndex += 1
        } else {
            // Final tier: stay full
            tierIndex = tiers.count - 1
            currentProgress = Double(currentBarTotal)
        }
    }
    

    // MARK: - Init (standard convenience)
    static func standard() -> ProgressionManager {
        // These should mirror your BuildBars tuning. Adjust as you rebalance.
        let tuning = ProgressTuning(p: 0.5, c: 1.7, gamma: 0.7)
        let specs: [ProgressTierSpec] = [
            .init(name: "Starter",   targetFlips: 1),
            .init(name: "Lab",   targetFlips: 1),
            .init(name: "Pond",     targetFlips: 50),
            .init(name: "Map3", targetFlips: 280),
            .init(name: "Map4",   targetFlips: 380),
        ]
        let tiers = buildTiers(tuning: tuning, specs: specs)
        return ProgressionManager(tuning: tuning, tiers: tiers)
    }

    init(tuning: ProgressTuning, tiers: [ProgressTier]) {
        self.tuning = tuning
        self.tiers  = tiers

        let savedTier = UserDefaults.standard.integer(forKey: Self.kTierIndex)
        let savedProg = UserDefaults.standard.object(forKey: Self.kCurProgress) as? Double ?? 0.0

        self.tierIndex = min(max(0, savedTier), max(0, tiers.count - 1))
        self.currentProgress = max(0.0, savedProg)
    }

    // MARK: - Award logic (end-of-streak only)
    /// Call exactly once when a streak ends with length `len > 0`.
    func awardForStreak(len: Int) {
        guard len > 0, !tiers.isEmpty, tierIndex < tiers.count else { return }

        let award = tuning.r(len)                // Double
        let needed = max(0.0, Double(currentBarTotal) - currentProgress)

        if award >= needed, needed > 0 {
            // Fill this bar exactly, advance tier, and DROP any remainder
            currentProgress += needed
            onBarFilled()                        // advances and resets progress to 0 (or clamps at final)
            // spillover intentionally discarded
        } else if award > 0 {
            // Partial fill within the same bar
            currentProgress += award
            currentProgress = min(currentProgress, Double(currentBarTotal))
        }
    }
    
    // Debug: reset to first tier with empty progress (and update persistence)
    func debugResetToFirstTier() {
        let defaults = UserDefaults.standard
        defaults.set(0, forKey: Self.kTierIndex)
        defaults.set(0.0, forKey: Self.kCurProgress)
        tierIndex = 0
        currentProgress = 0.0
    }


    // MARK: - Private helpers
    private func onBarFilled() {
        // TODO: hook SFX/FX here (bar complete)
        if tierIndex + 1 < tiers.count {
            // Advance to next tier and reset progress
            currentProgress = 0.0
            tierIndex += 1
        } else {
            // Final tier complete: clamp full and stop accumulating
            tierIndex = tiers.count - 1
            currentProgress = Double(currentBarTotal)
        }
    }

    // MARK: - Persistence keys
    private static let kTierIndex   = "pm_tierIndex_v1"
    private static let kCurProgress = "pm_curProgress_v1"
}

