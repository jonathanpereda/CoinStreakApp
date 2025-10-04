import SwiftUI

struct ChooseFaceScreen: View {
    @ObservedObject var store: FlipStore
    
    let groundY: CGFloat
    let screenSize: CGSize

    // Match your main game’s layout constants so placement feels consistent
    private let coinDiameterPctMain: CGFloat = 0.565
    private let ledgeTopYPct: CGFloat = 0.97
    private let coinRestOverlapPct: CGFloat = 0.06

    // Smaller chooser coins
    private let coinDiameterPctChoose: CGFloat = 0.36  // tweak to taste

    // 🔧 Easy tuning for this screen
    private let chooseSpacingMultiplier: CGFloat = 0    // horizontal gap = coinD * this
    private let shadowYOffsetTweakChoose: CGFloat = 0   // small per-screen nudge in points
    private let coinsXOffset: CGFloat = 0               // move both coins left(−)/right(+)
    private let coinsYOffset: CGFloat = -50             // move both coins up(−)/down(+)

    var body: some View {
        let W = screenSize.width
        let H = screenSize.height

        // Reference/main coin (for scaling shadow offsets)
        let coinD_main = W * coinDiameterPctMain
        let coinD = W * coinDiameterPctChoose
        let scaleFactor = coinD / coinD_main

        let coinR = coinD / 2
        let coinCenterY = groundY - coinR * (1 - coinRestOverlapPct)
        let groundY = H * ledgeTopYPct

        ZStack {
            Image("game_background")
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
            let pairHeight = coinD * 1.6  // just enough vertical room for coins + shadow

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
            .position(x: W/2 + coinsXOffset, y: coinCenterY + coinsYOffset)

        }
        .ignoresSafeArea()
        .statusBarHidden(true)
    }

    private func choose(_ selected: Face) {
        withAnimation(.easeInOut(duration: 0.35)) {
            store.chosenFace = selected
        }
        // No modal to dismiss anymore; safe to drop this.
        // dismiss()
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
    @State private var flightAngle: Double = 0
    @State private var flightTarget: Double = 0

    var body: some View {
        // Height param for shadow dynamics
        let jumpPx = max(180, UIScreen.main.bounds.height * 0.32)
        let height01 = max(0, min(1, -y / jumpPx))

        // ---- Shadow dynamics (scaled from your tuned main values) ----
        // Your main values: baseW=1.00, minW=0.40, baseH=0.60, minH=0.22, main tweak ~ -157
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

        // Top-locked shadow so it visually kisses the ledge:
        let mainTweakScaled = (-157.0) * scaleFactor
        let shadowY_center_topLocked = groundY + (shadowHcur / 2) + mainTweakScaled + shadowYOffsetTweakChoose
        // Convert to local offset relative to the coin container’s center (which is at centerY)
        let shadowLocalOffsetY = shadowY_center_topLocked - centerY

        // Fixed face for this coin (prevents the “two heads” issue)
        let base = (face == .Heads) ? "Heads" : "Tails"

        // Container sized to include shadow; center the coin inside it
        let containerW = coinD * 1.4
        let containerH = coinD * 1.6

        ZStack {
            // Ground-locked shadow (relative to this coin's center)
            Ellipse()
                .fill(Color.black.opacity(shadowOpacity))
                .frame(width: shadowW, height: shadowHcur)
                .blur(radius: shadowBlur)
                .offset(x: 0, y: shadowLocalOffsetY)

            // Coin
            FlippingCoin(
                angle: flightAngle,
                targetAngle: flightTarget,
                baseFace: base,
                width: coinD,
                position: .init(x: containerW / 2, y: containerH / 2)
            )
            .offset(y: y) // coin floats up; shadow stays put (but both fade)
        }
        .frame(width: containerW, height: containerH)
        .opacity(groupOpacity)          // fades coin + shadow together
        .offset(x: offsetX)             // slides coin + shadow together (unchosen)
        .contentShape(Circle())         // hit area ~ coin
        .onTapGesture {
            guard !isAnimating else { return }
            isAnimating = true

            // Selected coin: flip up and fade away (coin moves; shadow only fades)
            let total: Double = 0.75
            let upDur = total * 0.42
            let jump: CGFloat = max(160, UIScreen.main.bounds.height * 0.28)

            flightAngle = 0
            flightTarget = 6 * 180 // 3 full flips
            withAnimation(.linear(duration: total)) {
                flightAngle = flightTarget
            }
            withAnimation(.easeOut(duration: upDur)) {
                y = -jump
                groupOpacity = 0      // fade BOTH coin + shadow
            }

            // Tell the other coin to slide away
            NotificationCenter.default.post(name: .slideAway, object: isLeftCoin) // true = left selected

            // Finish -> persist choice
            DispatchQueue.main.asyncAfter(deadline: .now() + total) {
                onChosen(face)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .slideAway)) { note in
            guard isAnimating == false else { return } // ignore if we’re the selected coin
            if let leftWasSelected = note.object as? Bool {
                // If left selected → we (right) slide right. If right selected → we (left) slide left.
                let dir: CGFloat = leftWasSelected ? 1 : -1
                withAnimation(.easeInOut(duration: 0.45)) {
                    offsetX = dir * (UIScreen.main.bounds.width + 200)
                    groupOpacity = 0 // fade BOTH coin + shadow as we slide
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
            // Use the same ledge % you use in ContentView
            let groundY = geo.size.height * 0.97
            ChooseFaceScreen(
                store: store,
                groundY: groundY,
                screenSize: geo.size
            )
            .ignoresSafeArea()
        }
    }
}

#Preview("ChooseFaceScreen") {
    ChooseFaceScreenPreviewWrapper()
        .previewDevice("iPhone 16 Pro") // or any device you prefer
}

