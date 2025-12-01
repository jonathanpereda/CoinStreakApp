import SwiftUI
import Foundation

private struct NewsHeadlinesDTO: Decodable {
    let asOf: String
    let slot1: String
    let slot2: String
    let slot3: String
}

/// Overlay that renders the three news-map headlines with the "burn-in" glow effect.
/// Coordinates are mapped from the 1320x2868 design canvas to the current screen size.
struct NewsHeadlinesOverlay: View {
    let screenSize: CGSize

    @State private var headlineTop: String = "FLIP STREAK DAILY"
    @State private var headlineMiddle: String = "HEADS AND TAILS AT WAR"
    @State private var headlineBottom: String = "BREAKING: THE SKY IS BLUE"
    @State private var asOfVersion: String? = nil

    @State private var appearProgress: CGFloat = 0.0
    @State private var glowOpacity: CGFloat = 0.0

    // Re-run the burn-in animation for whatever text is currently set.
    private func runBurnAnimation() {
        // Reset animation state
        appearProgress = 0.0
        glowOpacity = 0.0

        // Fade the ink in from invisible → fully visible
        withAnimation(.easeOut(duration: 0.9)) {
            appearProgress = 1.0
        }

        // Glow / burn effect while appearing
        withAnimation(.easeInOut(duration: 0.4)) {
            glowOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.7).delay(0.4)) {
            glowOpacity = 0.0
        }
    }

    // Base design canvas (matches 1320x2868 layout)
    private let designW: CGFloat = 1320
    private let designH: CGFloat = 2868

    // UserDefaults keys for caching the last-known headlines
    private let defaultsAsOfKey   = "newsHeadlines.asOf"
    private let defaultsTopKey    = "newsHeadlines.top"
    private let defaultsMiddleKey = "newsHeadlines.middle"
    private let defaultsBottomKey = "newsHeadlines.bottom"

    // Newspaper clipping bounding boxes (px) from layout
    private let boxSize = CGSize(width: 300, height: 162)

    // (treated as top-left origins, not centers)
    private let topOrigin    = CGPoint(x: 983, y: 375)
    private let middleOrigin = CGPoint(x: 983, y: 910)
    private let bottomOrigin = CGPoint(x: 983, y: 1456)

    private var scaleX: CGFloat { screenSize.width  / designW }
    private var scaleY: CGFloat { screenSize.height / designH }

    // Helper to render one headline box at a given design-space origin (top-left)
    private func box(_ text: String, origin: CGPoint) -> some View {
        let w = boxSize.width * scaleX
        let h = boxSize.height * scaleY

        // Treat origin.x / origin.y as TOP-LEFT of the box,
        // convert to center for SwiftUI .position.
        let x = (origin.x + boxSize.width  / 2) * scaleX
        let y = (origin.y + boxSize.height / 2) * scaleY

        let baseColor = Color(red: 156.0/255.0, green: 134.0/255.0, blue: 98.0/255.0) // #9C8662
        let glowColor = Color(red: 1.0, green: 0.72, blue: 0.30) // warmer, fire-like glow

        return ZStack {
            // Base ink layer: fades in from 0 → 1
            Text(text)
                .font(
                    .custom(
                        "Arial-Black",
                        size: 34 * min(scaleX, scaleY)
                    )
                )
                .foregroundColor(baseColor)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
                .frame(width: w, height: h, alignment: .center)
                .opacity(Double(appearProgress))

            // Glowing burn layer on top: appears while text is coming in, then fades out
            Text(text)
                .font(
                    .custom(
                        "Arial-Black",
                        size: 34 * min(scaleX, scaleY)
                    )
                )
                .foregroundColor(glowColor)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .frame(width: w, height: h, alignment: .center)
                .opacity(Double(glowOpacity))
                .shadow(color: glowColor.opacity(0.9), radius: 10, x: 0, y: 0)
                .shadow(color: glowColor.opacity(0.6), radius: 18, x: 0, y: 0)
                .shadow(color: glowColor.opacity(0.4), radius: 26, x: 0, y: 0)
                .blendMode(.screen)
        }
        .position(x: x, y: y)
    }

    var body: some View {
        ZStack {
            box(headlineTop,
                origin: topOrigin)

            box(headlineMiddle,
                origin: middleOrigin)

            box(headlineBottom,
                origin: bottomOrigin)
        }
        .allowsHitTesting(false)
        .onAppear {
            // Initial burn-in when the News map becomes visible
            runBurnAnimation()

            // Kick off the async refresh loop in its own Task
            startHeadlineRefreshLoop()
        }
        /*.task {
            // 1) Seed from any cached headlines (if present)
            await loadCachedHeadlines()
            // 2) Immediately try to fetch fresh data
            await refreshHeadlinesIfNeeded()
            // 3) Keep checking every few minutes while this overlay is visible
            await pollForHeadlineUpdates()
        }*/
    }

    @MainActor
    private func loadCachedHeadlines() {
        let ud = UserDefaults.standard
        if let savedAsOf = ud.string(forKey: defaultsAsOfKey) {
            asOfVersion = savedAsOf
        }
        if let s = ud.string(forKey: defaultsTopKey) {
            headlineTop = s
        }
        if let s = ud.string(forKey: defaultsMiddleKey) {
            headlineMiddle = s
        }
        if let s = ud.string(forKey: defaultsBottomKey) {
            headlineBottom = s
        }
    }

    @MainActor
    private func cacheHeadlines(asOf: String, top: String, middle: String, bottom: String) {
        let ud = UserDefaults.standard
        ud.set(asOf,   forKey: defaultsAsOfKey)
        ud.set(top,    forKey: defaultsTopKey)
        ud.set(middle, forKey: defaultsMiddleKey)
        ud.set(bottom, forKey: defaultsBottomKey)
        asOfVersion     = asOf
        headlineTop     = top
        headlineMiddle  = middle
        headlineBottom  = bottom
    }
    
    private func startHeadlineRefreshLoop() {
        Task {
            // 1) Load from cache immediately on main actor
            await MainActor.run {
                loadCachedHeadlines()
            }

            // 2) One immediate fetch
            await refreshHeadlinesIfNeeded()

            // 3) Optional: background polling
            await pollForHeadlineUpdates()
        }
    }

    private func refreshHeadlinesIfNeeded() async {
        // Build /v1/news URL off the same base used elsewhere
        let url = ScoreboardAPI.base.appendingPathComponent("/v1/news-headlines")

        do {
            let (data, resp) = try await URLSession.shared.data(from: url)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
                return
            }

            let dto = try JSONDecoder().decode(NewsHeadlinesDTO.self, from: data)

            // Only update if it's a new version
            if dto.asOf == asOfVersion {
                return
            }

            await MainActor.run {
                cacheHeadlines(
                    asOf: dto.asOf,
                    top: dto.slot1,
                    middle: dto.slot2,
                    bottom: dto.slot3
                )

                // Re-run the burn effect to smoothly reveal updated headlines
                runBurnAnimation()
            }
        } catch {
            print("news headlines fetch failed:", error.localizedDescription)
        }
    }

    private func pollForHeadlineUpdates() async {
        while !Task.isCancelled {
            // Sleep for 5 minutes between checks
            try? await Task.sleep(nanoseconds: 1 * 60 * 1_000_000_000)
            if Task.isCancelled { break }
            await refreshHeadlinesIfNeeded()
        }
    }
}
