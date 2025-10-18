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
    // Map lock (prevents automatic map changes; manual selects still allowed)
    @Published var mapLocked: Bool {
        didSet { UserDefaults.standard.set(mapLocked, forKey: Self.kMapLocked) }
    }

    // Total number of times the bar has filled (drives unlocks fairly)
    @Published var totalFills: Int {
        didSet { UserDefaults.standard.set(totalFills, forKey: Self.kTotalFills) }
    }

    // Unlock rule: starter always unlocked (1), then +1 map per every 2 fills.
    var unlockedCount: Int {
        let maxMaps = 1 + nonStarterNames.count
        // Old:
        // return min(1 + totalFills / 2, maxMaps)
        // New (arrival-based unlocks):
        return min(1 + ( (totalFills + 1) / 2 ), maxMaps)
    }


    // MARK: - Config
    struct LinearConfig {
        let baseTargetFlips: Int   // e.g. 30
        let incrementPerLevel: Int // e.g. 20 (so L0=30, L1=50, L2=70, ...)
    }

    let tuning: ProgressTuning
    let starterName: String = "Starter"
    #if TRAILER_RESET
    let nonStarterNames: [String] = ["Pond", "Space", "Brick", "Chair_Room", "Lab", "Backrooms", "Underwater"]
    #else
    let nonStarterNames: [String] = ["Lab", "Pond", "Brick", "Chair_Room", "Space", "Backrooms", "Underwater"] // fixed, ordered (not random)
    #endif
    let linear: LinearConfig

    // MARK: - Derived (compat layer to minimize UI changes)
    var tierIndex: Int { levelIndex } // Back-compat
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

    static func standard() -> ProgressionManager {
        let tuning = ProgressTuning(p: 0.5, c: 1.7, gamma: 0.7)

        // MARK: TUNE PROGRESSION
        let linear = LinearConfig(baseTargetFlips: 3, incrementPerLevel: 0) //40 : 10

        return ProgressionManager(tuning: tuning, linear: linear)
    }

    init(tuning: ProgressTuning, linear: LinearConfig) {
        self.tuning = tuning
        self.linear = linear
        let savedLevel = UserDefaults.standard.integer(forKey: Self.kLevelIndex)
        let savedProg  = UserDefaults.standard.object(forKey: Self.kCurProgress) as? Double ?? 0.0
        self.levelIndex = max(0, savedLevel)
        self.currentProgress = max(0.0, savedProg)
        self.mapLocked  = UserDefaults.standard.object(forKey: Self.kMapLocked) as? Bool ?? false
        self.totalFills = UserDefaults.standard.integer(forKey: Self.kTotalFills)
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
    
    // Clears the progress bar after a fill when we are NOT auto-advancing maps.
    func resetBarAfterLockedFill() {
        // Just clear progress; do not touch levelIndex or totals.
        currentProgress = 0
    }

    // Debug: reset to first level with empty progress
    func debugResetToFirstTier() {
        let defaults = UserDefaults.standard
        defaults.set(0, forKey: Self.kLevelIndex)
        defaults.set(0.0, forKey: Self.kCurProgress)
        levelIndex = 0
        currentProgress = 0.0
    }
    // Resets the map-unlock progression and lock state.
    func debugResetUnlocks() {
        totalFills = 0          // starter-only unlocked (unlockedCount becomes 1)
        mapLocked  = false
    }
    
    func registerBarFill() {
        totalFills &+= 1
    }
    
    func jumpToLevelIndex(_ idx: Int) {
        let clamped = max(0, idx)
        if clamped != levelIndex {
            levelIndex = clamped
            // keep currentProgress unchanged (manual selection shouldn’t alter the bar)
        }
    }


    // MARK: - Persistence keys
    private static let kLevelIndex   = "pm_levelIndex_v2"
    private static let kCurProgress  = "pm_curProgress_v2"
    private static let kMapLocked   = "pm_mapLocked_v1"
    private static let kTotalFills  = "pm_totalFills_v1"

}
