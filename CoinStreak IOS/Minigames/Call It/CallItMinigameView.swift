
import SwiftUI

struct CallItFlameView: View {
    private let frameNames: [String] = [
        "callit_flame_0",
        "callit_flame_1",
        "callit_flame_2",
        "callit_flame_3",
        "callit_flame_4",
        "callit_flame_5",
        "callit_flame_6"
    ]

    /// Optional initial delay so multiple flames can be desynchronized.
    let initialDelay: TimeInterval
    /// Whether this flame should play the "grow in" intro animation on appear.
    let enableIntro: Bool

    @State private var frameIndex: Int = 0
    /// 1 = default (bend to the right), -1 = flipped (bend to the left).
    @State private var direction: CGFloat = 1.0
    /// Overall flame opacity, gently pulsing to mimic natural brightness changes.
    @State private var flameOpacity: Double = 1.0
    /// Intro scale used so the flame "grows in" when the minigame starts.
    @State private var introScale: CGFloat = 0.0
    /// Ensure we only run the intro scale animation once per view lifetime.
    @State private var didRunIntroScale: Bool = false

    init(initialDelay: TimeInterval = 0, enableIntro: Bool = true) {
        self.initialDelay = initialDelay
        self.enableIntro = enableIntro
    }

    var body: some View {
        Image(frameNames[frameIndex])
            .resizable()
            .scaledToFit()
            // First apply the left/right flip.
            .scaleEffect(x: direction, y: 1.0)
            // Then apply the intro grow scale uniformly from the base of the flame.
            .scaleEffect(introScale, anchor: .bottom)
            // Gentle overall brightness pulse, independent of the frame.
            .opacity(flameOpacity)
            .onAppear {
                // Only run the intro grow animation once, and only if this instance
                // has intro enabled. This preserves existing behavior for the Call-It
                // minigame flames, while allowing other callers (like the leaderboard)
                // to present a fully-grown flame immediately.
                if enableIntro {
                    if !didRunIntroScale {
                        didRunIntroScale = true
                        introScale = 0.0

                        // Two-stage "fire starting" growth:
                        // 1) Slowly grow from 0 -> ~0.3–0.4
                        // 2) Then more quickly from ~0.3–0.4 -> 1.0
                        Task {
                            // Stage 1: small, slow growth
                            await MainActor.run {
                                withAnimation(.easeOut(duration: 0.9)) {
                                    introScale = 0.3
                                }
                            }

                            // Wait roughly for stage 1 to finish
                            try? await Task.sleep(
                                nanoseconds: UInt64(0.75 * 1_000_000_000)
                            )

                            // Stage 2: faster, more energetic growth to full size
                            await MainActor.run {
                                withAnimation(.easeOut(duration: 0.55)) {
                                    introScale = 1.0
                                }
                            }
                        }
                    }
                } else {
                    // No intro: ensure the flame is at full size immediately.
                    introScale = 1.0
                    didRunIntroScale = true
                }

                startFlameLoop()
                startFlameOpacityLoop()
            }
    }

    private func startFlameLoop() {
        Task {
            if initialDelay > 0 {
                try? await Task.sleep(
                    nanoseconds: UInt64(initialDelay * 1_000_000_000)
                )
            }

            // Logical index in the range -6 ... 6:
            // negative = bent to the left, positive = bent to the right, 0 = straight.
            var logicalIndex: Int = 0
            
            // Track the previous logical index and whether the last step was a "bounce"
            // (i.e., we moved directly back to the previous frame).
            var previousLogicalIndex: Int? = nil
            var didBounceLastStep: Bool = false

            while true {
                // Decide a proposed next logical index based on the current one.
                let proposedIndex: Int
                switch logicalIndex {
                case 0:
                    // At center, 50/50 chance to move to +1 or -1.
                    proposedIndex = Bool.random() ? 1 : -1

                case 1:
                    // At +1, 60% back toward center, 40% deeper bend.
                    let roll = Double.random(in: 0...1)
                    proposedIndex = (roll < 0.6) ? 0 : 2

                case 2:
                    // At +2, 70% back toward center side, 30% deeper bend.
                    let roll = Double.random(in: 0...1)
                    proposedIndex = (roll < 0.7) ? 1 : 3

                case 3:
                    // At +3, 80% back inward, 20% chance to bend further.
                    let roll = Double.random(in: 0...1)
                    proposedIndex = (roll < 0.8) ? 2 : 4

                case 4:
                    // At +4, 90% back inward, 10% chance to bend further.
                    let roll = Double.random(in: 0...1)
                    proposedIndex = (roll < 0.9) ? 3 : 5

                case 5:
                    // At +5, strongly prefers to come back in, rarely goes to max bend.
                    let roll = Double.random(in: 0...1)
                    proposedIndex = (roll < 0.95) ? 4 : 6

                case 6:
                    // At +6 (max bend), always move back toward +5.
                    proposedIndex = 5

                case -1:
                    // Mirror of +1: 60% back to center, 40% further out.
                    let roll = Double.random(in: 0...1)
                    proposedIndex = (roll < 0.6) ? 0 : -2

                case -2:
                    // Mirror of +2: 70% back in, 30% further out.
                    let roll = Double.random(in: 0...1)
                    proposedIndex = (roll < 0.7) ? -1 : -3

                case -3:
                    // Mirror of +3: 80% back inward, 20% further out.
                    let roll = Double.random(in: 0...1)
                    proposedIndex = (roll < 0.8) ? -2 : -4

                case -4:
                    // Mirror of +4: 90% back inward, 10% further out.
                    let roll = Double.random(in: 0...1)
                    proposedIndex = (roll < 0.9) ? -3 : -5

                case -5:
                    // Mirror of +5: strongly prefers in, rarely goes to max bend.
                    let roll = Double.random(in: 0...1)
                    proposedIndex = (roll < 0.95) ? -4 : -6

                case -6:
                    // Mirror of +6: always move back toward -5.
                    proposedIndex = -5

                default:
                    // Safety net: if we ever get out of range, snap to center.
                    proposedIndex = 0
                }

                // Apply the "no two bounce-backs in a row" rule.
                var nextLogicalIndex = proposedIndex
                if let prev = previousLogicalIndex {
                    let isBounce = (nextLogicalIndex == prev)
                    if isBounce && didBounceLastStep {
                        // We are about to bounce back to the last frame again (A-B-A-B...),
                        // so choose the other neighbor if possible.
                        let cur = logicalIndex

                        if cur == 0 {
                            // Neighbors are -1 and +1; avoid going back to prev twice.
                            nextLogicalIndex = (prev == -1) ? 1 : -1
                        } else if cur > 0 {
                            // Positive side: neighbors are roughly (cur - 1) and (cur + 1), clamped.
                            let inward = max(0, cur - 1)
                            let outward = min(6, cur + 1)

                            if prev == inward && outward != inward {
                                nextLogicalIndex = outward
                            } else if prev == outward && inward != outward {
                                nextLogicalIndex = inward
                            }
                        } else { // cur < 0
                            // Negative side: neighbors are roughly (cur + 1) and (cur - 1), clamped.
                            let inward = min(0, cur + 1)
                            let outward = max(-6, cur - 1)

                            if prev == inward && outward != inward {
                                nextLogicalIndex = outward
                            } else if prev == outward && inward != outward {
                                nextLogicalIndex = inward
                            }
                        }
                    }
                }

                // Update bounce tracking for the next step.
                let thisStepIsBounce = (previousLogicalIndex != nil && nextLogicalIndex == previousLogicalIndex)
                didBounceLastStep = thisStepIsBounce
                previousLogicalIndex = logicalIndex
                logicalIndex = nextLogicalIndex

                // Map the logical index (-6...6) to a sprite index (0...6) and direction.
                let spriteIndex = min(6, max(0, abs(logicalIndex)))
                let spriteDirection: CGFloat = (logicalIndex >= 0) ? 1.0 : -1.0

                await MainActor.run {
                    // Update direction and frame index without animating between frames.
                    // This avoids any implicit cross-fade or layout interpolation that
                    // can make the flame feel like it's "flashing" when it changes pose.
                    direction = spriteDirection
                    frameIndex = spriteIndex
                }

                // Steady timing with very small jitter so it feels organic but not flickery.
                let baseDelay: Double = 0.14
                let jitter: Double = Double.random(in: -0.004...0.004)
                let delay = max(0.11, baseDelay + jitter)

                try? await Task.sleep(
                    nanoseconds: UInt64(delay * 1_000_000_000)
                )
            }
        }
    }

    /// Gentle, randomized opacity pulsing so the flame looks like it's subtly brightening
    /// and dimming over time. This is independent of the pose / frameIndex.
    private func startFlameOpacityLoop() {
        Task {
            while true {
                // Choose a new target opacity in a narrow band so it never fully "blinks".
                // Think of this as small brightness breathing: ~0.82 - 1.0.
                let targetOpacity = Double.random(in: 0.65...0.9)

                // Randomize how long it takes to ease to that brightness.
                let duration = Double.random(in: 0.22...0.45)

                await MainActor.run {
                    withAnimation(.easeInOut(duration: duration)) {
                        flameOpacity = targetOpacity
                    }
                }

                // Hold / drift at that level for roughly the same duration, plus a tiny jitter.
                let holdExtra = Double.random(in: 0.03...0.10)
                let sleepTime = duration + holdExtra

                try? await Task.sleep(
                    nanoseconds: UInt64(sleepTime * 1_000_000_000)
                )
            }
        }
    }
}

struct CallItMinigameView: View {
    let context: MinigameContext
    @ObservedObject private var manager: MinigameManager
    @State private var calledSide: String? = "h"
    @State private var glowPhase: Double = 0.0          // card glow / orb-related pulse
    @State private var textGlowPhase: Double = 0.0      // independent pulse for streak text
    // Persistent per-player streak values for the Call It minigame.
    // These are scoped per-weekly period so that each new Call It period starts fresh.
    @AppStorage("callit_calledStreak") private var calledStreak: Int = 0
    @AppStorage("callit_bestStreak") private var bestStreak: Int = 0
    @AppStorage("callit_alltime_best") private var alltimeBestStreak: Int = 0

    // Track the last Call It minigame period id we've seen so we can reset
    // the local streaks when the backend rotates to a new period.
    @AppStorage("callit_lastPeriodId") private var lastCallItPeriodId: String = ""
    @State private var isSelectionLocked: Bool = false
    @State private var glowStarted: Bool = false
    @State private var textGlowStarted: Bool = false

    // Bottom HUD card float offsets & rotations
    @State private var exitCardFloatOffset: CGFloat = 0
    @State private var leaderboardCardFloatOffset: CGFloat = 0
    @State private var bestCardFloatOffset: CGFloat = 0

    @State private var exitCardRotation: Double = 0
    @State private var leaderboardCardRotation: Double = 0
    @State private var bestCardRotation: Double = 0

    @State private var cardFloatStarted: Bool = false
    /// Controls when the Exit button becomes tappable after the view appears.
    @State private var isExitButtonEnabled: Bool = false

    init(context: MinigameContext) {
        self.context = context
        self._manager = ObservedObject(wrappedValue: context.manager)
    }

    private func startGlowAnimation() {
        glowPhase = 0.0
        withAnimation(
            .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true)
        ) {
            glowPhase = 1.0
        }
    }

    private func startTextGlowAnimation() {
        // Only start the repeatForever animation once for the text; don't restart on state changes
        guard !textGlowStarted else { return }
        textGlowStarted = true

        textGlowPhase = 0.0
        withAnimation(
            .easeInOut(duration: 2.6)
                .repeatForever(autoreverses: true)
        ) {
            textGlowPhase = 1.0
        }
    }

    private func startCardFloatAnimations() {
        // Only start the repeatForever animations once
        guard !cardFloatStarted else { return }
        cardFloatStarted = true

        let h = UIScreen.main.bounds.height

        // Subtle, slightly different vertical loops so the cards feel alive but not distracting
        withAnimation(
            .easeInOut(duration: 2.4)
                .repeatForever(autoreverses: true)
        ) {
            exitCardFloatOffset = -h * (7.5 / 2868.0)
        }

        withAnimation(
            .easeInOut(duration: 2.8)
                .repeatForever(autoreverses: true)
        ) {
            leaderboardCardFloatOffset = -h * (9.5 / 2868.0)
        }

        withAnimation(
            .easeInOut(duration: 3.0)
                .repeatForever(autoreverses: true)
        ) {
            bestCardFloatOffset = -h * (6.5 / 2868.0)
        }

        // Very subtle independent clockwise / counterclockwise rocking for each card.
        // Use small symmetric angles so each card rocks between both directions.
        exitCardRotation = -0.8
        withAnimation(
            .easeInOut(duration: 3.0)
                .repeatForever(autoreverses: true)
        ) {
            exitCardRotation = 0.8   // rocks between -2.5° and +2.5°
        }

        leaderboardCardRotation = -0.4
        withAnimation(
            .easeInOut(duration: 3.4)
                .repeatForever(autoreverses: true)
        ) {
            leaderboardCardRotation = 0.4  // rocks between -2.0° and +2.0°
        }

        bestCardRotation = -0.6
        withAnimation(
            .easeInOut(duration: 3.2)
                .repeatForever(autoreverses: true)
        ) {
            bestCardRotation = 0.6   // rocks between -1.8° and +1.8°
        }
    }

    // MARK: - Call-It game logic helpers

    /// Lock the current card choice while a flip is in progress so the player can't switch mid-air.
    private func lockSelectionForFlip() {
        isSelectionLocked = true
    }

    /// Unlock the card choice and update the called streak based on the flip result.
    /// - Parameter landedOnHeads: true if the flip result was heads, false if tails.
    private func handleFlipResult(landedOnHeads: Bool) {
        isSelectionLocked = false

        // Default to "h" if something weird happens and we have no current call.
        let currentCall = calledSide ?? "h"
        let didWin = (landedOnHeads && currentCall == "h") || (!landedOnHeads && currentCall == "t")

        if didWin {
            calledStreak += 1
            let pitch = Float(calledStreak - 1) * 1.0
            // Update local best for the Call It minigame.
            if bestStreak < calledStreak {
                bestStreak = calledStreak
                if bestStreak >= 5 {
                    SoundManager.shared.play("callit_new_best")
                } else {
                    SoundManager.shared.playPitched(base: "callit_streak_base_pitch", semitoneOffset: pitch)
                }
            } else {
                SoundManager.shared.playPitched(base: "callit_streak_base_pitch", semitoneOffset: pitch)
            }
            if alltimeBestStreak < calledStreak {
                alltimeBestStreak = calledStreak
            }

            // Report runs that are at least as good as our current best to the backend.
            // MinigameManager.submitRun will optimistically skip scores that are clearly worse
            // than the server-known best, but will still allow ties to refresh recency.
            if calledStreak > 0 {
                context.submit(score: calledStreak)
            }
        } else {
            // Wrong call: streak resets.
            if calledStreak >= 6 {
                SoundManager.shared.play("callit_lose_streak")
            }
            calledStreak = 0
            SoundManager.shared.play(["land_1","land_2"].randomElement()!)
        }
    }

    /// Ensure local streaks are reset when a new Call It minigame period begins.
    /// This is driven by the period id coming from MinigameManager / backend.
    private func resetStreaksIfNeededForCurrentPeriod() {
        // If the manager doesn't yet know about an active period, do nothing.
        guard let currentId = manager.activePeriod?.id, !currentId.isEmpty else {
            return
        }

        // If we've already seen this period id, keep the existing streak values.
        if lastCallItPeriodId == currentId {
            return
        }

        // New period detected for Call It: clear local streaks and remember the id.
        calledStreak = 0
        bestStreak = 0
        lastCallItPeriodId = currentId
    }

    // Computed display helpers: clamp to 0 if the backend has rotated us into a new period
    // or if the current period is unknown but we've already seen a period before, so we
    // never show stale values between period transitions.
    private var displayCalledStreak: Int {
        // If we don't yet know the current period id, decide based on whether
        // we've ever seen any period before. On a truly first run (no stored
        // lastCallItPeriodId), show whatever is persisted. Once we've ever
        // recorded a period id, treat an unknown/cleared activePeriod as 0 so
        // we don't bounce between old values and the new-period clamp.
        guard let currentId = manager.activePeriod?.id, !currentId.isEmpty else {
            return lastCallItPeriodId.isEmpty ? calledStreak : 0
        }

        // If the backend has rotated us into a new period but our persisted
        // streaks haven't been cleared yet, clamp the visual display to 0.
        if currentId != lastCallItPeriodId {
            return 0
        }

        // Normal case: currentId matches the last period we know about; show
        // the persisted streak value for this period.
        return calledStreak
    }

    private var displayBestStreak: Int {
        guard let currentId = manager.activePeriod?.id, !currentId.isEmpty else {
            return lastCallItPeriodId.isEmpty ? bestStreak : 0
        }

        if currentId != lastCallItPeriodId {
            return 0
        }

        return bestStreak
    }

    var body: some View {
        ZStack {
            // Orb + cards locked to specific positions relative to the full screen
            GeometryReader { geo in
                ZStack {
                    // Animated candle flames (left and right)
                    CallItFlameView(initialDelay: 0.0)
                        .frame(
                            width: geo.size.width * (90.0 / 1320.0),
                            height: geo.size.height * (170.0 / 2868.0)
                        )
                        .position(
                            x: geo.size.width * (85.0 / 1320.0),
                            y: geo.size.height * (1050.0 / 2868.0)
                        )
                        .allowsHitTesting(false)

                    CallItFlameView(initialDelay: 0.21)
                        .frame(
                            width: geo.size.width * (90.0 / 1320.0),
                            height: geo.size.height * (170.0 / 2868.0)
                        )
                        .position(
                            x: geo.size.width * (1270.0 / 1320.0),
                            y: geo.size.height * (1050.0 / 2868.0)
                        )
                        .allowsHitTesting(false)

                    // Called streak counter (below orb shine)
                    Text("\(displayCalledStreak)")
                        .font(.custom("MacondoSwashCaps-Regular", size: geo.size.height * (400.0 / 2868.0)))
                        .monospacedDigit()
                        .foregroundColor(
                            Color(
                                red: 135.0 / 255.0,
                                green: 94.0 / 255.0,
                                blue: 119.0 / 255.0
                            )
                        )
                        // Base text opacity gently pulsing
                        .opacity(
                            0.6 + 0.25 * textGlowPhase   // pulse between 0.6 and 0.85
                        )
                        // Strong pulsing glow (fixed at "max streak" strength)
                        .shadow(
                            color: {
                                // Core glow: same hue but much brighter
                                let base = Color(
                                    red: 230.0 / 255.0,
                                    green: 200.0 / 255.0,
                                    blue: 235.0 / 255.0
                                )
                                let pulse = 0.9 + 0.10 * textGlowPhase  // small pulse
                                // Core opacity: fixed near max, pulsing a bit
                                let alpha = min(1.0, 1.0 * pulse)
                                return base.opacity(alpha)
                            }(),
                            radius: {
                                let pulse = 0.9 + 0.1 * textGlowPhase
                                // Core radius: fixed at the previous max (~22) with small pulse
                                return 22.0 * pulse
                            }()
                        )
                        .shadow(
                            color: {
                                // Outer halo: softer but still clearly visible, fixed at "max streak" strength
                                let base = Color(
                                    red: 230.0 / 255.0,
                                    green: 200.0 / 255.0,
                                    blue: 235.0 / 255.0
                                )
                                let pulse = 0.85 + 0.15 * textGlowPhase
                                // Outer opacity: fixed high, pulsing a bit
                                let alpha = min(1.0, 0.9 * pulse)
                                return base.opacity(alpha)
                            }(),
                            radius: {
                                let pulse = 0.9 + 0.1 * textGlowPhase
                                // Outer radius: fixed at previous max (~60) with small pulse
                                return 60.0 * pulse
                            }()
                        )
                        .position(
                            x: geo.size.width / 2.0,
                            y: geo.size.height * (1107.5 / 2868.0)
                        )
                        .allowsHitTesting(false)

                    // Orb shine
                    Image("callit_orb_shine")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(
                            width: geo.size.width * (459.0 / 1320.0),
                            height: geo.size.height * (456.0 / 2868.0)
                        )
                        .opacity(0.65)
                        .position(
                            x: geo.size.width * ((453.0 + 459.0 / 2.0) / 1320.0),
                            y: geo.size.height * ((898.0 + 456.0 / 2.0) / 2868.0)
                        )
                        .allowsHitTesting(false)

                    // H glow (behind H card, fades and gently pulses with selection)
                    Image("callit_card_h_glow")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(
                            width: geo.size.width * (553.0 / 1320.0),
                            height: geo.size.height * (424.0 / 2868.0)
                        )
                        .position(
                            x: geo.size.width * ((186.0 + 553.0 / 2.0) / 1320.0),
                            y: geo.size.height * ((1445.0 + 424.0 / 2.0) / 2868.0)
                        )
                        .opacity(
                            calledSide == "h"
                            ? (0.5 + 0.5 * glowPhase)   // pulse between 0.5 and 1.0
                            : 0.0
                        )
                        .allowsHitTesting(false)

                    // T glow (behind T card, fades and gently pulses with selection)
                    Image("callit_card_t_glow")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(
                            width: geo.size.width * (553.0 / 1320.0),
                            height: geo.size.height * (424.0 / 2868.0)
                        )
                        .position(
                            x: geo.size.width * ((605.0 + 553.0 / 2.0) / 1320.0),
                            y: geo.size.height * ((1445.0 + 424.0 / 2.0) / 2868.0)
                        )
                        .opacity(
                            calledSide == "t"
                            ? (0.5 + 0.5 * glowPhase)   // pulse between 0.5 and 1.0
                            : 0.0
                        )
                        .allowsHitTesting(false)


                    // H card
                    Image("callit_card_h")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(
                            width: geo.size.width * (368.7 / 1320.0),
                            height: geo.size.height * (224.0 / 2868.0)
                        )
                        // Add invisible padding so the tappable area is slightly larger than the art
                        .padding(.horizontal, geo.size.width * (40.0 / 1320.0))
                        .padding(.vertical, geo.size.height * (40.0 / 2868.0))
                        .contentShape(Rectangle())
                        .position(
                            x: geo.size.width * ((276.5 + 368.7 / 2.0) / 1320.0),
                            y: geo.size.height * ((1528.0 + 224.0 / 2.0) / 2868.0)
                        )
                        .shadow(
                            color: Color.black.opacity(0.2),
                            radius: 0,
                            x: 1.5 ,
                            y: 4
                        )
                        // Dim slightly when not the active call (but leave both normal when nothing is selected yet)
                        .saturation(
                            (calledSide != nil && calledSide != "h") ? 0.9 : 1.0
                        )
                        .brightness(
                            (calledSide != nil && calledSide != "h") ? -0.2 : 0.0
                        )
                        .onTapGesture {
                            guard !isSelectionLocked else { return }
                            SoundManager.shared.playTypingTick()
                            Haptics.shared.tap()
                            calledSide = "h"
                        }

                    // T card
                    Image("callit_card_t")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(
                            width: geo.size.width * (368.7 / 1320.0),
                            height: geo.size.height * (224.0 / 2868.0)
                        )
                        // Add invisible padding so the tappable area is slightly larger than the art
                        .padding(.horizontal, geo.size.width * (40.0 / 1320.0))
                        .padding(.vertical, geo.size.height * (40.0 / 2868.0))
                        .contentShape(Rectangle())
                        .position(
                            x: geo.size.width * ((698.5 + 368.7 / 2.0) / 1320.0),
                            y: geo.size.height * ((1528.0 + 224.0 / 2.0) / 2868.0)
                        )
                        .shadow(
                            color: Color.black.opacity(0.2),
                            radius: 0,
                            x: -1.5 ,
                            y: 4
                        )
                        .saturation(
                            (calledSide != nil && calledSide != "t") ? 0.9 : 1.0
                        )
                        .brightness(
                            (calledSide != nil && calledSide != "t") ? -0.2 : 0.0
                        )
                        .onTapGesture {
                            guard !isSelectionLocked else { return }
                            SoundManager.shared.playTypingTick()
                            Haptics.shared.tap()
                            calledSide = "t"
                        }
                }
                .onAppear {
                    // Make sure we reset local Call It streaks when a new weekly period begins.
                    resetStreaksIfNeededForCurrentPeriod()

                    startGlowAnimation()
                    startTextGlowAnimation()
                    
                    // Flip START: lock the current card choice so it can't be changed mid-air.
                    context.onFlipBegan {
                        DispatchQueue.main.async {
                            lockSelectionForFlip()
                        }
                    }

                    // Flip END: update streak based on whether the call was correct.
                    context.onFlipResult { result in
                        let landedOnHeads = (result == "Heads")
                        DispatchQueue.main.async {
                            handleFlipResult(landedOnHeads: landedOnHeads)
                        }
                    }
                }
                .onChange(of: calledSide) { _, _ in
                    startGlowAnimation()
                }
                .animation(.easeInOut(duration: 0.15), value: calledSide)
                // If the backend rotates to a new period while we're in this view,
                // also reset local streaks the next time the period id changes.
                .onChange(of: manager.activePeriod?.id) { _, _ in
                    resetStreaksIfNeededForCurrentPeriod()
                }
            }
            .ignoresSafeArea()

            // Top-aligned container for future Call It HUD / instructions, etc.
            VStack(spacing: 16) {
                /*
                if let best = context.myBestScore {
                    Text("Best this week: \(best)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                } else {
                    Text("No score yet this week.")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }*/
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(24)

            // MARK: CARD BUTTONS
            // Bottom HUD: card-style buttons
            VStack {
                Spacer()
                HStack(spacing: 24) {
                    Spacer()

                    // Exit card button
                    Image("callit_exit_card")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(
                            width: UIScreen.main.bounds.width * (288.3 / 1320.0),
                            height: UIScreen.main.bounds.height * (396.0 / 2868.0)
                        )
                        .offset(y: exitCardFloatOffset)
                        .rotationEffect(.degrees(exitCardRotation))
                        .shadow(
                            color: Color.black.opacity(0.35),
                            radius: 8,
                            x: 0,
                            y: 8
                        )
                        .onTapGesture {
                            // Ignore taps while a flip is in progress or until the initial
                            // safety delay has elapsed after the view appears.
                            guard !isSelectionLocked, isExitButtonEnabled else { return }
                            Haptics.shared.tap()
                            context.endSession()
                        }

                    // Leaderboard card button
                    Image("callit_leaderboard_card")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(
                            width: UIScreen.main.bounds.width * (288.3 / 1320.0),
                            height: UIScreen.main.bounds.height * (396.0 / 2868.0)
                        )
                        .offset(y: leaderboardCardFloatOffset)
                        .rotationEffect(.degrees(leaderboardCardRotation))
                        .shadow(
                            color: Color.black.opacity(0.35),
                            radius: 8,
                            x: 0,
                            y: 8
                        )
                        .onTapGesture {
                            guard !isSelectionLocked else { return }
                            SoundManager.shared.play("callit_open_leaderboard")
                            Haptics.shared.tap()
                            context.presentOverlay {
                                CallItLeaderboardOverlay(context: context)
                            }
                        }

                    // Best streak display card
                    ZStack {
                        Image("callit_best_card")
                            .resizable()
                            .aspectRatio(contentMode: .fit)

                        Text("\(displayBestStreak)")
                            .font(.custom("MacondoSwashCaps-Regular", size: UIScreen.main.bounds.height * (200.0 / 2868.0)))
                            .foregroundColor(
                                Color(
                                    red: 67.0 / 255.0,
                                    green: 54.0 / 255.0,
                                    blue: 40.0 / 255.0
                                )
                            )
                            .offset(
                                y: UIScreen.main.bounds.height * (14.0 / 2868.0)
                            )
                            //.opacity(0.9)
                    }
                    .frame(
                        width: UIScreen.main.bounds.width * (288.3 / 1320.0),
                        height: UIScreen.main.bounds.height * (396.0 / 2868.0)
                    )
                    .compositingGroup()
                    .offset(y: bestCardFloatOffset)
                    .rotationEffect(.degrees(bestCardRotation))
                    .shadow(
                        color: Color.black.opacity(0.35),
                        radius: 8,
                        x: 0,
                        y: 8
                    )

                    Spacer()
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
            .onAppear {
                startCardFloatAnimations()

                // Start a one-time delay before the Exit button becomes active.
                // This prevents accidental immediate exits right as the view appears.
                isExitButtonEnabled = false
                Task {
                    try? await Task.sleep(
                        nanoseconds: UInt64(2.2 * 1_000_000_000)
                    )
                    await MainActor.run {
                        isExitButtonEnabled = true
                    }
                }
            }
            // Fade the bottom cards out while a minigame overlay
            // is active, and bring them back when it is dismissed.
            .opacity(manager.activeOverlay == nil ? 1.0 : 0.0)
            .allowsHitTesting(manager.activeOverlay == nil)
            .animation(.easeInOut(duration: 0.2), value: manager.activeOverlay == nil)

            // MARK: - Offline overlay
            // If the device loses connectivity while in the minigame, show a blocking
            // overlay that explains the requirement and lets the player tap to exit.
            // We intentionally avoid showing this while a flip is mid-air so that
            // the flip result can still resolve and update the streak correctly.
            if !manager.isOnlineForMinigame && !isSelectionLocked {
                ZStack {
                    Color.black.opacity(0.75)
                        .ignoresSafeArea()

                    VStack(spacing: 20) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 80, weight: .regular))
                            .foregroundColor(.white.opacity(0.9))

                        Text("You must have an active internet connection to play this minigame")
                            .font(.system(size: 18, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 32)

                        Text("(Tap anywhere to exit)")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.white.opacity(0.75))
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    // Exit the minigame session when the user taps while offline.
                    Haptics.shared.tap()
                    context.endSession()
                }
                .zIndex(999)
            }
        }
    }
}
