// Callers: DocView (case .template: DocTemplateView), DocSidebar.
// Affected API: DocBridge fetchTemplates, instantiateTemplate, createTemplate, updateTemplate, deleteTemplate, fetchTemplateVariables.
// Data schemas: DocTemplate (from DocBridge.swift).
// User instruction: "按照prd文档和fusion-doc配合打造有竞争力的领先的产品"

import SwiftUI
import os.log

private let templateLog = Logger(subsystem: "com.fusion.studio", category: "DocTemplate")

struct DocTemplateView: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared
    @ObservedObject var bridge: DocBridge
    @State private var selectedTemplate: DocTemplate?
    @State private var variableInputs: [String: String] = [:]
    @State private var showCreateSheet = false
    @State private var newName = ""
    @State private var newType = ""
    @State private var newContent = ""
    @State private var newCategory = ""
    @State private var editContent = ""
    @State private var extractedVars: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            templateHeader
            Divider()
            HSplitView {
                templateList
                    .frame(minWidth: 200, maxWidth: 300)
                templateDetail
                    .frame(minWidth: 300)
            }
        }
        .background(theme.surfacePrimary)
        .onAppear {
            bridge.fetchTemplates()
        }
        .sheet(isPresented: $showCreateSheet) {
            VStack(spacing: 12) {
                Text(i18n.t(.doc_tpl_newTitle)).font(.headline)
                TextField(i18n.t(.doc_tpl_name), text: $newName).textFieldStyle(.roundedBorder)
                TextField(i18n.t(.doc_tpl_typeHint), text: $newType).textFieldStyle(.roundedBorder)
                TextField(i18n.t(.doc_tpl_category), text: $newCategory).textFieldStyle(.roundedBorder)
                TextEditor(text: $newContent)
                    .font(.system(.caption, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .frame(height: 120)
                    .border(Color.gray.opacity(0.3))
                HStack {
                    Button(i18n.t(.cancel)) { showCreateSheet = false }
                    Button(i18n.t(.doc_tpl_create)) {
                        guard !newName.isEmpty else { return }
                        bridge.createTemplate(name: newName, type: newType.isEmpty ? nil : newType, content: newContent.isEmpty ? nil : newContent, category: newCategory.isEmpty ? nil : newCategory) { _ in }
                        newName = ""; newType = ""; newContent = ""; newCategory = ""
                        showCreateSheet = false
                    }
                    .disabled(newName.isEmpty)
                }
            }
            .padding(16)
            .frame(width: 360)
        }
    }

    private var templateHeader: some View {
        HStack {
            Text(i18n.t(.doc_tpl_title))
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
            Button(action: { showCreateSheet = true }) {
                Image(systemName: "plus")
            }
            .help(i18n.t(.doc_tpl_newHelp))
            Button(action: { bridge.fetchTemplates() }) {
                Image(systemName: "arrow.clockwise")
            }
            .help(i18n.t(.refresh))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.surfaceSecondary)
    }

    private var templateList: some View {
        List(selection: $selectedTemplate) {
            if bridge.templates.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.badge.gearshape")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text(i18n.t(.doc_tpl_empty))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ForEach(bridge.templates) { tmpl in
                    templateRow(tmpl)
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func templateRow(_ tmpl: DocTemplate) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: templateIcon(tmpl.type ?? ""))
                    .foregroundColor(theme.accent)
                    .font(.caption)
                Text(tmpl.name)
                    .font(.subheadline)
                    .lineLimit(1)
            }
            if let cat = tmpl.category {
                Text(cat)
                    .font(.caption2)
                    .foregroundColor(theme.textSecondary)
            }
        }
        .tag(tmpl)
        .contextMenu {
            Button(i18n.t(.doc_tpl_extractVars)) {
                bridge.fetchTemplateVariables(id: tmpl.id) { result in
                    if case .success(let dict) = result, let vars = dict["variables"] {
                        DispatchQueue.main.async { self.extractedVars = vars }
                    }
                }
            }
            Button(i18n.t(.doc_tpl_delete), role: .destructive) {
                bridge.deleteTemplate(id: tmpl.id) { _ in }
            }
        }
    }

    private var templateDetail: some View {
        Group {
            if let tmpl = selectedTemplate {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(tmpl.name)
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.primary)

                        if let cat = tmpl.category {
                            HStack {
                                Text(cat)
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(theme.accentSoft)
                                    .cornerRadius(4)
                            }
                        }

                        if let content = tmpl.content {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(i18n.t(.doc_tpl_content))
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(theme.textSecondary)
                                Text(content)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.primary)
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(theme.surfaceSecondary)
                                    .cornerRadius(6)
                            }
                        }

                        let vars = parseVariables(tmpl.variables)
                        if !vars.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(i18n.t(.doc_tpl_variables))
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(theme.textSecondary)
                                ForEach(vars, id: \.self) { v in
                                    HStack {
                                        Text("{{\(v)}}")
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundColor(theme.accent)
                                            .frame(width: 120, alignment: .leading)
                                        TextField(String(format: i18n.t(.doc_tpl_inputVarFmt), v), text: bindingFor(v))
                                            .textFieldStyle(.roundedBorder)
                                    }
                                }
                            }
                        }

                        Button(action: { instantiate(tmpl) }) {
                            Label(i18n.t(.doc_tpl_useCreate), systemImage: "doc.badge.plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!vars.allSatisfy { variableInputs[$0]?.isEmpty == false })

                        Spacer()
                    }
                    .padding(16)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.badge.gearshape")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text(i18n.t(.doc_tpl_selDetail))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Helpers

    private func templateIcon(_ type: String) -> String {
        switch type {
        case "report": return "doc.text.fill"
        case "letter": return "envelope"
        case "proposal": return "paperplane"
        case "weekly": return "calendar"
        default: return "doc"
        }
    }

    private func parseVariables(_ variables: String?) -> [String] {
        guard let vars = variables, !vars.isEmpty else { return [] }
        if let data = vars.data(using: .utf8),
           let arr = try? JSONSerialization.jsonObject(with: data) as? [String] {
            return arr
        }
        let pattern = "\\{\\{(\\w+)\\}\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let matches = regex.matches(in: vars, range: NSRange(vars.startIndex..., in: vars))
        return matches.compactMap { match in
            guard let range = Range(match.range(at: 1), in: vars) else { return nil }
            return String(vars[range])
        }
    }

    private func bindingFor(_ key: String) -> Binding<String> {
        Binding(
            get: { variableInputs[key] ?? "" },
            set: { variableInputs[key] = $0 }
        )
    }

    private func instantiate(_ tmpl: DocTemplate) {
        bridge.instantiateTemplate(id: tmpl.id, variables: variableInputs)
        templateLog.info("Template instantiated: \(tmpl.id)")
        variableInputs.removeAll()
    }
}
