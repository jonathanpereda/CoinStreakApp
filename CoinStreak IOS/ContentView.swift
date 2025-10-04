//
//  ContentView.swift
//  CoinStreak IOS
//
//  Created by Jonathan Pereda on 10/3/25.
//

import SwiftUI


// MARK: - Animatable coin that swaps face based on the live angle
struct FlippingCoin: View, Animatable {
    // SwiftUI interpolates this every frame
    var angle: Double                 // 0 → targetAngle during flight
    var targetAngle: Double           // (kept for completeness; not used here)
    var baseFace: String              // "Heads" at takeoff (or "Tails")
    var width: CGFloat
    var position: CGPoint

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    private func flipped(_ s: String) -> String { s == "Heads" ? "Tails" : "Heads" }
    private func imageName(for face: String) -> String { face == "Tails" ? "coin_tails" : "coin_heads" }

    private let tiltMag: CGFloat = 0.20      // base axis tilt magnitude
    private let backScale: CGFloat = 0.14    // ↓ reduce tilt on back half (90°–270°)
    private let pitchX: Double = -6          // fixed camera pitch (top slightly away)
    private let perspective: CGFloat = 0.51  // 0.5–0.7 looks natural

    var body: some View {
        // Normalize to [0, 360)
        let a = (angle.truncatingRemainder(dividingBy: 360) + 360)
                .truncatingRemainder(dividingBy: 360)

        // Back side visible between 90° and <270° → swap face + flip bitmap
        let seeingBack = (a >= 90 && a < 270)
        let face = seeingBack ? flipped(baseFace) : baseFace
        let flipX: CGFloat = seeingBack ? -1 : 1

        // --- Signed axis tilt with attenuation on the back half ---
        // cos(a) gives + on 0–90, − on 90–270, + on 270–360 (smooth sign flip)
        let rad = a * .pi / 180
        let mag = seeingBack ? backScale : 1        // attenuate only on the back
        let signedTilt: CGFloat = tiltMag * mag * CGFloat(cos(rad))

        // Normalize axis (critical)
        let vx = signedTilt, vy: CGFloat = 1
        let len = sqrt(vx*vx + vy*vy)
        let ax = vx / max(len, 0.0001), ay = vy / max(len, 0.0001)

        return Image(imageName(for: face))
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: width)
            .compositingGroup()

            // Prevent mirrored look when back is showing
            .scaleEffect(x: flipX, y: 1, anchor: .center)

            // Fixed camera pitch (keep consistent with your artwork perspective)
            .rotation3DEffect(.degrees(pitchX), axis: (x: 1, y: 0, z: 0), anchor: .center)

            // Main rotation around normalized, sign-flipping axis (center pivot)
            .rotation3DEffect(.degrees(a),
                              axis: (x: ax, y: ay, z: 0),
                              anchor: .center,
                              perspective: perspective)

            // Position AFTER rotations so the pivot stays at the coin’s center
            .position(position)

            // Hard swap on face change (no cross-fade)
            .animation(nil, value: face)
    }
}



struct ContentView: View {
    
    @StateObject private var store = FlipStore()
    
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
    @State private var flightTarget: Double = 0
    
    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = geo.size.height
            let coinD = W * coinDiameterPct
            let coinR = coinD / 2
            // center Y so the coin “sits” on the ledge line, with a bit of overlap
            let coinCenterY = H * ledgeTopYPct - coinR * (1 - coinRestOverlapPct)
            
            let groundY = H * ledgeTopYPct

            // How high the coin is (0 = on ground, 1 = apex)
            let jumpPx   = max(180, H * 0.32)
            let height01 = max(0, min(1, -y / jumpPx))   // t

            // ---- Shadow geometry (rest vs apex) ----
            // You already tuned these — keep your values here
            let baseShadowW: CGFloat = coinD * 1.00      // width at rest
            let minShadowW:  CGFloat = coinD * 0.40      // width at apex

            let baseShadowH: CGFloat = coinD * 0.60      // height at rest  (your current value)
            let minShadowH:  CGFloat = coinD * 0.22      // height at apex  (tweak to taste)

            // If you want width to shrink more than height, you can bias t for height:
            let heightShrinkBias: CGFloat = 0.75         // 0.0..1.0 (smaller = less shrink on height)
            let th = min(1, height01 / max(heightShrinkBias, 0.0001))

            // Linear interpolate
            let shadowW = baseShadowW + (minShadowW - baseShadowW) * height01
            let shadowHcur = baseShadowH + (minShadowH - baseShadowH) * th

            // Visuals
            let shadowOpacity = 0.28 * (1.0 - 0.65 * height01)
            let shadowBlur    = 6.0 + 10.0 * height01

            // Place ellipse center so its *top* sits on the ledge
            let shadowYOffsetTweak: CGFloat = -157       // keep your tuned offset
            let shadowY_centerLocked = (groundY + baseShadowH / 2) + shadowYOffsetTweak

            
            
            ZStack {
                Color.black.ignoresSafeArea() // fallback fill (prevents any gap)
                Image("game_background")
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .ignoresSafeArea()
                
                
                Ellipse()
                    .fill(Color.black.opacity(shadowOpacity))
                    .frame(width: shadowW, height: shadowHcur)
                    .blur(radius: shadowBlur)
                    .position(x: W/2, y: shadowY_centerLocked)
                
                
                FlippingCoin(angle: flightAngle,
                             targetAngle: flightTarget,
                             baseFace: baseFaceAtLaunch,
                             width: coinD,
                             position: .init(x: W/2, y: coinCenterY))
                    .offset(y: y)
                    .scaleEffect(scale)
                    .contentShape(Rectangle())
                    .onTapGesture { flipCoin()
                        
                }
                
                #if DEBUG
                Button("DEV: Reset Choice") {
                    store.chosenFace = nil
                    store.currentStreak = 0
                }
                .padding(8)
                .background(.red.opacity(0.2))
                .cornerRadius(8)
                #endif
                
                HStack{
                    Text("Streak: \(store.currentStreak)")
                        .font(.headline)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                    Spacer()
                }
                
            }
            .ignoresSafeArea()
            .overlay {
                if store.chosenFace == nil {
                    ChooseFaceScreen(
                        store: store,
                        groundY: groundY,          // <- pass the actual ledge Y you use in the game
                        screenSize: geo.size       // <- so the chooser uses the same W/H
                    )
                    .frame(width: geo.size.width, height: geo.size.height)  // lock to the same box
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(1000)
                }
            }




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
        
        
        flightAngle = 0
        flightTarget = Double(halfTurns) * 180
        withAnimation(.linear(duration: total)) {
            flightAngle = flightTarget
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
            withAnimation(.easeOut(duration: 0.10)) {
                // brief widen & darken
                // (we can fake it by nudging y slightly negative & letting height01 = 0 react)
            }
        }

        // Land: commit result & streak; normalize for next flip
        DispatchQueue.main.asyncAfter(deadline: .now() + total) {
            curState = desired
            if let faceVal = Face(rawValue: desired) {
                    store.recordFlip(result: faceVal)
            }
            baseFaceAtLaunch = desired
            isFlipping = false
            flightAngle = 0
            flightTarget = 0
        }
    }
}


#if DEBUG
import SwiftUI

struct CoinTiltBackScaleTuner: View {
    @State private var angle: Double = 0                   // 0…360
    @State private var tiltMag: CGFloat = 0.34             // base tilt magnitude
    @State private var backScale: CGFloat = 0.86           // scale tilt on back (90–270)
    @State private var pitchX: Double = -6                 // camera pitch
    @State private var perspective: CGFloat = 0.60         // 0.45–0.8
    private let demoWidth: CGFloat = 240

    private func imageName(_ face: String) -> String { face == "Tails" ? "coin_tails" : "coin_heads" }

    var body: some View {
        VStack(spacing: 18) {
            // Normalize angle to [0, 360)
            let a = (angle.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
            let seeingBack = (a >= 90 && a < 270)
            let face = seeingBack ? "Tails" : "Heads"
            let flipX: CGFloat = seeingBack ? -1 : 1

            // Signed tilt with attenuation on back half
            let rad = a * .pi / 180
            let mag = seeingBack ? backScale : 1
            let signedTilt: CGFloat = tiltMag * mag * CGFloat(cos(rad))

            // Normalize axis
            let vx = signedTilt, vy: CGFloat = 1
            let len = sqrt(vx*vx + vy*vy)
            let ax = vx / max(len, 0.0001), ay = vy / max(len, 0.0001)

            // Coin
            Image(imageName(face))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: demoWidth)
                .scaleEffect(x: flipX, y: 1, anchor: .center)
                .rotation3DEffect(.degrees(pitchX), axis: (x: 1, y: 0, z: 0), anchor: .center)
                .rotation3DEffect(.degrees(a),
                                  axis: (x: ax, y: ay, z: 0),
                                  anchor: .center,
                                  perspective: perspective)
                .border(.gray.opacity(0.2))

            // Controls
            VStack(spacing: 10) {
                Slider(value: $angle, in: 0...360) { Text("Angle") }
                HStack {
                    Text("Angle \(Int(angle))°"); Spacer()
                }
                HStack {
                    Text("TiltMag \(String(format: "%.2f", tiltMag))")
                    Slider(value: $tiltMag, in: 0.20...0.50)
                }
                HStack {
                    Text("BackScale \(String(format: "%.2f", backScale))")
                    Slider(value: $backScale, in: 0.75...1.00)
                }
                HStack {
                    Text("Pitch \(Int(pitchX))°")
                    Slider(value: $pitchX, in: -12...4)
                }
                HStack {
                    Text("Perspective \(String(format: "%.2f", perspective))")
                    Slider(value: $perspective, in: 0.45...0.80)
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

//#Preview { CoinTiltBackScaleTuner() }
#endif






#Preview {
    ContentView()
}
