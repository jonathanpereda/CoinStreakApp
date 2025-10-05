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
            groundY: lipY,                         // baseline you found for the table lip
            duration: 0.60,                        // a touch heavier than the coin’s
            count: 25,                             // denser plume
            baseColor: Color.white.opacity(0.60),
            shadowColor: Color.black.opacity(0.18),
            seed: 777                              // different seed from coin puff
        )
        .frame(width: width, height: height)
        // 2) Shape it to look like an upward column
        .scaleEffect(x: horizNarrow, y: vertStretch, anchor: .bottom)
        // 3) Clip to only show ABOVE the table lip
        .mask(
            Rectangle()
                .frame(width: width, height: lipY - 1)
                .position(x: width / 2, y: (lipY - 1) / 2)
        )
        // 4) Feather the LEFT/RIGHT edges so it feels like a vertical plume
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

