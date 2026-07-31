// Callers: UnifiedChatView + menu Skills submenu, ChatSessionStore.sendMessage (skill systemPrompt injection).
// Affected API: FusionSkillManager.shared (CRUD + persistence), ChatSessionData.activeSkill.
// Data schemas: FusionSkill {id, name, description, systemPrompt, icon, isBuiltin}.
// User instruction: "这个里面还有很多能力没有落地，你逐一排查，需要全面对标落地，对上下游有问题和需求就提issue和pr"

import Foundation
import os.log

private let skillLog = Logger(subsystem: "com.fusion.studio", category: "FusionSkill")

struct FusionSkill: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var description: String
    var systemPrompt: String
    var icon: String
    var isBuiltin: Bool

    init(name: String, description: String, systemPrompt: String, icon: String = "star", isBuiltin: Bool = false) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.systemPrompt = systemPrompt
        self.icon = icon
        self.isBuiltin = isBuiltin
    }
}

class FusionSkillManager: ObservableObject {
    static let shared = FusionSkillManager()

    @Published var skills: [FusionSkill] = []

    private let baseDir: URL
    private let indexURL: URL

    init() {
        let fm = FileManager.default
        baseDir = fm.homeDirectoryForCurrentUser.appendingPathComponent(".fusion-studio/skills", isDirectory: true)
        indexURL = baseDir.appendingPathComponent("index.json")
        try? fm.createDirectory(at: baseDir, withIntermediateDirectories: true)
        loadSkills()
        if skills.isEmpty {
            seedBuiltins()
        }
    }

    private func loadSkills() {
        guard let data = try? Data(contentsOf: indexURL),
              let decoded = try? JSONDecoder().decode([FusionSkill].self, from: data) else {
            skills = []
            return
        }
        skills = decoded
        skillLog.info("Loaded \(decoded.count) skills")
    }

    private func saveIndex() {
        guard let data = try? JSONEncoder().encode(skills) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }

    private func seedBuiltins() {
        let builtins: [FusionSkill] = [
            FusionSkill(
                name: "代码审查",
                description: "审查代码质量、安全性和最佳实践",
                systemPrompt: "You are a senior code reviewer. Analyze code for bugs, security vulnerabilities, performance issues, and violations of best practices. Provide specific, actionable feedback with code examples. Structure your review by severity: critical, warning, suggestion.",
                icon: "ladybug",
                isBuiltin: true
            ),
            FusionSkill(
                name: "周报生成",
                description: "根据工作内容自动生成结构化周报",
                systemPrompt: "You are a weekly report generator. Given raw work items, produce a structured weekly report with sections: Key Accomplishments, In Progress, Blockers, Next Week Plan. Use concise professional language. Highlight metrics and outcomes.",
                icon: "doc.text",
                isBuiltin: true
            ),
            FusionSkill(
                name: "翻译助手",
                description: "高质量中英双向翻译，保持语境和语气",
                systemPrompt: "You are a professional translator between Chinese and English. Preserve tone, context, and cultural nuances. For technical content, use industry-standard terminology. Output only the translation, no explanations unless ambiguous.",
                icon: "character.book.closed",
                isBuiltin: true
            ),
            FusionSkill(
                name: "文档转换",
                description: "将内容转换为 Markdown/JSON/API 文档等格式",
                systemPrompt: "You are a document format converter. Transform raw content into well-structured output in the requested format (Markdown, JSON schema, API doc, README, etc.). Follow conventions of the target format strictly. Preserve all factual information.",
                icon: "doc.on.doc",
                isBuiltin: true
            ),
        ]
        skills = builtins
        saveIndex()
        skillLog.info("Seeded \(builtins.count) builtin skills")
    }

    func createSkill(name: String, description: String, systemPrompt: String, icon: String = "star") -> FusionSkill {
        let skill = FusionSkill(name: name, description: description, systemPrompt: systemPrompt, icon: icon)
        skills.append(skill)
        saveIndex()
        skillLog.info("Skill created: \(name)")
        return skill
    }

    func updateSkill(_ skill: FusionSkill) {
        guard let idx = skills.firstIndex(where: { $0.id == skill.id }) else { return }
        skills[idx] = skill
        saveIndex()
        skillLog.info("Skill updated: \(skill.name)")
    }

    func deleteSkill(_ skill: FusionSkill) {
        skills.removeAll { $0.id == skill.id }
        saveIndex()
        skillLog.info("Skill deleted: \(skill.name)")
    }
}
