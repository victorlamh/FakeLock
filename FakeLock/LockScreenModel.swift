import Foundation
import UIKit
import AVFoundation

// MARK: - Fake Notification
struct FakeNotification: Identifiable, Codable {
    var id = UUID()
    var appName: String = ""
    var sfSymbol: String = "message.fill"
    var title: String = ""
    var body: String = ""
    var minutesAgo: Int = 5
}

// MARK: - Unlock Trigger
enum UnlockTrigger: String, Codable, CaseIterable {
    case volumeDown = "volumeDown"
    case tripleTap  = "tripleTap"
    case auto       = "auto"

    var label: String {
        switch self {
        case .volumeDown: return "Volume Down button"
        case .tripleTap:  return "Triple tap screen"
        case .auto:       return "Auto (timer)"
        }
    }
}

// MARK: - Volume Observer
class VolumeObserver: NSObject, ObservableObject {
    private let audioSession = AVAudioSession.sharedInstance()
    private var debounceTimer: Timer?
    var onVolumeDown: (() -> Void)?

    override init() {
        super.init()
        try? audioSession.setActive(true)
        audioSession.addObserver(self, forKeyPath: "outputVolume",
                                  options: [.new, .old], context: nil)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                                change: [NSKeyValueChangeKey: Any]?,
                                context: UnsafeMutableRawPointer?) {
        guard keyPath == "outputVolume" else { return }
        let newVol = (change?[.newKey] as? Float) ?? 0
        let oldVol = (change?[.oldKey] as? Float) ?? 0
        guard newVol < oldVol else { return }
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            DispatchQueue.main.async { self?.onVolumeDown?() }
        }
    }

    deinit { audioSession.removeObserver(self, forKeyPath: "outputVolume") }
}

// MARK: - Lock Engine
class LockEngine: ObservableObject {

    // Time
    @Published var forceTime: Bool = false
    @Published var forcedHour: Int = 11
    @Published var forcedMinute: Int = 11

    // Battery
    @Published var forceBattery: Bool = false
    @Published var forcedBattery: Int = 37
    @Published var forcedCharging: Bool = false

    // Notifications
    @Published var fakeNotifications: [FakeNotification] = []

    // Unlock
    @Published var unlockTrigger: UnlockTrigger = .volumeDown
    @Published var autoUnlockDelay: Double = 5.0

    // State — not persisted
    @Published var isUnlocked: Bool = false

    init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        load()
    }

    var forcedTimeString: String {
        String(format: "%d:%02d", forcedHour, forcedMinute)
    }

    func liveTimeString() -> String {
        let cal = Calendar.current
        let now = Date()
        return String(format: "%d:%02d",
                      cal.component(.hour, from: now),
                      cal.component(.minute, from: now))
    }

    func liveDateString() -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE d MMMM"
        f.locale = Locale.current
        return f.string(from: Date()).capitalized
    }

    var displayBattery: Int {
        if forceBattery { return forcedBattery }
        let level = UIDevice.current.batteryLevel
        return level < 0 ? 100 : Int(level * 100)
    }

    var isCharging: Bool {
        if forceBattery { return forcedCharging }
        let s = UIDevice.current.batteryState
        return s == .charging || s == .full
    }

    func unlock() {
        withAnimation(.easeInOut(duration: 0.55)) { isUnlocked = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation(.easeInOut(duration: 0.4)) { self.isUnlocked = false }
        }
    }

    // MARK: Wallpaper
    func saveWallpaper(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.7) else { return }
        let url = wallpaperURL()
        try? data.write(to: url)
    }

    func loadWallpaper() -> UIImage? {
        let url = wallpaperURL()
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    private func wallpaperURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("wallpaper.jpg")
    }

    // MARK: Persist
    func save() {
        let d = UserDefaults.standard
        d.set(forceTime,              forKey: "forceTime")
        d.set(forcedHour,             forKey: "forcedHour")
        d.set(forcedMinute,           forKey: "forcedMinute")
        d.set(forceBattery,           forKey: "forceBattery")
        d.set(forcedBattery,          forKey: "forcedBattery")
        d.set(forcedCharging,         forKey: "forcedCharging")
        d.set(unlockTrigger.rawValue, forKey: "unlockTrigger")
        d.set(autoUnlockDelay,        forKey: "autoUnlockDelay")
        if let data = try? JSONEncoder().encode(fakeNotifications) {
            d.set(data, forKey: "fakeNotifications")
        }
    }

    func load() {
        let d = UserDefaults.standard
        forceTime       = d.bool(forKey: "forceTime")
        forcedHour      = d.object(forKey: "forcedHour")    as? Int ?? 11
        forcedMinute    = d.object(forKey: "forcedMinute")  as? Int ?? 11
        forceBattery    = d.bool(forKey: "forceBattery")
        forcedBattery   = d.object(forKey: "forcedBattery") as? Int ?? 37
        forcedCharging  = d.bool(forKey: "forcedCharging")
        unlockTrigger   = UnlockTrigger(rawValue: d.string(forKey: "unlockTrigger") ?? "volumeDown") ?? .volumeDown
        autoUnlockDelay = d.object(forKey: "autoUnlockDelay") as? Double ?? 5.0
        if let data = d.data(forKey: "fakeNotifications"),
           let decoded = try? JSONDecoder().decode([FakeNotification].self, from: data) {
            fakeNotifications = decoded
        }
    }
}
