import SwiftUI

@main
struct BCConnectorApp: App {
    @StateObject private var authManager = AuthenticationManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
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
