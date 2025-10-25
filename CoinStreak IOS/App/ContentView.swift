//
//  ContentView.swift
//  CoinStreak IOS
//
//  Created by Jonathan Pereda on 10/3/25.
//

import SwiftUI
import Foundation
import UIKit

///MISC

private enum AppPhase { case choosing, preRoll, playing }

// Score board
private func panelWidth() -> CGFloat {
    let scale = UIScreen.main.scale
    return 1004.0 / scale // PANEL_W_PX / scale
}
private func tabWidth() -> CGFloat {
    let scale = UIScreen.main.scale
    return 89.0 / scale // TAB_W_PX / scale
}



struct ContentView: View {
    
    // MARK: STATE VARS
    
    @StateObject private var store = FlipStore()
    
    // Score board stuff
    @State private var didRestorePhase = false
    @State private var didKickBootstrap = false
    @StateObject private var scoreboardVM = ScoreboardVM()
    @State private var isScoreMenuOpen: Bool = false
    @State private var isLeaderboardOpen: Bool = false
    @State private var isSettingsOpen: Bool = false
    
    // Achievement Stuff
    @StateObject private var achievements = AchievementsStore()
    @State private var isTrophiesOpen: Bool = false
    @State private var showNewTrophyToast: Bool = false
    @State private var activeTooltip: AchievementID? = nil
    @State private var tooltipHideWorkItem: DispatchWorkItem?
    @AppStorage("ach.progress.unlucky_wrong10")
    private var unluckyWrong10: Int = 0
    
    // Map menu stuff
    @Environment(\.scenePhase) private var scenePhase
    @State private var isMapSelectOpen = false
    @State private var manualTargetAfterClose: Int? = nil
    @State private var showNewMapToast = false
    @State private var lastUnlockedCount = 1   // starter = 1
    @State private var showCycleHint = false
    @State private var cycleHintText = "Cycle: On"

    @State private var curState = "Heads"

    // animation state
    @State var y: CGFloat = 0        // 0 = on ledge
    @State private var scale: CGFloat = 1.0

    // Layout
    private let coinDiameterPct: CGFloat = 0.565
    private let ledgeTopYPct: CGFloat = 0.97
    private let coinRestOverlapPct: CGFloat = 0.06

    // Flip state
    @State private var spritePlan: SpriteFlipPlan? = nil
    @State private var isFlipping = false
    @State private var baseFaceAtLaunch = "Heads"
    @State private var flightAngle: Double = 0
    @State private var flightTarget: Double = 0
    @State private var settleT: Double = 1.0   // 1 = idle (no wobble), animate 0 -> 1 on land
    @State var bounceGen: Int = 0   // cancels any in-flight bounce sequence
    @State private var settleBounceT: Double = 1.0   // 0→1 drives bounce curve; 1 = idle
    @State private var currentFlipWasSuper = false


    // App phase
    @State private var phase: AppPhase = .choosing
    @State private var gameplayOpacity: Double = 0   // 0 = hidden during pre-roll, 1 = visible
    @State private var counterOpacity: Double = 1.0
    
    //Face Icon
    @State private var iconPulse: Bool = false
    
    //DustPuff
    @State var gameplayDustTrigger: Date? = nil
    @State private var backwallDustTrigger: Date? = nil
    @State private var doorDustTrigger: Date? = nil

    //Progress
    @StateObject private var progression = ProgressionManager.standard()
    @State private var barPulse: AwardPulse?
    @State private var barValueOverride: Double? = nil
    @State private var isTierTransitioning = false
    @State private var deferCounterFadeInUntilClose = false
    @State private var fontBelowName: String = "Herculanum"   // default matches Starter
    @State private var fontAboveName: String = "Herculanum"
    @State private var lastTierName: String = "Starter"
    @State private var barNonce = 0
    
    //Settings
    @State private var sfxMutedUI   = SoundManager.shared.isSfxMuted
    @State private var musicMutedUI = SoundManager.shared.isMusicMuted
    @State private var hapticsEnabledUI = Haptics.shared.isEnabled
    @AppStorage("disableTapFlip") private var disableTapFlip = false


    @ViewBuilder
    private func streakLayer(fontName: String) -> some View {
        VStack {
            StreakCounter(value: store.currentStreak, fontName: fontName)
                .frame(maxWidth: .infinity)
                .padding(.top, 75)
                .padding(.horizontal, 20)
            Spacer()
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }
    

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = geo.size.height
            let coinD = W * coinDiameterPct
            let coinR = coinD / 2
            let coinCenterY = H * ledgeTopYPct - coinR * (1 - coinRestOverlapPct)
            let groundY = H * ledgeTopYPct

            // Shadow geometry for main coin (during gameplay)
            let jumpPx   = max(180, H * 0.32)
            let height01 = max(0, min(1, -y / jumpPx))

            let baseShadowW: CGFloat = coinD * 1.00
            let minShadowW:  CGFloat = coinD * 0.40

            let baseShadowH: CGFloat = coinD * 0.60
            let minShadowH:  CGFloat = coinD * 0.22

            let heightShrinkBias: CGFloat = 0.75
            let th = min(1, height01 / max(heightShrinkBias, 0.0001))

            let shadowW = baseShadowW + (minShadowW - baseShadowW) * height01
            let shadowHcur = baseShadowH + (minShadowH - baseShadowH) * th

            let shadowOpacity = 0.28 * (1.0 - 0.65 * height01)
            let shadowBlur    = 6.0 + 10.0 * height01

            let shadowYOffsetTweak: CGFloat = -157
            let shadowY_centerLocked = (groundY + baseShadowH / 2) + shadowYOffsetTweak
            
            let theme = tierTheme(for: progression.currentTierName)
            
            // MARK: MAIN UI RENDER

            ZStack {
                
                ElevatorSwitcher(
                    currentBackwallName: theme.backwall,
                    starterSceneName: "starter_backwall",
                    doorLeftName: "starter_left",
                    doorRightName: "starter_right",
                    belowDoors: {
                        // shows during open/close and when open
                        streakLayer(fontName: fontBelowName)
                    },
                    aboveDoors: {
                        // top copy, animate with counterOpacity
                        streakLayer(fontName: fontAboveName)
                            .opacity(counterOpacity)
                    },
                    onOpenEnded: {
                        // nothing needed for fonts here
                    },
                    onCloseEnded: {
                        // doors just finished closing on Starter → switch both to Starter font, then (optionally) fade top in
                        let now = Date()
                        doorDustTrigger = now
                        // auto-clear after the effect ends (keep in sync with DoorDustLine.duration)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.60) {
                            if doorDustTrigger == now { doorDustTrigger = nil }
                        }   
                        let starterFont = tierTheme(for: "Starter").font
                        fontBelowName = starterFont
                        fontAboveName = starterFont
                        if deferCounterFadeInUntilClose {
                            withAnimation(.easeInOut(duration: 0.25)) { counterOpacity = 1.0 }
                            deferCounterFadeInUntilClose = false
                        }
                        // If a manual nonstarter→nonstarter selection is waiting, jump to it now (this triggers OPEN)
                        if let pending = manualTargetAfterClose {
                            manualTargetAfterClose = nil
                            progression.jumpToLevelIndex(pending)   
                        }

                    }
                )
                
                if let trig = doorDustTrigger {
                    DoorDustLine.seamBurst(trigger: trig)
                        .id(trig)                       // remount per trigger
                        .frame(width: W, height: H)     // concrete size for Canvas
                        .allowsHitTesting(false)
                }

                Image("starter_table2")
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .ignoresSafeArea()
                
                // MARK: BAR & BADGE
                
                // HUD: progress bar + chosen-face badge (single instance, top of stack)
                if phase != .choosing, let icon = chosenIconName(store.chosenFace) {
                    let iconSize: CGFloat = 52
                    let barWidth = min(geo.size.width * 0.70, 360)
                    let extraRight: CGFloat = 20

                    HStack(spacing: 24) {
                        let tiltXDeg: Double = -14
                        let persp: CGFloat = 0.45
                        let barHeight: CGFloat = 28
                        let barColor = LinearGradient(colors: [ Color("#908B7A"), Color("#C0BAA2") ],
                                                      startPoint: .leading, endPoint: .trailing)

                        ZStack {
                            TierProgressBar(
                                tierIndex: progression.tierIndex,
                                total: progression.currentBarTotal,
                                liveValue: barValueOverride ?? progression.currentProgress,
                                pulse: barPulse,
                                height: barHeight,
                                corner: barHeight / 2,
                                baseFill: barColor
                            )
                            if progression.mapLocked {
                                Image(systemName: "pause.circle")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white.opacity(0.95))
                                    .shadow(radius: 2)
                                    .allowsHitTesting(false)
                            }
                        }
                        .frame(width: barWidth, height: barHeight)
                        .id("tier-\(progression.tierIndex)-\(barNonce)")
                        .compositingGroup()
                        .rotation3DEffect(.degrees(tiltXDeg),
                                          axis: (x: 1, y: 0, z: 0),
                                          anchor: .bottom,
                                          perspective: persp)
                        .onChange(of: progression.tierIndex) { _, _ in
                            barPulse = nil
                        }
                        .opacity((isMapSelectOpen || isSettingsOpen || isTrophiesOpen) ? 0 : 1)
                        .animation(.easeInOut(duration: 0.2), value: isMapSelectOpen)
                        .animation(.easeInOut(duration: 0.2), value: isSettingsOpen)
                        .animation(.easeInOut(duration: 0.2), value: isTrophiesOpen)



                        Image(icon)
                            .resizable()
                            .interpolation(.high)
                            .antialiased(true)
                            .renderingMode(.original)
                            .frame(width: iconSize, height: iconSize)
                            .shadow(color: iconPulse ? .yellow.opacity(0.5) : .clear,
                                    radius: iconPulse ? 3 : 0)
                            .animation(.easeOut(duration: 0.25), value: iconPulse)
                            .opacity((isMapSelectOpen || isSettingsOpen || isTrophiesOpen) ? 0 : 1)
                            .animation(.easeInOut(duration: 0.2), value: isMapSelectOpen)
                            .animation(.easeInOut(duration: 0.2), value: isSettingsOpen)
                            .animation(.easeInOut(duration: 0.2), value: isTrophiesOpen)
                    }
                    .padding(.trailing, geo.safeAreaInsets.trailing + extraRight)
                    .padding(.bottom, geo.safeAreaInsets.bottom + 36)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .allowsHitTesting(false)
                    .zIndex(50)                // keep above table/gameplay
                    .transition(.opacity)
                    
                    // MARK: BOTTOM MENU BUTTONS
                    
                    .overlay(alignment: .bottomLeading) {
                        ZStack(alignment: .leading) {

                            var anyBottomSheetOpen: Bool {
                                isMapSelectOpen || isSettingsOpen || isTrophiesOpen
                            }
                            
                            // === Buttons row (Map + Settings + Scoreboard) ===
                            HStack(spacing: 8) {
                                // MAP button
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                        if isSettingsOpen {
                                            isSettingsOpen = false           // close Settings if open
                                        } else if isTrophiesOpen {
                                            isTrophiesOpen = false           // close Trophies if open
                                        } else {
                                            isMapSelectOpen.toggle()
                                        }
                                    }
                                } label: {
                                    SquareHUDButton(
                                        isOutlined: showNewMapToast,
                                        outlineColor: Color(red: 0.35, green: 0.4, blue: 1.0)
                                    ) {
                                        Image(systemName: anyBottomSheetOpen ? "xmark" : "map.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 22, height: 22)
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                }
                                .buttonStyle(.plain)
                                
                                // TROPHIES button
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                        if isMapSelectOpen { isMapSelectOpen = false }
                                        if isSettingsOpen { isSettingsOpen = false }
                                        isTrophiesOpen.toggle()
                                    }
                                } label: {
                                    SquareHUDButton(
                                        isOutlined: showNewTrophyToast,
                                        outlineColor: Color(red: 1.0, green: 0.8, blue: 0.2)
                                    ) {
                                        Image(systemName: "trophy.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 22, height: 22)
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                }
                                .buttonStyle(.plain)
                                .opacity((isMapSelectOpen || isSettingsOpen || isTrophiesOpen) ? 0 : 1)
                                .disabled(isMapSelectOpen || isSettingsOpen || isTrophiesOpen)
                                .animation(.easeInOut(duration: 0.2), value: isMapSelectOpen)
                                .animation(.easeInOut(duration: 0.2), value: isSettingsOpen)
                                .animation(.easeInOut(duration: 0.2), value: isTrophiesOpen)


                                
                                // SETTINGS button
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                        if isMapSelectOpen { isMapSelectOpen = false }   // opening settings closes map
                                        isSettingsOpen.toggle()
                                    }
                                } label: {
                                    SquareHUDButton(isOutlined: false) {
                                        Image(systemName: "gearshape.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 22, height: 22)
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                }
                                .buttonStyle(.plain)
                                .opacity((isMapSelectOpen || isSettingsOpen || isTrophiesOpen) ? 0 : 1)
                                .disabled(isMapSelectOpen || isSettingsOpen || isTrophiesOpen)
                                .animation(.easeInOut(duration: 0.2), value: isMapSelectOpen)
                                .animation(.easeInOut(duration: 0.2), value: isSettingsOpen)
                                .animation(.easeInOut(duration: 0.2), value: isTrophiesOpen)



                                // SCOREBOARD menu button
                                Button {
                                    withAnimation(.easeInOut(duration: 0.22)) {
                                        if isScoreMenuOpen {
                                            isLeaderboardOpen = false
                                            isScoreMenuOpen = false
                                        } else {
                                            isScoreMenuOpen = true
                                        }
                                    }
                                } label: {
                                    SquareHUDButton(isOutlined: isScoreMenuOpen) {
                                        Image("scoreboard_menu_icon")
                                            .resizable()
                                            .interpolation(.high)
                                            .scaledToFit()
                                            .frame(width: 22, height: 22)
                                            .opacity(0.8)
                                    }
                                }
                                .buttonStyle(.plain)
                                .opacity((isMapSelectOpen || isSettingsOpen || isTrophiesOpen) ? 0 : 1)
                                .disabled(isMapSelectOpen || isSettingsOpen || isTrophiesOpen)
                                .animation(.easeInOut(duration: 0.2), value: isMapSelectOpen)
                                .animation(.easeInOut(duration: 0.2), value: isSettingsOpen)
                                .animation(.easeInOut(duration: 0.2), value: isTrophiesOpen)

                            }

                            // === Toast layer ===
                            if !anyBottomSheetOpen && showNewMapToast {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.15, green: 0.55, blue: 1.0, opacity: 0.95),
                                                Color(red: 0.50, green: 0.20, blue: 1.0, opacity: 0.95)
                                            ],
                                            startPoint: .leading, endPoint: .trailing
                                        )
                                    )
                                    .frame(width: 160, height: 24, alignment: .leading)
                                    .overlay(
                                        Text("New map unlocked")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 12),
                                        alignment: .leading
                                    )
                                    .padding(.leading, 0)
                                    .offset(y: -31)
                                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                                    .transition(.opacity)
                                    .animation(.easeInOut(duration: 0.5), value: showNewMapToast)
                                    .allowsHitTesting(false) // taps pass through to buttons underneath
                                    .zIndex(999)            // <<< ensures it sits above ANY buttons to the right
                            }
                            
                            // === Trophy toast ===
                            if !anyBottomSheetOpen && showNewTrophyToast {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.95, green: 0.78, blue: 0.10, opacity: 0.96),
                                                Color(red: 1.00, green: 0.55, blue: 0.18, opacity: 0.96)
                                            ],
                                            startPoint: .leading, endPoint: .trailing
                                        )
                                    )
                                    .frame(width: 170, height: 24, alignment: .leading)
                                    .overlay(
                                        Text("New trophy unlocked")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.black.opacity(0.85))
                                            .padding(.horizontal, 12),
                                        alignment: .leading
                                    )
                                    .padding(.leading, 45)
                                    .offset(y: -31)
                                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                                    .transition(.opacity)
                                    .animation(.easeInOut(duration: 0.5), value: showNewTrophyToast)
                                    .allowsHitTesting(false)
                                    .zIndex(999)
                            }

                            
                        }
                        .padding(.leading, 24)
                        .padding(.bottom, 30)
                        .opacity(phase != .choosing ? 1 : 0)
                        .animation(.easeInOut(duration: 0.2), value: phase)
                    }


                }


                // MARK: RENDER COIN
                Group {
                    // Shadow
                    Ellipse()
                        .fill(Color.black.opacity(shadowOpacity))
                        .frame(width: shadowW, height: shadowHcur)
                        .blur(radius: shadowBlur)
                        .position(x: W/2, y: shadowY_centerLocked-10)
                    
                    // Dust
                    if let trig = gameplayDustTrigger {
                        DustPuff(
                            trigger: trig,
                            originX: W / 2,
                            groundY: (groundY + baseShadowH / 2) + shadowYOffsetTweak-52,
                            duration: 0.48,
                            count: 16,
                            baseColor: Color.white.opacity(0.85),
                            shadowColor: Color.black.opacity(0.22),
                            seed: 42
                        )
                        .frame(width: W, height: H)


                    }

                    // Coin
                    ZStack {
                        SpriteCoinImage(
                            plan: spritePlan,
                            idleFace: (curState == "Heads") ? .H : .T,
                            width: coinD,
                            position: .init(x: W/2, y: coinCenterY)
                        )
                        .offset(y: y + CGFloat(bounceY(settleBounceT)))
                        .scaleEffect(scale)
                    }
                    .modifier(SettleWiggle(t: settleT))
                    .modifier(SettleBounce(t: settleBounceT))
                    .allowsHitTesting(false)
                    
                }
                .opacity(gameplayOpacity)                 // <— no animation; see onReveal below
                .allowsHitTesting(phase == .playing)      // disable taps until playing


                // MARK: INPUT HITBOX
                if phase == .playing {
                    // Tune these two lines to adjust the band:
                    let topSafeInset: CGFloat    = max(geo.safeAreaInsets.top,     H * 0.22)
                    let bottomSafeInset: CGFloat = max(geo.safeAreaInsets.bottom,  H * 0.055)

                    let bandMinY: CGFloat   = topSafeInset
                    let bandMaxY: CGFloat   = H - bottomSafeInset
                    let bandHeight: CGFloat = max(0, bandMaxY - bandMinY)

                    Rectangle()
                        .fill(Color.clear) // set to .red.opacity(0.25) when debugging
                        .frame(width: W, height: bandHeight)
                        .position(x: W/2, y: bandMinY + bandHeight/2)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                                .onEnded { v in
                                    guard !isFlipping, !isTierTransitioning else { return }
                                    // Only accept gestures that START inside the band
                                    let startY = v.startLocation.y
                                    guard startY >= bandMinY && startY <= bandMaxY else { return }

                                    let dx = v.translation.width
                                    let dy = v.translation.height
                                    if hypot(dx, dy) < 10 {
                                        guard !disableTapFlip else { return }
                                        flipCoin()
                                    } else {
                                        let up = max(0, -dy)
                                        let predUp = max(0, -v.predictedEndTranslation.height)
                                        let extra = max(0, predUp - up)
                                        let raw = Double(up) + 0.5 * Double(extra)
                                        let impulse = raw / Double(H * 0.70)
                                        if impulse > 0.15 { flipCoin(impulse: impulse) }
                                    }
                                }
                        )
                        // IMPORTANT: keep below panels so they remain tappable
                        // .zIndex(0)  // (you can omit this; default is fine)
                }




            

                // MARK: RECENT FLIPS COLUMN
                if phase != .choosing, !store.recent.isEmpty {
                    // Where the BOTTOM should live (0.0 = top, 1.0 = bottom)
                    let baselineYPct: CGFloat = 0.30   // mid-left baseline
                    let baselineY = geo.size.height * baselineYPct

                    ZStack(alignment: .bottomLeading) {
                        RecentFlipsColumn(recent: store.recent, chosenFace: store.chosenFace)
                            .padding(.leading, max(12, geo.safeAreaInsets.leading + 4))
                    }
                    // Container height == distance from top → baseline; column is bottom-aligned inside
                    .frame(width: geo.size.width, height: baselineY, alignment: .bottomLeading)
                    .animation(.spring(response: 0.28, dampingFraction: 0.8), value: store.recent)
                    .transition(.opacity)
                    .allowsHitTesting(false)
                }
                
                // MARK: - MAP MENU WINDOW
                if isMapSelectOpen {
                    VStack {
                        Spacer()

                        // Bottom floating content: left column + (empty) right side for carousel
                        HStack(alignment: .center, spacing: 12) {
                            // LEFT COLUMN: lock toggle (icon-only) + close button
                            VStack(spacing: 12) {
                                
                                // Lock toggle icon (manual selects still allowed when ON)
                                Button {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        progression.mapLocked.toggle()
                                    }
                                    cycleHintText = progression.mapLocked ? "Cycle: OFF" : "Cycle: ON"
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            showCycleHint = true
                                        }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            showCycleHint = false
                                        }
                                    }

                                } label: {
                                    Image(systemName: progression.mapLocked
                                          ? "pause.circle"
                                          : "arrow.triangle.2.circlepath")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 22, height: 22)
                                    .foregroundColor(.white)
                                    .padding(7)
                                    .background(.ultraThinMaterial.opacity(0.5))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .shadow(radius: 3)
                                }
                                .overlay(alignment: .top) {
                                    if showCycleHint {
                                        Text(cycleHintText)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.white.opacity(0.75))
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 10)
                                            .background(Color.black.opacity(0.15))
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
                                            .fixedSize(horizontal: true, vertical: true)   // ← let it expand past button width
                                            .offset(y: -25)                                 // distance above
                                            .allowsHitTesting(false)
                                            .transition(.opacity)
                                            .animation(.easeInOut(duration: 0.2), value: showCycleHint)
                                            .zIndex(1)                                      // optional: draw on top
                                    }
                                }
                                .onChange(of: isMapSelectOpen) { _, isOpen in
                                    if !isOpen && showCycleHint {
                                        showCycleHint = false
                                    }
                                }

                            }
                            .padding(.leading, 12)

                            let items = makeMapItems(progression)
                            let unlockedCount = progression.unlockedCount
                            let currentIdx = currentMapListIndex(progression)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(items) { item in
                                        let idx = item.id
                                        let isUnlocked = idx < unlockedCount
                                        let isCurrent = (idx == currentIdx)

                                        // Resolve the backwall asset name via tierTheme(for:)
                                        let backwall: String? = {
                                            // item.name is your tier name ("Starter", "Lab", etc.)
                                            let theme = tierTheme(for: item.name)
                                            return theme.backwall
                                        }()

                                        MapTile(
                                            state: isUnlocked ? .unlocked(isCurrent: isCurrent) : .locked,
                                            backwallName: backwall,
                                            size: 90
                                        )
                                        .onTapGesture {
                                            guard isUnlocked else { return }                // ignore locked tiles
                                            let targetTile = idx
                                            let currentTile = currentTileIndex()
                                            if targetTile == currentTile {
                                                // already here → just close the panel
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                                    isMapSelectOpen = false
                                                }
                                                return
                                            }

                                            let targetLI = levelIndexForTile(targetTile)
                                            let onStarter = (currentTile == 0)

                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                                isMapSelectOpen = false
                                            }

                                            if onStarter {
                                                // Starter → Non-starter : OPEN only (switch directly to target map)
                                                progression.jumpToLevelIndex(targetLI)
                                            } else {
                                                if targetTile == 0 {
                                                    // Non-starter → Starter : CLOSE only (switch directly to Starter)
                                                    progression.jumpToLevelIndex(0)
                                                } else {
                                                    // Non-starter → Non-starter : CLOSE, then OPEN (via Starter)
                                                    manualTargetAfterClose = targetLI   // schedule the OPEN to target after close ends
                                                    progression.jumpToLevelIndex(0)     // trigger the CLOSE by switching to Starter first
                                                }
                                            }
                                        }

                                    }
                                    
                                }
                                .padding(.vertical, 4)
                                .padding(.trailing, 8)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 96)
                            .offset(y: 24)


                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
                        .frame(maxWidth: .infinity)
                        .frame(height: min(180, UIScreen.main.bounds.height * 0.22)) // ~half the previous size
                        // No background — floats over your map background
                        // No dim layer — screen stays bright
                    }
                    .ignoresSafeArea(edges: .bottom)
                }
                
                // MARK: - TROPHIES MENU WINDOW
                if isTrophiesOpen {
                    VStack {
                        Spacer()
                        HStack(alignment: .center, spacing: 12) {
                            Spacer().frame(width: 46).allowsHitTesting(false)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(AchievementsCatalog.all) { ach in
                                        let unlocked = achievements.isUnlocked(ach.id)

                                        TrophyCell(
                                            achievement: ach,
                                            isUnlocked: unlocked,
                                            isActive: activeTooltip == ach.id
                                        ) {
                                            // toggle the inline tooltip
                                            if activeTooltip == ach.id {
                                                withAnimation(.easeInOut(duration: 0.15)) { activeTooltip = nil }
                                                tooltipHideWorkItem?.cancel()
                                            } else {
                                                activeTooltip = ach.id
                                                tooltipHideWorkItem?.cancel()
                                                let work = DispatchWorkItem {
                                                    withAnimation(.easeInOut(duration: 0.2)) { activeTooltip = nil }
                                                }
                                                tooltipHideWorkItem = work
                                                withAnimation(.easeInOut(duration: 0.15)) { /* fade handled by .transition */ }
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: work)
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                                .padding(.trailing, 8)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 96)
                            .offset(y: 24)
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
                        .frame(maxWidth: .infinity)
                        .frame(height: min(180, UIScreen.main.bounds.height * 0.22))
                    }
                    .ignoresSafeArea(edges: .bottom)
                }



                

                // MARK: - SETTINGS MENU WINDOW
                if isSettingsOpen {

                    VStack {
                        Spacer()
                        HStack(alignment: .center, spacing: 12) {

                            // Reserve the X area; don't intercept taps here
                            Spacer()
                                .frame(width: 46)
                                .allowsHitTesting(false)

                            // SETTINGS carousel
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    // MUSIC tile
                                    SettingsTile(size: 90, label: "Music") {
                                        ZStack {
                                            Image(systemName: "music.note")
                                                .font(.system(size: 90 * 0.34, weight: .semibold))
                                                .foregroundColor(.white.opacity(0.8))
                                            if musicMutedUI {
                                                Rectangle()
                                                    .fill(Color.red.opacity(0.5))
                                                    .frame(width: 90 * 0.8, height: 3)
                                                    .rotationEffect(.degrees(-45))
                                            }
                                        }
                                    }
                                    .onTapGesture {
                                        SoundManager.shared.toggleMusicMuted()
                                        musicMutedUI = SoundManager.shared.isMusicMuted
                                        if musicMutedUI {
                                            SoundManager.shared.stopLoop(fadeOut: 0.4)
                                        } else {
                                            let theme = tierTheme(for: progression.currentTierName)
                                            updateTierLoop(theme)
                                        }
                                    }

                                    // SFX tile
                                    SettingsTile(size: 90, label: "Sounds Effects") {
                                        ZStack {
                                            Text("SFX")
                                                .font(.system(size: 90 * 0.78 * 0.34, weight: .semibold))
                                                .foregroundColor(.white.opacity(0.8))
                                                .minimumScaleFactor(0.85)
                                                .lineLimit(1)
                                                .padding(.horizontal, 6)
                                            if sfxMutedUI {
                                                Rectangle()
                                                    .fill(Color.red.opacity(0.5))
                                                    .frame(width: 90 * 0.8, height: 3)
                                                    .rotationEffect(.degrees(-45))
                                            }
                                        }
                                    }
                                    .onTapGesture {
                                        SoundManager.shared.toggleSfxMuted()
                                        sfxMutedUI = SoundManager.shared.isSfxMuted
                                    }
                                    
                                    // TAP INPUT tile
                                    SettingsTile(size: 90, label: "Tap to Flip") {
                                        ZStack {
                                            // finger.tap icon
                                            Image(systemName: "hand.tap.fill")
                                                .font(.system(size: 90 * 0.34, weight: .semibold))
                                                .foregroundColor(.white.opacity(0.8))

                                            // Red slash overlay when tap-to-flip is disabled
                                            if disableTapFlip {
                                                Rectangle()
                                                    .fill(Color.red.opacity(0.5))
                                                    .frame(width: 90 * 0.8, height: 3)
                                                    .rotationEffect(.degrees(-45))
                                            }
                                        }
                                    }
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            disableTapFlip.toggle()
                                        }
                                    }
                                    
                                    // HAPTICS tile
                                    SettingsTile(size: 90, label: "Haptics") {
                                        ZStack {
                                            // Use a clear, device-y glyph
                                            Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                                                .font(.system(size: 90 * 0.34, weight: .semibold))
                                                .foregroundColor(.white.opacity(0.8))
                                            if !hapticsEnabledUI {
                                                Rectangle()
                                                    .fill(Color.red.opacity(0.5))
                                                    .frame(width: 90 * 0.8, height: 3)
                                                    .rotationEffect(.degrees(-45))
                                            }
                                        }
                                    }
                                    .onTapGesture {
                                        // toggle
                                        hapticsEnabledUI.toggle()
                                        Haptics.shared.isEnabled = hapticsEnabledUI

                                        // if enabling, give a tiny confirmation tap
                                        if hapticsEnabledUI {
                                            Haptics.shared.tap()
                                        }
                                    }


                                    
                                }
                                .padding(.vertical, 4)
                                .padding(.trailing, 8)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 96)
                            .offset(y: 24)
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
                        .frame(maxWidth: .infinity)
                        .frame(height: min(180, UIScreen.main.bounds.height * 0.22))
                    }
                    .ignoresSafeArea(edges: .bottom)
                }







            }
            .ignoresSafeArea()


            // MARK: DEBUG BUTTONS
            
            #if DEBUG
            .overlay(alignment: .topLeading) {
                VStack(spacing: 6) {
                    // ⬅︎ Reset button
                    Button("◀︎") {
                        // 0) Stop polling during reset (optional)
                        scoreboardVM.stopPolling()

                        // 1) Ask server to remove this install's contribution (optional but clean)
                        //let oldId = InstallIdentity.getOrCreateInstallId()
                        Task {
                            //_ = await ScoreboardAPI.retireAndKeepSide(installId: oldId)
                            // Note: this keeps the server's side lock for this oldId, which is fine
                            // because we're about to delete the local installId and generate a new one.

                            // 2) Wipe Keychain identity & side so next run is brand-new
                            InstallIdentity.removeLockedSide()
                            InstallIdentity.removeInstallId()

                            // 3) Clear offline sync & bootstrap marker
                            StreakSync.shared.debugReset()
                            BootstrapMarker.clear()

                            // 4) Reset local UI / game state
                            await MainActor.run {
                                store.chosenFace = nil
                                store.currentStreak = 0
                                store.clearRecent()

                                didRestorePhase = false
                                phase = .choosing
                                gameplayOpacity = 0

                                withTransaction(Transaction(animation: nil)) {
                                    barPulse = nil
                                    progression.debugResetToFirstTier()
                                    progression.debugResetUnlocks()   // ← add this

                                    // local UI state cleanup you already added
                                    resetMapSelectUI()

                                    // make sure the toast diff doesn’t immediately fire after reset
                                    lastUnlockedCount = 1  // starter-only
                                }

                                // Clear scoreboard UI immediately
                                scoreboardVM.heads = 0
                                scoreboardVM.tails = 0
                                scoreboardVM.isOnline = true

                                // 5) Resume polling (or let onAppear do it)
                                scoreboardVM.startPolling()
                                
                                
                                achievements.resetAll()
                            }
                        }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(radius: 2)

                    // ▶︎ Advance button
                    Button("▶︎") {
                        func jumpToNextTier() {
                            _ = progression.applyAward(len: 10_000)
                            progression.advanceTierAfterFill()
                        }
                        jumpToNextTier()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(radius: 2)
                }
                .padding(.top, 2)
                .padding(.leading, 8)
            }
            #endif

            
            // MARK: CHOOSE SCREEN OVERLAY
            
            .overlay {
                if phase == .choosing {
                    ChooseFaceScreen(
                        store: store,
                        groundY: groundY,
                        screenSize: geo.size
                    ) { selected in
                            // 1) Lock side in Keychain (survives reinstall)
                            InstallIdentity.setLockedSide(selected == .Heads ? "H" : "T")

                            // 2) Persist selection locally & enter gameplay
                            store.chosenFace = selected
                            curState         = selected.rawValue
                            baseFaceAtLaunch = selected.rawValue
                            gameplayOpacity  = 1
                            phase            = .playing

                            // 3) Backend + sync
                            let installId = InstallIdentity.getOrCreateInstallId()
                            Task {
                                // idempotent: safe if already registered
                                await ScoreboardAPI.register(installId: installId, side: selected)

                                // ensure server has your current streak (first-time add)
                                await ScoreboardAPI.bootstrap(
                                    installId: installId,
                                    side: selected,
                                    currentStreak: store.currentStreak
                                )

                                // seed offline replay baseline, then refresh UI totals
                                StreakSync.shared.seedAcked(to: store.currentStreak)
                                await scoreboardVM.refresh()   // remove if not in scope here
                            }
                        

                        // Reset gameplay coin transforms just in case
                        y = 0; scale = 1
                        flightAngle = 0; flightTarget = 0

                        // HIDE gameplay coin immediately (no animation) so it won't show before the drop
                        withTransaction(Transaction(animation: nil)) { gameplayOpacity = 0 }

                        // Start pre-roll
                        withAnimation(.easeInOut(duration: 0.35)) {
                            phase = .preRoll
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(1000)
                }
            }

            
            // MARK: HERO DROP OVERLAY
            .overlay {
                if phase == .preRoll {
                    IntroOverlay(
                        groundY: groundY,
                        screenSize: geo.size,
                        coinDiameterPct: coinDiameterPct,
                        coinRestOverlapPct: coinRestOverlapPct,
                        finalFace: store.chosenFace ?? .Heads,
                        onRevealGameplay: {                     // called exactly at touchdown
                            let tx = Transaction(animation: nil) // ensure no fade-in of gameplay coin
                            withTransaction(tx) {
                                gameplayOpacity = 1              // coin instantly visible UNDER overlay
                            }
                        },
                        onFinished: {                            // overlay fade done -> start playing
                            withAnimation(.easeInOut(duration: 0.20)) {
                                phase = .playing
                            }
                        },
                        onThud: {date in
                            gameplayDustTrigger = date
                            
                            // auto-remove the puff after it finishes (match DustPuff duration + tiny buffer)
                            let lifetime = 0.48 + 0.05
                            DispatchQueue.main.asyncAfter(deadline: .now() + lifetime) {
                                if gameplayDustTrigger == date {   // only clear if nothing retriggered
                                    gameplayDustTrigger = nil
                                }
                            }
                        }
                    )
                    // No transition here—overlay manages its own fade
                    .zIndex(999)
                    .ignoresSafeArea()
                }
            }
            // Top score window that fades in at the very top (ignores safe area)
            .overlay(alignment: .topLeading) {
                TopScoreboardOverlay(
                    vm: scoreboardVM,
                    isOpen: $isScoreMenuOpen,
                    isLeaderboardOpen: $isLeaderboardOpen
                )
                .opacity(store.chosenFace != nil ? 1 : 0) // only after a side is chosen
                .ignoresSafeArea(edges: .top)             // sit flush against the top curves
            }





        }
        // MARK: ON APPEAR
        .onAppear {
            guard !didRestorePhase else {
                updateTierLoop(tierTheme(for: progression.currentTierName)); return
            }
            didRestorePhase = true

            // 1) Try Keychain first
            if store.chosenFace == nil, let s = InstallIdentity.getLockedSide() {
                store.chosenFace = (s == "H") ? .Heads : .Tails
            }

            // 2) If still nil, ask the server (one-time recovery for old users)
            if store.chosenFace == nil {
                let installId = InstallIdentity.getOrCreateInstallId()
                Task {
                    if let face = await ScoreboardAPI.fetchLockedSide(installId: installId) {
                        InstallIdentity.setLockedSide(face == .Heads ? "H" : "T")
                        await MainActor.run {
                            store.chosenFace = face
                            curState         = face.rawValue
                            baseFaceAtLaunch = face.rawValue
                            gameplayOpacity  = 1
                            phase            = .playing
                        }

                        // register (safe if already registered)
                        await ScoreboardAPI.register(installId: installId, side: face)

                        // state restore
                        if let state = await ScoreboardAPI.fetchState(installId: installId) {
                            await MainActor.run { store.currentStreak = state.currentStreak }
                            StreakSync.shared.seedAcked(to: state.currentStreak)
                        }
                    } else {
                        await MainActor.run {
                            gameplayOpacity  = 0
                            phase            = .choosing
                        }
                    }
                }
            } else {
                // We have a face from Keychain
                curState         = store.chosenFace!.rawValue
                baseFaceAtLaunch = store.chosenFace!.rawValue
                gameplayOpacity  = 1
                phase            = .playing

                let installId = InstallIdentity.getOrCreateInstallId()
                Task {
                    // NEW: register (safe if already registered)
                    await ScoreboardAPI.register(installId: installId, side: store.chosenFace!)

                    if let state = await ScoreboardAPI.fetchState(installId: installId) {
                        await MainActor.run { store.currentStreak = state.currentStreak }
                        StreakSync.shared.seedAcked(to: state.currentStreak)
                    }
                }
            }

            // --- 3) One-time bootstrap (after side is known) ---
            if !didKickBootstrap {
                didKickBootstrap = true

                guard let side = store.chosenFace,
                      BootstrapMarker.needsBootstrap() else { return }

                let installId = InstallIdentity.getOrCreateInstallId()
                let localBefore = store.currentStreak

                Task {
                    if let state = await ScoreboardAPI.fetchState(installId: installId) {
                        if state.currentStreak == 0, localBefore > 0 {
                            await ScoreboardAPI.bootstrap(
                                installId: installId, side: side, currentStreak: localBefore
                            )
                            StreakSync.shared.seedAcked(to: localBefore)
                            BootstrapMarker.markBootstrapped()
                            await MainActor.run { store.currentStreak = localBefore }
                        } else {
                            await MainActor.run { store.currentStreak = state.currentStreak }
                            StreakSync.shared.seedAcked(to: state.currentStreak)
                            if state.currentStreak > 0 { BootstrapMarker.markBootstrapped() }
                        }
                    } else {
                        StreakSync.shared.seedAcked(to: localBefore)
                    }
                }
            }

            // --- 4) Tier/sound init (once) ---
            let initialTheme = tierTheme(for: progression.currentTierName)
            fontBelowName = initialTheme.font
            fontAboveName = initialTheme.font
            lastTierName  = progression.currentTierName

            updateTierLoop(tierTheme(for: progression.currentTierName))

            sfxMutedUI   = SoundManager.shared.isSfxMuted
            musicMutedUI = SoundManager.shared.isMusicMuted
        }
        
        // MARK: ON CHANGES
        .onChange(of: progression.tierIndex) { _, _ in
            SoundManager.shared.play("scrape_1")
            
            
            let newName  = progression.currentTierName
            let newTheme = tierTheme(for: progression.currentTierName)
            let oldName  = lastTierName
            
            updateTierLoop(newTheme)
            
            if oldName == "Starter" && newName != "Starter" {
                // OPENING: switch the BELOW font immediately to the new tier
                fontBelowName = newTheme.font
                // top copy is fading out anyway, so no need to change fontAboveName now
            } else if oldName != "Starter" && newName == "Starter" {
                // CLOSING: keep BELOW font as the OLD tier during the close
                // (do NOT change fontBelowName yet)
                // after doors close, onCloseEnded will set both to Starter
                deferCounterFadeInUntilClose = true
            } else {
                // Shouldn't happen with alternating logic, but incase:
                fontBelowName = newTheme.font
                fontAboveName = newTheme.font
            }

            lastTierName = newName
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                scoreboardVM.startPolling()
                Task { await scoreboardVM.refresh() } // optional immediate refresh
                if scoreboardVM.isOnline {
                    let id = InstallIdentity.getOrCreateInstallId()
                    StreakSync.shared.replayIfNeeded(installId: id)
                }
            case .inactive, .background:
                scoreboardVM.stopPolling()
            @unknown default: break
            }
        }
        .onAppear {
            lastUnlockedCount = progression.unlockedCount
        }
        .onChange(of: progression.unlockedCount) { old, new in
            if new > old && !isMapSelectOpen {
                triggerNewMapToast()
            }
            lastUnlockedCount = new
        }
        
        .statusBarHidden(true)

    }
    
    ////SOME MAP HELPERS
    
    /// Map tile index (0 = Starter, 1+ = non-starters) → canonical levelIndex
    private func levelIndexForTile(_ idx: Int) -> Int {
        return (idx == 0) ? 0 : (2 * (idx - 1) + 1)
    }

    /// Current tile index from progression.levelIndex (0 = Starter)
    private func currentTileIndex() -> Int {
        let li = progression.levelIndex
        return (li % 2 == 0) ? 0 : (li + 1) / 2
    }

    private func triggerNewMapToast() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            showNewMapToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.95)) {
                showNewMapToast = false
            }
        }
    }
    
    // Clears all UI state related to the map selector/toast so a reset is truly fresh.
    private func resetMapSelectUI() {
        let noAnim = Transaction(animation: nil)
        withTransaction(noAnim) {
            // Map menu
            isMapSelectOpen = false
            progression.mapLocked = false
            // Any manual jump target you’ve been using (if present)
            manualTargetAfterClose = nil
            
            // Toast
            showNewMapToast = false
        }
    }

    

    // MARK: - FLIP LOGIC
    
    // Keep the no-arg for taps
    func flipCoin() { flipCoin(impulse: nil) }

    // New: impulse-aware flip
    func flipCoin(impulse: Double?) {
        guard phase == .playing else { return }
        guard !isFlipping && !isTierTransitioning else { return }

        // Cancel wobble/bounce & reset pose instantly
        withTransaction(.init(animation: nil)) {
            settleBounceT = 1.0
            settleT = 1.0
            y = 0
        }

        // Launch SFX
        SoundManager.shared.play(["launch_1","launch_2"].randomElement()!)

        // Unbiased result: choose face at random (trailer override kept)
        #if TRAILER_RESET
        let desired = (Int.random(in: 0..<3) < 2) ? "Heads" : "Tails"
        #else
        let desired = Bool.random() ? "Heads" : "Tails"
        //let desired = "Tails"
        #endif

        
        // Capture state
        baseFaceAtLaunch = curState
        isFlipping = true

        // Choose parity target (odd/even) to land on desired
        let needOdd = (desired != baseFaceAtLaunch)

        // Derive flight feel from swipe power (or defaults)
        let params = flightParams(impulse: impulse,
                                  needOdd: needOdd,
                                  screenH: UIScreen.main.bounds.height)
        let halfTurns = params.halfTurns
        let total = params.total
        let jump = params.jump
        currentFlipWasSuper = params.isSuper

        // Sprite plan
        let startSide: CoinSide = (baseFaceAtLaunch == "Heads") ? .H : .T
        let endSide:   CoinSide = (desired == "Heads") ? .H : .T
        spritePlan = SpriteFlipPlan(
            startFace: startSide,
            endFace: endSide,
            halfTurns: halfTurns,
            startTime: Date(),
            duration: total
        )

        // Split total into up/down like before (keep your nice feel)
        let upDur = total * 0.38
        let downDur = total - upDur

        // Up (ease-out)
        withAnimation(.easeOut(duration: upDur)) {
            y = -jump
            scale = 0.98
        }
        // Down (ease-in)
        DispatchQueue.main.asyncAfter(deadline: .now() + upDur) {
            withAnimation(.easeIn(duration: downDur)) {
                y = 0
                scale = 1
            }
            withAnimation(.easeOut(duration: 0.10)) {}
        }

        // Touchdown
        DispatchQueue.main.asyncAfter(deadline: .now() + total) {
            curState = desired
            let noAnim = Transaction(animation: nil)
            withTransaction(noAnim) {
                baseFaceAtLaunch = desired
                isFlipping = false
                spritePlan = nil
            }

            // Bounce & wobble
            settleBounceT = 0.0
            withAnimation(.linear(duration: 0.70)) { settleBounceT = 1.0 }
            settleT = 0.0
            withAnimation(.linear(duration: 0.85)) { settleT = 1.0 }
            
            // If this was a “super” swipe, also do the dust burst + thud like hero drop
            if currentFlipWasSuper {
                triggerDustImpactFromLanding()
                
                // ACHIEVEMENT: High Flyer
                if achievements.unlock(.highFlyer) {
                    // show a brief toast + glow the Trophies button
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        showNewTrophyToast = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.95)) {
                            showNewTrophyToast = false
                        }
                    }
                    // sfx
                    SoundManager.shared.play("trophy_unlock")
                    Haptics.shared.success()
                }
 
                currentFlipWasSuper = false
            }

            // (unchanged) streak / award / tier / SFX logic
            if let faceVal = Face(rawValue: desired) {
                let preStreak = store.currentStreak
                let wasSuccess = (faceVal == store.chosenFace)
                
                // === UNLUCKY (10 wrong in a row) tracker ===
                if !achievements.isUnlocked(.unlucky) {
                    if wasSuccess {
                        if unluckyWrong10 != 0 { unluckyWrong10 = 0 }      // reset on any correct flip
                    } else {
                        unluckyWrong10 &+= 1
                        if unluckyWrong10 >= 10 {
                            unluckyWrong10 = 0                              // clear progress once achieved
                            if achievements.unlock(.unlucky) {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                    showNewTrophyToast = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.95)) {
                                        showNewTrophyToast = false
                                    }
                                }
                                SoundManager.shared.play("trophy_unlock")
                                Haptics.shared.success()
                            }
                        }
                    }
                }
           
                store.recordFlip(result: faceVal)
                let installId = InstallIdentity.getOrCreateInstallId()
                StreakSync.shared.handleLocalFlip(
                    installId: installId,
                    current: store.currentStreak,
                    isOnline: scoreboardVM.isOnline
                )

                if wasSuccess {
                    let pitch = Float(store.currentStreak) * 0.5
                    SoundManager.shared.playPitched(base: "streak_base_pitch", semitoneOffset: pitch)
                    iconPulse = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { iconPulse = false }
                } else {
                    // END-OF-STREAK: award once if there was a run going
                    if preStreak > 0 {

                        if preStreak >= 5 {
                            SoundManager.shared.play("boost_1")
                        }

                        // Current snapshot for the pulse
                        let preProgress = progression.currentProgress
                        let total = Double(progression.currentBarTotal)
                        let needed = max(0.0, total - preProgress)
                        let rawAward = progression.tuning.r(preStreak)
                        let applied  = min(needed, rawAward)

                        // Emit the colored wedge pulse for the UI
                        barPulse = AwardPulse(
                            id: UUID(),
                            start: preProgress,
                            delta: applied,
                            end: preProgress + applied,
                            color: streakColor(preStreak),
                            tierIndex: progression.tierIndex
                        )

                        // Apply the award to the model WITHOUT spillover or immediate tier advance
                        let didFill = progression.applyAward(len: preStreak)

                        // If this award FILLS the bar, advance tier AFTER the fill animation plays
                        if didFill {
                            isTierTransitioning = true

                            // Keep this delay in sync with TierProgressBar’s grow+fade timings (≈0.28 + 0.22)
                            let fillAnimationDelay: Double = 0.55
                            // complete_1 sound delay
                            let postCompletePause: Double = 0.25

                            if !progression.mapLocked {
                                SoundManager.shared.stopLoop(fadeOut: 0.6)
                            }
                            //SoundManager.shared.stopLoop(fadeOut: 0.6)

                            withAnimation(.easeOut(duration: fillAnimationDelay * 0.9)) {
                                counterOpacity = 0.0
                            }

                            // When the fill animation finishes, play the completion sting
                            DispatchQueue.main.asyncAfter(deadline: .now() + fillAnimationDelay) {
                                // 1) Completion sting (unchanged)
                                SoundManager.shared.play("complete_1")

                                // 3) Visual slide-down setup
                                let oldTotal = Double(progression.currentBarTotal)
                                let downAnimDur: Double = 0.45

                                withTransaction(Transaction(animation: nil)) {
                                    barValueOverride = oldTotal
                                }
                                
                                // 2) Count this fill
                                progression.registerBarFill()

                                // --- Only for LOCKED mode, clear the model *now* to avoid jitter ---
                                if progression.mapLocked {
                                    // Clear the underlying progress immediately (no animation) so when the
                                    // override is removed later, the model is already 0 and there’s no jump.
                                    progression.resetBarAfterLockedFill()
                                }

                                // 4) Animate the visual bar back to 0 (unchanged)
                                withAnimation(.linear(duration: downAnimDur)) {
                                    barValueOverride = 0
                                }

                                // 5) After the pause, clear override and either restore counter or advance
                                DispatchQueue.main.asyncAfter(deadline: .now() + postCompletePause) {
                                    withTransaction(Transaction(animation: nil)) {
                                        barValueOverride = nil
                                    }

                                    if progression.mapLocked {
                                        // (Model is already 0 from earlier.)
                                        // Force the bar view to rebuild so it reflects 0 immediately.
                                        withTransaction(Transaction(animation: nil)) {
                                            barNonce &+= 1
                                        }
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            counterOpacity = 1.0
                                        }
                                        isTierTransitioning = false
                                    } else {
                                        deferCounterFadeInUntilClose = true
                                        progression.advanceTierAfterFill()
                                        isTierTransitioning = false
                                    }
                                }

                            }
                        }
                    }

                    // Play landing sound
                    SoundManager.shared.play(["land_1","land_2"].randomElement()!)
                }
            }
        }
    }


}


#Preview { ContentView() }





