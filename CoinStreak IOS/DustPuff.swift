import SwiftUI

struct DustPuff: View {
    let trigger: Date
    let originX: CGFloat
    let groundY: CGFloat
    let duration: Double
    let count: Int
    let baseColor: Color
    let shadowColor: Color
    let seed: UInt64

    @State private var t: CGFloat = 0  // 0 → 1 over `duration`

    var body: some View {
        ZStack {
            DustPuffCanvas(
                progress: t,
                originX: originX,
                groundY: groundY,
                baseColor: baseColor,
                shadowColor: shadowColor,
                count: count,
                seed: seed
            )
        }
        .id(trigger) // restart animation when trigger changes
        .onAppear { animate() }
        .onChange(of: trigger) { animate() }   // iOS 17+ overload
        .allowsHitTesting(false)
    }

    private func animate() {
        t = 0
        withAnimation(.linear(duration: duration)) {
            t = 1
        }
    }
}

/// Split Canvas into its own small view to help the type-checker.
private struct DustPuffCanvas: View, Animatable {
    var progress: CGFloat              // 0 → 1 driven by SwiftUI
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    let originX: CGFloat
    let groundY: CGFloat
    let baseColor: Color
    let shadowColor: Color
    let count: Int
    let seed: UInt64

    var body: some View {
        Canvas { context, _ in
            // ----- BEGIN: tight, ground-hugging puff (visibility-first) -----

            // Use the animated progress directly
            let tt: CGFloat = max(0, min(1, progress))

            // Eases
            let grow  = 1 - pow(1 - tt, 2)     // size growth
            let fade = pow(max(0, 1 - tt), 1.4)  // tweak 1.2–1.8 to taste; still hits 0
            let lift  = 1 - pow(1 - tt, 3)     // tiny upward "breath"

            // Puff radius: starts tiny, grows a bit (no screen travel)
            let r0: CGFloat = 105
            let r1: CGFloat = 165
            let r:  CGFloat = r0 + (r1 - r0) * grow

            // Keep it hugging the ground
            let squash: CGFloat = 0.55

            // Blob size (pretty big so you can’t miss it)
            let baseW: CGFloat = 34
            let baseH: CGFloat = 22
            let scale: CGFloat = 1.0 + 0.15 * grow
            let w: CGFloat = baseW * scale
            let h: CGFloat = baseH * scale

            
            #if DEBUG
            // DEBUG: center marker so we know we're drawing at the right spot
            context.fill(
                Path(ellipseIn: CGRect(x: originX - 3, y: groundY - 2, width: 6, height: 4)),
                with: .color(.green)
            )
            #endif

            // Even ring of blobs around the coin base
            let n: Int = max(20, count)
            for i in 0..<n {
                @inline(__always) func cosD(_ a: CGFloat) -> CGFloat { CGFloat(cos(Double(a))) }
                @inline(__always) func sinD(_ a: CGFloat) -> CGFloat { CGFloat(sin(Double(a))) }
                @inline(__always) func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }
                
                let jitterAmp: CGFloat = .pi / 48   // ~3.75°
                let jitter = (CGFloat(i) * 1.618)   // golden-ratio step for blue-noise-ish spacing
                let angle = (2 * .pi) * (CGFloat(i) / CGFloat(n)) + sin(jitter) * jitterAmp

                
                let rNoise = (sin(jitter * 2.3) * 0.5 + 0.5)   // 0..1
                let rVar   = lerp( -3, 3, rNoise )             // ±6 pts
                let rr     = r + rVar
                let dx = cosD(angle) * rr
                let dy = -sinD(angle) * rr * squash - 6 * lift


                // Rect for one blob
                let rect = CGRect(
                    x: originX + dx - w/2,
                    y: groundY + dy - h/2,
                    width: w, height: h
                )
    


                // Main blob (make it bright for testing)
                context.fill(Path(ellipseIn: rect), with: .color(baseColor.opacity(0.95 * fade)))

                // Soft shadow just beneath
                context.fill(Path(ellipseIn: rect.offsetBy(dx: 0, dy: 1)),
                             with: .color(shadowColor.opacity(0.28 * fade)))
            }
            // ----- END -----


        }
        // Keep modifiers very short (big chains can trigger the error)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .blur(radius: 3) // soft but simple
    }
}
