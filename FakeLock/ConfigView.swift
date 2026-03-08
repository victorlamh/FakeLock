import SwiftUI
import PhotosUI

struct ConfigView: View {
    @EnvironmentObject var engine: LockEngine
    @EnvironmentObject var cardEngine: CardInputEngine
    @EnvironmentObject var iconStore: AppIconStore
    @Environment(\.dismiss) var dismiss

    @State private var selectedWallpaper: PhotosPickerItem?  = nil
    @State private var selectedHomeScreen: PhotosPickerItem? = nil
    @State private var selectedIcon: PhotosPickerItem?       = nil
    @State private var pendingIconImage: UIImage?            = nil
    @State private var pendingIconName: String               = ""
    @State private var showIconNameAlert: Bool               = false

    var body: some View {
        NavigationStack {
            Form {
                tricksSection
                if engine.acrosticEnabled { cardStatusSection }
                if engine.acrosticEnabled { iconSection }
                statusBarSection
                timeSection
                batterySection
                if engine.passcodeEnabled { passcodeSection }
                if engine.passcodeEnabled { timingSection }
                wallpaperSection
                homeScreenSection
                notificationsSection
            }
            .navigationTitle("Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
                ToolbarItem(placement: .navigationBarLeading) { EditButton() }
            }
            .alert("App Name", isPresented: $showIconNameAlert) {
                TextField("e.g. Facebook", text: $pendingIconName)
                Button("Add") {
                    if let img = pendingIconImage, !pendingIconName.isEmpty {
                        iconStore.addIcon(name: pendingIconName, image: img)
                        pendingIconName  = ""
                        pendingIconImage = nil
                        selectedIcon     = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    pendingIconName  = ""
                    pendingIconImage = nil
                    selectedIcon     = nil
                }
            } message: {
                Text("Enter the app name. The first letter will be used for the acrostic spelling.")
            }
        }
    }

    // MARK: - Sections

    var tricksSection: some View {
        Section {
            Toggle("Passcode trick", isOn: $engine.passcodeEnabled)
                .onChange(of: engine.passcodeEnabled) { _ in engine.save() }
            Toggle("Acrostic card trick", isOn: $engine.acrosticEnabled)
                .onChange(of: engine.acrosticEnabled) { _ in engine.save() }
        } header: {
            Text("Active Tricks")
        } footer: {
            Text("Each trick is fully independent. Enable only what you need for the current session.")
        }
    }

    var cardStatusSection: some View {
        Section {
            if let card = cardEngine.confirmedCard {
                HStack {
                    Text("Armed card")
                    Spacer()
                    Text(card.displayName)
                        .foregroundColor(.green)
                        .fontWeight(.semibold)
                }
                let missing = iconStore.missingLetters(for: card)
                if !missing.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Missing icons for: \(missing.map(String.init).joined(separator: ", "))")
                            .foregroundColor(.orange)
                            .font(.system(size: 13))
                    }
                } else {
                    Label("All letters covered ✓", systemImage: "checkmark.seal.fill")
                        .foregroundColor(.green)
                }
                Button("Clear card") { cardEngine.clearConfirmed() }
                    .foregroundColor(.red)
            } else {
                Text("No card armed yet.")
                    .foregroundColor(.secondary)
                Text("Lock screen: Vol UP (value 1–13) then Vol DOWN (suit 1–4) — wait 2s.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("Card Input Status")
        }
    }

    var iconSection: some View {
        Section {
            ForEach(iconStore.icons) { icon in
                HStack(spacing: 12) {
                    if let img = icon.image {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 40, height: 40)
                            Text(String(icon.letter))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(icon.name).font(.system(size: 15))
                        Text("Letter: \(String(icon.letter))")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 2)
            }
            .onDelete { iconStore.icons.remove(atOffsets: $0); iconStore.save() }

            PhotosPicker(selection: $selectedIcon, matching: .images) {
                Label("Add App Icon", systemImage: "plus.circle.fill")
            }
            .onChange(of: selectedIcon) { item in
                Task {
                    guard let item else { return }
                    if let data  = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            pendingIconImage  = image
                            showIconNameAlert = true
                        }
                    }
                }
            }
        } header: {
            Text("App Icons (\(iconStore.icons.count))")
        } footer: {
            Text("First letter of the name is used for the acrostic. Add one icon per letter needed.")
        }
    }

    var statusBarSection: some View {
        Section {
            HStack {
                Text("Carrier name")
                Spacer()
                TextField("Free", text: $engine.carrierName)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.secondary)
                    .onChange(of: engine.carrierName) { _ in engine.save() }
            }
        } header: {
            Text("Status Bar")
        } footer: {
            Text("Carrier shown top-left (e.g. Free, Orange, SFR).")
        }
    }

    var timeSection: some View {
        Section {
            Toggle("Force time", isOn: $engine.forceTime)
                .onChange(of: engine.forceTime) { _ in engine.save() }
            if engine.forceTime {
                Stepper("Hour: \(engine.forcedHour)",
                        value: $engine.forcedHour, in: 0...23)
                    .onChange(of: engine.forcedHour) { _ in engine.save() }
                Stepper(String(format: "Minute: %02d", engine.forcedMinute),
                        value: $engine.forcedMinute, in: 0...59)
                    .onChange(of: engine.forcedMinute) { _ in engine.save() }
            }
        } header: {
            Text("Time Force")
        } footer: {
            Text(engine.forceTime
                 ? "Displays \(engine.forcedTimeString) instead of real time."
                 : "Displays real time.")
        }
    }

    var batterySection: some View {
        Section {
            Toggle("Force battery", isOn: $engine.forceBattery)
                .onChange(of: engine.forceBattery) { _ in engine.save() }
            if engine.forceBattery {
                Stepper("Level: \(engine.forcedBattery)%",
                        value: $engine.forcedBattery, in: 1...100)
                    .onChange(of: engine.forcedBattery) { _ in engine.save() }
                Toggle("Show as charging", isOn: $engine.forcedCharging)
                    .onChange(of: engine.forcedCharging) { _ in engine.save() }
            }
        } header: {
            Text("Battery Force")
        }
    }

    var passcodeSection: some View {
        Section {
            HStack {
                Text("Code")
                Spacer()
                Text(engine.passcodeDigits.map(String.init).joined())
                    .font(.system(size: 17, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            ForEach(0..<4, id: \.self) { i in
                Stepper("Digit \(i + 1): \(engine.passcodeDigits[i])",
                        value: Binding(
                            get: { engine.passcodeDigits[i] },
                            set: { engine.passcodeDigits[i] = $0; engine.save() }
                        ), in: 0...9)
            }
        } header: {
            Text("Passcode")
        } footer: {
            Text("4-digit code auto-typed when the secret button is tapped on the passcode screen.")
        }
    }

    var timingSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Delay before typing")
                    Spacer()
                    Text("\(String(format: "%.1f", engine.autoTypeDelay))s")
                        .foregroundColor(.secondary).monospacedDigit()
                }
                Slider(value: $engine.autoTypeDelay, in: 0...5, step: 0.5)
                    .tint(.blue)
                    .onChange(of: engine.autoTypeDelay) { _ in engine.save() }
            }
            .padding(.vertical, 4)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Interval between digits")
                    Spacer()
                    Text("\(String(format: "%.1f", engine.digitInterval))s")
                        .foregroundColor(.secondary).monospacedDigit()
                }
                Slider(value: $engine.digitInterval, in: 0.2...1.5, step: 0.1)
                    .tint(.blue)
                    .onChange(of: engine.digitInterval) { _ in engine.save() }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Auto-Type Timing")
        } footer: {
            Text("Secret button tapped → waits delay → types each digit → shows home screen.")
        }
    }

    var wallpaperSection: some View {
        Section {
            PhotosPicker(selection: $selectedWallpaper, matching: .images) {
                Label("Choose Lock Screen Wallpaper", systemImage: "photo.on.rectangle")
            }
            .onChange(of: selectedWallpaper) { item in
                Task {
                    guard let item else { return }
                    if let data  = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run { engine.saveWallpaper(image) }
                    }
                }
            }
            if engine.wallpaperImage != nil {
                HStack {
                    Text("Wallpaper set ✓").foregroundColor(.secondary)
                    Spacer()
                    Button("Remove") {
                        engine.wallpaperImage = nil
                        try? FileManager.default.removeItem(at:
                            FileManager.default
                                .urls(for: .documentDirectory, in: .userDomainMask)[0]
                                .appendingPathComponent("wallpaper.jpg"))
                    }
                    .foregroundColor(.red)
                }
            }
        } header: {
            Text("Lock Screen Wallpaper")
        } footer: {
            Text("Screenshot your real lock screen for maximum realism.")
        }
    }

    var homeScreenSection: some View {
        Section {
            PhotosPicker(selection: $selectedHomeScreen, matching: .images) {
                Label("Choose Home Screen Snapshot", systemImage: "iphone")
            }
            .onChange(of: selectedHomeScreen) { item in
                Task {
                    guard let item else { return }
                    if let data  = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run { engine.saveHomeScreen(image) }
                    }
                }
            }
            if engine.homeScreenImage != nil {
                HStack {
                    Text("Home screen set ✓").foregroundColor(.secondary)
                    Spacer()
                    Button("Remove") {
                        engine.homeScreenImage = nil
                        try? FileManager.default.removeItem(at:
                            FileManager.default
                                .urls(for: .documentDirectory, in: .userDomainMask)[0]
                                .appendingPathComponent("homescreen.jpg"))
                    }
                    .foregroundColor(.red)
                }
            }
        } header: {
            Text("Home Screen")
        } footer: {
            Text("Used as fallback when acrostic trick is off. Screenshot your real home screen.")
        }
    }

    var notificationsSection: some View {
        Section {
            ForEach($engine.fakeNotifications) { $notif in
                NotificationRowView(notif: $notif)
            }
            .onDelete { engine.fakeNotifications.remove(atOffsets: $0); engine.save() }
            .onMove   { engine.fakeNotifications.move(fromOffsets: $0, toOffset: $1); engine.save() }
            Button {
                engine.fakeNotifications.append(FakeNotification())
                engine.save()
            } label: {
                Label("Add Notification", systemImage: "plus.circle.fill")
            }
        } header: {
            Text("Fake Notifications")
        } footer: {
            Text("Max 3 shown. Triple-tap the clock on the lock screen to reopen this.")
        }
    }
}

// MARK: - Notification Row
struct NotificationRowView: View {
    @Binding var notif: FakeNotification
    @EnvironmentObject var engine: LockEngine

    let symbols = ["message.fill", "envelope.fill", "phone.fill", "bell.fill",
                   "heart.fill", "star.fill", "camera.fill", "map.fill", "calendar"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("App name", text: $notif.appName)
                .font(.system(size: 15))
                .onChange(of: notif.appName) { _ in engine.save() }
            Divider()
            Picker("Icon", selection: $notif.sfSymbol) {
                ForEach(symbols, id: \.self) { sym in
                    Label(sym, systemImage: sym).tag(sym)
                }
            }
            .onChange(of: notif.sfSymbol) { _ in engine.save() }
            Divider()
            TextField("Title", text: $notif.title)
                .font(.system(size: 15))
                .onChange(of: notif.title) { _ in engine.save() }
            Divider()
            TextField("Body", text: $notif.body)
                .font(.system(size: 15))
                .onChange(of: notif.body) { _ in engine.save() }
            Divider()
            Stepper(
                "Shown \(notif.minutesAgo == 0 ? "now" : "\(notif.minutesAgo)m ago")",
                value: $notif.minutesAgo, in: 0...60
            )
            .onChange(of: notif.minutesAgo) { _ in engine.save() }
        }
        .padding(.vertical, 6)
    }
}
