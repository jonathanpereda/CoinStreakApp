import SwiftUI

/// Full-screen overlay for the Call It minigame leaderboard.
/// This view is intended to be presented via `MinigameContext.presentOverlay`,
/// and will be rendered above the core game (including the coin) by the host.
struct CallItLeaderboardOverlay: View {
    let context: MinigameContext
    @ObservedObject private var manager: MinigameManager
    
    // Persistent best streak for the Call It minigame, shared with the main view.
    @AppStorage("callit_bestStreak") private var bestStreak: Int = 0
    
    // Local UI state for the rewards card glow pulse and rewards overlay visibility.
    @State private var rewardsGlowPhase: Double = 0.0
    @State private var isShowingRewards: Bool = false
    
    // Fan-out animation progress for the bottom-right card stack (0 = stacked, 1 = fully fanned).
    @State private var fanProgress: CGFloat = 0.0
    
    // Local tick used to drive a live countdown display for the remaining time.
    @State private var countdownTick: Int = 0
    
    // Dimmed lighting layer + single candle glow (no intro reveal).
    @State private var blackoutOpacity: Double = 0.18
    @State private var candleFlickerPhase: CGFloat = 0.0
    @State private var hasStartedCandleFlicker: Bool = false
    
    init(context: MinigameContext) {
        self.context = context
        self._manager = ObservedObject(wrappedValue: context.manager)
    }
    
    var body: some View {
        GeometryReader { geo in
            // Characters representing the remaining time for this minigame, e.g. "07d23h".
            let timeChars = formattedTimeCharacters(for: manager.timeRemaining)
            
            // Design-space constants (matching your 1320 x 2868 layout).
            let designWidth: CGFloat = 1320.0
            let designHeight: CGFloat = 2868.0
            
            // Scale factors and candle origin for dim lighting.
            let scaleX = geo.size.width / designWidth
            let scaleY = geo.size.height / designHeight
            let scale = min(scaleX, scaleY)
            
            // Candle origin in design-space coordinates (158, 91) mapped to screen-space.
            let candleDesignPoint = CGPoint(x: 158.0, y: 91.0)
            let candlePoint = CGPoint(
                x: candleDesignPoint.x * scaleX,
                y: candleDesignPoint.y * scaleY
            )
            
            // Base radius for the candle light in screen-space.
            let candleBaseRadius: CGFloat = 750.0 * scale
            
            // Max region for each card's value character (in design-space pixels).
            // You specified a max of 32px wide and 44px tall in the 1320x2868 layout.
            let maxCharRegionWidth = geo.size.width * (30.0 / designWidth)
            let maxCharRegionHeight = geo.size.height * (44.0 / designHeight)
            
            // Bottom-right fan anchor position in design coordinates.
            // Treat this as the anchor around the bottom-left of the fan (roughly under the left-most card).
            let fanBaseXDesign: CGFloat = 870.0
            let fanBaseYDesign: CGFloat = 2550.0
            
            // Card size in design coordinates for the new playing cards.
            let fanCardWidthDesign: CGFloat = 281.9
            let fanCardHeightDesign: CGFloat = 395.3
            
            // From bottom to top: heart, spade, diamond, spade, heart, club.
            // NOTE: Assumes `callit_club_card` exists alongside the others.
            let fanCardImageNames: [String] = [
                "callit_heart_card",
                "callit_spade_card",
                "callit_diamond_card",
                "callit_spade_card",
                "callit_heart_card",
                "callit_club_card"
            ]
            
            // Horizontal offsets (in design-space X) for the fan, from bottom to top.
            // Very small spread so the cards mostly stay stacked, with just a hint of separation.
            let fanOffsetsDesign: [CGFloat] = [0.0, 24.0, 48.0, 72.0, 96.0, 120.0]
            
            // Vertical offsets (in design-space Y) for a very subtle rise as we move right.
            let fanYOffsetDesign: [CGFloat] = [0.0, -4.0, -8.0, -12.0, -16.0, -20.0]
            
            // Rotation angles (in degrees) for the fan, from bottom to top.
            // Left-most card leans left, cards gradually rotate right as they move right.
            let fanAngles: [Double] = [-18.0, -10.0, -4.0, 2.0, 8.0, 14.0]
            
            ZStack {
                // Full-screen leaderboard art. The PNG itself contains alpha so the
                // underlying Call It scene can show through in the desired areas.
                Image("callit_leaderboard")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .position(x: geo.size.width / 2.0, y: geo.size.height / 2.0)
                    .allowsHitTesting(false)

                // Animated candle flame for the leaderboard overlay (no intro sequence).
                CallItFlameView(initialDelay: 0.0, enableIntro: false)
                    .frame(
                        width: geo.size.width * (40.0 / designWidth),
                        height: geo.size.height * (70.0 / designHeight)
                    )
                    .position(
                        x: geo.size.width * (162.0 / designWidth),
                        y: geo.size.height * (86.0 / designHeight)
                    )
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
                        SoundManager.shared.play("callit_close_leaderboard")
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
                        SoundManager.shared.play("callit_open_rewards")
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
                
                // Leaderboard container: shows up to top 10 players, with placeholder rows
                // for the first 5 ranks when there are no players.
                let leaderboardWidth = geo.size.width * (600.0 / designWidth)
                let leaderboardHeight = geo.size.height * (710.0 / designHeight)
                let leaderboardX = geo.size.width * ((422.0 + 600.0 / 2.0) / designWidth)
                let leaderboardY = geo.size.height * ((1426.0 + 710.0 / 2.0) / designHeight)
                
                let leaderboardEntries = manager.leaderboard
                let maxRows = min(10, max(leaderboardEntries.count, 5))
                
                let baseTextColor = Color(
                    red: 59.0 / 255.0,
                    green: 55.0 / 255.0,
                    blue: 51.0 / 255.0
                ) // #3B3733
                let scoreTextColor = Color(
                    red: 67.0 / 255.0,
                    green: 54.0 / 255.0,
                    blue: 40.0 / 255.0
                )
                
                // Larger font for better readability.
                let rowFontSize = geo.size.height * (80.0 / designHeight)
                let rowSpacing = geo.size.height * (10.0 / designHeight)
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: rowSpacing) {
                        ForEach(1...maxRows, id: \.self) { rank in
                            // Look up the entry for this rank (if any).
                            let entry = leaderboardEntries.first(where: { $0.rank == rank })
                            
                            if let entry {
                                HStack(spacing: geo.size.width * (2.0 / designWidth)) {
                                    // Rank column
                                    Text("\(entry.rank).")
                                        .font(
                                            .custom(
                                                "ReenieBeanie",
                                                size: rowFontSize
                                            )
                                        )
                                        .foregroundColor(baseTextColor)
                                        .lineLimit(1)
                                        .frame(
                                            width: leaderboardWidth * 0.15,
                                            alignment: .leading
                                        )
                                    
                                    // Name column
                                    Text(entry.displayName)
                                        .font(
                                            .custom(
                                                "ReenieBeanie",
                                                size: rowFontSize
                                            )
                                        )
                                        .foregroundColor(baseTextColor)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .frame(
                                            width: leaderboardWidth * 0.56,
                                            alignment: .leading
                                        )
                                    
                                    // Separator dash with a regular-sized region
                                    Text("-")
                                        .font(
                                            .custom(
                                                "ReenieBeanie",
                                                size: rowFontSize
                                            )
                                        )
                                        .foregroundColor(baseTextColor)
                                        .lineLimit(1)
                                        .frame(
                                            width: leaderboardWidth * 0.04,
                                            alignment: .center
                                        )
                                    
                                    // Score column
                                    Text("\(entry.score)")
                                        .font(
                                            .custom(
                                                "ReenieBeanie",
                                                size: rowFontSize
                                            )
                                        )
                                        .foregroundColor(scoreTextColor)
                                        .lineLimit(1)
                                        .frame(
                                            width: leaderboardWidth * 0.245,
                                            alignment: .trailing
                                        )
                                }
                            } else if rank <= 5 {
                                // Placeholder row for missing players among the first 5 ranks.
                                Text("\(rank).  ~ ~ ~ ~ ~ ~")
                                    .font(
                                        .custom(
                                            "ReenieBeanie",
                                            size: rowFontSize
                                        )
                                    )
                                    .foregroundColor(baseTextColor)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .frame(
                                        width: leaderboardWidth,
                                        alignment: .leading
                                    )
                            }
                        }
                    }
                    .frame(width: leaderboardWidth, alignment: .topLeading)
                }
                .frame(width: leaderboardWidth, height: leaderboardHeight, alignment: .topLeading)
                .position(x: leaderboardX, y: leaderboardY)
                
                // Bottom-right fanned stack of Call It playing cards.
                // From bottom to top: heart, spade, diamond, spade, heart, club.
                ZStack(alignment: .bottomLeading) {
                    ForEach(fanCardImageNames.indices, id: \.self) { idx in
                        let imageName = fanCardImageNames[idx]
                        let angle = fanAngles[idx]
                        
                        // Choose text color based on suit: hearts/diamonds = red-ish, spades/clubs = dark brown.
                        let isRedSuit =
                        imageName.contains("heart") || imageName.contains("diamond")
                        let valueColor = isRedSuit
                        ? Color(
                            red: 123.0 / 255.0,
                            green: 52.0 / 255.0,
                            blue: 42.0 / 255.0
                        ) // #7B342A
                        : Color(
                            red: 63.0 / 255.0,
                            green: 44.0 / 255.0,
                            blue: 26.0 / 255.0
                        ) // #3F2C1A
                        
                        ZStack(alignment: .topLeading) {
                            Image(imageName)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                            
                            // Time-remaining digit/character for this card position.
                            let ch: Character = idx < timeChars.count ? timeChars[idx] : " "
                            
                            Text(String(ch))
                                .font(
                                    .system(
                                        size: geo.size.height * (42.0 / designHeight)
                                    )
                                )
                                .foregroundColor(valueColor)
                            // Constrain the character to a fixed region and center the glyph
                            // within that region so wide characters (like "m") and narrow
                            // digits share the same visual origin.
                                .frame(
                                    width: maxCharRegionWidth,
                                    height: maxCharRegionHeight,
                                    alignment: .center
                                )
                                .minimumScaleFactor(0.4)
                                .lineLimit(1)
                            // Position the character region toward the top-left of the card,
                            // in design-space terms. The region stays fixed; the glyph
                            // centers inside it.
                                .padding(.top, geo.size.height * (15.0 / designHeight))
                                .padding(.leading, geo.size.width * (10.0 / designWidth))
                        }
                        // Apply a very small horizontal and vertical spread so the cards
                        // mostly stay stacked, but their top-left corners separate slightly.
                        .offset(
                            x: geo.size.width * (fanOffsetsDesign[idx] / designWidth) * fanProgress,
                            y: geo.size.height * (fanYOffsetDesign[idx] / designHeight) * fanProgress
                        )
                        .rotationEffect(
                            .degrees(angle * Double(fanProgress)),
                            anchor: .bottomLeading
                        )
                    }
                }
                // Size the whole stack like a single card; all cards share the same
                // bottom-left pivot inside this container.
                .frame(
                    width: geo.size.width * (fanCardWidthDesign / designWidth),
                    height: geo.size.height * (fanCardHeightDesign / designHeight)
                )
                .position(
                    x: geo.size.width * (fanBaseXDesign / designWidth),
                    y: geo.size.height * (fanBaseYDesign / designHeight)
                )
                
                // Rewards overlay: dim the leaderboard and show the rewards art + reward schedule.
                if isShowingRewards {
                    // Precompute reward groups so we can drive the UI.
                    let groups = rewardDisplayGroups()
                    
                    // Container dimensions and position in design-space coordinates.
                    let rewardsContainerWidth = geo.size.width * (821.0 / designWidth)
                    let rewardsContainerHeight = geo.size.height * (1322.0 / designHeight)
                    let rewardsContainerX = geo.size.width * ((249.0 + 821.0 / 2.0) / designWidth)
                    let rewardsContainerY = geo.size.height * ((898.0 + 1322.0 / 2.0) / designHeight)
                    
                    ZStack {
                        Color.black.opacity(0.2)
                            .ignoresSafeArea()
                        
                        Image("callit_rewards")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .position(x: geo.size.width / 2.0, y: geo.size.height / 2.0)
                            .allowsHitTesting(false)
                        
                        // Reward schedule content overlaid within the callit_rewards panel.
                        // Fixed height for each reward row so spacing looks consistent
                        let rewardsRowHeight = geo.size.height * (180.0 / designHeight)
                        if groups.isEmpty {
                            // Fallback when no reward schedule is configured.
                            Text("No rewards configured for this minigame.")
                                .font(
                                    .custom(
                                        "UncialAntiqua-Regular",
                                        size: geo.size.height * (42.0 / designHeight)
                                    )
                                )
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .frame(
                                    width: rewardsContainerWidth,
                                    height: rewardsContainerHeight
                                )
                                .position(x: rewardsContainerX, y: rewardsContainerY)
                        } else {
                            ScrollView(.vertical, showsIndicators: true) {
                                VStack(
                                    spacing: geo.size.height * (32.0 / designHeight)
                                ) {
                                    ForEach(groups) { group in
                                        VStack(
                                            spacing: geo.size.height * (10.0 / designHeight)
                                        ) {
                                            // RANK(S)
                                            Text(rankLabel(for: group.ranges))
                                                .font(
                                                    .custom(
                                                        "UncialAntiqua-Regular",
                                                        size: geo.size.height * (120.0 / designHeight)
                                                    )
                                                )
                                                .foregroundColor(baseTextColor)
                                                .multilineTextAlignment(.center)
                                                .frame(maxWidth: .infinity)
                                            
                                            // Horizontal separator bar under the rank label
                                            Rectangle()
                                                .fill(baseTextColor)
                                                .frame(
                                                    width: geo.size.width * (600.0 / designWidth),
                                                    height: geo.size.height * (4.0 / designHeight)
                                                )
                                                .opacity(0.55)
                                                .frame(maxWidth: .infinity, alignment: .center)
                                            
                                            // [TOKEN REWARD] [ASSET(S) REWARD]
                                            HStack(
                                                spacing: geo.size.width * (50.0 / designWidth)
                                            ) {
                                                if let tokens = group.reward.tokenAmount,
                                                   tokens > 0 {
                                                    HStack(
                                                        spacing: geo.size.width * (8.0 / designWidth)
                                                    ) {
                                                        Text("\(tokens)")
                                                            .font(
                                                                .system(
                                                                    //"UncialAntiqua-Regular",
                                                                    size: geo.size.height * (60.0 / designHeight)
                                                                )
                                                            )
                                                            .foregroundColor(.white)
                                                            .opacity(0.55)
                                                        
                                                        Image("tokens_icon")
                                                            .resizable()
                                                            .aspectRatio(contentMode: .fit)
                                                            .frame(
                                                                width: geo.size.width * (70.0 / designWidth),
                                                                height: geo.size.height * (70.0 / designHeight)
                                                            )
                                                    }
                                                }
                                                
                                                if !group.reward.assetKeys.isEmpty {
                                                    HStack(
                                                        spacing: geo.size.width * (35.0 / designWidth)
                                                    ) {
                                                        ForEach(group.reward.assetKeys, id: \.self) { key in
                                                            Image("\(key)_reward_icon")
                                                                .resizable()
                                                                .aspectRatio(contentMode: .fit)
                                                                .frame(
                                                                    width: geo.size.width * (140.0 / designWidth),
                                                                    height: geo.size.height * (140.0 / designHeight)
                                                                )
                                                        }
                                                    }
                                                }
                                            }
                                            .frame(maxWidth: .infinity, alignment: .center)
                                            .frame(height: rewardsRowHeight, alignment: .center)
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                }
                                .padding(.vertical, geo.size.height * (24.0 / designHeight))
                                .padding(.horizontal, geo.size.width * (16.0 / designWidth))
                                .frame(maxWidth: .infinity)
                            }
                            .frame(
                                width: rewardsContainerWidth,
                                height: rewardsContainerHeight
                            )
                            .position(x: rewardsContainerX, y: rewardsContainerY)
                        }
                    }
                    .transition(.opacity)
                    .onTapGesture {
                        Haptics.shared.tap()
                        SoundManager.shared.play("callit_close_rewards")
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isShowingRewards = false
                        }
                    }
                }
                // Candle-style dimming overlay: low-opacity black + single candle glow.
                ZStack {
                    Color.black.opacity(blackoutOpacity)
                    
                    // Slight radius jitter to simulate flicker.
                    let flickerScale: CGFloat = 0.97 + 0.06 * candleFlickerPhase
                    let radius = candleBaseRadius * flickerScale
                    
                    // Mask the darkness with a soft circular light around the candle.
                    RadialGradient(
                        gradient: Gradient(colors: [.white, .clear]),
                        center: .center,
                        startRadius: 0,
                        endRadius: radius
                    )
                    .frame(width: radius * 2, height: radius * 2)
                    .position(candlePoint)
                    .blendMode(.destinationOut)
                    
                    // Warm candle glow on top of the scene, with soft radial fade.
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color(red: 1.0, green: 0.55, blue: 0.10).opacity(0.20),
                            .clear
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: radius * 1.1
                    )
                    .frame(width: radius * 2, height: radius * 2)
                    .position(candlePoint)
                    .blendMode(.screen)

                    // Secondary, larger glow to gently light more of the scene.
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color(red: 1.0, green: 0.75, blue: 0.40).opacity(0.12),
                            .clear
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: radius * 2.0   // roughly twice the main glow radius
                    )
                    .frame(width: radius * 4, height: radius * 4)
                    .position(candlePoint)
                    .blendMode(.screen)
                }
                .compositingGroup()
                .allowsHitTesting(false)
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
                
                // Animate the fan-out of the bottom-right card stack when the overlay appears.
                if fanProgress == 0.0 {
                    withAnimation(.easeOut(duration: 0.7)) {
                        fanProgress = 1.0
                    }
                }
                
                // Start the candle flicker loop once (no intro reveal, just dim + flicker).
                if !hasStartedCandleFlicker {
                    hasStartedCandleFlicker = true
                    startCandleFlicker()
                }
            }
            .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
                // Drive a live countdown by invalidating the view every second.
                countdownTick &+= 1
            }
        }
    }
    
    /// Convert a remaining TimeInterval into a 6-character display for the cards.
    ///
    /// While remaining >= 1 day:    "DDdHHh"
    /// While remaining >= 1 hour:   "HHhMMm"
    /// Otherwise (>= 0):            "MMmSSs"
    /// All numeric fields are zero-padded to two digits.
    private func formattedTimeCharacters(for remaining: TimeInterval?) -> [Character] {
        guard let remaining = remaining else {
            // Fallback when no period is active: show zeros in minutes/seconds format.
            let fallback = "00m00s"
            return Array(fallback)
        }
        
        let totalSeconds = max(0, Int(remaining))
        let days = totalSeconds / 86_400
        let hours = (totalSeconds % 86_400) / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60
        
        let formatted: String
        if days > 0 {
            // Show days and hours: DDdHHh
            let d = min(days, 99)
            formatted = String(format: "%02dd%02dh", d, hours)
        } else if hours > 0 {
            // Show hours and minutes: HHhMMm
            formatted = String(format: "%02dh%02dm", hours, minutes)
        } else {
            // Show minutes and seconds: MMmSSs
            formatted = String(format: "%02dm%02ds", minutes, seconds)
        }
        
        // Ensure we always return exactly 6 characters (two digits, unit, two digits, unit).
        if formatted.count == 6 {
            return Array(formatted)
        } else if formatted.count > 6 {
            return Array(formatted.prefix(6))
        } else {
            // Pad with spaces if something unexpected happens.
            let padded = formatted.padding(toLength: 6, withPad: " ", startingAt: 0)
            return Array(padded)
        }
    }
    
    // MARK: - Reward display helpers
    
    /// Group reward brackets that share identical rewards (same token amount and asset keys)
    /// so we can show one entry per unique reward with combined rank ranges.
    private func rewardDisplayGroups() -> [RewardDisplayGroup] {
        let brackets = manager.rewardBrackets
        guard !brackets.isEmpty else { return [] }
        
        var grouped: [String: RewardDisplayGroup] = [:]
        
        for bracket in brackets {
            let reward = bracket.reward
            let tokenKey = reward.tokenAmount.map(String.init) ?? "nil"
            let assetsKey = reward.assetKeys.sorted().joined(separator: "|")
            let key = tokenKey + "##" + assetsKey
            
            let range = bracket.minRank...bracket.maxRank
            
            if let existing = grouped[key] {
                var newRanges = existing.ranges
                newRanges.append(range)
                grouped[key] = RewardDisplayGroup(
                    id: existing.id,
                    ranges: newRanges,
                    reward: reward
                )
            } else {
                grouped[key] = RewardDisplayGroup(
                    id: key,
                    ranges: [range],
                    reward: reward
                )
            }
        }
        
        // Sort groups by their lowest rank so the list feels natural (top ranks first).
        return grouped.values.sorted { (lhs: RewardDisplayGroup, rhs: RewardDisplayGroup) in
            guard let lMin = lhs.ranges.map(\.lowerBound).min(),
                  let rMin = rhs.ranges.map(\.lowerBound).min() else {
                return false
            }
            return lMin < rMin
        }
    }
    
    /// Format a rank range list into a human-readable label, e.g. "1st", "2nd–3rd", "1st–3rd, 5th".
    private func rankLabel(for ranges: [ClosedRange<Int>]) -> String {
        let sortedRanges = ranges.sorted { $0.lowerBound < $1.lowerBound }
        let parts: [String] = sortedRanges.map { range in
            if range.lowerBound == range.upperBound {
                return ordinal(range.lowerBound)
            } else {
                return "\(ordinal(range.lowerBound))–\(ordinal(range.upperBound))"
            }
        }
        return parts.joined(separator: ", ")
    }
    
    /// Convert an integer rank into an ordinal string (1 -> "1st", 2 -> "2nd", 3 -> "3rd", etc.).
    private func ordinal(_ n: Int) -> String {
        let suffix: String
        let ones = n % 10
        let tens = (n / 10) % 10
        if tens == 1 {
            suffix = "th"
        } else {
            switch ones {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(n)\(suffix)"
    }
    
    /// Internal grouping model for rendering rewards.
    private struct RewardDisplayGroup: Identifiable {
        let id: String
        let ranges: [ClosedRange<Int>]
        let reward: MinigameReward
    }
    
    /// Start a simple looping flicker for the candle light radius.
    private func startCandleFlicker() {
        Task {
            while true {
                // Small random jitter every ~0.12s
                try? await Task.sleep(nanoseconds: 120_000_000)
                
                await MainActor.run {
                    let nextPhase = CGFloat.random(in: 0.0...1.0)
                    withAnimation(.easeInOut(duration: 0.12)) {
                        candleFlickerPhase = nextPhase
                    }
                }
            }
        }
    }
}
