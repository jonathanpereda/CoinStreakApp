import SwiftUI

struct NameEntryBar: View {
    @ObservedObject var vm: NameEntryVM

    let boxSize: CGSize
    let corner: CGFloat = 8
    let showDebug: Bool

    @FocusState private var isFocused: Bool
    @State private var overlayText: String? = nil   // NEW: reuse “cooldown style” overlay

    var body: some View {
        let boxW = boxSize.width
        let boxH = boxSize.height

        HStack(spacing: boxH * 0.32) {
            ZStack {
                // FIELD
                TextField("", text: $vm.currentName)
                    .textFieldStyle(.plain)
                    .font(.system(size: boxH * 0.60, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.85))
                    .frame(width: boxW, height: boxH)
                    .focused($isFocused)
                    .disabled(!vm.canChange)
                    .opacity(overlayText == nil ? 1 : 0)      // hide name while flashing overlay
                    // Enforce 7-char hard cap + allowed chars
                    .onChange(of: vm.currentName) { _, newVal in
                        // Keep A–Z, a–z, 0–9, space, _ and -
                        let allowed = CharacterSet.alphanumerics
                            .union(.init(charactersIn: " _-"))

                        // filter disallowed
                        let filtered = newVal.unicodeScalars.filter { allowed.contains($0) }
                        var s = String(String.UnicodeScalarView(filtered))

                        // collapse multiple spaces to one
                        s = s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

                        // trim leading/trailing spaces
                        s = s.trimmingCharacters(in: .whitespaces)

                        // clamp to 7 chars
                        s = String(s.prefix(7))

                        if s != newVal { vm.currentName = s }
                    }


                // GLASS when locked
                if !vm.canChange {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.10))
                        .frame(width: boxW, height: boxH)
                }

                // OVERLAY (cooldown OR error messages)
                if let msg = overlayText {
                    Text(msg)
                        .font(.system(size: boxH * 0.60, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                        .frame(width: boxW, height: boxH)
                        .transition(.opacity)
                }

                // Tap when locked → show cooldown
                if !vm.canChange && overlayText == nil {
                    Rectangle().fill(Color.clear)
                        .frame(width: boxW, height: boxH)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            flashOverlay("Cooldown: \(vm.cooldownMinutesRounded) min")
                        }
                }
            }
            .frame(width: boxW, height: boxH)
            .simultaneousGesture(                       // keep the force-focus you added
                TapGesture().onEnded { if vm.canChange { isFocused = true } }
            )

            // SAVE (only while editing & changed & valid)
            if isFocused && vm.canChange && saveEnabled {
                Button {
                    Task { await handleSaveTapped() }    // NEW
                } label: {
                    Text("Save")
                        .font(.system(size: boxH * 0.46, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, boxH * 0.45)
                        .frame(height: boxH)
                        .background(
                            (showDebug ? Color.blue.opacity(0.35) : Color.clear)
                                .background(.ultraThinMaterial.opacity(0.35))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: corner))
                        .overlay(
                            RoundedRectangle(cornerRadius: corner)
                                .stroke(.white.opacity(0.22), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isFocused)
        .animation(.easeInOut(duration: 0.18), value: vm.canChange)
        .animation(.easeInOut(duration: 0.18), value: overlayText)
    }

    // Computed: when to show Save
    private var saveEnabled: Bool {
        let trimmed = vm.currentName.trimmingCharacters(in: .whitespaces)
        return vm.prevalidate(trimmed) && trimmed != vm.displayName
    }

    // Handle save with overlayed error feedback
    @MainActor
    private func handleSaveTapped() async {
        let result = await vm.submitName()
        switch result {
        case .success:
            isFocused = false
            overlayText = nil

        case .failure(let err):
            isFocused = false
            switch err {
            case .taken:
                flashOverlay("Name already taken")
            case .invalidLocal:
                flashOverlay("Invalid name")
            case .cooldown:
                flashOverlay("Cooldown: \(vm.cooldownMinutesRounded) min")
            case .server:
                flashOverlay("Try again")
            }
            // Clear the attempt back to saved name
            vm.currentName = vm.displayName
        }
    }

    // Shows an overlay for ~2.5s
    private func flashOverlay(_ msg: String) {
        overlayText = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeInOut(duration: 0.18)) { overlayText = nil }
        }
    }
}
