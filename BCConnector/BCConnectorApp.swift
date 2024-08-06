import SwiftUI

@main
struct BCConnectorApp: App {
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var settingsManager = SettingsManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
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
