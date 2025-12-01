import SwiftUI

struct StatsMenuView: View {
    @Binding var isOpen: Bool
    @ObservedObject var stats: StatsStore

    let unlockedTrophies: Int
    let totalTrophies: Int
    let unlockedMaps: Int
    let totalMaps: Int
    
    /// Called when the stats view appears so we can ensure backfill has run.
    let onBackfill: () -> Void
    
    @StateObject private var store = FlipStore()

    @State private var flickerOpacity: Double = 0.0
    @State private var isScreenOn: Bool = false

    // Match the same design canvas as BattleMenuView so coordinates line up
    private let designW: CGFloat = 1320
    private let designH: CGFloat = 2868

    // Helpers to convert design-space to device-space
    private func px(_ x: CGFloat, _ geo: GeometryProxy) -> CGFloat {
        x / designW * geo.size.width
    }

    private func py(_ y: CGFloat, _ geo: GeometryProxy) -> CGFloat {
        y / designH * geo.size.height
    }

    private func pw(_ w: CGFloat, _ geo: GeometryProxy) -> CGFloat {
        w / designW * geo.size.width
    }

    private func ph(_ h: CGFloat, _ geo: GeometryProxy) -> CGFloat {
        h / designH * geo.size.height
    }

    /// Run a short "CRT flicker" startup animation for the stats content.
    private func runStartupFlicker() {
        // Start with the screen "off"
        flickerOpacity = 0.0
        isScreenOn = false

        // Small delay so the overlay fade-in can complete before the CRT "boot" effect starts.
        let initialDelay: TimeInterval = 0.35

        // Sequence of opacity steps (time offset from the start of the flicker, target opacity)
        let steps: [(TimeInterval, Double)] = [
            (0.00, 0.0),
            (0.05, 1.0),
            (0.10, 0.15),
            (0.15, 1.0),
            (0.20, 0.4),
            (0.26, 1.0)
        ]

        // Drive the text flicker
        for (offset, alpha) in steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + initialDelay + offset) {
                withAnimation(.easeOut(duration: 0.04)) {
                    flickerOpacity = alpha
                }
            }
        }

        // After the flicker completes, switch the background to the "on" image (instant swap)
        if let lastOffset = steps.last?.0 {
            let totalDelay = initialDelay + lastOffset + 0.05
            DispatchQueue.main.asyncAfter(deadline: .now() + totalDelay) {
                isScreenOn = true
            }
        }
    }

    var body: some View {
        GeometryReader { geo in
            let headsPctRaw = stats.headsShare * 100
            let tailsPctRaw = max(0, 100 - headsPctRaw)

            let headsPctString = headsPctRaw.formatted(.number.precision(.fractionLength(2)))
            let tailsPctString = tailsPctRaw.formatted(.number.precision(.fractionLength(2)))

            let ratioText = "\(headsPctString)% : \(tailsPctString)%"

            let currentStreak = store.currentStreak

            let oddsText: String = {
                if currentStreak <= 0 {
                    return "N/A"
                } else {
                    // For a fair coin, odds of a streak of length N are 1 / 2^N
                    let denom = 1 << min(currentStreak, 40)
                    return "1 / \(formatStatInt(denom))"
                }
            }()

            ZStack {
                // Background image for the stats menu
                Image(isScreenOn ? "stats_menu_background" : "stats_menu_background_off")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()

                // Close button hit area
                Button {
                    Haptics.shared.tap()
                    SoundManager.shared.play("stats_turnoff")
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isOpen = false
                    }
                } label: {
                    Color.clear
                    //Color.red.opacity(0.4)
                }
                .frame(width: pw(161, geo), height: ph(139, geo))
                .contentShape(Rectangle())
                .position(
                    x: px(106 + 161 / 2, geo),
                    y: py(2250 + 139 / 2, geo)
                )

                // Stats list box (invisible container)
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .center, spacing: 18) {

                        // FLIPS SECTION
                        VStack(spacing: 10) {
                            Text("Flips")
                                .font(.custom("VT323", size: 28))
                                .foregroundColor(Color(red: 0.98, green: 0.84, blue: 0.45)) // warm gold
                                .crtText()

                            VStack(alignment: .leading, spacing: 8) {
                                StatRow(label: "Total Flips", value: formatStatInt(stats.totalFlips))
                                StatRow(label: "Total Heads Flipped", value: formatStatInt(stats.totalHeads))
                                StatRow(label: "Total Tails Flipped", value: formatStatInt(stats.totalTails))
                                StatRow(label: "Heads/Tails Ratio", value: ratioText)
                                StatRow(label: "Longest Losing Streak", value: formatStatInt(stats.longestLosingStreak))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .font(.custom("VT323", size: 20))
                            .foregroundColor(.white.opacity(0.95))
                            .crtText()
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 22)
                                .fill(Color.black.opacity(0.35))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22)
                                        .stroke(Color(red: 0.98, green: 0.84, blue: 0.45).opacity(0.9), lineWidth: 1.5)
                                )
                        )

                        // ODDS SECTION
                        VStack(spacing: 10) {
                            Text("Odds")
                                .font(.custom("VT323", size: 28))
                                .foregroundColor(Color(red: 0.80, green: 0.95, blue: 0.80)) // pale green
                                .crtText()

                            VStack(alignment: .leading, spacing: 8) {
                                StatRow(label: "Current Streak", value: formatStatInt(max(currentStreak, 0)))
                                StatRow(label: "Odds", value: oddsText)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .font(.custom("VT323", size: 20))
                            .foregroundColor(.white.opacity(0.95))
                            .crtText()

                            OddsGaugeView(currentStreak: currentStreak)
                                .padding(.top, 6)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 22)
                                .fill(Color.black.opacity(0.35))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22)
                                        .stroke(Color(red: 0.80, green: 0.95, blue: 0.80).opacity(0.9), lineWidth: 1.5)
                                )
                        )

                        // MISC SECTION
                        VStack(spacing: 10) {
                            Text("Misc")
                                .font(.custom("VT323", size: 28))
                                .foregroundColor(Color(red: 0.69, green: 0.87, blue: 0.98)) // soft cyan
                                .crtText()

                            VStack(alignment: .leading, spacing: 8) {
                                StatRow(label: "Total Tokens Earned", value: formatStatInt(stats.totalTokensEarned))
                                StatRow(label: "Total Tokens Spent", value: formatStatInt(stats.totalTokensSpent))
                                StatRow(label: "Trophies Earned", value: "\(formatStatInt(unlockedTrophies)) / \(formatStatInt(totalTrophies))")
                                StatRow(label: "Maps Unlocked", value: "\(formatStatInt(unlockedMaps)) / \(formatStatInt(totalMaps))")
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .font(.custom("VT323", size: 20))
                            .foregroundColor(.white.opacity(0.95))
                            .crtText()
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 22)
                                .fill(Color.black.opacity(0.35))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22)
                                        .stroke(Color(red: 0.69, green: 0.87, blue: 0.98).opacity(0.9), lineWidth: 1.5)
                                )
                        )

                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 15)
                    .opacity(flickerOpacity)
                }
                .frame(
                    width: pw(913, geo),
                    height: ph(1348, geo)
                )
                .clipShape(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                )
                .position(
                    x: px(204 + 913 / 2, geo),
                    y: py(648 + 1348 / 2, geo)
                )

                // Screen surface effect (larger than scroll container, no hit-testing)
                ZStack {
                    let shape = RoundedRectangle(cornerRadius: 29, style: .continuous)

                    // Base darkening over the screen area (lighter so the glow comes through more)
                    shape
                        .fill(Color.black.opacity(0.10))

                    // Softer inner edge / bezel highlight
                    shape
                        .stroke(Color.white.opacity(0.10), lineWidth: 1.0)

                    // Vertical "glass" gradient: gentle highlight + mild darkening at bottom
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.06),
                            Color.clear,
                            Color.black.opacity(0.25)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .blendMode(.screen)
                    .clipShape(shape)

                    // Horizontal vignette: softer darkening towards left/right edges
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.20),
                            Color.clear,
                            Color.black.opacity(0.20)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .blendMode(.multiply)
                    .clipShape(shape)
                }
                .frame(
                    width: pw(1003, geo),
                    height: ph(1466, geo)
                )
                .allowsHitTesting(false)
                .position(
                    x: px(158 + 1003 / 2, geo),
                    y: py(586 + 1466 / 2, geo)
                )
            }
            .onAppear {
                SoundManager.shared.play("stats_startup")
                onBackfill()
                runStartupFlicker()
            }
        }
        .statusBarHidden(true)
        .ignoresSafeArea()
    }
}

private struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(value)
                .lineLimit(1)
                .minimumScaleFactor(0.5) // shrink as needed instead of wrapping
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

private struct OddsGaugeView: View {
    let currentStreak: Int

    private let totalBars = 10

    // Mapping from bar index to the minimum streak needed to light it.
    // 0–1 streak -> none lit
    // 2–3 -> bar 1
    // 4–5 -> bar 2
    // 6–7 -> bar 3
    // ...
    // 20+ -> bar 10
    private func thresholdForBar(_ index: Int) -> Int {
        switch index {
        case 1:  return 2
        case 2:  return 4
        case 3:  return 6
        case 4:  return 8
        case 5:  return 10
        case 6:  return 12
        case 7:  return 14
        case 8:  return 16
        case 9:  return 18
        case 10: return 20
        default: return .max
        }
    }

    private func isBarLit(index: Int) -> Bool {
        currentStreak >= thresholdForBar(index)
    }

    private func barColor(for index: Int, lit: Bool) -> Color {
        let base: Color
        switch index {
        case 1...3:
            base = Color(red: 0.60, green: 0.95, blue: 0.60) // green-ish
        case 4...6:
            base = Color(red: 0.98, green: 0.90, blue: 0.55) // yellow-ish
        case 7...8:
            base = Color(red: 0.98, green: 0.70, blue: 0.40) // orange-ish
        default:
            base = Color(red: 0.98, green: 0.45, blue: 0.45) // red-ish
        }
        return lit ? base : base.opacity(0.18)
    }

    private func labelColor(threshold: Int) -> Color {
        currentStreak >= threshold ? Color.white.opacity(0.9) : Color.white.opacity(0.25)
    }

    private func labelOffsetX(for index: Int) -> CGFloat {
        // Slightly nudge labels that should visually sit between bars.
        // Tuned by eye; you can tweak these values if alignment needs adjustment.
        switch index {
        case 4:  // "100" should appear between bars 3 and 4
            return -12
        case 9:  // "100K" should appear between bars 8 and 9
            return -12
        default:
            return 0
        }
    }

    private func getLabelData(for index: Int) -> (text: String?, threshold: Int?) {
        // Returns the label text and the streak threshold at which it should light up.
        switch index {
        case 2:
            return ("10", 4)      // lights up at streak 4+
        case 4:
            return ("100", 7)     // lights up at streak 7+
        case 5:
            return ("1K", 10)     // lights up at streak 10+
        case 7:
            return ("10K", 14)    // lights up at streak 14+
        case 9:
            return ("100K", 17)   // lights up at streak 17+
        case 10:
            return ("1M", 20)     // lights up at streak 20+
        default:
            return (nil, nil)
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            // Bars row
            HStack(spacing: 4) {
                ForEach(0..<totalBars, id: \.self) { rawIndex in
                    let idx = rawIndex + 1
                    let lit = isBarLit(index: idx)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(barColor(for: idx, lit: lit))
                        .frame(width: 14, height: 36)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(Color.white.opacity(lit ? 0.4 : 0.12), lineWidth: 1)
                        )
                        // Give each bar its own "column" width so it lines up with the label row below
                        .frame(maxWidth: .infinity)
                }
            }

            // Labels row (dim until their streak threshold is reached)
            HStack(spacing: 4) {
                ForEach(0..<totalBars, id: \.self) { rawIndex in
                    let idx = rawIndex + 1
                    let (text, threshold) = getLabelData(for: idx)

                    Group {
                        if let text = text, let threshold = threshold {
                            Text(text)
                                .font(.custom("VT323", size: 14))
                                .foregroundColor(labelColor(threshold: threshold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .offset(x: labelOffsetX(for: idx))
                        } else {
                            Text(" ")
                                .font(.custom("VT323", size: 14))
                                .foregroundColor(.clear)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

private struct CRTText: ViewModifier {
    func body(content: Content) -> some View {
        content
            // subtle glow around the glyphs to feel like emitted light
            .shadow(color: Color(red: 0.6, green: 0.9, blue: 1.0).opacity(0.6), radius: 0, x: 0, y: 0)
            .shadow(color: Color(red: 0.4, green: 0.8, blue: 1.0).opacity(0.4), radius: 3, x: 0, y: 0)
    }
}

private extension View {
    func crtText() -> some View {
        self.modifier(CRTText())
    }
}

fileprivate func formatStatInt(_ value: Int) -> String {
    value.formatted(.number.grouping(.automatic))
}
