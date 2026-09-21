import SwiftUI

struct SettingsView: View {
    @Bindable var player = WatchAudioPlayer.shared
    @State private var username = KeychainManager.shared.currentUsername
    @State private var password = KeychainManager.shared.currentPassword
    @State private var listenKey = KeychainManager.shared.currentListenKey
    @State private var isPasswordVisible = false
    @State private var statusMessage: String?
    @State private var isError = false
    @State private var isAuthenticating = false
    
    var body: some View {
        Form {
            Section(
                header: Text("Stream Quality"),
                footer: Text(player.currentQuality.description)
            ) {
                Picker("Bitrate", selection: Binding(
                    get: { player.currentQuality },
                    set: { newQuality in
                        player.setAudioQuality(newQuality)
                    }
                )) {
                    ForEach(AudioQuality.allCases) { quality in
                        Text(quality.title).tag(quality)
                    }
                }
            }
            
            Section(
                header: Text("Listen Key"),
                footer: Text("Only the Listen Key is needed for streaming audio. You can paste your key via iPhone keyboard continuity.")
            ) {
                TextField("Listen Key", text: $listenKey)
                    .font(.system(.footnote, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                
                HStack(spacing: 8) {
                    Button("Save Key") {
                        let trimmed = listenKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            KeychainManager.shared.saveListenKey(trimmed)
                            listenKey = trimmed
                            statusMessage = "Listen key saved."
                            isError = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(listenKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    
                    if !listenKey.isEmpty {
                        Button(action: {
                            listenKey = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            Section(
                header: Text("DI.FM Account"),
                footer: Text("Username & password are required to like/dislike tracks due to DI.FM API session requirements.")
            ) {
                TextField("Username or Email", text: $username)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                
                HStack {
                    if isPasswordVisible {
                        TextField("Password", text: $password)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                    } else {
                        SecureField("Password", text: $password)
                            .textContentType(.password)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                    }
                    
                    Button(action: {
                        isPasswordVisible.toggle()
                    }) {
                        Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                Button(action: authenticate) {
                    if isAuthenticating {
                        ProgressView()
                    } else {
                        Text("Sign In & Fetch Key")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty || isAuthenticating)
            }
            
            if let statusMessage = statusMessage {
                Section {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundColor(isError ? .red : .green)
                }
            }
        }
        .navigationTitle("Settings")
    }
    
    private func authenticate() {
        isAuthenticating = true
        statusMessage = nil
        let trimmedUser = username.trimmingCharacters(in: .whitespacesAndNewlines)
        
        Task {
            do {
                let key = try await AudioAddictAPI.shared.authenticate(username: trimmedUser, password: password)
                await MainActor.run {
                    KeychainManager.shared.saveCredentials(username: trimmedUser, password: password)
                    KeychainManager.shared.saveListenKey(key)
                    listenKey = key
                    statusMessage = "Authenticated! Key updated."
                    isError = false
                    isAuthenticating = false
                }
            } catch {
                await MainActor.run {
                    statusMessage = "Authentication failed. Check credentials."
                    isError = true
                    isAuthenticating = false
                }
            }
        }
    }
}
