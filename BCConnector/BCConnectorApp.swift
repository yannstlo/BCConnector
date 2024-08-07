import SwiftUI

@main
struct BCConnectorApp: App {
    @StateObject private var authManager: AuthenticationManager = AuthenticationManager.shared
    @StateObject private var settingsManager = SettingsManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(settingsManager)
                .onOpenURL { url in
                    Task {
                        await handleURL(url)
                    }
                }
        }
    }
    
    private func handleURL(_ url: URL) async {
        do {
            try await authManager.handleRedirect(url: url)
        } catch {
            print("Error handling redirect: \(error)")
        }
    }
}
