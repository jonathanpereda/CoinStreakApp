import SwiftUI
import Foundation

// MARK: - HERO DROP ANIM (stronger mid-air tilt; no bounce; reveal gameplay at touchdown)
struct IntroOverlay: View {
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

        // 1) Compute with the scaled coin diameter so overlap math stays correct
        let scaledCoinD = coinD * NewCoinTweak.scale
        //let coinRScaled = coinR * NewCoinTweak.scale

        let baseShadowW = coinD * 1.00
        let minShadowW = coinD * 0.40
        let baseShadowH = coinD * 0.60
        let minShadowH = coinD * 0.22

        // Lift shadow a hair more like gameplay
        let shadowYOffsetTweak: CGFloat = -157

        // Use scaled radius for the “rest” center, then add the global coin nudge later
        let coinCenterY_atRest = groundY - coinR * (1 - coinRestOverlapPct)

        let faceImageName = (finalFace == .Tails) ? "starter_coin_T" : "starter_coin_H"


        ZStack {
            Color.clear
            
            Group {
                Ellipse()
                    .fill(Color.black.opacity(shadowOpacity))
                    .frame(width: shadowW, height: shadowH)
                    .blur(radius: 8)
                    // add both the coin nudge and extra -10 lift to the shadow:
                    .position(x: W/2, y: (groundY + baseShadowH / 2) + shadowYOffsetTweak - 10)

                Image(faceImageName)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    // render at scaled size
                    .frame(width: scaledCoinD)
                    .rotationEffect(.degrees(angle))
                    .rotation3DEffect(.degrees(yaw), axis: (x: 0, y: 1, z: 0))
                    // add NewCoinTweak.nudgeY so the coin sits exactly like gameplay
                    .position(x: W/2, y: coinCenterY_atRest + coinY + NewCoinTweak.nudgeY)


            }
            .opacity(dropGroupOpacity)   // instantly hide overlay’s coin+shadow at touchdown
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
                Haptics.shared.thud()
                
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

