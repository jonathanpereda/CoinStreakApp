//
//  ContentView.swift
//  CoinStreak IOS
//
//  Created by Jonathan Pereda on 10/3/25.
//

import SwiftUI

// MARK: - App Phases
private enum AppPhase { case choosing, preRoll, playing }

// MARK: - Animatable coin that swaps face based on the live angle
struct FlippingCoin: View, Animatable {
    var angle: Double
    var targetAngle: Double
    var baseFace: String
    var width: CGFloat
    var position: CGPoint

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    private func flipped(_ s: String) -> String { s == "Heads" ? "Tails" : "Heads" }
    private func imageName(for face: String) -> String { face == "Tails" ? "coin_tails" : "coin_heads" }

    private let tiltMag: CGFloat = 0.20
    private let backScale: CGFloat = 0.14
    private let pitchX: Double = -6
    private let perspective: CGFloat = 0.51

    var body: some View {
        let a = (angle.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        let seeingBack = (a >= 90 && a < 270)
        let face = seeingBack ? flipped(baseFace) : baseFace
        let flipX: CGFloat = seeingBack ? -1 : 1

        let rad = a * .pi / 180
        let mag = seeingBack ? backScale : 1
        
        // NEW: zero tilt at rest (a ≈ 0 or 180), max around mid-flight.
        // Also clamp tiny values so we don’t see a micro skew.
        var signedTilt: CGFloat = tiltMag * mag * CGFloat(sin(rad))
        if abs(signedTilt) < 0.001 { signedTilt = 0 }   // snap truly flat at rest

        let vx = signedTilt, vy: CGFloat = 1
        let len = sqrt(vx*vx + vy*vy)
        let ax = vx / max(len, 0.0001), ay = vy / max(len, 0.0001)

        return Image(imageName(for: face))
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: width)
            .compositingGroup()
            .scaleEffect(x: flipX, y: 1, anchor: .center)
            .rotation3DEffect(.degrees(pitchX),
                              axis: (x: 1, y: 0, z: 0),
                              anchor: .center,
                              perspective: perspective)          // ← was default (nonzero)

            .rotation3DEffect(.degrees(a),
                              axis: (x: ax, y: ay, z: 0),
                              anchor: .center,
                              perspective: perspective)          // ← was 0.51
            .position(position)
            .animation(nil, value: face)
    }
}

// t: 0 → 1
private func settleAnglesSide(_ t: Double) -> (xRock: Double, yRock: Double) {
    // Slower decay and clear side tilt
    let decay: Double = 6.8
    let e = exp(-decay * t)

    let yAmp: Double = 30.0   // ← dominant: left/right tilt (Y axis)
    let xAmp: Double = 2.0    // ← subtle front/back (X axis) so it doesn’t look flat

    // Slight detune + phase gives natural feel
    let y = yAmp * sin(2 * Double.pi * 3.0 * t + Double.pi/4) * e
    let x = xAmp * sin(2 * Double.pi * 3.4 * t) * e
    return (x, y)
}



private struct SettleWiggle: AnimatableModifier {
    var t: Double
    var animatableData: Double {
        get { t }
        set { t = newValue }
    }
    func body(content: Content) -> some View {
        let ang = settleAnglesSide(t)   // your (xRock, yRock)
        content
            // subtle front/back
            .rotation3DEffect(.degrees(ang.xRock),
                              axis: (x: 1, y: 0, z: 0),
                              anchor: .bottom,
                              perspective: 0.45)  // ← add perspective here
            // dominant left/right rock
            .rotation3DEffect(.degrees(ang.yRock),
                              axis: (x: 0, y: 1, z: 0),
                              anchor: .bottom,
                              perspective: 0.45)  // ← and here
    }
}



private func bounceY(_ t: Double) -> Double {
    // t: 0→1; return NEGATIVE (upwards) pixels; 0 = rest
    // Using |sin| so each lobe is an “upward tap”, then back to 0.
    let decay = 6.5         // larger = dies faster
    let freq  = 3.0         // ~3 taps across t∈[0,1]
    let amp   = 10.0        // max height in px for first tap

    let envelope = exp(-decay * t)
    let pulses   = abs(sin(2 * Double.pi * freq * t))  // 0→1→0 lobes
    return -(amp * envelope * pulses)                  // negative y = up
}

private struct SettleBounce: AnimatableModifier {
    var t: Double                        // 0→1
    var animatableData: Double {
        get { t }
        set { t = newValue }
    }
    func body(content: Content) -> some View {
        content.offset(y: CGFloat(bounceY(t)))
    }
}





private func streakColor(_ v: Int) -> Color {
    switch v {
    case ...2:      return Color("#6E6E6E") // neutral gray
    case 3...5:     return Color("#5B8BF7") // vibrant blue
    case 6...8:     return Color("#00C2A8") // teal
    case 9...10:    return Color("#7DDA58") // green
    case 11...12:   return Color("#F7C948") // yellow/amber
    case 13:        return Color("#FF8C00") // orange
    case 14:        return Color("#E63946") // red
    case 15:        return Color("#8A2BE2") // purple placeholder
    case 16:        return Color("#8A2BE2")
    case 17:        return Color("#8A2BE2")
    case 18:        return Color("#8A2BE2")
    case 19:        return Color("#8A2BE2")
    default:        return Color("#8A2BE2") // 20+
    }
}

@ViewBuilder
private func streakNumberView(_ value: Int) -> some View {
    let baseText =
        Text("\(value)")
            .font(.custom("Herculanum", size: 124))

    if value >= 20 {
        // Legendary tier: animated rainbow
        RainbowText(text: baseText)
    } else if (15...19).contains(value) {
        // High tier: shimmer sweep
        ShimmerText(text: baseText)
    } else {
        // Normal tiers: solid color ramp
        baseText.foregroundColor(streakColor(value))
    }
}



private struct StreakCounter: View {
    let value: Int
    @State private var pop: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 20) {
            Image("streak_text")
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .scaledToFit()
                .scaleEffect(0.75)
                .allowsHitTesting(false)

            streakNumberView(value)
                .shadow(radius: 10)
                .scaleEffect(pop)
                .animation(.spring(response: 0.22, dampingFraction: 0.55, blendDuration: 0.1), value: pop)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .onChange(of: value, initial: false) { oldValue, newValue in
            pop = 1.18
            DispatchQueue.main.async { pop = 1.0 }
        }
    }
}

private func chosenIconName(_ face: Face?) -> String? {
    guard let f = face else { return nil }
    return (f == .Tails) ? "t_icon" : "h_icon"
}

private struct RecentFlipsColumn: View {
    let recent: [FlipEvent]
    let chosenFace: Face?
    let maxShown: Int = 9   // full stack size

    var body: some View {
        // Oldest at top, newest at bottom
        let items = Array(recent.prefix(maxShown).reversed())
        let n = items.count

        // When the column is FULL (n == maxShown), the very top hits this opacity:
        let minOpacityAtFull: Double = 0.18

        // How strong the fade is when full:
        let totalFadeAtFull = 1.0 - minOpacityAtFull  // = 0.82

        VStack(spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.element.id) { idx, ev in
                // idx: 0 = top (oldest), n-1 = bottom (newest)
                let span = max(n - 1, 1)

                // Dynamically raise the top opacity when the list is short:
                // topOpacity(n) = 1 - totalFadeAtFull * (n-1)/(maxShown-1)
                let topOpacity = 1.0 - totalFadeAtFull * (Double(n - 1) / Double(max(maxShown - 1, 1)))

                // Interpolate from topOpacity (at idx=0) to 1.0 (at idx=n-1) across current n
                let t = Double(idx) / Double(span)
                let opacity = topOpacity + (1.0 - topOpacity) * t

                let isPick = (chosenFace == ev.face)
                let color: Color = isPick ? Color("#FFEB99") : .white

                Text(ev.face == .Heads ? "H" : "T")
                    .font(.custom("Herculanum", size: 32))
                    .foregroundColor(color)
                    .opacity(opacity)
                    .shadow(radius: isPick ? 3 : 2)
            }
        }
        .allowsHitTesting(false)
    }
}







struct ContentView: View {
    @StateObject private var store = FlipStore()
    @State private var didRestorePhase = false

    @State private var curState = "Heads"

    // animation state
    @State private var y: CGFloat = 0        // 0 = on ledge
    @State private var scale: CGFloat = 1.0

    // Layout
    private let coinDiameterPct: CGFloat = 0.565
    private let ledgeTopYPct: CGFloat = 0.97
    private let coinRestOverlapPct: CGFloat = 0.06

    // Flip state
    @State private var isFlipping = false
    @State private var baseFaceAtLaunch = "Heads"
    @State private var flightAngle: Double = 0
    @State private var flightTarget: Double = 0
    @State private var settleT: Double = 1.0   // 1 = idle (no wobble), we animate 0 -> 1 on land
    @State private var bounceGen: Int = 0   // cancels any in-flight bounce sequence
    @State private var settleBounceT: Double = 1.0   // 0→1 drives bounce curve; 1 = idle


    // App phase
    @State private var phase: AppPhase = .choosing
    @State private var gameplayOpacity: Double = 0   // 0 = hidden during pre-roll, 1 = visible
    
    //Face Icon
    @State private var iconPulse: Bool = false
    
    //DustPuff
    @State private var gameplayDustTrigger: Date? = nil


    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = geo.size.height
            let coinD = W * coinDiameterPct
            let coinR = coinD / 2
            let coinCenterY = H * ledgeTopYPct - coinR * (1 - coinRestOverlapPct)
            let groundY = H * ledgeTopYPct

            // Shadow geometry for main coin (during gameplay)
            let jumpPx   = max(180, H * 0.32)
            let height01 = max(0, min(1, -y / jumpPx))

            let baseShadowW: CGFloat = coinD * 1.00
            let minShadowW:  CGFloat = coinD * 0.40

            let baseShadowH: CGFloat = coinD * 0.60
            let minShadowH:  CGFloat = coinD * 0.22

            let heightShrinkBias: CGFloat = 0.75
            let th = min(1, height01 / max(heightShrinkBias, 0.0001))

            let shadowW = baseShadowW + (minShadowW - baseShadowW) * height01
            let shadowHcur = baseShadowH + (minShadowH - baseShadowH) * th

            let shadowOpacity = 0.28 * (1.0 - 0.65 * height01)
            let shadowBlur    = 6.0 + 10.0 * height01

            let shadowYOffsetTweak: CGFloat = -157
            let shadowY_centerLocked = (groundY + baseShadowH / 2) + shadowYOffsetTweak

            ZStack {
                Color.black.ignoresSafeArea() // fallback fill
                Image("game_background")
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .ignoresSafeArea()

                // Gameplay shadow + coin are always in the tree; opacity gates visibility.
                Group {
                    // Shadow
                    Ellipse()
                        .fill(Color.black.opacity(shadowOpacity))
                        .frame(width: shadowW, height: shadowHcur)
                        .blur(radius: shadowBlur)
                        .position(x: W/2, y: shadowY_centerLocked)
                    
                    // Dust
                    if let trig = gameplayDustTrigger {
                        DustPuff(
                            trigger: trig,
                            originX: W / 2,
                            groundY: (groundY + baseShadowH / 2) + shadowYOffsetTweak-52,
                            duration: 0.48,
                            count: 16,
                            baseColor: Color.white.opacity(0.85),   // or match your palette
                            shadowColor: Color.black.opacity(0.22),
                            seed: 42
                        )
                        .frame(width: W, height: H)


                    }

                    // Coin
                    ZStack {
                        FlippingCoin(angle: flightAngle,
                                     targetAngle: flightTarget,
                                     baseFace: baseFaceAtLaunch,
                                     width: coinD,
                                     position: .init(x: W/2, y: coinCenterY))
                            .offset(y: y + CGFloat(bounceY(settleBounceT)))   // ← flight + bounce together
                            .scaleEffect(scale)
                    }
                    .modifier(SettleWiggle(t: settleT))       // apply to parent, not inside coin’s 3D perspective
                    .modifier(SettleBounce(t: settleBounceT)) // ditto
                    .contentShape(Rectangle())
                    .onTapGesture { flipCoin() }

                }
                .opacity(gameplayOpacity)                 // <— no animation; see onReveal below
                .allowsHitTesting(phase == .playing)      // disable taps until playing


                // Top overlay: Streak Counter
                VStack {
                    if phase != .choosing {
                        StreakCounter(value: store.currentStreak)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 75)
                            .padding(.horizontal, 20)
                            .transition(.opacity)
                    }
                    Spacer()
                }
                .allowsHitTesting(false) // don't block coin taps
                
                // Bottom-right chosen-face badge (safe-area aware even with ignoresSafeArea)
                if phase != .choosing, let icon = chosenIconName(store.chosenFace) {
                    let size: CGFloat = 52
                    Image(icon)
                        .resizable()
                        .interpolation(.high)
                        .antialiased(true)
                        .renderingMode(.original)
                        .frame(width: size, height: size)
                        .shadow(color: iconPulse ? .yellow.opacity(0.5) : .clear,
                                    radius: iconPulse ? 18 : 0)
                        .animation(.easeOut(duration: 0.25), value: iconPulse)
                        .allowsHitTesting(false)
                        .position(
                            x: geo.size.width  - (size / 2) - max(12, geo.safeAreaInsets.trailing),
                            y: geo.size.height - (size / 2) -  geo.safeAreaInsets.bottom
                        )
                        .offset(y: 60)
                        .transition(.opacity)
                }
                
                // Recent flips pillar: bottom fixed at a baseline, grows upward
                if phase != .choosing, !store.recent.isEmpty {
                    // Choose where the BOTTOM should live (0.0 = top, 1.0 = bottom)
                    let baselineYPct: CGFloat = 0.30   // mid-left baseline; tweak to taste
                    let baselineY = geo.size.height * baselineYPct

                    ZStack(alignment: .bottomLeading) {
                        RecentFlipsColumn(recent: store.recent, chosenFace: store.chosenFace)
                            .padding(.leading, max(12, geo.safeAreaInsets.leading + 4))
                    }
                    // Container height == distance from top → baseline; column is bottom-aligned inside
                    .frame(width: geo.size.width, height: baselineY, alignment: .bottomLeading)
                    .animation(.spring(response: 0.28, dampingFraction: 0.8), value: store.recent)
                    .transition(.opacity)
                    .allowsHitTesting(false)
                }




            }
            .ignoresSafeArea()

            //Debug
            
            #if DEBUG
            .overlay(alignment: .topTrailing) {
                Button {
                    store.chosenFace = nil
                    store.currentStreak = 0
                    store.clearRecent()
                    didRestorePhase = false
                    phase = .choosing
                    gameplayOpacity = 0
                }label: {
                    Image(systemName: "gearshape.fill")    // SF Symbols gear icon
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)      // small size
                        .foregroundColor(.white)
                        .padding(10)                       // tap target
                        .background(Color.red.opacity(0.25))
                        .clipShape(Circle())
                        .shadow(radius: 3)
                }
                .padding(.top, 2)
                .padding(.trailing, 2)
            }
            #endif
            
            
            // Choose overlay
            .overlay {
                if phase == .choosing {
                    ChooseFaceScreen(
                        store: store,
                        groundY: groundY,
                        screenSize: geo.size
                    ) { selected in
                        // Persist selection & make gameplay coin match it
                        store.chosenFace     = selected
                        curState             = selected.rawValue
                        baseFaceAtLaunch     = selected.rawValue

                        // Reset gameplay coin transforms just in case
                        y = 0; scale = 1
                        flightAngle = 0; flightTarget = 0

                        // HIDE gameplay coin immediately (no animation) so it won't show before the drop
                        let tx = Transaction(animation: nil)
                        withTransaction(tx) { gameplayOpacity = 0 }

                        // Start pre-roll
                        withAnimation(.easeInOut(duration: 0.35)) {
                            phase = .preRoll
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(1000)
                }
            }

            // Pre-roll hero coin drop overlay
            .overlay {
                if phase == .preRoll {
                    IntroOverlay(
                        groundY: groundY,
                        screenSize: geo.size,
                        coinDiameterPct: coinDiameterPct,
                        coinRestOverlapPct: coinRestOverlapPct,
                        finalFace: store.chosenFace ?? .Heads,
                        onRevealGameplay: {                     // called exactly at touchdown
                            let tx = Transaction(animation: nil) // ensure no fade-in of gameplay coin
                            withTransaction(tx) {
                                gameplayOpacity = 1              // coin instantly visible UNDER overlay
                            }
                        },
                        onFinished: {                            // overlay fade done -> start playing
                            withAnimation(.easeInOut(duration: 0.20)) {
                                phase = .playing
                            }
                        },
                        onThud: {date in
                            gameplayDustTrigger = date
                            
                            // auto-remove the puff after it finishes (match DustPuff duration + tiny buffer)
                            let lifetime = 0.48 + 0.05
                            DispatchQueue.main.asyncAfter(deadline: .now() + lifetime) {
                                if gameplayDustTrigger == date {   // only clear if nothing retriggered
                                    gameplayDustTrigger = nil
                                }
                            }
                        }
                    )
                    // No transition here—overlay manages its own fade
                    .zIndex(999)
                    .ignoresSafeArea()
                }
            }


        }
        .onAppear {
            guard !didRestorePhase else { return }
            didRestorePhase = true

            if let pick = store.chosenFace {
                // User already chose — skip chooser forever
                curState = pick.rawValue
                baseFaceAtLaunch = pick.rawValue
                gameplayOpacity = 1
                phase = .playing
            } else {
                // First ever launch
                gameplayOpacity = 0
                phase = .choosing
            }
        }

    }
    
    
    private func runReboundBounces() {
        // Increment generation to invalidate any earlier scheduled steps
        bounceGen &+= 1
        let gen = bounceGen

        // Tunables
        let amps: [CGFloat] = [-10, -6, -3]    // pixels up (negative y = up)
        let upResp:  Double = 0.12
        let upDamp:  Double = 0.62
        let dnResp:  Double = 0.16
        let dnDamp:  Double = 0.88

        // Total timing accumulator
        var t: Double = 0

        func schedule(_ delay: Double, _ block: @escaping () -> Void) {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard gen == bounceGen else { return }  // canceled by new flip
                block()
            }
        }

        for i in 0..<amps.count {
            let a = amps[i]

            // Up tick
            schedule(t) {
                withAnimation(.spring(response: upResp, dampingFraction: upDamp)) {
                    y = a
                }
            }
            t += upResp * 0.85  // begin coming down slightly before the up spring fully settles

            // Down to rest
            schedule(t) {
                withAnimation(.spring(response: dnResp, dampingFraction: dnDamp)) {
                    y = 0
                }
            }
            t += dnResp * 0.95
        }
    }


    // MARK: - Flip logic
    func flipCoin() {
        guard phase == .playing else { return }   // block until pre-roll done
        guard !isFlipping else { return }
        
        // Cancel any ongoing bounce/wobble and reset pose instantly
        withTransaction(.init(animation: nil)) {
            settleBounceT = 1.0
            settleT = 1.0
            y = 0
        }



        
        // Random launch sound
        SoundManager.shared.play(["launch_1","launch_2"].randomElement()!)

        let desired = Bool.random() ? "Heads" : "Tails"
        
        //DEV TEST
        //let desired = "Heads"

        // Capture takeoff state
        baseFaceAtLaunch = curState
        isFlipping = true

        // Choose # of half-turns so final parity matches desired face
        let needOdd = (desired != baseFaceAtLaunch)
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
        }
        // Down (ease-in)
        DispatchQueue.main.asyncAfter(deadline: .now() + upDur) {
            withAnimation(.easeIn(duration: downDur)) {
                y = 0
                scale = 1
            }
            withAnimation(.easeOut(duration: 0.10)) {
                // small settle
            }
        }

        // Land: commit result & streak; normalize for next flip
        DispatchQueue.main.asyncAfter(deadline: .now() + total) {
            curState = desired
            
            // 1) freeze flip state (prevents drift)
            let noAnim = Transaction(animation: nil)
            withTransaction(noAnim) {
                baseFaceAtLaunch = desired
                isFlipping = false
                flightAngle = 0
                flightTarget = 0
            }

            // Kick off bounce + wobble once
            settleBounceT = 0.0
            withAnimation(.linear(duration: 0.70)) { settleBounceT = 1.0 }

            settleT = 0.0
            withAnimation(.linear(duration: 0.85)) { settleT = 1.0 }

            
            if let faceVal = Face(rawValue: desired) {
                store.recordFlip(result: faceVal)
                if faceVal == store.chosenFace {
                    
                    let pitch = Float(store.currentStreak) * 0.5  // each +0.5 semitone
                    SoundManager.shared.playPitched(base: "streak_base_pitch", semitoneOffset: pitch)
                    
                    iconPulse = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        iconPulse = false
                    }
                } else {
                    // Play landing sound
                    SoundManager.shared.play(["land_1","land_2"].randomElement()!)
                }
            }
        }
    }
}


#Preview { ContentView() }

// MARK: - Intro overlay (stronger mid-air tilt; no bounce; reveal gameplay at touchdown)
private struct IntroOverlay: View {
    let groundY: CGFloat
    let screenSize: CGSize
    let coinDiameterPct: CGFloat
    let coinRestOverlapPct: CGFloat
    let finalFace: Face
    let onRevealGameplay: () -> Void
    let onFinished: () -> Void
    let onThud: (Date) -> Void

    @State private var coinY: CGFloat = -600
    @State private var shadowW: CGFloat = 0
    @State private var shadowH: CGFloat = 0
    @State private var shadowOpacity: CGFloat = 0
    @State private var overlayOpacity: CGFloat = 1
    @State private var angle: Double = -32          // stronger tilt
    @State private var dropGroupOpacity: Double = 1
    @State private var yaw: Double = -7
    
    @State private var dustTrigger: Date? = nil

    var body: some View {
        let W = screenSize.width
        let H = screenSize.height
        let coinD = W * coinDiameterPct
        let coinR = coinD / 2

        let baseShadowW = coinD * 1.00
        let minShadowW  = coinD * 0.40
        let baseShadowH = coinD * 0.60
        let minShadowH  = coinD * 0.22
        let shadowYOffsetTweak: CGFloat = -157
        let coinCenterY_atRest = groundY - coinR * (1 - coinRestOverlapPct)

        let faceImageName = (finalFace == .Tails) ? "coin_tails" : "coin_heads"

        ZStack {
            Color.clear
            
            Group {
                Ellipse()
                    .fill(Color.black.opacity(shadowOpacity))
                    .frame(width: shadowW, height: shadowH)
                    .blur(radius: 8)
                    .position(x: W/2, y: (groundY + baseShadowH / 2) + shadowYOffsetTweak)

                Image(faceImageName)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: coinD)
                    .rotationEffect(.degrees(angle))                               // 2D tilt
                    .rotation3DEffect(.degrees(yaw), axis: (x: 0, y: 1, z: 0))     // NEW: subtle 3D yaw
                    .position(x: W/2, y: coinCenterY_atRest + coinY)

            }
            .opacity(dropGroupOpacity)   // NEW: instantly hide overlay’s coin+shadow at touchdown
        }
        .opacity(overlayOpacity)
        .onAppear {
            // Start state
            coinY = -max(700, H * 0.9)
            shadowW = minShadowW
            shadowH = minShadowH
            shadowOpacity = 0.02
            overlayOpacity = 1

            angle = -32   // stronger 2D tilt
            yaw   = -7    // subtle 3D yaw

            // Timings
            let dropDur: Double = 0.55

            // (1) Vertical drop (no overshoot)
            withAnimation(.easeIn(duration: dropDur)) {
                coinY = 0
                shadowW = baseShadowW
                shadowH = baseShadowH
                shadowOpacity = 0.28
            }

            // (2) Keep the coin noticeably tilted for a moment, then finish tilt IN AIR
            // Hold tilt for ~0.12s, then straighten over ~0.38s so it completes just before touchdown.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.easeOut(duration: 0.38)) {
                    angle = 0
                    yaw   = 0
                }
            }

            // (3) Touchdown → instantly hide overlay’s coin/shadow, reveal gameplay coin, fade overlay
            DispatchQueue.main.asyncAfter(deadline: .now() + dropDur) {
                let tx = Transaction(animation: nil)
                
                SoundManager.shared.play("thud_1")
                onThud(Date())
                
                withTransaction(tx) { dropGroupOpacity = 0 }   // hide overlay coin+shadow instantly
                withTransaction(tx) { onRevealGameplay() }     // show gameplay coin under overlay

                withAnimation(.easeInOut(duration: 0.22)) {
                    overlayOpacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                    onFinished()
                }
            }
        }
        .allowsHitTesting(false)
    }
}




