import SwiftUI

struct AwardPulse: Identifiable, Equatable {
    let id: UUID
    let start: Double
    let delta: Double
    let end: Double
    let color: Color
    let tierIndex: Int
}

struct TierProgressBar: View {
    let tierIndex: Int
    let total: Int
    let liveValue: Double
    let pulse: AwardPulse?

    var height: CGFloat = 22
    var corner: CGFloat = 12
    var baseFill: LinearGradient = LinearGradient(
        colors: [ Color.white,
                  Color(red: 1.0, green: 0.922, blue: 0.60) ],
        startPoint: .leading, endPoint: .trailing
    )

    @State private var shownBase: Double = 0
    @State private var wedgeWidth: Double = 0
    @State private var wedgeOpacity: Double = 0
    @State private var finalYellowOpacity: Double = 0
    @State private var targetEnd: Double = 0
    @State private var animatingPulse = false
    @State private var lastPulseID: UUID?

    private func frac(_ v: Double) -> Double {
        guard total > 0 else { return 0 }
        return min(1.0, max(0.0, v / Double(total)))
    }

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                )

            GeometryReader { geo in
                let totalW = geo.size.width
                let baseW  = totalW * frac(shownBase)
                let combinedW = totalW * frac(shownBase + wedgeWidth)
                let finalW = totalW * frac(targetEnd)

                // UNDERLAY: streak-colored extension (base + wedge)
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(pulse?.color ?? .white)
                    .frame(width: max(0, combinedW))
                    .opacity(wedgeOpacity)
                    //.shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)

                // OVERLAY: frozen yellow base (never moves during wedge)
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(baseFill)
                    .frame(width: max(0, baseW))
                    .shadow(color: .black.opacity(0.25 * (1 - finalYellowOpacity)), radius: 3, x: 0, y: 1)

                // OVERLAY: full-width yellow for the merge crossfade
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(baseFill)
                    .frame(width: max(0, finalW))
                    .opacity(finalYellowOpacity)
                    .shadow(color: .black.opacity(0.25 * finalYellowOpacity), radius: 3, x: 0, y: 1)
                
            }
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        }
        .mask(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .frame(height: height)

        .onAppear {
            shownBase = liveValue
            wedgeWidth = 0
            wedgeOpacity = 0
            finalYellowOpacity = 0
            targetEnd = liveValue
        }

        .onChange(of: tierIndex) { _, _ in
            animatingPulse = false
            wedgeWidth = 0
            wedgeOpacity = 0
            finalYellowOpacity = 0
            targetEnd = 0
            withTransaction(.init(animation: nil)) { shownBase = 0 }
        }

        // ★ Gate: if a NEW pulse is pending, ignore liveValue changes so the base never moves first.
        .onChange(of: liveValue) { _, new in
            if let p = pulse, p.id != lastPulseID { return }  // ← pulse pending; freeze base
            guard !animatingPulse else { return }
            withAnimation(.easeOut(duration: 0.28)) {
                shownBase = new
                targetEnd = new
            }
        }
        
        .onChange(of: total) { _, _ in
            // New bar → wipe all transient state immediately (no animation)
            animatingPulse = false
            lastPulseID = nil
            withTransaction(.init(animation: nil)) {
                shownBase = 0
                wedgeWidth = 0
                wedgeOpacity = 0
                finalYellowOpacity = 0
                targetEnd = 0
            }
        }



        // Pulse: freeze base to pre-award, grow wedge UNDER it, crossfade to final yellow, then snap base.
        .onChange(of: pulse?.id) { _, newID in
            guard let p = pulse, newID != nil, newID != lastPulseID else { return }
            lastPulseID = p.id
            animatingPulse = true

            // ★ Freeze base exactly at pre-award width (no animation).
            withTransaction(.init(animation: nil)) {
                shownBase = p.start     // ← force to the true pre-award width
                targetEnd = p.end
                wedgeWidth = 0
                wedgeOpacity = 1
                finalYellowOpacity = 0
            }

            // Grow just the extension amount.
            let needed = max(0.0, p.end - p.start)

            withAnimation(.easeOut(duration: 0.28)) {
                wedgeWidth = needed
            }

            // Crossfade merge to final yellow, then snap base behind the overlay.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.29) {
                guard p.tierIndex == tierIndex else {
                    animatingPulse = false
                    wedgeWidth = 0
                    wedgeOpacity = 0
                    finalYellowOpacity = 0
                    return
                }
                withAnimation(.easeOut(duration: 0.22)) {
                    finalYellowOpacity = 1
                    wedgeOpacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                    withTransaction(.init(animation: nil)) {
                        shownBase = p.end    // snap base to final with overlay hiding any jump
                    }
                    withAnimation(.linear(duration: 0.01)) {
                        finalYellowOpacity = 0
                    }
                    wedgeWidth = 0
                    animatingPulse = false
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Progress"))
        .accessibilityValue(Text("\(Int((frac(shownBase) * 100).rounded())) percent"))
    }
}
