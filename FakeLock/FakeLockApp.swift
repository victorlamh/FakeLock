import SwiftUI

@main
struct FakeLockApp: App {
    @StateObject private var engine = LockEngine()

    var body: some Scene {
        WindowGroup {
            LockScreenView()
                .environmentObject(engine)
                .preferredColorScheme(.dark)
        }
    }
}
