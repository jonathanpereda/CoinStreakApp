//
//  SoundManager.swift
//  CoinStreak IOS
//
//  Created by Jonathan Pereda on 10/4/25.
//

import AVFoundation

final class SoundManager: NSObject {
    static let shared = SoundManager()

    // Keep short players alive during playback
    private var players: [String: AVAudioPlayer] = [:]

    // Engine chain for pitched streak tone
    private var engine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var pitchNode: AVAudioUnitTimePitch?

    // MARK: - Typing SFX pool

    /// Short "bleep" for typewriter / headline text, lives in Sounds/
    private let typingSoundName = "headline_type"

    /// Small pool so overlapping ticks don't stomp each other
    private var typingPlayers: [AVAudioPlayer] = []
    private var typingIndex: Int = 0

    /// Simple throttle so we don't spam too fast
    private var lastTypingSoundTime: TimeInterval = 0

    private let preferredSubdirectory = "Sounds"

    private override init() {}
    
    // MARK: - Mute preferences (persisted)
    private let kSfxMutedKey   = "audio.sfx.muted"
    private let kMusicMutedKey = "audio.music.muted"

    private(set) var isSfxMuted: Bool = UserDefaults.standard.bool(forKey: "audio.sfx.muted") {
        didSet { UserDefaults.standard.set(isSfxMuted, forKey: kSfxMutedKey) }
    }
    private(set) var isMusicMuted: Bool = UserDefaults.standard.bool(forKey: "audio.music.muted") {
        didSet {
            UserDefaults.standard.set(isMusicMuted, forKey: kMusicMutedKey)
            applyMusicMuteNow()
        }
    }

    // Exposed helpers
    func setSfxMuted(_ v: Bool)   { isSfxMuted = v }
    func setMusicMuted(_ v: Bool) { isMusicMuted = v }
    func toggleSfxMuted()         { isSfxMuted.toggle() }
    func toggleMusicMuted()       { isMusicMuted.toggle() }

    
    
    // MARK: - Public API

    /// Play a short one-shot SFX
    func play(_ name: String, volume: Float = 1.0) {
        guard !isSfxMuted else { return }
        
        ensureAudioSessionActive()
        
        let url = resolveURL(for: name, ext: "wav")
              ?? resolveURL(for: name, ext: "mp3")
        guard let url else {
            print("Missing sound: \(name) (.wav/.mp3 not found)")
            return
        }
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.volume = volume
            p.prepareToPlay()
            p.play()
            players[name] = p
            p.delegate = self
        } catch {
            print("Sound error (\(name)): \(error.localizedDescription)")
        }
    }

    /// Lazily build a small pool of players for the typing SFX.
    private func ensureTypingPlayersLoaded() {
        if !typingPlayers.isEmpty { return }  // already loaded

        guard let url = resolveURL(for: typingSoundName, ext: "wav")
           ?? resolveURL(for: typingSoundName, ext: "mp3") else {
            print("Missing typing SFX: \(typingSoundName)")
            return
        }

        do {
            // Small pool (3–4) is plenty for overlapping ticks
            let poolSize = 4
            var pool: [AVAudioPlayer] = []
            for _ in 0..<poolSize {
                let p = try AVAudioPlayer(contentsOf: url)
                p.volume = 1.0
                p.prepareToPlay()
                pool.append(p)
            }
            typingPlayers = pool
        } catch {
            print("Failed to load typing SFX: \(error.localizedDescription)")
        }
    }

    /// Lightweight, pooled "tick" for typewriter / headline text.
    func playTypingTick() {
        guard !isSfxMuted else { return }

        // Throttle a bit: don't fire more often than every ~60ms.
        let now = Date().timeIntervalSince1970
        if now - lastTypingSoundTime < 0.06 {
            return
        }
        lastTypingSoundTime = now

        ensureAudioSessionActive()
        ensureTypingPlayersLoaded()
        guard !typingPlayers.isEmpty else { return }

        // Round-robin through the pool
        let player = typingPlayers[typingIndex]
        typingIndex = (typingIndex + 1) % typingPlayers.count

        // Restart from the beginning and play
        player.currentTime = 0
        player.play()
    }

    /// Play the base tone at a given semitone offset (for streak buildup).
    /// 1 semitone = 100 cents.
    func playPitched(base name: String, semitoneOffset: Float, volume: Float = 0.4) {
        guard !isSfxMuted else { return }
        guard let url = resolveURL(for: name, ext: "wav"),
              let file = try? AVAudioFile(forReading: url) else {
            print("Missing pitched sound: \(name)")
            return
        }

        // Activate session
        ensureAudioSessionActive()

        // Rebuild engine fresh
        engine?.stop()
        engine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        pitchNode = AVAudioUnitTimePitch()

        guard let engine, let playerNode, let pitchNode else { return }

        // Pitch in cents (100 = 1 semitone)
        pitchNode.pitch = semitoneOffset * 100

        engine.attach(playerNode)
        engine.attach(pitchNode)

        let format = file.processingFormat
        engine.connect(playerNode, to: pitchNode, format: format)
        engine.connect(pitchNode, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = volume

        // Read file into buffer
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                            frameCapacity: AVAudioFrameCount(file.length)) else { return }
        do {
            try file.read(into: buffer)
        } catch {
            print("Buffer read error: \(error.localizedDescription)")
            return
        }

        do {
            try engine.start()
        } catch {
            print("Engine start error: \(error.localizedDescription)")
            return
        }

        // Schedule buffer and play
        playerNode.scheduleBuffer(buffer, at: nil, options: []) { [weak self] in
            // Give the tail a moment, then stop to free resources
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self?.engine?.stop()
            }
        }

        playerNode.play()
    }


    // MARK: - Debug helpers
    /*
    /// Call once to see what’s actually packaged.
    func debugListSounds() {
        if let dir = Bundle.main.url(forResource: nil, withExtension: nil, subdirectory: preferredSubdirectory),
           let contents = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            print("\(preferredSubdirectory)/:", contents.map(\.lastPathComponent))
        } else {
            print("ℹ️ No \(preferredSubdirectory)/ folder found in bundle; files may be at root.")
            if let root = Bundle.main.resourceURL,
               let contents = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) {
                let wavs = contents.filter { $0.pathExtension.lowercased() == "wav" }
                print("Bundle root wavs:", wavs.map(\.lastPathComponent))
            }
        }
    }
     */

    // MARK: - URL resolution

    /// Try preferred subfolder first then fall back to bundle root.
    private func resolveURL(for name: String, ext: String) -> URL? {
        if let u = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: preferredSubdirectory) {
            return u
        }
        return Bundle.main.url(forResource: name, withExtension: ext)
    }
    
    private func ensureAudioSessionActive() {
        let session = AVAudioSession.sharedInstance()
        // .ambient won’t pause other audio; use .playback for “app takes over”
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true, options: [])
    }

    
}

// MARK: - AVAudioPlayerDelegate (cleanup finished players)
extension SoundManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // Remove any entries that reference this player
        for (k, v) in players where v === player {
            players.removeValue(forKey: k)
            break
        }
    }
}

// MARK: - Background loop (tier ambience/music)
extension SoundManager {
    private static var bgmPlayer: AVAudioPlayer?
    private static var bgmFaderTimer: Timer?
    private static var bgmCurrentName: String?
    private static var bgmTargetVolume: Float = 0.8

    /// Suspended loop info (e.g. main tier ambience) while a temporary
    /// override (like a minigame BGM) is playing.
    private static var bgmSuspendedName: String?
    private static var bgmSuspendedVolume: Float = 0.8


    /// Start (or swap) a looping track with a gentle fade-in.
    /// Looks for .wav first, then .mp3.
    func startLoop(named name: String, volume: Float = 0.8, fadeIn: TimeInterval = 0.8) {
        // If same track already playing, just fade to target volume
        if Self.bgmCurrentName == name, let p = Self.bgmPlayer, p.isPlaying {
            fade(to: volume, over: fadeIn)
            return
        }

        // Stop any existing loop quickly before starting new one
        stopLoop(fadeOut: 0.15)

        // Resolve URL (prefer wav, then mp3)
        let url = resolveURL(for: name, ext: "wav")
              ?? resolveURL(for: name, ext: "mp3")

        guard let url else {
            print("Loop asset '\(name)' not found (.wav or .mp3)")
            return
        }

        // Make sure the session is active
        ensureAudioSessionActive()

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = 0.0
            player.prepareToPlay()
            player.play()

            Self.bgmPlayer = player
            Self.bgmCurrentName = name
            Self.bgmTargetVolume = volume
            fade(to: isMusicMuted ? 0.0 : volume, over: fadeIn)
        } catch {
            print("Failed to start loop '\(name)': \(error)")
        }
    }

    /// Stop the loop with a gentle fade-out (and release the player).
    func stopLoop(fadeOut: TimeInterval = 0.6) {
        guard let p = Self.bgmPlayer, p.isPlaying else { return }
        fade(to: 0.0, over: fadeOut) {
            Self.bgmPlayer?.stop()
            Self.bgmPlayer = nil
            Self.bgmCurrentName = nil
        }
    }

    /// Smooth volume ramp utility.
    private func fade(to target: Float, over duration: TimeInterval, completion: (() -> Void)? = nil) {
        Self.bgmFaderTimer?.invalidate()
        guard duration > 0, let player = Self.bgmPlayer else {
            Self.bgmPlayer?.volume = isMusicMuted ? 0.0 : target
            completion?()
            return
        }

        let goal = isMusicMuted ? 0.0 : target
        let steps = 30
        let dt = duration / Double(steps)
        let start = player.volume
        var i = 0

        let timer = Timer.scheduledTimer(withTimeInterval: dt, repeats: true) { timer in
            i += 1
            let t = min(1.0, Double(i) / Double(steps))
            player.volume = start + Float(t) * (goal - start)
            if t >= 1.0 {
                timer.invalidate()
                completion?()
            }
        }
        Self.bgmFaderTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    
    private func applyMusicMuteNow() {
        guard let p = Self.bgmPlayer else { return }
        // Snap instantly to current mute target (no ramp here)
        p.volume = isMusicMuted ? 0.0 : Self.bgmTargetVolume
    }


    // MARK: - Loop suspension / resume (for minigames, overlays, etc.)

    /// Suspend the currently playing loop (if any) with a fade-out, remembering
    /// its identity and target volume so it can be restored later.
    ///
    /// Typical usage:
    ///   SoundManager.shared.suspendCurrentLoop(fadeOut: 0.3)
    ///   SoundManager.shared.startLoop(named: "callit_bgm", volume: 0.8)
    ///
    /// Then, after the temporary track is done:
    ///   SoundManager.shared.stopLoop(fadeOut: 0.3)
    ///   SoundManager.shared.resumeSuspendedLoop(fadeIn: 0.6)
    func suspendCurrentLoop(fadeOut: TimeInterval = 0.3) {
        // If nothing is playing, nothing to suspend.
        guard let currentName = Self.bgmCurrentName,
              let _ = Self.bgmPlayer else { return }

        // Remember what was playing and at what target volume.
        Self.bgmSuspendedName = currentName
        Self.bgmSuspendedVolume = Self.bgmTargetVolume

        // Now fade out and stop the current loop.
        stopLoop(fadeOut: fadeOut)
    }

    /// Resume any previously suspended loop, if present. This will restart the
    /// remembered track from the beginning, fading it in to its prior target
    /// volume. If nothing was suspended, this is a no-op.
    func resumeSuspendedLoop(fadeIn: TimeInterval = 0.6) {
        guard let name = Self.bgmSuspendedName else { return }

        let volume = Self.bgmSuspendedVolume

        // Clear the suspension state first to avoid re-entrancy issues.
        Self.bgmSuspendedName = nil

        // Restart the original loop. It will respect isMusicMuted internally.
        startLoop(named: name, volume: volume, fadeIn: fadeIn)
    }


}
