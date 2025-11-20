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
    
    @State private var isPresentingAddEnv = false
    @State private var newEnvName: String = ""
    @State private var showRetryAlert = false
    @State private var envPendingRetry: APIClient.BCEnvironment?

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
                        ForEach(environments, id: \.self) { env in
                            Button {
                                selectedEnvironment = env
                                Task { await loadCompanies(for: env) }
                            } label: {
                                HStack {
                                    Text(env.displayName)
                                    Spacer()
                                    if selectedEnvironment?.name == env.name {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                            .foregroundColor(.primary)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    deleteEnvironment(env.name)
                                    Task { await loadEnvironments() }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
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
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(comp.name)
                                        Text(comp.id)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                                .tag(Optional(comp))
                            }
                        }
                    }
                }

                Section {
                    Button("Save Selection") {
                        if let env = selectedEnvironment, let comp = selectedCompany {
                            settings.environment = env.name
                            settings.companyId = comp.id
                            settings.companyName = comp.name
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
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isPresentingAddEnv = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Environment")
                }
            }
            .task {
                await loadEnvironments()
            }
            .alert("No companies found", isPresented: $showRetryAlert) {
                Button("Retry") {
                    if let env = envPendingRetry {
                        Task { await loadCompanies(for: env) }
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("The selected environment may not exist or is temporarily unavailable. Would you like to try again?")
            }
            .sheet(isPresented: $isPresentingAddEnv) {
                NavigationView {
                    Form {
                        Section(header: Text("Environment Name")) {
                            TextField("e.g., Production or Sandbox1", text: $newEnvName)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                        }
                        Section {
                            Button("Add") {
                                addCustomEnvironments(from: newEnvName)
                                newEnvName = ""
                                isPresentingAddEnv = false
                                Task { await loadEnvironments() }
                            }
                            .disabled(newEnvName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            Button("Cancel", role: .cancel) { isPresentingAddEnv = false }
                        }
                    }
                    .navigationTitle("Add Environment")
                }
            }
        }
    }

    private func loadEnvironments() async {
        errorMessage = nil
        isLoading = true
        let discovered = await APIClient.shared.fetchEnvironments()
        let custom = settings.customEnvironments
            .map { APIClient.BCEnvironment(id: $0.lowercased(), name: $0, displayName: $0) }
        // Merge and de-duplicate by lowercase name
        var byKey: [String: APIClient.BCEnvironment] = [:]
        for e in (discovered + custom) { byKey[e.name.lowercased()] = e }
        let hidden = Set(settings.hiddenEnvironments.map { $0.lowercased() })
        let envs = Array(byKey.values)
            .filter { !hidden.contains($0.name.lowercased()) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        await MainActor.run {
            self.environments = envs
            self.isLoading = false
            // Preselect from saved settings if available
            if let savedEnv = settings.environment.isEmpty ? nil : envs.first(where: { $0.name.caseInsensitiveCompare(settings.environment) == .orderedSame }) {
                self.selectedEnvironment = savedEnv
                Task { await loadCompanies(for: savedEnv) }
            } else if envs.count == 1 {
                self.selectedEnvironment = envs.first
                Task { await loadCompanies(for: envs[0]) }
            }
        }
    }

    private func loadCompanies(for env: APIClient.BCEnvironment) async {
        errorMessage = nil
        isLoading = true
        do {
            let comps = try await APIClient.shared.fetchCompanies(inEnvironment: env.name)
            await MainActor.run {
                if comps.isEmpty {
                    self.errorMessage = "No companies found for \(env.name)."
                    self.envPendingRetry = env
                    self.showRetryAlert = true
                    self.companies = []
                    self.selectedCompany = nil
                } else {
                    self.companies = comps
                    if let savedId = settings.companyId.isEmpty ? nil : comps.first(where: { $0.id == settings.companyId }) {
                        self.selectedCompany = savedId
                    } else {
                        self.selectedCompany = comps.first
                    }
                }
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
    
    private func addCustomEnvironments(from input: String) {
        let parts = input
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !parts.isEmpty else { return }
        var lowerSet = Set(settings.customEnvironments.map { $0.lowercased() })
        var merged = settings.customEnvironments
        for p in parts {
            let lower = p.lowercased()
            if !lowerSet.contains(lower) {
                merged.append(p)
                lowerSet.insert(lower)
            }
            // Unhide if previously hidden
            settings.hiddenEnvironments.removeAll { $0.lowercased() == lower }
        }
        settings.customEnvironments = merged
    }

    private func deleteEnvironment(_ name: String) {
        // Remove from custom list if present
        settings.customEnvironments.removeAll { $0.caseInsensitiveCompare(name) == .orderedSame }
        // Add to hidden list so discovered entries are also suppressed
        let lower = name.lowercased()
        if !settings.hiddenEnvironments.contains(where: { $0.lowercased() == lower }) {
            settings.hiddenEnvironments.append(name)
        }
        if let sel = selectedEnvironment, sel.name.caseInsensitiveCompare(name) == .orderedSame {
            selectedEnvironment = nil
            companies = []
            selectedCompany = nil
        }
    }
}

#Preview {
    EnvironmentCompanySelectionView()
        .environmentObject(AuthenticationManager.shared)
        .environmentObject(SettingsManager.shared)
}
