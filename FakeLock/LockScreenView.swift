import SwiftUI
import MediaPlayer
import AVFoundation

// MARK: - Hex Color
extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        self.init(
            red:   Double((int >> 16) & 0xFF) / 255,
            green: Double((int >> 8)  & 0xFF) / 255,
            blue:  Double(int         & 0xFF) / 255
        )
    }
}

// MARK: - Volume helper
func resetVolumeToMid() {
    let v = MPVolumeView()
    guard let s = v.subviews.first(where: { $0 is UISlider }) as? UISlider else { return }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { s.value = 0.5 }
}

// MARK: - Camera View
struct CameraView: UIViewControllerRepresentable {
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraView
        init(_ parent: CameraView) { self.parent = parent }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.dismiss()
        }
    }
}

// MARK: - Lock Screen View
struct LockScreenView: View {
    @EnvironmentObject var engine: LockEngine
    @StateObject private var volumeObserver = VolumeObserver()

    @State private var currentTime: String = ""
    @State private var currentDate: String = ""
    @State private var clockTimer: Timer?
    @State private var dragOffset: CGFloat = 0
    @State private var tapCount = 0
    @State private var tapTimer: Timer?
    @State private var showConfig = false
    @State private var showCamera = false

    var body: some View {
        GeometryReader { geo in
            ZStack {

                // ── WALLPAPER ─────────────────────────────────────
                wallpaperView.ignoresSafeArea()

                // ── LOCK CONTENT ──────────────────────────────────
                if engine.lockState == .locked {
                    lockContent(geo: geo)
                        .offset(y: dragOffset < 0 ? dragOffset * 0.6 : 0)
                        .opacity(1.0 - Double(max(0, -dragOffset)) / 300)
                }

                // ── PASSCODE OVERLAY ──────────────────────────────
                if engine.lockState == .passcode || engine.lockState == .unlocking {
                    PasscodeView()
                        .environmentObject(engine)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(y: 30)),
                            removal:   .opacity.combined(with: .offset(y: 30))
                        ))
                }

                // ── HOME SCREEN SNAPSHOT — instant, no animation ──
                if engine.showHomeScreen {
                    homeScreenOverlay
                        .ignoresSafeArea()
                        .zIndex(99)
                }
            }
            .animation(.spring(response: 0.42, dampingFraction: 0.88), value: engine.lockState)
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .onAppear {
            startClock()
            setupVolumeObserver()
        }
        .onDisappear { clockTimer?.invalidate() }
        .sheet(isPresented: $showConfig) {
            ConfigView().environmentObject(engine)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView()
        }
    }

    // MARK: - Wallpaper
    @ViewBuilder var wallpaperView: some View {
        if let img = engine.wallpaperImage {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
        } else {
            LinearGradient(
                colors: [Color(hex: "0a0e27"), Color(hex: "1a1060"), Color(hex: "0d0d1a")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: - Home Screen Overlay
    @ViewBuilder var homeScreenOverlay: some View {
        if let img = engine.homeScreenImage {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
        } else {
            Color.black
        }
    }

    // MARK: - Lock Content
    func lockContent(geo: GeometryProxy) -> some View {
        ZStack {
            if engine.wallpaperImage != nil {
                Color.black.opacity(0.2).ignoresSafeArea()
            }

            VStack(spacing: 0) {

                // Status bar
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 12, weight: .semibold))
                        Image(systemName: "wifi")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Text("\(engine.displayBattery)%")
                            .font(.system(size: 12, weight: .semibold))
                        Image(systemName: engine.isCharging
                              ? "battery.100percent.bolt" : batteryIcon)
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.top, max(geo.safeAreaInsets.top, 14))

                // Push time block to roughly 35% from top
                Spacer().frame(height: geo.size.height * 0.10)

                Image(systemName: "lock.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))

                Spacer().frame(height: 14)

                Text(engine.forceTime ? engine.forcedTimeString : currentTime)
                    .font(.system(size: 82, weight: .thin))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .onTapGesture { handleTripleTap() }

                Text(currentDate)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.top, 4)

                Spacer().frame(height: 36)

                // Notifications
                if !engine.fakeNotifications.isEmpty {
                    VStack(spacing: 10) {
                        ForEach(engine.fakeNotifications.prefix(3)) { notif in
                            NotificationCard(notif: notif)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                Spacer()

                // Face ID hint
                VStack(spacing: 8) {
                    Image(systemName: "faceid")
                        .font(.system(size: 28))
                        .foregroundColor(.white.opacity(0.7))
                    Text("Swipe up to unlock")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer().frame(height: 22)

                // Torch + Camera
                HStack {
                    CornerButton(
                        icon: engine.torchOn ? "flashlight.on.fill" : "flashlight.off.fill"
                    ) { engine.toggleTorch() }
                    Spacer()
                    CornerButton(icon: "camera.fill") { showCamera = true }
                }
                .padding(.horizontal, 46)
                .padding(.bottom, max(geo.safeAreaInsets.bottom, 20) + 10)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 12)
                .onChanged { value in
                    if value.translation.height < 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    let velocity = value.predictedEndTranslation.height
                    if value.translation.height < -70 || velocity < -200 {
                        dragOffset = 0
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                            engine.lockState = .passcode
                        }
                    } else {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.75)) {
                            dragOffset = 0
                        }
                    }
                }
        )
    }

    // MARK: - Helpers
    var batteryIcon: String {
        let b = engine.displayBattery
        if b > 75 { return "battery.100percent" }
        if b > 50 { return "battery.75percent" }
        if b > 25 { return "battery.50percent" }
        if b > 10 { return "battery.25percent" }
        return "battery.0percent"
    }

    func handleTripleTap() {
        tapCount += 1
        tapTimer?.invalidate()
        tapTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { _ in
            if tapCount >= 3 { showConfig = true }
            tapCount = 0
        }
    }

    func startClock() {
        currentTime = engine.liveTimeString()
        currentDate = engine.liveDateString()
        clockTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            currentTime = engine.liveTimeString()
            currentDate = engine.liveDateString()
        }
    }

    func setupVolumeObserver() {
        resetVolumeToMid()
        volumeObserver.onVolumeDown = {
            if engine.lockState == .locked {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                    engine.lockState = .passcode
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + engine.autoTypeDelay) {
                NotificationCenter.default.post(name: .startAutoType, object: nil)
            }
            resetVolumeToMid()
        }
    }
}

// MARK: - Notification Card
struct NotificationCard: View {
    let notif: FakeNotification

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: "3a3a3c"))
                    .frame(width: 36, height: 36)
                Image(systemName: notif.sfSymbol)
                    .font(.system(size: 18))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(notif.appName.isEmpty ? "Messages" : notif.appName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    Text(notif.minutesAgo == 0 ? "now" : "\(notif.minutesAgo)m ago")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }
                if !notif.title.isEmpty {
                    Text(notif.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                if !notif.body.isEmpty {
                    Text(notif.body)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(2)
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(14)
    }
}

// MARK: - Corner Button
struct CornerButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 52, height: 52)
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
        }
    }
}
