// IMPORTERS/CALLERS: DocSidebar headerBar (sheet via showAdminSheet)
// AFFECTED API: DocBridge - 13 API groups: Users, AI-Raw, Branding, Theme, Vocabulary,
//   Webhooks, Metadata, System Info, System Config, Export, RAG, Graph Search, Notifications
// DATA SCHEMAS: DocUser, DocBranding, DocTheme, DocVocabulary, DocWebhook, DocMetadataEntry,
//   DocSystemInfo, DocSystemConfig, DocExportJob, DocNotification, DocGraph
// USER INSTRUCTION: "立即启动4项GUI增强 - 13 API组面板"

import SwiftUI
import os.log

private let docAdminLog = Logger(subsystem: "com.fusion.studio", category: "DocAdminView")

extension NSColor {
    convenience init?(hexString: String) {
        var s = hexString.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(red: CGFloat((v >> 16) & 0xFF) / 255,
                  green: CGFloat((v >> 8) & 0xFF) / 255,
                  blue: CGFloat(v & 0xFF) / 255,
                  alpha: 1)
    }
}

struct DocAdminView: View {
    @Environment(\.studioTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var bridge: DocBridge
    @State private var section: AdminSection = .users

    private enum AdminSection: String, CaseIterable, Identifiable {
        case users = "Users"
        case aiRaw = "AI Raw"
        case branding = "Branding"
        case theme = "Theme"
        case vocabulary = "Vocabulary"
        case webhooks = "Webhooks"
        case metadata = "Metadata"
        case systemInfo = "System Info"
        case systemConfig = "System Config"
        case exportJobs = "Export"
        case rag = "RAG"
        case graph = "Graph Search"
        case notifications = "Notifications"
        var id: String { rawValue }
        var localizedName: String {
            switch self {
            case .users: return I18nManager.shared.t(.doc_admin_sec_users)
            case .aiRaw: return I18nManager.shared.t(.doc_admin_sec_aiRaw)
            case .branding: return I18nManager.shared.t(.doc_admin_sec_branding)
            case .theme: return I18nManager.shared.t(.doc_admin_sec_theme)
            case .vocabulary: return I18nManager.shared.t(.doc_admin_sec_vocabulary)
            case .webhooks: return I18nManager.shared.t(.doc_admin_sec_webhooks)
            case .metadata: return I18nManager.shared.t(.doc_admin_sec_metadata)
            case .systemInfo: return I18nManager.shared.t(.doc_admin_sec_systemInfo)
            case .systemConfig: return I18nManager.shared.t(.doc_admin_sec_systemConfig)
            case .exportJobs: return I18nManager.shared.t(.doc_admin_sec_export)
            case .rag: return I18nManager.shared.t(.doc_admin_sec_rag)
            case .graph: return I18nManager.shared.t(.doc_admin_sec_graph)
            case .notifications: return I18nManager.shared.t(.doc_admin_sec_notifications)
            }
        }
        var icon: String {
            switch self {
            case .users: return "person.2"
            case .aiRaw: return "cpu"
            case .branding: return "paintbrush"
            case .theme: return "swatchpalette"
            case .vocabulary: return "text.book.closed"
            case .webhooks: return "webhook"
            case .metadata: return "tag"
            case .systemInfo: return "info.circle"
            case .systemConfig: return "gearshape"
            case .exportJobs: return "square.and.arrow.up"
            case .rag: return "doc.text.magnifyingglass"
            case .graph: return "point.3.connected.trianglepath.dotted"
            case .notifications: return "bell"
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                Text(I18nManager.shared.t(.doc_admin_title))
                    .font(.headline)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(theme.surfaceSecondary)
                Divider()
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(AdminSection.allCases) { s in
                            Button {
                                section = s
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: s.icon)
                                        .frame(width: 18)
                                        .foregroundColor(section == s ? theme.accent : theme.textSecondary)
                                    Text(s.localizedName)
                                        .foregroundColor(section == s ? theme.text : theme.textSecondary)
                                    Spacer()
                                }
                                .padding(.vertical, 7)
                                .padding(.horizontal, 12)
                                .background(section == s ? theme.selBg : Color.clear)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .frame(width: 180)
            .background(theme.surfaceSecondary)

            Divider()

            ScrollView {
                Group {
                    switch section {
                    case .users: UserAdminPanel(bridge: bridge)
                    case .aiRaw: AIRawPanel(bridge: bridge)
                    case .branding: BrandingPanel(bridge: bridge)
                    case .theme: ThemePanel(bridge: bridge)
                    case .vocabulary: VocabularyPanel(bridge: bridge)
                    case .webhooks: WebhookPanel(bridge: bridge)
                    case .metadata: MetadataPanel(bridge: bridge)
                    case .systemInfo: SystemInfoPanel(bridge: bridge)
                    case .systemConfig: SystemConfigPanel(bridge: bridge)
                    case .exportJobs: ExportPanel(bridge: bridge)
                    case .rag: RAGPanel(bridge: bridge)
                    case .graph: GraphPanel(bridge: bridge)
                    case .notifications: NotificationPanel(bridge: bridge)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 780, height: 600)
        .background(theme.surfacePrimary)
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(theme.textTertiary)
            }
            .padding(10)
        }
    }
}

private struct PanelHeader: View {
    @Environment(\.studioTheme) private var theme
    let title: String
    var body: some View {
        Text(title).font(.title3).fontWeight(.semibold).foregroundColor(theme.text)
    }
}

private struct ErrorLine: View {
    let message: String
    var body: some View {
        Text(message).font(.caption).foregroundColor(.red)
    }
}

private struct EmptyHint: View {
    @Environment(\.studioTheme) private var theme
    let text: String
    var body: some View {
        Text(text).foregroundColor(theme.textTertiary).font(.subheadline)
    }
}

// MARK: - Users

private struct UserAdminPanel: View {
    @Environment(\.studioTheme) private var theme
    @ObservedObject var bridge: DocBridge
    @State private var loading = false
    @State private var error: String?

    private let roles = ["viewer", "editor", "admin"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelHeader(title: I18nManager.shared.t(.doc_admin_panel_users))
            if loading { ProgressView() }
            if let err = error { ErrorLine(message: err) }
            if bridge.users.isEmpty && !loading {
                EmptyHint(text: I18nManager.shared.t(.doc_admin_empty_users))
            } else {
                ForEach(bridge.users) { u in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(u.username ?? u.id).fontWeight(.medium)
                            Text(u.email ?? "-").font(.caption).foregroundColor(theme.textSecondary)
                        }
                        Spacer()
                        Picker("", selection: Binding(
                            get: { u.role ?? "viewer" },
                            set: { newRole in bridge.updateUser(id: u.id, role: newRole) { _ in load() } }
                        )) {
                            ForEach(roles, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 90)
                        Button(role: .destructive) {
                            bridge.deleteUser(id: u.id) { _ in load() }
                        } label: { Image(systemName: "trash") }
                            .buttonStyle(.plain)
                    }
                    .padding(10)
                    .background(theme.surfaceSecondary)
                    .cornerRadius(8)
                }
            }
        }
        .onAppear { load() }
    }

    private func load() {
        loading = true; error = nil
        docAdminLog.info("fetchUsers")
        bridge.fetchUsers { result in
            DispatchQueue.main.async {
                loading = false
                if case .failure(let err) = result { error = err.localizedDescription }
            }
        }
    }
}

// MARK: - AI Raw

private struct AIRawPanel: View {
    @Environment(\.studioTheme) private var theme
    @ObservedObject var bridge: DocBridge
    @State private var prompt = ""
    @State private var result = ""
    @State private var loading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelHeader(title: I18nManager.shared.t(.doc_admin_panel_aiRaw))
            TextField(I18nManager.shared.t(.doc_admin_label_input_prompt), text: $prompt, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
            HStack {
                Button(I18nManager.shared.t(.doc_admin_btn_completions)) { runCompletions() }
                    .buttonStyle(.borderedProminent)
                    .disabled(prompt.isEmpty || loading)
                Button(I18nManager.shared.t(.doc_admin_btn_chat)) { runChat() }
                    .buttonStyle(.bordered)
                    .disabled(prompt.isEmpty || loading)
                if loading { ProgressView().controlSize(.small) }
            }
            if !result.isEmpty {
                Text(I18nManager.shared.t(.doc_admin_label_result)).font(.caption).foregroundColor(theme.textSecondary)
                TextEditor(text: .constant(result))
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 180)
                    .background(theme.surfaceSecondary)
                    .cornerRadius(8)
            }
        }
        .onAppear { docAdminLog.info("AIRawPanel appear") }
    }

    private func runCompletions() {
        loading = true; result = ""
        bridge.aiCompletions(prompt: prompt) { res in
            DispatchQueue.main.async {
                loading = false
                switch res {
                case .success(let d): result = d.values.joined(separator: "\n")
                case .failure(let e): result = I18nManager.shared.tf(.doc_admin_err_prefix, e.localizedDescription)
                }
            }
        }
    }

    private func runChat() {
        loading = true; result = ""
        bridge.aiChat(messages: [["role": "user", "content": prompt]]) { res in
            DispatchQueue.main.async {
                loading = false
                switch res {
                case .success(let d): result = d["content"] ?? d.values.joined(separator: "\n")
                case .failure(let e): result = I18nManager.shared.tf(.doc_admin_err_prefix, e.localizedDescription)
                }
            }
        }
    }
}

// MARK: - Branding

private struct BrandingPanel: View {
    @Environment(\.studioTheme) private var theme
    @ObservedObject var bridge: DocBridge
    @State private var logoUrl = ""
    @State private var primaryColor = ""
    @State private var secondaryColor = ""
    @State private var font = ""
    @State private var customCss = ""
    @State private var loading = false
    @State private var saved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelHeader(title: I18nManager.shared.t(.doc_admin_panel_branding))
            if loading { ProgressView().frame(maxWidth: .infinity, alignment: .center) } else {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                    GridRow { Text("Logo URL").frame(width: 110, alignment: .trailing); TextField("", text: $logoUrl).textFieldStyle(.roundedBorder) }
                    GridRow { Text(I18nManager.shared.t(.doc_admin_label_primary_color)).frame(width: 110, alignment: .trailing)
                        HStack { TextField("#007AFF", text: $primaryColor).textFieldStyle(.roundedBorder); ColorSwatch(hex: primaryColor) } }
                    GridRow { Text(I18nManager.shared.t(.doc_admin_label_secondary_color)).frame(width: 110, alignment: .trailing)
                        HStack { TextField("", text: $secondaryColor).textFieldStyle(.roundedBorder); ColorSwatch(hex: secondaryColor) } }
                    GridRow { Text(I18nManager.shared.t(.doc_admin_label_font)).frame(width: 110, alignment: .trailing); TextField("", text: $font).textFieldStyle(.roundedBorder) }
                }
                Text(I18nManager.shared.t(.doc_admin_label_custom_css)).font(.caption).foregroundColor(theme.textSecondary)
                TextEditor(text: $customCss)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 100)
                    .background(theme.surfaceSecondary)
                    .cornerRadius(8)
                HStack {
                    Button(I18nManager.shared.t(.doc_admin_btn_save)) { save() }.buttonStyle(.borderedProminent)
                    if saved { Label(I18nManager.shared.t(.doc_admin_label_saved), systemImage: "checkmark.circle.fill").foregroundColor(.green).font(.caption) }
                }
            }
        }
        .onAppear { load() }
    }

    private func load() {
        loading = true
        bridge.fetchBranding { res in
            DispatchQueue.main.async {
                loading = false
                if case .success(let b) = res {
                    logoUrl = b.logo_url ?? ""
                    primaryColor = b.primary_color ?? ""
                    secondaryColor = b.secondary_color ?? ""
                    font = b.font ?? ""
                    customCss = b.custom_css ?? ""
                }
            }
        }
    }

    private func save() {
        let b = DocBranding(logo_url: logoUrl.isEmpty ? nil : logoUrl,
                            primary_color: primaryColor.isEmpty ? nil : primaryColor,
                            secondary_color: secondaryColor.isEmpty ? nil : secondaryColor,
                            font: font.isEmpty ? nil : font,
                            custom_css: customCss.isEmpty ? nil : customCss)
        bridge.updateBranding(branding: b) { res in
            DispatchQueue.main.async {
                if case .success = res { saved = true }
            }
        }
    }
}

private struct ColorSwatch: View {
    let hex: String
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color(nsColor: NSColor(hexString: hex) ?? .controlAccentColor))
            .frame(width: 22, height: 22)
    }
}

// MARK: - Theme

private struct ThemePanel: View {
    @Environment(\.studioTheme) private var theme
    @ObservedObject var bridge: DocBridge
    @State private var newName = ""
    @State private var newCss = ""
    @State private var newDark = false
    @State private var loading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelHeader(title: I18nManager.shared.t(.doc_admin_panel_theme))
            if loading { ProgressView() }
            ForEach(bridge.themes) { t in
                HStack {
                    Image(systemName: t.is_dark == true ? "moon.fill" : "sun.max.fill")
                        .foregroundColor(theme.textSecondary)
                    Text(t.name)
                    Spacer()
                    Button(role: .destructive) { bridge.deleteTheme(id: t.id) { _ in load() } }
                        label: { Image(systemName: "trash") }.buttonStyle(.plain)
                }
                .padding(10).background(theme.surfaceSecondary).cornerRadius(8)
            }
            Divider()
            Text(I18nManager.shared.t(.doc_admin_label_new_theme)).font(.subheadline).fontWeight(.medium)
            TextField(I18nManager.shared.t(.doc_admin_label_name), text: $newName).textFieldStyle(.roundedBorder)
            TextField(I18nManager.shared.t(.doc_admin_label_css_optional), text: $newCss, axis: .vertical).textFieldStyle(.roundedBorder).lineLimit(2...4)
            Toggle(I18nManager.shared.t(.doc_admin_label_dark), isOn: $newDark)
            Button(I18nManager.shared.t(.doc_admin_btn_create)) {
                bridge.createTheme(name: newName, css: newCss.isEmpty ? nil : newCss, isDark: newDark) { _ in
                    newName = ""; newCss = ""; newDark = false; load()
                }
            }.buttonStyle(.borderedProminent).disabled(newName.isEmpty)
        }
        .onAppear { load() }
    }

    private func load() {
        loading = true
        bridge.fetchThemes { _ in DispatchQueue.main.async { loading = false } }
    }
}

// MARK: - Vocabulary

private struct VocabularyPanel: View {
    @Environment(\.studioTheme) private var theme
    @ObservedObject var bridge: DocBridge
    @State private var term = ""
    @State private var definition = ""
    @State private var category = ""
    @State private var loading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelHeader(title: I18nManager.shared.t(.doc_admin_panel_vocabulary))
            if loading { ProgressView() }
            ForEach(bridge.vocabulary) { v in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(v.term).fontWeight(.medium)
                        if let d = v.definition { Text(d).font(.caption).foregroundColor(theme.textSecondary) }
                    }
                    Spacer()
                    if let c = v.category { Text(c).font(.caption).padding(.horizontal, 6).padding(.vertical, 2).background(theme.controlTinted).cornerRadius(4) }
                    Button(role: .destructive) { bridge.deleteVocabulary(id: v.id) { _ in load() } }
                        label: { Image(systemName: "trash") }.buttonStyle(.plain)
                }
                .padding(10).background(theme.surfaceSecondary).cornerRadius(8)
            }
            Divider()
            Text(I18nManager.shared.t(.doc_admin_label_new_term)).font(.subheadline).fontWeight(.medium)
            HStack {
                TextField(I18nManager.shared.t(.doc_admin_label_term), text: $term).textFieldStyle(.roundedBorder)
                TextField(I18nManager.shared.t(.doc_admin_label_category), text: $category).textFieldStyle(.roundedBorder).frame(width: 100)
            }
            TextField(I18nManager.shared.t(.doc_admin_label_definition), text: $definition, axis: .vertical).textFieldStyle(.roundedBorder).lineLimit(2...3)
            Button(I18nManager.shared.t(.doc_admin_btn_add)) {
                bridge.createVocabulary(term: term, definition: definition.isEmpty ? nil : definition, category: category.isEmpty ? nil : category) { _ in
                    term = ""; definition = ""; category = ""; load()
                }
            }.buttonStyle(.borderedProminent).disabled(term.isEmpty)
        }
        .onAppear { load() }
    }

    private func load() {
        loading = true
        bridge.fetchVocabulary { _ in DispatchQueue.main.async { loading = false } }
    }
}

// MARK: - Webhooks

private struct WebhookPanel: View {
    @Environment(\.studioTheme) private var theme
    @ObservedObject var bridge: DocBridge
    @State private var url = ""
    @State private var events = ""
    @State private var secret = ""
    @State private var loading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelHeader(title: I18nManager.shared.t(.doc_admin_panel_webhooks))
            if loading { ProgressView() }
            ForEach(bridge.webhooks) { w in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(w.url).fontWeight(.medium).lineLimit(1)
                        if let ev = w.events { Text(ev.joined(separator: ", ")).font(.caption).foregroundColor(theme.textSecondary) }
                    }
                    Spacer()
                    if w.is_active == true { Circle().fill(.green).frame(width: 8, height: 8) }
                    Button(role: .destructive) { bridge.deleteWebhook(id: w.id) { _ in load() } }
                        label: { Image(systemName: "trash") }.buttonStyle(.plain)
                }
                .padding(10).background(theme.surfaceSecondary).cornerRadius(8)
            }
            Divider()
            Text(I18nManager.shared.t(.doc_admin_label_new_webhook)).font(.subheadline).fontWeight(.medium)
            TextField("URL", text: $url).textFieldStyle(.roundedBorder)
            TextField(I18nManager.shared.t(.doc_admin_label_events), text: $events).textFieldStyle(.roundedBorder)
            SecureField(I18nManager.shared.t(.doc_admin_label_secret), text: $secret).textFieldStyle(.roundedBorder)
            Button(I18nManager.shared.t(.doc_admin_btn_create)) {
                let ev = events.isEmpty ? nil : events.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
                bridge.createWebhook(url: url, events: ev, secret: secret.isEmpty ? nil : secret) { _ in
                    url = ""; events = ""; secret = ""; load()
                }
            }.buttonStyle(.borderedProminent).disabled(url.isEmpty)
        }
        .onAppear { load() }
    }

    private func load() {
        loading = true
        bridge.fetchWebhooks { _ in DispatchQueue.main.async { loading = false } }
    }
}

// MARK: - Metadata

private struct MetadataPanel: View {
    @Environment(\.studioTheme) private var theme
    @ObservedObject var bridge: DocBridge
    @State private var entity = ""
    @State private var entityId = ""
    @State private var entries: [DocMetadataEntry] = []
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelHeader(title: I18nManager.shared.t(.doc_admin_panel_metadata))
            HStack {
                TextField("entity", text: $entity).textFieldStyle(.roundedBorder)
                TextField("entity_id", text: $entityId).textFieldStyle(.roundedBorder)
                Button(I18nManager.shared.t(.doc_admin_btn_query)) { load() }.buttonStyle(.borderedProminent).disabled(entity.isEmpty || entityId.isEmpty)
            }
            if loading { ProgressView() }
            if let err = error { ErrorLine(message: err) }
            ForEach(entries) { e in
                HStack {
                    Text(e.key).fontWeight(.medium)
                    Text(e.value ?? "-").font(.caption).foregroundColor(theme.textSecondary)
                    Spacer()
                    Button(role: .destructive) {
                        bridge.deleteMetadata(entity: entity, entityId: entityId, key: e.key) { _ in load() }
                    } label: { Image(systemName: "trash") }.buttonStyle(.plain)
                }
                .padding(10).background(theme.surfaceSecondary).cornerRadius(8)
            }
            if entries.isEmpty && !loading { EmptyHint(text: I18nManager.shared.t(.doc_admin_empty_metadata_query)) }
        }
    }

    private func load() {
        loading = true; error = nil
        bridge.fetchMetadata(entity: entity, entityId: entityId) { res in
            DispatchQueue.main.async {
                loading = false
                switch res {
                case .success(let list): entries = list
                case .failure(let err): error = err.localizedDescription
                }
            }
        }
    }
}

// MARK: - System Info

private struct SystemInfoPanel: View {
    @Environment(\.studioTheme) private var theme
    @ObservedObject var bridge: DocBridge
    @State private var loading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { PanelHeader(title: I18nManager.shared.t(.doc_admin_panel_systemInfo)); Spacer(); Button(I18nManager.shared.t(.doc_admin_btn_refresh)) { load() }.buttonStyle(.bordered) }
            if loading { ProgressView() }
            if let info = bridge.systemInfo {
                VStack(spacing: 8) {
                    InfoRow(label: I18nManager.shared.t(.doc_admin_label_version), value: info.version ?? "-")
                    if let up = info.uptime { InfoRow(label: I18nManager.shared.t(.doc_admin_label_uptime), value: "\(Int(up))s") }
                    if let b = info.total_books { InfoRow(label: I18nManager.shared.t(.doc_admin_label_total_books), value: "\(b)") }
                    if let p = info.total_pages { InfoRow(label: I18nManager.shared.t(.doc_admin_label_total_pages), value: "\(p)") }
                    if let u = info.total_users { InfoRow(label: I18nManager.shared.t(.doc_admin_label_total_users), value: "\(u)") }
                }
            } else if !loading {
                EmptyHint(text: I18nManager.shared.t(.doc_admin_empty_sysinfo))
            }
        }
        .onAppear { if bridge.systemInfo == nil { load() } }
    }

    private func load() {
        loading = true
        bridge.fetchSystemInfo { _ in DispatchQueue.main.async { loading = false } }
    }
}

private struct InfoRow: View {
    @Environment(\.studioTheme) private var theme
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).foregroundColor(theme.textSecondary).frame(width: 100, alignment: .leading)
            Text(value)
            Spacer()
        }
        .padding(10).background(theme.surfaceSecondary).cornerRadius(8)
    }
}

// MARK: - System Config

private struct SystemConfigPanel: View {
    @Environment(\.studioTheme) private var theme
    @ObservedObject var bridge: DocBridge
    @State private var edits: [String: String] = [:]
    @State private var loading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { PanelHeader(title: I18nManager.shared.t(.doc_admin_panel_systemConfig)); Spacer(); Button(I18nManager.shared.t(.doc_admin_btn_refresh)) { load() }.buttonStyle(.bordered) }
            if loading { ProgressView() }
            ForEach(bridge.systemConfig, id: \.key) { c in
                HStack {
                    Text(c.key).fontWeight(.medium).frame(width: 160, alignment: .leading)
                    TextField("", text: Binding(
                        get: { edits[c.key] ?? c.value ?? "" },
                        set: { edits[c.key] = $0 }
                    )).textFieldStyle(.roundedBorder)
                    Button(I18nManager.shared.t(.doc_admin_btn_save)) {
                        if let v = edits[c.key] {
                            bridge.updateSystemConfig(key: c.key, value: v) { _ in load() }
                        }
                    }.buttonStyle(.borderedProminent)
                }
            }
            if bridge.systemConfig.isEmpty && !loading { EmptyHint(text: I18nManager.shared.t(.doc_admin_empty_sysconfig)) }
        }
        .onAppear { if bridge.systemConfig.isEmpty { load() } }
    }

    private func load() {
        loading = true
        bridge.fetchSystemConfig { _ in DispatchQueue.main.async { loading = false } }
    }
}

// MARK: - Export

private struct ExportPanel: View {
    @Environment(\.studioTheme) private var theme
    @ObservedObject var bridge: DocBridge
    @State private var bookId = ""
    @State private var format = "pdf"
    @State private var loading = false
    @State private var error: String?

    private let formats = ["pdf", "docx", "epub", "html", "markdown"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelHeader(title: I18nManager.shared.t(.doc_admin_panel_export))
            HStack {
                TextField("Book ID", text: $bookId).textFieldStyle(.roundedBorder)
                Picker(I18nManager.shared.t(.doc_admin_label_format), selection: $format) {
                    ForEach(formats, id: \.self) { Text($0).tag($0) }
                }.pickerStyle(.menu).frame(width: 110)
                Button(I18nManager.shared.t(.doc_admin_btn_export)) { exportBook() }.buttonStyle(.borderedProminent).disabled(bookId.isEmpty || loading)
                if loading { ProgressView().controlSize(.small) }
            }
            if let err = error { ErrorLine(message: err) }
            if !bridge.exportJobs.isEmpty {
                Text(I18nManager.shared.t(.doc_admin_label_export_jobs)).font(.subheadline).fontWeight(.medium)
                ForEach(bridge.exportJobs) { job in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(job.id).font(.system(.caption, design: .monospaced))
                            HStack {
                                Text(job.status ?? "-").font(.caption)
                                if let p = job.progress { ProgressView(value: p).frame(width: 80) }
                            }
                        }
                        Spacer()
                        Button(I18nManager.shared.t(.doc_admin_btn_refresh_status)) {
                            bridge.fetchExportStatus(jobId: job.id) { res in
                                DispatchQueue.main.async {
                                    if case .success(let updated) = res {
                                        if let idx = bridge.exportJobs.firstIndex(where: { $0.id == job.id }) {
                                            bridge.exportJobs[idx] = updated
                                        }
                                    }
                                }
                            }
                        }.buttonStyle(.bordered)
                    }
                    .padding(10).background(theme.surfaceSecondary).cornerRadius(8)
                }
            }
        }
    }

    private func exportBook() {
        loading = true; error = nil
        bridge.exportBook(bookId: bookId, format: format) { res in
            DispatchQueue.main.async {
                loading = false
                if case .failure(let err) = res { error = err.localizedDescription }
            }
        }
    }
}

// MARK: - RAG

private struct RAGPanel: View {
    @Environment(\.studioTheme) private var theme
    @ObservedObject var bridge: DocBridge
    @State private var status: [String: String] = [:]
    @State private var embedContent = ""
    @State private var loading = false
    @State private var msg: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { PanelHeader(title: I18nManager.shared.t(.doc_admin_panel_rag)); Spacer(); Button(I18nManager.shared.t(.doc_admin_btn_refresh_status)) { loadStatus() }.buttonStyle(.bordered) }
            if loading { ProgressView() }
            if !status.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(status.sorted(by: { $0.key < $1.key }), id: \.key) { kv in
                        Text("\(kv.key): \(kv.value)").font(.system(.caption, design: .monospaced))
                    }
                }
                .padding(10).background(theme.surfaceSecondary).cornerRadius(8)
            }
            HStack {
                Button(I18nManager.shared.t(.doc_admin_btn_build_index)) { runOp(bridge.buildRAGIndex, label: "build") }.buttonStyle(.borderedProminent)
                Button(I18nManager.shared.t(.doc_admin_btn_clear_index)) { runOp(bridge.clearRAGIndex, label: "clear") }.buttonStyle(.bordered)
            }
            Text(I18nManager.shared.t(.doc_admin_label_embed_content)).font(.caption).foregroundColor(theme.textSecondary)
            TextField(I18nManager.shared.t(.doc_admin_label_input_text), text: $embedContent, axis: .vertical).textFieldStyle(.roundedBorder).lineLimit(2...4)
            Button(I18nManager.shared.t(.doc_admin_btn_embed)) {
                bridge.embedRAGContent(content: embedContent) { res in
                    DispatchQueue.main.async {
                        msg = formatBoolResult(res, label: "embed")
                    }
                }
            }.buttonStyle(.bordered).disabled(embedContent.isEmpty)
            if let m = msg { Text(m).font(.caption).foregroundColor(theme.textSecondary) }
        }
        .onAppear { loadStatus() }
    }

    private func loadStatus() {
        loading = true
        bridge.fetchRAGStatus { res in
            DispatchQueue.main.async {
                loading = false
                if case .success(let s) = res { status = s }
            }
        }
    }

    private func runOp(_ fn: (@escaping (Result<[String: Bool], Error>) -> Void) -> Void, label: String) {
        loading = true
        fn { res in
            DispatchQueue.main.async {
                loading = false
                msg = formatBoolResult(res, label: label)
            }
        }
    }

    private func formatBoolResult(_ res: Result<[String: Bool], Error>, label: String) -> String {
        switch res {
        case .success(let d): return "\(label): " + d.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        case .failure(let e): return I18nManager.shared.tf(.doc_admin_err_failed, label, e.localizedDescription)
        }
    }
}

// MARK: - Graph Search

private struct GraphPanel: View {
    @Environment(\.studioTheme) private var theme
    @ObservedObject var bridge: DocBridge
    @State private var query = ""
    @State private var startId = ""
    @State private var depth = 3
    @State private var graph: DocGraph?
    @State private var clusterResult = ""
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelHeader(title: I18nManager.shared.t(.doc_admin_panel_graph))
            if loading { ProgressView() }
            if let err = error { ErrorLine(message: err) }
            VStack(alignment: .leading, spacing: 6) {
                Text(I18nManager.shared.t(.doc_admin_label_semantic_search)).font(.subheadline).fontWeight(.medium)
                HStack {
                    TextField(I18nManager.shared.t(.doc_admin_label_query_ph), text: $query).textFieldStyle(.roundedBorder)
                    Button(I18nManager.shared.t(.doc_admin_btn_search)) { search() }.buttonStyle(.borderedProminent).disabled(query.isEmpty)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(I18nManager.shared.t(.doc_admin_label_graph_traverse)).font(.subheadline).fontWeight(.medium)
                HStack {
                    TextField(I18nManager.shared.t(.doc_admin_label_start_node), text: $startId).textFieldStyle(.roundedBorder)
                    Stepper(I18nManager.shared.tf(.doc_admin_fmt_depth, depth), value: $depth, in: 1...10)
                    Button(I18nManager.shared.t(.doc_admin_btn_traverse)) { traverse() }.buttonStyle(.bordered).disabled(startId.isEmpty)
                }
            }
            HStack {
                Button(I18nManager.shared.t(.doc_admin_btn_cluster)) { cluster() }.buttonStyle(.bordered)
            }
            if let g = graph {
                Text(I18nManager.shared.tf(.doc_admin_fmt_graph_result, g.nodes.count, g.edges.count)).font(.caption).foregroundColor(theme.textSecondary)
                ForEach(g.nodes.prefix(20)) { n in
                    HStack {
                        Image(systemName: "circle.fill").foregroundColor(theme.accent).font(.system(size: 6))
                        Text(n.title)
                        if let t = n.type { Text(t).font(.caption).foregroundColor(theme.textSecondary) }
                    }
                }
            }
            if !clusterResult.isEmpty {
                Text(I18nManager.shared.t(.doc_admin_label_cluster_result)).font(.caption).foregroundColor(theme.textSecondary)
                Text(clusterResult).font(.system(.caption, design: .monospaced))
                    .padding(10).background(theme.surfaceSecondary).cornerRadius(8)
            }
        }
    }

    private func search() {
        loading = true; error = nil; graph = nil
        bridge.graphSemanticSearch(query: query) { res in
            DispatchQueue.main.async {
                loading = false
                switch res {
                case .success(let g): graph = g
                case .failure(let e): error = e.localizedDescription
                }
            }
        }
    }

    private func traverse() {
        loading = true; error = nil; graph = nil
        bridge.graphTraverse(startId: startId, maxDepth: depth) { res in
            DispatchQueue.main.async {
                loading = false
                switch res {
                case .success(let g): graph = g
                case .failure(let e): error = e.localizedDescription
                }
            }
        }
    }

    private func cluster() {
        loading = true; error = nil; clusterResult = ""
        bridge.graphCluster { res in
            DispatchQueue.main.async {
                loading = false
                switch res {
                case .success(let clusters):
                    clusterResult = clusters.map { (k, v) in I18nManager.shared.tf(.doc_admin_fmt_cluster_line, k, v.count) }.joined(separator: "\n")
                case .failure(let e): error = e.localizedDescription
                }
            }
        }
    }
}

// MARK: - Notifications

private struct NotificationPanel: View {
    @Environment(\.studioTheme) private var theme
    @ObservedObject var bridge: DocBridge
    @State private var loading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { PanelHeader(title: I18nManager.shared.t(.doc_admin_panel_notifications)); Spacer()
                Button(I18nManager.shared.t(.doc_admin_btn_mark_all_read)) {
                    bridge.markAllNotificationsRead { _ in load() }
                }.buttonStyle(.bordered)
                Button(I18nManager.shared.t(.doc_admin_btn_refresh)) { load() }.buttonStyle(.bordered)
            }
            if loading { ProgressView() }
            if bridge.notifications.isEmpty && !loading {
                EmptyHint(text: I18nManager.shared.t(.doc_admin_empty_notifications))
            } else {
                ForEach(bridge.notifications) { n in
                    HStack {
                        Image(systemName: n.is_read == true ? "envelope.open" : "envelope.fill")
                            .foregroundColor(n.is_read == true ? theme.textSecondary : theme.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(n.message ?? n.id)
                            if let t = n.type { Text(t).font(.caption).foregroundColor(theme.textSecondary) }
                        }
                        Spacer()
                        if n.is_read != true {
                            Button(I18nManager.shared.t(.doc_admin_btn_mark_read)) {
                                bridge.markNotificationRead(id: n.id) { _ in load() }
                            }.buttonStyle(.bordered).controlSize(.small)
                        }
                    }
                    .padding(10).background(theme.surfaceSecondary).cornerRadius(8)
                }
            }
        }
        .onAppear { load() }
    }

    private func load() {
        loading = true
        bridge.fetchNotifications { _ in DispatchQueue.main.async { loading = false } }
    }
}
