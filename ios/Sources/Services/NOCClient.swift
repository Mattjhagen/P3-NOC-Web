import Foundation
import Observation
import Combine
import LocalAuthentication
import UserNotifications
import Darwin

@Observable
@MainActor
public class NOCClient: NSObject, UNUserNotificationCenterDelegate {
    public var isAuthenticated = false
    public var token: String? = nil
    
    public static func getLocalIPAddress() -> String {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddr) == 0 {
            var temp_addr = ifaddr
            while temp_addr != nil {
                if let addr = temp_addr?.pointee {
                    let addrFamily = addr.ifa_addr.pointee.sa_family
                    if addrFamily == UInt8(AF_INET) {
                        let name = String(cString: addr.ifa_name)
                        if name == "en0" {
                            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                            if getnameinfo(addr.ifa_addr, socklen_t(addr.ifa_addr.pointee.sa_len),
                                           &hostname, socklen_t(hostname.count),
                                           nil, socklen_t(0), NI_NUMERICHOST) == 0 {
                                let ip = String(cString: hostname)
                                if !ip.isEmpty && ip != "127.0.0.1" {
                                    address = ip
                                    break
                                }
                            }
                        } else if name.hasPrefix("en") || name.hasPrefix("eth") {
                            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                            if getnameinfo(addr.ifa_addr, socklen_t(addr.ifa_addr.pointee.sa_len),
                                           &hostname, socklen_t(hostname.count),
                                           nil, socklen_t(0), NI_NUMERICHOST) == 0 {
                                let ip = String(cString: hostname)
                                if !ip.isEmpty && ip != "127.0.0.1" {
                                    address = ip
                                }
                            }
                        }
                    }
                }
                temp_addr = temp_addr?.pointee.ifa_next
            }
            freeifaddrs(ifaddr)
        }
        return address ?? "192.168.1.85"
    }

    public static var isRunningOnMacOrSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        if ProcessInfo.processInfo.isiOSAppOnMac {
            return true
        }
        return false
        #endif
    }

    public static var isLocalEnvironment: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        if ProcessInfo.processInfo.isiOSAppOnMac {
            return true
        }
        #if DEBUG
        return true
        #else
        return false
        #endif
        #endif
    }
    
    public var hostUrl: String = {
        if NOCClient.isLocalEnvironment {
            if NOCClient.isRunningOnMacOrSimulator {
                let ip = NOCClient.getLocalIPAddress()
                return "http://\(ip):8000"
            } else {
                // Physical iOS device - default to the host Mac's mDNS local address
                return "http://Mattys-MacBook-Air.local:8000"
            }
        } else {
            return "https://mattyhagen.xyz"
        }
    }()
    
    public var status: NOCStatusPayload? = nil
    public var conversations: [Conversation] = []
    public var messages: [ChatMessage] = []
    public var isStreamingChat = false
    public var logs: [OperationsLog] = []
    public var availableModels: [String] = ["qwen3:8b", "phi3:mini"]
    public var isBiometricUnlocked = false
    public var isInputFocused = false
    public var connectionError: String? = nil
    
    public var isBiometricsAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    public func authenticateBiometrics() async -> Bool {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            self.isBiometricUnlocked = true
            return true
        }
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Access P3 NOC Command Console"
            )
            self.isBiometricUnlocked = success
            return success
        } catch {
            print("FaceID authentication failed: \(error.localizedDescription)")
            return false
        }
    }
    
    private var webSocketTask: URLSessionWebSocketTask? = nil
    private var isWebSocketConnected = false
    
    private func normalizeHostUrl(_ urlString: String) -> String {
        var clean = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty {
            if NOCClient.isLocalEnvironment {
                if NOCClient.isRunningOnMacOrSimulator {
                    return "http://\(NOCClient.getLocalIPAddress()):8000"
                } else {
                    return "http://192.168.1.85:8000"
                }
            } else {
                return "https://mattyhagen.xyz"
            }
        }
        
        // Remove trailing slash if present
        if clean.hasSuffix("/") {
            clean.removeLast()
        }
        
        // Check if there is already a scheme
        if clean.hasPrefix("http://") || clean.hasPrefix("https://") {
            return clean
        }
        
        // If it's a local address (localhost, 127.0.0.1, or 192.168.x.x), default to http
        let isLocal = clean.contains("localhost") || 
                      clean.contains("127.0.0.1") || 
                      clean.contains(".local") || 
                      clean.hasPrefix("192.168.") || 
                      clean.hasPrefix("10.") ||
                      clean.hasPrefix("172.")
        
        let scheme = isLocal ? "http://" : "https://"
        return scheme + clean
    }
    
    public override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        requestNotificationPermissions()
        
        // Retrieve cached host url if present (respect cached URL first in all environments)
        if let cachedHost = UserDefaults.standard.string(forKey: "p3noc_host_url") {
            self.hostUrl = cachedHost
        }
        self.hostUrl = normalizeHostUrl(self.hostUrl)
        
        if let cachedToken = UserDefaults.standard.string(forKey: "p3noc_token") {
            self.token = cachedToken
            self.isAuthenticated = true
            Task {
                await fetchConversations()
                connectWebSocket()
            }
        }
    }
    
    public func login(username: String, password: String) async throws {
        self.hostUrl = normalizeHostUrl(self.hostUrl)
        
        guard let url = URL(string: "\(hostUrl)/api/auth/login") else {
            throw NSError(domain: "NOCClient", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid host URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyComponents = [
            "username=\(username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")",
            "password=\(password.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        ]
        request.httpBody = bodyComponents.joined(separator: "&").data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "NOCClient", code: 500, userInfo: [NSLocalizedDescriptionKey: "Server communication failed"])
        }
        
        if httpResponse.statusCode != 200 {
            throw NSError(domain: "NOCClient", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Authentication failed: \(httpResponse.statusCode)"])
        }
        
        struct TokenResponse: Codable {
            let access_token: String
        }
        
        let tokenData = try JSONDecoder().decode(TokenResponse.self, from: data)
        
        self.token = tokenData.access_token
        self.isAuthenticated = true
        self.isBiometricUnlocked = true
        
        // Cache credentials
        UserDefaults.standard.set(self.hostUrl, forKey: "p3noc_host_url")
        UserDefaults.standard.set(tokenData.access_token, forKey: "p3noc_token")
        
        // Load initial data and connect WebSockets
        await fetchConversations()
        connectWebSocket()
    }
    
    public func logout() {
        disconnectWebSocket()
        self.token = nil
        self.isAuthenticated = false
        self.isBiometricUnlocked = false
        self.status = nil
        self.conversations = []
        self.messages = []
        UserDefaults.standard.removeObject(forKey: "p3noc_token")
    }
    
    public func changePassword(current: String, new: String) async throws {
        guard let url = URL(string: "\(hostUrl)/api/auth/change-password") else {
            throw NSError(domain: "NOCClient", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid host URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "current_password": current,
            "new_password": new
        ]
        request.httpBody = try? JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "NOCClient", code: 500, userInfo: [NSLocalizedDescriptionKey: "Server communication failed"])
        }
        
        if httpResponse.statusCode != 200 {
            struct ErrorResponse: Codable {
                let detail: String
            }
            if let errDecoded = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NSError(domain: "NOCClient", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errDecoded.detail])
            }
            throw NSError(domain: "NOCClient", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to update passphrase: Status \(httpResponse.statusCode)"])
        }
    }
    
    // --- WebSocket Telemetry System ---
    
    public func connectWebSocket() {
        guard isAuthenticated, let token = token else { return }
        disconnectWebSocket()
        
        let cleanHost = hostUrl.replacingOccurrences(of: "http://", with: "").replacingOccurrences(of: "https://", with: "")
        let scheme = hostUrl.hasPrefix("https") ? "wss" : "ws"
        guard let wsUrl = URL(string: "\(scheme)://\(cleanHost)/ws/status") else { return }
        
        var request = URLRequest(url: wsUrl)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        let task = session.webSocketTask(with: request)
        self.webSocketTask = task
        self.isWebSocketConnected = true
        task.resume()
        
        receiveWebSocketMessage()
        print("NOC Telemetry WebSocket initiated connection: \(wsUrl.absoluteString)")
    }
    
    public func disconnectWebSocket() {
        isWebSocketConnected = false
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        print("NOC Telemetry WebSocket disconnected.")
    }
    
    private func receiveWebSocketMessage() {
        guard isWebSocketConnected, let task = webSocketTask else { return }
        
        task.receive { [weak self] result in
            guard let self = self else { return }
            
            Task { @MainActor in
                switch result {
                case .success(let message):
                    switch message {
                    case .string(let text):
                        self.parseWebSocketPayload(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            self.parseWebSocketPayload(text)
                        }
                    @unknown default:
                        break
                    }
                    self.receiveWebSocketMessage()
                case .failure(let error):
                    print("WebSocket connection dropped: \(error.localizedDescription)")
                    let isCancelled = (error as? URLError)?.code == .cancelled || error.localizedDescription.lowercased().contains("cancel")
                    self.isWebSocketConnected = false
                    
                    if !isCancelled {
                        self.connectionError = "WebSocket offline: \(error.localizedDescription)"
                    }
                    
                    if !isCancelled && self.isAuthenticated {
                        // Retry connection after 5 seconds if authenticated and not already connected
                        try? await Task.sleep(nanoseconds: 5_000_000_000)
                        if self.isAuthenticated && !self.isWebSocketConnected {
                            self.connectWebSocket()
                        }
                    }
                }
            }
        }
    }
    
    private func parseWebSocketPayload(_ jsonString: String) {
        guard let data = jsonString.data(using: .utf8) else { return }
        do {
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(NOCStatusPayload.self, from: data)
            let oldStatus = self.status
            self.status = decoded
            self.connectionError = nil
            if let old = oldStatus {
                checkForNotifications(old: old, new: decoded)
            }
            if let models = decoded.r510?.availableModels, !models.isEmpty {
                self.availableModels = models
            }
        } catch {
            // Ignore pong responses or mismatch payload
            if jsonString.contains("pong") { return }
            print("Failed to decode telemetry payload: \(error)")
        }
    }
    
    // --- REST API Endpoints ---
    
    public func fetchConversations() async {
        guard let url = URL(string: "\(hostUrl)/api/chat/conversations") else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token ?? "")", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 401 {
                    self.logout()
                    return
                } else if httpResponse.statusCode >= 400 {
                    self.connectionError = "HTTP Status Code \(httpResponse.statusCode)"
                    return
                }
            }
            let decoded = try JSONDecoder().decode([Conversation].self, from: data)
            self.conversations = decoded
            self.connectionError = nil
        } catch {
            print("Error loading chat conversations: \(error)")
            let errMsg = error.localizedDescription
            if errMsg.contains("Unexpected character") || error is DecodingError {
                self.connectionError = "Server returned invalid HTML page (Offline/Cloudflare Error)"
            } else {
                self.connectionError = errMsg
            }
        }
    }
    
    public func createConversation() async -> Int? {
        guard let url = URL(string: "\(hostUrl)/api/chat/conversations") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let dateString = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        let body = ["title": "Mobile Session - \(dateString)"]
        request.httpBody = try? JSONEncoder().encode(body)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoded = try JSONDecoder().decode(Conversation.self, from: data)
            await fetchConversations()
            return decoded.id
        } catch {
            print("Failed to create conversation: \(error)")
            return nil
        }
    }
    
    public func deleteConversation(id: Int) async {
        guard let url = URL(string: "\(hostUrl)/api/chat/conversations/\(id)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token ?? "")", forHTTPHeaderField: "Authorization")
        
        do {
            _ = try await URLSession.shared.data(for: request)
            await fetchConversations()
        } catch {
            print("Failed to delete conversation: \(error)")
        }
    }
    
    public func fetchMessages(conversationId: Int) async {
        guard let url = URL(string: "\(hostUrl)/api/chat/conversations/\(conversationId)/messages") else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token ?? "")", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoded = try JSONDecoder().decode([ChatMessage].self, from: data)
            self.messages = decoded
        } catch {
            print("Error loading messages: \(error)")
        }
    }
    
    // Asynchronous SSE stream message pipeline
    public func sendMessage(
        conversationId: Int,
        content: String,
        model: String,
        temperature: Double,
        topP: Double,
        systemPromptOverride: String?
    ) async {
        guard let url = URL(string: "\(hostUrl)/api/chat/conversations/\(conversationId)/messages") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 180.0
        request.setValue("Bearer \(token ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = MessagePostPayload(
            content: content,
            model: model,
            temperature: temperature,
            topP: topP,
            systemPromptOverride: systemPromptOverride?.isEmpty == false ? systemPromptOverride : nil
        )
        
        request.httpBody = try? JSONEncoder().encode(payload)
        
        // Add User message to local UI
        let userMessage = ChatMessage(role: "user", content: content)
        self.messages.append(userMessage)
        
        // Add Assistant placeholder message to local UI
        let assistantIndex = self.messages.count
        self.messages.append(ChatMessage(role: "assistant", content: ""))
        
        self.isStreamingChat = true
        
        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                self.messages[assistantIndex].content = "Ollama connection timeout or server error."
                self.isStreamingChat = false
                return
            }
            
            var accumulatedResponse = ""
            var hasThinkingBlock = false
            
            for try await line in bytes.lines {
                if line.hasPrefix("data: ") {
                    let jsonStr = line.dropFirst(6).trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !jsonStr.isEmpty, let data = jsonStr.data(using: .utf8) else { continue }
                    
                    // Decode custom metadata chunks or Ollama stream chunk
                    struct SourcesChunk: Codable {
                        let sources: [ChatSource]?
                    }
                    struct SuggestionsChunk: Codable {
                        let suggestions: [String]?
                    }
                    struct OllamaChunk: Codable {
                        struct Message: Codable {
                            let content: String?
                            let thinking: String?
                        }
                        let message: Message?
                        let error: String?
                    }
                    
                    if let sChunk = try? JSONDecoder().decode(SourcesChunk.self, from: data), let srcs = sChunk.sources {
                        self.messages[assistantIndex].sources = srcs
                    } else if let sugChunk = try? JSONDecoder().decode(SuggestionsChunk.self, from: data), let sugs = sugChunk.suggestions {
                        self.messages[assistantIndex].suggestions = sugs
                    } else if let chunk = try? JSONDecoder().decode(OllamaChunk.self, from: data) {
                        if let error = chunk.error {
                            accumulatedResponse += "\n[ERROR: \(error)]"
                        } else if let msg = chunk.message {
                            if let thinking = msg.thinking {
                                if !hasThinkingBlock {
                                    accumulatedResponse += "[THINKING]"
                                    hasThinkingBlock = true
                                }
                                accumulatedResponse += thinking
                            }
                            if let content = msg.content {
                                if hasThinkingBlock && !accumulatedResponse.contains("[/THINKING]") {
                                    accumulatedResponse += "[/THINKING]\n\n"
                                }
                                accumulatedResponse += content
                            }
                        }
                        self.messages[assistantIndex].content = accumulatedResponse
                    }
                }
            }
        } catch {
            self.messages[assistantIndex].content = "Error streaming message: \(error.localizedDescription)"
        }
        
        self.isStreamingChat = false
        await fetchConversations()
    }
    
    public func fetchOperationsLogs() async {
        guard let url = URL(string: "\(hostUrl)/api/alerts") else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token ?? "")", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            struct AlertsResponse: Codable {
                let logs: [OperationsLog]
            }
            let decoded = try JSONDecoder().decode(AlertsResponse.self, from: data)
            self.logs = decoded.logs
        } catch {
            print("Failed to fetch logs: \(error)")
        }
    }
    
    public func triggerRecoveryAction(action: String) async -> Bool {
        guard let url = URL(string: "\(hostUrl)/api/recovery/\(action)") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token ?? "")", forHTTPHeaderField: "Authorization")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return httpResponse.statusCode == 200
        } catch {
            print("Failed to trigger recovery \(action): \(error)")
            return false
        }
    }
    
    public func unlockAutopilot() async -> Bool {
        guard let url = URL(string: "\(hostUrl)/api/recovery/unlock-autopilot") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token ?? "")", forHTTPHeaderField: "Authorization")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return httpResponse.statusCode == 200
        } catch {
            print("Failed to unlock autopilot: \(error)")
            return false
        }
    }
    
    // --- Local Notifications System ---
    
    public func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    private func checkForNotifications(old: NOCStatusPayload, new: NOCStatusPayload) {
        // 1. Notify on health coefficient degradations
        if new.overallHealthScore < 90 && old.overallHealthScore >= 90 {
            sendLocalNotification(
                title: "🚨 SYSTEM HEALTH WARNING",
                body: "System health score has dropped to \(new.overallHealthScore)%. Status: \(new.overallStatus)."
            )
        } else if new.overallHealthScore < 50 && old.overallHealthScore >= 50 {
            sendLocalNotification(
                title: "⚠️ CRITICAL SYSTEM DEGRADATION",
                body: "CRITICAL: System health coefficient is at \(new.overallHealthScore)%. Safelocking Autopilot."
            )
        }
        
        // 2. Notify on new active issues
        let oldIssues = Set(old.activeIssues)
        let newIssues = Set(new.activeIssues)
        let addedIssues = newIssues.subtracting(oldIssues)
        
        for issue in addedIssues {
            sendLocalNotification(
                title: "⚡️ NEW OPERATIONAL INCIDENT",
                body: issue.uppercased()
            )
        }
    }
    
    public func sendLocalNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error posting notification: \(error.localizedDescription)")
            }
        }
    }
    
    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }
}

// MARK: - SSL/TLS Challenge Handler for WebSocket
extension NOCClient: URLSessionWebSocketDelegate {
    nonisolated public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if let serverTrust = challenge.protectionSpace.serverTrust {
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
                return
            }
        }
        completionHandler(.performDefaultHandling, nil)
    }
}
