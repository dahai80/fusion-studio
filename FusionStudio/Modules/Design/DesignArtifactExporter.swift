// Callers: DesignWorkflowOrchestrator, DesignChatPanel, DesignBridge (auto-export), MultiFormatExportSheet
// Affected API: DesignArtifactExporter.exportPage/exportAllPages/multiFormatExport, MultiFormatExportSheet
// Data schemas: ExportResult, ExportFormatOption (html/react/vue/swiftui/svg)
// User instruction: "继续实施Phase 6"

import SwiftUI
import os.log

private let exporterLog = Logger(subsystem: "com.fusion.studio", category: "DesignArtifactExporter")

struct ExportResult {
    let success: Bool
    let path: String
    let error: String?

    static func ok(_ path: String) -> ExportResult {
        ExportResult(success: true, path: path, error: nil)
    }

    static func fail(_ path: String, _ error: String) -> ExportResult {
        ExportResult(success: false, path: path, error: error)
    }
}

class DesignArtifactExporter {
    static let shared = DesignArtifactExporter()

    private let fm = FileManager.default
    private let designDir = ".fusion-design"

    private init() {}

    // MARK: - Export single page to project

    func exportPage(title: String, code: String, type: String, version: Int = 0, projectId: String? = nil) -> ExportResult {
        guard let rootPath = resolveRootPath(projectId: projectId) else {
            exporterLog.error("DesignArtifactExporter: no project root path")
            return ExportResult.fail("", "No active project root path")
        }

        let dir = designDirectory(rootPath: rootPath, artifactName: title)
        do {
            try fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
        } catch {
            exporterLog.error("DesignArtifactExporter: failed to create dir \(dir) — \(error.localizedDescription)")
            return ExportResult.fail(dir, error.localizedDescription)
        }

        let ext = fileExtension(for: type)
        let versionSuffix = version > 0 ? "_v\(version)" : ""
        let fileName = sanitizeFileName(title) + versionSuffix + ".\(ext)"
        let filePath = (dir as NSString).appendingPathComponent(fileName)

        do {
            try code.write(toFile: filePath, atomically: true, encoding: .utf8)
            exporterLog.info("DesignArtifactExporter: exported \(title) → \(filePath)")
            postExportNotification(path: rootPath)
            return ExportResult.ok(filePath)
        } catch {
            exporterLog.error("DesignArtifactExporter: write failed — \(error.localizedDescription)")
            return ExportResult.fail(filePath, error.localizedDescription)
        }
    }

    // MARK: - Export all pages

    func exportAllPages(pages: [(title: String, code: String, type: String)], projectId: String? = nil) -> [ExportResult] {
        guard let rootPath = resolveRootPath(projectId: projectId) else {
            exporterLog.error("DesignArtifactExporter: no project root path for batch export")
            return [ExportResult.fail("", "No active project root path")]
        }

        let baseDir = (rootPath as NSString).appendingPathComponent(designDir)
        do {
            try fm.createDirectory(atPath: baseDir, withIntermediateDirectories: true)
        } catch {
            exporterLog.error("DesignArtifactExporter: batch dir create failed — \(error.localizedDescription)")
            return [ExportResult.fail(baseDir, error.localizedDescription)]
        }

        var results: [ExportResult] = []
        for page in pages {
            let result = exportPage(title: page.title, code: page.code, type: page.type, projectId: projectId)
            results.append(result)
        }

        exporterLog.info("DesignArtifactExporter: batch exported \(results.filter(\.success).count)/\(pages.count) pages")
        postExportNotification(path: rootPath)
        return results
    }

    // MARK: - Import file into Design

    func importFromFile(filePath: String) -> (title: String, code: String, type: String)? {
        guard fm.fileExists(atPath: filePath) else {
            exporterLog.warning("DesignArtifactExporter: import file not found — \(filePath)")
            return nil
        }

        guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            exporterLog.error("DesignArtifactExporter: failed to read file — \(filePath)")
            return nil
        }

        let fileName = (filePath as NSString).lastPathComponent
        let nameWithoutExt = fileName.components(separatedBy: ".").dropLast().joined(separator: ".")
        let ext = (filePath as NSString).pathExtension.lowercased()
        let type = typeFromExtension(ext)

        exporterLog.info("DesignArtifactExporter: imported \(fileName) (\(content.count) chars, type=\(type))")
        return (title: nameWithoutExt, code: content, type: type)
    }

    // MARK: - List design files in project

    func listDesignFiles(projectId: String? = nil) -> [String] {
        guard let rootPath = resolveRootPath(projectId: projectId) else { return [] }
        let baseDir = (rootPath as NSString).appendingPathComponent(designDir)

        guard let enumerator = fm.enumerator(atPath: baseDir) else { return [] }

        var files: [String] = []
        for case let relativePath as String in enumerator {
            let fullPath = (baseDir as NSString).appendingPathComponent(relativePath)
            var isDir: ObjCBool = false
            fm.fileExists(atPath: fullPath, isDirectory: &isDir)
            if !isDir.boolValue {
                let ext = (fullPath as NSString).pathExtension.lowercased()
                if designExtensions.contains(ext) {
                    files.append(fullPath)
                }
            }
        }

        exporterLog.info("DesignArtifactExporter: found \(files.count) design files in \(baseDir)")
        return files
    }

    // MARK: - Resolve design directory for an artifact

    func designDirectory(rootPath: String, artifactName: String) -> String {
        let base = (rootPath as NSString).appendingPathComponent(designDir)
        let safeName = sanitizeFileName(artifactName.isEmpty ? "untitled" : artifactName)
        return (base as NSString).appendingPathComponent(safeName)
    }

    // MARK: - Private helpers

    private func resolveRootPath(projectId: String?) -> String? {
        if let pid = projectId,
           let project = FusionProjectManager.shared.projects.first(where: { $0.id == pid }) {
            return project.rootPath
        }
        return FusionProjectManager.shared.activeProject?.rootPath
    }

    private func fileExtension(for type: String) -> String {
        switch type.lowercased() {
        case "react": return "jsx"
        case "vue": return "vue"
        case "swiftui": return "swift"
        case "svg": return "svg"
        case "markdown", "md": return "md"
        default: return "html"
        }
    }

    func typeFromExtension(_ ext: String) -> String {
        switch ext {
        case "jsx", "tsx": return "react"
        case "vue": return "vue"
        case "swift": return "swiftui"
        case "svg": return "svg"
        case "md": return "markdown"
        default: return "html"
        }
    }

    private func sanitizeFileName(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return name.components(separatedBy: invalid).joined(separator: "_")
    }

    private let designExtensions: Set<String> = ["html", "htm", "jsx", "tsx", "vue", "svg", "css", "swift", "md"]

    private func postExportNotification(path: String) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .designArtifactDidExport,
                object: nil,
                userInfo: ["rootPath": path]
            )
        }
    }
}

// MARK: - Notification name

extension Notification.Name {
    static let designArtifactDidExport = Notification.Name("designArtifactDidExport")
}

// MARK: - Multi-Format Export

enum ExportFormatOption: String, CaseIterable {
    case html = "HTML"
    case react = "React"
    case vue = "Vue"
    case swiftui = "SwiftUI"
    case svg = "SVG"

    var icon: String {
        switch self {
        case .html: return "globe"
        case .react: return "atom"
        case .vue: return "leaf"
        case .swiftui: return "swift"
        case .svg: return "square.dashed"
        }
    }
}

extension DesignArtifactExporter {
    func multiFormatExport(title: String, code: String, formats: [ExportFormatOption], projectId: String? = nil) -> [ExportResult] {
        var results: [ExportResult] = []
        for fmt in formats {
            let result = exportPage(title: title, code: code, type: fmt.rawValue.lowercased(), projectId: projectId)
            results.append(result)
        }
        exporterLog.info("DesignArtifactExporter: multi-format export \(formats.count) formats, \(results.filter(\.success).count) succeeded")
        return results
    }
}

struct MultiFormatExportSheet: View {
    @Environment(\.studioTheme) var theme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var designBridge: DesignBridge
    @StateObject private var i18n = I18nManager.shared
    @State private var selectedFormats: Set<ExportFormatOption> = [.html]
    @State private var exportResults: [ExportResult] = []
    @State private var isExporting = false

    let pageTitle: String
    let pageCode: String

    var body: some View {
        VStack(spacing: theme.spacingM) {
            Text(i18n.t(.design_ae_multiFormat))
                .font(.system(size: theme.titleSize, weight: .bold))
                .foregroundStyle(theme.text)

            Text(pageTitle)
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textSecondary)

            VStack(alignment: .leading, spacing: theme.spacingS) {
                ForEach(ExportFormatOption.allCases, id: \.self) { fmt in
                    HStack(spacing: theme.spacingS) {
                        Image(systemName: fmt.icon)
                            .foregroundStyle(theme.accent)
                            .frame(width: 20)
                        Text(fmt.rawValue)
                            .font(.system(size: theme.textSize))
                            .foregroundStyle(theme.text)
                        Spacer()
                        if selectedFormats.contains(fmt) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(theme.accent)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selectedFormats.contains(fmt) {
                            selectedFormats.remove(fmt)
                        } else {
                            selectedFormats.insert(fmt)
                        }
                    }
                    .padding(theme.spacingS)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                            .fill(selectedFormats.contains(fmt) ? theme.surfaceElevated : theme.surfaceSecondary)
                    )
                }
            }
            .padding(theme.spacingM)

            if !exportResults.isEmpty {
                VStack(alignment: .leading, spacing: theme.spacingXS) {
                    ForEach(Array(exportResults.enumerated()), id: \.offset) { idx, result in
                        HStack {
                            Image(systemName: result.success ? "checkmark.circle" : "xmark.circle")
                                .foregroundStyle(result.success ? .green : .red)
                            Text(result.path)
                                .font(.system(size: theme.captionSize))
                                .foregroundStyle(theme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(theme.spacingS)
            }

            HStack(spacing: theme.spacingM) {
                FusionButton(i18n.t(.design_ae_cancel), style: .ghost) { dismiss() }
                FusionButton(String(format: i18n.t(.design_ae_exportFmt), selectedFormats.count), icon: "square.and.arrow.up", style: .primary) {
                    exportAll()
                }
                .disabled(selectedFormats.isEmpty || isExporting)
            }
        }
        .padding(theme.spacingL)
        .frame(width: 360)
        .background(theme.surfacePrimary)
    }

    private func exportAll() {
        isExporting = true
        let results = DesignArtifactExporter.shared.multiFormatExport(
            title: pageTitle,
            code: pageCode,
            formats: Array(selectedFormats)
        )
        exportResults = results
        isExporting = false
        if results.allSatisfy(\.success) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
        }
    }
}
