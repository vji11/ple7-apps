import SwiftUI

@main
struct PLE7App: App {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var vpnManager = VPNManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(vpnManager)
        }
    }
}
