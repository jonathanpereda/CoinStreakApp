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


struct RainbowText: View {
    let text: Text
    var duration: Double = 3.0

    @State private var phase: Double = 0

    // Looping rainbow (start == end to make a seamless rotation)
    private let colors: [Color] = [
        Color("#FF0055"), Color("#FFEA00"),
        Color("#00FFB7"), Color("#00A3FF"),
        Color("#B400FF"), Color("#FF0055")
    ]

    var body: some View {
        // Use overlay + mask (safe on iOS 16/17) instead of foregroundStyle
        text
            .overlay(
                AngularGradient(gradient: Gradient(colors: colors),
                                center: .center,
                                angle: .degrees(phase))
            )
            .mask(text) // the gradient only fills the glyphs
            .onAppear {
                // Avoid re-starting animation if the view re-appears during state changes
                if phase == 0 {
                    withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                        phase = 360
                    }
                }
            }
    }
}

