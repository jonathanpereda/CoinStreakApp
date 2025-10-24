import SwiftUI

struct TrophyCell: View {
    let achievement: Achievement
    let isUnlocked: Bool
    let isActive: Bool          // true = show description
    let onTap: () -> Void
    private let size: CGFloat = 90

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(.white.opacity(0.10))

            // Normal content (icon + label)
            VStack(spacing: 6) {
                ZStack {
                    if isUnlocked {
                        Image(achievement.thumbName)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .padding(.top, 10)
                            .padding(.horizontal, 8)
                    } else {
                        Image(achievement.silhouetteName)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .opacity(0.35)
                            .padding(.top, 10)
                            .padding(.horizontal, 8)
                    }
                }
                .frame(maxHeight: .infinity)

                Text(isUnlocked ? achievement.name : "????")
                    .font(.system(size: size * 0.10, weight: .semibold))
                    .foregroundColor(.white.opacity(isUnlocked ? 0.85 : 0.45))
                    .padding(.bottom, 6)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: size * 0.9, height: size * 0.9)
            .opacity(isActive ? 0 : 1)
            .allowsHitTesting(false)

            // Description layer (inline tooltip)
            Text(AchievementsCatalog.byID(achievement.id).shortBlurb)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
                .frame(width: size * 0.86, height: size * 0.86, alignment: .center)
                .opacity(isActive ? 1 : 0)
                .allowsHitTesting(false)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.35), radius: 5, x: 0, y: 3)
        .contentShape(Rectangle())
        .onTapGesture {
            guard isUnlocked else { return }
            onTap()
        }
        // smooth crossfade both ways
        .animation(.easeInOut(duration: 0.18), value: isActive)
    }
}
