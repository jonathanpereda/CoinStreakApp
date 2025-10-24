import SwiftUI


// MARK: RECENT FLIPS COLUMN
func chosenIconName(_ face: Face?) -> String? {
    guard let f = face else { return nil }
    return (f == .Tails) ? "t_icon" : "h_icon"
}

struct RecentFlipsColumn: View {
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
