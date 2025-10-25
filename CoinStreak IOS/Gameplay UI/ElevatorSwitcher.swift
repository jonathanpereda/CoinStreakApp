import SwiftUI

/// Elevator-style transition using two pre-split door images.
///
/// Slots:
/// - belowDoors : content that should appear *behind* the doors (during open/close and when open)
/// - aboveDoors : content that should appear *in front of* the closed doors (Starter idle, and after close)
struct ElevatorSwitcher<Below: View, Mid: View, Above: View>: View {
    let currentBackwallName: String
    let starterSceneName: String
    let doorLeftName: String
    let doorRightName: String
    var onDoorImpact: ((Date) -> Void)? = nil
    let belowDoors: () -> Below
    let midOverlay: () -> Mid
    let aboveDoors: () -> Above
    var onOpenEnded: (() -> Void)? = nil
    var onCloseEnded: (() -> Void)? = nil


    // Tunables
    private let openDur: Double  = 1.20
    private let closeDur: Double = 1.00
    // Fires near the end of the CLOSE, right when doors "slam"
    var onCloseImpact: (() -> Void)? = nil
    var closeImpactAt: Double = 0.88   // fraction of the close animation (0…1)
    private let openAnim: Animation  = .easeInOut(duration: 1.20)
    private let closeAnim: Animation = .easeInOut(duration: 1.00)
    private let seamTiltDeg: Double = 3.0
    private let perspective: CGFloat = 0.55

    // State
    @State private var displayedBackwall: String
    @State private var doorsOpen: Bool = false
    @State private var doorsHidden: Bool = false
    @State private var prevScene: String
    @State private var bootstrapped: Bool = false

    // Which slot is showing?
    @State private var showBelow: Bool = false
    @State private var showAbove: Bool = true

    init(
        currentBackwallName: String,
        starterSceneName: String,
        doorLeftName: String,
        doorRightName: String,
        onDoorImpact: ((Date) -> Void)? = nil,
        @ViewBuilder belowDoors: @escaping () -> Below,
        @ViewBuilder midOverlay: @escaping () -> Mid = { EmptyView() },
        @ViewBuilder aboveDoors: @escaping () -> Above,
        onOpenEnded: (() -> Void)? = nil,
        onCloseEnded: (() -> Void)? = nil,
        onCloseImpact: (() -> Void)? = nil,
        closeImpactAt: Double = 0.88
        
    ) {
        self.currentBackwallName = currentBackwallName
        self.starterSceneName = starterSceneName
        self.doorLeftName = doorLeftName
        self.doorRightName = doorRightName
        self.onDoorImpact = onDoorImpact
        self.belowDoors = belowDoors
        self.midOverlay = midOverlay
        self.aboveDoors = aboveDoors
        self.onOpenEnded = onOpenEnded
        self.onCloseEnded = onCloseEnded
        self.onCloseImpact = onCloseImpact
        self.closeImpactAt = max(0, min(1, closeImpactAt))

        _displayedBackwall = State(initialValue: currentBackwallName)
        _prevScene = State(initialValue: currentBackwallName)
    }

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = geo.size.height
            let slide = ceil(W / 2) + 80  // overscan to kill edge sliver

            ZStack {
                // BACK SCENE
                Image(displayedBackwall)
                    .resizable()
                    .scaledToFill()
                    .frame(width: W, height: H)
                    .clipped()
                    .ignoresSafeArea()

                // BELOW-DOORS SLOT
                if showBelow {
                    belowDoors()
                        .compositingGroup()
                        .zIndex(5)      // sits behind the doors
                }

                // DOORS
                Group {
                    Image(doorLeftName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: W, height: H)
                        .clipped()
                        .ignoresSafeArea()
                        .rotation3DEffect(.degrees(doorsOpen ? -seamTiltDeg : 0),
                                          axis: (x: 0, y: 1, z: 0),
                                          anchor: .trailing,
                                          perspective: perspective)
                        .offset(x: doorsOpen ? -slide : 0)
                        .opacity(doorsHidden ? 0 : 1)

                    Image(doorRightName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: W, height: H)
                        .clipped()
                        .ignoresSafeArea()
                        .rotation3DEffect(.degrees(doorsOpen ? seamTiltDeg : 0),
                                          axis: (x: 0, y: 1, z: 0),
                                          anchor: .leading,
                                          perspective: perspective)
                        .offset(x: doorsOpen ? +slide : 0)
                        .opacity(doorsHidden ? 0 : 1)
                }
                .zIndex(10)
                
                // mid overlay lives above doors, below the top UI
                midOverlay()
                  .frame(maxWidth: .infinity, maxHeight: .infinity)
                  .contentShape(Rectangle())
                  .allowsHitTesting(false)
                  .zIndex(15)

                // ABOVE-DOORS SLOT
                if showAbove {
                    aboveDoors()
                        .compositingGroup()
                        .zIndex(20)     // sits in front of closed doors
                }
            }
            .onAppear {
                bootstrapped = true
                displayedBackwall = currentBackwallName
                doorsOpen = (currentBackwallName != starterSceneName)
                doorsHidden = doorsOpen

                // If mount on Starter (doors closed), streak should be ABOVE doors.
                if currentBackwallName == starterSceneName {
                    showAbove = true
                    showBelow = false
                } else {
                    showAbove = false
                    showBelow = true
                }
            }
            .onChange(of: currentBackwallName) { _, newName in
                guard bootstrapped, newName != prevScene else { return }

                let fromStarter = (prevScene == starterSceneName)
                let toStarter   = (newName == starterSceneName)

                if fromStarter && !toStarter {
                    // OPEN: before anim, move streak BELOW doors so it’s revealed as doors open.
                    displayedBackwall = newName
                    showBelow = true
                    showAbove = false
                    doorsHidden = false
                    SoundManager.shared.play("scrape_1")
                    Haptics.shared.scrapeOpen()
                    withAnimation(openAnim) { doorsOpen = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + openDur) {
                        doorsHidden = true
                        onDoorImpact?(Date())
                        onOpenEnded?()
                    }
                } else if !fromStarter && toStarter {
                    // CLOSE: keep streak BELOW while doors shut over it...
                    showBelow = true
                    showAbove = false
                    doorsHidden = false
                    SoundManager.shared.play("scrape_1")
                    Haptics.shared.scrapeClose()
                    withAnimation(closeAnim) { doorsOpen = false }
                    DispatchQueue.main.asyncAfter(deadline: .now() + closeDur) {
                        displayedBackwall = newName
                        showAbove = true
                        showBelow = false
                        onDoorImpact?(Date())
                        onCloseEnded?()
                        SoundManager.shared.play("thud_1")
                        Haptics.shared.thud()
                    }
                } else {
                    // Fallback for unexpected changes
                    displayedBackwall = newName
                    let onStarter = (newName == starterSceneName)
                    doorsOpen = !onStarter
                    doorsHidden = !onStarter
                    showAbove = onStarter
                    showBelow = !onStarter
                }

                prevScene = newName
            }
        }
    }
}
