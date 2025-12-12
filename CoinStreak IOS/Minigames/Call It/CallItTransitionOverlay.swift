import SwiftUI

struct CallItTransitionOverlay: View {
    /// Controls whether this overlay is shown at all.
    @Binding var isActive: Bool
    let isPaused : Bool
    let exitTrigger: Int

    @State private var lastExitTrigger: Int = 0
    @State private var isExiting: Bool = false
    
    /// Opacity of the overall blackout layer (0–1).
    @State private var blackoutOpacity: Double = 0.0

    /// 0 → no candle reveal, 1 → fully expanded candle “light” area.
    @State private var revealProgress: CGFloat = 0.0
    @State private var flickerPhaseLeft: CGFloat = 0.0
    @State private var flickerPhaseRight: CGFloat = 0.0

    var body: some View {
        GeometryReader { geo in
            // Your usual design size
            let designWidth: CGFloat = 1320
            let designHeight: CGFloat = 2868

            let scaleX = geo.size.width / designWidth
            let scaleY = geo.size.height / designHeight
            let scale = min(scaleX, scaleY)

            let candle1Design = CGPoint(x: 63, y: 1073)  // left candle (design-space)
            let candle2Design = CGPoint(x: 1290, y: 1073)  // right candle (design-space)

            let candle1Point = CGPoint(
                x: candle1Design.x * scaleX,
                y: candle1Design.y * scaleY
            )
            let candle2Point = CGPoint(
                x: candle2Design.x * scaleX,
                y: candle2Design.y * scaleY
            )

            // Soft-edged mask around the central text (fixed size, design-space).
            let textMaskDesignCenter = CGPoint(x: 668.0, y: 1106.0)
            let textMaskPoint = CGPoint(
                x: textMaskDesignCenter.x * scaleX,
                y: textMaskDesignCenter.y * scaleY
            )
            let textMaskRadius: CGFloat = (538.0 / 2.0) * scale

            // Strength of the text mask:
            // - stays off during the initial flicker (revealProgress ≈ 0)
            // - fades in during the candle reveal as the blackout eases out
            // - is forced off during the exit transition
            let textMaskRevealFactor = max(0.0, min(1.0, revealProgress))
            let textMaskDimFactor = max(0.0, min(1.0, 1.0 - blackoutOpacity))
            let textMaskStrength = isExiting ? 0.0 : (textMaskRevealFactor * textMaskDimFactor)

            let minRadius: CGFloat = 2 * scale      // tiny, very close to the flame
            let maxRadius: CGFloat = 600 * scale     // final reach of the candle light 1800

            ZStack {
                // Base darkness
                Color.black
                    .opacity(blackoutOpacity)

                let t = max(0, min(1, revealProgress))
                // Linear bloom: grow radius at a constant rate over revealProgress.
                let baseRadius = minRadius + (maxRadius - minRadius) * t

                // LEFT candle: its own subtle, slightly random flicker
                let flickerScaleLeft: CGFloat = revealProgress >= 0.999
                    ? (0.97 + 0.06 * flickerPhaseLeft)  // Map [0, 1] -> [0.97, 1.03]
                    : 1.0
                let leftRadius = baseRadius * flickerScaleLeft

                RadialGradient(
                    gradient: Gradient(colors: [.white, .clear]),
                    center: .center,
                    startRadius: 0,
                    endRadius: leftRadius
                )
                .frame(width: leftRadius * 2, height: leftRadius * 2)
                .position(candle1Point)
                .blendMode(.destinationOut)

                // RIGHT candle: independent phase/amplitude so it doesn't pulse in sync
                let flickerScaleRight: CGFloat = revealProgress >= 0.999
                    ? (0.965 + 0.07 * flickerPhaseRight) // Slightly different range
                    : 1.0
                let rightRadius = baseRadius * flickerScaleRight

                RadialGradient(
                    gradient: Gradient(colors: [.white, .clear]),
                    center: .center,
                    startRadius: 0,
                    endRadius: rightRadius
                )
                .frame(width: rightRadius * 2, height: rightRadius * 2)
                .position(candle2Point)
                .blendMode(.destinationOut)

                // Additional soft-edged mask around the central text area.
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(textMaskStrength),
                        .clear
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: textMaskRadius
                )
                .frame(width: textMaskRadius * 2, height: textMaskRadius * 2)
                .position(textMaskPoint)
                .blendMode(.destinationOut)

                let leftGlowRadius = leftRadius * 1.05
                let rightGlowRadius = rightRadius * 1.05

                // Soft candle glows (LEFT + RIGHT), but only visible below a horizontal
                // cutoff line. We compute that cutoff from the design-space Y = 1344.
                let designCutoffY: CGFloat = 1344
                let cutoffY = designCutoffY * scaleY

                // Primary halos are restricted to below the cutoff line…
                ZStack {
                    // LEFT glow (primary candle halo)
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color(red: 1.0, green: 0.55, blue: 0.10).opacity(0.4),
                            .clear
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: leftGlowRadius
                    )
                    .frame(width: leftGlowRadius * 2, height: leftGlowRadius * 2)
                    .position(candle1Point)
                    .opacity(0.8)
                    .blendMode(.screen)

                    // RIGHT glow (primary candle halo)
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color(red: 1.0, green: 0.55, blue: 0.10).opacity(0.4),
                            .clear
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: rightGlowRadius
                    )
                    .frame(width: rightGlowRadius * 2, height: rightGlowRadius * 2)
                    .position(candle2Point)
                    .opacity(0.8)
                    .blendMode(.screen)
                }
                .mask(
                    // Only show the primary halos in the region below the cutoff line.
                    Rectangle()
                        .frame(width: geo.size.width,
                               height: max(0, geo.size.height - cutoffY))
                        .position(
                            x: geo.size.width / 2,
                            y: cutoffY + max(0, geo.size.height - cutoffY) / 2
                        )
                )

                // …but the secondary, larger washes are allowed to extend above it.
                ZStack {
                    // LEFT secondary glow — larger, softer wash to light more of the scene.
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color(red: 1.0, green: 0.75, blue: 0.40).opacity(0.07),
                            .clear
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: leftGlowRadius * 2.0
                    )
                    .frame(width: leftGlowRadius * 4, height: leftGlowRadius * 4)
                    .position(candle1Point)
                    .blendMode(.screen)

                    // RIGHT secondary glow — larger, softer wash to light more of the scene.
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color(red: 1.0, green: 0.75, blue: 0.40).opacity(0.07),
                            .clear
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: rightGlowRadius * 2.0
                    )
                    .frame(width: rightGlowRadius * 4, height: rightGlowRadius * 4)
                    .position(candle2Point)
                    .blendMode(.screen)
                }
            }
            .opacity(isPaused ? 0.0 : 1.0)
            .compositingGroup()
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .onAppear {
                blackoutOpacity = 0.0
                revealProgress = 0.0
                runFlickerAndReveal()
            }
            .onChange(of: exitTrigger) {_, newValue in
                guard newValue != lastExitTrigger else { return }
                lastExitTrigger = newValue
                runExitTransition()      // new: "lights off → swap → lights on"
            }
        }
    }

    /// Full flow: flicker → dead black → candle reveal → remove overlay.
    private func runFlickerAndReveal() {
        Task {
            SoundManager.shared.suspendCurrentLoop(fadeOut: 0.3)
            SoundManager.shared.play("callit_start_game", volume: 0.7)
            // --- Flicker phase (same vibe as before) ---
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.08)) {
                    blackoutOpacity = 0.65
                }
            }
            try? await Task.sleep(nanoseconds: 90_000_000) // 0.09s

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.06)) {
                    blackoutOpacity = 0.15
                }
            }
            try? await Task.sleep(nanoseconds: 70_000_000) // 0.07s

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.10)) {
                    blackoutOpacity = 0.80
                }
            }
            try? await Task.sleep(nanoseconds: 110_000_000) // 0.11s

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.06)) {
                    blackoutOpacity = 0.30
                }
            }
            try? await Task.sleep(nanoseconds: 70_000_000) // 0.07s

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.14)) {
                    blackoutOpacity = 1.0
                }
            }

            // Short pause fully dark so we can safely “swap” to the Call It screen underneath
            try? await Task.sleep(nanoseconds: 450_000_000) // 0.45s

            // --- Candle reveal phase ---
            // Here we both:
            // - grow the radial “holes” around each candle
            // - fade out the remaining darkness
            await MainActor.run {
                withAnimation(.linear(duration: 2.4)) {
                    revealProgress = 1.0
                }
            }
            await MainActor.run {
                withAnimation(.easeOut(duration: 6)) {
                    blackoutOpacity = 0.30
                }
            }
            SoundManager.shared.startLoop(named: "callit_hum", volume: 1.0, fadeIn: 0.6)
            // Let the reveal settle a bit, then start a subtle, randomized candle flicker.
            try? await Task.sleep(nanoseconds: 800_000_000)

            while isActive && !isExiting {
                // Small random jitter every ~0.12s
                try? await Task.sleep(nanoseconds: 120_000_000)

                await MainActor.run {
                    let nextLeft = CGFloat.random(in: 0.0...1.0)
                    let nextRight = CGFloat.random(in: 0.0...1.0)

                    withAnimation(.easeInOut(duration: 0.12)) {
                        flickerPhaseLeft = nextLeft
                        flickerPhaseRight = nextRight
                    }
                }
            }
            /*try? await Task.sleep(nanoseconds: 120_000_000)
            isActive = false*/
        }
    }
    
    /// EXIT flow: go to full black, hold while main game is underneath,
    /// then flicker the lights back on and finally dismiss the overlay.
    private func runExitTransition() {
        Task {
            await MainActor.run {
                // Mark that we're in the exit phase and immediately snap to
                // a full blackout, so the underlying swap from the Call It
                // minigame back to the main game is never visible.
                isExiting = true
                revealProgress = 0.0
                blackoutOpacity = 1.0
            }
            SoundManager.shared.stopLoop(fadeOut: 0.3)
            SoundManager.shared.resumeSuspendedLoop(fadeIn: 0.6)
            SoundManager.shared.play("callit_exit_game", volume: 0.7)

            // 2) Hold black so the main game can be visible underneath.
            try? await Task.sleep(nanoseconds: 350_000_000) // 0.35s

            // 3) "Lights flicker on" — overhead lights stuttering back to life.
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.05)) {
                    blackoutOpacity = 0.70   // first pop of light
                }
            }
            try? await Task.sleep(nanoseconds: 60_000_000)

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.04)) {
                    blackoutOpacity = 0.95   // drop back toward full dark
                }
            }
            try? await Task.sleep(nanoseconds: 50_000_000)

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.07)) {
                    blackoutOpacity = 0.45   // stronger light
                }
            }
            try? await Task.sleep(nanoseconds: 70_000_000)

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.05)) {
                    blackoutOpacity = 0.85   // one more stutter
                }
            }
            try? await Task.sleep(nanoseconds: 60_000_000)

            await MainActor.run {
                withAnimation(.easeOut(duration: 0.10)) {
                    blackoutOpacity = 0.08   // lights basically on, slight ambient darkness
                }
            }

            // Let it breathe for a moment.
            try? await Task.sleep(nanoseconds: 250_000_000)

            // 4) Finally remove the overlay.
            await MainActor.run {
                isActive = false
            }
        }
    }
}
