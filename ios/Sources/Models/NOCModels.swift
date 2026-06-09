import Foundation

public struct NOCStatusPayload: Codable {
    public let overallHealthScore: Int
    public let overallStatus: String
    public let autopilotLocked: Bool
    public let autopilotSafeMode: Bool
    public let activeIssues: [String]
    public let totalRecoveriesToday: Int
    public let uptime: String
    public let t310: T310Metrics?
    public let r510: R510Metrics?
    public let queueCounts: QueueCounts?

    enum CodingKeys: String, CodingKey {
        case overallHealthScore = "overall_health_score"
        case overallStatus = "overall_status"
        case autopilotLocked = "autopilot_locked"
        case autopilotSafeMode = "autopilot_safe_mode"
        case activeIssues = "active_issues"
        case totalRecoveriesToday = "total_recoveries_today"
        case uptime
        case t310
        case r510
        case queueCounts = "queue_counts"
    }
}

public struct T310Metrics: Codable {
    public let online: Bool
    public let cpuPercent: Double?
    public let ramPercent: Double?
    public let diskPercent: Double?
    public let networkRxKbps: Double?
    public let networkTxKbps: Double?
    public let loadAvg: [Double]?
    public let uptime: String?

    enum CodingKeys: String, CodingKey {
        case online
        case cpuPercent = "cpu_percent"
        case ramPercent = "ram_percent"
        case diskPercent = "disk_percent"
        case networkRxKbps = "network_rx_kbps"
        case networkTxKbps = "network_tx_kbps"
        case loadAvg = "load_avg"
        case uptime
    }
}

public struct R510Metrics: Codable {
    public let online: Bool
    public let pingLatencyMs: Double?
    public let sshStatus: String?
    public let ollamaStatus: String?
    public let activeModel: String?
    public let loadedMemoryGb: Double?
    public let activeRequests: Int?
    public let availableModels: [String]?
    public let responseLatencyMs: Double?
    public let cpuPercent: Double?
    public let ramPercent: Double?
    public let uptime: String?

    enum CodingKeys: String, CodingKey {
        case online
        case pingLatencyMs = "ping_latency_ms"
        case sshStatus = "ssh_status"
        case ollamaStatus = "ollama_status"
        case activeModel = "active_model"
        case loadedMemoryGb = "loaded_memory_gb"
        case activeRequests = "active_requests"
        case availableModels = "available_models"
        case responseLatencyMs = "response_latency_ms"
        case cpuPercent = "cpu_percent"
        case ramPercent = "ram_percent"
        case uptime
    }
}

public struct QueueCounts: Codable {
    public let pending: Int
    public let processing: Int
    public let completed: Int
    public let failed: Int
}

public struct Conversation: Codable, Identifiable {
    public let id: Int
    public let title: String
    public let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case createdAt = "created_at"
    }
}

public struct ChatSource: Codable, Identifiable, Equatable {
    public var id: String { url }
    public let title: String
    public let url: String
}

public struct ChatMessage: Codable, Identifiable {
    public var id = UUID()
    public var backendId: Int?
    public let role: String
    public var content: String
    public var sources: [ChatSource]?
    public var suggestions: [String]?
    public let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case backendId = "id"
        case role
        case content
        case sources
        case suggestions
        case createdAt = "created_at"
    }
    
    public init(id: Int? = nil, role: String, content: String, sources: [ChatSource]? = nil, suggestions: [String]? = nil, createdAt: String? = nil) {
        self.backendId = id
        self.role = role
        self.content = content
        self.sources = sources
        self.suggestions = suggestions
        self.createdAt = createdAt
    }
}

public struct MessagePostPayload: Codable {
    public let content: String
    public let model: String?
    public let temperature: Double?
    public let topP: Double?
    public let systemPromptOverride: String?

    enum CodingKeys: String, CodingKey {
        case content
        case model
        case temperature
        case topP = "top_p"
        case systemPromptOverride = "system_prompt_override"
    }
}

public struct OperationsLog: Codable, Identifiable {
    public let id: Int
    public let severity: String
    public let event: String
    public let actionTaken: String
    public let result: String
    public let host: String
    public let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case severity
        case event
        case actionTaken = "action_taken"
        case result
        case host
        case createdAt = "created_at"
    }
}
