//
//  ContentView.swift
//  CoinStreak IOS
//
//  Created by Jonathan Pereda on 10/3/25.
//

import SwiftUI

// MARK: - Animatable coin that swaps face based on the live angle
struct FlippingCoin: View, Animatable {
    // SwiftUI interpolates this every frame during animation
    var angle: Double                     // flight angle: 0 → N*180
    var baseFace: String                  // "Heads" at takeoff (or "Tails")
    var width: CGFloat                    // rendered width of the coin
    var position: CGPoint                 // center position on screen

    // Animatable conformance
    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    private func flipped(_ s: String) -> String { s == "Heads" ? "Tails" : "Heads" }
    private func imageName(for face: String) -> String { face == "Tails" ? "coin_tails" : "coin_heads" }

    var body: some View {
        // Normalize 0..360
        let a = (angle.truncatingRemainder(dividingBy: 360) + 360)
                    .truncatingRemainder(dividingBy: 360)

        // Face rule: show flipped from 90° up to 270° (back-facing half)
        let showFlipped = (a >= 90 && a < 270)
        let face = showFlipped ? (baseFace == "Heads" ? "Tails" : "Heads") : baseFace

        // - Break total angle into half-turns (180° blocks)
        let halfIndex = Int(floor(a / 180))                 // 0 for 0..179, 1 for 180..359
        let within = a.truncatingRemainder(dividingBy: 180) // 0..180 within this half
        // Fold to 0..90..0 triangle wave
        let folded = (within <= 90) ? within : (180 - within)
        // Alternate sign each half-turn so motion stays continuous: +folded, -folded, +folded, ...
        let renderedAngle = (halfIndex % 2 == 0) ? folded : -folded

        return Image(face == "Tails" ? "coin_tails" : "coin_heads")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: width)
            .position(position)
            .compositingGroup()
            .rotation3DEffect(.degrees(renderedAngle),   // 👈 use folded angle, not raw
                              axis: (x: 0, y: 1, z: 0),
                              perspective: 0.7)
            .animation(nil, value: face)                 // hard swap (no cross-fade)
    }
}

struct ContentView: View {
    
    @State private var streak = 0;
    @State private var curState = "Heads";
    
    // animation state
    @State private var y: CGFloat = 0        // 0 = on ledge
    @State private var scale: CGFloat = 1.0
    @State private var shadow: CGFloat = 12
    
    private let coinDiameterPct: CGFloat = 0.565   // coin diameter as % of screen width
    private let ledgeTopYPct: CGFloat = 0.97      // ledge top as % of screen height
    private let coinRestOverlapPct: CGFloat = 0.06// how much the coin overlaps “into” the ledge

    @State private var isFlipping = false
    @State private var baseFaceAtLaunch = "Heads"
    @State private var flightAngle: Double = 0

    
    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = geo.size.height
            let coinD = W * coinDiameterPct
            let coinR = coinD / 2
            // center Y so the coin “sits” on the ledge line, with a bit of overlap
            let coinCenterY = H * ledgeTopYPct - coinR * (1 - coinRestOverlapPct)
            
            ZStack {
                Color.black.ignoresSafeArea() // fallback fill (prevents any gap)
                Image("game_background")
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .ignoresSafeArea()
                
                FlippingCoin(angle: flightAngle,
                             baseFace: baseFaceAtLaunch,
                             width: coinD,
                             position: .init(x: W/2, y: coinCenterY))
                .offset(y: y)
                .scaleEffect(scale)
                .shadow(radius: shadow, y: shadow)
                .contentShape(Rectangle())
                .onTapGesture { flipCoin()
                }
            }
            .ignoresSafeArea()
        }
    }
    // MARK: - Flip logic
        func flipCoin() {
            guard !isFlipping else { return }

            let desired = Bool.random() ? "Heads" : "Tails"

            // Capture takeoff state
            baseFaceAtLaunch = curState
            isFlipping = true

            // Choose # of half-turns so final parity matches desired face
            let needOdd = (desired != baseFaceAtLaunch)       // odd half-turns -> flip overall
            let halfTurns = (needOdd ? [7, 9, 11] : [6, 8, 10]).randomElement()!

            // Timing & "gravity"
            let total: Double = 0.85
            let upDur = total * 0.38
            let downDur = total - upDur
            let jump: CGFloat = max(180, UIScreen.main.bounds.height * 0.32)

            // Reset flight angle and animate smoothly to target;
            // FlippingCoin will receive interpolated angles each frame.
            flightAngle = 0
            withAnimation(.linear(duration: total)) {
                flightAngle = Double(halfTurns) * 180
            }

            // Up (ease-out)
            withAnimation(.easeOut(duration: upDur)) {
                y = -jump
                scale = 0.98
                shadow = 3
            }
            // Down (ease-in)
            DispatchQueue.main.asyncAfter(deadline: .now() + upDur) {
                withAnimation(.easeIn(duration: downDur)) {
                    y = 0
                    scale = 1
                    shadow = 12
                }
            }

            // Land: commit result & streak; normalize for next flip
            DispatchQueue.main.asyncAfter(deadline: .now() + total) {
                curState = desired
                if desired == baseFaceAtLaunch { streak += 1 } else { streak = 1 }
                baseFaceAtLaunch = desired
                isFlipping = false
                flightAngle = 0
            }
        }
    }


#Preview {
    ContentView()
}
