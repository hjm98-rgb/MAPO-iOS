import SwiftUI

@main
struct MAPOApp: App {
    @StateObject private var auth = AuthStore()
    @AppStorage("mapo.splashDone") private var splashDone = false
    @State private var showSplash: Bool

    init() {
        _showSplash = State(initialValue: !UserDefaults.standard.bool(forKey: "mapo.splashDone"))
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                Color.black.ignoresSafeArea()
                if showSplash {
                    SplashView {
                        splashDone = true
                        withAnimation(.easeInOut(duration: 0.4)) { showSplash = false }
                    }
                } else if auth.isLoggedIn {
                    HomeView()
                } else {
                    LoginGateView()
                }
            }
            .environmentObject(auth)
            .preferredColorScheme(.dark)
        }
    }
}
