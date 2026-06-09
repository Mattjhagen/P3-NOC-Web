import SwiftUI

@main
struct P3NOCApp: App {
    @State private var client = NOCClient()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            MainView(client: client)
                .preferredColorScheme(.dark)
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        // Reconnect WS if already logged in and active
                        if client.isAuthenticated {
                            client.connectWebSocket()
                        }
                    case .background:
                        // Save resource/battery and close socket connection when app enters background
                        client.disconnectWebSocket()
                        if client.isAuthenticated {
                            client.isBiometricUnlocked = false
                        }
                    case .inactive:
                        // Do not lock or disconnect during temporary system overlays (e.g. FaceID prompt itself)
                        break
                    @unknown default:
                        break
                    }
                }
        }
    }
}
