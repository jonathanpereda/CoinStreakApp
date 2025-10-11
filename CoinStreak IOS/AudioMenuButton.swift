//
//  AudioMenuButton.swift
//  CoinStreak
//
//  Created by Jonathan Pereda on 10/10/25.
//

import SwiftUI
// MARK: - Audio Menu (expanding circle → pill, smooth icon morph, icon-only inner buttons)
struct AudioMenuButton: View {
    @State private var isOpen = false
    @State private var sfxMuted = SoundManager.shared.isSfxMuted
    @State private var musicMuted = SoundManager.shared.isMusicMuted

    private let buttonSize: CGFloat = 38      // diameter of the whole control
    private let iconSize: CGFloat = 18
    private let innerSpacing: CGFloat = 10
    private let verticalPad: CGFloat = 8

    private var closedHeight: CGFloat { buttonSize }
    private var openHeight: CGFloat {
        verticalPad*2 + (buttonSize * 3) + (innerSpacing * 2)
    }
    private var containerWidth: CGFloat { buttonSize }

    var body: some View {
        ZStack(alignment: .top) {
            // One shape that grows: circle → pill
            RoundedRectangle(cornerRadius: containerWidth / 2, style: .continuous)
                .fill(Color.gray.opacity(0.28))
                .overlay(
                    RoundedRectangle(cornerRadius: containerWidth / 2, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
                .frame(width: containerWidth, height: isOpen ? openHeight : closedHeight)
                .animation(.spring(response: 0.28, dampingFraction: 0.88), value: isOpen)

            VStack(spacing: innerSpacing) {
                // Top toggle (gear⇄chevron), no stretch: cross-fade + scale
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) { isOpen.toggle() }
                } label: {
                    ZStack {
                        // keep a fixed circular hit area
                        Circle()
                            .fill(Color.clear)
                            .frame(width: buttonSize, height: buttonSize)
                            .contentShape(Circle())

                        // Two stacked symbols; we animate opacity/scale so there’s no glyph jump
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: iconSize, weight: .semibold))
                            .foregroundColor(.white)
                            .opacity(isOpen ? 0 : 1)
                            .scaleEffect(isOpen ? 0.85 : 1.0)
                            .animation(.easeInOut(duration: 0.16), value: isOpen)

                        Image(systemName: "chevron.up")
                            .font(.system(size: iconSize, weight: .semibold))
                            .foregroundColor(.white)
                            .opacity(isOpen ? 1 : 0)
                            .scaleEffect(isOpen ? 1.0 : 0.85)
                            .animation(.easeInOut(duration: 0.16), value: isOpen)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isOpen ? "Close audio menu" : "Open audio menu")

                if isOpen {
                    // Music (icon-only; no inner circle/shadow)
                    Button {
                        SoundManager.shared.toggleMusicMuted()
                        musicMuted = SoundManager.shared.isMusicMuted
                    } label: {
                        iconOnly(size: buttonSize) {
                            Image(systemName: "music.note")
                                .font(.system(size: iconSize, weight: .semibold))
                                .foregroundColor(.white)
                                .overlay(alignment: .topTrailing) {
                                    if musicMuted {
                                        Image(systemName: "slash.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.red.opacity(0.9))
                                            .offset(x: 6, y: -6)
                                    }
                                }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(musicMuted ? "Music muted" : "Music on")
                    .transition(.move(edge: .top).combined(with: .opacity))

                    // SFX (icon-only; no inner circle/shadow)
                    Button {
                        SoundManager.shared.toggleSfxMuted()
                        sfxMuted = SoundManager.shared.isSfxMuted
                    } label: {
                        iconOnly(size: buttonSize) {
                            Image(systemName: sfxMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.system(size: iconSize, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(sfxMuted ? "Sound effects muted" : "Sound effects on")
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(.vertical, isOpen ? verticalPad : 0)
        }
        .frame(width: containerWidth, height: isOpen ? openHeight : closedHeight, alignment: .top)
        .contentShape(Rectangle())
        .padding(6)
        .onAppear {
            sfxMuted = SoundManager.shared.isSfxMuted
            musicMuted = SoundManager.shared.isMusicMuted
        }
    }

    // MARK: - Helpers

    /// Creates an icon-only tappable area with a circular hit region, no visible bubble.
    @ViewBuilder
    private func iconOnly<Content: View>(size: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Circle().fill(Color.clear).frame(width: size, height: size).contentShape(Circle())
            content()
        }
    }
}





