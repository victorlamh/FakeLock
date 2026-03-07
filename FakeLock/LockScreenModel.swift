import Foundation
import SwiftUI
import UIKit
import AVFoundation

// MARK: - Lock State
enum LockState: Equatable {
    case locked
    case passcode
    case unlocking
}

// MARK: - Fake Notification
struct FakeNotification: Identifiable, Codable {
    var id = UUID()
    var appName: String = ""
    var sfSymbol: String = "message.fill"
    var title: String = ""
    var body: String = ""
    var minutesAgo: Int = 5
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

    @Published var lockState: LockState = .locked

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

    // Passcode — 4 digits
    @Published var passcodeDigits: [Int] = [1, 2, 3, 4]
    @Published var autoTypeDelay: Double = 1.5   // delay after volume press before typing starts
    @Published var digitInterval: Double = 0.5   // time between each digit

    // Torch
    @Published var torchOn: Bool = false

    init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        load()
    }

    // MARK: Time
    var forcedTimeString: String {
        String(format: "%d:%02d", forcedHour, forcedMinute)
    }

    func liveTimeString() -> String {
        let c = Calendar.current; let n = Date()
        return String(format: "%d:%02d", c.component(.hour, from: n), c.component(.minute, from: n))
    }

    func liveDateString() -> String {
        let f = DateFormatter(); f.dateFormat = "EEEE d MMMM"; f.locale = Locale.current
        return f.string(from: Date()).capitalized
    }

    // MARK: Battery
    var displayBattery: Int {
        if forceBattery { return forcedBattery }
        let l = UIDevice.current.batteryLevel
        return l < 0 ? 100 : Int(l * 100)
    }

    var isCharging: Bool {
        if forceBattery { return forcedCharging }
        let s = UIDevice.current.batteryState
        return s == .charging || s == .full
    }

    // MARK: Torch
    func toggleTorch() {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }
        try? device.lockForConfiguration()
        torchOn.toggle()
        device.torchMode = torchOn ? .on : .off
        device.unlockForConfiguration()
    }

    // MARK: Unlock → real home screen
    func performUnlock() {
        lockState = .unlocking
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
            // Reset after returning to app
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.lockState = .locked
            }
        }
    }

    // MARK: Wallpaper
    func saveWallpaper(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return }
        try? data.write(to: wallpaperURL())
    }

    func loadWallpaper() -> UIImage? {
        guard let data = try? Data(contentsOf: wallpaperURL()) else { return nil }
        return UIImage(data: data)
    }

    private func wallpaperURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("wallpaper.jpg")
    }

    // MARK: Persist
    func save() {
        let d = UserDefaults.standard
        d.set(forceTime,       forKey: "forceTime")
        d.set(forcedHour,      forKey: "forcedHour")
        d.set(forcedMinute,    forKey: "forcedMinute")
        d.set(forceBattery,    forKey: "forceBattery")
        d.set(forcedBattery,   forKey: "forcedBattery")
        d.set(forcedCharging,  forKey: "forcedCharging")
        d.set(autoTypeDelay,   forKey: "autoTypeDelay")
        d.set(digitInterval,   forKey: "digitInterval")
        d.set(passcodeDigits,  forKey: "passcodeDigits")
        if let data = try? JSONEncoder().encode(fakeNotifications) {
            d.set(data, forKey: "fakeNotifications")
        }
    }

    func load() {
        let d = UserDefaults.standard
        forceTime      = d.bool(forKey: "forceTime")
        forcedHour     = d.object(forKey: "forcedHour")   as? Int ?? 11
        forcedMinute   = d.object(forKey: "forcedMinute") as? Int ?? 11
        forceBattery   = d.bool(forKey: "forceBattery")
        forcedBattery  = d.object(forKey: "forcedBattery") as? Int ?? 37
        forcedCharging = d.bool(forKey: "forcedCharging")
        autoTypeDelay  = d.object(forKey: "autoTypeDelay") as? Double ?? 1.5
        digitInterval  = d.object(forKey: "digitInterval") as? Double ?? 0.5
        passcodeDigits = d.array(forKey: "passcodeDigits") as? [Int] ?? [1, 2, 3, 4]
        if let data = d.data(forKey: "fakeNotifications"),
           let decoded = try? JSONDecoder().decode([FakeNotification].self, from: data) {
            fakeNotifications = decoded
        }
    }
}
