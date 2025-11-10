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
    //@StateObject private var leaderboardVM = LeaderboardVM()
    @StateObject private var nameVM = NameEntryVM()
    
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
                    
                    let boxOriginPx = CGPoint(x: 556, y: 720)    // top-left of the baked input box INSIDE leaderboard art
                    let boxSizePx   = CGSize(width: 397, height: 48)

                    // Scale to points (same 's' used above)
                    let boxW = boxSizePx.width * s
                    let boxH = boxSizePx.height * s

                    // Convert design-px origin → on-screen position:
                    // - The leaderboard's left/top on screen is (-bleedX, lbY)
                    // - Then add your design-pixel offset (scaled by 's')
                    let posX = (-bleedX) + boxOriginPx.x * s + boxW/2
                    let posY = lbY       + boxOriginPx.y * s + boxH/2

                    // Debug-on version so you can see it
                    NameEntryBar(vm: nameVM,
                                  boxSize: .init(width: boxW, height: boxH+6),
                                  showDebug: false)
                    .position(x: posX+28, y: posY+12)
                    .zIndex(20_000)
                    .allowsHitTesting(true)
                    
                    /*Text("Tap name to report")
                        .font(.system(size: 8, weight: .semibold))
                        .position(x: posX + 115, y: posY+5)
                        .foregroundStyle(.red.opacity(0.5))*/
                }
                if isLeaderboardOpen {
                    // Fixed viewport in design pixels (matches original static layout area).
                    // Adjust these if your baked art changes.
                    let listViewportOriginPx = CGPoint(x: 46, y: 272)   // top-left of list window inside leaderboard art
                    let listViewportSizePx   = CGSize(width: 1200, height: 420)

                    // Scale to points using the same 's' factor
                    let vpW = listViewportSizePx.width * s
                    let vpH = listViewportSizePx.height * s

                    // Convert design-space origin to on-screen center position.
                    // Leaderboard art’s top-left on screen is (-bleedX, lbY)
                    let vpCenterX = (-bleedX) + listViewportOriginPx.x * s + vpW / 2
                    let vpCenterY = lbY       + listViewportOriginPx.y * s + vpH / 2

                    LeaderboardContent(
                        heads: vm.headsTop,
                        tails: vm.tailsTop,
                        streakColor: streakColor,
                        headsTint: headsFill,
                        tailsTint: tailsFill
                    )
                    .frame(width: vpW, height: vpH, alignment: .top)
                    .clipped()
                    .position(x: vpCenterX, y: vpCenterY)
                    .zIndex(20_000)
                    .allowsHitTesting(true)
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
                            .frame(width: expandBtnFrame.width + 20, height: expandBtnFrame.height + 10)
                            .position(x: expandBtnFrame.midX + 10, y: expandBtnFrame.midY)
                            .allowsHitTesting(false)
                            .zIndex(2)
                    }
                    
                    // OFFLINE BADGE — bottom-right of the score menu (same look as before)
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
                        .background(Color.black.opacity(0.35))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                        )
                        .padding(.trailing, 14)  // tweak to taste
                        .padding(.bottom, 26)     // tweak to taste
                        .frame(width: menuContainerWidth, height: Art.menuH * s, alignment: .bottomTrailing)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                        .zIndex(3)
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
            .onChange(of: isLeaderboardOpen) { _, open in
                if open {
                    Task {
                        await nameVM.loadProfile()
                        await vm.refresh(includeLeaderboard: true)
                    }
                }
            }
            
        }
        .transition(.opacity)
        .zIndex(999)
    }
}

// MARK: LEADERBOARD CONTENT

private struct LeaderboardContent: View {
    let heads: [LeaderboardEntryDTO]
    let tails: [LeaderboardEntryDTO]
    let streakColor: (Int) -> Color
    let headsTint: Color
    let tailsTint: Color
    
    @State private var reportTarget: LeaderboardEntryDTO? = nil
    @State private var showReportConfirm: Bool = false

    var body: some View {
        GeometryReader { g in
            // Compute a strict layout to keep both columns inside the viewport.
            let totalW: CGFloat      = g.size.width
            let edgeInset: CGFloat   = 6        // small L/R padding so text doesn’t touch edges
            let interColGap: CGFloat = 12       // gap between the two columns
            let usableW: CGFloat     = max(0, totalW - 2 * edgeInset - interColGap)
            let colW: CGFloat        = usableW / 2

            ZStack {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top, spacing: interColGap) {
                            // Left column (Heads)
                            column(entries: heads, side: "H", colWidth: colW)
                                .frame(width: colW, alignment: .leading)

                            // Right column (Tails)
                            column(entries: tails, side: "T", colWidth: colW)
                                .frame(width: colW, alignment: .trailing)
                        }
                        .padding(.top, 4)
                        .padding(.horizontal, edgeInset)
                    }
                    .foregroundColor(.white)
                }
                .scrollBounceBehavior(.basedOnSize)
                .contentMargins(.vertical, 0, for: .scrollContent)
                .animation(nil, value: heads.map(\.installId))
                .animation(nil, value: tails.map(\.installId))

                // Subtle top/bottom fade to hint scrollability (non-interactive)
                VStack {
                    LinearGradient(
                        colors: [Color.black.opacity(0.18), Color.black.opacity(0.0)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 16)
                    .allowsHitTesting(false)

                    Spacer()

                    LinearGradient(
                        colors: [Color.black.opacity(0.0), Color.black.opacity(0.18)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 16)
                    .allowsHitTesting(false)
                }
            }
            .allowsHitTesting(true)
        }
    }

    @ViewBuilder
    private func column(entries: [LeaderboardEntryDTO], side: String, colWidth: CGFloat) -> some View {
        // Fixed widths for rank & streak; name width is computed to fit the column.
        let rankW: CGFloat   = 40
        let streakW: CGFloat = 36
        let gap: CGFloat     = 2
        let nameW: CGFloat   = max(60, colWidth - rankW - streakW - 2 * gap)

        VStack(alignment: .leading, spacing: 6) {
            if entries.isEmpty {
                Text("—").opacity(0.5)
            } else {
                ForEach(Array(entries.enumerated()), id: \.element.installId) { idx, e in
                    HStack(alignment: .firstTextBaseline, spacing: gap) {
                        if side == "T" {
                            // Right column (Tails): STREAK → NAME → RANK
                            Text("\(e.currentStreak)")
                                .font(.system(size: 14, weight: .heavy))
                                .monospacedDigit()
                                .foregroundColor(streakColor(e.currentStreak))
                                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                                .frame(width: streakW, alignment: .trailing)
                                .lineLimit(1)

                            Button {
                                reportTarget = e
                                showReportConfirm = true
                            } label: {
                                Text(e.displayName)
                                    .font(.system(size: 14, weight: .semibold))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .opacity(0.92)
                                    .frame(width: nameW, alignment: .trailing)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            Text("[\(idx + 1)]")
                                .font(.system(size: 14, weight: .bold))
                                .monospacedDigit()
                                .lineLimit(1)
                                .opacity(0.75)
                                .frame(width: rankW, alignment: .trailing)
                                .overlay(
                                    Text("[\(idx + 1)]")
                                        .font(.system(size: 14, weight: .bold))
                                        .monospacedDigit()
                                        .lineLimit(1)
                                        .foregroundStyle(tailsTint)
                                        .opacity(0.22)
                                        .frame(width: rankW, alignment: .trailing)
                                )

                        } else {
                            // Left column (Heads): RANK → NAME → STREAK
                            Text("[\(idx + 1)]")
                                .font(.system(size: 14, weight: .bold))
                                .monospacedDigit()
                                .lineLimit(1)
                                .opacity(0.75)
                                .frame(width: rankW, alignment: .leading)
                                .overlay(
                                    Text("[\(idx + 1)]")
                                        .font(.system(size: 14, weight: .bold))
                                        .monospacedDigit()
                                        .lineLimit(1)
                                        .foregroundStyle(headsTint)
                                        .opacity(0.22)
                                        .frame(width: rankW, alignment: .leading)
                                )

                            Button {
                                reportTarget = e
                                showReportConfirm = true
                            } label: {
                                Text(e.displayName)
                                    .font(.system(size: 14, weight: .semibold))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .opacity(0.92)
                                    .frame(width: nameW, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            Text("\(e.currentStreak)")
                                .font(.system(size: 14, weight: .heavy))
                                .monospacedDigit()
                                .foregroundColor(streakColor(e.currentStreak))
                                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                                .frame(width: streakW, alignment: .leading)
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(alignment: .topLeading)
        .alert("Report this name?", isPresented: $showReportConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Report", role: .destructive) {
                guard let t = reportTarget else { return }
                let reporter = InstallIdentity.getOrCreateInstallId()
                Task {
                    _ = await ScoreboardAPI.reportName(
                        reporterInstallId: reporter,
                        targetInstallId: t.installId,
                        reason: "inappropriate-username",
                        details: "Reported from leaderboard tap"
                    )
                }
                showReportConfirm = false
            }
        } message: {
            if let t = reportTarget {
                Text("“\(t.displayName)”")
            } else {
                Text("")
            }
        }
    }
}
