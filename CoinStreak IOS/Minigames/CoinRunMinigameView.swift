import SwiftUI

struct CoinRunMinigameView: View {
    let context: MinigameContext

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Coin Run (placeholder)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)

                if let best = context.myBestScore {
                    Text("Best distance this week: \(best)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                } else {
                    Text("No distance recorded yet.")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }

                Button {
                    context.endSession()
                } label: {
                    Text("Close")
                        .font(.system(size: 16, weight: .semibold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(10)
                }
            }
            .padding(24)
        }
    }
}
