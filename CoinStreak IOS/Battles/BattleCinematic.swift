import SwiftUI
import AVKit
import AVFoundation

struct BattleVideoCinematic: View {
    let event: BattleRevealEvent
    let meInstallId: String
    var meName: String
    var opponentName: String
    var onDone: () -> Void

    // MARK: Player / lifecycle
    @State private var player: AVPlayer?
    @State private var endObserver: NSObjectProtocol?

    // MARK: Visual phases
    private enum Phase { case vsIntro, swordsEnter, clash, fadeOutIntro, legend, video, done }
    @State private var phase: Phase = .vsIntro
    @State private var introOpacity: Double = 1.0
    @State private var legendOpacity: Double = 0.0
    @State private var swordsProgress: CGFloat = 0.0   // 0 → offscreen, 1 → center

    private var iWon: Bool { event.winnerInstallId == meInstallId }
    private var videoName: String { iWon ? "battle_win_green" : "battle_lose_red" }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Video is underneath; we only start playback after legend fades in
            if let player {
                PlayerLayerView(player: player)        // no transport controls
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            // VS + swords intro (visible during early phases)
            if phase == .vsIntro || phase == .swordsEnter || phase == .clash || phase == .fadeOutIntro {
                VSOverlay(
                    meName: meName.isEmpty ? "You" : meName,
                    opponentName: opponentName,
                    swordsProgress: swordsProgress
                )
                .opacity(introOpacity)
                .transition(.opacity)
                .allowsHitTesting(false)
            }

            // Legend overlay (after intro)
            if phase == .legend || phase == .video {
                LegendOverlay(meName: meName.isEmpty ? "You" : meName,
                              opponentName: opponentName)
                    .opacity(legendOpacity)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .task { await preparePlayer() }            // load AVPlayer + observer (no autoplay)
        .task { await runIntroSequenceAndPlay() }  // drive intro → legend → start video
        .onDisappear { cleanup() }
        .statusBarHidden(true)
    }

    // MARK: - Player prep (no autoplay here)
    private func preparePlayer() async {
        guard let url = Bundle.main.url(forResource: videoName, withExtension: "mp4") else {
            // If the asset is missing, just complete the flow so the UI recovers
            onDone()
            return
        }

        // Light audio config
        try? AVAudioSession.sharedInstance().setCategory(
            .ambient, mode: .moviePlayback, options: [.mixWithOthers]
        )

        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            Task { @MainActor in finish() }
        }

        await MainActor.run {
            let p = AVPlayer(playerItem: item)
            p.preventsDisplaySleepDuringVideoPlayback = true
            p.isMuted = false
            player = p
        }
    }

    // MARK: - Sequence: VS intro → legend → start video
    private func runIntroSequenceAndPlay() async {
        await MainActor.run {
            phase = .vsIntro
            introOpacity = 1.0
            legendOpacity = 0.0
            swordsProgress = 0.0
        }

        // slight settle before movement
        try? await Task.sleep(nanoseconds: 250_000_000)

        // swords slide in
        await MainActor.run {
            phase = .swordsEnter
            withAnimation(.easeOut(duration: 0.35)) {
                swordsProgress = 0.92
            }
        }

        try? await Task.sleep(nanoseconds: 350_000_000)

        // final snap + clash spark (and optional sfx/haptic)
        await MainActor.run {
            phase = .clash
            withAnimation(.easeIn(duration: 0.08)) {
                swordsProgress = 1.0
            }
            // SoundManager.shared.play("sword_clash")   // optional
            // Haptics.shared.heavy()                    // optional
        }

        try? await Task.sleep(nanoseconds: 1200_000_000)

        await MainActor.run {
            phase = .fadeOutIntro
            withAnimation(.easeOut(duration: 0.18)) {
                introOpacity = 0.0
            }
        }

        try? await Task.sleep(nanoseconds: 500_000_000)

        // Legend fades in, then start the video beneath it
        await MainActor.run {
            phase = .legend
            withAnimation(.easeIn(duration: 0.20)) {
                legendOpacity = 1.0
            }
        }

        // start video playback
        await MainActor.run {
            phase = .video
            player?.seek(to: .zero)
            player?.play()
        }
    }

    // MARK: - Finish / cleanup
    @MainActor
    private func finish() {
        // Fade legend out a hair at the end for polish, then complete.
        withAnimation(.easeOut(duration: 0.20)) {
            legendOpacity = 0.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { onDone() }
    }

    private func cleanup() {
        player?.pause()
        player = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
    }
}

// MARK: - VS + Swords overlay

private struct VSOverlay: View {
    let meName: String
    let opponentName: String
    let swordsProgress: CGFloat    // 0 → offscreen, 1 → center

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 24) {
                Spacer().frame(height: 88) // sit below status area

                // Names + VS centered
                HStack(alignment: .firstTextBaseline, spacing: 24) {
                    NameBlock(name: meName, align: .trailing)
                    Text("VS")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundColor(.red)
                    NameBlock(name: opponentName, align: .leading)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 30)

                // Swords row
                ZStack {
                    // Left sword - mirrored
                    Image("clash_sword")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80)
                        .scaleEffect(x: -1, y: 1, anchor: .center)   // mirror horizontally
                        .rotationEffect(.degrees(-35 + 80 * Double(swordsProgress)))
                        .offset(x: -max(0, (1 - swordsProgress)) * geo.size.width * 0.6)

                    // Right sword
                    Image("clash_sword")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80)
                        .rotationEffect(.degrees(35 - 80 * Double(swordsProgress)))
                        .offset(x: max(0, (1 - swordsProgress)) * geo.size.width * 0.6)

                }

                Spacer()
            }
        }
    }
}

private enum AlignSide { case leading, trailing }

private struct NameBlock: View {
    let name: String
    let align: AlignSide
    var body: some View {
        VStack(alignment: align == .leading ? .leading : .trailing, spacing: 6) {
            Text(name)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(maxWidth: 180, alignment: align == .leading ? .leading : .trailing)
        }
    }
}

// MARK: - Legend overlay (centered near top)

private struct LegendOverlay: View {
    let meName: String
    let opponentName: String
    var body: some View {
        VStack {
            Spacer().frame(height: 80)
            HStack(spacing: 30) {
                LegendChip(color: .green, text: meName)
                LegendChip(color: .red, text: opponentName)
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 30)
            Spacer()
        }
    }
}

// MARK: - Transportless AVPlayerLayer wrapper

private final class PlayerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        playerLayer.videoGravity = .resizeAspectFill   // fill; you said you prefer this
        backgroundColor = .black
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

private struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer
    func makeUIView(context: Context) -> PlayerView {
        let v = PlayerView()
        v.playerLayer.player = player
        return v
    }
    func updateUIView(_ uiView: PlayerView, context: Context) {
        uiView.playerLayer.player = player
    }
}

// MARK: - Legend chip

private struct LegendChip: View {
    let color: Color
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 16, height: 16)
                .shadow(radius: 3, y: 1)
            Text(text)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 20)
        .background(.black.opacity(0.45))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 1.5))
    }
}
