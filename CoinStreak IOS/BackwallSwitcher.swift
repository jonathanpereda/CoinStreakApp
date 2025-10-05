//
//  BackwallSwitcher.swift
//  CoinStreak
//
//  Created by Jonathan Pereda on 10/5/25.
//

import SwiftUI
import Combine

/// Backwall that reveals the next scene by first swinging on the TOP-RIGHT corner,
/// then the hinge breaks and it drops straight down offscreen.
/// Time-driven via a Timer publisher (no TimelineView needed).
struct BackwallSwitcher: View {
    let tierName: String
    var onDropImpact: ((Date) -> Void)? = nil

    // MARK: - Tuning
    private let perspective: CGFloat = 0.55

    // Master timeline duration (seconds)
    private let totalDur: Double = 2.2

    // Phase proportions within the master timeline (fractions of 0...1)
    private let swingFrac: Double   = 0.55   // portion of totalDur used by swing
    private let holdFrac: Double    = 0.02   // extra hold after swing before drop
    private let overlapFrac: Double = 0.18   // set >0 if you WANT drop to start before swing ends

    // Swing targets (hinge at top-right)
    private let swingZDeg: Double   = -40    // clockwise in-plane (right side dips)
    private let swingXDeg: Double   = 14     // forward tilt during swing
    private let swingYawDeg: Double = -6     // subtle yaw flutter
    private let swingSagPx: CGFloat = 18     // downward sag while swinging

    // Drop targets
    private let dropTiltXDeg: Double   = 32  // forward tilt continues during drop
    private let fadeTail: Double       = 0.14
    private let dropOvershoot: CGFloat = 200 // extra px to fully clear offscreen

    // MARK: - State
    @State private var currentImage: String
    @State private var outgoingImage: String?

    // Time-driven master timeline: 0 → 1 over totalDur
    @State private var animStart: Date? = nil
    @State private var masterT: Double = 0.0

    // First render guard
    @State private var bootstrapped = false

    // Timer driving the animation ticks (~120fps)
    private let tick = Timer.publish(every: 1.0 / 120.0, on: .main, in: .common).autoconnect()

    init(tierName: String, onDropImpact: ((Date) -> Void)? = nil) {
        self.tierName = tierName
        self.onDropImpact = onDropImpact
        _currentImage = State(initialValue: BackwallSwitcher.imageName(for: tierName))
    }


    var body: some View {
        GeometryReader { geo in
            let H = geo.size.height

            ZStack {
                // New/active backwall always behind.
                Image(currentImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .ignoresSafeArea()

                // Outgoing wall performs swing → (hold) → drop
                if let out = outgoingImage {
                    // ---- Phase boundaries (fractions of timeline) ----
                    let swingEnd    = min(1.0, swingFrac)
                    let holdEnd     = min(1.0, swingEnd + max(0, holdFrac))

                    // If you WANT overlap, set overlapFrac > 0; otherwise we clamp to holdEnd.
                    let dropStartRaw = max(0.0, swingEnd - max(0, overlapFrac))
                    let dropStart    = max(holdEnd, dropStartRaw)
                    let dropEnd      = 1.0

                    // ---- Per-phase progress (0..1), with hard gating ----
                    let swingP  = easeInOutCubic(segProgress(masterT, 0.0,     swingEnd))
                    let dropP   = easeInPow(     segProgress(masterT, dropStart, dropEnd), 3.6)

                    // ---- Compose transforms ----
                    let zDeg = swingZDeg * swingP
                    let xDeg = (swingXDeg * swingP) + (dropTiltXDeg * dropP)
                    let yaw  = swingYawDeg * sin(swingP * .pi) * (1 - 0.3 * swingP)
                    let sag  = swingSagPx * CGFloat(swingP)
                    let fall = CGFloat(dropP) * (H + dropOvershoot)

                    Image(out)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .ignoresSafeArea()
                        .compositingGroup()
                        .rotationEffect(.degrees(zDeg), anchor: .topTrailing) // in-plane swing
                        .rotation3DEffect(.degrees(xDeg),
                                          axis: (x: 1, y: 0, z: 0),
                                          anchor: .topTrailing,
                                          perspective: perspective)
                        .rotation3DEffect(.degrees(yaw),
                                          axis: (x: 0, y: 1, z: 0),
                                          anchor: .topTrailing,
                                          perspective: perspective)
                        .offset(y: sag + fall)
                        .opacity(1.0 - fadeTail * max(0, (dropP - 0.75) / 0.25))
                        .zIndex(1)
                }
            }
            // Drive masterT from real time while an animation is active
            .onReceive(tick) { now in
                guard let start = animStart else { return }
                let elapsed = now.timeIntervalSince(start)
                let t = max(0, min(1, elapsed / totalDur))
                if t != masterT { masterT = t }
            }
        }
        .onAppear { bootstrapped = true }
        .onChange(of: tierName) { _, newTier in
            let next = BackwallSwitcher.imageName(for: newTier)
            guard next != currentImage else { return }

            // First mount / restore: no animation.
            guard bootstrapped else {
                currentImage = next
                outgoingImage = nil
                masterT = 0
                animStart = nil
                bootstrapped = true
                return
            }

            // Stage: NEXT goes behind, animate PREV on top.
            let prev = currentImage
            currentImage = next
            outgoingImage = prev
            masterT = 0
            animStart = Date()
            
            SoundManager.shared.play("scrape_1")

            // Hard cleanup after totalDur (independent of SwiftUI implicit animations)
            DispatchQueue.main.asyncAfter(deadline: .now() + totalDur) {
                
                SoundManager.shared.play("thud_2")
                
                //Dust
                let impact = Date()
                onDropImpact?(impact)
                
                masterT = 1.0
                outgoingImage = nil
                animStart = nil
                // reset masterT so the next run starts from 0 (not visible)
                DispatchQueue.main.async { masterT = 0 }
            }
        }
    }
}

// MARK: - Helpers

private func segProgress(_ t: Double, _ a: Double, _ b: Double) -> Double {
    // 0..1 progress of t through [a,b], clamped
    guard b > a else { return t >= b ? 1 : 0 }
    return min(1, max(0, (t - a) / (b - a)))
}

private func easeInOutCubic(_ t: Double) -> Double {
    if t < 0.5 { return 4 * t * t * t }
    let u = -2 * t + 2
    return 1 - (u * u * u) / 2
}

private func easeInPow(_ t: Double, _ p: Double) -> Double {
    let tt = min(1, max(0, t))
    return pow(tt, p) // p>1 → stronger ease-in (slower start)
}

// Map tier → asset name. Adjust if you change naming.
private extension BackwallSwitcher {
    static func imageName(for tier: String) -> String {
        switch tier {
        case "Starter": return "starter_backwall"
        case "Map1":    return "map1_backwall"
        case "Map2":    return "map2_backwall"
        case "Map3":    return "map3_backwall"
        case "Map4":    return "map4_backwall"
        default:        return "starter_backwall"
        }
    }
}
