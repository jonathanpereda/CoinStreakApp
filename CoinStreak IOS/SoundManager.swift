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

    // If you’re using a blue folder named "Sounds", leave this as "Sounds".
    // If not, no worries — the resolver falls back to bundle root automatically.
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

    /// Play a short one-shot SFX (e.g., launch_1, land_2).
    func play(_ name: String, volume: Float = 1.0) {
        guard !isSfxMuted else { return }
        let url = resolveURL(for: name, ext: "wav")
              ?? resolveURL(for: name, ext: "mp3")   // ← add this
        guard let url else {
            print("⚠️ Missing sound: \(name) (.wav/.mp3 not found)")
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
            print("🔈 Sound error (\(name)): \(error.localizedDescription)")
        }
    }


    /// Play the base tone at a given semitone offset (for streak buildup).
    /// 1 semitone = 100 cents. Example: semitoneOffset = 7 → a perfect fifth up.
    func playPitched(base name: String, semitoneOffset: Float, volume: Float = 0.4) {
        guard !isSfxMuted else { return }
        guard let url = resolveURL(for: name, ext: "wav"),
              let file = try? AVAudioFile(forReading: url) else {
            print("⚠️ Missing pitched sound: \(name)")
            return
        }

        // Activate session (important for AVAudioEngine)
        ensureAudioSessionActive()

        // Rebuild engine fresh for simplicity
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

        // Read file into buffer (more reliable for very short clips)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                            frameCapacity: AVAudioFrameCount(file.length)) else { return }
        do {
            try file.read(into: buffer)
        } catch {
            print("🎛️ Buffer read error: \(error.localizedDescription)")
            return
        }

        do {
            try engine.start()
        } catch {
            print("🎛️ Engine start error: \(error.localizedDescription)")
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

    /// Call once (e.g., in onAppear) to see what’s actually packaged.
    func debugListSounds() {
        if let dir = Bundle.main.url(forResource: nil, withExtension: nil, subdirectory: preferredSubdirectory),
           let contents = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            print("📦 \(preferredSubdirectory)/:", contents.map(\.lastPathComponent))
        } else {
            print("ℹ️ No \(preferredSubdirectory)/ folder found in bundle; files may be at root.")
            if let root = Bundle.main.resourceURL,
               let contents = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) {
                let wavs = contents.filter { $0.pathExtension.lowercased() == "wav" }
                print("📦 Bundle root wavs:", wavs.map(\.lastPathComponent))
            }
        }
    }

    // MARK: - URL resolution

    /// Try preferred subfolder first (e.g., "Sounds"), then fall back to bundle root.
    private func resolveURL(for name: String, ext: String) -> URL? {
        if let u = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: preferredSubdirectory) {
            return u
        }
        return Bundle.main.url(forResource: name, withExtension: ext)
    }
    
    private func ensureAudioSessionActive() {
        let session = AVAudioSession.sharedInstance()
        // .ambient won’t pause other audio; use .playback if you want “app takes over”
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
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


    /// Start (or swap) a looping track with a gentle fade-in.
    /// Looks for .wav first (your default), then .mp3.
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
            print("⚠️ Loop asset '\(name)' not found (.wav or .mp3)")
            return
        }

        // Make sure the session is active (mixes with others by default in your setup)
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
            print("⚠️ Failed to start loop '\(name)': \(error)")
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


}
