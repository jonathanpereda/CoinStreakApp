import SwiftUI
import Foundation

// MARK: - Bottom MENU

struct SquareHUDButton<Content: View>: View {
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
                .fill(.ultraThinMaterial.opacity(0.5))
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

struct MapItem: Identifiable, Equatable {
    let id: Int        // 0 = Starter, 1... = non-starters in order
    let name: String
    let thumbName: String?   // optional asset name for a thumbnail (plug later)
}

func makeMapItems(_ progression: ProgressionManager) -> [MapItem] {
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
func currentMapListIndex(_ progression: ProgressionManager) -> Int {
    if progression.levelIndex % 2 == 0 { return 0 }
    let i = (progression.levelIndex / 2) % max(progression.nonStarterNames.count, 1)
    return i + 1
}

struct MapTile: View {
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
struct BackwallThumb: View {
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

struct SettingsTile<Content: View>: View {
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
                .shadow(radius: 4)

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


struct TrophyAnchorKey: PreferenceKey {
    static var defaultValue: [AchievementID: Anchor<CGRect>] = [:]
    static func reduce(value: inout [AchievementID: Anchor<CGRect>], nextValue: () -> [AchievementID: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}
