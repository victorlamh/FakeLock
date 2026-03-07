import SwiftUI

@main
struct FakeLockApp: App {
    @StateObject private var engine = LockEngine()
    @Environment(\.scenePhase) var scenePhase

    var body: some Scene {
        WindowGroup {
            LockScreenView()
                .environmentObject(engine)
                .preferredColorScheme(.dark)
        }
        .onChange(of: scenePhase) { phase in
            // When app returns from background after "unlock", reset to locked
            if phase == .active && engine.lockState == .unlocking {
                engine.lockState = .locked
            }
        }
    }
}
