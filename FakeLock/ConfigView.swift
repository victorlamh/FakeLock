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
                } header: {
                    Text("Time Force")
                } footer: {
                    Text(engine.forceTime
                         ? "Lock screen will display \(engine.forcedTimeString) instead of real time."
                         : "Lock screen shows real time.")
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
                } header: {
                    Text("Battery Force")
                } footer: {
                    Text(engine.forceBattery
                         ? "Lock screen will display \(engine.forcedBattery)%."
                         : "Lock screen shows real battery level.")
                }

                // ── UNLOCK TRIGGER ────────────────────────────────────
                Section {
                    Picker("Trigger", selection: $engine.unlockTrigger) {
                        ForEach(UnlockTrigger.allCases, id: \.self) { t in
                            Text(t.label).tag(t)
                        }
                    }
                    .onChange(of: engine.unlockTrigger) { _ in engine.save() }

                    if engine.unlockTrigger == .auto {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Delay")
                                Spacer()
                                Text("\(Int(engine.autoUnlockDelay))s")
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }
                            Slider(value: $engine.autoUnlockDelay, in: 1...30, step: 1)
                                .tint(.blue)
                                .onChange(of: engine.autoUnlockDelay) { _ in engine.save() }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Unlock Trigger")
                } footer: {
                    Text("Triple tap the time to open this config at any time.")
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
                } header: {
                    Text("Wallpaper")
                } footer: {
                    Text("Use a screenshot of your real lock screen for maximum realism.")
                }

                // ── NOTIFICATIONS ─────────────────────────────────────
                Section {
                    ForEach($engine.fakeNotifications) { $notif in
                        NotificationRowView(notif: $notif)
                    }
                    .onDelete { engine.fakeNotifications.remove(atOffsets: $0); engine.save() }
                    .onMove   { engine.fakeNotifications.move(fromOffsets: $0, toOffset: $1); engine.save() }

                    Button(action: {
                        engine.fakeNotifications.append(FakeNotification())
                        engine.save()
                    }) {
                        Label("Add Notification", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Fake Notifications")
                } footer: {
                    Text("Shown on lock screen in order. Max 3 displayed.")
                }
            }
            .navigationTitle("Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
        }
    }
}

// MARK: - Notification Row
struct NotificationRowView: View {
    @Binding var notif: FakeNotification
    @EnvironmentObject var engine: LockEngine

    let symbols = ["message.fill", "envelope.fill", "phone.fill",
                   "bell.fill", "heart.fill", "star.fill",
                   "camera.fill", "map.fill", "calendar"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("App name (e.g. Messages)", text: $notif.appName)
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
            TextField("Title (e.g. Sarah)", text: $notif.title)
                .font(.system(size: 15))
                .onChange(of: notif.title) { _ in engine.save() }
            Divider()
            TextField("Body (e.g. Are you coming tonight?)", text: $notif.body)
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
