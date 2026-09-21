import SwiftUI

struct ContentView: View {
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var manualListenKey: String = ""
    @State private var showManualEntry: Bool = false
    
    @State private var syncManager = WatchSyncManager.shared
    
    var body: some View {
        NavigationStack {
            Form {
                if syncManager.isLoggedIn {
                    loggedInView
                } else {
                    loginView
                }
                
                statusSection
            }
            .navigationTitle("DiWatchFM")
        }
    }
    
    // MARK: - Logged In State View
    
    @ViewBuilder
    private var loggedInView: some View {
        Section(header: Text("Connected Account")) {
            HStack {
                Text("Account")
                    .foregroundColor(.secondary)
                Spacer()
                Text(syncManager.userEmail.isEmpty ? syncManager.currentUsername : syncManager.userEmail)
                    .fontWeight(.medium)
            }
            
            HStack {
                Text("Status")
                    .foregroundColor(.secondary)
                Spacer()
                Text(syncManager.userType.capitalized)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
            }
            
            HStack {
                Text("Listen Key")
                    .foregroundColor(.secondary)
                Spacer()
                Text(maskedListenKey(syncManager.currentListenKey))
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        
        Section {
            Button(action: {
                syncManager.reSync()
            }) {
                HStack {
                    Spacer()
                    Text("Re-sync to Apple Watch")
                        .fontWeight(.semibold)
                    Spacer()
                }
            }
            
            Button(role: .destructive, action: {
                syncManager.logout()
            }) {
                HStack {
                    Spacer()
                    Text("Log Out")
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Login / Setup State View
    
    @ViewBuilder
    private var loginView: some View {
        Section {
            Text("Sign in with your DI.FM credentials. Your Listen Key will be automatically retrieved and synced to your Apple Watch.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        
        Section(header: Text("DI.FM Account")) {
            TextField("Username or Email", text: $username)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .textContentType(.username)
            
            SecureField("Password", text: $password)
                .textContentType(.password)
        }
        
        Section {
            Button(action: handleLoginAndSync) {
                HStack {
                    Spacer()
                    if syncManager.isAuthenticating {
                        ProgressView()
                            .padding(.trailing, 8)
                        Text("Retrieving Listen Key...")
                            .fontWeight(.semibold)
                    } else {
                        Text("Log In & Sync to Watch")
                            .fontWeight(.semibold)
                    }
                    Spacer()
                }
            }
            .disabled(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty || syncManager.isAuthenticating)
        }
        
        Section {
            DisclosureGroup("Manual Listen Key Entry", isExpanded: $showManualEntry) {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Paste Listen Key", text: $manualListenKey)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .font(.system(.body, design: .monospaced))
                    
                    Text("If you prefer not to enter your credentials, paste your DI.FM Listen Key directly.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: handleManualSync) {
                        Text("Sync Key Directly")
                            .fontWeight(.medium)
                    }
                    .disabled(manualListenKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    // MARK: - Status & Error Feedback
    
    @ViewBuilder
    private var statusSection: some View {
        if let error = syncManager.lastSyncError {
            Section {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
        
        if let date = syncManager.lastSyncDate {
            Section {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Synced to Apple Watch at \(date.formatted(date: .omitted, time: .shortened)).")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func handleLoginAndSync() {
        Task {
            _ = await syncManager.authenticateAndSync(username: username, password: password)
        }
    }
    
    private func handleManualSync() {
        let key = manualListenKey.trimmingCharacters(in: .whitespacesAndNewlines)
        KeychainManager.shared.saveListenKey(key)
        syncManager.syncCredentials(listenKey: key)
    }
    
    private func maskedListenKey(_ key: String) -> String {
        guard key.count > 6 else { return key }
        let suffix = key.suffix(4)
        return "••••••••\(suffix)"
    }
}

#Preview {
    ContentView()
}
