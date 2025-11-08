import SwiftUI


struct BattleMenuView: View {
    @Binding var isOpen: Bool
    @ObservedObject var vm: BattleMenuVM
    @StateObject private var nameVM = NameEntryVM()
    
    @State private var showRefreshAck = false
    
    @State private var showAcceptConfirm = false
    @State private var confirmTarget: ChallengeDTO? = nil


    // Create overlay state
    @State private var showCreatePanel = false
    @State private var selectedTarget: UserSearchItem? = nil

    // Convenience
    private let designW: CGFloat = 1320
    private let designH: CGFloat = 2868

    // Proportional placement helper
    private func px(_ x: CGFloat, _ W: CGFloat) -> CGFloat { W * (x / designW) }
    private func py(_ y: CGFloat, _ H: CGFloat) -> CGFloat { H * (y / designH) }
    private func pw(_ w: CGFloat, _ W: CGFloat) -> CGFloat { W * (w / designW) }
    private func ph(_ h: CGFloat, _ H: CGFloat) -> CGFloat { H * (h / designH) }

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = geo.size.height

            ZStack {
                // FULL-BLEED BACKGROUND (kills all white gutters)
                Image("battles_menu_background")
                    .resizable()
                    .scaledToFill()
                    .frame(width: W, height: H)
                    .clipped()
                    //.ignoresSafeArea()

                // === TAP TARGETS + DYNAMIC CONTENT (all proportional to 1320x2868) ===
                ZStack {
                    // Exit “X” — baked icon; we add a transparent tap area
                    Button {
                        Haptics.shared.tap()
                        isOpen = false
                    } label: {
                        Color.clear
                        //Color.red.opacity(0.4)
                    }
                    .frame(width: pw(133, W), height: ph(133, H))
                    .contentShape(Rectangle())
                    .position(x: px(100 + 55, W), y: py(80 + 58, H)) // given x,y were top-left; position uses center
                    .accessibilityLabel("Close")
                    
                    Button {
                        Haptics.shared.tap()
                        let id = InstallIdentity.getOrCreateInstallId()
                        Task {
                            vm.isLoading = true
                            defer{
                                vm.isLoading = false
                                showRefreshAck = true
                                Haptics.shared.tap()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                    withAnimation(.easeOut(duration: 0.15)) { showRefreshAck = false }
                                }
                            }
                            await vm.refreshLists(installId: id)
                            await vm.pollForRevealIfNeeded(installId: id)
                        }
                    } label: {
                        Color.red.opacity(0.0) // set to 0.2 while placing, then back to 0.0
                    }
                    .frame(width: pw(133, W), height: ph(133, H))
                    .contentShape(Rectangle())
                    // Mirror of the close button: top-right corner padding matches the close button’s offsets
                    .position(
                        x: W - px(100 + 55, W),
                        y: py(80 + 58, H)
                    )
                    .accessibilityLabel("Refresh")
                    .disabled(vm.isLoading)
                    
                    Group {
                        if vm.isLoading {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.9)
                                .transition(.opacity)
                        } else if showRefreshAck {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.white.opacity(0.6))
                                .shadow(radius: 2, y: 1)
                                .transition(.opacity)
                        }
                    }
                    .position(x: W - px(100 + 55, W), y: py(80 + 58, H))
                    .zIndex(3)

                    

                    // Name field dynamic text (inside baked name box)
                    Group {
                        // Player name text
                        NameEntryBar(vm: nameVM,
                                     boxSize: CGSize(width: pw(900, W) - pw(140, W), height: ph(88, H)),
                                     showDebug: false)
                            .frame(width: pw(773, W) - pw(140, W), height: ph(88, H))
                            .position(
                                x: px(614.5, W),
                                y: py(552, H) + ph(88, H)/2
                            )

                        // Streak badge (number only; “YOU:” is baked)
                        ZStack {
                            Text("\(vm.myStreak)")
                                .font(.system(size: pw(180, W), weight: .bold, design: .rounded))
                                .foregroundColor(streakColor(vm.myStreak))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        //.frame(width: pw(122, W), height: ph(122, H))
                        .position(x: px(1091 + 61, W), y: py(536 + 61, H))
                    }

                    // Sort toggle (“Recent” <-> “Streak”) — baked label space
                    Button {
                        Haptics.shared.tap()
                        vm.sortMode = (vm.sortMode == .recent) ? .highest : .recent
                        let id = InstallIdentity.getOrCreateInstallId()
                        Task { await vm.refreshLists(installId: id) }
                    } label: {
                        Text(vm.sortMode == .recent ? "Recent" : "Streak")
                            .font(.system(size: pw(36, W), weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                            .frame(width: pw(209, W), height: ph(64, H))
                    }
                    .background(Color.clear)
                    .contentShape(Rectangle())
                    .position(x: px(1053 + 209/2, W), y: py(1485 + 64/2, H))

                    // “+” button — baked icon; make it tappable (debug red visible hitbox as requested)
                    Button {
                        Haptics.shared.tap()
                        // Enforce simple limit = 1 for now
                        if vm.outgoing.count >= 1 {
                            vm.createErrorBanner = "Max sent challenges reached."
                        } else {
                            showCreatePanel = true
                            selectedTarget = nil
                            vm.query = ""
                        }
                    } label: {
                        // Toggle between translucent red (debug) and clear if you want to ship
                        Color.red.opacity(0.0) // ← make 0.0 when you’re done positioning
                    }
                    .frame(width: pw(62, W), height: ph(62, H))
                    .contentShape(Rectangle())
                    .position(x: px(1183 + 31, W), y: py(800 + 31, H))
                    .accessibilityLabel("Create battle")

                    // Sent box scroll area (inside the baked rounded rectangle)
                    SentList(outgoing: vm.outgoing, lastResult: vm.lastResult, W: W, H: H) { ch in
                        let myId = InstallIdentity.getOrCreateInstallId()
                        Task { _ = await vm.cancel(installId: myId, challengeId: ch.id) }
                    }
                    .frame(width: pw(1211, W), height: ph(403, H))
                    .clipShape(RoundedRectangle(cornerRadius: pw(60, W), style: .continuous))
                    .position(x: px(54 + 1211/2, W), y: py(882 + 403/2, H))

                    // Requests list (big box)
                    RequestsList(
                        incoming: vm.incoming, W: W, H: H,
                        accept: { ch in
                            Haptics.shared.tap()
                            confirmTarget = ch
                            withAnimation(.easeIn(duration: 0.15)) { showAcceptConfirm = true }
                        },
                        decline: { ch in
                            let myId = InstallIdentity.getOrCreateInstallId()
                            Task { _ = await vm.decline(installId: myId, challengeId: ch.id) }
                        }
                    )
                    .frame(width: W, height: ph(1295, H), alignment: .top)
                    .clipped()
                    .position(x: W/2, y: py(1572 + 1295/2, H))
                }
                .allowsHitTesting(true)

                // Error banner
                if let banner = vm.createErrorBanner {
                    VStack {
                        Text(banner)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black.opacity(0.9))
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.yellow.opacity(0.95))
                            )
                            .shadow(radius: 3, y: 2)
                        Spacer().frame(height: 12)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 80)
                    .transition(.opacity)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation(.easeOut(duration: 0.2)) { vm.createErrorBanner = nil }
                        }
                    }
                    .zIndex(2)
                }

                // Custom CREATE overlay (no Apple default sheet)
                if showCreatePanel {
                    CreateBattleOverlay(
                        vm: vm,
                        isOpen: $showCreatePanel,
                        selected: $selectedTarget
                    )
                    .transition(.opacity)
                    .zIndex(1)
                }
                
                // Accept confirmation overlay
                if showAcceptConfirm, let ch = confirmTarget {
                    AcceptConfirmOverlay(
                        opponentName: ch.challengerName,
                        opponentStreak: ch.challengerStreakCurrent,
                        typeText: "Single flip picks winner",
                        stakeText: "Lose current streak",
                        onCancel: {
                            Haptics.shared.tap()
                            withAnimation(.easeOut(duration: 0.15)) {
                                showAcceptConfirm = false
                            }
                        },
                        onConfirm: {
                            Haptics.shared.tap()
                            let myId = InstallIdentity.getOrCreateInstallId()
                            Task {
                                // Call the real accept only after confirm
                                _ = await vm.accept(installId: myId, challengeId: ch.id)
                                await MainActor.run {
                                    withAnimation(.easeOut(duration: 0.15)) {
                                        showAcceptConfirm = false
                                        confirmTarget = nil
                                    }
                                }
                            }
                        }
                    )
                    .transition(.opacity)
                    .zIndex(10)
                }
            }
        }
        .ignoresSafeArea()              // ensure we never reserve a safe-area gutter
        .ignoresSafeArea(.keyboard)     // don’t jump when the keyboard appears
        .statusBarHidden(true)
        
        .task {
            await nameVM.loadProfile()
            vm.myName = nameVM.displayName   // keep BattleMenuVM in sync on first load
        }
        .onChange(of: nameVM.displayName) {_, new in
            vm.myName = new
        }
        .onAppear {
            // When the Battles menu opens, mark-opened on server and clear the attention locally
            let id = InstallIdentity.getOrCreateInstallId()
            Task { await vm.markOpened(installId: id) }
        }

    }
}

// MARK: - Sent List (compact)
private struct SentList: View {
    let outgoing: [ChallengeDTO]
    let lastResult: (opponentInstallId: String, opponentName: String, outcome: String)?
    let W: CGFloat
    let H: CGFloat
    var onCancel: (ChallengeDTO) -> Void

    init(outgoing: [ChallengeDTO],
         lastResult: (opponentInstallId: String, opponentName: String, outcome: String)?,
         W: CGFloat, H: CGFloat,
         onCancel: @escaping (ChallengeDTO) -> Void) {
        self.outgoing = outgoing
        self.lastResult = lastResult
        self.W = W
        self.H = H
        self.onCancel = onCancel
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 8) {
                if outgoing.isEmpty {
                    Text("No sent challanges")
                        .foregroundColor(.white.opacity(0.75))
                        .font(.system(size: 16, weight: .medium))
                        .padding(.top, 6)
                } else {
                    ForEach(outgoing) { ch in
                        let isPending = (ch.status ?? .pending) == .pending
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ch.targetName)
                                    .lineLimit(1)
                                    .foregroundColor(.white)
                                    .font(.system(size: 16, weight: .semibold))

                                if !isPending {
                                    let badgeText: String = {
                                        switch ch.status ?? .pending {
                                        case .declined: return "DECLINED"
                                        case .accepted:
                                            if let lr = lastResult,
                                               lr.opponentInstallId == ch.installIds.target || lr.opponentName == ch.targetName {
                                                return lr.outcome // "WON" or "LOST"
                                            }
                                            return "RESULT"
                                        default:
                                            return "RESULT"
                                        }
                                    }()
                                    Text(badgeText)
                                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                                        .foregroundColor(.black.opacity(0.85))
                                        .padding(.vertical, 2)
                                        .padding(.horizontal, 6)
                                        .background(Color.yellow.opacity(0.85))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                            }
                            Spacer()
                            HStack{
                                Text("Streak: ")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                Text("\(ch.targetStreakCurrent)")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(streakColor(ch.targetStreakCurrent))
                            }

                            Button(isPending ? "Cancel" : "Dismiss") {
                                onCancel(ch)
                            }
                            .font(.system(size: 14, weight: .bold))
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(Color.white.opacity(isPending ? 0.12 : 0.20))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 48)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
}


// MARK: - Requests List (full)
private struct RequestsList: View {
    let incoming: [ChallengeDTO]
    let W: CGFloat
    let H: CGFloat
    var accept: (ChallengeDTO) -> Void
    var decline: (ChallengeDTO) -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 10) {
                if incoming.isEmpty {
                    Text("No incoming challanges")
                        .foregroundColor(.white.opacity(0.75))
                        .font(.system(size: 18, weight: .medium))
                        .padding(.top, 10)
                } else {
                    ForEach(incoming) { ch in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ch.challengerName)
                                    .foregroundColor(.white)
                                    .font(.system(size: 18, weight: .semibold))
                                    .lineLimit(1)
                                HStack{
                                    Text("Streak: ")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text("\(ch.challengerStreakCurrent)")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(streakColor(ch.challengerStreakCurrent))
                                }
                            }
                            Spacer()
                            Button("Decline") {
                                decline(ch)
                            }
                            .font(.system(size: 14, weight: .bold))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.white.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                            Button("Accept") {
                                accept(ch)
                            }
                            .font(.system(size: 14, weight: .bold))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.white.opacity(0.25))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 56)
                    }
                }
            }
            .padding(.vertical, 10)
        }
    }
}

// MARK: - Custom Create Overlay
private struct CreateBattleOverlay: View {
    @ObservedObject var vm: BattleMenuVM
    @Binding var isOpen: Bool
    @Binding var selected: UserSearchItem?
    
    @FocusState private var searchFocused: Bool

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = geo.size.height

            ZStack {
                // Dim the world
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if searchFocused { searchFocused = false }   // tap out of keyboard
                        else { isOpen = false }                       // (optional) tap-out to close panel
                    }

                // Panel
                VStack(spacing: 14) {
                    // Title
                    Text("Create Battle")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    // Search
                    HStack(spacing: 8) {
                        TextField("Search username to battle…", text: $vm.query)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .submitLabel(.done)               // return key says “Done”
                            .focused($searchFocused)          // ← bind focus
                            .onSubmit { searchFocused = false } // hide on Return
                            .padding(.horizontal, 12)
                            .frame(height: 40)
                            .background(Color.white.opacity(0.38))
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        if vm.isSearching {
                            ProgressView().tint(.white)
                        }
                    }

                    // Results
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(vm.searchResults) { user in
                                Button {
                                    selected = user
                                    searchFocused = false
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(user.displayName)
                                                .foregroundColor(.white)
                                                .font(.system(size: 16, weight: .semibold))
                                                .lineLimit(1)
                                            /*Text(user.installId)
                                                .foregroundColor(.white.opacity(0.5))
                                                .font(.system(size: 12, weight: .regular))
                                                .lineLimit(1)*/
                                        }
                                        Spacer()
                                        Text("\(user.currentStreak)")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(streakColor(user.currentStreak))
                                            //.background(.white.opacity(0.2))
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 10)
                                            //.clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    .padding(10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10).fill(
                                            (selected?.installId == user.installId)
                                            ? Color.blue.opacity(0.48)
                                            : Color.white.opacity(0.10)
                                        )
                                    )
                                }
                            }
                            if vm.searchResults.isEmpty && !vm.query.isEmpty && !vm.isSearching {
                                Text("No users found.")
                                    .foregroundColor(.white.opacity(0.7))
                                    .padding(.top, 8)
                            }
                        }
                    }
                    .frame(height: min(260, H * 0.32))
                    .scrollDismissesKeyboard(.immediately)

                    // Type / Stake (static for now)
                    VStack(spacing: 6) {
                        HStack {
                            Text("Type:")
                                .foregroundColor(.white.opacity(0.75))
                            Text("Single flip picks winner")
                                .foregroundColor(.white)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        HStack {
                            Text("Stake:")
                                .foregroundColor(.white.opacity(0.75))
                            Text("Lose current streak")
                                .foregroundColor(.white)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .font(.system(size: 14))

                    // Buttons
                    HStack {
                        Button("Cancel") { isOpen = false }
                            .font(.system(size: 16, weight: .bold))
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(Color.white.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        Button("Confirm") {
                            guard let target = selected else { return }
                            let myId = InstallIdentity.getOrCreateInstallId()
                            Task {
                                searchFocused = false
                                let ok = await vm.create(installId: myId, targetInstallId: target.installId)
                                if ok { isOpen = false }
                            }
                        }
                        .font(.system(size: 16, weight: .bold))
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.25))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .disabled(selected == nil)
                        .opacity(selected == nil ? 0.6 : 1.0)
                    }
                }
                .padding(16)
                .frame(width: min(520, W * 0.92))
                .background(.ultraThinMaterial.opacity(0.92))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20).strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(radius: 12)
            }
            .ignoresSafeArea(.keyboard)
        }
    }
}

// MARK: ACCEPT CONFIRMATION

private struct AcceptConfirmOverlay: View {
    var opponentName: String?
    var opponentStreak: Int
    let typeText: String
    let stakeText: String
    var onCancel: () -> Void
    var onConfirm: () -> Void

    @State private var appear = false

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let panelW = min(520, W * 0.92)

            ZStack {
                // Dim background
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { onCancel() }

                // Panel
                VStack(spacing: 14) {
                    Text("Are you sure?")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundColor(.white)

                    if let name = opponentName, !name.isEmpty {
                        HStack{
                            Text("\(name) ")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white.opacity(0.9))
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .padding(.bottom, 4)
                            Text("\(opponentStreak) ")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(streakColor(opponentStreak))
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .padding(.bottom, 4)
                            Text("challenges you to:")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .padding(.bottom, 4)
                        }
                    }

                    VStack(spacing: 8) {
                        HStack {
                            Text("Type:")
                                .foregroundColor(.white.opacity(0.75))
                            Text(typeText)
                                .foregroundColor(.white)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        HStack {
                            Text("Stake:")
                                .foregroundColor(.white.opacity(0.75))
                            Text(stakeText)
                                .foregroundColor(.white)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .font(.system(size: 14))

                    HStack(spacing: 10) {
                        Button("Cancel") { onCancel() }
                            .font(.system(size: 16, weight: .bold))
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(Color.white.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        Button("Accept") { onConfirm() }
                            .font(.system(size: 16, weight: .bold))
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(Color.white.opacity(0.25))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(16)
                .frame(width: panelW)
                .background(.ultraThinMaterial.opacity(0.95))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(radius: 12)
                .opacity(appear ? 1 : 0)
                .scaleEffect(appear ? 1 : 0.97)
                .onAppear {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                        appear = true
                    }
                }
            }
        }
        .ignoresSafeArea(.keyboard)
    }
}
