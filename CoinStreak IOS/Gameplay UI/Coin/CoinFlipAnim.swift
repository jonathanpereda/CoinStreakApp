import SwiftUI
import Foundation
import UIKit


// MARK: - COIN FLIP ANIM
///(uses coin_flip_HT / coin_flip_TH atlases)

enum CoinSide: String { case H = "Heads", T = "Tails" }

struct SpriteFlipPlan: Equatable {
    let startFace: CoinSide       // "Heads" or "Tails"
    let endFace:   CoinSide
    let halfTurns: Int            // number of half flips (each = one atlas run)
    let startTime: Date
    let duration:  Double         // seconds
}

/// Frame-naming helper: frames are named coin_HT_0001 ... coin_TH_0036
private func atlasFrameName(prefix: String, idx1based: Int) -> String {
    String(format: "%@_%04d", prefix, idx1based)
}

/// Build the alternating atlas run list using real frame prefixes
private func buildAtlasRun(start: CoinSide, halfTurns: Int) -> [(prefix: String, frameCount: Int, skipFirst: Bool)] {
    var list: [(String, Int, Bool)] = []
    var cur = start
    for i in 0..<halfTurns {
        let next: CoinSide = (cur == .H) ? .T : .H
        // Use frame name prefixes
        let prefix = (cur == .H && next == .T) ? "coin_HT" : "coin_TH"
        list.append((prefix, 36, i > 0 /* skip first frame after the first run */))
        cur = next
    }
    return list
}

/// Given a flip plan and "now", compute which image name we should be on.
func spriteFrameFor(plan: SpriteFlipPlan, now: Date) -> String {
    let elapsed = max(0, now.timeIntervalSince(plan.startTime))
    // Clamp 0...duration
    let t = min(elapsed, plan.duration)
    let atlases = buildAtlasRun(start: plan.startFace, halfTurns: plan.halfTurns)

    // Total frames accounting for skips
    let totalFrames = atlases.reduce(0) { $0 + $1.frameCount - ($1.skipFirst ? 1 : 0) }
    // Progress -> frame index in [0, totalFrames-1]
    let idx = Int(round((t / max(plan.duration, 0.0001)) * Double(totalFrames - 1)))

    // Walk atlases to find concrete (atlas, localIndex)
    var remaining = idx
    for (prefix, count, skipFirst) in atlases {
        let effective = count - (skipFirst ? 1 : 0)
        if remaining < effective {
            // local 1-based index inside this atlas sequence
            let local1based = remaining + (skipFirst ? 2 : 1)
            return atlasFrameName(prefix: prefix, idx1based: local1based)
        } else {
            remaining -= effective
        }
    }
    // Shouldn’t happen, but fall back to the final idle
    let finalPrefix = (plan.endFace == .H) ? "coin_flip_TH" : "coin_flip_HT"
    return atlasFrameName(prefix: finalPrefix, idx1based: 36)
}

/// Static image names for rest frames provided: coin_H / coin_T
func staticFaceImage(_ face: CoinSide) -> String { face == .H ? "coin_H" : "coin_T" }

/// Small per-asset visual tweaks because the new images have a larger alpha box.
struct CoinVisualTweak {
    let scale: CGFloat   // 1.0 = no change
    let nudgeY: CGFloat  // +down / -up, in points
}
let NewCoinTweak = CoinVisualTweak(scale: 2.7, nudgeY: -58) // adjust to taste

/// A view that shows either a static coin image, or a frame from the current sprite flip.
/// It does not control Y/scale/jiggle—that remains owned by the existing state/animations.
struct SpriteCoinImage: View {
    let plan: SpriteFlipPlan?
    let idleFace: CoinSide         // the face to show when plan is nil
    let width: CGFloat
    let position: CGPoint

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date
            let name: String = {
                if let p = plan {
                    return spriteFrameFor(plan: p, now: now)
                } else {
                    return staticFaceImage(idleFace)
                }
            }()
            Image(name)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: width * NewCoinTweak.scale)
                .position(x: position.x, y: position.y + NewCoinTweak.nudgeY)
                .drawingGroup()
        }
    }
}

// t: 0 → 1
func settleAnglesSide(_ t: Double) -> (xRock: Double, yRock: Double) {
    // Slower decay and clear side tilt
    let decay: Double = 6.8
    let e = exp(-decay * t)

    let yAmp: Double = 15.0   // ← dominant: left/right tilt (Y axis)
    let xAmp: Double = 1.0    // ← subtle front/back (X axis) so it doesn’t look flat

    // Slight detune + phase gives natural feel
    let y = yAmp * sin(2 * Double.pi * 3.0 * t + Double.pi/4) * e
    let x = xAmp * sin(2 * Double.pi * 3.4 * t) * e
    return (x, y)
}

struct SettleWiggle: AnimatableModifier {
    var t: Double
    var animatableData: Double {
        get { t }
        set { t = newValue }
    }
    func body(content: Content) -> some View {
        let ang = settleAnglesSide(t)   // (xRock, yRock)
        content
            // subtle front/back
            .rotation3DEffect(.degrees(ang.xRock),
                              axis: (x: 1, y: 0, z: 0),
                              anchor: .bottom,
                              perspective: 0.45)
            // dominant left/right rock
            .rotation3DEffect(.degrees(ang.yRock),
                              axis: (x: 0, y: 1, z: 0),
                              anchor: .bottom,
                              perspective: 0.45)
    }
}

func bounceY(_ t: Double) -> Double {
    // t: 0→1; return NEGATIVE (upwards) pixels; 0 = rest
    // Using |sin| so each lobe is an “upward tap”, then back to 0.
    let decay = 6.5         // larger = dies faster
    let freq  = 3.0         // ~3 taps across t∈[0,1]
    let amp   = 10.0        // max height in px for first tap

    let envelope = exp(-decay * t)
    let pulses   = abs(sin(2 * Double.pi * freq * t))  // 0→1→0 lobes
    return -(amp * envelope * pulses)                  // negative y = up
}

struct SettleBounce: AnimatableModifier {
    var t: Double                        // 0→1
    var animatableData: Double {
        get { t }
        set { t = newValue }
    }
    func body(content: Content) -> some View {
        content.offset(y: CGFloat(bounceY(t)))
    }
}

// Clamp helper
private func clamp<T: Comparable>(_ v: T, _ lo: T, _ hi: T) -> T { max(lo, min(hi, v)) }

// Map a 0..~1.6 "impulse" to flight parameters.
// If impulse is nil, we return your current default feel.
func flightParams(
    impulse: Double?,
    needOdd: Bool,
    screenH: CGFloat
) -> (halfTurns: Int, total: Double, jump: CGFloat, isSuper: Bool) {

    // Defaults = your old random-tap behavior
    let baseHalfTurnsRangeEven = [6, 8, 10]
    let baseHalfTurnsRangeOdd  = [7, 9, 11]
    var total = 0.85
    let defaultJump = max(180, UIScreen.main.bounds.height * 0.32)

    // No swipe → original feel (and not "super")
    guard let rawPower = impulse else {
        let halfTurns = (needOdd ? baseHalfTurnsRangeOdd : baseHalfTurnsRangeEven).randomElement()!
        return (halfTurns, total, CGFloat(defaultJump), false)
    }

    // --- Power shaping ---
    // Use *raw* (unclamped) power to detect "super"; clamp for normal feel.
    let norm = max(0.0, rawPower) / 1.6        // 1.0 ≈ old "max"
    let isSuper = norm > 2                   // threshold to break ceiling (tune as you like)
    let superT  = clamp((norm - 1.05) / 0.45, 0.0, 1.0) // ramp 0→1 up to ~1.50× old

    let pClamped = clamp(rawPower, 0.0, 1.6)
    let shaped = pow(pClamped / 1.6, 0.85)     // raise exponent for less sensitivity

    // --- Duration (normal lane) ---
    total = 0.58 + (1.05 - 0.58) * shaped

    // --- Jump (normal lane) ---
    var jump = CGFloat(Double(defaultJump) * (0.90 + (1.40 - 0.90) * shaped))

    // --- Half-turns (normal lane) ---
    let minTurns = needOdd ? 5 : 4
    var maxTurns = needOdd ? 11 : 12
    var halfTurns = Int(round(Double(minTurns) + Double(maxTurns - minTurns) * shaped))

    // --- Super swipe lane: break the ceiling gracefully ---
    if isSuper {
        let superJumpTarget = screenH * 0.86
        jump = CGFloat(Double(jump) * (1.0 - superT) + Double(superJumpTarget) * superT)
        total += 0.10 * Double(superT)         // extra airtime
        maxTurns += 2                          // a bit more spin headroom
        halfTurns = Int(round(Double(halfTurns) + 2.0 * Double(superT)))
    }

    // Parity fix
    if (halfTurns % 2 == 1) != needOdd {
        halfTurns += (halfTurns <= maxTurns ? 1 : -1)
    }
    halfTurns = clamp(halfTurns, minTurns, maxTurns)

    return (halfTurns, total, jump, isSuper)
}


