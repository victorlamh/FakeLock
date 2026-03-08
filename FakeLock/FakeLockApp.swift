import SwiftUI
import UIKit

class LockHostingController: UIHostingController<AnyView> {
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { .bottom }
}

class SceneDelegate: NSObject, UIWindowSceneDelegate {
    var window: UIWindow?
    var engine      = LockEngine()
    var cardEngine  = CardInputEngine()
    var iconStore   = AppIconStore()

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let content = RootView()
            .environmentObject(engine)
            .environmentObject(cardEngine)
            .environmentObject(iconStore)
            .preferredColorScheme(.dark)
        let host   = LockHostingController(rootView: AnyView(content))
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = host
        window.makeKeyAndVisible()
        self.window = window
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        if engine.showHomeScreen || engine.lockState == .unlocking {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.engine.resetToLocked()
            }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

@main
struct FakeLockApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup { EmptyView() }
    }
}

// MARK: - Root router
struct RootView: View {
    @EnvironmentObject var engine: LockEngine
    @EnvironmentObject var cardEngine: CardInputEngine

    var body: some View {
        ZStack {
            LockScreenView()
            if engine.showHomeScreen {
                FakeHomeView()
                    .ignoresSafeArea()
                    .zIndex(99)
            }
        }
    }
}
