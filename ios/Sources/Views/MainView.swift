import SwiftUI

struct MainView: View {
    @Bindable var client: NOCClient
    
    @State private var selectedTab: Tab = .dashboard
    
    enum Tab: Int, CaseIterable {
        case dashboard = 0
        case chat = 1
        case autopilot = 2
    }
    
    var body: some View {
        if client.isAuthenticated {
            if client.isBiometricUnlocked || !client.isBiometricsAvailable {
                VStack(spacing: 0) {
                    if let error = client.connectionError {
                        connectionErrorBanner(error)
                    }
                    
                    // Main view router
                    Group {
                        switch selectedTab {
                        case .dashboard:
                            DashboardView(client: client)
                        case .chat:
                            ChatView(client: client)
                        case .autopilot:
                            AutopilotView(client: client)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Metro Solid Tab Bar
                    if !client.isInputFocused {
                        metroTabBar()
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .background(Color.cyberTerminalBg.ignoresSafeArea())
            } else {
                biometricLockScreen()
            }
        } else {
            LoginView(client: client)
        }
    }
    
    private func metroTabBar() -> some View {
        VStack(spacing: 0) {
            // Thin top accent line
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
            
            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    let isActive = selectedTab == tab
                    
                    Button {
                        if selectedTab != tab {
                            HapticManager.shared.selection()
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedTab = tab
                            }
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: iconName(for: tab))
                                .font(.system(size: 18))
                                .foregroundColor(isActive ? .white : Color.white.opacity(0.35))
                            
                            Text(tabTitle(for: tab))
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1)
                                .foregroundColor(isActive ? .white : Color.white.opacity(0.35))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(isActive ? Color.white.opacity(0.03) : Color.clear)
                        .overlay(alignment: .bottom) {
                            if isActive {
                                Rectangle()
                                    .fill(Color.cyberBlue)
                                    .frame(height: 3)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color.cyberTerminalBg)
        }
    }
    
    private func iconName(for tab: Tab) -> String {
        switch tab {
        case .dashboard: return "cpu"
        case .chat: return "message"
        case .autopilot: return "bolt.shield"
        }
    }
    
    private func tabTitle(for tab: Tab) -> String {
        switch tab {
        case .dashboard: return "DASHBOARD"
        case .chat: return "INTELLIGENCE"
        case .autopilot: return "RECOVERY"
        }
    }
    
    private func biometricLockScreen() -> some View {
        ZStack {
            Color.cyberTerminalBg.ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Oversized Title Block
                VStack(alignment: .leading, spacing: 4) {
                    Text("P3 CONSOLE")
                        .font(.system(size: 56, weight: .light))
                        .tracking(-2)
                        .foregroundColor(.white)
                    
                    Text("PROTOCOL LOCK")
                        .font(.system(size: 20, weight: .semibold))
                        .tracking(3)
                        .foregroundColor(.cyberBlue)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 32)
                
                // Information box
                VStack(alignment: .leading, spacing: 12) {
                    Text("BIOMETRIC ACCESS AUTHENTICATION REQUIRED")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .foregroundColor(Color.white.opacity(0.35))
                    
                    Text("Operator verification needed to mount the node decryption keys and bind active session pipes.")
                        .font(.system(size: 13, weight: .light))
                        .foregroundColor(.white)
                        .lineSpacing(4)
                }
                .padding(24)
                .background(Color.cyberGlassBg)
                .border(Color.white.opacity(0.08), width: 1)
                .padding(.horizontal, 32)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 16) {
                    Button {
                        HapticManager.shared.impact(style: .medium)
                        Task {
                            _ = await client.authenticateBiometrics()
                        }
                    } label: {
                        Text("AUTHORIZE CONSOLE BRIDGE")
                            .font(.system(size: 12, weight: .bold))
                            .tracking(1)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.cyberBlue)
                    }
                    
                    Button {
                        HapticManager.shared.impact(style: .heavy)
                        client.logout()
                    } label: {
                        Text("TERMINATE SESSION")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1)
                            .foregroundColor(.cyberRed)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.clear)
                            .border(Color.cyberRed.opacity(0.3), width: 1)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                _ = await client.authenticateBiometrics()
            }
        }
    }

    private func connectionErrorBanner(_ error: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.black)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("CONNECTION WARNING")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundColor(.black)
                
                Text(error.uppercased())
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(.black.opacity(0.8))
                    .lineLimit(2)
            }
            
            Spacer()
            
            Button {
                HapticManager.shared.notification(type: .warning)
                client.logout()
            } label: {
                Text("RESET HOST")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.clear)
                    .border(Color.black, width: 1.5)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.cyberYellow)
    }
}

#Preview {
    MainView(client: NOCClient())
}
