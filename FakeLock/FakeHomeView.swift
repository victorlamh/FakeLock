import SwiftUI

struct FakeHomeView: View {
    @EnvironmentObject var engine: LockEngine
    @EnvironmentObject var iconStore: AppIconStore
    @EnvironmentObject var cardEngine: CardInputEngine

    // Grid state
    @State private var grid: [AppIcon?] = []
    @State private var currentTime: String = ""
    @State private var clockTimer: Timer?

    let columns = Array(repeating: GridItem(.flexible(), spacing: 20), count: 4)

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Wallpaper
                if let img = engine.wallpaperImage {
                    Image(uiImage: img).resizable().scaledToFill().ignoresSafeArea()
                } else {
                    LinearGradient(
                        colors: [Color(hex: "0a0e27"), Color(hex: "1a1060"), Color(hex: "0d0d1a")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ).ignoresSafeArea()
                }
                Color.black.opacity(0.25).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Status bar
                    HStack {
                        Text(engine.carrierName)
                            .font(.system(size: 15, weight: .semibold))
                        Spacer()
                        HStack(spacing: 6) {
                            Image(systemName: "cellularbars")
                                .font(.system(size: 16, weight: .semibold))
                            Text("5G")
                                .font(.system(size: 15, weight: .semibold))
                            Image(systemName: engine.isCharging
                                  ? "battery.100percent.bolt" : batteryIcon)
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.top, max(geo.safeAreaInsets.top, 14))

                    // Clock
                    Text(engine.forceTime ? engine.forcedTimeString : currentTime)
                        .font(.system(size: 52, weight: .thin))
                        .foregroundColor(.white)
                        .padding(.top, 20)

                    Spacer()

                    // Icon grid
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(0..<24, id: \.self) { i in
                            if i < grid.count, let icon = grid[i] {
                                AppIconCell(icon: icon)
                            } else {
                                Color.clear.frame(width: 60, height: 60)
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer().frame(height: geo.safeAreaInsets.bottom + 20)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            buildGrid()
            startClock()
        }
        .onDisappear { clockTimer?.invalidate() }
        .onChange(of: cardEngine.confirmedCard) { card in
            buildGrid()
        }
    }

    // MARK: - Grid
    func buildGrid() {
        if let card = cardEngine.confirmedCard {
            grid = AcrosticEngine.buildGrid(card: card, store: iconStore)
        } else {
            // Default: just show all icons shuffled, no spell
            grid = iconStore.icons.shuffled().prefix(24).map { Optional($0) }
            while grid.count < 24 { grid.append(nil) }
        }
    }

    // MARK: - Clock
    func startClock() {
        currentTime = engine.liveTimeString()
        clockTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            currentTime = engine.liveTimeString()
        }
    }

    var batteryIcon: String {
        let b = engine.displayBattery
        if b > 75 { return "battery.100percent" }
        if b > 50 { return "battery.75percent" }
        if b > 25 { return "battery.50percent" }
        if b > 10 { return "battery.25percent" }
        return "battery.0percent"
    }
}

// MARK: - App Icon Cell
struct AppIconCell: View {
    let icon: AppIcon

    var body: some View {
        VStack(spacing: 6) {
            Group {
                if let img = icon.image {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    // Placeholder with first letter
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.gray.opacity(0.4))
                        Text(String(icon.letter))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)

            Text(icon.name)
                .font(.system(size: 11))
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(width: 64)
        }
    }
}
