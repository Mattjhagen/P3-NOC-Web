import SwiftUI

struct DashboardView: View {
    let client: NOCClient
    @State private var showingChangePasswordSheet = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.cyberTerminalBg.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        
                        // Oversized Header Text Block (like eventtransport.space style)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("SYSTEM")
                                .font(.system(size: 64, weight: .light))
                                .tracking(-3)
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            Text("TELEMETRY STATUS")
                                .font(.system(size: 20, weight: .bold))
                                .tracking(3)
                                .foregroundColor(.cyberBlue)
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                        
                        // Health Metro Banner (Flat Banner Tile)
                        if let status = client.status {
                            healthMetroBanner(score: status.overallHealthScore, statusText: status.overallStatus, uptime: status.uptime)
                        } else {
                            loadingPlaceholderView()
                        }
                        
                        // Node Panels
                        VStack(spacing: 20) {
                            // T310 Local Host Metrics
                            t310Panel()
                            
                            // R510 AI Node Metrics
                            r510Panel()
                            
                            // Processing Queue Metrics
                            queuePanel()
                            
                            // Autopilot Issues List
                            autopilotIssuesPanel()
                        }
                        .padding(.horizontal)
                        
                        Spacer()
                            .frame(height: 100) // Padding for custom floating tab bar
                    }
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 6) {
                        Rectangle()
                            .fill(client.status != nil ? Color.cyberGreen : Color.cyberRed)
                            .frame(width: 8, height: 8)
                        Text("BRIDGE ACTIVE")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1)
                            .foregroundColor(.white)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            HapticManager.shared.impact(style: .medium)
                            showingChangePasswordSheet = true
                        } label: {
                            Image(systemName: "key.fill")
                                .foregroundColor(.cyberBlue)
                        }
                        
                        Button {
                            HapticManager.shared.notification(type: .warning)
                            client.logout()
                        } label: {
                            Image(systemName: "power")
                                .foregroundColor(.cyberRed)
                        }
                    }
                }
            }
            .toolbarBackground(Color.cyberTerminalBg, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showingChangePasswordSheet) {
                ChangePassphraseSheet(client: client)
            }
        }
    }
    
    // --- Helper UI Components ---
    
    private func healthMetroBanner(score: Int, statusText: String, uptime: String) -> some View {
        let healthColor = score > 80 ? Color.cyberGreen : (score > 50 ? Color.cyberYellow : Color.cyberRed)
        
        return HStack(spacing: 0) {
            // Left thick state color strip
            Rectangle()
                .fill(healthColor)
                .frame(width: 8)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(score)")
                        .font(.system(size: 64, weight: .bold))
                        .tracking(-4)
                        .foregroundColor(.white)
                    
                    Text("%")
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(Color.white.opacity(0.5))
                    
                    Spacer()
                    
                    Text(statusText.uppercased())
                        .font(.system(size: 13, weight: .bold))
                        .tracking(1.5)
                        .foregroundColor(healthColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .border(healthColor, width: 1)
                }
                
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
                
                HStack {
                    Text("SYSTEM UPTIME:")
                        .metroLabelStyle()
                    Spacer()
                    Text(uptime.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .padding(20)
            .background(Color.cyberGlassBg)
        }
        .border(Color.white.opacity(0.06), width: 1)
        .padding(.horizontal)
    }
    
    private func loadingPlaceholderView() -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ProgressView()
                .tint(.cyberGreen)
            
            Text("SYNCHRONIZING TELEMETRY BUFFER...")
                .font(.system(size: 11, weight: .bold))
                .tracking(1)
                .foregroundColor(.cyberGreen)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cyberGlassBg)
        .border(Color.white.opacity(0.06), width: 1)
        .padding(.horizontal)
    }
    
    private func t310Panel() -> some View {
        let metrics = client.status?.t310
        let isOnline = metrics?.online ?? false
        
        return VStack(alignment: .leading, spacing: 18) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "server.rack")
                        .foregroundColor(.cyberGreen)
                    Text("DELL T310 HOST")
                        .font(.system(size: 14, weight: .bold))
                        .tracking(1)
                        .foregroundColor(.white)
                }
                Spacer()
                statusPill(text: isOnline ? "ONLINE" : "OFFLINE", isGreen: isOnline)
            }
            
            if let metrics = metrics, isOnline {
                telemetryRow(label: "CPU LOAD", value: String(format: "%.1f%%", metrics.cpuPercent ?? 0.0), percent: metrics.cpuPercent, color: .cyberGreen)
                telemetryRow(label: "RAM UTILIZATION", value: String(format: "%.1f%%", metrics.ramPercent ?? 0.0), percent: metrics.ramPercent, color: .cyberGreen)
                telemetryRow(label: "DISK FOOTPRINT", value: String(format: "%.1f%%", metrics.diskPercent ?? 0.0), percent: metrics.diskPercent, color: .cyberGreen)
                metricDetailsRow(label: "NETWORK SPEED (RX/TX)", value: String(format: "%.1f / %.1f KB/S", metrics.networkRxKbps ?? 0.0, metrics.networkTxKbps ?? 0.0))
                metricDetailsRow(label: "CONTAINER UPTIME", value: metrics.uptime?.uppercased() ?? "N/A")
            } else {
                Text("HOST COMMUNICATIONS INTERRUPTED / OFFLINE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.cyberRed)
            }
        }
        .padding(20)
        .background(Color.cyberGlassBg)
        .border(isOnline ? Color.white.opacity(0.06) : Color.cyberRed.opacity(0.35), width: 1)
    }
    
    private func r510Panel() -> some View {
        let metrics = client.status?.r510
        let isOnline = metrics?.online ?? false
        let isOllamaOnline = metrics?.ollamaStatus == "ONLINE"
        
        return VStack(alignment: .leading, spacing: 18) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.cyberBlue)
                    Text("DELL R510 AI NODE")
                        .font(.system(size: 14, weight: .bold))
                        .tracking(1)
                        .foregroundColor(.white)
                }
                Spacer()
                statusPill(text: isOnline ? "ONLINE" : "OFFLINE", isGreen: isOnline)
            }
            
            if let metrics = metrics, isOnline {
                metricDetailsRow(label: "NETWORK LATENCY", value: String(format: "%.1f MS", metrics.pingLatencyMs ?? 0.0))
                metricDetailsRow(label: "OLLAMA ENGINE", value: metrics.ollamaStatus ?? "OFFLINE", color: isOllamaOnline ? .cyberGreen : .cyberRed)
                metricDetailsRow(label: "LAUNCHED LLM WEIGHTS", value: metrics.activeModel ?? "NONE", color: metrics.activeModel != "None" ? .cyberBlue : .white)
                
                let vramPct = min(((metrics.loadedMemoryGb ?? 0.0) / 12.0) * 100.0, 100.0)
                telemetryRow(label: "VRAM FOOTPRINT", value: String(format: "%.2f / 12.00 GB", metrics.loadedMemoryGb ?? 0.0), percent: vramPct, color: .cyberBlue)
                
                metricDetailsRow(label: "INFERENCE TELEMETRY RTT", value: String(format: "%.1f MS", metrics.responseLatencyMs ?? 0.0))
            } else {
                Text("REMOTE AI NODE CO-PROCESSOR DISCONNECTED")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.cyberRed)
            }
        }
        .padding(20)
        .background(Color.cyberGlassBg)
        .border(isOnline ? Color.white.opacity(0.06) : Color.cyberRed.opacity(0.35), width: 1)
    }
    
    private func queuePanel() -> some View {
        let queue = client.status?.queueCounts
        
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "tray.2")
                    .foregroundColor(.cyberBlue)
                Text("PIPELINE TASK QUEUES")
                    .font(.system(size: 14, weight: .bold))
                    .tracking(1)
                    .foregroundColor(.white)
            }
            
            HStack(spacing: 8) {
                queueBlock(title: "PENDING", count: queue?.pending ?? 0, color: .cyberBlue)
                queueBlock(title: "RUNNING", count: queue?.processing ?? 0, color: .cyberYellow)
                queueBlock(title: "RESOLVED", count: queue?.completed ?? 0, color: .cyberGreen)
                queueBlock(title: "FAILED", count: queue?.failed ?? 0, color: .cyberRed)
            }
        }
        .padding(20)
        .background(Color.cyberGlassBg)
        .border(Color.white.opacity(0.06), width: 1)
    }
    
    private func autopilotIssuesPanel() -> some View {
        let activeIssues = client.status?.activeIssues ?? []
        let autopilotLocked = client.status?.autopilotLocked ?? false
        let safeMode = client.status?.autopilotSafeMode ?? false
        
        let headerColor = autopilotLocked ? Color.cyberRed : (safeMode ? Color.cyberYellow : Color.cyberGreen)
        
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: autopilotLocked ? "lock.shield" : "shield.checkered")
                        .foregroundColor(headerColor)
                    Text("AUTOPILOT CO-PILOT")
                        .font(.system(size: 14, weight: .bold))
                        .tracking(1)
                        .foregroundColor(.white)
                }
                Spacer()
                Text(autopilotLocked ? "LOCKED" : (safeMode ? "SAFE MODE" : "ACTIVE"))
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .foregroundColor(.black)
                    .background(headerColor)
            }
            
            if activeIssues.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.cyberGreen)
                    Text("NO DEVIATION ALERTS IN TELEMETRY LOOPS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.cyberGreen)
                }
                .padding(.vertical, 4)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(activeIssues, id: \.self) { issue in
                        HStack(alignment: .top, spacing: 8) {
                            Text("⚡")
                                .foregroundColor(.cyberYellow)
                            Text("TELEMETRY ALERT: \(issue.uppercased())")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.cyberYellow)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(Color.cyberGlassBg)
        .border(activeIssues.isEmpty ? Color.white.opacity(0.06) : Color.cyberYellow.opacity(0.35), width: 1)
    }
    
    // --- Layout Elements ---
    
    private func statusPill(text: String, isGreen: Bool) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .tracking(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundColor(.black)
            .background(isGreen ? Color.cyberGreen : Color.cyberRed)
    }
    
    private func telemetryRow(label: String, value: String, percent: Double?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.35))
                Spacer()
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
            }
            
            if let pct = percent {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.05))
                            .frame(height: 2)
                        
                        Rectangle()
                            .fill(color)
                            .frame(width: geo.size.width * CGFloat(min(pct, 100.0) / 100.0), height: 2)
                    }
                }
                .frame(height: 2)
            }
        }
    }
    
    private func metricDetailsRow(label: String, value: String, color: Color = .white) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color.white.opacity(0.35))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
        }
    }
    
    private func queueBlock(title: String, count: Int, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 8, weight: .bold))
                .tracking(1)
                .foregroundColor(Color.white.opacity(0.35))
            Text("\(count)")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.black.opacity(0.2))
        .border(Color.white.opacity(0.06), width: 1)
    }
}

// MARK: - Change Passphrase Sheet Overhaul
struct ChangePassphraseSheet: View {
    let client: NOCClient
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var statusMessage: String? = nil
    @State private var isSuccess = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.cyberTerminalBg.ignoresSafeArea()
                
                VStack(spacing: 32) {
                    VStack(spacing: 12) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.cyberBlue)
                        
                        Text("UPDATE SECURE PASSPHRASE")
                            .font(.system(size: 16, weight: .bold))
                            .tracking(1)
                            .foregroundColor(.white)
                    }
                    .padding(.top, 24)
                    
                    if let message = statusMessage {
                        Text("LOG: \(message.uppercased())")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(isSuccess ? .cyberGreen : .cyberRed)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.03))
                            .border(isSuccess ? Color.cyberGreen : Color.cyberRed, width: 1)
                            .padding(.horizontal)
                    }
                    
                    VStack(spacing: 20) {
                        // Current Passphrase
                        VStack(alignment: .leading, spacing: 6) {
                            Text("CURRENT DEC_KEY")
                                .metroLabelStyle()
                            
                            SecureField("Current Passphrase", text: $currentPassword)
                                .font(.system(size: 15))
                                .foregroundColor(.white)
                                .padding(.vertical, 10)
                                .background(Color.clear)
                                .overlay(alignment: .bottom) {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.15))
                                        .frame(height: 2)
                                }
                        }
                        
                        // New Passphrase
                        VStack(alignment: .leading, spacing: 6) {
                            Text("NEW DEC_KEY")
                                .metroLabelStyle()
                            
                            SecureField("New Passphrase", text: $newPassword)
                                .font(.system(size: 15))
                                .foregroundColor(.white)
                                .padding(.vertical, 10)
                                .background(Color.clear)
                                .overlay(alignment: .bottom) {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.15))
                                        .frame(height: 2)
                                }
                        }
                        
                        // Confirm Passphrase
                        VStack(alignment: .leading, spacing: 6) {
                            Text("CONFIRM NEW DEC_KEY")
                                .metroLabelStyle()
                            
                            SecureField("Confirm New Passphrase", text: $confirmPassword)
                                .font(.system(size: 15))
                                .foregroundColor(.white)
                                .padding(.vertical, 10)
                                .background(Color.clear)
                                .overlay(alignment: .bottom) {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.15))
                                        .frame(height: 2)
                                }
                        }
                    }
                    .padding(.horizontal)
                    
                    Button {
                        HapticManager.shared.impact(style: .medium)
                        Task {
                            await performPassphraseUpdate()
                        }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.black)
                                    .padding(.trailing, 8)
                            }
                            Text(isLoading ? "TRANSMITTING..." : "COMMIT KEY UPDATE")
                                .font(.system(size: 12, weight: .bold))
                                .tracking(1)
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isSuccess ? Color.cyberGreen : Color.cyberBlue)
                    }
                    .disabled(isLoading || currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty || isSuccess)
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("ABORT") {
                        HapticManager.shared.impact(style: .light)
                        dismiss()
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gray)
                }
            }
            .toolbarBackground(Color.cyberTerminalBg, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
    
    private func performPassphraseUpdate() async {
        guard newPassword == confirmPassword else {
            statusMessage = "New passphrases mismatch."
            isSuccess = false
            HapticManager.shared.notification(type: .error)
            return
        }
        
        isLoading = true
        statusMessage = nil
        
        do {
            try await client.changePassword(current: currentPassword, new: newPassword)
            isSuccess = true
            statusMessage = "Key committed successfully."
            HapticManager.shared.notification(type: .success)
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            dismiss()
        } catch {
            isSuccess = false
            statusMessage = error.localizedDescription
            HapticManager.shared.notification(type: .error)
        }
        
        isLoading = false
    }
}

#Preview {
    let mock = NOCClient()
    DashboardView(client: mock)
}
