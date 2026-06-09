import SwiftUI

struct AutopilotView: View {
    let client: NOCClient
    
    @State private var isExecutingAction = false
    @State private var actionMessage: String? = nil
    
    // Log filter
    @State private var selectedLogFilter: LogFilter = .all
    enum LogFilter {
        case all, critical, warning
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.cyberTerminalBg.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        
                        // Oversized Header Text Block
                        VStack(alignment: .leading, spacing: 2) {
                            Text("RECOVERY")
                                .font(.system(size: 64, weight: .light))
                                .tracking(-3)
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            Text("SELF-HEALING CONTROL")
                                .font(.system(size: 20, weight: .bold))
                                .tracking(3)
                                .foregroundColor(.cyberBlue)
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                        
                        // Autopilot Circuit Breaker Status
                        autopilotStatusCard()
                            .padding(.horizontal)
                        
                        // Manual Recovery Triggers
                        recoveryTriggersCard()
                            .padding(.horizontal)
                        
                        // Operations Log Console
                        consoleLogsCard()
                            .padding(.horizontal)
                        
                        Spacer()
                            .frame(height: 100) // Padding for custom floating tab bar
                    }
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticManager.shared.impact(style: .medium)
                        Task {
                            await client.fetchOperationsLogs()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.cyberGreen)
                    }
                }
            }
            .onAppear {
                Task {
                    await client.fetchOperationsLogs()
                }
            }
            .toolbarBackground(Color.cyberTerminalBg, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
    
    // --- UI Panels ---
    
    private func autopilotStatusCard() -> some View {
        let isLocked = client.status?.autopilotLocked ?? false
        let safeMode = client.status?.autopilotSafeMode ?? false
        
        let statusColor = isLocked ? Color.cyberRed : (safeMode ? Color.cyberYellow : Color.cyberGreen)
        let statusLabel = isLocked ? "TRIPPED (LOCKED)" : (safeMode ? "DEGRADED (SAFE)" : "HEALTHY (ACTIVE)")
        
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("AUTOPILOT CIRCUIT BREAKERS")
                        .font(.system(size: 14, weight: .bold))
                        .tracking(1)
                        .foregroundColor(.white)
                    
                    Text("STATUS: \(statusLabel)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(statusColor)
                }
                Spacer()
                
                Image(systemName: isLocked ? "bolt.shield.fill" : "bolt.fill")
                    .font(.title2)
                    .foregroundColor(statusColor)
            }
            
            if isLocked {
                Text("CRITICAL: Circuit breaker tripped due to excessive self-healing restart loops. Safety mechanism is engaged. Manual confirmation sweep is required to unlock.")
                    .font(.system(size: 11, weight: .light))
                    .foregroundColor(.cyberRed.opacity(0.85))
                    .lineSpacing(3)
                
                // Flat Metro Slide-to-unlock
                SlidingLockGate {
                    Task {
                        await runRecovery {
                            await client.unlockAutopilot()
                        }
                    }
                }
                .padding(.top, 4)
            } else {
                Text("Telemetry monitor loop is currently active. Autopilot healing triggers are standing by.")
                    .font(.system(size: 11, weight: .light))
                    .foregroundColor(Color.white.opacity(0.5))
            }
        }
        .padding(20)
        .background(Color.cyberGlassBg)
        .border(isLocked ? Color.cyberRed.opacity(0.35) : Color.white.opacity(0.06), width: 1)
    }
    
    private func recoveryTriggersCard() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("MANUAL REACTOR OVERRIDE COMMANDS")
                .font(.system(size: 14, weight: .bold))
                .tracking(1)
                .foregroundColor(.white)
            
            if let message = actionMessage {
                Text("TRANSMISSION: \(message.uppercased())")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.cyberBlue)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.03))
                    .border(Color.cyberBlue.opacity(0.35), width: 1)
            }
            
            VStack(spacing: 12) {
                recoveryButton(label: "REBOOT INGESTION RSS TIMER", action: "restart-ingest", isDanger: false)
                recoveryButton(label: "REBOOT PROCESSOR WORKER SERVICE", action: "restart-worker", isDanger: false)
                recoveryButton(label: "PRELOAD & WARM LLM COMPILER", action: "warm-model", isDanger: false)
                
                HStack(spacing: 12) {
                    recoveryButton(label: "REQUEUE FAILS", action: "requeue-failed", isDanger: true)
                    recoveryButton(label: "PURGE STUCK QUEUE", action: "clear-stuck", isDanger: true)
                }
            }
        }
        .padding(20)
        .background(Color.cyberGlassBg)
        .border(Color.white.opacity(0.06), width: 1)
    }
    
    private func consoleLogsCard() -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("JOURNAL PROCESS LOGGER")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                    .foregroundColor(Color.white.opacity(0.35))
                Spacer()
                
                // Filters selector (Flat Metro Style tabs)
                HStack(spacing: 8) {
                    filterButton(title: "ALL", filter: .all)
                    filterButton(title: "WARN", filter: .warning)
                    filterButton(title: "CRIT", filter: .critical)
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                let filteredEntries = filteredLogs()
                
                if filteredEntries.isEmpty {
                    Text("NO COMPLIANT ENTRIES IN BUFFER")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.2))
                        .padding(.vertical, 8)
                } else {
                    ForEach(filteredEntries.prefix(20)) { entry in
                        let color = entry.severity == "CRITICAL" ? Color.cyberRed : (entry.severity == "WARNING" ? Color.cyberYellow : Color.cyberGreen)
                        let timeStr = formatIsoTimestamp(entry.createdAt)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text("[\(timeStr)]")
                                    .font(.system(size: 10, weight: .regular))
                                    .foregroundColor(Color.white.opacity(0.35))
                                
                                Text("[\(entry.severity)]")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(color)
                                
                                Text(entry.event.uppercased())
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            
                            Text("ACTION: \(entry.actionTaken.uppercased()) ➔ STATUS: \(entry.result.uppercased())")
                                .font(.system(size: 10, weight: .light))
                                .foregroundColor(Color.white.opacity(0.5))
                                .padding(.leading, 8)
                        }
                        
                        Rectangle()
                            .fill(Color.white.opacity(0.04))
                            .frame(height: 1)
                    }
                }
            }
            .padding(16)
            .background(Color.black.opacity(0.2))
            .border(Color.white.opacity(0.06), width: 1)
        }
    }
    
    // --- Helper Components ---
    
    private func filterButton(title: String, filter: LogFilter) -> some View {
        Button {
            HapticManager.shared.impact(style: .light)
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedLogFilter = filter
            }
        } label: {
            Text(title)
                .font(.system(size: 8, weight: .bold))
                .tracking(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .foregroundColor(selectedLogFilter == filter ? .black : Color.white.opacity(0.5))
                .background(selectedLogFilter == filter ? Color.cyberGreen : Color.clear)
                .border(selectedLogFilter == filter ? Color.clear : Color.white.opacity(0.15), width: 1)
        }
    }
    
    private func filteredLogs() -> [OperationsLog] {
        switch selectedLogFilter {
        case .all:
            return client.logs
        case .critical:
            return client.logs.filter { $0.severity == "CRITICAL" }
        case .warning:
            return client.logs.filter { $0.severity == "WARNING" }
        }
    }
    
    private func recoveryButton(label: String, action: String, isDanger: Bool) -> some View {
        Button {
            HapticManager.shared.impact(style: .medium)
            Task {
                await runRecovery {
                    await client.triggerRecoveryAction(action: action)
                }
            }
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .tracking(0.5)
                .foregroundColor(isDanger ? .cyberRed : .cyberBlue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.black.opacity(0.2))
                .border(isDanger ? Color.cyberRed.opacity(0.5) : Color.cyberBlue.opacity(0.5), width: 1)
        }
        .disabled(isExecutingAction)
    }
    
    private func runRecovery(recoveryCall: @escaping () async -> Bool) async {
        isExecutingAction = true
        actionMessage = "TRANSMITTING TRIGGER SEQUENCE..."
        
        let success = await recoveryCall()
        
        if success {
            actionMessage = "EXECUTION ENVELOPE COMMITTED."
            HapticManager.shared.notification(type: .success)
            await client.fetchOperationsLogs()
        } else {
            actionMessage = "TRANSMISSION FAILED. CHECK CONNECTIVITY."
            HapticManager.shared.notification(type: .error)
        }
        
        isExecutingAction = false
    }
    
    private func formatIsoTimestamp(_ isoString: String) -> String {
        let parts = isoString.components(separatedBy: "T")
        guard parts.count == 2 else { return isoString }
        
        let datePart = parts[0]
        let timePart = parts[1]
        
        let dateSub = datePart.suffix(5)
        let timeSub = timePart.prefix(8)
        
        return "\(dateSub) \(timeSub)"
    }
}

// MARK: - Sliding Lock Gate View for Safe Armed Switches
struct SlidingLockGate: View {
    let onUnlock: () -> Void
    @State private var dragOffset: CGFloat = 0.0
    
    var body: some View {
        GeometryReader { geo in
            let trackWidth = geo.size.width
            let knobWidth: CGFloat = 56.0
            let maxDrag = trackWidth - knobWidth
            
            ZStack(alignment: .leading) {
                // Background Track
                Rectangle()
                    .fill(Color.black.opacity(0.3))
                    .border(Color.cyberRed.opacity(0.3), width: 1)
                
                // Label instruction
                Text("SLIDE TO RESOLVE BREAKER TRIP")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .foregroundColor(.cyberRed)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .opacity(Double(1.0 - (dragOffset / maxDrag)))
                
                // Sliding sweep button
                Rectangle()
                    .fill(Color.cyberRed)
                    .frame(width: knobWidth, height: 44)
                    .overlay(
                        Image(systemName: "bolt.shield.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.black)
                    )
                    .offset(x: dragOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                let dragVal = gesture.translation.width
                                if dragVal >= 0 {
                                    dragOffset = min(dragVal, maxDrag)
                                    HapticManager.shared.selection()
                                }
                            }
                            .onEnded { gesture in
                                if dragOffset >= (maxDrag - 10.0) {
                                    onUnlock()
                                    withAnimation(.easeOut(duration: 0.1)) {
                                        dragOffset = 0.0
                                    }
                                } else {
                                    HapticManager.shared.impact(style: .medium)
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                        dragOffset = 0.0
                                    }
                                }
                            }
                    )
            }
        }
        .frame(height: 44)
    }
}

#Preview {
    let mock = NOCClient()
    AutopilotView(client: mock)
}
