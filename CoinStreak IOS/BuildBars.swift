//
//  BuildBars.swift
//  CoinStreak
//
//  Created by Jonathan Pereda on 10/4/25.
//
import Foundation

/// Tuning for end-of-streak-only rewards.
struct ProgressTuning {
    // Coin success probability (chosen face).
    let p: Double
    // Reward curve parameters: r(s) = s^γ * c^(s-1), with c < 1/p to keep sums finite.
    let c: Double
    let gamma: Double

    private var q: Double { 1 - p }

    /// Reward for a streak length s (s >= 1).
    func r(_ s: Int) -> Double {
        pow(Double(s), gamma) * pow(c, Double(s - 1))
    }

    /// E[r(L)] where L ~ Geometric(q) on {1,2,...} with P(L=ℓ) = q * p^(ℓ-1).
    /// sum until terms are negligible; c must be < 1/p or this diverges.
    func expected_r_of_L(tol: Double = 1e-12, maxL: Int = 10_000) -> Double {
        precondition(c < 1.0 / p, "Reward grows too fast: require c < 1/p")
        var acc = 0.0
        for l in 1...maxL {
            let pmf  = q * pow(p, Double(l - 1))
            let term = pmf * r(l)
            acc += term
            if term < tol && l > 64 { break }
        }
        return acc
    }

    /// Expected progress per flip when awarding ONLY at end of each streak.
    func expectedPerFlip_EndOnly() -> Double {
        p * q * expected_r_of_L()
    }

    /// Convert desired average flips N to a bar total B (integer).
    func barSize(forTargetFlips N: Double) -> Int {
        let epf = expectedPerFlip_EndOnly()
        return max(1, Int((N * epf).rounded()))
    }
}

/// Define tier intents in "target flips", then generate fixed bar totals at launch.
struct ProgressTierSpec {
    let name: String
    let targetFlips: Double
}
struct ProgressTier {
    let name: String
    let barTotal: Int
    let targetFlips: Double
}

func buildTiers(tuning: ProgressTuning, specs: [ProgressTierSpec]) -> [ProgressTier] {
    specs.map { spec in
        ProgressTier(name: spec.name,
                     barTotal: tuning.barSize(forTargetFlips: spec.targetFlips),
                     targetFlips: spec.targetFlips)
    }
}

// --- Example wiring ---
let tuning = ProgressTuning(p: 0.5, c: 1.7, gamma: 0.7)

/*

let tierSpecs: [ProgressTierSpec] = [
    .init(name: "Bronze",   targetFlips: 100),
    .init(name: "Silver",   targetFlips: 140),
    .init(name: "Gold",     targetFlips: 200),
    .init(name: "Platinum", targetFlips: 280),
    .init(name: "Mythic",   targetFlips: 380),
]

// Compute once at launch and freeze:
let tiers = buildTiers(tuning: tuning, specs: tierSpecs)
// -> use `tiers[i].barTotal` in your UI/logic; display names from `tiers[i].name`

*/
