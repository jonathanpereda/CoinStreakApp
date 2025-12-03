import SwiftUI

/// Full-screen overlay for the Call It minigame leaderboard.
/// This view is intended to be presented via `MinigameContext.presentOverlay`,
/// and will be rendered above the core game (including the coin) by the host.
struct CallItLeaderboardOverlay: View {
    let context: MinigameContext

    // Persistent best streak for the Call It minigame, shared with the main view.
    @AppStorage("callit_bestStreak") private var bestStreak: Int = 0

    // Local UI state for the rewards card glow pulse and rewards overlay visibility.
    @State private var rewardsGlowPhase: Double = 0.0
    @State private var isShowingRewards: Bool = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Full-screen leaderboard art. The PNG itself contains alpha so the
                // underlying Call It scene can show through in the desired areas.
                Image("callit_leaderboard")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .position(x: geo.size.width / 2.0, y: geo.size.height / 2.0)
                    .allowsHitTesting(false)

                // Exit card (top-left-ish), no float or shadow, rotated ~9.4°
                Image("callit_exit_card")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(
                        width: geo.size.width * (288.3 / 1320.0),
                        height: geo.size.height * (396.0 / 2868.0)
                    )
                    .position(
                        x: geo.size.width * ((260 / 2.0) / 1320.0),
                        y: geo.size.height * ((2240 + 396.0 / 2.0) / 2868.0)
                    )
                    .rotationEffect(.degrees(-9.4))
                    .onTapGesture {
                        Haptics.shared.tap()
                        context.dismissOverlay()
                    }

                // Rewards card with pulsing glow; opens a rewards overlay when tapped.
                Image("callit_rewards_card")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(
                        width: geo.size.width * (288.3 / 1320.0),
                        height: geo.size.height * (396.0 / 2868.0)
                    )
                    .position(
                        x: geo.size.width * ((840 + 288.3 / 2.0) / 1320.0),
                        y: geo.size.height * ((375 + 396.0 / 2.0) / 2868.0)
                    )
                    .rotationEffect(.degrees(-2.5))
                    .shadow(
                        color: Color(
                            red: 1.0,
                            green: 0.88,
                            blue: 0.75
                        ).opacity(0.3 + 0.2 * rewardsGlowPhase),
                        radius: 8 + 4 * rewardsGlowPhase,
                        x: 0,
                        y: 0
                    )
                    .onTapGesture {
                        Haptics.shared.tap()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isShowingRewards = true
                        }
                    }

                // Best streak card (top-right-ish), rotated ~353.2° with value text
                ZStack {
                    Image("callit_best_card")
                        .resizable()
                        .aspectRatio(contentMode: .fit)

                    Text("\(bestStreak)")
                        .font(
                            .custom(
                                "MacondoSwashCaps-Regular",
                                size: geo.size.height * (200.0 / 2868.0)
                            )
                        )
                        .foregroundColor(
                            Color(
                                red: 67.0 / 255.0,
                                green: 54.0 / 255.0,
                                blue: 40.0 / 255.0
                            )
                        )
                        // Nudge slightly downward within the card, scaled to screen
                        .offset(
                            y: geo.size.height * (14.0 / 2868.0)
                        )
                }
                .frame(
                    width: geo.size.width * (288.3 / 1320.0),
                    height: geo.size.height * (396.0 / 2868.0)
                )
                .position(
                    x: geo.size.width * ((50 + 288.3 / 2.0) / 1320.0),
                    y: geo.size.height * ((620 + 396.0 / 2.0) / 2868.0)
                )
                .rotationEffect(.degrees(-353.2))

                // Rewards overlay: dim the leaderboard and show the rewards art.
                if isShowingRewards {
                    ZStack {
                        Color.black.opacity(0.2)
                            .ignoresSafeArea()

                        Image("callit_rewards")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .position(x: geo.size.width / 2.0, y: geo.size.height / 2.0)
                            .allowsHitTesting(false)
                    }
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isShowingRewards = false
                        }
                    }
                }
            }
            .ignoresSafeArea()
            .onAppear {
                // Start a subtle pulsing glow for the rewards card.
                if rewardsGlowPhase == 0.0 {
                    withAnimation(
                        .easeInOut(duration: 2.6)
                            .repeatForever(autoreverses: true)
                    ) {
                        rewardsGlowPhase = 1.0
                    }
                }
            }
        }
    }
}
