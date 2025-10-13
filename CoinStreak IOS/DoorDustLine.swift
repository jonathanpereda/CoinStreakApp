import SwiftUI

struct DoorDustLine: View {
    enum Orientation { case vertical, horizontal }

    let trigger: Date
    let orientation: Orientation
    let duration: Double
    let count: Int
    let spread: CGFloat
    let downDrift: CGFloat
    let thickness: CGFloat
    let baseColor: Color
    let shadowColor: Color

    var body: some View {
        TimelineView(.animation) { timeline in
            // Progress based SOLELY on the trigger timestamp.
            let elapsed = max(0, timeline.date.timeIntervalSince(trigger))
            let t = CGFloat(min(elapsed / max(duration, 0.001), 1))

            Canvas { ctx, size in
                let W = size.width, H = size.height
                let cx = W * 0.5, cy = H * 0.5

                // Seeded RNG per trigger (stable pattern during a burst)
                // Compute milliseconds as UInt64 and mod in integer space to avoid Double precision issues.
                let ms = UInt64(max(0, trigger.timeIntervalSince1970 * 1000))
                var seed: UInt64 = ms % 9_223_372_036_854_775_807
                @inline(__always) func rand01() -> CGFloat {
                    seed = 2862933555777941757 &* seed &+ 3037000493
                    let x = Double((seed >> 33) & 0xFFFFFFFF)
                    return CGFloat(x / Double(UInt32.max))
                }


                // Motion + fade
                let ease = cubicOut(t)           // positional progress
                let fade = pow(1 - t, 1.6)       // alpha falloff

                // (Debug seam line — keep nonzero while testing)
                if thickness > 0 {
                    var core = Path()
                    if orientation == .vertical {
                        core.addRoundedRect(in: CGRect(x: cx - thickness/2, y: 0, width: thickness, height: H),
                                            cornerSize: .init(width: thickness/2, height: thickness/2))
                    } else {
                        core.addRoundedRect(in: CGRect(x: 0, y: cy - thickness/2, width: W, height: thickness),
                                            cornerSize: .init(width: thickness/2, height: thickness/2))
                    }
                    ctx.fill(core, with: .color(baseColor.opacity(0.28 * fade)))
                }

                // Particles along the full line (top→bottom for vertical)
                for i in 0..<max(1, count) {
                    let u = (CGFloat(i) + 0.5) / CGFloat(max(count, 1))

                    // Start positions
                    var px = cx, py = cy
                    switch orientation {
                    case .vertical:
                        px = cx
                        py = u * H + (rand01() - 0.5) * 8
                    case .horizontal:
                        px = u * W + (rand01() - 0.5) * 8
                        py = cy
                    }

                    // Velocity (perpendicular spread + slight drift along the line)
                    var vx: CGFloat = 0, vy: CGFloat = 0
                    if orientation == .vertical {
                        // centered lateral jitter in [-spread, +spread], biased to be smaller more often
                        let jitter: CGFloat = (rand01() - 0.5)         // uniform in [-0.5, +0.5]
                        let soft: CGFloat   = 0.6 * jitter + 0.4 * jitter * abs(jitter)
                        //   soft compresses big values so most puffs stay close to center
                        vx = soft * (spread * (0.8 + 0.2 * rand01()))  // small symmetric push
                        vy = downDrift * (0.35 + 0.65 * rand01())      // gentle downward drift

                    } else {
                        let dir: CGFloat = rand01() < 0.5 ? -1 : 1
                        vy = dir * spread * (0.45 + 0.55 * rand01())
                        vx = downDrift * (0.35 + 0.65 * rand01())
                    }

                    // Current position
                    let x = px + vx * ease
                    let y = py + vy * ease

                    // BIG puffs + slight shrink + fade
                    let r0: CGFloat = 9.5 + rand01() * 5.0
                    let r  = max(0.8, r0 * (0.86 + 0.14 * (1 - t)))
                    let a  = Double(0.95 * fade) * (0.70 + 0.30 * Double(rand01()))

                    let circle = Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2*r, height: 2*r))
                    ctx.fill(circle, with: .color(baseColor.opacity(a)))
                    ctx.fill(circle, with: .color(shadowColor.opacity(a * 0.55)))
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

private func cubicOut(_ x: CGFloat) -> CGFloat {
    let u = min(max(x, 0), 1)
    let inv = 1 - u
    return 1 - inv * inv * inv
}

extension DoorDustLine {
    static func seamBurst(trigger: Date,
                          orientation: Orientation = .vertical) -> DoorDustLine {
        DoorDustLine(
            trigger: trigger,
            orientation: orientation,
            duration: 1.0,
            count: 80,
            spread: 110,
            downDrift: 20,
            thickness: 0,                  // For testing
            baseColor: .white.opacity(0.44),             // fully opaque while testing
            shadowColor: .black.opacity(0.2)
        )
    }
}
