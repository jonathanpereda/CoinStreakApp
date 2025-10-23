import SwiftUI

private enum Art {
    static let menuW: CGFloat = 1288.4
    static let menuH: CGFloat =  506.3
    static let lbW:   CGFloat = 1288.4
    static let lbH:   CGFloat =  845.0
}
private enum Offsets {
    static let dx: CGFloat = 16.0   // score_menu's left margin to screen
    static let dy: CGFloat = 14.7   // score_menu's top margin to screen
}

struct TopScoreboardOverlay: View {
    @ObservedObject var vm: ScoreboardVM
    @Binding var isOpen: Bool
    @Binding var isLeaderboardOpen: Bool

    @State private var rememberedLeaderboardOpen: Bool = false

    // subtle framing tweaks
    private let bleedX: CGFloat    = 0.8       // tiny left/right bleed
    private let topBleedY: CGFloat = 0.8       // small upward nudge

    private let headsFill = Color(hex: "#3C7DC0")
    private let tailsFill = Color(hex: "#C02A2B")
    private let barCorner: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width / Art.menuW

            // ==== score_menu (menu-local coords: subtract dx/dy) ====
            let barX = (60.1  - Offsets.dx + 19) * s
            let barY = (230.0 - Offsets.dy + 2) * s
            let barW = 1166 * s
            let barH = 86.0  * s

            let headsBox = CGRect(
                x: (155.6 - Offsets.dx + 10) * s, y: ( 78.9 - Offsets.dy + 9) * s,
                width: 172.5 * s, height: 49.3 * s
            )
            let tailsBox = CGRect(
                x: (1003.2 - Offsets.dx - 6) * s, y: ( 78.9 - Offsets.dy + 9) * s,
                width: 172.5 * s, height: 49.3 * s
            )

            // EXPAND button (menu-local)
            let expandBtnFrame = CGRect(
                x: ( 58.0 - Offsets.dx + 3) * s, y: (453.0 - Offsets.dy - 20) * s,
                width: 185.0 * s, height: 85.0 * s
            )

            // ==== leaderboard (absolute screen coords per the spec) ====
            // leaderboard art top-left is at (x:16, y:440) — we draw it with lbY offset.
            let lbY = (400.0) * s

            // COLLAPSE button: absolute screen coords — DO NOT subtract Offsets or add lbY.
            // Use the raw positions from the spec: x:58, y:1200, size: 185×85.
            let lbCollapseAbs = CGRect(
                x: 58.0 * s, y: 1200.0 * s,
                width: 185.0 * s, height: 85.0 * s
            )

            let menuH = Art.menuH * s
            let overlayHeight = isLeaderboardOpen ? max(menuH, lbY + Art.lbH * s) : menuH

            // menu container global shift (same as visuals)
            let menuShiftX: CGFloat = -bleedX
            let menuShiftY: CGFloat = -topBleedY
            let menuContainerWidth  = geo.size.width + 2 * bleedX

            ZStack(alignment: .topLeading) {

                // ---- LEADERBOARD art (under the menu) ----
                if isLeaderboardOpen {
                    Image("leaderboard")
                        .resizable()
                        .interpolation(.high)
                        .frame(width: geo.size.width + 2 * bleedX, height: Art.lbH * s)
                        .offset(x: -bleedX, y: lbY)
                        .allowsHitTesting(false)
                        .zIndex(0)
                }

                // ---- SCORE MENU visuals (no hit-testing) ----
                ZStack(alignment: .topLeading) {
                    Image("score_menu")
                        .resizable()
                        .interpolation(.high)
                        .frame(width: menuContainerWidth, height: Art.menuH * s)
                        .allowsHitTesting(false)
                        .zIndex(1)

                    // BAR
                    let heads = max(0, vm.heads)
                    let tails = max(0, vm.tails)
                    let sum   = heads + tails
                    let hFrac: CGFloat = (sum == 0) ? 0.5 : CGFloat(heads) / CGFloat(sum)
                    let leftW  = barW * hFrac
                    let rightW = barW - leftW

                    ZStack(alignment: .leading) {
                        Rectangle().fill(headsFill).frame(width: leftW,  height: barH)
                        Rectangle().fill(tailsFill).frame(width: rightW, height: barH)
                            .offset(x: leftW)

                        GeometryReader { g in
                            let leftCenterX  = max(0, min(leftW,  g.size.width)) / 2
                            let rightCenterX = leftW + max(0, min(rightW, g.size.width)) / 2

                            Text("\(heads)")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.92))
                                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                                .position(x: leftCenterX, y: g.size.height/2)

                            Text("\(tails)")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.92))
                                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                                .position(x: rightCenterX, y: g.size.height/2)
                        }
                    }
                    .frame(width: barW, height: barH)
                    .clipShape(RoundedRectangle(cornerRadius: barCorner, style: .continuous))
                    .position(x: barX + barW/2, y: barY + barH/2)
                    .saturation(vm.isOnline ? 1 : 0)
                    .allowsHitTesting(false)
                    .zIndex(2)

                    // Player counts
                    Text("\(vm.headsPlayers)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(vm.isOnline ? 0.95 : 0.65))
                        .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                        .frame(width: headsBox.width, height: headsBox.height)
                        .position(x: headsBox.midX, y: headsBox.midY)
                        .modifier(NumericMorph())
                        .allowsHitTesting(false)
                        .zIndex(2)

                    Text("\(vm.tailsPlayers)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(vm.isOnline ? 0.95 : 0.65))
                        .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                        .frame(width: tailsBox.width, height: tailsBox.height)
                        .position(x: tailsBox.midX, y: tailsBox.midY)
                        .modifier(NumericMorph())
                        .allowsHitTesting(false)
                        .zIndex(2)

                    // EXPAND button art (non-interactive)
                    if !isLeaderboardOpen {
                        Image("expand_leaderboard_button")
                            .resizable()
                            .frame(width: expandBtnFrame.width, height: expandBtnFrame.height)
                            .position(x: expandBtnFrame.midX, y: expandBtnFrame.midY)
                            .allowsHitTesting(false)
                            .zIndex(2)
                    }
                }
                .frame(width: menuContainerWidth, height: Art.menuH * s, alignment: .topLeading)
                .offset(x: menuShiftX, y: menuShiftY)
                .allowsHitTesting(false)
                .zIndex(5)

                // ---- TOP-LEVEL HIT ZONES ----

                if !isLeaderboardOpen {
                    // EXPAND (menu-local + same global shift; full intended size)
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                            isLeaderboardOpen = true
                        }
                    } label: {
                        Rectangle().fill(Color.white.opacity(0.001))
                    }
                    .frame(width: expandBtnFrame.width, height: expandBtnFrame.height)
                    .position(x: expandBtnFrame.midX + menuShiftX,
                              y: expandBtnFrame.midY + menuShiftY)
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
                    .zIndex(10_000)
                } else {
                    // COLLAPSE (absolute to screen; no dx/dy subtraction and no +lbY)
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                            isLeaderboardOpen = false
                        }
                    } label: {
                        Rectangle().fill(Color.white.opacity(0.001))
                    }
                    .frame(width: lbCollapseAbs.width, height: lbCollapseAbs.height)
                    .position(x: lbCollapseAbs.minX + lbCollapseAbs.width/2 - bleedX, // match leaderboard x-bleed
                              y: lbCollapseAbs.minY + lbCollapseAbs.height/2)        // absolute Y
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
                    .zIndex(10_000)
                }
            }
            .frame(width: geo.size.width, height: overlayHeight + topBleedY, alignment: .topLeading)
            .opacity(isOpen ? 1 : 0)
            .animation(.easeInOut(duration: 0.22), value: isOpen)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(isOpen)
            .onChange(of: isOpen) { _, nowOpen in
                if nowOpen {
                    isLeaderboardOpen = rememberedLeaderboardOpen
                } else {
                    rememberedLeaderboardOpen = isLeaderboardOpen
                    isLeaderboardOpen = false
                }
            }
        }
        .transition(.opacity)
        .zIndex(999)
    }
}
