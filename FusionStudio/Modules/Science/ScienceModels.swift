import Foundation
import os.log

private let modelsLog = Logger(subsystem: "com.fusion.studio", category: "ScienceModels")

struct ScienceSession: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let createdAt: Double
    let updatedAt: Double
    let status: String

    enum CodingKeys: String, CodingKey {
        case id, title, status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    static let placeholder = ScienceSession(
        id: "", title: "New Session", createdAt: 0, updatedAt: 0, status: "active"
    )
}

struct ScienceMessage: Codable, Identifiable, Hashable {
    let id: String
    let sessionId: String
    let role: String
    let content: String
    let createdAt: Double
    let artifacts: [ScienceArtifact]?

    enum CodingKeys: String, CodingKey {
        case id, role, content, artifacts
        case sessionId = "session_id"
        case createdAt = "created_at"
    }

    var isUser: Bool { role == "user" }
    var isAssistant: Bool { role == "assistant" }
}

struct ScienceArtifact: Codable, Identifiable, Hashable {
    let id: String
    let type: String
    let title: String
    let content: String

    var isFigure: Bool { type == "figure" }
    var isCode: Bool { type == "code" }
    var isPaper: Bool { type == "paper" }
}

struct SciencePaper: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let authors: String?
    let year: Int?
    let abstract: String?
    let source: String?
    let doi: String?
    let relevanceScore: Double?

    enum CodingKeys: String, CodingKey {
        case id, title, authors, year, abstract, source, doi
        case relevanceScore = "relevance_score"
    }
}

struct ScienceFigure: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let figureType: String
    let dataJson: String?
    let imageUrl: String?
    let description: String?

    enum CodingKeys: String, CodingKey {
        case id, title, description
        case figureType = "figure_type"
        case dataJson = "data_json"
        case imageUrl = "image_url"
    }
}

struct ScienceAuditEntry: Codable, Identifiable, Hashable {
    let id: String
    let step: String
    let status: String
    let detail: String?
    let timestamp: Double

    enum CodingKeys: String, CodingKey {
        case id, step, status, detail, timestamp
    }

    var isComplete: Bool { status == "complete" }
    var isFailed: Bool { status == "failed" }
    var isRunning: Bool { status == "running" }
}

struct ScienceDatabase: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String?
    let paperCount: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case paperCount = "paper_count"
    }
}

struct SciencePipelineTemplate: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let steps: [String]
}

let sciencePipelineTemplates: [SciencePipelineTemplate] = [
    SciencePipelineTemplate(
        id: "lit-review",
        name: "Literature Review",
        description: "Search, analyze, and synthesize research papers",
        icon: "doc.text.magnifyingglass",
        steps: ["search", "analyze", "review"]
    ),
    SciencePipelineTemplate(
        id: "data-analysis",
        name: "Data Analysis",
        description: "Load data, explore, and generate visualizations",
        icon: "chart.bar.xaxis",
        steps: ["analyze", "visualize"]
    ),
    SciencePipelineTemplate(
        id: "full-research",
        name: "Full Research Cycle",
        description: "End-to-end: search, analyze, visualize, review",
        icon: "flask",
        steps: ["search", "analyze", "visualize", "review"]
    ),
]

struct ScienceHealthResponse: Codable {
    let status: String
    let version: String?
}
