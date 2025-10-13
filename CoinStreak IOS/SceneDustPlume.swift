//
//  SceneDustPlume.swift
//  CoinStreak
//
//  Created by Jonathan Pereda on 10/5/25.
//
import SwiftUI

struct SceneDustPlume: View {
    let trigger: Date
    let lipY: CGFloat
    let width: CGFloat
    let height: CGFloat

    // Style knobs for the plume *shape*
    var horizNarrow: CGFloat = 0.85   // < 1 narrows horizontally
    var vertStretch: CGFloat = 1.8    // > 1 stretches vertically
    var windowWidthFrac: CGFloat = 0.62  // plume “window” width as a fraction of screen

    var body: some View {
        // 1) Render DustPuff full-screen
        DustPuff(
            trigger: trigger,
            originX: width / 2,
            groundY: lipY,
            duration: 0.60,
            count: 25,
            baseColor: Color.white.opacity(0.60),
            shadowColor: Color.black.opacity(0.18),
            seed: 777
        )
        .frame(width: width, height: height)
        .scaleEffect(x: horizNarrow, y: vertStretch, anchor: .bottom)
        .mask(
            Rectangle()
                .frame(width: width, height: lipY - 1)
                .position(x: width / 2, y: (lipY - 1) / 2)
        )
        .mask(
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear,  location: 0.00),
                    .init(color: .white,  location: 0.20),
                    .init(color: .white,  location: 0.80),
                    .init(color: .clear,  location: 1.00),
                ]),
                startPoint: .leading, endPoint: .trailing
            )
        )
        .allowsHitTesting(false)
    }
}

