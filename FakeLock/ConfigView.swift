import SwiftUI
import PhotosUI

struct ConfigView: View {
    @EnvironmentObject var engine: LockEngine
    @Environment(\.dismiss) var dismiss
    @State private var selectedPhoto: PhotosPickerItem? = nil

    var body: some View {
        NavigationStack {
            Form {

                // ── TIME ─────────────────────────────────────────────
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
                } header: { Text("Time Force") } footer: {
                    Text(engine.forceTime
                         ? "Shows \(engine.forcedTimeString) instead of real time."
                         : "Shows real time.")
                }

                // ── BATTERY ───────────────────────────────────────────
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
                } header: { Text("Battery Force") }

                // ── PASSCODE ──────────────────────────────────────────
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
                } header: { Text("Passcode") } footer: {
                    Text("The 4-digit code that auto-types after the volume trigger.")
                }

                // ── AUTO TYPE ─────────────────────────────────────────
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
                } header: { Text("Auto-Type Timing") } footer: {
                    Text("Volume down → waits delay → types each digit → unlocks to home screen.")
                }

                // ── WALLPAPER ─────────────────────────────────────────
                Section {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Choose Wallpaper", systemImage: "photo.on.rectangle")
                    }
                    .onChange(of: selectedPhoto) { item in
                        Task {
                            if let data = try? await item?.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                engine.saveWallpaper(image)
                            }
                        }
                    }
                } header: { Text("Wallpaper") } footer: {
                    Text("Take a screenshot of your real lock screen and use it here for maximum realism.")
                }

                // ── NOTIFICATIONS ─────────────────────────────────────
                Section {
                    ForEach($engine.fakeNotifications) { $notif in
                        NotificationRowView(notif: $notif)
                    }
                    .onDelete { engine.fakeNotifications.remove(atOffsets: $0); engine.save() }
                    .onMove   { engine.fakeNotifications.move(fromOffsets: $0, toOffset: $1); engine.save() }
                    Button(action: {
                        engine.fakeNotifications.append(FakeNotification()); engine.save()
                    }) {
                        Label("Add Notification", systemImage: "plus.circle.fill")
                    }
                } header: { Text("Fake Notifications") } footer: {
                    Text("Max 3 shown. Triple-tap the time on the lock screen to reopen this.")
                }
            }
            .navigationTitle("Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
                ToolbarItem(placement: .navigationBarLeading) { EditButton() }
            }
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
            Stepper("Shown \(notif.minutesAgo == 0 ? "now" : "\(notif.minutesAgo)m ago")",
                    value: $notif.minutesAgo, in: 0...60)
                .onChange(of: notif.minutesAgo) { _ in engine.save() }
        }
        .padding(.vertical, 6)
    }
}
