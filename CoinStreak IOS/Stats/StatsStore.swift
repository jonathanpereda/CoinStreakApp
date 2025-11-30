import Foundation
import Combine

final class StatsStore: ObservableObject {
    @Published private(set) var totalFlips: Int
    @Published private(set) var totalHeads: Int
    @Published private(set) var totalTails: Int
    @Published private(set) var longestLosingStreak: Int
    @Published private(set) var totalTokensEarned: Int
    @Published private(set) var totalTokensSpent: Int

    private var currentLosingStreak: Int
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        totalFlips          = defaults.integer(forKey: "stats.totalFlips")
        totalHeads          = defaults.integer(forKey: "stats.totalHeads")
        totalTails          = defaults.integer(forKey: "stats.totalTails")
        longestLosingStreak = defaults.integer(forKey: "stats.longestLosingStreak")
        totalTokensEarned   = defaults.integer(forKey: "stats.totalTokensEarned")
        totalTokensSpent    = defaults.integer(forKey: "stats.totalTokensSpent")
        currentLosingStreak = defaults.integer(forKey: "stats.currentLosingStreak")
    }
    
    //legacy backfill to seed stats from pre-existing game state.
    func backfillIfNeeded(
        legacyTotalFlips: Int?,
        legacyHeads: Int?,
        legacyTails: Int?,
        legacyLongestLosingStreak: Int?,
        legacyTokensEarned: Int?,
        legacyTokensSpent: Int?
    ) {
        // No "only once" guard: this is safe to run multiple times because we only ever
        // raise values when the legacy snapshot is higher than what we already have.

        if let v = legacyTotalFlips, v > 0, v > totalFlips {
            totalFlips = v
        }
        if let v = legacyHeads, v > 0, v > totalHeads {
            totalHeads = v
        }
        if let v = legacyTails, v > 0, v > totalTails {
            totalTails = v
        }
        if let v = legacyLongestLosingStreak, v > 0, v > longestLosingStreak {
            longestLosingStreak = v
        }
        if let v = legacyTokensEarned, v > 0, v > totalTokensEarned {
            totalTokensEarned = v
        }
        if let v = legacyTokensSpent, v > 0, v > totalTokensSpent {
            totalTokensSpent = v
        }

        persist()
    }

    // MARK: - Derived ratios

    var totalHeadsAndTails: Int {
        totalHeads + totalTails
    }

    /// 0.5 default when you have no flips yet
    var headsShare: Double {
        let total = totalHeadsAndTails
        guard total > 0 else { return 0.5 }
        return Double(totalHeads) / Double(total)
    }

    var tailsShare: Double {
        1.0 - headsShare
    }

    // MARK: - Mutators

    /// `isCorrect` = whether this flip matched the user's chosen side
    func recordFlip(isHeads: Bool, isCorrect: Bool?) {
        totalFlips &+= 1

        if isHeads {
            totalHeads &+= 1
        } else {
            totalTails &+= 1
        }

        if let ok = isCorrect {
            if ok {
                currentLosingStreak = 0
            } else {
                currentLosingStreak &+= 1
                if currentLosingStreak > longestLosingStreak {
                    longestLosingStreak = currentLosingStreak
                }
            }
        }

        persist()
    }

    func addTokensEarned(_ amount: Int) {
        guard amount > 0 else { return }
        totalTokensEarned &+= amount
        persist()
    }

    func addTokensSpent(_ amount: Int) {
        guard amount > 0 else { return }
        totalTokensSpent &+= amount
        persist()
    }

    // MARK: - Persistence

    private func persist() {
        defaults.set(totalFlips,          forKey: "stats.totalFlips")
        defaults.set(totalHeads,          forKey: "stats.totalHeads")
        defaults.set(totalTails,          forKey: "stats.totalTails")
        defaults.set(longestLosingStreak, forKey: "stats.longestLosingStreak")
        defaults.set(currentLosingStreak, forKey: "stats.currentLosingStreak")
        defaults.set(totalTokensEarned,   forKey: "stats.totalTokensEarned")
        defaults.set(totalTokensSpent,    forKey: "stats.totalTokensSpent")
    }
}
