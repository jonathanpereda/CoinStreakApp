// ProgressionManager.swift
import SwiftUI

/// Manages infinite, alternating levels with linear target growth:
///   Starter → NonStarter1 → Starter → NonStarter2 → Starter → ...
final class ProgressionManager: ObservableObject {

    // MARK: - Public, bindable state
    @Published private(set) var levelIndex: Int {                // 0-based, infinite
        didSet { UserDefaults.standard.set(levelIndex, forKey: Self.kLevelIndex) }
    }
    @Published private(set) var currentProgress: Double {         // fractional, no spillover
        didSet { UserDefaults.standard.set(currentProgress, forKey: Self.kCurProgress) }
    }

    // MARK: - Config
    struct LinearConfig {
        let baseTargetFlips: Int   // e.g. 30
        let incrementPerLevel: Int // e.g. 20 (so L0=30, L1=50, L2=70, ...)
    }

    let tuning: ProgressTuning                    // your r(s) function
    let starterName: String = "Starter"
    let nonStarterNames: [String] = ["Lab", "Pond", "Brick", "Chair_Room", "Space", "Backrooms", "Underwater"] // fixed, ordered (not random)
    let linear: LinearConfig

    // MARK: - Derived (compat layer to minimize UI changes)
    var tierIndex: Int { levelIndex } // Back-compat: you were observing this
    var currentTierName: String {
        if levelIndex % 2 == 0 { return starterName }
        let i = (levelIndex / 2) % max(nonStarterNames.count, 1)
        return nonStarterNames[i]
    }
    var currentBarTotal: Int {
        max(1, linear.baseTargetFlips + levelIndex * linear.incrementPerLevel)
    }
    var progressFraction: Double {
        min(1.0, currentProgress / Double(currentBarTotal))
    }

    // MARK: - Init
    static func standard() -> ProgressionManager {
        // Keep your award curve
        let tuning = ProgressTuning(p: 0.5, c: 1.7, gamma: 0.7)

        // Tweak these two numbers to taste.
        // Example: start at 30 flips, +20 per level → 30,50,70,90,110,...
        let linear = LinearConfig(baseTargetFlips: 40, incrementPerLevel: 10)         //TUNE PROGRESSION

        return ProgressionManager(tuning: tuning, linear: linear)
    }

    init(tuning: ProgressTuning, linear: LinearConfig) {
        self.tuning = tuning
        self.linear = linear
        let savedLevel = UserDefaults.standard.integer(forKey: Self.kLevelIndex)
        let savedProg  = UserDefaults.standard.object(forKey: Self.kCurProgress) as? Double ?? 0.0
        self.levelIndex = max(0, savedLevel)
        self.currentProgress = max(0.0, savedProg)
    }

    // MARK: - Award logic (end-of-streak only)
    /// Applies award with NO spillover. Returns true if this fills the current bar.
    @discardableResult
    func applyAward(len: Int) -> Bool {
        guard len > 0 else { return false }
        let award = tuning.r(len)
        let needed = max(0.0, Double(currentBarTotal) - currentProgress)
        if needed > 0, award >= needed {
            currentProgress += needed
            return true
        } else if award > 0 {
            currentProgress = min(Double(currentBarTotal), currentProgress + award)
        }
        return false
    }

    /// Call AFTER the fill animation completes to advance/reset (still no spillover).
    func advanceTierAfterFill() {
        // Only act if we’re actually full
        guard currentProgress >= Double(currentBarTotal) else { return }
        currentProgress = 0.0
        levelIndex &+= 1 // infinite
    }

    // Debug: reset to first level with empty progress
    func debugResetToFirstTier() {
        let defaults = UserDefaults.standard
        defaults.set(0, forKey: Self.kLevelIndex)
        defaults.set(0.0, forKey: Self.kCurProgress)
        levelIndex = 0
        currentProgress = 0.0
    }

    // MARK: - Persistence keys (v2)
    private static let kLevelIndex   = "pm_levelIndex_v2"
    private static let kCurProgress  = "pm_curProgress_v2"
}
