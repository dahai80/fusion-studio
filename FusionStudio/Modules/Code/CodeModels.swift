// F-I7: CodeEditorView.swift 拆分 — 数据模型 + 终端行模型。
// 迁自 CodeEditorView.swift: CodeFile / RecentProject / TerminalLine。
// codeLog 共享在 CodeView.swift (module-internal let)。

import Foundation

// MARK: - CodeFile

struct CodeFile: Identifiable, Hashable {
    let id: String
    var name: String
    var path: String
    var content: String
    var language: String
    var isModified: Bool
    var isDirectory: Bool
    var children: [CodeFile]?
    var isExpanded: Bool = false
    var relativePath: String = ""
    var fileSize: Int64 = 0

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: CodeFile, rhs: CodeFile) -> Bool { lhs.id == rhs.id }

    static func languageForPath(_ path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "Swift"
        case "py": return "Python"
        case "js": return "JavaScript"
        case "ts": return "TypeScript"
        case "tsx", "jsx": return "React"
        case "rs": return "Rust"
        case "go": return "Go"
        case "java": return "Java"
        case "kt": return "Kotlin"
        case "rb": return "Ruby"
        case "c", "h": return "C"
        case "cpp", "cc", "cxx", "hpp": return "C++"
        case "cs": return "C#"
        case "scala": return "Scala"
        case "sh", "bash", "zsh": return "Shell"
        case "sql": return "SQL"
        case "html": return "HTML"
        case "css": return "CSS"
        case "json": return "JSON"
        case "yaml", "yml": return "YAML"
        case "toml": return "TOML"
        case "xml": return "XML"
        case "md", "markdown": return "Markdown"
        case "dart": return "Dart"
        case "lua": return "Lua"
        case "r": return "R"
        case "zig": return "Zig"
        default: return ""
        }
    }

    static func iconForFile(_ file: CodeFile) -> String {
        if file.isDirectory { return "folder.fill" }
        let lang = file.language.isEmpty ? languageForPath(file.path) : file.language
        switch lang {
        case "Swift": return "swift"
        case "Python": return "snake"
        case "JavaScript", "TypeScript", "React": return "curlybraces"
        case "Rust": return "gearshape"
        case "Go": return "goforward"
        case "Markdown": return "doc.richtext"
        case "JSON", "YAML", "TOML": return "list.bullet.indent"
        case "HTML": return "globe"
        case "CSS": return "paintbrush"
        case "Shell": return "terminal"
        default: return "doc.text"
        }
    }

    static let skipDirectories: Set<String> = [
        ".git", ".svn", ".hg", "__pycache__", "node_modules",
        ".venv", "venv", "env", ".env", ".tox", ".mypy_cache",
        ".pytest_cache", ".ruff_cache", "build", "dist", ".build",
        "DerivedData", ".gradle", ".idea", ".vscode",
        "Pods", ".spm", "htmlcov", ".next", ".nuxt",
    ]

    static let skipFileExtensions: Set<String> = [
        "pyc", "pyo", "o", "so", "dylib", "dll", "exe",
        "class", "jar", "war", "DS_Store", "icloud",
    ]

    static let maxFileSize: Int64 = 1_024_000
}

// MARK: - RecentProject

struct RecentProject: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let path: String
    let gitURL: String?
    let lastOpened: Date

    init(name: String, path: String, gitURL: String? = nil) {
        self.id = UUID()
        self.name = name
        self.path = path
        self.gitURL = gitURL
        self.lastOpened = Date()
    }
}

// MARK: - TerminalLine (TerminalView 模型, 含嵌套 enum LineType)

struct TerminalLine: Identifiable {
    let id = UUID(); let text: String; let type: LineType
    enum LineType { case input, output, info }
    var attributedString: AttributedString {
        var attr = AttributedString(text)
        switch type { case .input: attr.foregroundColor = .green; case .output: attr.foregroundColor = .white; case .info: attr.foregroundColor = .cyan }
        return attr
    }
}
