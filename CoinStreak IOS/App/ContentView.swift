//
//  ContentView.swift
//  CoinStreak IOS
//
//  Created by Jonathan Pereda on 10/3/25.
//

import SwiftUI
import Foundation
import UIKit
import Combine

///MISC

private enum AppPhase { case choosing, preRoll, playing, shop }

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
    @AppStorage("ach.progress.alt_count") private var alternatingCount: Int = 0
    @AppStorage("ach.progress.alt_last_raw")
    private var alternatingLastRaw: String = ""
    @AppStorage("ach.progress.total_flips") private var totalFlips: Int = 0
    
    // TOKENS
    private let TOKENS_PER_FILL = 150
    private let TOKENS_PER_STREAK = 25
    @AppStorage("tokens.balance") private var tokenBalance: Int = 0
    @State private var showNewTokensToast: Bool = false
    @State private var lastTokenGain: Int = 0
    
    //SHOP
    @StateObject private var shopVM = ShopVM()
    @StateObject private var shopUnlocks = ShopUnlocksStore()
    @State private var restoreCounterAfterOpen = false
    // Shop fade-in opacity (0…1)
    @State private var shopOpacity: Double = 0.0
    @State private var showShopUI: Bool = false
    @State private var lastLevelIndexBeforeShop: Int = 0     // remember where we came from
    @State private var pendingEnterShopAfterClose = false    // already used for enter → shop
    @State private var pendingExitShopToIndex: Int? = nil    // where to go after we CLOSE
    @State private var suppressStreakUntilCloseEnds = false  // hide streak during close-out from shop
    @State private var isDoorsClosing: Bool = false  // gate opening shop while the CLOSE animation is in progress
    @State private var isDoorsOpening = false
    @AppStorage("equipped.table.key") private var equippedTableKey: String = "starter"
    @AppStorage("equipped.table.image") private var equippedTableImage: String = ""
    @AppStorage("equipped.coin.key") private var equippedCoinKey: String = "starter"

    // Map menu stuff
    @Environment(\.scenePhase) private var scenePhase
    @State private var isMapSelectOpen = false
    @State private var manualTargetAfterClose: Int? = nil
    @State private var showNewMapToast = false
    @State private var lastUnlockedCount = 1   // starter = 1
    @State private var showCycleHint = false
    @State private var cycleHintText = "Cycle: On"
    
    //More Menu
    @State private var isMoreOpen = false
    
    //Stats Menu
    @State private var isStatsOpen = false
    @StateObject private var stats = StatsStore()
    
    //News map
    @State private var showNewsHeadlines = false
    

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
    @AppStorage("pending.flip.outcome") private var pendingFlipOutcomeRaw: String = ""
    @AppStorage("pending.flip.justApplied") private var pendingFlipJustApplied: Bool = false


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
    
    //Update Prompt
    @State private var showUpdateSheet = false
    @State private var storeVersionToPrompt: String? = nil
    
    //Battles
    @State private var isBattleMenuOpen = false
    @StateObject private var battleVM = BattleMenuVM()
    @State private var showBattleCinematic = false
    @State private var currentBattleEvent: BattleRevealEvent?
    @State private var currentOpponentName: String = "Opponent"
    @StateObject private var nameVM = NameEntryVM()
    @State private var currentMyName: String = "You"
    
    //Minigames
    @StateObject private var minigameManager = MinigameManager(
        api: CloudflareMinigameAPI(),
        installId: InstallIdentity.getOrCreateInstallId()
    )
    @State private var isMinigameOpen = false
    @AppStorage("minigame_lastFinishedPeriodSeen")
    private var lastSeenFinishedPeriodId: String?
    @State private var showMinigameResults: Bool = false
    @State private var showMinigameToast: Bool = false
    @State private var minigameToastMessage: String = ""

    // Call It minigame custom transition
    @State private var showCallItTransition: Bool = false
    @State private var callItExitTrigger: Int = 0

    @ViewBuilder
    private func streakLayer(fontName: String) -> some View {
        VStack {
            let visibleStreak = battleVM.maskStreakUntilReveal
                ? (battleVM.streakValueBeforeReveal ?? store.currentStreak)
                : store.currentStreak
            
            StreakCounter(value: visibleStreak, fontName: fontName)
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
            
            let isTakeoverMinigameActive: Bool = {
                guard minigameManager.isSessionActive,
                      let hostConfig = minigameManager.currentHostConfig
                else { return false }
                return hostConfig.mode == .dedicatedScreen
            }()

            let theme = tierTheme(for: progression.currentTierName)

            let currentBackwall: String = {
                // If a dedicated-screen minigame is active, use "<minigame_raw_value>_backwall"
                if minigameManager.isSessionActive,
                   let hostConfig = minigameManager.currentHostConfig,
                   hostConfig.mode == .dedicatedScreen,
                   let id = minigameManager.activeMinigameId {
                    return "\(id.rawValue)_backwall"
                }

                // Shop has its own fixed backwall
                if phase == .shop {
                    return "shop_backwall"
                }

                // Otherwise use the normal tier backwall
                return theme.backwall
            }()

            // MARK: MAIN UI RENDER

            ZStack {
                // Call It "lights out" transition layer
                if showCallItTransition {
                    CallItTransitionOverlay(
                        isActive: $showCallItTransition,
                        isPaused: minigameManager.activeOverlay != nil,
                        exitTrigger: callItExitTrigger
                    )
                    .zIndex(2000)
                }
                
                if isTakeoverMinigameActive {
                    Image(currentBackwall)
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                } else {
                    // Normal maps/shop: full elevator + doors + headlines + streak
                    ElevatorSwitcher(
                        currentBackwallName: currentBackwall,
                        starterSceneName: "starter_backwall",
                        doorLeftName: "starter_left",
                        doorRightName: "starter_right",
                        belowDoors: {
                            ZStack {
                                // NEWS HEADLINES: sit underneath the streak counter, only on the news map
                                if theme.backwall == "news_backwall",
                                   phase != .shop,
                                   !isDoorsOpening,
                                   !isDoorsClosing {
                                    NewsHeadlinesOverlay(screenSize: geo.size)
                                }

                                // STREAK COUNTER: on top of headlines, during open/close and when open
                                if phase != .shop && !suppressStreakUntilCloseEnds && !minigameHidesHUD {
                                    streakLayer(fontName: fontBelowName)
                                }
                            }
                        },
                        aboveDoors: {
                            // top copy, animate with counterOpacity
                            if phase != .shop && !suppressStreakUntilCloseEnds && !minigameHidesHUD {
                                streakLayer(fontName: fontAboveName)
                                    .opacity(counterOpacity)
                            }
                        },
                        shouldShowAboveAfterClose: {
                            !pendingEnterShopAfterClose
                        },
                        onOpenEnded: {
                            if restoreCounterAfterOpen {
                                withAnimation(.easeInOut(duration: 0.25)) { counterOpacity = 1.0 }
                                restoreCounterAfterOpen = false
                            }
                            isDoorsOpening = false
                            //Turn on news headlines
                            let themeNow = tierTheme(for: progression.currentTierName)
                            if phase != .shop && themeNow.backwall == "news_backwall" {
                                showNewsHeadlines = true
                            } else {
                                showNewsHeadlines = false
                            }
                        },
                        onCloseEnded: {
                            isDoorsClosing = false
                            showShopUI = false
                            shopOpacity = 0.0
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
                            // Entering shop from a non-starter: switch to shop now (will OPEN)
                            if pendingEnterShopAfterClose {
                                pendingEnterShopAfterClose = false
                                withAnimation(.easeInOut(duration: 0.2)) { phase = .shop }
                                switchToShopMusic()
                                return
                            }

                            // Exiting shop: we just finished the CLOSE to Starter
                            if let idx = pendingExitShopToIndex {
                                // Allow streak to show again (we hid it only during the close)
                                suppressStreakUntilCloseEnds = false
                                // Fade out shop loop; the OPEN will start the map loop via tier change
                                SoundManager.shared.stopLoop(fadeOut: 0.4)
                                // Now OPEN to the previous map
                                pendingExitShopToIndex = nil
                                progression.jumpToLevelIndex(idx)     // starter → non-starter triggers OPEN
                            } else {
                                // Exiting to Starter (no reopen)
                                suppressStreakUntilCloseEnds = false
                                // Bring the streak back now that the doors are fully closed
                                withAnimation(.easeInOut(duration: 0.25)) { counterOpacity = 1.0 }
                                switchToMapMusic()
                            }
                        }
                    )
                }
                
                if let trig = doorDustTrigger {
                    DoorDustLine.seamBurst(trigger: trig)
                        .id(trig)                       // remount per trigger
                        .frame(width: W, height: H)     // concrete size for Canvas
                        .allowsHitTesting(false)
                }

                let sideLetter: String = {
                    if let f = store.chosenFace { return (f == .Heads ? "h" : "t") }
                    return "h" // safe default while we restore face
                }()

                TableView(
                    sideLetter: sideLetter,
                    equippedTableImage: equippedTableImage,
                    screenSize: geo.size
                )
                
                // MARK: PROGRESS BAR
                
                // HUD: progress bar
                if phase != .choosing {
                    let barWidth = min(geo.size.width * 0.70, 360)

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
                        .opacity(
                            (isMapSelectOpen || isSettingsOpen || isTrophiesOpen || isMoreOpen || minigameHidesHUD)
                            ? 0 : 1
                        )
                        .animation(.easeInOut(duration: 0.2), value: isMapSelectOpen)
                        .animation(.easeInOut(duration: 0.2), value: isSettingsOpen)
                        .animation(.easeInOut(duration: 0.2), value: isTrophiesOpen)

                    }
                    .padding(.trailing, geo.safeAreaInsets.trailing + 96)
                    .padding(.bottom, geo.safeAreaInsets.bottom + 50)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .allowsHitTesting(false)
                    .zIndex(50)                // keep above table/gameplay
                    .transition(.opacity)
                    
                    
                    /*.overlay(alignment: .bottomLeading) {
                        bottomMenuOverlay(geo)
                    }*/
                    .overlay(alignment: .bottomLeading) {
                        ZStack(alignment: .bottomLeading) {
                            bottomMenuOverlay(geo) // this already hides itself in .shop per your logic
                            if phase == .shop {
                                exitShopButton(geo)
                                    .opacity(shopOpacity)
                            }
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        if showShopUI {
                            ShopOverlay(
                                vm: shopVM,
                                stats: stats,
                                tokenBalance: $tokenBalance,
                                size: geo.size,
                                equippedTableImage: $equippedTableImage,
                                equippedTableKey: $equippedTableKey,
                                equippedCoinKey: $equippedCoinKey,
                                sideProvider: { (store.chosenFace == .Heads) ? "h" : "t" },
                                unlocks: shopUnlocks
                            )
                            .opacity(shopOpacity)
                        }
                    }
                    // Weekly minigame host: lives in the same layer as HUD / shop
                    // so the coin (zIndex 100) stays visually on top.
                    .overlay {
                        minigameHostOverlay()
                    }
                    .onChange(of: phase) { _, newPhase in
                        if newPhase == .shop {
                            showShopUI = true
                            // Start hidden, then fade in while doors are opening
                            shopOpacity = 0.0
                            withAnimation(.easeInOut(duration: 1.2)) {
                                shopOpacity = 1.0
                            }
                        }
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
                            position: .init(x: W/2, y: coinCenterY),
                            coinKey: equippedCoinKey
                        )
                        .offset(y: y + CGFloat(bounceY(settleBounceT)))
                        .scaleEffect(scale)
                    }
                    .zIndex(100)
                    .modifier(SettleWiggle(t: settleT))
                    .modifier(SettleBounce(t: settleBounceT))
                    .allowsHitTesting(false)
                    
                }
                .opacity(gameplayOpacity)                 // <— no animation; see onReveal below
                .allowsHitTesting(phase == .playing)      // disable taps until playing


                // MARK: INPUT HITBOX
                if phase == .playing || phase == .shop {
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

                                    // When a takeover minigame is active, route all flips as visual-only
                                    // so they animate but don't affect the main streak logic.
                                    let hijackActive = minigameManager.isSessionActive
                                        && (minigameHostConfig?.hijacksGameplayCoin ?? false)
                                    let visualOnly = (phase == .shop) || hijackActive

                                    let dx = v.translation.width
                                    let dy = v.translation.height
                                    if hypot(dx, dy) < 10 {
                                        guard !disableTapFlip else { return }
                                        flipCoin(visualOnly: visualOnly)
                                    } else {
                                        let up = max(0, -dy)
                                        let predUp = max(0, -v.predictedEndTranslation.height)
                                        let extra = max(0, predUp - up)
                                        let raw = Double(up) + 0.5 * Double(extra)
                                        let impulse = raw / Double(H * 0.70)
                                        if impulse > 0.15 {
                                            flipCoin(impulse: impulse, visualOnly: visualOnly)
                                        }
                                    }
                                }
                        )
                        // IMPORTANT: keep below panels so they remain tappable
                        // .zIndex(0)  // (you can omit this; default is fine)
                }




            

                // MARK: RECENT FLIPS COLUMN
                if phase == .playing, !store.recent.isEmpty {
                    // Where the BOTTOM should live (0.0 = top, 1.0 = bottom)
                    let baselineYPct: CGFloat = 0.30   // mid-left baseline
                    let baselineY = geo.size.height * baselineYPct

                    ZStack(alignment: .bottomLeading) {
                        RecentFlipsColumn(recent: store.recent, chosenFace: store.chosenFace)
                            .padding(.leading, max(12, geo.safeAreaInsets.leading + 4))
                    }
                    // Container height == distance from top → baseline; column is bottom-aligned inside
                    .frame(width: geo.size.width, height: baselineY, alignment: .bottomLeading)
                    .opacity(minigameHidesHUD ? 0 : 1)
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
                                            
                                            guard !isDoorsClosing && !isDoorsOpening else { return }

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
                                            isActive: activeTooltip == ach.id,
                                            isHighlighted: achievements.isUnseen(ach.id)
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
                                            if phase == .shop {
                                                switchToShopMusic()
                                            } else {
                                                let theme = tierTheme(for: progression.currentTierName)
                                                updateTierLoop(theme)
                                            }
                                        }
                                    }

                                    // SFX tile
                                    SettingsTile(size: 90, label: "Sound Effects") {
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

                // MARK: - MINIGAME GLOBAL OVERLAY
                if let overlay = minigameManager.activeOverlay {
                    ZStack {
                        // Dim behind the overlay, but still allow the minigame scene to show through
                        Color.black.opacity(overlay.dimOpacity)
                            .ignoresSafeArea()

                        // Minigame-provided overlay content (e.g. Call It leaderboard UI)
                        overlay.content
                            .ignoresSafeArea()
                    }
                    .transition(.opacity)
                    .zIndex(1000)
                    
                    //Easy escape when testing
                    /*.onTapGesture {
                        if overlay.dismissOnBackgroundTap {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                minigameManager.activeOverlay = nil
                            }
                        }
                    }*/
                }


            }
            .ignoresSafeArea()
            .ignoresSafeArea(.keyboard)
            
            
            .onChange(of: minigameManager.isSessionActive) {_, isActive in
                if !isActive {
                    callItExitTrigger &+= 1
                }
            }


            // MARK: DEBUG BUTTONS
            /*
            #if DEBUG
            .overlay(alignment: .topLeading) {
                VStack(spacing: 6) {
                    // ⬅︎ Reset button
                    Button("◀︎") {
                        //NADA
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
            */
            
            
            
            .overlay { chooseOverlay(geo, groundY: groundY) }
             
            
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
                .ignoresSafeArea(.keyboard)
            }





        }
        // MARK: ON APPEAR
        .onAppear {
            // Apply the last-used map's streak font immediately on cold start (before progression emits)
            if let savedTier = UserDefaults.standard.string(forKey: "LastTierName") {
                let savedTheme = tierTheme(for: savedTier)
                fontBelowName = savedTheme.font
                fontAboveName = savedTheme.font
                lastTierName  = savedTier
                // Keep loop music/backwall aligned as well
                updateTierLoop(savedTheme)
            }
            
            // --- Minigame: bootstrap "last finished" snapshot (once per launch) ---
            minigameManager.refreshLastFinished()
            
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
                        
                        syncEquippedTableToFaceAndKey()
                        syncEquippedCoinWithVM()

                        // register (safe if already registered)
                        await ScoreboardAPI.register(installId: installId, side: face)

                        // state restore
                        if let state = await ScoreboardAPI.fetchState(installId: installId) {
                            await MainActor.run {
                                if !pendingFlipJustApplied {
                                    store.currentStreak = state.currentStreak
                                }
                            }
                            // Seed acks from whatever we’re actually showing locally
                            let ackVal = await MainActor.run { store.currentStreak }
                            StreakSync.shared.seedAcked(to: ackVal)
                            // Clear the one-shot guard after first reconciliation
                            pendingFlipJustApplied = false
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
                
                syncEquippedTableToFaceAndKey()
                syncEquippedCoinWithVM()

                let installId = InstallIdentity.getOrCreateInstallId()
                Task {
                    // NEW: register (safe if already registered)
                    await ScoreboardAPI.register(installId: installId, side: store.chosenFace!)

                    if let state = await ScoreboardAPI.fetchState(installId: installId) {
                        await MainActor.run {
                            if !pendingFlipJustApplied {
                                store.currentStreak = state.currentStreak
                            }
                        }
                        // Seed acks from whatever we’re actually showing locally
                        let ackVal = await MainActor.run { store.currentStreak }
                        StreakSync.shared.seedAcked(to: ackVal)
                        // Clear the one-shot guard after first reconciliation
                        pendingFlipJustApplied = false
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
            
            let openId = InstallIdentity.getOrCreateInstallId()
            Task { _ = await ScoreboardAPI.appOpened(installId: openId) }
            
            // Seed StatsStore from pre-existing data (only runs once).
            runStatsBackfillIfNeeded()
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
                
                isDoorsOpening = true
                
                // top copy is fading out anyway, so no need to change fontAboveName now
            } else if oldName != "Starter" && newName == "Starter" {
                // CLOSING: keep BELOW font as the OLD tier during the close
                // (do NOT change fontBelowName yet)
                // after doors close, onCloseEnded will set both to Starter
                deferCounterFadeInUntilClose = true
                isDoorsClosing = true
            } else {
                // Shouldn't happen with alternating logic, but incase:
                fontBelowName = newTheme.font
                fontAboveName = newTheme.font
            }

            lastTierName = newName
            UserDefaults.standard.set(newName, forKey: "LastTierName")
        }
        // Keep streak counter font/theme in sync on cold start restores where tierIndex may not emit
        .onChange(of: progression.currentTierName) { _, newName in
            guard newName != lastTierName else { return }          // avoid redundant updates
            let theme = tierTheme(for: newName)
            fontBelowName = theme.font
            fontAboveName = theme.font
            lastTierName  = newName
            UserDefaults.standard.set(newName, forKey: "LastTierName")
            updateTierLoop(theme)
            
        }
        .onChange(of: scenePhase) {_, newPhase in
            switch newPhase {
            case .active:
                // Ensure streak font matches the last-used map upon returning active
                if let savedTier = UserDefaults.standard.string(forKey: "LastTierName") {
                    let theme = tierTheme(for: savedTier)
                    fontBelowName = theme.font
                    fontAboveName = theme.font
                    if phase != .shop { updateTierLoop(theme) }
                }
                finalizePendingFlipIfPossible()
                //Quick check if a battle happened
                let id = InstallIdentity.getOrCreateInstallId()
                Task { _ = await ScoreboardAPI.appOpened(installId: id) }
                Task { await battleVM.pollForRevealIfNeeded(installId: id) }
                // Refresh every 5s; includes leaderboard only when it's open
                scoreboardVM.startPolling(includeLeaderboard: { isLeaderboardOpen })
                // (Optional) immediate kick so LB shows right away if open
                Task { await scoreboardVM.refresh(includeLeaderboard: isLeaderboardOpen) }
            case .inactive:
                // Commit any in-flight flip immediately when app becomes inactive (e.g., app switcher)
                finalizePendingFlipIfPossible()
                scoreboardVM.stopPolling()
            case .background:
                // Commit any in-flight flip when we enter background as well
                finalizePendingFlipIfPossible()
                scoreboardVM.stopPolling()
            @unknown default: break
            }
        }
        .onChange(of: isLeaderboardOpen) {_, open in
            if open {
                Task { await scoreboardVM.refresh(includeLeaderboard: true) }
            }
        }
        .onAppear {
            lastUnlockedCount = progression.unlockedCount
        }
        .onChange(of: progression.unlockedCount) { old, new in
            if new > old && !isMapSelectOpen { triggerNewMapToast() }
            lastUnlockedCount = new
        }
        .onChange(of: isTrophiesOpen) { _, open in
            // When the player closes the trophies panel, consider all newly-unlocked trophies "seen"
            if !open {
                achievements.markAllSeen()
            }
        }
        .onReceive(scoreboardVM.$headsTop) { _ in
            checkLeaderboardMedals()
        }
        .onReceive(scoreboardVM.$tailsTop) { _ in
            checkLeaderboardMedals()
        }
        .onChange(of: isLeaderboardOpen) { _, open in
            if open { checkLeaderboardMedals() }
        }
        .onChange(of: battleVM.revealPending) { _, ev in
            guard let ev else { return }
            
            let me = InstallIdentity.getOrCreateInstallId()
            if ev.loserInstallId == me {
                Task { @MainActor in
                    battleVM.beginStreakMask(currentVisibleStreak: store.currentStreak)
                }
            }
            currentBattleEvent = ev

            if let opp = ev.opponent {
                currentOpponentName = opp.name
            } else {
                currentOpponentName = "Opponent"
                let me = InstallIdentity.getOrCreateInstallId()
                let otherId = (ev.winnerInstallId == me) ? ev.loserInstallId : ev.winnerInstallId
                Task {
                    if let prof = await ScoreboardAPI.fetchProfile(installId: otherId) {
                        await MainActor.run { currentOpponentName = prof.displayName }
                    }
                }

            }

            // NEW: close the battle menu before showing the cinematic
            if isBattleMenuOpen { isBattleMenuOpen = false }
            
            // --- resolve my name from server directly ---
            Task {
                let resolvedName: String = {
                    // default immediately to "You" while we fetch, but we’ll overwrite before presenting
                    "You"
                }()

                var finalName = resolvedName

                // Await server name—but cap wait so we never hang the UI longer than ~300ms
                let start = Date()
                if let prof = await ScoreboardAPI.fetchProfile(installId: me) {
                    finalName = prof.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if finalName.isEmpty { finalName = "You" }
                }
                let elapsed = Date().timeIntervalSince(start)

                await MainActor.run {
                    currentMyName = finalName
                    // present after name is set; if fetch was super fast, still delay a hair to let covers dismiss
                    let delay: Double = elapsed > 0.3 ? 0.0 : 0.15
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        withAnimation(.easeIn(duration: 0.2)) { showBattleCinematic = true }
                    }
                }
            }
            // --------------------------------------------

            // NEW: present the cinematic just after the cover dismisses
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeIn(duration: 0.2)) { showBattleCinematic = true }
            }
        }
        
        .onChange(of: tokenBalance) { old, new in
            guard new > old else { return }          // only on gains
            lastTokenGain = new - old
            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                showNewTokensToast = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.95)) {
                    showNewTokensToast = false
                    
                    // Rainy Day (have ≥ 2500 tokens at once)
                    let rainyDayThreshold = 2500
                    if !achievements.isUnlocked(.rainyday), new >= rainyDayThreshold {
                        if achievements.unlock(.rainyday) {
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
        }

        .onChange(of: store.chosenFace) { _, _ in
            finalizePendingFlipIfPossible()
            // Face shouldn’t change, but this keeps things future-proof
            syncEquippedTableToFaceAndKey()
            syncEquippedCoinWithVM()
        }

        .onChange(of: equippedTableKey) { _, _ in
            // If key changes (e.g., future UI), ensure image follows the key + current face
            let side = (store.chosenFace == .Heads) ? "h" : "t"
            let target = "\(equippedTableKey)_table_\(side)"
            if equippedTableImage != target { equippedTableImage = target }
        }
        


        
        // STATS OVERLAY (shows game behind)
        .overlay {
            if isStatsOpen {
                ZStack {
                    // Dimming background over the game, but still partially see-through
                    Color.black.opacity(0.55)
                        .ignoresSafeArea()

                    let allAchievements = AchievementsCatalog.all
                    let unlockedTrophies = allAchievements.filter { ach in
                        achievements.isUnlocked(ach.id)
                    }.count

                    let mapItems = makeMapItems(progression)
                    let totalMaps = mapItems.count
                    let unlockedMaps = progression.unlockedCount

                    StatsMenuView(
                        isOpen: $isStatsOpen,
                        stats: stats,
                        unlockedTrophies: unlockedTrophies,
                        totalTrophies: allAchievements.count,
                        unlockedMaps: unlockedMaps,
                        totalMaps: totalMaps,
                        onBackfill: { runStatsBackfillIfNeeded() }
                    )
                    .transition(.opacity)
                }
                .zIndex(500)
            }
        }
        
        
        // MINIGAME RESULTS POPUP OVERLAY
        .overlay {
            if showMinigameResults,
               let snapshot = minigameManager.lastFinishedSnapshot {
                MinigameResultsPopup(
                    snapshot: snapshot,
                    activeMinigameId: minigameManager.activeMinigameId,
                    onDismiss: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showMinigameResults = false
                        }

                        // Safely grab the snapshot & period id at dismissal time
                        guard let snapshot = minigameManager.lastFinishedSnapshot else { return }
                        let periodId = snapshot.period.id

                        // Avoid double-claiming rewards for the same finished period
                        if lastSeenFinishedPeriodId == periodId {
                            return
                        }

                        // Determine this player's reward from their final rank
                        if let rank = snapshot.me.rank,
                           let brackets = snapshot.rewardBrackets,
                           let bracket = brackets.first(where: { rank >= $0.minRank && rank <= $0.maxRank }) {

                            let reward = bracket.reward

                            // 1) Tokens (unchanged behavior, still delayed so the toast is visible)
                            if let tokenAmount = reward.tokenAmount,
                               tokenAmount > 0 {

                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    tokenBalance &+= tokenAmount
                                    stats.addTokensEarned(tokenAmount)
                                    SoundManager.shared.play(["earn_token_1","earn_token_2"].randomElement()!)
                                }
                            }
                            // 2) Asset unlocks
                            if !reward.assetKeys.isEmpty {
                                shopUnlocks.unlock(reward.assetKeys)
                            }
                        }
                        // Remember that we've processed this period's results
                        lastSeenFinishedPeriodId = periodId
                        UserDefaults.standard.set(
                            periodId,
                            forKey: "LastSeenFinishedMinigamePeriodId"
                        )
                    }
                )
                .ignoresSafeArea()
                .transition(.opacity)
                .zIndex(1200)
            }
        }

        .onReceive(minigameManager.$lastFinishedSnapshot) { snapshot in
            print("DEBUG lastFinishedSnapshot changed ->",
                  snapshot?.period.id ?? "nil")
            
            // Only show when we actually have a finished snapshot
            guard let snapshot = snapshot else { return }
            
            let periodId = snapshot.period.id
            
            // If we've already processed/seen this period's results, don't show again
            if lastSeenFinishedPeriodId == periodId {
                return
            }
            
            withAnimation(.easeInOut(duration: 0.25)) {
                showMinigameResults = true
            }
        }


        

        .fullScreenCover(isPresented: $isBattleMenuOpen, onDismiss: {
            // no-op
        }) {
            BattleMenuView(isOpen: $isBattleMenuOpen, vm: battleVM)
                .onAppear {
                    let id = InstallIdentity.getOrCreateInstallId()
                    Task {
                        await battleVM.loadInitial(installId: id)
                        await battleVM.markOpened(installId: id)   // clears the “!” when opening
                    }
                }
        }
        .task {
            let me = InstallIdentity.getOrCreateInstallId()
            await battleVM.pollForRevealIfNeeded(installId: me) // immediate

            for await _ in Timer.publish(every: 6, on: .main, in: .common).autoconnect().values {
                if !showBattleCinematic {
                    await battleVM.pollForRevealIfNeeded(installId: me)
                    await battleVM.refreshLists(installId: me)
                }
            }
        }
        
        
        // MARK: UPDATE PROMPT
        
        .task {
            if let storeV = await UpdateCheck.fetchStoreVersion(),
               UpdateCheck.shouldPrompt(for: storeV) {
                storeVersionToPrompt = storeV
                showUpdateSheet = true
            }
        }
        .sheet(isPresented: $showUpdateSheet, onDismiss: {
            if let v = storeVersionToPrompt { UpdateCheck.markPrompted(storeVersion: v) }
        }) {
            VStack(spacing: 14) {
                Text("Update available")
                    .font(.title3).bold()
                Text("Version (\(storeVersionToPrompt ?? "")) is available on the App Store.")
                    .multilineTextAlignment(.center)
                    .opacity(0.8)
                Text("Update for new cool features!")
                    .multilineTextAlignment(.center)
                    .opacity(0.8)

                HStack {
                    Button("Not now") {
                        showUpdateSheet = false
                    }
                    Spacer()
                    Button("Update") {
                        if let url = URL(string: "itms-apps://itunes.apple.com/app/id6753908572") {
                            UIApplication.shared.open(url)
                        }
                        showUpdateSheet = false
                    }
                    .bold()
                }
                .padding(.top, 6)
            }
            .padding(20)
            .presentationDetents([.fraction(0.28)])
        }
        
        
        
        // MARK: BATTLE CINEMATIC
        
        .background(
            FadeFullScreenCover(isPresented: $showBattleCinematic) {
                if let ev = currentBattleEvent {
                    BattleVideoCinematic(
                        event: ev,
                        meInstallId: InstallIdentity.getOrCreateInstallId(),
                        meName: currentMyName,
                        opponentName: currentOpponentName
                    ) {
                        //onDone
                        withAnimation(.easeOut(duration: 0.2)) { showBattleCinematic = false }

                        if !ev.eventId.hasPrefix("local-") {
                            Task {
                                await battleVM.ackReveal(
                                    installId: InstallIdentity.getOrCreateInstallId(),
                                    eventId: ev.eventId
                                )
                                await battleVM.pollForRevealIfNeeded(
                                    installId: InstallIdentity.getOrCreateInstallId()
                                )
                            }
                        }

                        Task {
                            let me = InstallIdentity.getOrCreateInstallId()
                            if let s = await ScoreboardAPI.fetchState(installId: me) {
                                await MainActor.run {
                                    battleVM.myStreak = s.currentStreak
                                    store.currentStreak = s.currentStreak
                                }
                                StreakSync.shared.seedAcked(to: s.currentStreak)
                            }
                            await MainActor.run { battleVM.endStreakMask() }
                        }

                        battleVM.recordRevealResult(
                            event: ev,
                            myInstallId: InstallIdentity.getOrCreateInstallId(),
                            myName: currentMyName,
                            myOpponentName: currentOpponentName
                        )

                        battleVM.revealPending = nil
                        // === end onDone ===
                    }
                    .ignoresSafeArea()                 // keep edge-to-edge
                    .statusBarHidden(true)
                    // (no need for interactiveDismissDisabled; there’s no drag handle)
                } else {
                    Color.black.ignoresSafeArea()      // defensive fallback
                }
            }
        )


        
        .statusBarHidden(true)
        .ignoresSafeArea(.keyboard)

    }
    

    // MARK: - Stats Backfill

    /// One-time seeding of StatsStore from legacy data so players don't start from 0
    private func runStatsBackfillIfNeeded() {
        // 1) Legacy flips come from the existing totalFlips counter
        //    that you already use for Steady / Dedicated / Devoted.
        let legacyFlips = totalFlips

        var legacyHeads: Int? = nil
        var legacyTails: Int? = nil
        if legacyFlips > 0 {
            let h = legacyFlips / 2
            legacyHeads = h
            legacyTails = legacyFlips - h
        }

        var legacyLongest: Int? = nil
        if achievements.isUnlocked(.unlucky) {
            legacyLongest = 10
        }

        let legacySpent = computeLegacyTokensSpent()
        let legacyEarned = legacySpent.map { $0 + tokenBalance }
        
        //print("[StatsBackfill] flips=\(legacyFlips), heads=\(legacyHeads ?? -1), tails=\(legacyTails ?? -1), longest=\(legacyLongest ?? -1), spent=\(legacySpent ?? -1), earned=\(legacyEarned ?? -1), tokenBalance=\(tokenBalance)")


        stats.backfillIfNeeded(
            legacyTotalFlips: legacyFlips,
            legacyHeads: legacyHeads,
            legacyTails: legacyTails,
            legacyLongestLosingStreak: legacyLongest,
            legacyTokensEarned: legacyEarned,
            legacyTokensSpent: legacySpent
        )
    }

    /// Compute how many tokens have already been spent on shop items,
    /// based on the current owned set and the canonical catalog.
    ///
    /// We iterate all catalog items, check whether the player owns them,
    /// and sum the remote-adjusted price (ignoring any free items like "starter").
    private func computeLegacyTokensSpent() -> Int? {
        var total = 0

        for category in ShopCategory.allCases {
            let items = ShopCatalog.items(for: category)
            for item in items {
                // Only count items the player actually owns
                guard shopVM.isOwned(item.id) else { continue }

                // Use the same pricing logic as purchases (respects RemoteShop overrides)
                let price = RemoteShop.price(for: item)

                // Skip free items (e.g. starter cosmetics)
                guard price > 0 else { continue }

                total += price
            }
        }

        return total
    }
    
    
    
    //SHOP HELPERS
    
    // SHOP MUSIC HELPERS
    private func switchToShopMusic() {
        guard !musicMutedUI else { return }
        SoundManager.shared.stopLoop(fadeOut: 0.4)
        SoundManager.shared.startLoop(named: "shop_music", volume: 0.40, fadeIn: 0.8)
    }

    private func switchToMapMusic() {
        guard !musicMutedUI else { return }
        updateTierLoop(tierTheme(for: progression.currentTierName))
    }
    
    private func enterShop() {
        guard phase != .shop else { return }
        guard !isDoorsClosing else { return }
        // Close scoreboard/leaderboard if open when entering the shop
        withAnimation(.easeInOut(duration: 0.22)) {
            isLeaderboardOpen = false
            isScoreMenuOpen = false
        }

        // Ensure latest remote price overrides before showing shop
        Task { _ = await RemoteShop.fetchIfNeeded(force: true) }

        isDoorsOpening = true

        // Close panels
        isMapSelectOpen = false
        isSettingsOpen = false
        isTrophiesOpen = false
        isBattleMenuOpen = false
        isMoreOpen = false

        // Remember where we were
        lastLevelIndexBeforeShop = currentTileIndex()

        // Fade streak out BEFORE any doors move
        withAnimation(.easeInOut(duration: 0.2)) { counterOpacity = 0 }

        if lastLevelIndexBeforeShop == 0 {
            // Starter (doors closed) → switch to shop and let OPEN run
            withAnimation(.easeInOut(duration: 0.2)) { phase = .shop }
            switchToShopMusic()
        } else {
            // Non-starter (doors open) → CLOSE first (via Starter), then go to shop on close-end
            pendingEnterShopAfterClose = true
            progression.jumpToLevelIndex(0)   // triggers CLOSE (shop switch will happen in onCloseEnded)
        }
    }

    private func exitShop() {
        guard phase == .shop else { return }
        guard !isDoorsOpening else { return }
        //shopOpacity = 0.0
        isDoorsClosing = true
        withAnimation(.easeInOut(duration: 0.8)) {
            shopOpacity = 0.0
        }


        // While closing out of the shop, keep streak hidden the whole time
        suppressStreakUntilCloseEnds = true

        if lastLevelIndexBeforeShop == 0 {
            // We want to end on Starter (doors closed). Force a CLOSE from shop → starter.
            withAnimation(.easeInOut(duration: 0.2)) { phase = .playing }
            pendingExitShopToIndex = nil
        } else {
            // We want to CLOSE to Starter then immediately OPEN to the previous non-starter.
            pendingExitShopToIndex = levelIndexForTile(lastLevelIndexBeforeShop)
            withAnimation(.easeInOut(duration: 0.2)) { phase = .playing }
            progression.jumpToLevelIndex(0)   // triggers CLOSE; reopen happens in onCloseEnded
        }
    }
    
    @ViewBuilder
    private func exitShopButton(_ geo: GeometryProxy) -> some View {
        HStack(spacing: 8) {
            Button(action: { exitShop() }) {
                SquareHUDButton(isOutlined: false) {
                    Image(systemName: "xmark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .opacity(0.9)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 24)
        .padding(.trailing, 96)
        .padding(.bottom, 30)
    }
    
    private func syncEquippedTableToFaceAndKey() {
        // Decide key: prefer ShopVM’s persisted equip, fall back to our AppStorage
        let keyFromVM = shopVM.equipped[.tables] ?? equippedTableKey
        if equippedTableKey != keyFromVM { equippedTableKey = keyFromVM }

        // Decide face letter (default to h if unknown)
        let side = (store.chosenFace == .Heads) ? "h" : "t"

        let targetImage = "\(equippedTableKey)_table_\(side)"
        if equippedTableImage != targetImage {
            equippedTableImage = targetImage
        }
    }
    
    private func syncEquippedCoinWithVM() {
        let keyFromVM = shopVM.equipped[.coins] ?? equippedCoinKey
        if equippedCoinKey != keyFromVM { equippedCoinKey = keyFromVM }
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
    private func triggerMinigameToast(message: String) {
        minigameToastMessage = message
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            showMinigameToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.95)) {
                showMinigameToast = false
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
    
    // MARK: Leaderboard Medals
    
    private func checkLeaderboardMedals() {
        guard isLeaderboardOpen, let mySide = store.chosenFace else { return }
        let myId = InstallIdentity.getOrCreateInstallId()

        // Pick the correct column for the user’s side
        let slice: [LeaderboardEntryDTO] = (mySide == .Heads) ? scoreboardVM.headsTop : scoreboardVM.tailsTop

        // Find my rank (top-5 only)
        guard let idx = slice.firstIndex(where: { $0.installId == myId }) else { return }
        let rank = idx + 1

        switch rank {
        case 1:
            if achievements.unlock(.gold) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { showNewTrophyToast = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.95)) { showNewTrophyToast = false }
                }
                SoundManager.shared.play("trophy_unlock")
                Haptics.shared.success()
            }
        case 2:
            if achievements.unlock(.silver) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { showNewTrophyToast = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.95)) { showNewTrophyToast = false }
                }
                SoundManager.shared.play("trophy_unlock")
                Haptics.shared.success()
            }
        case 3:
            if achievements.unlock(.bronze) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { showNewTrophyToast = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.95)) { showNewTrophyToast = false }
                }
                SoundManager.shared.play("trophy_unlock")
                Haptics.shared.success()
            }
        default:
            break   // ranks 4–5 (or not present) do nothing
        }
    }

    
    
    private func finalizePendingFlipIfPossible() {
        guard !pendingFlipOutcomeRaw.isEmpty else { return }
        guard let _ = store.chosenFace,
              let faceVal = Face(rawValue: pendingFlipOutcomeRaw) else { return }

        // Make the coin rest on the resolved outcome so UI matches reality
        curState = pendingFlipOutcomeRaw
        baseFaceAtLaunch = pendingFlipOutcomeRaw

        // Record in Recent Flips via store API (avoids private setter issues)
        store.recordFlip(result: faceVal)

        // Mark that we updated locally this launch
        pendingFlipJustApplied = true

        // Push through the same offline/online sync path you already use
        let installId = InstallIdentity.getOrCreateInstallId()
        StreakSync.shared.handleLocalFlip(
            installId: installId,
            current: store.currentStreak,
            isOnline: scoreboardVM.isOnline
        )

        // Clear pending
        pendingFlipOutcomeRaw = ""
    }

    // MARK: - FLIP LOGIC
    
    // Keep the no-arg for taps
    func flipCoin(visualOnly: Bool = false) { flipCoin(impulse: nil, visualOnly: visualOnly) }

    // Impulse-aware flip with visual-only mode for shop
    func flipCoin(impulse: Double?, visualOnly: Bool = false) {
        // If a minigame is actively hijacking the gameplay coin, ignore normal (non-visual) flips.
        if !visualOnly,
           minigameManager.isSessionActive,
           (minigameHostConfig?.hijacksGameplayCoin ?? false) {
            return
        }

        guard phase == .playing || (visualOnly && phase == .shop) else { return }
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
        //let desired = "Heads"
        //let desired = "Tails"
        #endif
        
        // Record this flip as pending so it's applied even if app is backgrounded/killed
        if !visualOnly {
            pendingFlipOutcomeRaw = desired
        }
        
        //DEBUG USE ONLY
        //achievements.resetAll()

        
        // Capture state
        baseFaceAtLaunch = curState
        isFlipping = true

        // If this is a visual-only flip while a hijacking minigame is active,
        // notify the minigame that the flip has begun (so it can lock selection, etc.).
        if visualOnly,
           minigameManager.isSessionActive,
           (minigameHostConfig?.hijacksGameplayCoin ?? false) {
            minigameManager.onVisualFlipBegan?()
        }

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

            // Notify any hijacking minigame of the visual-only flip outcome.
            if visualOnly,
               minigameManager.isSessionActive,
               (minigameHostConfig?.hijacksGameplayCoin ?? false) {
                minigameManager.onVisualFlipResolved?(desired)
            }

            // Bounce & wobble
            settleBounceT = 0.0
            withAnimation(.linear(duration: 0.70)) { settleBounceT = 1.0 }
            settleT = 0.0
            withAnimation(.linear(duration: 0.85)) { settleT = 1.0 }
            // In shop (visual-only) — but when a hijacking minigame is active,
            // let the minigame own its landing audio entirely.
            if visualOnly,
               !(minigameManager.isSessionActive && (minigameHostConfig?.hijacksGameplayCoin ?? false)) {
                SoundManager.shared.play(["land_1","land_2"].randomElement()!)
            }
            
            // If this was a “super” swipe, also do the dust burst + thud like hero drop
            if currentFlipWasSuper {
                // Always show the dust impact; only award achievements in normal play
                triggerDustImpactFromLanding()
                if !visualOnly {
                    if achievements.unlock(.highFlyer) {
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
                currentFlipWasSuper = false
            }

            // streak / award / tier / SFX logic
            if !visualOnly, let faceVal = Face(rawValue: desired), pendingFlipOutcomeRaw == desired {
                let preStreak = store.currentStreak
                let wasSuccess = (faceVal == store.chosenFace)
                
                //Flip Stats
                let isHeads = (faceVal == .Heads)
                stats.recordFlip(isHeads: isHeads, isCorrect: wasSuccess)
                
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
                
                // === STEADY / DEDICATED / DEVOTED ===
                totalFlips &+= 1

                if totalFlips >= 35000 && !achievements.isUnlocked(.devoted) {
                    if achievements.unlock(.devoted) {
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
                } else if totalFlips >= 10000 && !achievements.isUnlocked(.dedicated) {
                    if achievements.unlock(.dedicated) {
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
                } else if totalFlips >= 1000 && !achievements.isUnlocked(.steady) {
                    if achievements.unlock(.steady) {
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
                
                // === NIGHT OWL (flip between 12–4 AM local time) ===
                if !achievements.isUnlocked(.nightowl) {
                    let hour = Calendar.current.component(.hour, from: Date())
                    if (0...3).contains(hour) {    // 0,1,2 = 12AM–3:59AM
                        if achievements.unlock(.nightowl) {
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


                
                // === BALANCED / HARMONY: alternation tracker (H–T–H–T…) ===
                // Only do work if Harmony isn't already unlocked (Balanced may still unlock at 10 on the way)
                if !achievements.isUnlocked(.harmony) {
                    let prev = (alternatingLastRaw.isEmpty ? nil : alternatingLastRaw)
                    if let prev {
                        if prev != desired {
                            alternatingCount &+= 1
                        } else {
                            alternatingCount = 1
                        }
                    } else {
                        alternatingCount = 1
                    }
                    alternatingLastRaw = desired

                    // Unlocks (keep counting up so 10 → 15 works in one run)
                    if alternatingCount >= 15 {
                        // Hit Harmony
                        alternatingCount = 0 // clear so it can't spam
                        if achievements.unlock(.harmony) {
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
                    } else if alternatingCount >= 10 && !achievements.isUnlocked(._balanced) {
                        // Hit Balanced (only once)
                        if achievements.unlock(._balanced) {
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
                            
                            if preStreak >= 6 {
                                tokenBalance &+= TOKENS_PER_STREAK
                                stats.addTokensEarned(TOKENS_PER_STREAK)
                                SoundManager.shared.play(["earn_token_1","earn_token_2"].randomElement()!)
                            }
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
                                
                                // Award tokens per completed bar fill
                                tokenBalance &+= TOKENS_PER_FILL
                                stats.addTokensEarned(TOKENS_PER_FILL)
                                SoundManager.shared.play(["earn_token_1","earn_token_2"].randomElement()!)

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

                    // Play landing sound only when no hijacking minigame is active.
                    if !(minigameManager.isSessionActive && (minigameHostConfig?.hijacksGameplayCoin ?? false)) {
                        SoundManager.shared.play(["land_1","land_2"].randomElement()!)
                    }
                }
                
                pendingFlipOutcomeRaw = ""
            }
        }
    }

}


// MARK: BOTTOM MENU BUTTONS

private extension ContentView {
    @ViewBuilder
    func bottomMenuOverlay(_ geo: GeometryProxy) -> some View {
        ZStack(alignment: .leading) {

            var anyBottomSheetOpen: Bool {
                isMapSelectOpen || isSettingsOpen || isTrophiesOpen || isMoreOpen
            }

            // === Buttons row (Map + Settings + Trophy + Scoreboard) ===
            HStack(alignment: .bottom, spacing: 8) {
                // MAP button
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                        if isMapSelectOpen {
                            isMapSelectOpen = false
                        } else if isSettingsOpen {
                            isSettingsOpen = false
                        } else if isTrophiesOpen {
                            isTrophiesOpen = false
                        } else if isMoreOpen {
                            isMoreOpen = false
                        } else {
                            isMapSelectOpen = true
                        }
                    }
                    Haptics.shared.tap()
                } label: {
                    SquareHUDButton(
                        isOutlined: showNewMapToast,
                        outlineColor: Color(red: 0.35, green: 0.4, blue: 1.0)
                    ) {
                        Image(systemName: anyBottomSheetOpen ? "xmark" : "map.fill")
                            .resizable().scaledToFit()
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
                        if isMoreOpen { isMoreOpen = false }
                        isTrophiesOpen.toggle()
                    }
                    Haptics.shared.tap()
                } label: {
                    SquareHUDButton(
                        isOutlined: showNewTrophyToast,
                        outlineColor: Color(red: 1.0, green: 0.8, blue: 0.2)
                    ) {
                        Image(systemName: "trophy.fill")
                            .resizable().scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .buttonStyle(.plain)
                .opacity((isMapSelectOpen || isSettingsOpen || isTrophiesOpen || isMoreOpen) ? 0 : 1)
                .disabled(isMapSelectOpen || isSettingsOpen || isTrophiesOpen || isMoreOpen)
                .animation(.easeInOut(duration: 0.2), value: isMapSelectOpen)
                .animation(.easeInOut(duration: 0.2), value: isSettingsOpen)
                .animation(.easeInOut(duration: 0.2), value: isTrophiesOpen)
                .animation(.easeInOut(duration: 0.2), value: isMoreOpen)
                
                // MORE button
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                        let new = !isMoreOpen
                        // Close other panels when toggling More
                        isMapSelectOpen = false
                        isSettingsOpen = false
                        isTrophiesOpen = false
                        isBattleMenuOpen = false
                        isMoreOpen = new
                    }
                    Haptics.shared.tap()
                } label: {
                    SquareHUDButton(isOutlined: false) {
                        VStack(spacing: 4) {
                            Capsule()
                                .frame(width: 18, height: 3)
                            Capsule()
                                .frame(width: 18, height: 3)
                            Capsule()
                                .frame(width: 18, height: 3)
                        }
                        .foregroundColor(.white.opacity(0.6))
                    }
                }
                .buttonStyle(.plain)
                .opacity((isMapSelectOpen || isSettingsOpen || isTrophiesOpen || isMoreOpen) ? 0 : 1)
                .disabled(isMapSelectOpen || isSettingsOpen || isTrophiesOpen || isMoreOpen)
                .animation(.easeInOut(duration: 0.2), value: isMapSelectOpen)
                .animation(.easeInOut(duration: 0.2), value: isSettingsOpen)
                .animation(.easeInOut(duration: 0.2), value: isTrophiesOpen)
                .animation(.easeInOut(duration: 0.2), value: isMoreOpen)
                
                //SHOP button
                Button {
                    enterShop()
                    Haptics.shared.tap()
                } label: {
                    SquareHUDButton(
                        isOutlined: showNewTokensToast,
                        outlineColor: Color(red: 1.00, green: 0.85, blue: 0.20) // warm gold
                    ) {
                        Image(systemName: "storefront.fill")
                            .resizable().scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .buttonStyle(.plain)
                .opacity((isMapSelectOpen || isSettingsOpen || isTrophiesOpen || isMoreOpen) ? 0 : 1)
                .disabled(isMapSelectOpen || isSettingsOpen || isTrophiesOpen || isMoreOpen)
                .animation(.easeInOut(duration: 0.2), value: isMapSelectOpen)
                .animation(.easeInOut(duration: 0.2), value: isSettingsOpen)
                .animation(.easeInOut(duration: 0.2), value: isTrophiesOpen)
                .animation(.easeInOut(duration: 0.2), value: isMoreOpen)

                //Spacer(minLength: 0)
                
                //BATTLES menu button
                /*Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                        isBattleMenuOpen = true
                    }
                    Haptics.shared.tap()
                } label: {
                    SquareHUDButton(isOutlined: false) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "flag.2.crossed.fill")
                                .resizable().scaledToFit()
                                .frame(width: 28, height: 28)
                                .foregroundColor(.white.opacity(0.6))

                            if battleVM.hasAttention {
                                Text("!")
                                    .font(.system(size: 11, weight: .black, design: .rounded))
                                    .foregroundColor(.black.opacity(0.9))
                                    .frame(width: 16, height: 16)
                                    .background(Color.yellow.opacity(0.95))
                                    .clipShape(Circle())
                                    .offset(x: 6, y: -6) // nudge to corner
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
                .opacity((isMapSelectOpen || isSettingsOpen || isTrophiesOpen) ? 0 : 1)
                .disabled(isMapSelectOpen || isSettingsOpen || isTrophiesOpen)
                .animation(.easeInOut(duration: 0.2), value: isMapSelectOpen)
                .animation(.easeInOut(duration: 0.2), value: isSettingsOpen)
                .animation(.easeInOut(duration: 0.2), value: isTrophiesOpen)*/
                
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
                    Haptics.shared.tap()
                } label: {
                    SquareHUDButton(isOutlined: isScoreMenuOpen) {
                        Image("scoreboard_menu_icon")
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(width: 23, height: 23)
                            .opacity(0.8)
                        }
                }
                .buttonStyle(.plain)
                .opacity((isMapSelectOpen || isSettingsOpen || isTrophiesOpen || isMoreOpen) ? 0 : 1)
                .disabled(isMapSelectOpen || isSettingsOpen || isTrophiesOpen || isMoreOpen)
                .animation(.easeInOut(duration: 0.2), value: isMapSelectOpen)
                .animation(.easeInOut(duration: 0.2), value: isSettingsOpen)
                .animation(.easeInOut(duration: 0.2), value: isTrophiesOpen)
                .animation(.easeInOut(duration: 0.2), value: isMoreOpen)
                
                
                // WEEKLY MINIGAME button
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                        // Close any bottom sheets when opening minigame
                        isMapSelectOpen = false
                        isSettingsOpen = false
                        isTrophiesOpen = false
                        isMoreOpen = false
                        // Also close scoreboard/leaderboard if open
                        isScoreMenuOpen = false
                        isLeaderboardOpen = false
                    }

                    Haptics.shared.tap()

                    // Guard: only allow entering the minigame when we are online and
                    // the backend is reachable.
                    if !minigameManager.isOnlineForMinigame {
                        triggerMinigameToast(message: "Connection required")
                        return
                    }

                    // Guard: backend says there *is* a current minigame, but this client
                    // doesn't have a registered host config/descriptor for it → require update.
                    guard minigameManager.currentHostConfig != nil else {
                        triggerMinigameToast(message: "Update required")
                        return
                    }
                    // When the active minigame is Call It, go through the custom transition
                    // path instead of starting the session immediately.
                    if minigameManager.activeMinigameId == .callIt {
                        
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showCallItTransition = true
                        }

                        // After the brief blackout ramp-up, begin the actual session.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.54) {
                            minigameManager.beginSession()
                        }
                    } else {
                        // All other minigames: fall back to the normal behavior.
                        minigameManager.beginSession()
                    }
                    
                } label: {
                    VStack(spacing: 3) {
                        if let remaining = minigameManager.timeRemaining {
                            Text(formatMinigameTimeRemaining(remaining))
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundColor(.white.opacity(0.7))
                        } else {
                            Text("Weekly")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                        }
  
                        SquareHUDButton(
                            isOutlined: false,
                            buttonWidth: 62,   // tweak these numbers to taste
                            buttonHeight: 36
                        ) {
                            Image(systemName: "gamecontroller.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 36, height: 36)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
                .buttonStyle(.plain)
                .opacity((isMapSelectOpen || isSettingsOpen || isTrophiesOpen || isMoreOpen) ? 0 : 1)
                .disabled(isMapSelectOpen || isSettingsOpen || isTrophiesOpen || isMoreOpen)
                .animation(.easeInOut(duration: 0.2), value: isMapSelectOpen)
                .animation(.easeInOut(duration: 0.2), value: isSettingsOpen)
                .animation(.easeInOut(duration: 0.2), value: isTrophiesOpen)
                .animation(.easeInOut(duration: 0.2), value: isMoreOpen)
                
            }

            // === Map toast ===
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
                    .offset(y: -24)
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.5), value: showNewMapToast)
                    .allowsHitTesting(false)
                    .zIndex(999)
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
                    .offset(y: -24)
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.5), value: showNewTrophyToast)
                    .allowsHitTesting(false)
                    .zIndex(999)
            }
            
            // === Tokens toast ===
            if !anyBottomSheetOpen && showNewTokensToast {
                HStack(spacing: 6) {
                    Text("+ \(lastTokenGain)")
                        .font(.system(size: 14, weight: .semibold))
                        .monospacedDigit()                               // stable digit widths
                    Image("tokens_icon")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .opacity(0.95)
                }
                .foregroundColor(.white.opacity(0.65))
                .padding(.horizontal, 12)                                // inner horizontal padding
                .frame(height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.09, green: 0.09, blue: 0.09, opacity: 0.10),
                                    Color(red: 0.095, green: 0.095, blue: 0.095, opacity: 0.20)
                                ],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .fixedSize(horizontal: true, vertical: false)
                .padding(.leading, 132)
                .offset(y: -24)
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.5), value: showNewTokensToast)
                .allowsHitTesting(false)
                .zIndex(999)
            }
            
            // === Minigame toast ===
            if !anyBottomSheetOpen && showMinigameToast {
                HStack(spacing: 8) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 13, weight: .bold))
                        .opacity(0.9)
                    Text(minigameToastMessage)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                }
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 14)
                .frame(height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.65, green: 0.10, blue: 0.10, opacity: 0.96),
                                    Color(red: 0.90, green: 0.20, blue: 0.18, opacity: 0.96)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .fixedSize(horizontal: true, vertical: false)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.leading, 110)
                .offset(y: -24)
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.5), value: showMinigameToast)
                .allowsHitTesting(false)
                .zIndex(1000)
            }
            
            
        }
        .padding(.leading, 24)
        .padding(.trailing, 96)
        .padding(.bottom, 30)
        .opacity(
            (phase != .choosing && phase != .shop) &&
            !(minigameManager.isSessionActive && (minigameManager.currentHostConfig?.hidesBottomMenu ?? false))
            ? 1 : 0
        )
        .animation(.easeInOut(duration: 0.2), value: phase)
        
        // MARK: - MORE MENU WINDOW
        if isMoreOpen {

            VStack {
                Spacer()
                HStack(alignment: .center, spacing: 12) {

                    // Reserve the X area; don't intercept taps here
                    Spacer()
                        .frame(width: 46)
                        .allowsHitTesting(false)

                    // MORE carousel
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            // SETTINGS tile
                            SettingsTile(size: 90, label: "Settings") {
                                ZStack {
                                    Image(systemName: "gearshape.fill")
                                        .font(.system(size: 90 * 0.34, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                            .onTapGesture {
                                Haptics.shared.tap()
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isMoreOpen = false
                                    isSettingsOpen = true
                                }
                            }
                            
                            // STATS tile
                            SettingsTile(size: 90, label: "Stats") {
                                ZStack {
                                    Image(systemName: "chart.bar.xaxis")
                                        .font(.system(size: 90 * 0.34, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                            .onTapGesture {
                                Haptics.shared.tap()
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isMoreOpen = false
                                    isStatsOpen = true
                                }
                            }

                            // BATTLES tile
                            SettingsTile(size: 90, label: "Battles") {
                                ZStack {
                                    Image(systemName: "flag.and.flag.filled.crossed")
                                        .font(.system(size: 90 * 0.34, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                            .onTapGesture {
                                Haptics.shared.tap()
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isMoreOpen = false
                                    isBattleMenuOpen = true
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
    
    private func formatMinigameTimeRemaining(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let days = totalSeconds / 86_400
        let hours = (totalSeconds % 86_400) / 3_600
        let minutes = (totalSeconds % 3_600) / 60

        if days > 0 {
            return "\(days)d \(String(format: "%02d", hours))h"
        } else {
            return String(format: "%02d:%02d", hours, minutes)
        }
    }
}


// MARK: CHOOSE/MINIGAME OVERLAY

private extension ContentView {
    
    // MARK: Minigame host helpers
    
    /// Convenience for reading the current minigame host config (if any).
    var minigameHostConfig: MinigameHostConfig? {
        minigameManager.currentHostConfig
    }
    
    /// True when an active minigame has requested that the main HUD be hidden.
    var minigameHidesHUD: Bool {
        minigameManager.isSessionActive && (minigameHostConfig?.hidesStreakHUD ?? false)
    }
    
    /// True when an active minigame is running in a dedicated screen / takeover mode.
    var minigameIsTakeover: Bool {
        minigameManager.isSessionActive && (minigameHostConfig?.mode == .dedicatedScreen)
    }
    
    @ViewBuilder
    func minigameHostOverlay() -> some View {
        if minigameManager.isSessionActive,
           let registered = minigameManager.currentRegisteredMinigame,
           let hostConfig = minigameManager.currentHostConfig {

            let context = MinigameContext(
                manager: minigameManager,
                flipCoinVisual: { flipCoin(visualOnly: true) }
            )

            switch hostConfig.mode {
            case .overlay:
                ZStack {
                    Color.black.opacity(0.55)
                        .ignoresSafeArea()
                    registered.makeView(context)
                }
                .transition(.opacity)
                .zIndex(550)

            case .dedicatedScreen:
                // For dedicated-screen minigames like Call It, let the underlying
                // coin/table/backwall show through and let the minigame view
                // decide how much additional chrome or dimming it wants.
                registered.makeView(context)
                    .transition(.opacity)
                    .zIndex(550)
            }
        }
    }
    
    @ViewBuilder
    func chooseOverlay(_ geo: GeometryProxy, groundY: CGFloat) -> some View {
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
                        await scoreboardVM.refresh(includeLeaderboard: isLeaderboardOpen)
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
}







