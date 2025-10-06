//
//  ColorHex.swift
//  CoinStreak
//
//  Created by Jonathan Pereda on 10/4/25.
//

import SwiftUI

extension Color {
    init(_ hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)

        let r, g, b, a: Double
        switch s.count {
        case 3: // RGB (12-bit)
            r = Double((v >> 8) & 0xF) / 15.0
            g = Double((v >> 4) & 0xF) / 15.0
            b = Double(v & 0xF) / 15.0
            a = 1
        case 6: // RRGGBB
            r = Double((v >> 16) & 0xFF) / 255.0
            g = Double((v >> 8) & 0xFF) / 255.0
            b = Double(v & 0xFF) / 255.0
            a = 1
        case 8: // RRGGBBAA
            r = Double((v >> 24) & 0xFF) / 255.0
            g = Double((v >> 16) & 0xFF) / 255.0
            b = Double((v >> 8) & 0xFF) / 255.0
            a = Double(v & 0xFF) / 255.0
        default:
            r = 1; g = 1; b = 1; a = 1
        }
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}


// MARK: - 9 Ember Glow (Red breathe)
struct GlowText: View {
    let text: Text
    var base: Color = Color("#E63946")
    var glowA: Color = Color("#FF6A3D")
    var glowB: Color = Color("#FF8C00")
    var duration: Double = 1.6

    @State private var pulse: CGFloat = 0.85

    var body: some View {
        text
            .foregroundColor(base)
            .scaleEffect(1 + 0.02 * (pulse - 0.85))
            .overlay(
                text
                    .foregroundColor(glowA.opacity(0.45 * pulse))
                    .blur(radius: 2 + 8 * pulse)
            )
            .overlay(
                text
                    .foregroundColor(glowB.opacity(0.30 * pulse))
                    .blur(radius: 6 + 14 * pulse)
            )
            .onAppear {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    pulse = 1.15
                }
            }
    }
}

// MARK: - Tier 10 Purple Shimmer
struct ShimmerText: View {
    let text: Text
    var base: Color = Color("#8A2BE2")         // base purple
    var highlight: Color = .white.opacity(0.9) // gleam color
    var duration: Double = 1.6                 // speed

    @State private var phase: CGFloat = -1.0

    var body: some View {
        text
            .foregroundColor(base)
            .overlay {
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    // angled band: clear → highlight → clear
                    LinearGradient(
                        colors: [.clear, highlight, .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(width: max(w * 0.35, 60), height: h * 2) // band width
                    .rotationEffect(.degrees(20))
                    .offset(x: phase * (w + w*0.35), y: -h * 0.2)
                    .animation(.linear(duration: duration).repeatForever(autoreverses: false),
                               value: phase)
                }
                .mask(text)
            }
            .onAppear {
                // kick the sweep from left → right
                phase = 1.2
            }
    }
}

// MARK: - 11 Aurora Sweep (Teal drift)
struct AuroraText: View {
    let text: Text
    var c1: Color = Color("#00C2A8")
    var c2: Color = Color("#4BE5FF")
    var duration: Double = 2.2

    @State private var phase: CGFloat = -0.35
    @State private var hue: Double = 0

    var body: some View {
        text
            .overlay {
                GeometryReader { geo in
                    let w = geo.size.width
                    LinearGradient(colors: [c1, c2, c1],
                                   startPoint: .leading, endPoint: .trailing)
                        .hueRotation(.degrees(hue))
                        .scaleEffect(x: 2.0, y: 1, anchor: .center)
                        .offset(x: phase * w)
                        .animation(.linear(duration: duration).repeatForever(autoreverses: true), value: phase)
                        .animation(.easeInOut(duration: duration * 1.25).repeatForever(autoreverses: true), value: hue)
                }
                .mask(text)
            }
            .foregroundColor(c1)
            .onAppear { phase = 0.35; hue = 12 }
    }
}


// MARK: - 12 Neon Lime Surge
struct SurgeText: View {
    let text: Text
    var base: Color = Color("#7DDA58")   // lime green base
    var bright: Color = Color("#CFFFA6") // neon highlight

    @State private var p1: CGFloat = -1.0
    @State private var p2: CGFloat =  1.0

    var body: some View {
        text
            .foregroundColor(base)

            // Two diagonal neon bands sweeping in opposite directions
            .overlay {
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height

                    ZStack {
                        // Band 1 (↘ sweep)
                        LinearGradient(colors: [.clear, bright, .clear],
                                       startPoint: .top, endPoint: .bottom)
                            .frame(width: max(60, w * 0.28), height: h * 2)
                            .rotationEffect(.degrees(25))
                            .offset(x: p1 * (w + w * 0.28), y: -h * 0.2)
                            .blendMode(.plusLighter)

                        // Band 2 (↗ counter-sweep), a tad thinner for texture
                        LinearGradient(colors: [.clear, bright.opacity(0.9), .clear],
                                       startPoint: .bottomLeading, endPoint: .topTrailing)
                            .frame(width: max(50, w * 0.22), height: h * 2)
                            .rotationEffect(.degrees(-20))
                            .offset(x: p2 * (w + w * 0.22), y: h * 0.15)
                            .blendMode(.plusLighter)
                    }
                    // Independent speeds for a lively interference feel
                    .animation(.linear(duration: 1.4).repeatForever(autoreverses: false), value: p1)
                    .animation(.linear(duration: 1.9).repeatForever(autoreverses: false), value: p2)
                }
                .mask(text)
            }

            // Soft inner glow to “charge” the center
            .overlay {
                GeometryReader { geo in
                    RadialGradient(colors: [bright.opacity(0.35), .clear],
                                   center: .center,
                                   startRadius: 0,
                                   endRadius: max(geo.size.width, geo.size.height) * 0.7)
                }
                .mask(text)
            }

            .onAppear {
                // Kick bands in opposite directions
                p1 = 1.2
                p2 = -1.2
            }
    }
}



// MARK: - 13 Gilded Sheen (metallic double-pass)
struct GoldSheenText: View {
    let text: Text
    var base: Color = Color("#CFA448")
    var mid: Color  = Color("#F7C948")
    var tip: Color  = Color("#FFF1B0")
    var duration: Double = 1.4

    @State private var t: CGFloat = -0.8

    var body: some View {
        text
            .foregroundColor(mid)
            .overlay {
                GeometryReader { geo in
                    let w = geo.size.width
                    LinearGradient(colors: [.clear, tip.opacity(0.95), .clear],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(width: max(60, w * 0.35))
                        .rotationEffect(.degrees(18))
                        .offset(x: t * (w + w * 0.35))
                        .animation(.linear(duration: duration)
                            .repeatForever(autoreverses: true), value: t)
                }
                .mask(text)
            }
            .overlay(
                text.opacity(0.0) // keep layout
            )
            .onAppear { t = 1.2 }
    }
}

// MARK: - 14 Sapphire Scanline (techy glint)
struct ScanlineText: View {
    let text: Text
    var base: Color = Color("#5B8BF7")
    var duration: Double = 1.8

    @State private var y: CGFloat = 1.2

    var body: some View {
        text
            .foregroundColor(base)
            .overlay {
                GeometryReader { geo in
                    let h = geo.size.height
                    Rectangle()
                        .fill(LinearGradient(colors: [.clear, .white.opacity(0.9), .clear],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(height: max(2, h * 0.08))
                        .cornerRadius(2)
                        .offset(y: y * h - h * 0.1)
                        .animation(.linear(duration: duration).repeatForever(autoreverses: false), value: y)
                }
                .mask(text)
            }
            .onAppear { y = -0.2 }
    }
}

// MARK: - 15 Magenta Flux (violet <-> magenta morph)
struct FluxText: View {
    let text: Text
    var a: Color = Color("#8A2BE2")
    var b: Color = Color("#FF4FD8")
    var duration: Double = 2.6

    @State private var p: CGFloat = 0

    var body: some View {
        text
            .overlay(
                LinearGradient(colors: [a, b],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .hueRotation(.degrees(Double(p) * 8)) // subtle hue wobble
                    .animation(.easeInOut(duration: duration).repeatForever(autoreverses: true),
                               value: p)
            )
            .mask(text)
            .onAppear { p = 1 }
    }
}

// MARK: - 16 Fire & Ice Diagonal (warm/cool slide)
struct DiagonalDuoText: View {
    let text: Text
    var warm: Color = Color("#FFA84A")   // brighter than #FF8C00
    var cool: Color = Color("#39B6FF")   // brighter than #00A3FF
    var duration: Double = 2.6

    @State private var shift: CGFloat = -0.25

    var body: some View {
        text
            .overlay {
                GeometryReader { geo in
                    let w = geo.size.width
                    LinearGradient(colors: [warm, cool],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                        .saturation(1.15)
                        .brightness(0.05)
                        .scaleEffect(x: 1.5, y: 1.5, anchor: .center)
                        .offset(x: shift * w, y: shift * w * 0.4)
                        .animation(.linear(duration: duration).repeatForever(autoreverses: true), value: shift)
                }
                .mask(text)
            }
            .foregroundColor(warm)
            .onAppear { shift = 0.25 }
    }
}


// MARK: - 17 Arc Pulse
struct ArcPulseText: View {
    let text: Text
    var base: Color = Color("#7E2DF2")
    var highlight: Color = .white
    var duration: Double = 1.8

    @State private var angle: Double = -120

    var body: some View {
        text
            .foregroundColor(base)
            .overlay(
                AngularGradient(colors: [.clear, highlight.opacity(0.95), .clear],
                                center: .center,
                                angle: .degrees(angle))
                    .blur(radius: 0.6)
                    .saturation(1.1)
                    .brightness(0.03)
            )
            .mask(text)
            .onAppear {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    angle = 120
                }
            }
    }
}

// MARK: - 18 Chromatic Split (micro parallax)
struct ChromaticSplitText: View {
    let text: Text
    var base: Color = Color("#B400FF")
    var redGhost: Color = Color(red: 1, green: 0, blue: 0).opacity(0.35)
    var cyanGhost: Color = Color(red: 0, green: 1, blue: 1).opacity(0.35)
    var duration: Double = 1.2

    @State private var off: CGFloat = 0.0

    var body: some View {
        ZStack {
            text.foregroundColor(base)
            text
                .foregroundColor(redGhost)
                .offset(x: -off, y: 0)
            text
                .foregroundColor(cyanGhost)
                .offset(x: off, y: 0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                off = 1.6 // px-ish offset (depends on scale)
            }
        }
    }
}

// MARK: - 19 Holo Prism Orbit (restrained iridescence)
struct HoloPrismText: View {
    let text: Text
    var duration: Double = 4.0

    @State private var angle: Double = 0
    @State private var didStart = false

    private let colors: [Color] = [
        Color("#FF0055"), Color("#FFEA00"),
        Color("#00FFB7"), Color("#00A3FF"),
        Color("#B400FF"), Color("#FF0055")
    ]

    var body: some View {
        text
            .overlay(
                AngularGradient(gradient: Gradient(colors: colors.map { $0.opacity(0.9) }),
                                center: .center,
                                angle: .degrees(angle))
                    .blur(radius: 0.5) // slightly softer than 20+
            )
            .mask(text)
            .onAppear {
                guard !didStart else { return }
                didStart = true
                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                    angle = 360
                }
            }
    }
}

// MARK: - 20+ Legendary Flare
struct LegendaryText: View {
    let text: Text
    var orbitDuration: Double = 2.6
    var pulseDuration: Double = 1.8

    @State private var angle: Double = 0
    @State private var pulse: CGFloat = 0.2
    @State private var started = false

    // Prismatic set
    private let prism: [Color] = [
        Color("#FF0055"), Color("#FFEA00"),
        Color("#00FFB7"), Color("#00A3FF"),
        Color("#B400FF"), Color("#FF0055")
    ]
    private let aura = Color("#FFEA00") // legendary gold

    var body: some View {
        ZStack {
            // Prismatic orbit fill
            text
                .overlay(
                    AngularGradient(gradient: Gradient(colors: prism),
                                    center: .center,
                                    angle: .degrees(angle))
                )
                .mask(text)

            // Glowing ring that breathes
            text
                .overlay {
                    GeometryReader { geo in
                        let d = max(geo.size.width, geo.size.height)
                        Circle()
                            .strokeBorder(
                                LinearGradient(colors: [.white.opacity(0.9),
                                                        aura.opacity(0.45),
                                                        .clear],
                                               startPoint: .topLeading,
                                               endPoint: .bottomTrailing),
                                lineWidth: max(1, d * 0.03)
                            )
                            .blur(radius: d * 0.02)
                            .scaleEffect(0.9 + 0.15 * pulse)
                            .opacity(0.35 + 0.35 * pulse)
                            .blendMode(.plusLighter)
                            .frame(width: d, height: d)
                            .position(x: geo.size.width/2, y: geo.size.height/2)
                            .animation(.easeInOut(duration: pulseDuration).repeatForever(autoreverses: true),
                                       value: pulse)
                    }
                }
                .mask(text)

            // Core gold pulse
            text
                .overlay {
                    GeometryReader { geo in
                        let m = max(geo.size.width, geo.size.height)
                        RadialGradient(colors: [aura.opacity(0.6 * pulse), .clear],
                                       center: .center,
                                       startRadius: 0,
                                       endRadius: m * 0.6)
                            .animation(.easeInOut(duration: pulseDuration).repeatForever(autoreverses: true),
                                       value: pulse)
                    }
                }
                .mask(text)
        }
        .onAppear {
            guard !started else { return }
            started = true
            withAnimation(.linear(duration: orbitDuration).repeatForever(autoreverses: false)) {
                angle = 360
            }
            pulse = 1.0
        }
    }
}

