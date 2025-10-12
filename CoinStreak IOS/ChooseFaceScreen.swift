import SwiftUI

// === Sprite helpers (localized to the chooser) ===

private enum CoinSide: String { case H = "Heads", T = "Tails" }

private struct SpriteFlipPlan: Equatable {
    let startFace: CoinSide
    let endFace:   CoinSide
    let halfTurns: Int       // number of half flips (HT or TH alternations)
    let startTime: Date
    let duration:  Double
}

// Your chooser uses the same “large alpha box” correction as gameplay.
// If you change the main tweak later, mirror the numbers here.
private struct CoinVisualTweak { let scale: CGFloat; let nudgeY: CGFloat }
private let ChooseCoinTweak = CoinVisualTweak(scale: 2.7, nudgeY: -48)

// Your atlas frame names are coin_HT_0001...0036 and coin_TH_0001...0036
private func atlasFrameName(prefix: String, idx1based: Int) -> String {
    String(format: "%@_%04d", prefix, idx1based)
}

// Build the alternating atlas sequence for N half-turns.
// Skip the first frame of every run after the first so idle frames don't repeat.
private func buildAtlasRun(start: CoinSide, halfTurns: Int) -> [(prefix: String, count: Int, skipFirst: Bool)] {
    var list: [(String, Int, Bool)] = []
    var cur = start
    for i in 0..<halfTurns {
        let next: CoinSide = (cur == .H) ? .T : .H
        let prefix = (cur == .H && next == .T) ? "coin_HT" : "coin_TH"
        list.append((prefix, 36, i > 0))
        cur = next
    }
    return list
}

private func spriteFrameFor(plan: SpriteFlipPlan, now: Date) -> String {
    let elapsed = max(0, now.timeIntervalSince(plan.startTime))
    let t = min(elapsed, plan.duration)

    let atlases = buildAtlasRun(start: plan.startFace, halfTurns: plan.halfTurns)
    let totalFrames = atlases.reduce(0) { $0 + $1.count - ($1.skipFirst ? 1 : 0) }
    let idx = Int(round((t / max(plan.duration, 0.0001)) * Double(totalFrames - 1)))

    var remaining = idx
    for (prefix, count, skip) in atlases {
        let effective = count - (skip ? 1 : 0)
        if remaining < effective {
            let local1 = remaining + (skip ? 2 : 1)
            return atlasFrameName(prefix: prefix, idx1based: local1)
        }
        remaining -= effective
    }
    // Fallback: last frame of the final sequence
    let finalPrefix = (plan.endFace == .H) ? "coin_TH" : "coin_HT"
    return atlasFrameName(prefix: finalPrefix, idx1based: 36)
}

// Minimal sprite image view mirroring your gameplay component
private struct MiniSpriteCoinImage: View {
    let plan: SpriteFlipPlan?
    let idleFace: CoinSide
    let width: CGFloat
    let center: CGPoint   // container center in local coords

    var body: some View {
        TimelineView(.animation) { timeline in
            let name = plan.map { spriteFrameFor(plan: $0, now: timeline.date) }
                        ?? (idleFace == .H ? "coin_H" : "coin_T")

            Image(name)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: width * ChooseCoinTweak.scale)
                .position(x: center.x, y: center.y + ChooseCoinTweak.nudgeY)
                .drawingGroup()
        }
    }
}



struct ChooseFaceScreen: View {
    @ObservedObject var store: FlipStore

    let groundY: CGFloat
    let screenSize: CGSize
    let onSelection: (Face) -> Void   // selection callback to ContentView

    // Match your main game’s layout constants so placement feels consistent
    private let coinDiameterPctMain: CGFloat = 0.565
    private let coinRestOverlapPct: CGFloat = 0.06

    // Smaller chooser coins
    private let coinDiameterPctChoose: CGFloat = 0.36  // tweak to taste

    // 🔧 Easy tuning for this screen
    private let chooseSpacingMultiplier: CGFloat = 0    // horizontal gap = coinD * this
    private let shadowYOffsetTweakChoose: CGFloat = -10   // per-screen nudge (pts)
    private let coinsXOffset: CGFloat = 0               // move both coins left/right
    private let coinsYOffset: CGFloat = -50             // move both coins up/down

    var body: some View {
        let W = screenSize.width
        let H = screenSize.height

        // Reference/main coin (for scaling shadow offsets)
        let coinD_main = W * coinDiameterPctMain
        let coinD = W * coinDiameterPctChoose
        let scaleFactor = coinD / coinD_main

        let coinR = coinD / 2
        // Compute center from the SAME ledge Y passed in
        let coinCenterY = groundY - coinR * (1 - coinRestOverlapPct)

        ZStack {
            Image("game_background2")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .ignoresSafeArea()

            let targetWidth = min(W * 0.8, 620)
            Image("choose_text")
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .scaledToFit()
                .frame(width: targetWidth)
                .position(x: W / 2, y: H * 0.30)
                .allowsHitTesting(false)

            // compute spacing and the exact width the pair should take
            let spacing = coinD * chooseSpacingMultiplier
            let pairWidth = coinD * 2 + spacing
            let pairHeight = coinD * 1.6

            HStack(spacing: spacing) {
                PickableCoin(
                    face: .Heads,
                    coinD: coinD,
                    centerY: coinCenterY,
                    groundY: groundY,
                    scaleFactor: scaleFactor,
                    isLeftCoin: true,
                    shadowYOffsetTweakChoose: shadowYOffsetTweakChoose
                ) { choose($0) }

                PickableCoin(
                    face: .Tails,
                    coinD: coinD,
                    centerY: coinCenterY,
                    groundY: groundY,
                    scaleFactor: scaleFactor,
                    isLeftCoin: false,
                    shadowYOffsetTweakChoose: shadowYOffsetTweakChoose
                ) { choose($0) }
            }
            .frame(width: pairWidth, height: pairHeight, alignment: .center)
            .position(x: W/2 + coinsXOffset, y: coinCenterY + coinsYOffset + 15)
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
    }

    private func choose(_ selected: Face) {
        // You already animate the coins out inside PickableCoin and call this after.
        withAnimation(.easeInOut(duration: 0.35)) {
            onSelection(selected)
        }
    }
}

// MARK: - A single interactive coin with its own shadow + animations
private struct PickableCoin: View {
    let face: Face
    let coinD: CGFloat
    let centerY: CGFloat
    let groundY: CGFloat
    let scaleFactor: CGFloat
    let isLeftCoin: Bool
    let shadowYOffsetTweakChoose: CGFloat
    let onChosen: (Face) -> Void

    // Animations
    @State private var y: CGFloat = 0                 // selected coin float-up
    @State private var groupOpacity: CGFloat = 1      // fades coin + shadow together
    @State private var offsetX: CGFloat = 0           // slides unchosen coin + shadow
    @State private var isAnimating = false

    // Flip
    @State private var spritePlan: SpriteFlipPlan? = nil

    var body: some View {
        let jumpPx = max(180, UIScreen.main.bounds.height * 0.32)
        let height01 = max(0, min(1, -y / jumpPx))

        // Shadow dynamics (scaled from main values)
        let baseShadowW = coinD * 1.00
        let minShadowW  = coinD * 0.40
        let baseShadowH = coinD * 0.60
        let minShadowH  = coinD * 0.22
        let heightShrinkBias: CGFloat = 0.75
        let th = min(1, height01 / max(heightShrinkBias, 0.0001))

        let shadowW = baseShadowW + (minShadowW - baseShadowW) * height01
        let shadowHcur = baseShadowH + (minShadowH - baseShadowH) * th
        let shadowOpacity = 0.28 * (1.0 - 0.65 * height01)
        let shadowBlur = 6.0 + 10.0 * height01

        let mainTweakScaled = (-157.0) * scaleFactor
        let shadowY_center_topLocked = groundY + (shadowHcur / 2) + mainTweakScaled + shadowYOffsetTweakChoose
        let shadowLocalOffsetY = shadowY_center_topLocked - centerY

        let containerW = coinD * 1.4
        let containerH = coinD * 1.6

        ZStack {
            Ellipse()
                .fill(Color.black.opacity(shadowOpacity))
                .frame(width: shadowW, height: shadowHcur)
                .blur(radius: shadowBlur)
                .offset(x: 0, y: shadowLocalOffsetY)

            MiniSpriteCoinImage(
                plan: spritePlan,
                idleFace: (face == .Heads ? .H : .T),
                width: coinD,
                center: .init(x: containerW / 2, y: containerH / 2)
            )
            .offset(y: y)
        }
        .frame(width: containerW, height: containerH)
        .opacity(groupOpacity)
        .offset(x: offsetX)
        .contentShape(Circle())
        .onTapGesture {
            guard !isAnimating else { return }
            isAnimating = true

            // 🔊 Play launch sound immediately on pick
            if let s = ["launch_1","launch_2"].randomElement() {
                SoundManager.shared.play(s)
            }
            
            let total: Double = 0.75
            let upDur = total * 0.42
            let jump: CGFloat = max(160, UIScreen.main.bounds.height * 0.28)

            // === start sprite flip: 3 full flips = 6 half-turns ===
            let startSide: CoinSide = (face == .Heads) ? .H : .T
            let endSide:   CoinSide = (face == .Heads) ? .H : .T   // ends on same face for chooser flair
            spritePlan = SpriteFlipPlan(
                startFace: startSide,
                endFace: endSide,
                halfTurns: 6,
                startTime: Date(),
                duration: total
            )
            // Up & fade
            withAnimation(.easeOut(duration: upDur)) {
                y = -jump
                groupOpacity = 0
            }

            // Tell the other coin to slide away
            NotificationCenter.default.post(name: .slideAway, object: isLeftCoin)

            // Finish -> notify selection
            DispatchQueue.main.asyncAfter(deadline: .now() + total) {
                // stop sprite playback so it returns to idle frame
                spritePlan = nil
                onChosen(face)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .slideAway)) { note in
            guard isAnimating == false else { return }
            if let leftWasSelected = note.object as? Bool {
                let dir: CGFloat = leftWasSelected ? 1 : -1
                withAnimation(.easeInOut(duration: 0.45)) {
                    offsetX = dir * (UIScreen.main.bounds.width + 200)
                    groupOpacity = 0
                }
            }
        }
        .allowsHitTesting(!isAnimating)
    }
}

private extension Notification.Name {
    static let slideAway = Notification.Name("ChooseCoinSlideAway")
}

// MARK: - Preview
private struct ChooseFaceScreenPreviewWrapper: View {
    @StateObject var store = FlipStore()
    var body: some View {
        GeometryReader { geo in
            let groundY = geo.size.height * 0.97
            ChooseFaceScreen(
                store: store,
                groundY: groundY,
                screenSize: geo.size,
                onSelection: { _ in }
            )
            .ignoresSafeArea()
        }
    }
}

#Preview("ChooseFaceScreen") {
    ChooseFaceScreenPreviewWrapper()
}
