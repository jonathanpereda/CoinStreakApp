import SwiftUI

struct CallItTableCardOverlay: View {
    let sideLetter: String
    let screenSize: CGSize

    @State private var floatOffset: CGFloat = 0
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            let designWidth: CGFloat = 1320
            let designHeight: CGFloat = 2868

            let scaleX = screenSize.width / designWidth
            let scaleY = screenSize.height / designHeight
            let scale = min(scaleX, scaleY)

            let cardDesignWidth: CGFloat = 225.3
            let cardDesignHeight: CGFloat = 309.5

            let cardWidth = cardDesignWidth * scale
            let cardHeight = cardDesignHeight * scale

            let designPosX: CGFloat = 1220
            let designPosY: CGFloat = 2570

            let posX = (designPosX + cardDesignWidth / 2) * scale
            let basePosY = (designPosY + cardDesignHeight / 2) * scale

            Image("callit_table_card_\(sideLetter)")
                .resizable()
                .frame(width: cardWidth, height: cardHeight)
                .rotationEffect(.degrees(rotation))
                .shadow(
                    color: Color.black.opacity(0.35),
                    radius: 8,
                    x: 0,
                    y: 8
                )
                .position(x: posX, y: basePosY + floatOffset)
        }
        .frame(width: screenSize.width, height: screenSize.height)
        .allowsHitTesting(false)
        .onAppear {
            floatOffset = 0
            rotation = -0.6

            let h = screenSize.height

            withAnimation(
                .easeInOut(duration: 2.4)
                    .repeatForever(autoreverses: true)
            ) {
                floatOffset = -h * (7.5 / 2868.0)
            }

            withAnimation(
                .easeInOut(duration: 3.0)
                    .repeatForever(autoreverses: true)
            ) {
                rotation = 0.6
            }
        }
    }
}
