// Callers: ModuleDetailView.designInfoPanel ecosystem tab.
// Affected API: EcosystemSyncPanel.syncToCode now uses DesignBridge.runFusionDesign unified bridge.
// Data schemas: TemplateInfo, MutateCommand, EcosystemTab.
// User instruction: "按照GUI草图实现fusion design，和~/fusion/fusion-design配合，端到端完成fusion设计"

import SwiftUI
import os.log

private let ecoLog = Logger(subsystem: "com.fusion.studio", category: "EcosystemSyncPanel")

struct TemplateInfo: Identifiable, Decodable {
    let id: String
    let name: String
    let tags: [String]
    let category: String
    let document_json: String
    let created_at: UInt64
}

struct MutateCommand: Identifiable, Decodable {
    let node_id: String
    let x: Float?
    let y: Float?
    let w: Float?
    let h: Float?
    let fill: String?
    let stroke: String?
    let radius: Float?
    let opacity: Float?

    var id: String { node_id }

    var summary: String {
        var parts: [String] = []
        if let v = fill { parts.append("fill=\(v)") }
        if let v = stroke { parts.append("stroke=\(v)") }
        if let v = w { parts.append("w=\(v)") }
        if let v = h { parts.append("h=\(v)") }
        if let v = radius { parts.append("radius=\(v)") }
        if let v = opacity { parts.append("opacity=\(v)") }
        return parts.joined(separator: ", ")
    }
}

enum EcosystemTab: String, CaseIterable, Identifiable {
    case sync = "sync"
    case templates = "templates"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sync: return I18nManager.shared.t(.design_eco_tabSync)
        case .templates: return I18nManager.shared.t(.design_eco_tabTpl)
        }
    }

    var icon: String {
        switch self {
        case .sync: return "arrow.triangle.2.circlepath"
        case .templates: return "square.grid.2x2"
        }
    }
}

struct EcosystemSyncPanel: View {
    @Environment(\.studioTheme) var theme
    @EnvironmentObject var designBridge: DesignBridge
    @StateObject private var i18n = I18nManager.shared

    @State private var selectedTab: EcosystemTab = .sync
    @State private var componentName: String = "MyComponent"
    @State private var isSyncing = false
    @State private var syncResult: String?
    @State private var pendingMutations: [MutateCommand] = []
    @State private var isWatching = false
    @State private var templateSearchQuery: String = ""
    @State private var templateResults: [TemplateInfo] = []
    @State private var isSearching = false
    @State private var templateName: String = ""
    @State private var templateTags: String = ""
    @State private var templateCategory: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            tabPicker
            Rectangle().fill(theme.separator).frame(height: 1)
            if let error = errorMessage {
                messageBanner(error, isError: true)
            }
            if let msg = successMessage {
                messageBanner(msg, isError: false)
            }
            if selectedTab == .sync {
                syncContent
            } else {
                templateContent
            }
        }
    }

    private var tabPicker: some View {
        HStack(spacing: theme.spacingXS) {
            ForEach(EcosystemTab.allCases) { tab in
                Button(action: { selectedTab = tab }) {
                    HStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 9))
                        Text(tab.label)
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundStyle(selectedTab == tab ? theme.accentText : theme.textTertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                            .fill(selectedTab == tab ? theme.accent : theme.groupBg)
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
    }

    // MARK: - Sync Tab

    private var syncContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                syncToCodeSection
                watchCodeChangesSection
            }
            .padding(theme.spacingM)
        }
    }

    private var syncToCodeSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Label(i18n.t(.design_eco_syncToCode), systemImage: "arrow.right.doc.on.clipboard")
                .font(.system(size: theme.footnoteSize, weight: .semibold))
                .foregroundStyle(theme.text)

            HStack(spacing: theme.spacingS) {
                Text(i18n.t(.design_eco_compName))
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
                TextField("MyComponent", text: $componentName)
                    .textFieldStyle(.plain)
                    .font(.system(size: theme.captionSize, design: .monospaced))
                    .foregroundStyle(theme.text)
                    .frame(width: 120)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(theme.groupBg)
                    .cornerRadius(theme.cornerRadiusSmall)
                Spacer()
                Button(action: syncToCode) {
                    HStack(spacing: 3) {
                        if isSyncing {
                            ProgressView().scaleEffect(0.6).frame(width: 12, height: 12)
                        } else {
                            Image(systemName: "arrow.right.doc.on.clipboard")
                                .font(.system(size: 9))
                        }
                        Text(isSyncing ? i18n.t(.design_eco_syncing) : i18n.t(.design_eco_syncCode))
                            .font(.system(size: theme.captionSize, weight: .medium))
                    }
                    .foregroundStyle(theme.accentText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).fill(theme.accent))
                }
                .buttonStyle(.plain)
                .disabled(isSyncing)
            }

            if let result = syncResult {
                Text(result)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(3)
            }
        }
        .padding(theme.spacingS)
        .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).fill(theme.groupBg))
    }

    private var watchCodeChangesSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            HStack {
                Label(i18n.t(.design_eco_watchCode), systemImage: "arrow.left.doc.on.clipboard")
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                Spacer()
                Button(action: watchCodeChanges) {
                    HStack(spacing: 3) {
                        if isWatching {
                            ProgressView().scaleEffect(0.6).frame(width: 12, height: 12)
                        } else {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 9))
                        }
                        Text(isWatching ? i18n.t(.design_eco_checking) : i18n.t(.design_eco_checkChange))
                            .font(.system(size: theme.captionSize, weight: .medium))
                    }
                    .foregroundStyle(theme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).fill(theme.groupBg))
                }
                .buttonStyle(.plain)
                .disabled(isWatching)
            }

            if pendingMutations.isEmpty {
                Text(i18n.t(.design_eco_noMutation))
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
            } else {
                VStack(alignment: .leading, spacing: theme.spacingXS) {
                    ForEach(pendingMutations) { cmd in
                        HStack(spacing: 4) {
                            Circle().fill(theme.accentDestructive).frame(width: 5, height: 5)
                            Text(cmd.node_id)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(theme.text)
                            Text(cmd.summary)
                                .font(.system(size: 9))
                                .foregroundStyle(theme.textTertiary)
                                .lineLimit(1)
                        }
                    }
                    Button(action: applyMutations) {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 9))
                            Text(i18n.t(.design_eco_applyCanvas))
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundStyle(theme.accentText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).fill(theme.accent))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(theme.spacingS)
        .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).fill(theme.groupBg))
    }

    // MARK: - Template Tab

    private var templateContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                saveTemplateSection
                searchTemplateSection
            }
            .padding(theme.spacingM)
        }
    }

    private var saveTemplateSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Label(i18n.t(.design_eco_saveAsTpl), systemImage: "square.and.arrow.down")
                .font(.system(size: theme.footnoteSize, weight: .semibold))
                .foregroundStyle(theme.text)

            HStack(spacing: theme.spacingS) {
                TextField(i18n.t(.design_eco_tplNamePh), text: $templateName)
                    .textFieldStyle(.plain)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.text)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(theme.groupBg)
                    .cornerRadius(theme.cornerRadiusSmall)

                TextField(i18n.t(.design_eco_tplTagsPh), text: $templateTags)
                    .textFieldStyle(.plain)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.text)
                    .frame(width: 100)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(theme.groupBg)
                    .cornerRadius(theme.cornerRadiusSmall)

                TextField(i18n.t(.design_eco_tplCatPh), text: $templateCategory)
                    .textFieldStyle(.plain)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.text)
                    .frame(width: 60)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(theme.groupBg)
                    .cornerRadius(theme.cornerRadiusSmall)

                Button(action: saveTemplate) {
                    HStack(spacing: 3) {
                        if isSaving {
                            ProgressView().scaleEffect(0.6).frame(width: 12, height: 12)
                        } else {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 9))
                        }
                        Text(i18n.t(.design_eco_save))
                            .font(.system(size: theme.captionSize, weight: .medium))
                    }
                    .foregroundStyle(theme.accentText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).fill(theme.accent))
                }
                .buttonStyle(.plain)
                .disabled(isSaving || templateName.isEmpty || (designBridge.lastRenderedDocumentJSON ?? "").isEmpty)
            }
        }
        .padding(theme.spacingS)
        .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).fill(theme.groupBg))
    }

    private var searchTemplateSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Label(i18n.t(.design_eco_searchTpl), systemImage: "magnifyingglass")
                .font(.system(size: theme.footnoteSize, weight: .semibold))
                .foregroundStyle(theme.text)

            HStack(spacing: theme.spacingS) {
                TextField(i18n.t(.design_eco_searchPh), text: $templateSearchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.text)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(theme.groupBg)
                    .cornerRadius(theme.cornerRadiusSmall)
                    .onSubmit { searchTemplates() }

                Button(action: searchTemplates) {
                    HStack(spacing: 3) {
                        if isSearching {
                            ProgressView().scaleEffect(0.6).frame(width: 12, height: 12)
                        } else {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 9))
                        }
                        Text(i18n.t(.design_eco_search))
                            .font(.system(size: theme.captionSize, weight: .medium))
                    }
                    .foregroundStyle(theme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).fill(theme.groupBg))
                }
                .buttonStyle(.plain)
                .disabled(isSearching)
            }

            if templateResults.isEmpty && !isSearching {
                Text(i18n.t(.design_eco_noMatchTpl))
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
            } else {
                ForEach(templateResults) { tmpl in
                    templateRow(tmpl)
                }
            }
        }
        .padding(theme.spacingS)
        .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).fill(theme.groupBg))
    }

    private func templateRow(_ tmpl: TemplateInfo) -> some View {
        HStack(spacing: theme.spacingS) {
            VStack(alignment: .leading, spacing: 2) {
                Text(tmpl.name)
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(theme.text)
                HStack(spacing: 4) {
                    Text(tmpl.category)
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                    ForEach(tmpl.tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.system(size: 8))
                            .foregroundStyle(theme.accent)
                    }
                }
            }
            Spacer()
            Button(action: { loadTemplate(tmpl) }) {
                Text(i18n.t(.design_eco_load))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, theme.spacingXS)
    }

    private func messageBanner(_ msg: String, isError: Bool) -> some View {
        HStack(spacing: theme.spacingXS) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(isError ? theme.amberDot : theme.greenDot)
            Text(msg)
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.textSecondary)
                .lineLimit(2)
            Spacer()
            Button(action: { errorMessage = nil; successMessage = nil }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(theme.spacingS)
        .background(isError ? theme.warningBg : theme.groupBg)
    }

    // MARK: - Actions

    private func syncToCode() {
        isSyncing = true
        errorMessage = nil

        DispatchQueue.global(qos: .userInitiated).async {
            let ipcBase = self.ecosystemBaseDir().path
            let docJSON = designBridge.lastRenderedDocumentJSON ?? ""
            // F-I6: 固定名 fd_eco_export_input.json 散落系统 /tmp + 无 0600 → TOCTOU + 路径泄露。
            // 改统一目录 ~/.fusion-studio/tmp/ + UUID + 0600 + 启动清理 LRU。
            let tmpPath = FusionTempDir.shared.tmpFilePath(prefix: "fd_eco_export", ext: "json")
            try? docJSON.write(toFile: tmpPath, atomically: true, encoding: .utf8)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tmpPath)
            let result = designBridge.runFusionDesign(
                ["export", "--input", tmpPath, "--format", "html", "--out", ipcBase, "--ipc-base", ipcBase]
            )
            try? FileManager.default.removeItem(atPath: tmpPath)
            DispatchQueue.main.async {
                if result.exitCode == 0 {
                    self.syncResult = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
                    self.successMessage = I18nManager.shared.t(.design_eco_syncDone)
                    ecoLog.info("Sync to code completed via unified bridge")
                } else {
                    self.errorMessage = String(format: I18nManager.shared.t(.design_eco_syncFailFmt), String(result.error.prefix(200)))
                }
                self.isSyncing = false
            }
        }
    }

    private func watchCodeChanges() {
        isWatching = true
        let ipcBase = ecosystemBaseDir().appendingPathComponent("fusion-code")

        DispatchQueue.global(qos: .userInitiated).async {
            var mutations: [MutateCommand] = []
            let fm = FileManager.default

            if fm.fileExists(atPath: ipcBase.path) {
                if let entries = try? fm.contentsOfDirectory(at: ipcBase, includingPropertiesForKeys: nil) {
                    for entry in entries where entry.pathExtension == "json" {
                        if let data = try? Data(contentsOf: entry),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           json["action"] as? String == "style-change",
                           let payload = json["payload"] as? [String: Any],
                           let mutArr = payload["mutations"] as? [[String: Any]] {
                            for item in mutArr {
                                if let jsonData = try? JSONSerialization.data(withJSONObject: item),
                                   let cmd = try? JSONDecoder().decode(MutateCommand.self, from: jsonData) {
                                    mutations.append(cmd)
                                }
                            }
                        }
                        try? fm.removeItem(at: entry)
                    }
                }
            }

            DispatchQueue.main.async {
                self.pendingMutations = mutations
                self.isWatching = false
                ecoLog.info("Watch code changes: \(mutations.count) mutations found")
            }
        }
    }

    private func applyMutations() {
        for cmd in pendingMutations {
            designBridge.mutateNode(nodeId: cmd.node_id, fill: cmd.fill, stroke: cmd.stroke)
        }
        let count = pendingMutations.count
        pendingMutations = []
        successMessage = String(format: I18nManager.shared.t(.design_eco_appliedFmt), count)
    }

    private func saveTemplate() {
        isSaving = true
        errorMessage = nil

        DispatchQueue.global(qos: .userInitiated).async {
            let ipcBase = self.ecosystemBaseDir()
            let templateDir = ipcBase.appendingPathComponent("fusion-kb/templates")

            do {
                try FileManager.default.createDirectory(at: templateDir, withIntermediateDirectories: true)

                let id = self.templateName.lowercased().replacingOccurrences(of: " ", with: "-") + "-\(Int(Date().timeIntervalSince1970))"
                let tags = self.templateTags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                let timestamp = UInt64(Date().timeIntervalSince1970)

                let templateDict: [String: Any] = [
                    "id": id,
                    "name": self.templateName,
                    "tags": tags,
                    "category": self.templateCategory,
                    "document_json": self.designBridge.lastRenderedDocumentJSON ?? "",
                    "created_at": timestamp
                ]

                let file = templateDir.appendingPathComponent("\(id).json")
                let jsonData = try JSONSerialization.data(withJSONObject: templateDict, options: .prettyPrinted)
                try jsonData.write(to: file)

                DispatchQueue.main.async {
                    self.successMessage = String(format: I18nManager.shared.t(.design_eco_tplSavedFmt), self.templateName)
                    self.templateName = ""
                    self.templateTags = ""
                    self.templateCategory = ""
                    ecoLog.info("Template saved: \(id)")
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = String(format: I18nManager.shared.t(.design_eco_tplSaveFailFmt), error.localizedDescription)
                }
            }

            DispatchQueue.main.async { self.isSaving = false }
        }
    }

    private func searchTemplates() {
        isSearching = true

        DispatchQueue.global(qos: .userInitiated).async {
            let ipcBase = self.ecosystemBaseDir()
            let templateDir = ipcBase.appendingPathComponent("fusion-kb/templates")
            var results: [TemplateInfo] = []

            if FileManager.default.fileExists(atPath: templateDir.path) {
                if let entries = try? FileManager.default.contentsOfDirectory(at: templateDir, includingPropertiesForKeys: nil) {
                    for entry in entries where entry.pathExtension == "json" {
                        if let data = try? Data(contentsOf: entry),
                           let tmpl = try? JSONDecoder().decode(TemplateInfo.self, from: data) {
                            let q = self.templateSearchQuery.lowercased()
                            if q.isEmpty ||
                               tmpl.name.lowercased().contains(q) ||
                               tmpl.tags.contains(where: { $0.lowercased().contains(q) }) ||
                               tmpl.category.lowercased().contains(q) {
                                results.append(tmpl)
                            }
                        }
                    }
                }
            }

            results.sort { $0.created_at > $1.created_at }

            DispatchQueue.main.async {
                self.templateResults = results
                self.isSearching = false
                ecoLog.info("Template search: \(results.count) results")
            }
        }
    }

    private func loadTemplate(_ tmpl: TemplateInfo) {
        designBridge.loadDocumentJSON(tmpl.document_json)
        successMessage = String(format: I18nManager.shared.t(.design_eco_tplLoadedFmt), tmpl.name)
    }

    private func ecosystemBaseDir() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("fusion")
            .appendingPathComponent("ipc")
    }

}
