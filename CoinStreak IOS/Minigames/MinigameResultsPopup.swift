import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct MinigameResultsPopup: View {
    /// Snapshot for the finished minigame period we are showing results for.
    let snapshot: MinigameSnapshot
    let activeMinigameId: MinigameId?
    /// Called when the user dismisses the popup (e.g. by tapping a button
    /// or anywhere on the overlay, depending on how the host wires it).
    let onDismiss: () -> Void

    @State private var chaseStep: Int = 0
    @State private var animatedHeadlineText: String = ""
    @State private var typingMessageIndex: Int = 0
    @State private var typingCharIndex: Int = 0
    @State private var typingPhase: TypingPhase = .typing
    @State private var typingFinished: Bool = false

    var body: some View {
        ZStack {
            // Dimmed backdrop so the main game is still faintly visible behind.
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            // Main overlay artwork for the minigame results.
            Image("minigame_results_overlay")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            // Marquee lightbulbs around the perimeter
            GeometryReader { geo in
                let designWidth: CGFloat = 1320
                let designHeight: CGFloat = 2868

                // Tuned rectangle whose *edges* are where the bulb centers should sit
                let pathX: CGFloat = 178
                let pathY: CGFloat = 417
                let pathWidth: CGFloat = 964
                let pathHeight: CGFloat = 2023

                // Scale factors from design space → actual device space
                let scaleX = geo.size.width / designWidth
                let scaleY = geo.size.height / designHeight

                // Keep bulbs roughly circular by using a uniform size
                let bulbDesignSize: CGFloat = 70   // 70×69 in your assets
                let bulbSize = bulbDesignSize * min(scaleX, scaleY)

                // Corner inset so bulbs don't sit directly on the rounded corners
                let cornerInsetDesign: CGFloat = 28

                // Desired gap a bit larger than one bulb width
                let desiredSpacingDesign = bulbDesignSize * 2.1
                let patternLength = 8  // how many bulbs per "cycle" of the chaser

                // Compute segment counts around the perimeter, adjusted so that the
                // total bulb count is a clean multiple of the pattern length. This
                // avoids visible phase jumps at the wraparound.
                let counts = computeBulbCounts(
                    pathWidth: pathWidth,
                    pathHeight: pathHeight,
                    spacing: desiredSpacingDesign,
                    patternLength: patternLength
                )

                let topBottomCount = counts.topBottom
                let sideCount = counts.side
                let bulbsOnTop = counts.bulbsOnTop
                let bulbsOnRight = counts.bulbsOnRight
                let bulbsOnBottom = counts.bulbsOnBottom
                let bulbsOnLeft = counts.bulbsOnLeft

                // Titlecard layout constants in design space
                let finishedId = snapshot.period.minigameId
                let designCardWidth: CGFloat = 711.0
                let designCardHeight: CGFloat = 215.5
                let uniformScale = min(scaleX, scaleY)

                ZStack {
                    // Finished minigame titlecard BACKGROUND at (304, 544.8) in design space.
                    titleCardImage(for: finishedId)
                        .resizable()
                        .frame(
                            width: designCardWidth * uniformScale,
                            height: designCardHeight * uniformScale
                        )
                        .clipShape(
                            RoundedRectangle(cornerRadius: 40 * uniformScale, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 40 * uniformScale, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.35),
                                            Color.white.opacity(0.10),
                                            Color.white.opacity(0.02)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .blendMode(.screen)
                                .opacity(0.75)
                        )
                        .shadow(
                            color: Color.black.opacity(0.65),
                            radius: 10 * uniformScale,
                            x: 0,
                            y: 10 * uniformScale
                        )
                        // Circular 3D wobble: tilt in X and Y using sin/cos
                        .rotation3DEffect(
                            .degrees(
                                sin(Double(chaseStep) / 20.0) * 5.0
                            ),
                            axis: (x: 1.0, y: 0.0, z: 0.0),
                            perspective: 0.8
                        )
                        .rotation3DEffect(
                            .degrees(
                                cos(Double(chaseStep) / 20.0) * 1.0
                            ),
                            axis: (x: 0.0, y: 1.0, z: 0.0),
                            perspective: 0.8
                        )
                        .position(
                            x: (304.0 + designCardWidth / 2.0) * scaleX,
                            y: (544.8 + designCardHeight / 2.0) * scaleY
                        )

                    // Finished minigame titlecard TEXT (no wobble) stacked on top.
                    if let finishedText = titleCardTextImage(for: finishedId) {
                        finishedText
                            .resizable()
                            .frame(
                                width: designCardWidth * uniformScale,
                                height: designCardHeight * uniformScale
                            )
                            .shadow(
                                color: Color.black.opacity(0.8),
                                radius: 6 * uniformScale,
                                x: 0,
                                y: 4 * uniformScale
                            )
                            .position(
                                x: (304.0 + designCardWidth / 2.0) * scaleX,
                                y: (544.8 + designCardHeight / 2.0) * scaleY
                            )
                    }

                    // Leaderboard for the finished minigame period
                    let leaderboard = snapshot.leaderboard
                    let totalPlayers = min(leaderboard.count, 10)
                    let rowCount = max(totalPlayers, 5)

                    // Container dimensions and position in design space
                    let lbDesignWidth: CGFloat = 686.0
                    let lbDesignHeight: CGFloat = 572.0
                    let lbDesignOriginX: CGFloat = 317.2
                    let lbDesignOriginY: CGFloat = 858.0

                    let lbCenterX = (lbDesignOriginX + lbDesignWidth / 2.0) * scaleX
                    let lbCenterY = (lbDesignOriginY + lbDesignHeight / 2.0) * scaleY

                    let lbWidth = lbDesignWidth * uniformScale
                    let lbHeight = lbDesignHeight * uniformScale

                    let rowSpacing = 14.0 * uniformScale
                    let fontSize = 75.0 * uniformScale
                    let rowFont = Font.custom("Limelight-Regular", size: fontSize)
                    let baseTextColor = Color(
                        red: 0x33 / 255.0,
                        green: 0x13 / 255.0,
                        blue: 0x0A / 255.0
                    )

                    // Leaderboard list: up to top 10 players, with placeholders for the
                    // first 5 ranks if there are fewer players.
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: rowSpacing) {
                            // Column widths as proportions of the container width so this
                            // stays robust across different content sizes and devices.
                            let rankColumnWidth = lbWidth * 0.14
                            let dashColumnWidth = lbWidth * 0.05
                            let scoreColumnWidth = lbWidth * 0.25

                            ForEach(0..<rowCount, id: \.self) { index in
                                let rank = index + 1
                                let entry = leaderboard.first(where: { $0.rank == rank })

                                Group {
                                    if let entry = entry {
                                        HStack(spacing: 2.0 * uniformScale) {
                                            // [RANK]. — predictable, left aligned, fixed width
                                            Text("\(rank).")
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.7)
                                                .frame(
                                                    width: rankColumnWidth,
                                                    alignment: .leading
                                                )

                                            // [DISPLAYNAME] — flexible middle column, shrinks as needed,
                                            // never wraps, truncates with ellipsis.
                                            Text(entry.displayName)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.5)
                                                .truncationMode(.tail)
                                                .frame(
                                                    maxWidth: .infinity,
                                                    alignment: .leading
                                                )

                                            // "---" — predictable spacer between name and score,
                                            // fixed region so columns stay aligned.
                                            Text("---")
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.5)
                                                .frame(
                                                    width: dashColumnWidth,
                                                    alignment: .center
                                                )

                                            // [SCORE] — right-aligned, wider fixed column, shrinks as
                                            // needed for large values (e.g. 10,000), no wrapping.
                                            Text("\(entry.score)")
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.5)
                                                .monospacedDigit()
                                                .frame(
                                                    width: scoreColumnWidth,
                                                    alignment: .trailing
                                                )
                                        }
                                    } else if rank <= 5 {
                                        // Placeholder row for empty top 5 slots.
                                        HStack(spacing: 4.0 * uniformScale) {
                                            Text("\(rank).")
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.7)
                                                .frame(
                                                    width: rankColumnWidth,
                                                    alignment: .leading
                                                )

                                            Text("~~~~~")
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.5)
                                                .truncationMode(.tail)
                                                .frame(
                                                    maxWidth: .infinity,
                                                    alignment: .leading
                                                )

                                            Text("") // empty dash column
                                                .lineLimit(1)
                                                .frame(
                                                    width: dashColumnWidth,
                                                    alignment: .center
                                                )

                                            Text("") // empty score column
                                                .lineLimit(1)
                                                .frame(
                                                    width: scoreColumnWidth,
                                                    alignment: .trailing
                                                )
                                        }
                                    }
                                }
                                .font(rowFont)
                                .foregroundColor(baseTextColor)
                            }
                        }
                    }
                    .frame(width: lbWidth, height: lbHeight)
                    .position(x: lbCenterX, y: lbCenterY)

                    // MARK: - Player rank & score display
                    let myRankText: String = {
                        if let r = snapshot.me.rank {
                            return "#\(r)"
                        } else {
                            return "--"
                        }
                    }()

                    let myScoreText: String = {
                        if let s = snapshot.me.bestScore {
                            return "\(s)"
                        } else {
                            return "--"
                        }
                    }()

                    // Rank box: 220 x 118 at (311, 1580) in design space
                    let rankBoxWidthDesign: CGFloat = 220.0
                    let rankBoxHeightDesign: CGFloat = 118.0
                    let rankBoxOriginX: CGFloat = 311.0
                    let rankBoxOriginY: CGFloat = 1580.0

                    let rankBoxCenterX = (rankBoxOriginX + rankBoxWidthDesign / 2.0) * scaleX
                    let rankBoxCenterY = (rankBoxOriginY + rankBoxHeightDesign / 2.0) * scaleY

                    let rankBoxWidth = rankBoxWidthDesign * uniformScale
                    let rankBoxHeight = rankBoxHeightDesign * uniformScale

                    Text(myRankText)
                        .font(rowFont)
                        .foregroundColor(baseTextColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .multilineTextAlignment(.center)
                        .frame(width: rankBoxWidth, height: rankBoxHeight, alignment: .center)
                        .position(x: rankBoxCenterX, y: rankBoxCenterY)

                    // Score box: 403 x 118 at (607, 1580) in design space
                    let scoreBoxWidthDesign: CGFloat = 403.0
                    let scoreBoxHeightDesign: CGFloat = 118.0
                    let scoreBoxOriginX: CGFloat = 607.0
                    let scoreBoxOriginY: CGFloat = 1580.0

                    let scoreBoxCenterX = (scoreBoxOriginX + scoreBoxWidthDesign / 2.0) * scaleX
                    let scoreBoxCenterY = (scoreBoxOriginY + scoreBoxHeightDesign / 2.0) * scaleY

                    let scoreBoxWidth = scoreBoxWidthDesign * uniformScale
                    let scoreBoxHeight = scoreBoxHeightDesign * uniformScale

                    Text(myScoreText)
                        .font(rowFont)
                        .foregroundColor(baseTextColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .multilineTextAlignment(.center)
                        .frame(width: scoreBoxWidth, height: scoreBoxHeight, alignment: .center)
                        .position(x: scoreBoxCenterX, y: scoreBoxCenterY)

                    // Reward box: 700 x 118 at (310, 1784) in design space
                    let rewardBoxWidthDesign: CGFloat = 700.0
                    let rewardBoxHeightDesign: CGFloat = 118.0
                    let rewardBoxOriginX: CGFloat = 310.0
                    let rewardBoxOriginY: CGFloat = 1784.0

                    let rewardBoxCenterX = (rewardBoxOriginX + rewardBoxWidthDesign / 2.0) * scaleX
                    let rewardBoxCenterY = (rewardBoxOriginY + rewardBoxHeightDesign / 2.0) * scaleY

                    let rewardBoxWidth = rewardBoxWidthDesign * uniformScale
                    let rewardBoxHeight = rewardBoxHeightDesign * uniformScale

                    // Determine this player's reward (if any) based on their final rank
                    let myRank = snapshot.me.rank
                    let myBestScoreOpt = snapshot.me.bestScore

                    let myReward: MinigameReward? = {
                        guard
                            let rank = myRank,
                            let brackets = snapshot.rewardBrackets
                        else { return nil }
                        return brackets.first { rank >= $0.minRank && rank <= $0.maxRank }?.reward
                    }()

                    Group {
                        if myBestScoreOpt == nil {
                            // They never played this minigame period
                            Text("Play to win prizes")
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        } else if let reward = myReward,
                                  ((reward.tokenAmount ?? 0) > 0 || !reward.assetKeys.isEmpty) {
                            // They earned some rewards for their final rank
                            HStack(spacing: 48.0 * uniformScale) {
                                if let amount = reward.tokenAmount, amount > 0 {
                                    HStack(spacing: 6.0 * uniformScale) {
                                        Text("\(amount)")
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.5)
                                        Image("rewards_tokens_icon")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(height: rewardBoxHeight * 0.6)
                                            .opacity(0.8)
                                            .shadow(
                                                color: Color.black.opacity(0.35),
                                                radius: 5 * uniformScale,
                                                x: 0,
                                                y: 2 * uniformScale
                                            )
                                    }
                                }

                                if !reward.assetKeys.isEmpty {
                                    HStack(spacing: 20.0 * uniformScale) {
                                        ForEach(reward.assetKeys, id: \.self) { key in
                                            let iconName = "\(key)_reward_icon"
                                            Image(iconName)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(height: rewardBoxHeight * 0.7)
                                                .shadow(
                                                    color: Color.black.opacity(0.45),
                                                    radius: 5 * uniformScale,
                                                    x: 0,
                                                    y: 2 * uniformScale
                                                )
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        } else {
                            // They played, but didn't place in any reward bracket
                            Text("No rewards this time")
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        }
                    }
                    .font(rowFont)
                    .foregroundColor(baseTextColor)
                    .frame(width: rewardBoxWidth, height: rewardBoxHeight)
                    .position(x: rewardBoxCenterX, y: rewardBoxCenterY)

                    // Now-active minigame titlecard at (304, 2104.8), if we know it.
                    if let activeId = activeMinigameId {
                        // Now-active minigame titlecard BACKGROUND at (304, 2104.8) in design space.
                        titleCardImage(for: activeId)
                            .resizable()
                            .frame(
                                width: designCardWidth * uniformScale,
                                height: designCardHeight * uniformScale
                            )
                            .clipShape(
                                RoundedRectangle(cornerRadius: 40 * uniformScale, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 40 * uniformScale, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.35),
                                                Color.white.opacity(0.10),
                                                Color.white.opacity(0.02)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .blendMode(.screen)
                                    .opacity(0.75)
                            )
                            .shadow(
                                color: Color.black.opacity(0.65),
                                radius: 10 * uniformScale,
                                x: 0,
                                y: 10 * uniformScale
                            )
                            // Offset circular 3D wobble so it doesn't sync with the top card
                            .rotation3DEffect(
                                .degrees(
                                    sin(Double(chaseStep) / 20.0) * 5.0
                                ),
                                axis: (x: 1.0, y: 0.0, z: 0.0),
                                perspective: 0.8
                            )
                            .rotation3DEffect(
                                .degrees(
                                    cos(Double(chaseStep) / 20.0) * 1.0
                                ),
                                axis: (x: 0.0, y: 1.0, z: 0.0),
                                perspective: 0.8
                            )
                            .position(
                                x: (304.0 + designCardWidth / 2.0) * scaleX,
                                y: (2104.8 + designCardHeight / 2.0) * scaleY
                            )
                        // Now-active minigame titlecard TEXT (no wobble) stacked on top.
                        if let activeText = titleCardTextImage(for: activeId) {
                            activeText
                                .resizable()
                                .frame(
                                    width: designCardWidth * uniformScale,
                                    height: designCardHeight * uniformScale
                                )
                                .shadow(
                                    color: Color.black.opacity(0.8),
                                    radius: 6 * uniformScale,
                                    x: 0,
                                    y: 4 * uniformScale
                                )
                                .position(
                                    x: (304.0 + designCardWidth / 2.0) * scaleX,
                                    y: (2104.8 + designCardHeight / 2.0) * scaleY
                                )
                        }
                    }

                    // 1. TOP EDGE (Left -> Right)
                    // Visual direction matches Clockwise direction, so index is normal.
                    ForEach(0..<topBottomCount, id: \.self) { i in
                        let point = calculateTopPoint(
                            i: i,
                            count: topBottomCount,
                            px: pathX,
                            py: pathY,
                            w: pathWidth,
                            inset: cornerInsetDesign
                        )

                        let globalIndex = i
                        let phase = ( (chaseStep - globalIndex) % patternLength + patternLength ) % patternLength
                        let intensity = bulbIntensity(forPhase: phase)

                        BulbView(
                            point: point,
                            size: bulbSize,
                            scaleX: scaleX,
                            scaleY: scaleY,
                            intensity: intensity
                        )
                    }

                    // 2. RIGHT EDGE (Top -> Bottom)
                    if sideCount > 2 {
                        ForEach(1..<(sideCount - 1), id: \.self) { i in
                            let t = CGFloat(i) / CGFloat(max(sideCount - 1, 1))
                            let dx = pathX + pathWidth
                            let dy = pathY + t * pathHeight

                            let localIndex = i - 1
                            let globalIndex = bulbsOnTop + localIndex
                            let phase = ( (chaseStep - globalIndex) % patternLength + patternLength ) % patternLength
                            let intensity = bulbIntensity(forPhase: phase)

                            BulbView(
                                point: CGPoint(x: dx, y: dy),
                                size: bulbSize,
                                scaleX: scaleX,
                                scaleY: scaleY,
                                intensity: intensity
                            )
                        }
                    }

                    // 3. BOTTOM EDGE (Right -> Left)
                    ForEach(0..<topBottomCount, id: \.self) { i in
                        let point = calculateBottomPoint(
                            i: i,
                            count: topBottomCount,
                            px: pathX,
                            py: pathY,
                            w: pathWidth,
                            h: pathHeight,
                            inset: cornerInsetDesign
                        )

                        let invertedIndex = (topBottomCount - 1) - i
                        let globalIndex = bulbsOnTop + bulbsOnRight + invertedIndex

                        let phase = ( (chaseStep - globalIndex) % patternLength + patternLength ) % patternLength
                        let intensity = bulbIntensity(forPhase: phase)

                        BulbView(
                            point: point,
                            size: bulbSize,
                            scaleX: scaleX,
                            scaleY: scaleY,
                            intensity: intensity
                        )
                    }

                    // 4. LEFT EDGE (Bottom -> Top)
                    if sideCount > 2 {
                        ForEach(1..<(sideCount - 1), id: \.self) { i in
                            let t = CGFloat(i) / CGFloat(max(sideCount - 1, 1))
                            let dx = pathX
                            let dy = pathY + t * pathHeight

                            let localIndex = i - 1
                            let invertedIndex = (bulbsOnLeft - 1) - localIndex
                            let globalIndex = bulbsOnTop + bulbsOnRight + bulbsOnBottom + invertedIndex

                            let phase = ( (chaseStep - globalIndex) % patternLength + patternLength ) % patternLength
                            let intensity = bulbIntensity(forPhase: phase)

                            BulbView(
                                point: CGPoint(x: dx, y: dy),
                                size: bulbSize,
                                scaleX: scaleX,
                                scaleY: scaleY,
                                intensity: intensity
                            )
                        }
                    }
                    // Animated headline text at the top ("TIME'S UP!" → "RESULTS:")
                    let headlineText = animatedHeadlineText
                    let headlineChars = Array(headlineText)
                    let headlineColor = Color(
                        red: 0xE0 / 255.0,
                        green: 0xD7 / 255.0,
                        blue: 0xD5 / 255.0
                    )
                    let headlineFontSize: CGFloat = 165.0 * uniformScale
                    let headlineFont = Font.custom("Limelight-Regular", size: headlineFontSize)

                    if !headlineChars.isEmpty {
                        HStack(spacing: 4.0 * uniformScale) {
                            ForEach(headlineChars.indices, id: \.self) { idx in
                                let ch = String(headlineChars[idx])
                                // Per-character subtle floating, desynced by index
                                let phase = (Double(chaseStep) / 20.0) + Double(idx) * 0.7
                                let xOffset = cos(phase * 1.3) * 2.0 * Double(uniformScale)
                                let yOffset = sin(phase) * 3.0 * Double(uniformScale)

                                Text(ch)
                                    .font(headlineFont)
                                    .foregroundColor(headlineColor)
                                    .shadow(
                                        color: Color.black.opacity(0.9),
                                        radius: 0,
                                        x: 5 * uniformScale,
                                        y: 5 * uniformScale
                                    )
                                    .offset(x: xOffset, y: yOffset)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .position(
                            x: (designWidth / 2.0) * scaleX,
                            y: 260.0 * scaleY
                        )
                    }
                }
            }
        }
        // For now, let the whole overlay be tappable to dismiss; the host
        // can refine this later if they want a dedicated button instead.
        .contentShape(Rectangle())
        .onTapGesture {
            onDismiss()
        }
        .task {
            // Faster loop for smoother animation
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 80_000_000) // ~0.08s
                await MainActor.run {
                    chaseStep &+= 1
                }
            }
        }
        .task {
            await runTypingHeadline()
        }
    }

    /// Drive the typewriter-style animated headline text at the top of the popup.
    @MainActor
    private func runTypingHeadline() async {
        // Two messages we cycle through: first "TIME'S UP!", then "RESULTS:"
        let messages = ["TIME'S UP!", "RESULTS:"]

        // Initial state
        typingMessageIndex = 0
        typingCharIndex = 0
        animatedHeadlineText = ""
        typingPhase = .typing
        typingFinished = false

        while !Task.isCancelled && !typingFinished {
            let current = messages[typingMessageIndex]

            switch typingPhase {
            case .typing:
                if typingCharIndex < current.count {
                    typingCharIndex += 1
                    let prefix = String(current.prefix(typingCharIndex))
                    animatedHeadlineText = prefix
                    let ch = current[current.index(current.startIndex, offsetBy: typingCharIndex - 1)]
                    if !ch.isWhitespace {
                        SoundManager.shared.playTypingTick()
                    }
                    // Per-character typing speed
                    try? await Task.sleep(nanoseconds: 130_000_000)
                } else {
                    // Finished writing the current message — brief pause
                    typingPhase = .pausing
                    try? await Task.sleep(nanoseconds: 1700_000_000)
                }

            case .pausing:
                if typingMessageIndex == messages.count - 1 {
                    // On the final message ("RESULTS:") we stop after the pause
                    typingPhase = .finished
                    typingFinished = true
                } else {
                    // For the first message, transition into erasing
                    typingPhase = .erasing
                }

            case .erasing:
                if typingCharIndex > 0 {
                    typingCharIndex -= 1
                    let prefix = String(current.prefix(typingCharIndex))
                    animatedHeadlineText = prefix
                    // Slightly snappier erase speed
                    try? await Task.sleep(nanoseconds: 110_000_000)
                } else {
                    // Move on to the next message
                    typingMessageIndex = min(typingMessageIndex + 1, messages.count - 1)
                    typingPhase = .typing
                }

            case .finished:
                typingFinished = true
            }
        }
    }

    // MARK: - Helper Builders

    /// Top edge, left → right, with corner inset.
    private func calculateTopPoint(
        i: Int,
        count: Int,
        px: CGFloat,
        py: CGFloat,
        w: CGFloat,
        inset: CGFloat
    ) -> CGPoint {
        let t = CGFloat(i) / CGFloat(max(count - 1, 1))
        var dx = px + t * w
        var dy = py

        if i == 0 {
            dx = px + inset
            dy = py + inset
        } else if i == count - 1 {
            dx = px + w - inset
            dy = py + inset
        }
        return CGPoint(x: dx, y: dy)
    }

    /// Bottom edge, left → right in layout, but we will index right → left for the chase.
    private func calculateBottomPoint(
        i: Int,
        count: Int,
        px: CGFloat,
        py: CGFloat,
        w: CGFloat,
        h: CGFloat,
        inset: CGFloat
    ) -> CGPoint {
        let t = CGFloat(i) / CGFloat(max(count - 1, 1))
        var dx = px + t * w
        var dy = py + h

        if i == 0 {
            dx = px + inset
            dy = py + h - inset
        } else if i == count - 1 {
            dx = px + w - inset
            dy = py + h - inset
        }
        return CGPoint(x: dx, y: dy)
    }

    /// Compute the bulb counts for each edge of the marquee such that the total
    /// number of bulbs around the perimeter is a clean multiple of `patternLength`.
    /// This keeps the chaser pattern from "jumping" at the wraparound.
    private func computeBulbCounts(
        pathWidth: CGFloat,
        pathHeight: CGFloat,
        spacing: CGFloat,
        patternLength: Int
    ) -> (topBottom: Int, side: Int, bulbsOnTop: Int, bulbsOnRight: Int, bulbsOnBottom: Int, bulbsOnLeft: Int) {
        var topBottomCount = max(Int(pathWidth / spacing) + 1, 2)
        var sideCount = max(Int(pathHeight / spacing) + 1, 2)

        var totalBulbs = (topBottomCount * 2) + ((sideCount - 2) * 2)

        while totalBulbs % patternLength != 0 {
            if topBottomCount < sideCount {
                topBottomCount += 1
            } else {
                sideCount += 1
            }
            totalBulbs = (topBottomCount * 2) + ((sideCount - 2) * 2)
        }

        let bulbsOnTop = topBottomCount
        let bulbsOnRight = max(sideCount - 2, 0)
        let bulbsOnBottom = topBottomCount
        let bulbsOnLeft = bulbsOnRight

        return (topBottomCount, sideCount, bulbsOnTop, bulbsOnRight, bulbsOnBottom, bulbsOnLeft)
    }

    /// Resolve the appropriate titlecard image for a given minigame, falling
    /// back to a placeholder if the specific asset doesn't exist in this build.
    private func titleCardImage(for id: MinigameId) -> Image {
        let candidateName = "\(id.rawValue)_titlecard"
        #if canImport(UIKit)
        if UIImage(named: candidateName) != nil {
            return Image(candidateName)
        } else {
            return Image("placeholder_titlecard")
        }
        #else
        return Image(candidateName)
        #endif
    }
    
    /// Optional text layer for a given minigame titlecard, if the asset exists.
    /// This is expected to be the same size as the background titlecard image
    /// and will be stacked on top of it.
    private func titleCardTextImage(for id: MinigameId) -> Image? {
        let candidateName = "\(id.rawValue)_titlecard_text"
        #if canImport(UIKit)
        if UIImage(named: candidateName) != nil {
            return Image(candidateName)
        } else {
            return nil
        }
        #else
        // On non-UIKit platforms we assume the asset exists if referenced.
        return Image(candidateName)
        #endif
    }

    /// Map the chaser phase (0...(patternLength-1)) to a bulb intensity.
    private func bulbIntensity(forPhase phase: Int) -> BulbIntensity {
        switch phase {
        case 0, 1:
            return .full
        case 2, 7:
            return .half
        default:
            return .off
        }
    }
}

enum TypingPhase {
    case typing
    case pausing
    case erasing
    case finished
}

enum BulbIntensity {
    case off
    case half
    case full
}

// Separate subview to clean up the main body code
struct BulbView: View {
    let point: CGPoint
    let size: CGFloat
    let scaleX: CGFloat
    let scaleY: CGFloat
    let intensity: BulbIntensity

    var body: some View {
        let saturation: Double
        let brightness: Double
        let opacity: Double

        switch intensity {
        case .off:
            saturation = 0.0
            brightness = -0.4
            opacity = 0.35
        case .half:
            saturation = 0.7
            brightness = -0.15
            opacity = 0.75
        case .full:
            saturation = 1.0
            brightness = 0.0
            opacity = 1.0
        }

        return Image("minigame_results_lightbulb")
            .resizable()
            .frame(width: size, height: size)
            .saturation(saturation)
            .brightness(brightness)
            .opacity(opacity)
            .position(
                x: point.x * scaleX,
                y: point.y * scaleY
            )
    }
}
