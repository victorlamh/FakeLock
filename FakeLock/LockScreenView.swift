import SwiftUI
import MediaPlayer
import PhotosUI

// MARK: - Lock Screen
struct LockScreenView: View {
    @EnvironmentObject var engine: LockEngine
    @StateObject private var volumeObserver = VolumeObserver()

    @State private var currentTime: String = ""
    @State private var currentDate: String = ""
    @State private var clockTimer: Timer? = nil
    @State private var autoTimer: Timer? = nil
    @State private var tapCount = 0
    @State private var tapTimer: Timer? = nil
    @State private var showConfig = false
    @State private var wallpaper: UIImage? = nil

    // Unlock animation
    @State private var contentOffset: CGFloat = 0
    @State private var contentOpacity: Double = 1.0

    var body: some View {
        GeometryReader { geo in
            ZStack {

                // ── WALLPAPER ────────────────────────────────────────
                if let img = wallpaper {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                } else {
                    LinearGradient(
                        colors: [Color(hex: "0a0e27"), Color(hex: "1a1060"), Color(hex: "0d0d1a")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                }

                // Dark scrim
                Color.black.opacity(wallpaper != nil ? 0.25 : 0.0)
                    .ignoresSafeArea()

                // ── LOCK SCREEN CONTENT ──────────────────────────────
                VStack(spacing: 0) {

                    // Status bar
                    HStack {
                        // Signal + WiFi
                        HStack(spacing: 5) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 12, weight: .semibold))
                            Image(systemName: "wifi")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        Spacer()
                        // Battery
                        HStack(spacing: 4) {
                            Text("\(engine.displayBattery)%")
                                .font(.system(size: 12, weight: .semibold))
                            Image(systemName: engine.isCharging ? "battery.100percent.bolt" : batteryIcon)
                                .font(.system(size: 13, weight: .semibold))
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.top, geo.safeAreaInsets.top > 0 ? geo.safeAreaInsets.top : 14)

                    Spacer().frame(height: 40)

                    // Large time
                    Text(engine.forceTime ? engine.forcedTimeString : currentTime)
                        .font(.system(size: 88, weight: .thin, design: .default))
                        .foregroundColor(.white)
                        .onTapGesture {
                            handleTripleTap()
                        }

                    // Date
                    Text(currentDate)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.top, 6)

                    Spacer().frame(height: 44)

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

                    // Face ID + swipe hint
                    VStack(spacing: 6) {
                        Image(systemName: "faceid")
                            .font(.system(size: 26))
                            .foregroundColor(.white.opacity(0.7))
                        Text("Swipe up to unlock")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.bottom, 16)

                    // Bottom corners
                    HStack {
                        CornerButton(icon: "flashlight.off.fill")
                        Spacer()
                        CornerButton(icon: "camera.fill")
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, geo.safeAreaInsets.bottom > 0 ? geo.safeAreaInsets.bottom : 20)
                }
                .offset(y: contentOffset)
                .opacity(contentOpacity)

                // ── UNLOCK OVERLAY ───────────────────────────────────
                if engine.isUnlocked {
                    Color.black
                        .ignoresSafeArea()
                        .transition(.opacity)
                }
            }
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .onAppear {
            wallpaper = engine.loadWallpaper()
            startClock()
            setupVolumeObserver()
            if engine.unlockTrigger == .auto {
                startAutoUnlock()
            }
        }
        .onDisappear { teardown() }
        .onChange(of: engine.isUnlocked) { unlocked in
            if unlocked {
                withAnimation(.easeInOut(duration: 0.55)) {
                    contentOffset = -40
                    contentOpacity = 0
                }
            } else {
                contentOffset = 0
                contentOpacity = 1.0
            }
        }
        .sheet(isPresented: $showConfig) {
            ConfigView().environmentObject(engine)
        }
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
        // Triple tap also triggers unlock if set
        if engine.unlockTrigger == .tripleTap && tapCount >= 3 {
            engine.unlock()
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
        volumeObserver.onVolumeDown = {
            guard engine.unlockTrigger == .volumeDown else { return }
            engine.unlock()
            resetVolumeToMid()
        }
    }

    func startAutoUnlock() {
        autoTimer = Timer.scheduledTimer(withTimeInterval: engine.autoUnlockDelay,
                                         repeats: false) { _ in
            engine.unlock()
        }
    }

    func teardown() {
        clockTimer?.invalidate()
        autoTimer?.invalidate()
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

    var body: some View {
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

// MARK: - Volume Reset
private func resetVolumeToMid() {
    let v = MPVolumeView()
    guard let s = v.subviews.first(where: { $0 is UISlider }) as? UISlider else { return }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { s.value = 0.5 }
}
