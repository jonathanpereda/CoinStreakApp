import SwiftUI
import Foundation
import UIKit

extension ContentView {
    func runReboundBounces() {
        // Increment generation to invalidate any earlier scheduled steps
        bounceGen &+= 1
        let gen = bounceGen

        // Tunables
        let amps: [CGFloat] = [-10, -6, -3]    // pixels up (negative y = up)
        let upResp:  Double = 0.12
        let upDamp:  Double = 0.62
        let dnResp:  Double = 0.16
        let dnDamp:  Double = 0.88

        // Total timing accumulator
        var t: Double = 0

        func schedule(_ delay: Double, _ block: @escaping () -> Void) {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard gen == bounceGen else { return }  // canceled by new flip
                block()
            }
        }

        for i in 0..<amps.count {
            let a = amps[i]

            // Up tick
            schedule(t) {
                withAnimation(.spring(response: upResp, dampingFraction: upDamp)) {
                    y = a
                }
            }
            t += upResp * 0.85  // begin coming down slightly before the up spring fully settles

            // Down to rest
            schedule(t) {
                withAnimation(.spring(response: dnResp, dampingFraction: dnDamp)) {
                    y = 0
                }
            }
            t += dnResp * 0.95
        }
    }
    
    // Plays the hero-drop thud and spawns the gameplay dust burst at the coin’s ground contact.
    func triggerDustImpactFromLanding() {
        let now = Date()
        gameplayDustTrigger = now
        SoundManager.shared.play("thud_1")

        // auto-remove after the puff (match DustPuff’s 0.48s + tiny buffer)
        let lifetime = 0.48 + 0.05
        DispatchQueue.main.asyncAfter(deadline: .now() + lifetime) {
            if gameplayDustTrigger == now {
                gameplayDustTrigger = nil
            }
        }
    }
}
