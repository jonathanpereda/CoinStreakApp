import SwiftUI


extension Color {
    init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexSanitized.hasPrefix("#") { hexSanitized.removeFirst() }

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

struct SlidingScoreboardPanel: View {
    @ObservedObject var vm: ScoreboardVM
    @State private var isOpen = false
    @State private var showBar = false   // shows through open; hides after close

    // @3x assets → px/3 (change to /2 if @2x)
    private let panelWidth:  CGFloat = 1004.0 / 3.0
    private let panelHeight: CGFloat =  373.0 / 3.0
    private let tabWidth:    CGFloat =   89.0 / 3.0

    // tuned bar geometry
    private let barWidth:  CGFloat =  915.0 / 3.0
    private let barHeight: CGFloat =   69.0 / 3.0
    private let barLeft:   CGFloat =   50.0 / 3.0
    private let barCenterY:CGFloat =  295.5 / 3.0
    private let barCorner: CGFloat = 4   // less rounded

    // Player-count boxes (px → pt @3x)
    private let boxW: CGFloat = 133.0 / 3.0
    private let boxH: CGFloat =  38.0 / 3.0
    private let headsBoxX: CGFloat =  88.0 / 3.0
    private let headsBoxY: CGFloat = 141.0 / 3.0
    private let tailsBoxX: CGFloat = 803.0 / 3.0
    private let tailsBoxY: CGFloat = 141.0 / 3.0
    
    // Anim + your eps tweaks
    private let anim    = Animation.spring(response: 0.35, dampingFraction: 0.85)
    private let animDur : Double = 0.35
    private let CLOSED_EPS: CGFloat = -5    // pushes closed a bit further right
    private let OPEN_EPS:   CGFloat =  20   // tiny nudge when open so edge is flush

    var body: some View {
        ZStack(alignment: .trailing) {

            // MENU + BAR move together
            ZStack(alignment: .topLeading) {
                Image("score_panel_bg")
                    .resizable()
                    .interpolation(.high)
                    .frame(width: panelWidth, height: panelHeight)

                // math
                let heads = max(0, vm.heads)
                let tails = max(0, vm.tails)
                let sum   = heads + tails
                let hFrac: CGFloat = (sum == 0) ? 0.5 : CGFloat(heads) / CGFloat(sum)
                let leftW  = barWidth * hFrac
                let rightW = barWidth - leftW

                // BAR + COUNTS
                ZStack(alignment: .leading) {
                    // fills
                    Rectangle()
                        .fill(Color(hex: "#3C7DC0")) // Heads color (or your new picks)
                        .frame(width: leftW, height: barHeight)

                    Rectangle()
                        .fill(Color(hex: "#C02A2B")) // Tails color
                        .frame(width: rightW, height: barHeight)
                        .offset(x: leftW)

                    // counts overlay (center each number within its half)
                    GeometryReader { g in
                        // positions for text centers
                        let leftCenterX  = max(0, min(leftW, g.size.width)) / 2
                        let rightCenterX = leftW + max(0, min(rightW, g.size.width)) / 2

                        // Heads count
                        Text("\(heads)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.92))
                            .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                            .position(x: leftCenterX, y: g.size.height/2)

                        // Tails count
                        Text("\(tails)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.92))
                            .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                            .position(x: rightCenterX, y: g.size.height/2)
                    }
                }
                .frame(width: barWidth, height: barHeight, alignment: .leading) // important
                .clipShape(RoundedRectangle(cornerRadius: barCorner, style: .continuous))
                .offset(x: barLeft, y: barCenterY - barHeight/2)
                .opacity(showBar ? 1 : 0)
                .saturation(vm.isOnline ? 1 : 0)   // greyscale when offline
                .animation(.none, value: showBar)
                .allowsHitTesting(false)
                
                // HEADS player count (left box)
                Text("\(vm.headsPlayers)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(vm.isOnline ? 0.95 : 0.65))
                    .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                    .frame(width: boxW, height: boxH, alignment: .center)
                    .offset(x: headsBoxX, y: headsBoxY)
                    .allowsHitTesting(false)
                    .modifier(NumericMorph()) // smooth change on iOS 17+

                // TAILS player count (right box)
                Text("\(vm.tailsPlayers)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(vm.isOnline ? 0.95 : 0.65))
                    .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                    .frame(width: boxW, height: boxH, alignment: .center)
                    .offset(x: tailsBoxX, y: tailsBoxY)
                    .allowsHitTesting(false)
                    .modifier(NumericMorph())
                
                // OFFLINE BADGE (left side of main box)
                if !vm.isOnline {
                    HStack(spacing: 6) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 11, weight: .bold))
                        Text("Offline")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.35))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(.white.opacity(0.25), lineWidth: 0.5)
                    )
                    // position near left edge; adjust to taste
                    .offset(x: 8, y: 17)
                    .transition(.opacity)
                }
            }
            // slide distances — exactly what you wanted
            .offset(x: isOpen ? OPEN_EPS : (panelWidth - CLOSED_EPS))
            .animation(anim, value: isOpen)

            // TAB glued to menu’s left edge (same base offset minus panel width)
            Button {
              if !isOpen {
                // OPENING: 1) show bar immediately (no fade), 2) slide on next tick
                withAnimation(.none) {        // ensure the bar appears with no fade
                  showBar = true
                }
                DispatchQueue.main.async {    // next runloop tick -> start slide
                  withAnimation(anim) {
                    isOpen = true
                  }
                }
              } else {
                // CLOSING: slide first, then hide bar after animation finishes
                withAnimation(anim) {
                  isOpen = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + animDur) {
                  showBar = false
                }
              }
            } label: {
              Image(isOpen ? "score_tab_right" : "score_tab_left")
                .resizable()
                .interpolation(.high)
                .frame(width: tabWidth, height: panelHeight)
            }
            .offset(x: (isOpen ? OPEN_EPS : (panelWidth - CLOSED_EPS)) - panelWidth)
            .animation(anim, value: isOpen)
        }
        .frame(width: panelWidth + tabWidth, height: panelHeight)
        /*.onAppear {
            vm.startPolling()        // <- start the 5s loop again
        }
        .task {
            await vm.refresh()       // <- do an immediate fetch so it updates right away
        }*/
        
    }
    
}

struct NumericMorph: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.contentTransition(.numericText())
                .animation(.easeOut(duration: 0.35), value: UUID()) // trigger on value change
        } else {
            content
        }
    }
}
