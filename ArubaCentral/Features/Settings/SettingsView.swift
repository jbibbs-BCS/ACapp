import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    @AppStorage("appearance") private var appearanceRaw = "system"
    @State private var showingClientSecret = false
    @State private var credentialsError: String? = nil

    init(apiClient: CentralAPIClientProtocol) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(apiClient: apiClient))
    }

    var body: some View {
        Form {
            accountSection
            notificationsSection
            appearanceSection
            aboutSection
        }
        .navigationTitle("Settings")
        .alert("Error", isPresented: Binding(
            get: { credentialsError != nil },
            set: { if !$0 { credentialsError = nil } }
        )) {
            Button("OK") { credentialsError = nil }
        } message: { Text(credentialsError ?? "") }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        Section {
            TextField("Client ID", text: $viewModel.clientId)
                .textContentType(.username)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            HStack {
                Group {
                    if showingClientSecret {
                        TextField("Client Secret", text: $viewModel.clientSecret)
                    } else {
                        SecureField("Client Secret", text: $viewModel.clientSecret)
                    }
                }
                .textContentType(.password)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

                Button {
                    showingClientSecret.toggle()
                } label: {
                    Image(systemName: showingClientSecret ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showingClientSecret ? "Hide secret" : "Show secret")
            }

            Picker("Region", selection: $viewModel.selectedRegion) {
                ForEach(CentralRegion.all) { region in
                    Text(region.label).tag(region)
                }
            }

            Button("Save Credentials") {
                do {
                    try viewModel.saveCredentials()
                    viewModel.saveRegion()
                } catch let error as SettingsError {
                    credentialsError = error.userMessage
                } catch {
                    credentialsError = "Failed to save credentials."
                }
            }
            .disabled(viewModel.clientId.isEmpty || viewModel.clientSecret.isEmpty)

            testConnectionRow

        } header: {
            Text("Account")
        } footer: {
            Text("Credentials are stored securely in the iOS Keychain.")
        }
    }

    @ViewBuilder
    private var testConnectionRow: some View {
        HStack {
            Button("Test Connection") {
                Task { await viewModel.testConnection() }
            }
            .disabled({
                if case .testing = viewModel.connectionTestResult { return true }
                return false
            }())

            Spacer()

            switch viewModel.connectionTestResult {
            case .idle:
                EmptyView()
            case .testing:
                ProgressView().controlSize(.small)
            case .success(let expiry):
                VStack(alignment: .trailing, spacing: 2) {
                    Label("Connected", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption.bold())
                    Text("Token valid until \(expiry.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            case .failure(let error):
                Label(error.userMessage, systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        Section {
            Toggle("Critical", isOn: $viewModel.notificationPrefs.critical)
                .onChange(of: viewModel.notificationPrefs.critical) { _ in viewModel.saveNotificationPrefs() }
            Toggle("Major", isOn: $viewModel.notificationPrefs.major)
                .onChange(of: viewModel.notificationPrefs.major) { _ in viewModel.saveNotificationPrefs() }
            Toggle("Minor", isOn: $viewModel.notificationPrefs.minor)
                .onChange(of: viewModel.notificationPrefs.minor) { _ in viewModel.saveNotificationPrefs() }
            Toggle("Info", isOn: $viewModel.notificationPrefs.info)
                .onChange(of: viewModel.notificationPrefs.info) { _ in viewModel.saveNotificationPrefs() }
        } header: {
            Text("Notifications")
        } footer: {
            Text("Choose which alert severities trigger push notifications.")
        }
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: $appearanceRaw) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: appVersion)
            LabeledContent("Build",   value: buildNumber)
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }
}

private extension SettingsError {
    var userMessage: String {
        switch self {
        case .emptyClientId:     return "Client ID cannot be empty."
        case .emptyClientSecret: return "Client Secret cannot be empty."
        }
    }
}
