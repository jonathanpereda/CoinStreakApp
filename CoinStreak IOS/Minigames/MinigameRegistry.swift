import Foundation
import SwiftUI

/// Context object passed into each minigame’s view factory.
/// Gives the minigame access to shared manager state and helpers
/// without letting it poke directly at ContentView.
struct MinigameContext {
    let manager: MinigameManager
    /// Optional hook the host can provide so minigames can trigger a visual-only flip
    /// of the main gameplay coin without affecting the core streak logic.
    let flipCoinVisual: (() -> Void)?

    init(manager: MinigameManager, flipCoinVisual: (() -> Void)? = nil) {
        self.manager = manager
        self.flipCoinVisual = flipCoinVisual
    }

    var myBestScore: Int? {
        manager.myStatus.bestScore
    }

    func submit(score: Int) {
        manager.submitRun(score: score)
    }

    func endSession() {
        manager.endSession()
    }

    /// Request a visual-only flip of the main coin, if the host provided a hook.
    func flipCoin() {
        flipCoinVisual?()
    }

    /// Register a handler that will be called whenever a visual-only flip
    /// resolves while this minigame is hijacking the gameplay coin.
    func onFlipResult(_ handler: @escaping (String) -> Void) {
        manager.onVisualFlipResolved = handler
    }
    
    /// Called right when a visual-only flip begins.
    func onFlipBegan(_ handler: @escaping () -> Void) {
        manager.onVisualFlipBegan = handler
    }

    /// Present a full-screen overlay above the core game using the shared
    /// minigame overlay slot. The overlay content is supplied by the minigame
    /// and will be rendered generically by the host.
    func presentOverlay<Content: View>(
        dimOpacity: Double = 0.65,
        dismissOnBackgroundTap: Bool = true,
        @ViewBuilder _ makeContent: () -> Content
    ) {
        let view = AnyView(makeContent())
        manager.activeOverlay = MinigameOverlayPayload(
            dimOpacity: dimOpacity,
            dismissOnBackgroundTap: dismissOnBackgroundTap,
            content: view
        )
    }

    /// Dismiss any currently active overlay that was presented via `presentOverlay`.
    func dismissOverlay() {
        manager.activeOverlay = nil
    }
}

/// Wraps the model-level descriptor together with the SwiftUI view factory.
struct RegisteredMinigame {
    let descriptor: MinigameDescriptor
    let makeView: (MinigameContext) -> AnyView
}

/// Central registry that knows about all minigames in the app and how
/// to construct their views. This keeps ContentView / MinigameManager
/// generic; they only deal with MinigameId and MinigameDescriptor.
enum MinigameRegistry {

    /// All registered minigames, keyed by their identifier.
    /// For now these use simple placeholder views; we'll replace them with
    /// real implementations as we build each minigame out.
    static let all: [MinigameId: RegisteredMinigame] = [
        .callIt: RegisteredMinigame(
            descriptor: MinigameDescriptor(
                id: .callIt,
                displayName: "Call It",
                hostConfig: MinigameHostConfig(
                    mode: .dedicatedScreen,
                    hidesBottomMenu: true,
                    hidesStreakHUD: true,
                    hijacksGameplayCoin: true
                )
            ),
            makeView: { context in
                AnyView(CallItMinigameView(context: context))
            }
        ),
        .coinRun: RegisteredMinigame(
            descriptor: MinigameDescriptor(
                id: .coinRun,
                displayName: "Coin Run",
                hostConfig: MinigameHostConfig(
                    mode: .overlay,
                    hidesBottomMenu: false,
                    hidesStreakHUD: false,
                    hijacksGameplayCoin: false
                )
            ),
            makeView: { context in
                AnyView(CoinRunMinigameView(context: context))
            }
        )
    ]

    /// Look up a registered minigame by its id.
    static func registeredMinigame(for id: MinigameId) -> RegisteredMinigame? {
        all[id]
    }

    /// Convenience to get just the model-level descriptor, if needed.
    static func descriptor(for id: MinigameId) -> MinigameDescriptor? {
        all[id]?.descriptor
    }
}
