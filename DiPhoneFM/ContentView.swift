import SwiftUI

struct ContentView: View {
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var manualListenKey: String = ""
    @State private var showManualEntry: Bool = false
    @State private var copiedAlert: Bool = false
    
    @State private var syncManager = WatchSyncManager.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidGlassBackground()
                
                ScrollView {
                    VStack(spacing: 20) {
                        headerView
                        
                        if syncManager.isLoggedIn {
                            loggedInCard
                        } else {
                            loginCard
                        }
                        
                        watchConnectionCard
                        
                        if let error = syncManager.lastSyncError {
                            errorCard(error)
                        }
                        
                        if let date = syncManager.lastSyncDate {
                            successCard(date)
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("DiWatchFM")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.cyan.opacity(0.4), Color.clear],
                            center: .center,
                            startRadius: 5,
                            endRadius: 35
                        )
                    )
                    .frame(width: 70, height: 70)
                
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.cyan, Color(red: 0.5, green: 0.2, blue: 0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.cyan.opacity(0.5), radius: 10)
            }
            .padding(.top, 6)
            
            Text("DI.FM Apple Watch Companion")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.bottom, 6)
    }
    
    // MARK: - Logged In Card
    
    private var loggedInCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("Connected Account", systemImage: "person.crop.circle.fill")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
                Text(syncManager.userType.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.green.opacity(0.2))
                            .overlay(Capsule().stroke(Color.green.opacity(0.4), lineWidth: 1))
                    )
                    .foregroundColor(.green)
            }
            
            VStack(spacing: 12) {
                HStack {
                    Text("Account")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Text(syncManager.userEmail.isEmpty ? syncManager.currentUsername : syncManager.userEmail)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                }
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Listen Key")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.6))
                        Text(maskedListenKey(syncManager.currentListenKey))
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    Spacer()
                    Button {
                        UIPasteboard.general.string = syncManager.currentListenKey
                        withAnimation {
                            copiedAlert = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                copiedAlert = false
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: copiedAlert ? "checkmark" : "doc.on.doc")
                            Text(copiedAlert ? "Copied" : "Copy")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                                .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                        )
                        .foregroundColor(copiedAlert ? .green : .white)
                    }
                }
            }
            
            VStack(spacing: 10) {
                Button(action: {
                    syncManager.reSync()
                }) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Re-sync to Apple Watch")
                    }
                }
                .buttonStyle(LiquidGlassButtonStyle(isProminent: true))
                
                Button(action: {
                    syncManager.logout()
                }) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Log Out")
                    }
                }
                .buttonStyle(LiquidGlassButtonStyle(isProminent: false, isDestructive: true))
            }
        }
        .padding(20)
        .liquidGlassCard(cornerRadius: 24)
    }
    
    // MARK: - Login Card
    
    private var loginCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sign In with DI.FM")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Your Listen Key and member session will be retrieved and beamed directly to your Apple Watch.")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            VStack(spacing: 12) {
                // Username field
                HStack {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(.cyan.opacity(0.8))
                        .frame(width: 20)
                    TextField("Username or Email", text: $username)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .textContentType(.username)
                        .foregroundColor(.white)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.15), lineWidth: 1))
                )
                
                // Password field
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.cyan.opacity(0.8))
                        .frame(width: 20)
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .foregroundColor(.white)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.15), lineWidth: 1))
                )
            }
            
            Button(action: handleLoginAndSync) {
                HStack(spacing: 8) {
                    if syncManager.isAuthenticating {
                        ProgressView()
                            .tint(.white)
                        Text("Retrieving Listen Key...")
                    } else {
                        Image(systemName: "bolt.fill")
                        Text("Log In & Sync to Watch")
                    }
                }
            }
            .buttonStyle(LiquidGlassButtonStyle(isProminent: true))
            .disabled(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty || syncManager.isAuthenticating)
            
            // Manual entry toggle
            DisclosureGroup(
                isExpanded: $showManualEntry,
                content: {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Directly enter or paste your Listen Key:")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        TextField("Paste Listen Key", text: $manualListenKey)
                            .font(.system(size: 13, design: .monospaced))
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.08))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.15), lineWidth: 1))
                            )
                            .foregroundColor(.white)
                        
                        Button("Sync Key Directly") {
                            handleManualSync()
                        }
                        .buttonStyle(LiquidGlassButtonStyle(isProminent: false))
                        .disabled(manualListenKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.top, 10)
                },
                label: {
                    Text("Manual Listen Key Entry")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.cyan)
                }
            )
        }
        .padding(20)
        .liquidGlassCard(cornerRadius: 24)
    }
    
    // MARK: - Watch Connection Card
    
    private var watchConnectionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Apple Watch Status", systemImage: "applewatch")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
                
                // Live Pulsing LED
                HStack(spacing: 5) {
                    Circle()
                        .fill(syncManager.isWatchAppInstalled ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                        .shadow(color: syncManager.isWatchAppInstalled ? Color.green.opacity(0.8) : Color.orange.opacity(0.8), radius: 4)
                    Text(syncManager.isWatchAppInstalled ? "LINKED" : "UNLINKED")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(syncManager.isWatchAppInstalled ? .green : .orange)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(syncManager.isWatchAppInstalled ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                )
            }
            
            VStack(spacing: 12) {
                connectionRow(
                    title: "Watch Paired",
                    value: syncManager.isPaired ? "Yes" : "No",
                    icon: "link",
                    isGood: syncManager.isPaired
                )
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                connectionRow(
                    title: "Watch App",
                    value: syncManager.isWatchAppInstalled ? "Installed" : "Not Detected",
                    icon: "app.badge.checkmark",
                    isGood: syncManager.isWatchAppInstalled
                )
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                connectionRow(
                    title: "Connection",
                    value: syncManager.isReachable ? "Active & Reachable" : "Background Queue",
                    icon: "antenna.radiowaves.left.and.right",
                    isGood: syncManager.isReachable
                )
            }
            
            if !syncManager.isWatchAppInstalled {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.orange)
                        .font(.system(size: 14))
                    Text("If DiWatchFM is running on your Apple Watch but shows 'Not Detected', open the iPhone 'Watch' app, scroll to the bottom, and verify DiWatchFM is toggled on under 'Installed on Apple Watch'.")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.75))
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.25), lineWidth: 1))
                )
            }
        }
        .padding(20)
        .liquidGlassCard(cornerRadius: 24)
    }
    
    private func connectionRow(title: String, value: String, icon: String, isGood: Bool) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 20)
            Text(title)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(isGood ? .green : (title == "Connection" ? .cyan : .orange))
        }
    }
    
    // MARK: - Feedback Cards
    
    private func errorCard(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .font(.system(size: 20))
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.red.opacity(0.18))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.red.opacity(0.35), lineWidth: 1))
        )
    }
    
    private func successCard(_ date: Date) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 20))
            VStack(alignment: .leading, spacing: 2) {
                Text("Synced to Apple Watch")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Text(date.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.green.opacity(0.18))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.green.opacity(0.35), lineWidth: 1))
        )
    }
    
    // MARK: - Helpers
    
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
        guard key.count > 6 else { return key.isEmpty ? "Not set" : key }
        let suffix = key.suffix(4)
        return "••••••••\(suffix)"
    }
}

#Preview {
    ContentView()
}
