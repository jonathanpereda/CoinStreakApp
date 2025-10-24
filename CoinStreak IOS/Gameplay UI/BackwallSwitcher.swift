import SwiftUI
import Combine

// Backwall that swings from the top-right, then drops. Time-driven via Timer.
// Now supports a "middle" slot rendered between NEW backwall and OUTGOING wall.
struct BackwallSwitcher<Middle: View>: View {
    let backwallName: String
    var onDropImpact: ((Date) -> Void)? = nil
    @ViewBuilder var middle: () -> Middle

    // === Tuning ===
    private let perspective: CGFloat = 0.55
    private let totalDur: Double = 2.2
    private let swingFrac: Double   = 0.55
    private let holdFrac: Double    = 0.02
    private let overlapFrac: Double = 0.18
    private let swingZDeg: Double   = -40
    private let swingXDeg: Double   = 14
    private let swingYawDeg: Double = -6
    private let swingSagPx: CGFloat = 18
    private let dropTiltXDeg: Double   = 32
    private let fadeTail: Double       = 0.14
    private let dropOvershoot: CGFloat = 200

    // === State ===
    @State private var currentImage: String
    @State private var outgoingImage: String?
    @State private var animStart: Date? = nil
    @State private var masterT: Double = 0.0
    @State private var bootstrapped = false

    private let tick = Timer.publish(every: 1.0 / 120.0, on: .main, in: .common).autoconnect()

    init(
        backwallName: String,
        onDropImpact: ((Date) -> Void)? = nil,
        @ViewBuilder middle: @escaping () -> Middle
    ) {
        self.backwallName = backwallName
        self.onDropImpact = onDropImpact
        self.middle = middle
        _currentImage = State(initialValue: backwallName)
    }

    // Convenience init for when I don't want to pass a middle layer
    init(backwallName: String, onDropImpact: ((Date) -> Void)? = nil) where Middle == EmptyView {
        self.init(backwallName: backwallName, onDropImpact: onDropImpact) { EmptyView() }
    }

    var body: some View {
        GeometryReader { geo in
            let H = geo.size.height

            ZStack {
                // 1) NEW/ACTIVE backwall (back)
                Image(currentImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .ignoresSafeArea()

                // 2) MIDDLE SLOT — content goes here
                middle()

                // 3) OUTGOING wall (front), animated
                if let out = outgoingImage {
                    // Phase bounds
                    let swingEnd    = min(1.0, swingFrac)
                    let holdEnd     = min(1.0, swingEnd + max(0, holdFrac))
                    let dropStartRaw = max(0.0, swingEnd - max(0, overlapFrac))
                    let dropStart    = max(holdEnd, dropStartRaw)
                    let dropEnd      = 1.0

                    // Progress
                    let swingP  = easeInOutCubic(segProgress(masterT, 0.0,     swingEnd))
                    let dropP   = easeInPow(     segProgress(masterT, dropStart, dropEnd), 3.6)

                    // Transforms
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
                        .rotationEffect(.degrees(zDeg), anchor: .topTrailing)
                        .rotation3DEffect(.degrees(xDeg), axis: (x: 1, y: 0, z: 0),
                                          anchor: .topTrailing, perspective: perspective)
                        .rotation3DEffect(.degrees(yaw), axis: (x: 0, y: 1, z: 0),
                                          anchor: .topTrailing, perspective: perspective)
                        .offset(y: sag + fall)
                        .opacity(1.0 - fadeTail * max(0, (dropP - 0.75) / 0.25))
                        .zIndex(1) // (local to this ZStack)
                }
            }
            // Drive masterT from time
            .onReceive(tick) { now in
                guard let start = animStart else { return }
                let elapsed = now.timeIntervalSince(start)
                let t = max(0, min(1, elapsed / totalDur))
                if t != masterT { masterT = t }
            }
        }
        .onAppear { bootstrapped = true }
        .onChange(of: backwallName) { _, newName in
            guard newName != currentImage else { return }

            // First mount: no animation
            guard bootstrapped else {
                currentImage = newName
                outgoingImage = nil
                masterT = 0
                animStart = nil
                bootstrapped = true
                return
            }

            // Stage transition
            let prev = currentImage
            currentImage = newName
            outgoingImage = prev
            masterT = 0
            animStart = Date()

            // End-of-sequence cleanup + impact hook
            DispatchQueue.main.asyncAfter(deadline: .now() + totalDur) {
                SoundManager.shared.play("thud_1")
                onDropImpact?(Date())
                masterT = 1.0
                outgoingImage = nil
                animStart = nil
                DispatchQueue.main.async { masterT = 0 }
            }
        }
    }
}

// === Helpers ===
private func segProgress(_ t: Double, _ a: Double, _ b: Double) -> Double {
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
    return pow(tt, p)
}
