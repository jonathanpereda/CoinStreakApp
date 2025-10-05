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

    // MARK: - Public API

    /// Play a short one-shot SFX (e.g., launch_1, land_2).
    func play(_ name: String, volume: Float = 1.0) {
        guard let url = resolveURL(for: name, ext: "wav") else {
            print("⚠️ Missing sound: \(name)")
            return
        }
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.volume = volume
            p.prepareToPlay()
            p.play()
            // Retain until playback ends
            players[name] = p
            // Cleanup when finished (optional)
            p.delegate = self
        } catch {
            print("🔈 Sound error (\(name)): \(error.localizedDescription)")
        }
    }

    /// Play the base tone at a given semitone offset (for streak buildup).
    /// 1 semitone = 100 cents. Example: semitoneOffset = 7 → a perfect fifth up.
    func playPitched(base name: String, semitoneOffset: Float, volume: Float = 0.4) {
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
