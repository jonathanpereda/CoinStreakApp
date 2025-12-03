import SwiftUI

struct CallItMinigameView: View {
    let context: MinigameContext
    @ObservedObject private var manager: MinigameManager
    @State private var calledSide: String? = "h"
    @State private var glowPhase: Double = 0.0          // card glow / orb-related pulse
    @State private var textGlowPhase: Double = 0.0      // independent pulse for streak text
    // Persistent per-player streak values for the Call It minigame.
    // TODO: when wiring to the weekly-period backend, these should be reset
    // when a new Call It period begins so everyone starts fresh.
    @AppStorage("callit_calledStreak") private var calledStreak: Int = 0
    @AppStorage("callit_bestStreak") private var bestStreak: Int = 0
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
            if bestStreak < calledStreak {
                bestStreak = calledStreak
            }
        } else {
            calledStreak = 0
        }
    }

    var body: some View {
        ZStack {
            // Orb + cards locked to specific positions relative to the full screen
            GeometryReader { geo in
                ZStack {
                    // Called streak counter (below orb shine)
                    Text("\(calledStreak)")
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
                            0.5 + 0.25 * textGlowPhase   // pulse between 0.5 and 0.75
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
                        // Dim slightly when not the active call (but leave both normal when nothing is selected yet)
                        .saturation(
                            (calledSide != nil && calledSide != "h") ? 0.9 : 1.0
                        )
                        .brightness(
                            (calledSide != nil && calledSide != "h") ? -0.2 : 0.0
                        )
                        .onTapGesture {
                            guard !isSelectionLocked else { return }
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
                        .saturation(
                            (calledSide != nil && calledSide != "t") ? 0.9 : 1.0
                        )
                        .brightness(
                            (calledSide != nil && calledSide != "t") ? -0.2 : 0.0
                        )
                        .onTapGesture {
                            guard !isSelectionLocked else { return }
                            calledSide = "t"
                        }
                }
                .onAppear {
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

                        Text("\(bestStreak)")
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
            }
            // Fade the bottom cards out while a minigame overlay
            // is active, and bring them back when it is dismissed.
            .opacity(manager.activeOverlay == nil ? 1.0 : 0.0)
            .allowsHitTesting(manager.activeOverlay == nil)
            .animation(.easeInOut(duration: 0.2), value: manager.activeOverlay == nil)
        }
    }
}
