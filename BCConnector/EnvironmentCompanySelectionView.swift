import SwiftUI

struct EnvironmentCompanySelectionView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var settings: SettingsManager
    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var environments: [APIClient.BCEnvironment] = []
    @State private var selectedEnvironment: APIClient.BCEnvironment?

    @State private var companies: [APIClient.Company] = []
    @State private var selectedCompany: APIClient.Company?

    var body: some View {
        NavigationView {
            Form {
                if let message = errorMessage {
                    Section {
                        Text(message)
                            .foregroundColor(.red)
                        Button("Retry") {
                            Task { await loadEnvironments() }
                        }
                    }
                }

                Section(header: Text("Environment")) {
                    if isLoading && environments.isEmpty {
                        ProgressView("Loading environments…")
                    } else if environments.isEmpty {
                        Text("No environments found.")
                            .foregroundColor(.secondary)
                    } else {
                        Picker("Environment", selection: $selectedEnvironment) {
                            ForEach(environments, id: \.self) { env in
                                Text(env.displayName).tag(Optional(env))
                            }
                        }
                        .onChange(of: selectedEnvironment) { _, newValue in
                            if let env = newValue {
                                Task { await environmentChanged(to: env) }
                            }
                        }
                    }
                }

                Section(header: Text("Company")) {
                    if selectedEnvironment == nil {
                        Text("Select an environment first")
                            .foregroundColor(.secondary)
                    } else if isLoading && companies.isEmpty {
                        ProgressView("Loading companies…")
                    } else if companies.isEmpty {
                        Text("No companies found.")
                            .foregroundColor(.secondary)
                    } else {
                        Picker("Company", selection: $selectedCompany) {
                            ForEach(companies, id: \.self) { comp in
                                Text(comp.name).tag(Optional(comp))
                            }
                        }
                    }
                }

                Section {
                    Button("Save Selection") {
                        if let env = selectedEnvironment, let comp = selectedCompany {
                            settings.environment = env.name
                            settings.companyId = comp.id
                            dismiss()
                        }
                    }
                    .disabled(selectedEnvironment == nil || selectedCompany == nil)
                }
            }
            .navigationTitle("Select Workspace")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                await loadEnvironments()
            }
        }
    }

    private func loadEnvironments() async {
        errorMessage = nil
        isLoading = true
        let envs = await APIClient.shared.fetchEnvironments()
        await MainActor.run {
            self.environments = envs
            self.isLoading = false
            if envs.count == 1 {
                self.selectedEnvironment = envs.first
                Task { await environmentChanged(to: envs[0]) }
            }
        }
    }

    private func environmentChanged(to env: APIClient.BCEnvironment) async {
        errorMessage = nil
        isLoading = true
        await MainActor.run { settings.environment = env.name }
        do {
            let comps = try await APIClient.shared.fetchCompanies()
            await MainActor.run {
                self.companies = comps
                self.selectedCompany = comps.first
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.companies = []
                self.selectedCompany = nil
                self.isLoading = false
            }
        }
    }
}

#Preview {
    EnvironmentCompanySelectionView()
        .environmentObject(AuthenticationManager.shared)
        .environmentObject(SettingsManager.shared)
}
