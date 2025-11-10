import UIKit
import CoreHaptics

final class Haptics {
    static let shared = Haptics()

    private var engine: CHHapticEngine?
    private var supportsHaptics: Bool {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    // Persisted user toggle (default ON)
    private let keyEnabled = "haptics.enabled"
    var isEnabled: Bool {
        get {
            // default to true if key not set yet
            if UserDefaults.standard.object(forKey: keyEnabled) == nil { return true }
            return UserDefaults.standard.bool(forKey: keyEnabled)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: keyEnabled)
            if newValue {
                prepare()
            } else {
                // Stop and release engine to save battery
                engine?.stop(completionHandler: nil)
                engine = nil
            }
        }
    }

    /// Call once at app start (or onAppear) so the engine is ready with no latency.
    func prepare() {
        guard isEnabled, supportsHaptics else { return }
        do {
            if engine == nil { engine = try CHHapticEngine() }
            guard let engine else { return }

            // Keep engine alive
            engine.stoppedHandler = { [weak self] _ in
                guard let self else { return }
                if self.isEnabled { try? self.engine?.start() }
            }
            engine.resetHandler = { [weak self] in
                guard let self else { return }
                if self.isEnabled { try? self.engine?.start() }
            }

            try engine.start()
        } catch {
            // Fallback will handle runtime taps
            engine = nil
        }
    }

    /// Deep “thud” (low sharpness, high intensity)
    func thud() {
        guard isEnabled else { return }
        if supportsHaptics, let engine {
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
            let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
            do {
                let pattern = try CHHapticPattern(events: [event], parameters: [])
                let player  = try engine.makePlayer(with: pattern)
                try player.start(atTime: 0)
            } catch {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }
        } else {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
    }

    func tap() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func success() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Firm, descending double‑tap “deny” for unavailable/locked actions.
    /// Use when the user taps something they can't afford in the shop.
    func deny() {
        guard isEnabled else { return }

        if supportsHaptics, let engine {
            // Two quick knocks with a slight drop in intensity/sharpness → "nope"
            let i1 = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9)
            let s1 = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.30)
            let e1 = CHHapticEvent(eventType: .hapticTransient, parameters: [i1, s1], relativeTime: 0.0)

            let i2 = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6)
            let s2 = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.22)
            let e2 = CHHapticEvent(eventType: .hapticTransient, parameters: [i2, s2], relativeTime: 0.08)

            do {
                let pattern = try CHHapticPattern(events: [e1, e2], parameters: [])
                let player  = try engine.makePlayer(with: pattern)
                try player.start(atTime: 0)
            } catch {
                // Fallback to system "error" feel
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        } else {
            // Broadest fallback on devices without Core Haptics
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
    
    /// Subtle gritty buzz for door **opening** (slightly ramps up)
    func scrapeOpen(duration: Double = 1.0) {
        guard isEnabled else { return }
        playScrape(duration: duration, rampUp: true)
    }

    /// Subtle gritty buzz for door **closing** (slightly ramps down)
    func scrapeClose(duration: Double = 0.80) {
        guard isEnabled else { return }
        playScrape(duration: duration, rampUp: false)
    }

    // MARK: - Internal

    private func playScrape(duration: Double, rampUp: Bool) {
        // Fallback for older devices or if engine not ready
        func fallback() {
            let gen = UIImpactFeedbackGenerator(style: .rigid)
            gen.impactOccurred(intensity: 0.5)
        }

        guard supportsHaptics else { fallback(); return }
        prepare() // ensure engine is warm
        guard let engine else { fallback(); return }

        // Build a string of tiny transients to feel like a scrape/jitter
        // ~30ms spacing → ~33 Hz “texture”, soft intensity that ramps slightly
        let step: Double = 0.03
        let count = max(1, Int(duration / step))
        var events: [CHHapticEvent] = []
        for i in 0..<count {
            let t = Double(i) * step
            let pct = count > 1 ? Double(i) / Double(count - 1) : 1.0
            // base intensity 0.25 → 0.45 (open ramps up, close ramps down)
            let baseLo: Float = 0.25
            let baseHi: Float = 0.45
            let intensityVal: Float = rampUp
                ? baseLo + Float(pct) * (baseHi - baseLo)
                : baseHi - Float(pct) * (baseHi - baseLo)

            // keep sharpness low so it feels “rubby” not “tappy”; add a tiny wobble
            let sharpnessVal: Float = 0.28 + 0.04 * ((i % 2 == 0) ? 1 : -1)

            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensityVal)
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpnessVal)
            let ev = CHHapticEvent(eventType: .hapticTransient,
                                   parameters: [intensity, sharpness],
                                   relativeTime: t)
            events.append(ev)
        }

        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player  = try engine.makeAdvancedPlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            fallback()
        }
    }
}
