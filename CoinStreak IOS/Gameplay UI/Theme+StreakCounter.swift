import SwiftUI

// MARK: TIER THEMES
///Central theme for each tier: backwall art + font
struct TierTheme {
    let backwall: String   // asset name for the backwall image
    let font: String       // display font name for StreakCounter
    let loop: String?      // OPTIONAL: audio file name in bundle (no extension)
    let loopGain: Float    // 0.0–1.0
}
//********************IMPORTANT NOTE: WHEN ADDING A NEW MAP, MAKE SURE TO UPDATE PROGRESSION MANAGER*********************
func tierTheme(for tierName: String) -> TierTheme {
    switch tierName {
    case "Starter":
        return .init(backwall: "starter_backwall", font: "Herculanum",
                     loop: "elevator_hum1", loopGain: 0.35)
    case "Lab":
        return .init(backwall: "lab_backwall1", font: "Beirut",
                     loop: "lab_hum", loopGain: 0.45)
    case "Pond":
        return .init(backwall: "pond_backwall", font: "Chalkduster",
                     loop: "pond_mice", loopGain: 0.45)
    case "Brick":
        return .init(backwall: "brick_backwall", font: "BlowBrush",
                     loop: "brick_hum", loopGain: 0.45)
    case "Chair_Room":
        return .init(backwall: "chair_room_backwall", font: "DINCondensed-Bold",
                     loop: "chair_room_hum", loopGain: 0.55)
    case "Space":
        return .init(backwall: "space_backwall", font: "Audiowide-Regular",
                     loop: "song_4", loopGain: 0.15)
    case "Backrooms":
        return .init(backwall: "backrooms_backwall", font: "Arial-Black",
                     loop: "backrooms_hum", loopGain: 0.5)
    case "Underwater":
        return .init(backwall: "underwater_backwall", font: "BebasNeue-Regular",
                     loop: "underwater_hum", loopGain: 0.45)
    default:
        return .init(backwall: "starter_backwall", font: "Herculanum",
                     loop: nil, loopGain: 0.30)
    }
}
//Base font size
private let BaseCounterPointSize: CGFloat = 184
//Font rescale
private func streakNumberScale(for fontName: String) -> CGFloat {
    switch fontName {
    case "Herculanum":              return 1.40
    case "Beirut":                  return 1.78
    case "Chalkduster":             return 1.15
    case "PermanentMarker-Regular": return 1.10
    case "DINCondensed-Bold":       return 1.14
    case "Audiowide-Regular":       return 1.04
    case "Arial-Black":             return 1.20
    case "BebasNeue-Regular":       return 1.18
    default:                        return 1.00
    }
}

func updateTierLoop(_ theme: TierTheme) {
    if let loopName = theme.loop {
        SoundManager.shared.startLoop(named: loopName, volume: theme.loopGain, fadeIn: 0.8)
    } else {
        // No loop for this tier
        SoundManager.shared.stopLoop(fadeOut: 0.5)
    }
}


// MARK: STREAK COUNTER
func streakColor(_ v: Int) -> Color {
    switch v {
    case ...2:      return Color("#8A7763") // dusty brown
    case 3...4:     return Color("#5B8BF7") // vibrant blue
    case 5:         return Color("#00C2A8") // teal
    case 6:         return Color("#7DDA58") // green
    case 7:         return Color("#F7C948") // yellow/amber
    case 8:         return Color("#FF8C00") // orange
    case 9:         return Color("#E63946") // Ember Glow red
    case 10:        return Color("#8A2BE2") // Royal Shimmer purple
    case 11:        return Color("#00C2A8") // Aurora Sweep teal
    case 12:        return Color("#7DDA58") // Neon Lime pulse
    case 13:        return Color("#F7C948") // Gilded Sheen gold
    case 14:        return Color("#5B8BF7") // Sapphire Scanline blue
    case 15:        return Color("#C94BD6") // Magenta Flux violet-magenta
    case 16:        return Color("#FF8C00") // Fire & Ice warm tone
    case 17:        return Color("#7E2DF2") // Starlight Spark deep purple
    case 18:        return Color("#B400FF") // Chromatic Split violet
    case 19:        return Color("#8A2BE2") // Holo Prism fallback purple
    default:        return Color("#FFEA00") // Legendary Rainbow gold
    }
}

private struct CounterSize: ViewModifier {
    let fontName: String
    let pointSize: CGFloat
    func body(content: Content) -> some View {
        content
            .font(.custom(fontName, size: pointSize))
            .minimumScaleFactor(0.75)
            .allowsTightening(true)
    }
}

private extension View {
    func counterSized(fontName: String, pointSize: CGFloat) -> some View {
        self.modifier(CounterSize(fontName: fontName, pointSize: pointSize))
    }
}

@ViewBuilder
private func streakNumberView(_ value: Int, fontName: String) -> some View {
    let pointSize = BaseCounterPointSize              // <- fixed layout box
    let scale = streakNumberScale(for: fontName)      // <- visual scale only
    let plain = Text("\(value)")

    switch value {
    case 0...8: plain.foregroundColor(streakColor(value)).counterSized(fontName: fontName, pointSize: pointSize).scaleEffect(scale, anchor: .center)
    case 9:  GlowText(text: plain).counterSized(fontName: fontName, pointSize: pointSize).scaleEffect(scale, anchor: .center)
    case 10: ShimmerText(text: plain).counterSized(fontName: fontName, pointSize: pointSize).scaleEffect(scale, anchor: .center)
    case 11: AuroraText(text: plain).counterSized(fontName: fontName, pointSize: pointSize).scaleEffect(scale, anchor: .center)
    case 12: SurgeText(text: plain).counterSized(fontName: fontName, pointSize: pointSize).scaleEffect(scale, anchor: .center)
    case 13: GoldSheenText(text: plain).counterSized(fontName: fontName, pointSize: pointSize).scaleEffect(scale, anchor: .center)
    case 14: ScanlineText(text: plain).counterSized(fontName: fontName, pointSize: pointSize).scaleEffect(scale, anchor: .center)
    case 15: FluxText(text: plain).counterSized(fontName: fontName, pointSize: pointSize).scaleEffect(scale, anchor: .center)
    case 16: DiagonalDuoText(text: plain).counterSized(fontName: fontName, pointSize: pointSize).scaleEffect(scale, anchor: .center)
    case 17: ArcPulseText(text: plain).counterSized(fontName: fontName, pointSize: pointSize).scaleEffect(scale, anchor: .center)
    case 18: ChromaticSplitText(text: plain).counterSized(fontName: fontName, pointSize: pointSize).scaleEffect(scale, anchor: .center)
    case 19: HoloPrismText(text: plain).counterSized(fontName: fontName, pointSize: pointSize).scaleEffect(scale, anchor: .center)
    default: LegendaryText(text: plain).counterSized(fontName: fontName, pointSize: pointSize).scaleEffect(scale, anchor: .center)
    }
}

struct StreakCounter: View {
    let value: Int
    let fontName: String
    @State private var pop: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 20) {
            streakNumberView(value, fontName: fontName)
                .shadow(radius: 10)
                .scaleEffect(pop)
                .animation(.spring(response: 0.22, dampingFraction: 0.55, blendDuration: 0.1), value: pop)
        }
        .padding(.vertical, 90)
        .padding(.horizontal, 16)
        .onChange(of: value, initial: false) { oldValue, newValue in
            pop = 1.18
            DispatchQueue.main.async { pop = 1.0 }
        }
    }
}
