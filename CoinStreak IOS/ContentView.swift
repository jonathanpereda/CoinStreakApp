//
//  ContentView.swift
//  CoinStreak IOS
//
//  Created by Jonathan Pereda on 10/3/25.
//

import SwiftUI
import Foundation
import UIKit

// MARK: - MISC

private enum AppPhase { case choosing, preRoll, playing }

///An optional text outline using shadows
private struct TextOutline: ViewModifier {
    let color: Color
    let width: CGFloat      // stroke thickness (px)

    func body(content: Content) -> some View {
        content
            // four hard shadows = crisp outline (fast & iOS-safe)
            .shadow(color: color, radius: 0, x:  width, y:  0)
            .shadow(color: color, radius: 0, x: -width, y:  0)
            .shadow(color: color, radius: 0, x:  0,    y:  width)
            .shadow(color: color, radius: 0, x:  0,    y: -width)
    }
}
private extension View {
    func textOutline(_ color: Color = .black, width: CGFloat = 3) -> some View {
        modifier(TextOutline(color: color, width: width))
    }
}

// Score board
private func panelWidth() -> CGFloat {
    let scale = UIScreen.main.scale
    return 1004.0 / scale // PANEL_W_PX / scale
}
private func tabWidth() -> CGFloat {
    let scale = UIScreen.main.scale
    return 89.0 / scale // TAB_W_PX / scale
}


// MARK: - MAP MENU

private struct SquareHUDButton<Content: View>: View {
    let isOutlined: Bool
    let outlineColor: Color
    let content: Content

    init(
        isOutlined: Bool = false,
        outlineColor: Color = .white,
        @ViewBuilder content: () -> Content
    ) {
        self.isOutlined = isOutlined
        self.outlineColor = outlineColor
        self.content = content()
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial.opacity(0.3))
                .shadow(radius: 3)

            content
                .frame(width: 22, height: 22)
        }
        .frame(width: 36, height: 36)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(outlineColor.opacity(isOutlined ? 0.9 : 0.0), lineWidth: isOutlined ? 2 : 0)
                .shadow(color: outlineColor.opacity(isOutlined ? 0.75 : 0), radius: isOutlined ? 5 : 0)
        )
    }
}

private struct MapItem: Identifiable, Equatable {
    let id: Int        // 0 = Starter, 1... = non-starters in order
    let name: String
    let thumbName: String?   // optional asset name for a thumbnail (plug later)
}

private func makeMapItems(_ progression: ProgressionManager) -> [MapItem] {
    // Order: Starter, then nonStarters in the order you already defined
    var items: [MapItem] = []
    items.append(MapItem(id: 0, name: progression.starterName, thumbName: nil))
    for (i, n) in progression.nonStarterNames.enumerated() {
        // If you have actual thumbnail assets, set thumbName like "thumb_\(n)"
        items.append(MapItem(id: i + 1, name: n, thumbName: nil))
    }
    return items
}

/// Current map index for the carousel list (0 = Starter)
private func currentMapListIndex(_ progression: ProgressionManager) -> Int {
    if progression.levelIndex % 2 == 0 { return 0 }
    let i = (progression.levelIndex / 2) % max(progression.nonStarterNames.count, 1)
    return i + 1
}

private struct MapTile: View {
    enum State { case locked, unlocked(isCurrent: Bool) }
    let state: State
    let backwallName: String?  // <- now expects a backwall asset name
    let size: CGFloat

    var body: some View {
        ZStack {
            // Base tile
            RoundedRectangle(cornerRadius: 14)
                .fill(.white.opacity(0.10))

            switch state {
            case .locked:
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.gray.opacity(0.25))
                Image(systemName: "lock.fill")
                    .font(.system(size: size * 0.28, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))

            case .unlocked(let isCurrent):
                ZStack {
                    if let backwallName {
                        BackwallThumb(
                            imageName: backwallName,
                            corner: 14,
                            cropBottomPx: 1025,
                            zoomOut: 1,
                            panUpPx: 700
                        )

                    } else {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.white.opacity(0.12))
                            .overlay(Image(systemName: "photo").opacity(0.18))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.white.opacity(0.95), lineWidth: 2)
                        .shadow(radius: 4)
                        .opacity(isCurrent ? 1 : 0)
                )


            }
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.35), radius: 5, x: 0, y: 3)
    }
}


/// Shows a backwall image cropped by a fixed number of pixels from the bottom, inside a rounded tile.
private struct BackwallThumb: View {
    let imageName: String
    let corner: CGFloat
    let cropBottomPx: CGFloat
    let zoomOut: CGFloat   // 1.0 = normal fit, <1 zooms OUT, >1 zooms IN
    let panUpPx: CGFloat   // + moves view UP the original image (shows a higher section)

    var body: some View {
        GeometryReader { geo in
            if let ui = UIImage(named: imageName) {
                let pixelHeight = ui.size.height * ui.scale
                let cropFrac = min(max(cropBottomPx / max(pixelHeight, 1), 0), 0.95)
                let visibleFrac = max(1 - cropFrac, 0.05)

                // Convert pan in pixels to a fraction of the original, clamp so we stay in-bounds.
                let maxPanPx = pixelHeight * (1 - visibleFrac)
                let clampedPanPx = min(max(panUpPx, 0), maxPanPx)
                let panFrac = clampedPanPx / max(pixelHeight, 1)

                ZStack(alignment: .top) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(zoomOut, anchor: .top)
                        // Shift the drawn image DOWN by the pan fraction (relative to the tall, internal height)
                        // Positive panUpPx shows a *higher* section of the original.
                        .offset(y: (panFrac * geo.size.height) / visibleFrac)
                        .frame(width: geo.size.width, height: geo.size.height / visibleFrac)
                        .clipped()
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipShape(RoundedRectangle(cornerRadius: corner))
            } else {
                RoundedRectangle(cornerRadius: corner)
                    .fill(.white.opacity(0.12))
                    .overlay(Image(systemName: "photo").opacity(0.18))
            }
        }
    }
}

private struct SettingsTile<Content: View>: View {
    let size: CGFloat
    let label: String?
    let content: Content

    init(size: CGFloat, label: String? = nil, @ViewBuilder content: () -> Content) {
        self.size = size
        self.label = label
        self.content = content()
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(.white.opacity(0.10))

            VStack(spacing: 6) {
                // icon or inner content
                content
                    .frame(maxHeight: .infinity)
                    .padding(.top, 10)

                // optional text label
                if let label {
                    Text(label)
                        .font(.system(size: size * 0.1, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.bottom, 2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(width: size * 0.9, height: size * 0.9)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.35), radius: 5, x: 0, y: 3)
    }
}





// MARK: - COIN FLIP ANIM
///(uses coin_flip_HT / coin_flip_TH atlases)

private enum CoinSide: String { case H = "Heads", T = "Tails" }

private struct SpriteFlipPlan: Equatable {
    let startFace: CoinSide       // "Heads" or "Tails"
    let endFace:   CoinSide
    let halfTurns: Int            // number of half flips (each = one atlas run)
    let startTime: Date
    let duration:  Double         // seconds
}

/// Frame-naming helper: frames are named coin_HT_0001 ... coin_TH_0036
private func atlasFrameName(prefix: String, idx1based: Int) -> String {
    String(format: "%@_%04d", prefix, idx1based)
}

/// Build the alternating atlas run list using real frame prefixes
private func buildAtlasRun(start: CoinSide, halfTurns: Int) -> [(prefix: String, frameCount: Int, skipFirst: Bool)] {
    var list: [(String, Int, Bool)] = []
    var cur = start
    for i in 0..<halfTurns {
        let next: CoinSide = (cur == .H) ? .T : .H
        // Use frame name prefixes
        let prefix = (cur == .H && next == .T) ? "coin_HT" : "coin_TH"
        list.append((prefix, 36, i > 0 /* skip first frame after the first run */))
        cur = next
    }
    return list
}

/// Given a flip plan and "now", compute which image name we should be on.
private func spriteFrameFor(plan: SpriteFlipPlan, now: Date) -> String {
    let elapsed = max(0, now.timeIntervalSince(plan.startTime))
    // Clamp 0...duration
    let t = min(elapsed, plan.duration)
    let atlases = buildAtlasRun(start: plan.startFace, halfTurns: plan.halfTurns)

    // Total frames accounting for skips
    let totalFrames = atlases.reduce(0) { $0 + $1.frameCount - ($1.skipFirst ? 1 : 0) }
    // Progress -> frame index in [0, totalFrames-1]
    let idx = Int(round((t / max(plan.duration, 0.0001)) * Double(totalFrames - 1)))

    // Walk atlases to find concrete (atlas, localIndex)
    var remaining = idx
    for (prefix, count, skipFirst) in atlases {
        let effective = count - (skipFirst ? 1 : 0)
        if remaining < effective {
            // local 1-based index inside this atlas sequence
            let local1based = remaining + (skipFirst ? 2 : 1)
            return atlasFrameName(prefix: prefix, idx1based: local1based)
        } else {
            remaining -= effective
        }
    }
    // Shouldn’t happen, but fall back to the final idle
    let finalPrefix = (plan.endFace == .H) ? "coin_flip_TH" : "coin_flip_HT"
    return atlasFrameName(prefix: finalPrefix, idx1based: 36)
}

/// Static image names for rest frames provided: coin_H / coin_T
private func staticFaceImage(_ face: CoinSide) -> String { face == .H ? "coin_H" : "coin_T" }

/// Small per-asset visual tweaks because the new images have a larger alpha box.
private struct CoinVisualTweak {
    let scale: CGFloat   // 1.0 = no change
    let nudgeY: CGFloat  // +down / -up, in points
}
private let NewCoinTweak = CoinVisualTweak(scale: 2.7, nudgeY: -58) // adjust to taste

/// A view that shows either a static coin image, or a frame from the current sprite flip.
/// It does not control Y/scale/jiggle—that remains owned by the existing state/animations.
private struct SpriteCoinImage: View {
    let plan: SpriteFlipPlan?
    let idleFace: CoinSide         // the face to show when plan is nil
    let width: CGFloat
    let position: CGPoint

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date
            let name: String = {
                if let p = plan {
                    return spriteFrameFor(plan: p, now: now)
                } else {
                    return staticFaceImage(idleFace)
                }
            }()
            Image(name)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: width * NewCoinTweak.scale)
                .position(x: position.x, y: position.y + NewCoinTweak.nudgeY)
                .drawingGroup()
        }
    }
}

// t: 0 → 1
private func settleAnglesSide(_ t: Double) -> (xRock: Double, yRock: Double) {
    // Slower decay and clear side tilt
    let decay: Double = 6.8
    let e = exp(-decay * t)

    let yAmp: Double = 15.0   // ← dominant: left/right tilt (Y axis)
    let xAmp: Double = 1.0    // ← subtle front/back (X axis) so it doesn’t look flat

    // Slight detune + phase gives natural feel
    let y = yAmp * sin(2 * Double.pi * 3.0 * t + Double.pi/4) * e
    let x = xAmp * sin(2 * Double.pi * 3.4 * t) * e
    return (x, y)
}

private struct SettleWiggle: AnimatableModifier {
    var t: Double
    var animatableData: Double {
        get { t }
        set { t = newValue }
    }
    func body(content: Content) -> some View {
        let ang = settleAnglesSide(t)   // (xRock, yRock)
        content
            // subtle front/back
            .rotation3DEffect(.degrees(ang.xRock),
                              axis: (x: 1, y: 0, z: 0),
                              anchor: .bottom,
                              perspective: 0.45)
            // dominant left/right rock
            .rotation3DEffect(.degrees(ang.yRock),
                              axis: (x: 0, y: 1, z: 0),
                              anchor: .bottom,
                              perspective: 0.45)
    }
}

private func bounceY(_ t: Double) -> Double {
    // t: 0→1; return NEGATIVE (upwards) pixels; 0 = rest
    // Using |sin| so each lobe is an “upward tap”, then back to 0.
    let decay = 6.5         // larger = dies faster
    let freq  = 3.0         // ~3 taps across t∈[0,1]
    let amp   = 10.0        // max height in px for first tap

    let envelope = exp(-decay * t)
    let pulses   = abs(sin(2 * Double.pi * freq * t))  // 0→1→0 lobes
    return -(amp * envelope * pulses)                  // negative y = up
}

private struct SettleBounce: AnimatableModifier {
    var t: Double                        // 0→1
    var animatableData: Double {
        get { t }
        set { t = newValue }
    }
    func body(content: Content) -> some View {
        content.offset(y: CGFloat(bounceY(t)))
    }
}

// Clamp helper
private func clamp<T: Comparable>(_ v: T, _ lo: T, _ hi: T) -> T { max(lo, min(hi, v)) }

// Map a 0..~1.6 "impulse" to flight parameters.
// If impulse is nil, we return your current default feel.
private func flightParams(
    impulse: Double?,
    needOdd: Bool,
    screenH: CGFloat
) -> (halfTurns: Int, total: Double, jump: CGFloat, isSuper: Bool) {

    // Defaults = your old random-tap behavior
    let baseHalfTurnsRangeEven = [6, 8, 10]
    let baseHalfTurnsRangeOdd  = [7, 9, 11]
    var total = 0.85
    let defaultJump = max(180, UIScreen.main.bounds.height * 0.32)

    // No swipe → original feel (and not "super")
    guard let rawPower = impulse else {
        let halfTurns = (needOdd ? baseHalfTurnsRangeOdd : baseHalfTurnsRangeEven).randomElement()!
        return (halfTurns, total, CGFloat(defaultJump), false)
    }

    // --- Power shaping ---
    // Use *raw* (unclamped) power to detect "super"; clamp for normal feel.
    let norm = max(0.0, rawPower) / 1.6        // 1.0 ≈ old "max"
    let isSuper = norm > 2                   // threshold to break ceiling (tune as you like)
    let superT  = clamp((norm - 1.05) / 0.45, 0.0, 1.0) // ramp 0→1 up to ~1.50× old

    let pClamped = clamp(rawPower, 0.0, 1.6)
    let shaped = pow(pClamped / 1.6, 0.85)     // raise exponent for less sensitivity

    // --- Duration (normal lane) ---
    total = 0.58 + (1.05 - 0.58) * shaped

    // --- Jump (normal lane) ---
    var jump = CGFloat(Double(defaultJump) * (0.90 + (1.40 - 0.90) * shaped))

    // --- Half-turns (normal lane) ---
    let minTurns = needOdd ? 5 : 4
    var maxTurns = needOdd ? 11 : 12
    var halfTurns = Int(round(Double(minTurns) + Double(maxTurns - minTurns) * shaped))

    // --- Super swipe lane: break the ceiling gracefully ---
    if isSuper {
        let superJumpTarget = screenH * 0.86
        jump = CGFloat(Double(jump) * (1.0 - superT) + Double(superJumpTarget) * superT)
        total += 0.10 * Double(superT)         // extra airtime
        maxTurns += 2                          // a bit more spin headroom
        halfTurns = Int(round(Double(halfTurns) + 2.0 * Double(superT)))
    }

    // Parity fix
    if (halfTurns % 2 == 1) != needOdd {
        halfTurns += (halfTurns <= maxTurns ? 1 : -1)
    }
    halfTurns = clamp(halfTurns, minTurns, maxTurns)

    return (halfTurns, total, jump, isSuper)
}





///OLD coin flipping animation
/*struct FlippingCoin: View, Animatable {
    var angle: Double
    var targetAngle: Double
    var baseFace: String
    var width: CGFloat
    var position: CGPoint

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    private func flipped(_ s: String) -> String { s == "Heads" ? "Tails" : "Heads" }
    private func imageName(for face: String) -> String { face == "Tails" ? "coin_tails" : "coin_heads" }

    private let tiltMag: CGFloat = 0.20
    private let backScale: CGFloat = 0.14
    private let pitchX: Double = -6
    private let perspective: CGFloat = 0.51

    var body: some View {
        let a = (angle.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        let seeingBack = (a >= 90 && a < 270)
        let face = seeingBack ? flipped(baseFace) : baseFace
        let flipX: CGFloat = seeingBack ? -1 : 1

        let rad = a * .pi / 180
        let mag = seeingBack ? backScale : 1
        
        // NEW: zero tilt at rest (a ≈ 0 or 180), max around mid-flight.
        // Also clamp tiny values so we don’t see a micro skew.
        var signedTilt: CGFloat = tiltMag * mag * CGFloat(sin(rad))
        if abs(signedTilt) < 0.001 { signedTilt = 0 }   // snap truly flat at rest

        let vx = signedTilt, vy: CGFloat = 1
        let len = sqrt(vx*vx + vy*vy)
        let ax = vx / max(len, 0.0001), ay = vy / max(len, 0.0001)

        return Image(imageName(for: face))
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: width)
            .compositingGroup()
            .scaleEffect(x: flipX, y: 1, anchor: .center)
            .rotation3DEffect(.degrees(pitchX),
                              axis: (x: 1, y: 0, z: 0),
                              anchor: .center,
                              perspective: perspective)          // ← was default (nonzero)

            .rotation3DEffect(.degrees(a),
                              axis: (x: ax, y: ay, z: 0),
                              anchor: .center,
                              perspective: perspective)          // ← was 0.51
            .position(position)
            .animation(nil, value: face)
    }
}
*/


// MARK: TIER THEMES
///Central theme for each tier: backwall art + font
private struct TierTheme {
    let backwall: String   // asset name for the backwall image
    let font: String       // display font name for StreakCounter
    let loop: String?      // OPTIONAL: audio file name in bundle (no extension)
    let loopGain: Float    // 0.0–1.0
}
//********************IMPORTANT NOTE: WHEN ADDING A NEW MAP, MAKE SURE TO UPDATE PROGRESSION MANAGER*********************
private func tierTheme(for tierName: String) -> TierTheme {
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

private func updateTierLoop(_ theme: TierTheme) {
    if let loopName = theme.loop {
        SoundManager.shared.startLoop(named: loopName, volume: theme.loopGain, fadeIn: 0.8)
    } else {
        // No loop for this tier
        SoundManager.shared.stopLoop(fadeOut: 0.5)
    }
}


// MARK: STREAK COUNTER
private func streakColor(_ v: Int) -> Color {
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

private struct StreakCounter: View {
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


// MARK: RECENT FLIPS COLUMN
private func chosenIconName(_ face: Face?) -> String? {
    guard let f = face else { return nil }
    return (f == .Tails) ? "t_icon" : "h_icon"
}

private struct RecentFlipsColumn: View {
    let recent: [FlipEvent]
    let chosenFace: Face?
    let maxShown: Int = 9   // full stack size

    var body: some View {
        // Oldest at top, newest at bottom
        let items = Array(recent.prefix(maxShown).reversed())
        let n = items.count

        // When the column is FULL (n == maxShown), the very top hits this opacity:
        let minOpacityAtFull: Double = 0.18

        // How strong the fade is when full:
        let totalFadeAtFull = 1.0 - minOpacityAtFull  // = 0.82

        VStack(spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.element.id) { idx, ev in
                // idx: 0 = top (oldest), n-1 = bottom (newest)
                let span = max(n - 1, 1)

                // Dynamically raise the top opacity when the list is short:
                // topOpacity(n) = 1 - totalFadeAtFull * (n-1)/(maxShown-1)
                let topOpacity = 1.0 - totalFadeAtFull * (Double(n - 1) / Double(max(maxShown - 1, 1)))

                // Interpolate from topOpacity (at idx=0) to 1.0 (at idx=n-1) across current n
                let t = Double(idx) / Double(span)
                let opacity = topOpacity + (1.0 - topOpacity) * t

                let isPick = (chosenFace == ev.face)
                let color: Color = isPick ? Color("#FFEB99") : .white

                Text(ev.face == .Heads ? "H" : "T")
                    .font(.custom("Herculanum", size: 32))
                    .foregroundColor(color)
                    .opacity(opacity)
                    .shadow(radius: isPick ? 3 : 2)
            }
        }
        .allowsHitTesting(false)
    }
}





// MARK: CONTENT VIEW

struct ContentView: View {
    @StateObject private var store = FlipStore()
    
    // Score board stuff
    @State private var didRestorePhase = false
    @State private var didKickBootstrap = false
    @StateObject private var scoreboardVM = ScoreboardVM()
    @State private var isScoreMenuOpen: Bool = false
    @State private var isLeaderboardOpen: Bool = false
    @State private var isSettingsOpen: Bool = false

    
    // Map menu stuff
    @Environment(\.scenePhase) private var scenePhase
    @State private var isMapSelectOpen = false
    @State private var manualTargetAfterClose: Int? = nil
    @State private var showNewMapToast = false
    @State private var lastUnlockedCount = 1   // starter = 1
    @State private var showCycleHint = false
    @State private var cycleHintText = "Cycle: On"

    
    @State private var curState = "Heads"

    // animation state
    @State private var y: CGFloat = 0        // 0 = on ledge
    @State private var scale: CGFloat = 1.0

    // Layout
    private let coinDiameterPct: CGFloat = 0.565
    private let ledgeTopYPct: CGFloat = 0.97
    private let coinRestOverlapPct: CGFloat = 0.06

    // Flip state
    @State private var spritePlan: SpriteFlipPlan? = nil
    @State private var isFlipping = false
    @State private var baseFaceAtLaunch = "Heads"
    @State private var flightAngle: Double = 0
    @State private var flightTarget: Double = 0
    @State private var settleT: Double = 1.0   // 1 = idle (no wobble), animate 0 -> 1 on land
    @State private var bounceGen: Int = 0   // cancels any in-flight bounce sequence
    @State private var settleBounceT: Double = 1.0   // 0→1 drives bounce curve; 1 = idle
    @State private var currentFlipWasSuper = false
    
    @State private var disableTapFlip = false

    // App phase
    @State private var phase: AppPhase = .choosing
    @State private var gameplayOpacity: Double = 0   // 0 = hidden during pre-roll, 1 = visible
    @State private var counterOpacity: Double = 1.0
    
    //Face Icon
    @State private var iconPulse: Bool = false
    
    //DustPuff
    @State private var gameplayDustTrigger: Date? = nil
    @State private var backwallDustTrigger: Date? = nil
    @State private var doorDustTrigger: Date? = nil

    //Progress
    @StateObject private var progression = ProgressionManager.standard()
    @State private var barPulse: AwardPulse?
    @State private var barValueOverride: Double? = nil
    @State private var isTierTransitioning = false
    @State private var deferCounterFadeInUntilClose = false
    @State private var fontBelowName: String = "Herculanum"   // default matches Starter
    @State private var fontAboveName: String = "Herculanum"
    @State private var lastTierName: String = "Starter"
    @State private var barNonce = 0
    
    //MuteSounds
    @State private var sfxMutedUI   = SoundManager.shared.isSfxMuted
    @State private var musicMutedUI = SoundManager.shared.isMusicMuted


    @ViewBuilder
    private func streakLayer(fontName: String) -> some View {
        VStack {
            StreakCounter(value: store.currentStreak, fontName: fontName)
                .frame(maxWidth: .infinity)
                .padding(.top, 75)
                .padding(.horizontal, 20)
            Spacer()
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }
    

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = geo.size.height
            let coinD = W * coinDiameterPct
            let coinR = coinD / 2
            let coinCenterY = H * ledgeTopYPct - coinR * (1 - coinRestOverlapPct)
            let groundY = H * ledgeTopYPct

            // Shadow geometry for main coin (during gameplay)
            let jumpPx   = max(180, H * 0.32)
            let height01 = max(0, min(1, -y / jumpPx))

            let baseShadowW: CGFloat = coinD * 1.00
            let minShadowW:  CGFloat = coinD * 0.40

            let baseShadowH: CGFloat = coinD * 0.60
            let minShadowH:  CGFloat = coinD * 0.22

            let heightShrinkBias: CGFloat = 0.75
            let th = min(1, height01 / max(heightShrinkBias, 0.0001))

            let shadowW = baseShadowW + (minShadowW - baseShadowW) * height01
            let shadowHcur = baseShadowH + (minShadowH - baseShadowH) * th

            let shadowOpacity = 0.28 * (1.0 - 0.65 * height01)
            let shadowBlur    = 6.0 + 10.0 * height01

            let shadowYOffsetTweak: CGFloat = -157
            let shadowY_centerLocked = (groundY + baseShadowH / 2) + shadowYOffsetTweak
            
            let theme = tierTheme(for: progression.currentTierName)

            ZStack {
                
                ElevatorSwitcher(
                    currentBackwallName: theme.backwall,
                    starterSceneName: "starter_backwall",
                    doorLeftName: "starter_left",
                    doorRightName: "starter_right",
                    belowDoors: {
                        // shows during open/close and when open
                        streakLayer(fontName: fontBelowName)
                    },
                    aboveDoors: {
                        // top copy, animate with counterOpacity
                        streakLayer(fontName: fontAboveName)
                            .opacity(counterOpacity)
                    },
                    onOpenEnded: {
                        // nothing needed for fonts here
                    },
                    onCloseEnded: {
                        // doors just finished closing on Starter → switch both to Starter font, then (optionally) fade top in
                        let now = Date()
                        doorDustTrigger = now
                        // auto-clear after the effect ends (keep in sync with DoorDustLine.duration)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.60) {
                            if doorDustTrigger == now { doorDustTrigger = nil }
                        }   
                        let starterFont = tierTheme(for: "Starter").font
                        fontBelowName = starterFont
                        fontAboveName = starterFont
                        if deferCounterFadeInUntilClose {
                            withAnimation(.easeInOut(duration: 0.25)) { counterOpacity = 1.0 }
                            deferCounterFadeInUntilClose = false
                        }
                        // If a manual nonstarter→nonstarter selection is waiting, jump to it now (this triggers OPEN)
                        if let pending = manualTargetAfterClose {
                            manualTargetAfterClose = nil
                            progression.jumpToLevelIndex(pending)   
                        }

                    }
                )
                
                if let trig = doorDustTrigger {
                    DoorDustLine.seamBurst(trigger: trig)
                        .id(trig)                       // remount per trigger
                        .frame(width: W, height: H)     // concrete size for Canvas
                        .allowsHitTesting(false)
                }

                Image("starter_table2")
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .ignoresSafeArea()
                
                // HUD: progress bar + chosen-face badge (single instance, top of stack)
                if phase != .choosing, let icon = chosenIconName(store.chosenFace) {
                    let iconSize: CGFloat = 52
                    let barWidth = min(geo.size.width * 0.70, 360)
                    let extraRight: CGFloat = 20

                    HStack(spacing: 24) {
                        let tiltXDeg: Double = -14
                        let persp: CGFloat = 0.45
                        let barHeight: CGFloat = 28
                        let barColor = LinearGradient(colors: [ Color("#908B7A"), Color("#C0BAA2") ],
                                                      startPoint: .leading, endPoint: .trailing)

                        ZStack {
                            TierProgressBar(
                                tierIndex: progression.tierIndex,
                                total: progression.currentBarTotal,
                                liveValue: barValueOverride ?? progression.currentProgress,
                                pulse: barPulse,
                                height: barHeight,
                                corner: barHeight / 2,
                                baseFill: barColor
                            )
                            if progression.mapLocked {
                                Image(systemName: "pause.circle")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white.opacity(0.95))
                                    .shadow(radius: 2)
                                    .allowsHitTesting(false)
                            }
                        }
                        .frame(width: barWidth, height: barHeight)
                        .id("tier-\(progression.tierIndex)-\(barNonce)")
                        .compositingGroup()
                        .rotation3DEffect(.degrees(tiltXDeg),
                                          axis: (x: 1, y: 0, z: 0),
                                          anchor: .bottom,
                                          perspective: persp)
                        .onChange(of: progression.tierIndex) { _, _ in
                            barPulse = nil
                        }
                        .opacity((isMapSelectOpen || isSettingsOpen) ? 0 : 1)
                        .animation(.easeInOut(duration: 0.2), value: isMapSelectOpen)
                        .animation(.easeInOut(duration: 0.2), value: isSettingsOpen)


                        Image(icon)
                            .resizable()
                            .interpolation(.high)
                            .antialiased(true)
                            .renderingMode(.original)
                            .frame(width: iconSize, height: iconSize)
                            .shadow(color: iconPulse ? .yellow.opacity(0.5) : .clear,
                                    radius: iconPulse ? 3 : 0)
                            .animation(.easeOut(duration: 0.25), value: iconPulse)
                            .opacity((isMapSelectOpen || isSettingsOpen) ? 0 : 1)
                            .animation(.easeInOut(duration: 0.2), value: isMapSelectOpen)
                            .animation(.easeInOut(duration: 0.2), value: isSettingsOpen)
                    }
                    .padding(.trailing, geo.safeAreaInsets.trailing + extraRight)
                    .padding(.bottom, geo.safeAreaInsets.bottom + 36)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .allowsHitTesting(false)
                    .zIndex(50)                // keep above table/gameplay
                    .transition(.opacity)
                    
                    //OPEN MAP MENU BUTTON
                    // Replace your existing .overlay(alignment: .bottomLeading) { ... } block with this:
                    .overlay(alignment: .bottomLeading) {
                        // Keep the whole block hidden during the choosing phase (same as before)
                        ZStack(alignment: .leading) {

                            // === Buttons row (Map + Settings + Scoreboard) ===
                            HStack(spacing: 8) {
                                // MAP button
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                        if isSettingsOpen {
                                            isSettingsOpen = false           // close Settings if it's open
                                        } else {
                                            isMapSelectOpen.toggle()
                                        }
                                    }
                                } label: {
                                    SquareHUDButton(
                                        isOutlined: showNewMapToast,
                                        outlineColor: Color(red: 0.35, green: 0.4, blue: 1.0)
                                    ) {
                                        Image(systemName: (isMapSelectOpen || isSettingsOpen) ? "xmark" : "map.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 22, height: 22)
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                }
                                .buttonStyle(.plain)
                                
                                // SETTINGS button (make it a real Button, like Map/Scoreboard)
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                        if isMapSelectOpen { isMapSelectOpen = false }   // opening settings closes map
                                        isSettingsOpen.toggle()
                                    }
                                } label: {
                                    SquareHUDButton(isOutlined: isSettingsOpen) {
                                        Image(systemName: "gearshape.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 22, height: 22)
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                }
                                .buttonStyle(.plain)
                                .opacity((isMapSelectOpen || isSettingsOpen) ? 0 : 1)
                                .disabled(isMapSelectOpen || isSettingsOpen)
                                .animation(.easeInOut(duration: 0.2), value: isMapSelectOpen)
                                .animation(.easeInOut(duration: 0.2), value: isSettingsOpen)


                                // SCOREBOARD menu button (opens/closes the top score overlay)
                                Button {
                                    withAnimation(.easeInOut(duration: 0.22)) {
                                        if isScoreMenuOpen {
                                            isLeaderboardOpen = false
                                            isScoreMenuOpen = false
                                        } else {
                                            isScoreMenuOpen = true
                                        }
                                    }
                                } label: {
                                    SquareHUDButton(isOutlined: isScoreMenuOpen) {
                                        Image("scoreboard_menu_icon")
                                            .resizable()
                                            .interpolation(.high)
                                            .scaledToFit()
                                            .frame(width: 22, height: 22)
                                            .opacity(0.8)
                                    }
                                }
                                .buttonStyle(.plain)
                                .opacity((isMapSelectOpen || isSettingsOpen) ? 0 : 1)
                                .disabled(isMapSelectOpen || isSettingsOpen)
                                .animation(.easeInOut(duration: 0.2), value: isMapSelectOpen)
                                .animation(.easeInOut(duration: 0.2), value: isSettingsOpen)
                            }

                            // === Toast layer (always ABOVE buttons; same spacing you chose) ===
                            if !isMapSelectOpen && showNewMapToast {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.15, green: 0.55, blue: 1.0, opacity: 0.95),
                                                Color(red: 0.50, green: 0.20, blue: 1.0, opacity: 0.95)
                                            ],
                                            startPoint: .leading, endPoint: .trailing
                                        )
                                    )
                                    .frame(width: 160, height: 24, alignment: .leading)
                                    .overlay(
                                        Text("New map unlocked")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 12),
                                        alignment: .leading
                                    )
                                    // Keep your original “start exactly to the right of the 40pt map button”
                                    .padding(.leading, 40)
                                    .offset(y: 0)
                                    .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
                                    .transition(.opacity)
                                    .animation(.easeInOut(duration: 0.5), value: showNewMapToast)
                                    .allowsHitTesting(false) // taps pass through to buttons underneath
                                    .zIndex(999)            // <<< ensures it sits above ANY buttons to the right
                            }
                        }
                        .padding(.leading, 24)
                        .padding(.bottom, 30)
                        .opacity(phase != .choosing ? 1 : 0)
                        .animation(.easeInOut(duration: 0.2), value: phase)
                    }


                }


                // Gameplay shadow + coin are always in the tree; opacity gates visibility.
                Group {
                    // Shadow
                    Ellipse()
                        .fill(Color.black.opacity(shadowOpacity))
                        .frame(width: shadowW, height: shadowHcur)
                        .blur(radius: shadowBlur)
                        .position(x: W/2, y: shadowY_centerLocked-10)
                    
                    // Dust
                    if let trig = gameplayDustTrigger {
                        DustPuff(
                            trigger: trig,
                            originX: W / 2,
                            groundY: (groundY + baseShadowH / 2) + shadowYOffsetTweak-52,
                            duration: 0.48,
                            count: 16,
                            baseColor: Color.white.opacity(0.85),
                            shadowColor: Color.black.opacity(0.22),
                            seed: 42
                        )
                        .frame(width: W, height: H)


                    }

                    // Coin
                    ZStack {
                        SpriteCoinImage(
                            plan: spritePlan,
                            idleFace: (curState == "Heads") ? .H : .T,
                            width: coinD,
                            position: .init(x: W/2, y: coinCenterY)
                        )
                        .offset(y: y + CGFloat(bounceY(settleBounceT)))
                        .scaleEffect(scale)
                    }
                    .modifier(SettleWiggle(t: settleT))
                    .modifier(SettleBounce(t: settleBounceT))
                    .contentShape(Rectangle())
                    // 1) Swipe up → impulse flip
                    .gesture(
                        DragGesture(minimumDistance: 10, coordinateSpace: .local)
                            .onEnded { v in
                                guard phase == .playing, !isFlipping, !isTierTransitioning else { return }

                                // Upward distance (negative height → up)
                                let up = max(0, -v.translation.height)

                                // Predicted overshoot (captures flickiness)
                                let predUp = max(0, -v.predictedEndTranslation.height)
                                let extra = max(0, predUp - up)

                                // Raw “impulse”: distance + a little credit for flick
                                let raw = Double(up) + 0.5 * Double(extra)

                                // Normalize to ~0..1.6 using a fraction of screen height
                                // (feels good across phones; tweak the divisor if you want more/less sensitivity)
                                let impulse = raw / Double(geo.size.height * 0.70)

                                // Require a meaningful upward gesture
                                if impulse > 0.15 {
                                    flipCoin(impulse: impulse)
                                }
                            }
                    )
                    // 2) Tap → default random flip
                    .onTapGesture {
                        guard !disableTapFlip else { return }
                        flipCoin()
                    }



                }
                .opacity(gameplayOpacity)                 // <— no animation; see onReveal below
                .allowsHitTesting(phase == .playing)      // disable taps until playing



                // Recent flips pillar: bottom fixed at a baseline, grows upward
                if phase != .choosing, !store.recent.isEmpty {
                    // Where the BOTTOM should live (0.0 = top, 1.0 = bottom)
                    let baselineYPct: CGFloat = 0.30   // mid-left baseline
                    let baselineY = geo.size.height * baselineYPct

                    ZStack(alignment: .bottomLeading) {
                        RecentFlipsColumn(recent: store.recent, chosenFace: store.chosenFace)
                            .padding(.leading, max(12, geo.safeAreaInsets.leading + 4))
                    }
                    // Container height == distance from top → baseline; column is bottom-aligned inside
                    .frame(width: geo.size.width, height: baselineY, alignment: .bottomLeading)
                    .animation(.spring(response: 0.28, dampingFraction: 0.8), value: store.recent)
                    .transition(.opacity)
                    .allowsHitTesting(false)
                }
                
                // MARK: - MAP MENU WINDOW
                if isMapSelectOpen {
                    VStack {
                        Spacer()

                        // Bottom floating content: left column + (empty) right side for carousel
                        HStack(alignment: .center, spacing: 12) {
                            // LEFT COLUMN: lock toggle (icon-only) + close button
                            VStack(spacing: 12) {
                                
                                // Lock toggle icon (manual selects still allowed when ON)
                                Button {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        progression.mapLocked.toggle()
                                    }
                                    cycleHintText = progression.mapLocked ? "Cycle: OFF" : "Cycle: ON"
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            showCycleHint = true
                                        }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            showCycleHint = false
                                        }
                                    }

                                } label: {
                                    Image(systemName: progression.mapLocked
                                          ? "pause.circle"
                                          : "arrow.triangle.2.circlepath")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 22, height: 22)
                                    .foregroundColor(.white)
                                    .padding(7)
                                    .background(.ultraThinMaterial.opacity(0.5))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .shadow(radius: 3)
                                }
                                .overlay(alignment: .top) {
                                    if showCycleHint {
                                        Text(cycleHintText)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.white.opacity(0.75))
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 10)
                                            .background(Color.black.opacity(0.15))
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
                                            .fixedSize(horizontal: true, vertical: true)   // ← let it expand past button width
                                            .offset(y: -25)                                 // distance above
                                            .allowsHitTesting(false)
                                            .transition(.opacity)
                                            .animation(.easeInOut(duration: 0.2), value: showCycleHint)
                                            .zIndex(1)                                      // optional: draw on top
                                    }
                                }
                                .onChange(of: isMapSelectOpen) { _, isOpen in
                                    if !isOpen && showCycleHint {
                                        showCycleHint = false
                                    }
                                }

                            }
                            .padding(.leading, 12)

                            let items = makeMapItems(progression)
                            let unlockedCount = progression.unlockedCount
                            let currentIdx = currentMapListIndex(progression)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(items) { item in
                                        let idx = item.id
                                        let isUnlocked = idx < unlockedCount
                                        let isCurrent = (idx == currentIdx)

                                        // Resolve the backwall asset name via tierTheme(for:)
                                        let backwall: String? = {
                                            // item.name is your tier name ("Starter", "Lab", etc.)
                                            let theme = tierTheme(for: item.name)
                                            return theme.backwall
                                        }()

                                        MapTile(
                                            state: isUnlocked ? .unlocked(isCurrent: isCurrent) : .locked,
                                            backwallName: backwall,
                                            size: 90
                                        )
                                        .onTapGesture {
                                            guard isUnlocked else { return }                // ignore locked tiles
                                            let targetTile = idx
                                            let currentTile = currentTileIndex()
                                            if targetTile == currentTile {
                                                // already here → just close the panel
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                                    isMapSelectOpen = false
                                                }
                                                return
                                            }

                                            let targetLI = levelIndexForTile(targetTile)
                                            let onStarter = (currentTile == 0)

                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                                isMapSelectOpen = false
                                            }

                                            if onStarter {
                                                // Starter → Non-starter : OPEN only (switch directly to target map)
                                                progression.jumpToLevelIndex(targetLI)
                                            } else {
                                                if targetTile == 0 {
                                                    // Non-starter → Starter : CLOSE only (switch directly to Starter)
                                                    progression.jumpToLevelIndex(0)
                                                } else {
                                                    // Non-starter → Non-starter : CLOSE, then OPEN (via Starter)
                                                    manualTargetAfterClose = targetLI   // schedule the OPEN to target after close ends
                                                    progression.jumpToLevelIndex(0)     // trigger the CLOSE by switching to Starter first
                                                }
                                            }
                                        }

                                    }
                                    
                                }
                                .padding(.vertical, 4)
                                .padding(.trailing, 8)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 96)
                            .offset(y: 24)


                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
                        .frame(maxWidth: .infinity)
                        .frame(height: min(180, UIScreen.main.bounds.height * 0.22)) // ~half the previous size
                        // No background — floats over your map background
                        // No dim layer — screen stays bright
                    }
                    .ignoresSafeArea(edges: .bottom)
                }

                // MARK: - SETTINGS MENU WINDOW
                if isSettingsOpen {

                    VStack {
                        Spacer()
                        HStack(alignment: .center, spacing: 12) {

                            // Reserve the X area; don't intercept taps here
                            Spacer()
                                .frame(width: 46)
                                .allowsHitTesting(false)

                            // SETTINGS carousel
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    // MUSIC tile
                                    SettingsTile(size: 90, label: "Music") {
                                        ZStack {
                                            Image(systemName: "music.note")
                                                .font(.system(size: 90 * 0.34, weight: .semibold))
                                                .foregroundColor(.white.opacity(0.8))
                                            if musicMutedUI {
                                                Rectangle()
                                                    .fill(Color.red.opacity(0.5))
                                                    .frame(width: 90 * 0.8, height: 3)
                                                    .rotationEffect(.degrees(-45))
                                            }
                                        }
                                    }
                                    .onTapGesture {
                                        SoundManager.shared.toggleMusicMuted()
                                        musicMutedUI = SoundManager.shared.isMusicMuted
                                        if musicMutedUI {
                                            SoundManager.shared.stopLoop(fadeOut: 0.4)
                                        } else {
                                            let theme = tierTheme(for: progression.currentTierName)
                                            updateTierLoop(theme)
                                        }
                                    }

                                    // SFX tile
                                    SettingsTile(size: 90, label: "Sounds Effects") {
                                        ZStack {
                                            Text("SFX")
                                                .font(.system(size: 90 * 0.78 * 0.34, weight: .semibold))
                                                .foregroundColor(.white.opacity(0.8))
                                                .minimumScaleFactor(0.85)
                                                .lineLimit(1)
                                                .padding(.horizontal, 6)
                                            if sfxMutedUI {
                                                Rectangle()
                                                    .fill(Color.red.opacity(0.5))
                                                    .frame(width: 90 * 0.8, height: 3)
                                                    .rotationEffect(.degrees(-45))
                                            }
                                        }
                                    }
                                    .onTapGesture {
                                        SoundManager.shared.toggleSfxMuted()
                                        sfxMutedUI = SoundManager.shared.isSfxMuted
                                    }
                                    
                                    // TAP INPUT TOGGLE
                                    SettingsTile(size: 90, label: "Tap to Flip") {
                                        ZStack {
                                            // finger.tap icon
                                            Image(systemName: "hand.tap.fill")
                                                .font(.system(size: 90 * 0.34, weight: .semibold))
                                                .foregroundColor(.white.opacity(0.8))

                                            // Red slash overlay when tap-to-flip is disabled
                                            if disableTapFlip {
                                                Rectangle()
                                                    .fill(Color.red.opacity(0.5))
                                                    .frame(width: 90 * 0.8, height: 3)
                                                    .rotationEffect(.degrees(-35))
                                            }
                                        }
                                    }
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            disableTapFlip.toggle()
                                        }
                                    }

                                    
                                }
                                .padding(.vertical, 4)
                                .padding(.trailing, 8)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 96)
                            .offset(y: 24)
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
                        .frame(maxWidth: .infinity)
                        .frame(height: min(180, UIScreen.main.bounds.height * 0.22))
                    }
                    .ignoresSafeArea(edges: .bottom)
                }







            }
            .ignoresSafeArea()


            // MARK: DEBUG BUTTONS
            
            #if DEBUG
            .overlay(alignment: .topLeading) {
                VStack(spacing: 6) {
                    // ⬅︎ Reset button
                    Button("◀︎") {
                        // 0) Stop polling during reset (optional)
                        scoreboardVM.stopPolling()

                        // 1) Ask server to remove this install's contribution (optional but clean)
                        //let oldId = InstallIdentity.getOrCreateInstallId()
                        Task {
                            //_ = await ScoreboardAPI.retireAndKeepSide(installId: oldId)
                            // Note: this keeps the server's side lock for this oldId, which is fine
                            // because we're about to delete the local installId and generate a new one.

                            // 2) Wipe Keychain identity & side so next run is brand-new
                            InstallIdentity.removeLockedSide()
                            InstallIdentity.removeInstallId()

                            // 3) Clear offline sync & bootstrap marker
                            StreakSync.shared.debugReset()
                            BootstrapMarker.clear()

                            // 4) Reset local UI / game state
                            await MainActor.run {
                                store.chosenFace = nil
                                store.currentStreak = 0
                                store.clearRecent()

                                didRestorePhase = false
                                phase = .choosing
                                gameplayOpacity = 0

                                withTransaction(Transaction(animation: nil)) {
                                    barPulse = nil
                                    progression.debugResetToFirstTier()
                                    progression.debugResetUnlocks()   // ← add this

                                    // local UI state cleanup you already added
                                    resetMapSelectUI()

                                    // make sure the toast diff doesn’t immediately fire after reset
                                    lastUnlockedCount = 1  // starter-only
                                }

                                // Clear scoreboard UI immediately
                                scoreboardVM.heads = 0
                                scoreboardVM.tails = 0
                                scoreboardVM.isOnline = true

                                // 5) Resume polling (or let onAppear do it)
                                scoreboardVM.startPolling()
                            }
                        }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(radius: 2)

                    // ▶︎ Advance button
                    Button("▶︎") {
                        func jumpToNextTier() {
                            _ = progression.applyAward(len: 10_000)
                            progression.advanceTierAfterFill()
                        }
                        jumpToNextTier()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(radius: 2)
                }
                .padding(.top, 2)
                .padding(.leading, 8)
            }
            #endif

            #if TRAILER_RESET
            .overlay(alignment: .topLeading) {
                // Invisible but LARGE tap zones
                let tapSize = CGSize(width: 72, height: 72)   // adjust to taste
                let tapGap: CGFloat = 12

                VStack(alignment: .leading, spacing: tapGap) {
                    // ◀︎ Reset to beginning
                    Button(action: {
                        store.chosenFace = nil
                        store.currentStreak = 0
                        store.clearRecent()
                        didRestorePhase = false
                        phase = .choosing
                        gameplayOpacity = 0
                        withTransaction(Transaction(animation: nil)) {
                            barPulse = nil
                            progression.debugResetToFirstTier()
                        }
                    }) {
                        Color.clear
                            .frame(width: tapSize.width, height: tapSize.height)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .opacity(0.01)                 // invisible but hit-testable
                    .accessibilityHidden(true)

                    // ▶︎ Advance tier
                    Button(action: {
                        func jumpToNextTier() {
                            _ = progression.applyAward(len: 10_000)
                            progression.advanceTierAfterFill()
                        }
                        jumpToNextTier()
                    }) {
                        Color.clear
                            .frame(width: tapSize.width, height: tapSize.height)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .opacity(0.01)
                    .accessibilityHidden(true)
                }
                .padding(.top, 10)
                .padding(.leading, 10)
                .allowsHitTesting(true)
                .zIndex(999) // ensure taps aren’t blocked by views underneath
            }
            #endif


            
            // Choose coin overlay
            .overlay {
                if phase == .choosing {
                    ChooseFaceScreen(
                        store: store,
                        groundY: groundY,
                        screenSize: geo.size
                    ) { selected in
                            // 1) Lock side in Keychain (survives reinstall)
                            InstallIdentity.setLockedSide(selected == .Heads ? "H" : "T")

                            // 2) Persist selection locally & enter gameplay
                            store.chosenFace = selected
                            curState         = selected.rawValue
                            baseFaceAtLaunch = selected.rawValue
                            gameplayOpacity  = 1
                            phase            = .playing

                            // 3) Backend + sync
                            let installId = InstallIdentity.getOrCreateInstallId()
                            Task {
                                // idempotent: safe if already registered
                                await ScoreboardAPI.register(installId: installId, side: selected)

                                // ensure server has your current streak (first-time add)
                                await ScoreboardAPI.bootstrap(
                                    installId: installId,
                                    side: selected,
                                    currentStreak: store.currentStreak
                                )

                                // seed offline replay baseline, then refresh UI totals
                                StreakSync.shared.seedAcked(to: store.currentStreak)
                                await scoreboardVM.refresh()   // remove if not in scope here
                            }
                        

                        // Reset gameplay coin transforms just in case
                        y = 0; scale = 1
                        flightAngle = 0; flightTarget = 0

                        // HIDE gameplay coin immediately (no animation) so it won't show before the drop
                        withTransaction(Transaction(animation: nil)) { gameplayOpacity = 0 }

                        // Start pre-roll
                        withAnimation(.easeInOut(duration: 0.35)) {
                            phase = .preRoll
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(1000)
                }
            }

            // Pre-roll hero coin drop overlay
            .overlay {
                if phase == .preRoll {
                    IntroOverlay(
                        groundY: groundY,
                        screenSize: geo.size,
                        coinDiameterPct: coinDiameterPct,
                        coinRestOverlapPct: coinRestOverlapPct,
                        finalFace: store.chosenFace ?? .Heads,
                        onRevealGameplay: {                     // called exactly at touchdown
                            let tx = Transaction(animation: nil) // ensure no fade-in of gameplay coin
                            withTransaction(tx) {
                                gameplayOpacity = 1              // coin instantly visible UNDER overlay
                            }
                        },
                        onFinished: {                            // overlay fade done -> start playing
                            withAnimation(.easeInOut(duration: 0.20)) {
                                phase = .playing
                            }
                        },
                        onThud: {date in
                            gameplayDustTrigger = date
                            
                            // auto-remove the puff after it finishes (match DustPuff duration + tiny buffer)
                            let lifetime = 0.48 + 0.05
                            DispatchQueue.main.asyncAfter(deadline: .now() + lifetime) {
                                if gameplayDustTrigger == date {   // only clear if nothing retriggered
                                    gameplayDustTrigger = nil
                                }
                            }
                        }
                    )
                    // No transition here—overlay manages its own fade
                    .zIndex(999)
                    .ignoresSafeArea()
                }
            }
            // Top score window that fades in at the very top (ignores safe area)
            .overlay(alignment: .topLeading) {
                TopScoreboardOverlay(
                    vm: scoreboardVM,
                    isOpen: $isScoreMenuOpen,
                    isLeaderboardOpen: $isLeaderboardOpen
                )
                .opacity(store.chosenFace != nil ? 1 : 0) // only after a side is chosen
                .ignoresSafeArea(edges: .top)             // sit flush against the top curves
            }





        }
        .onAppear {
            guard !didRestorePhase else {
                updateTierLoop(tierTheme(for: progression.currentTierName)); return
            }
            didRestorePhase = true

            // 1) Try Keychain first
            if store.chosenFace == nil, let s = InstallIdentity.getLockedSide() {
                store.chosenFace = (s == "H") ? .Heads : .Tails
            }

            // 2) If still nil, ask the server (one-time recovery for old users)
            if store.chosenFace == nil {
                let installId = InstallIdentity.getOrCreateInstallId()
                Task {
                    if let face = await ScoreboardAPI.fetchLockedSide(installId: installId) {
                        InstallIdentity.setLockedSide(face == .Heads ? "H" : "T")
                        await MainActor.run {
                            store.chosenFace = face
                            curState         = face.rawValue
                            baseFaceAtLaunch = face.rawValue
                            gameplayOpacity  = 1
                            phase            = .playing
                        }

                        // NEW: register (safe if already registered)
                        await ScoreboardAPI.register(installId: installId, side: face)

                        // keep your existing state restore
                        if let state = await ScoreboardAPI.fetchState(installId: installId) {
                            await MainActor.run { store.currentStreak = state.currentStreak }
                            StreakSync.shared.seedAcked(to: state.currentStreak)
                        }
                    } else {
                        await MainActor.run {
                            gameplayOpacity  = 0
                            phase            = .choosing
                        }
                    }
                }
            } else {
                // We have a face from Keychain
                curState         = store.chosenFace!.rawValue
                baseFaceAtLaunch = store.chosenFace!.rawValue
                gameplayOpacity  = 1
                phase            = .playing

                let installId = InstallIdentity.getOrCreateInstallId()
                Task {
                    // NEW: register (safe if already registered)
                    await ScoreboardAPI.register(installId: installId, side: store.chosenFace!)

                    if let state = await ScoreboardAPI.fetchState(installId: installId) {
                        await MainActor.run { store.currentStreak = state.currentStreak }
                        StreakSync.shared.seedAcked(to: state.currentStreak)
                    }
                }
            }

            // --- 3) One-time bootstrap (after side is known) ---
            if !didKickBootstrap {
                didKickBootstrap = true

                guard let side = store.chosenFace,
                      BootstrapMarker.needsBootstrap() else { return }

                let installId = InstallIdentity.getOrCreateInstallId()
                let localBefore = store.currentStreak

                Task {
                    if let state = await ScoreboardAPI.fetchState(installId: installId) {
                        if state.currentStreak == 0, localBefore > 0 {
                            await ScoreboardAPI.bootstrap(
                                installId: installId, side: side, currentStreak: localBefore
                            )
                            StreakSync.shared.seedAcked(to: localBefore)
                            BootstrapMarker.markBootstrapped()
                            await MainActor.run { store.currentStreak = localBefore }
                        } else {
                            await MainActor.run { store.currentStreak = state.currentStreak }
                            StreakSync.shared.seedAcked(to: state.currentStreak)
                            if state.currentStreak > 0 { BootstrapMarker.markBootstrapped() }
                        }
                    } else {
                        StreakSync.shared.seedAcked(to: localBefore)
                    }
                }
            }

            // --- 4) Tier/sound init (once) ---
            let initialTheme = tierTheme(for: progression.currentTierName)
            fontBelowName = initialTheme.font
            fontAboveName = initialTheme.font
            lastTierName  = progression.currentTierName

            updateTierLoop(tierTheme(for: progression.currentTierName))

            sfxMutedUI   = SoundManager.shared.isSfxMuted
            musicMutedUI = SoundManager.shared.isMusicMuted
        }
        .onChange(of: progression.tierIndex) { _, _ in
            SoundManager.shared.play("scrape_1")
            
            
            let newName  = progression.currentTierName
            let newTheme = tierTheme(for: progression.currentTierName)
            let oldName  = lastTierName
            
            updateTierLoop(newTheme)
            
            if oldName == "Starter" && newName != "Starter" {
                // OPENING: switch the BELOW font immediately to the new tier
                fontBelowName = newTheme.font
                // top copy is fading out anyway, so no need to change fontAboveName now
            } else if oldName != "Starter" && newName == "Starter" {
                // CLOSING: keep BELOW font as the OLD tier during the close
                // (do NOT change fontBelowName yet)
                // after doors close, onCloseEnded will set both to Starter
                deferCounterFadeInUntilClose = true
            } else {
                // Shouldn't happen with alternating logic, but incase:
                fontBelowName = newTheme.font
                fontAboveName = newTheme.font
            }

            lastTierName = newName
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                scoreboardVM.startPolling()
                Task { await scoreboardVM.refresh() } // optional immediate refresh
                if scoreboardVM.isOnline {
                    let id = InstallIdentity.getOrCreateInstallId()
                    StreakSync.shared.replayIfNeeded(installId: id)
                }
            case .inactive, .background:
                scoreboardVM.stopPolling()
            @unknown default: break
            }
        }
        .onAppear {
            lastUnlockedCount = progression.unlockedCount
        }
        .onChange(of: progression.unlockedCount) { old, new in
            if new > old && !isMapSelectOpen {
                triggerNewMapToast()
            }
            lastUnlockedCount = new
        }
        
        .statusBarHidden(true)

    }
    
    ////SOME MAP HELPERS
    
    /// Map tile index (0 = Starter, 1+ = non-starters) → canonical levelIndex
    private func levelIndexForTile(_ idx: Int) -> Int {
        return (idx == 0) ? 0 : (2 * (idx - 1) + 1)
    }

    /// Current tile index from progression.levelIndex (0 = Starter)
    private func currentTileIndex() -> Int {
        let li = progression.levelIndex
        return (li % 2 == 0) ? 0 : (li + 1) / 2
    }

    private func triggerNewMapToast() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            showNewMapToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.95)) {
                showNewMapToast = false
            }
        }
    }
    
    // Clears all UI state related to the map selector/toast so a reset is truly fresh.
    private func resetMapSelectUI() {
        let noAnim = Transaction(animation: nil)
        withTransaction(noAnim) {
            // Map menu
            isMapSelectOpen = false
            progression.mapLocked = false
            // Any manual jump target you’ve been using (if present)
            manualTargetAfterClose = nil
            
            // Toast
            showNewMapToast = false
        }
    }


    
    
    private func runReboundBounces() {
        // Increment generation to invalidate any earlier scheduled steps
        bounceGen &+= 1
        let gen = bounceGen

        // Tunables
        let amps: [CGFloat] = [-10, -6, -3]    // pixels up (negative y = up)
        let upResp:  Double = 0.12
        let upDamp:  Double = 0.62
        let dnResp:  Double = 0.16
        let dnDamp:  Double = 0.88

        // Total timing accumulator
        var t: Double = 0

        func schedule(_ delay: Double, _ block: @escaping () -> Void) {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard gen == bounceGen else { return }  // canceled by new flip
                block()
            }
        }

        for i in 0..<amps.count {
            let a = amps[i]

            // Up tick
            schedule(t) {
                withAnimation(.spring(response: upResp, dampingFraction: upDamp)) {
                    y = a
                }
            }
            t += upResp * 0.85  // begin coming down slightly before the up spring fully settles

            // Down to rest
            schedule(t) {
                withAnimation(.spring(response: dnResp, dampingFraction: dnDamp)) {
                    y = 0
                }
            }
            t += dnResp * 0.95
        }
    }
    
    // Plays the hero-drop thud and spawns the gameplay dust burst at the coin’s ground contact.
    private func triggerDustImpactFromLanding() {
        let now = Date()
        gameplayDustTrigger = now
        SoundManager.shared.play("thud_1")

        // auto-remove after the puff (match DustPuff’s 0.48s + tiny buffer)
        let lifetime = 0.48 + 0.05
        DispatchQueue.main.asyncAfter(deadline: .now() + lifetime) {
            if gameplayDustTrigger == now {
                gameplayDustTrigger = nil
            }
        }
    }
    

    // MARK: - FLIP LOGIC
    
    // Keep the no-arg for taps
    func flipCoin() { flipCoin(impulse: nil) }

    // New: impulse-aware flip
    func flipCoin(impulse: Double?) {
        guard phase == .playing else { return }
        guard !isFlipping && !isTierTransitioning else { return }

        // Cancel wobble/bounce & reset pose instantly
        withTransaction(.init(animation: nil)) {
            settleBounceT = 1.0
            settleT = 1.0
            y = 0
        }

        // Launch SFX
        SoundManager.shared.play(["launch_1","launch_2"].randomElement()!)

        // Unbiased result: choose face at random (trailer override kept)
        #if TRAILER_RESET
        let desired = (Int.random(in: 0..<3) < 2) ? "Heads" : "Tails"
        #else
        let desired = Bool.random() ? "Heads" : "Tails"
        #endif

        // Capture state
        baseFaceAtLaunch = curState
        isFlipping = true

        // Choose parity target (odd/even) to land on desired
        let needOdd = (desired != baseFaceAtLaunch)

        // Derive flight feel from swipe power (or defaults)
        let params = flightParams(impulse: impulse,
                                  needOdd: needOdd,
                                  screenH: UIScreen.main.bounds.height)
        let halfTurns = params.halfTurns
        let total = params.total
        let jump = params.jump
        currentFlipWasSuper = params.isSuper

        // Sprite plan
        let startSide: CoinSide = (baseFaceAtLaunch == "Heads") ? .H : .T
        let endSide:   CoinSide = (desired == "Heads") ? .H : .T
        spritePlan = SpriteFlipPlan(
            startFace: startSide,
            endFace: endSide,
            halfTurns: halfTurns,
            startTime: Date(),
            duration: total
        )

        // Split total into up/down like before (keep your nice feel)
        let upDur = total * 0.38
        let downDur = total - upDur

        // Up (ease-out)
        withAnimation(.easeOut(duration: upDur)) {
            y = -jump
            scale = 0.98
        }
        // Down (ease-in)
        DispatchQueue.main.asyncAfter(deadline: .now() + upDur) {
            withAnimation(.easeIn(duration: downDur)) {
                y = 0
                scale = 1
            }
            withAnimation(.easeOut(duration: 0.10)) {}
        }

        // Touchdown
        DispatchQueue.main.asyncAfter(deadline: .now() + total) {
            curState = desired
            let noAnim = Transaction(animation: nil)
            withTransaction(noAnim) {
                baseFaceAtLaunch = desired
                isFlipping = false
                spritePlan = nil
            }

            // Bounce & wobble
            settleBounceT = 0.0
            withAnimation(.linear(duration: 0.70)) { settleBounceT = 1.0 }
            settleT = 0.0
            withAnimation(.linear(duration: 0.85)) { settleT = 1.0 }
            
            // If this was a “super” swipe, also do the dust burst + thud like hero drop
            if currentFlipWasSuper {
                triggerDustImpactFromLanding()
                currentFlipWasSuper = false
            }

            // (unchanged) streak / award / tier / SFX logic
            if let faceVal = Face(rawValue: desired) {
                let preStreak = store.currentStreak
                let wasSuccess = (faceVal == store.chosenFace)

                store.recordFlip(result: faceVal)
                let installId = InstallIdentity.getOrCreateInstallId()
                StreakSync.shared.handleLocalFlip(
                    installId: installId,
                    current: store.currentStreak,
                    isOnline: scoreboardVM.isOnline
                )

                if wasSuccess {
                    let pitch = Float(store.currentStreak) * 0.5
                    SoundManager.shared.playPitched(base: "streak_base_pitch", semitoneOffset: pitch)
                    iconPulse = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { iconPulse = false }
                } else {
                    // END-OF-STREAK: award once if there was a run going
                    if preStreak > 0 {

                        if preStreak >= 5 {
                            SoundManager.shared.play("boost_1")
                        }

                        // Current snapshot for the pulse
                        let preProgress = progression.currentProgress
                        let total = Double(progression.currentBarTotal)
                        let needed = max(0.0, total - preProgress)
                        let rawAward = progression.tuning.r(preStreak)
                        let applied  = min(needed, rawAward)

                        // Emit the colored wedge pulse for the UI
                        barPulse = AwardPulse(
                            id: UUID(),
                            start: preProgress,
                            delta: applied,
                            end: preProgress + applied,
                            color: streakColor(preStreak),
                            tierIndex: progression.tierIndex
                        )

                        // Apply the award to the model WITHOUT spillover or immediate tier advance
                        let didFill = progression.applyAward(len: preStreak)

                        // If this award FILLS the bar, advance tier AFTER the fill animation plays
                        if didFill {
                            isTierTransitioning = true

                            // Keep this delay in sync with TierProgressBar’s grow+fade timings (≈0.28 + 0.22)
                            let fillAnimationDelay: Double = 0.55
                            // complete_1 sound delay
                            let postCompletePause: Double = 0.25

                            if !progression.mapLocked {
                                SoundManager.shared.stopLoop(fadeOut: 0.6)
                            }
                            //SoundManager.shared.stopLoop(fadeOut: 0.6)

                            withAnimation(.easeOut(duration: fillAnimationDelay * 0.9)) {
                                counterOpacity = 0.0
                            }

                            // When the fill animation finishes, play the completion sting
                            DispatchQueue.main.asyncAfter(deadline: .now() + fillAnimationDelay) {
                                // 1) Completion sting (unchanged)
                                SoundManager.shared.play("complete_1")

                                // 3) Visual slide-down setup
                                let oldTotal = Double(progression.currentBarTotal)
                                let downAnimDur: Double = 0.45

                                withTransaction(Transaction(animation: nil)) {
                                    barValueOverride = oldTotal
                                }
                                
                                // 2) Count this fill
                                progression.registerBarFill()

                                // --- Only for LOCKED mode, clear the model *now* to avoid jitter ---
                                if progression.mapLocked {
                                    // Clear the underlying progress immediately (no animation) so when the
                                    // override is removed later, the model is already 0 and there’s no jump.
                                    progression.resetBarAfterLockedFill()
                                }

                                // 4) Animate the visual bar back to 0 (unchanged)
                                withAnimation(.linear(duration: downAnimDur)) {
                                    barValueOverride = 0
                                }

                                // 5) After the pause, clear override and either restore counter or advance
                                DispatchQueue.main.asyncAfter(deadline: .now() + postCompletePause) {
                                    withTransaction(Transaction(animation: nil)) {
                                        barValueOverride = nil
                                    }

                                    if progression.mapLocked {
                                        // (Model is already 0 from earlier.)
                                        // Force the bar view to rebuild so it reflects 0 immediately.
                                        withTransaction(Transaction(animation: nil)) {
                                            barNonce &+= 1
                                        }
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            counterOpacity = 1.0
                                        }
                                        isTierTransitioning = false
                                    } else {
                                        deferCounterFadeInUntilClose = true
                                        progression.advanceTierAfterFill()
                                        isTierTransitioning = false
                                    }
                                }

                            }
                        }
                    }

                    // Play landing sound
                    SoundManager.shared.play(["land_1","land_2"].randomElement()!)
                }
            }
        }
    }


}


#Preview { ContentView() }

// MARK: - HERO DROP ANIM (stronger mid-air tilt; no bounce; reveal gameplay at touchdown)
private struct IntroOverlay: View {
    let groundY: CGFloat
    let screenSize: CGSize
    let coinDiameterPct: CGFloat
    let coinRestOverlapPct: CGFloat
    let finalFace: Face
    let onRevealGameplay: () -> Void
    let onFinished: () -> Void
    let onThud: (Date) -> Void

    @State private var coinY: CGFloat = -600
    @State private var shadowW: CGFloat = 0
    @State private var shadowH: CGFloat = 0
    @State private var shadowOpacity: CGFloat = 0
    @State private var overlayOpacity: CGFloat = 1
    @State private var angle: Double = -32          // stronger tilt
    @State private var dropGroupOpacity: Double = 1
    @State private var yaw: Double = -7
    
    @State private var dustTrigger: Date? = nil

    var body: some View {
        let W = screenSize.width
        let H = screenSize.height
        let coinD = W * coinDiameterPct
        let coinR = coinD / 2

        // 1) Compute with the scaled coin diameter so overlap math stays correct
        let scaledCoinD = coinD * NewCoinTweak.scale
        //let coinRScaled = coinR * NewCoinTweak.scale

        let baseShadowW = coinD * 1.00
        let minShadowW = coinD * 0.40
        let baseShadowH = coinD * 0.60
        let minShadowH = coinD * 0.22

        // Lift shadow a hair more like gameplay
        let shadowYOffsetTweak: CGFloat = -157

        // Use scaled radius for the “rest” center, then add the global coin nudge later
        let coinCenterY_atRest = groundY - coinR * (1 - coinRestOverlapPct)

        let faceImageName = (finalFace == .Tails) ? "coin_T" : "coin_H"


        ZStack {
            Color.clear
            
            Group {
                Ellipse()
                    .fill(Color.black.opacity(shadowOpacity))
                    .frame(width: shadowW, height: shadowH)
                    .blur(radius: 8)
                    // add both the coin nudge and extra -10 lift to the shadow:
                    .position(x: W/2, y: (groundY + baseShadowH / 2) + shadowYOffsetTweak - 10)

                Image(faceImageName)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    // render at scaled size
                    .frame(width: scaledCoinD)
                    .rotationEffect(.degrees(angle))
                    .rotation3DEffect(.degrees(yaw), axis: (x: 0, y: 1, z: 0))
                    // add NewCoinTweak.nudgeY so the coin sits exactly like gameplay
                    .position(x: W/2, y: coinCenterY_atRest + coinY + NewCoinTweak.nudgeY)


            }
            .opacity(dropGroupOpacity)   // instantly hide overlay’s coin+shadow at touchdown
        }
        .opacity(overlayOpacity)
        .onAppear {
            // Start state
            coinY = -max(700, H * 0.9)
            shadowW = minShadowW
            shadowH = minShadowH
            shadowOpacity = 0.02
            overlayOpacity = 1

            angle = -32   // stronger 2D tilt
            yaw   = -7    // subtle 3D yaw

            // Timings
            let dropDur: Double = 0.55

            // (1) Vertical drop (no overshoot)
            withAnimation(.easeIn(duration: dropDur)) {
                coinY = 0
                shadowW = baseShadowW
                shadowH = baseShadowH
                shadowOpacity = 0.28
            }

            // (2) Keep the coin noticeably tilted for a moment, then finish tilt IN AIR
            // Hold tilt for ~0.12s, then straighten over ~0.38s so it completes just before touchdown.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.easeOut(duration: 0.38)) {
                    angle = 0
                    yaw   = 0
                }
            }

            // (3) Touchdown → instantly hide overlay’s coin/shadow, reveal gameplay coin, fade overlay
            DispatchQueue.main.asyncAfter(deadline: .now() + dropDur) {
                let tx = Transaction(animation: nil)
                
                SoundManager.shared.play("thud_1")
                onThud(Date())
                
                withTransaction(tx) { dropGroupOpacity = 0 }   // hide overlay coin+shadow instantly
                withTransaction(tx) { onRevealGameplay() }     // show gameplay coin under overlay

                withAnimation(.easeInOut(duration: 0.22)) {
                    overlayOpacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                    onFinished()
                }
            }
        }
        .allowsHitTesting(false)
    }
}




