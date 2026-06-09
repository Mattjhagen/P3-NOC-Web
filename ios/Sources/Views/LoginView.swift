import SwiftUI

struct LoginView: View {
    @Bindable var client: NOCClient
    
    @State private var username = "admin"
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    
    @FocusState private var focusedField: Field?
    enum Field {
        case host, username, password
    }
    
    @State private var terminalDecryptionPercent: Double = 0.0
    
    var body: some View {
        ZStack {
            Color.cyberTerminalBg.ignoresSafeArea()
            
            // Left border accent strip
            HStack {
                Rectangle()
                    .fill(Color.cyberBlue)
                    .frame(width: 8)
                Spacer()
            }
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Telemetry Header Status Bar
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SECURE CO-PILOT LINK v2.4.0")
                            .font(.system(size: 8, weight: .bold))
                            .tracking(1)
                            .foregroundColor(Color.white.opacity(0.35))
                        Text("DELL_NODE_LINK: ENCRYPTED_SSL")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(Color.cyberBlue.opacity(0.5))
                    }
                    Spacer()
                    Text("SYS_LOC: CLOUD_TUNNEL")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.35))
                }
                .padding(.horizontal, 32)
                .padding(.top, 24)
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 40) {
                    
                    // Brand / Logo (Flat Metro Design)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("P3")
                            .font(.system(size: 80, weight: .light))
                            .tracking(-4)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text("OPERATIONS CENTER")
                            .font(.system(size: 20, weight: .semibold))
                            .tracking(2)
                            .foregroundColor(Color.white.opacity(0.45))
                        
                        Rectangle()
                            .fill(Color.cyberBlue)
                            .frame(width: 140, height: 4)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 32)
                    
                    // Input Form Fields (Clean flat line borders)
                    VStack(spacing: 20) {
                        // Host Address
                        VStack(alignment: .leading, spacing: 6) {
                            Text("HOST ADDRESS")
                                .metroLabelStyle()
                            
                            TextField("Host URL", text: $client.hostUrl)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .font(.system(size: 16, weight: .light))
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .background(Color.clear)
                                .focused($focusedField, equals: .host)
                                .overlay(alignment: .bottom) {
                                    Rectangle()
                                        .fill(focusedField == .host ? Color.cyberBlue : Color.white.opacity(0.15))
                                        .frame(height: 2)
                                }
                        }
                        
                        // Operator ID
                        VStack(alignment: .leading, spacing: 6) {
                            Text("OPERATOR ID")
                                .metroLabelStyle()
                            
                            TextField("Username", text: $username)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .font(.system(size: 16, weight: .light))
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .background(Color.clear)
                                .focused($focusedField, equals: .username)
                                .overlay(alignment: .bottom) {
                                    Rectangle()
                                        .fill(focusedField == .username ? Color.cyberBlue : Color.white.opacity(0.15))
                                        .frame(height: 2)
                                }
                        }
                        
                        // Decrypt Passphrase
                        VStack(alignment: .leading, spacing: 6) {
                            Text("ACCESS DECRYPT PASSPHRASE")
                                .metroLabelStyle()
                            
                            SecureField("Password", text: $password)
                                .font(.system(size: 16, weight: .light))
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .background(Color.clear)
                                .focused($focusedField, equals: .password)
                                .overlay(alignment: .bottom) {
                                    Rectangle()
                                        .fill(focusedField == .password ? Color.cyberBlue : Color.white.opacity(0.15))
                                        .frame(height: 2)
                                }
                        }
                    }
                    .padding(.horizontal, 32)
                    
                    // Error block or Loading bar
                    if isLoading {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                ProgressView()
                                    .tint(.cyberBlue)
                                Text("DECRYPTING CHANNEL: \(Int(terminalDecryptionPercent))%")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.cyberBlue)
                            }
                        }
                        .padding(.horizontal, 32)
                    } else if let errorMessage = errorMessage {
                        Text("ERR: \(errorMessage.uppercased())")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.cyberRed)
                            .padding(.horizontal, 32)
                    }
                    
                    // Establish Console Bridge Button (Sharp borders, flat color)
                    Button {
                        focusedField = nil
                        HapticManager.shared.impact(style: .medium)
                        Task {
                            await performLogin()
                        }
                    } label: {
                        Text(isLoading ? "DECRYPTING..." : "SIGN IN")
                            .font(.system(size: 13, weight: .bold))
                            .tracking(1)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(isLoading ? Color.cyberGreen.opacity(0.5) : Color.cyberGreen)
                    }
                    .disabled(isLoading || password.isEmpty)
                    .padding(.horizontal, 32)
                }
                
                Spacer()
                
                // Footer
                Text("SECURE BRIDGE PROTOCOLS ACTIVE")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.5)
                    .foregroundColor(Color.white.opacity(0.2))
                    .padding(.bottom, 24)
            }
        }
    }
    
    private func performLogin() async {
        isLoading = true
        errorMessage = nil
        terminalDecryptionPercent = 0.0
        
        let steps = 30
        let delayNano = UInt64(1_000_000_000 * 0.4 / Double(steps))
        
        Task {
            for step in 0...steps {
                if !isLoading { break }
                try? await Task.sleep(nanoseconds: delayNano)
                await MainActor.run {
                    terminalDecryptionPercent = (Double(step) / Double(steps)) * 100.0
                    if step % 6 == 0 {
                        HapticManager.shared.impact(style: .light)
                    }
                }
            }
        }
        
        do {
            try await client.login(username: username, password: password)
            HapticManager.shared.notification(type: .success)
        } catch {
            HapticManager.shared.notification(type: .error)
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

#Preview {
    LoginView(client: NOCClient())
}
