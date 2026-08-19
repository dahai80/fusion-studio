import SwiftUI
import os.log

private let fsbLog = Logger(subsystem: "com.fusion.studio", category: "FSB")

struct FSBWorkspaceView: View {
    @EnvironmentObject var ipc: IPCClient
    @EnvironmentObject var appState: AppState
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    @State private var workspaces: [[String: Any]] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var isGridView = true
    @State private var selectedWsId: String? = nil
    @State private var showCreateDialog = false
    @State private var showRenameDialog = false
    @State private var renameWsId = ""
    @State private var renameWsName = ""
    @State private var showExportSheet = false
    @State private var exportData: String = ""
    @State private var fsbAvailable = false
    @State private var showOnboarding = false

    var body: some View {
        HStack(spacing: 0) {
            workspaceListPanel
            if let wsId = selectedWsId {
                FSBWorkbenchView(workspaceId: wsId, onBack: { selectedWsId = nil })
            } else {
                emptyStatePanel
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            checkFSBHealth()
            loadWorkspaces()
        }
        .sheet(isPresented: $showCreateDialog) {
            FSBCreateWorkspaceDialog(
                ipc: ipc,
                onCreate: { title, desc, projectId in
                    createWorkspace(title: title, desc: desc, projectId: projectId)
                }
            )
        }
        .alert(i18n.t(.fsb_ws_renameAlertTitle), isPresented: $showRenameDialog) {
            TextField(i18n.t(.fsb_ws_name), text: $renameWsName)
            Button(i18n.t(.confirm)) { renameWorkspace() }
            Button(i18n.t(.cancel), role: .cancel) {}
        }
        .sheet(isPresented: $showExportSheet) {
            VStack(spacing: theme.spacingM) {
                Text(i18n.t(.fsb_ws_exportTitle))
                    .font(.system(size: theme.headlineSize, weight: .bold))
                TextEditor(text: .constant(exportData))
                    .font(.system(size: theme.captionSize, design: .monospaced))
                    .frame(minWidth: 500, minHeight: 300)
                HStack {
                    Button(i18n.t(.fsb_ws_copyClipboard)) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(exportData, forType: .string)
                    }
                    .buttonStyle(.borderedProminent)
                    Button(i18n.t(.close)) { showExportSheet = false }
                }
            }
            .padding(theme.spacingL)
            .frame(minWidth: 560, minHeight: 400)
        }
        .sheet(isPresented: $showOnboarding) {
            FSBOnboardingDialog()
        }
    }

    private var workspaceListPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBar
            searchBar
            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if filteredWorkspaces.isEmpty {
                Spacer()
                VStack(spacing: theme.spacingS) {
                    Image(systemName: "storefront")
                        .font(.system(size: 32))
                        .foregroundStyle(theme.textTertiary)
                    Text(searchText.isEmpty ? i18n.t(.fsb_ws_emptyWorkspaces) : i18n.t(.fsb_ws_noMatch))
                        .foregroundStyle(theme.textSecondary)
                        .font(.system(size: theme.textSize))
                    if searchText.isEmpty {
                        Button(action: { showCreateDialog = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text(i18n.t(.fsb_ws_createWs))
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                Spacer()
            } else {
                if isGridView {
                    gridView
                } else {
                    listView
                }
            }
        }
        .frame(width: 300)
        .background(theme.contentBg)
    }

    private var headerBar: some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: "storefront")
                .foregroundStyle(theme.accent)
            Text(i18n.t(.fsb_ws_headerTitle))
                .font(.system(size: theme.textSize, weight: .bold))
                .foregroundStyle(theme.text)
            Spacer()
            Button(action: { showCreateDialog = true }) {
                Image(systemName: "plus")
                    .foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)
            .help(i18n.t(.fsb_ws_newWs))
            Button(action: { isGridView.toggle() }) {
                Image(systemName: isGridView ? "list.bullet" : "square.grid.2x2")
                    .foregroundStyle(theme.textSecondary)
            }
            .buttonStyle(.plain)
            .help(isGridView ? i18n.t(.fsb_ws_listView) : i18n.t(.fsb_ws_gridView))
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
    }

    private var searchBar: some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(theme.textTertiary)
            TextField(i18n.t(.fsb_ws_searchPh), text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: theme.footnoteSize))
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(theme.spacingS)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .fill(theme.surfaceElevated)
        )
        .padding(.horizontal, theme.spacingM)
        .padding(.bottom, theme.spacingS)
    }

    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: theme.spacingS),
                GridItem(.flexible(), spacing: theme.spacingS)
            ], spacing: theme.spacingS) {
                ForEach(filteredWorkspaces.indices, id: \.self) { idx in
                    let ws = filteredWorkspaces[idx]
                    workspaceGridCard(ws: ws)
                }
            }
            .padding(theme.spacingM)
        }
    }

    private var listView: some View {
        List {
            ForEach(filteredWorkspaces.indices, id: \.self) { idx in
                let ws = filteredWorkspaces[idx]
                workspaceListRow(ws: ws)
            }
        }
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private func workspaceGridCard(ws: [String: Any]) -> some View {
        let wsId = ws["wsId"] as? String ?? ws["id"] as? String ?? ""
        let title = ws["title"] as? String ?? ws["name"] as? String ?? i18n.t(.fsb_unnamed)
        let desc = ws["description"] as? String ?? ""
        let connectorCount = (ws["connectorIds"] as? [String])?.count ?? 0
        let skillCount = (ws["skillIds"] as? [String])?.count ?? 0
        let wfCount = (ws["workflowIds"] as? [String])?.count ?? 0

        VStack(alignment: .leading, spacing: theme.spacingS) {
            HStack {
                Image(systemName: "storefront")
                    .foregroundStyle(theme.accent)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                Spacer()
                wsContextMenu(wsId: wsId, ws: ws)
            }
            if !desc.isEmpty {
                Text(desc)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
            }
            HStack(spacing: theme.spacingM) {
                Label("\(connectorCount)", systemImage: "plug")
                Label("\(skillCount)", systemImage: "star")
                Label("\(wfCount)", systemImage: "flowchart")
            }
            .font(.system(size: theme.captionSize))
            .foregroundStyle(theme.textTertiary)
        }
        .padding(theme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .fill(selectedWsId == wsId ? theme.accentSoft : theme.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .stroke(selectedWsId == wsId ? theme.accent : Color.clear, lineWidth: 1.5)
        )
        .onTapGesture { selectedWsId = wsId }
    }

    @ViewBuilder
    private func workspaceListRow(ws: [String: Any]) -> some View {
        let wsId = ws["wsId"] as? String ?? ws["id"] as? String ?? ""
        let title = ws["title"] as? String ?? ws["name"] as? String ?? i18n.t(.fsb_unnamed)
        let desc = ws["description"] as? String ?? ""
        let connectorCount = (ws["connectorIds"] as? [String])?.count ?? 0
        let wfCount = (ws["workflowIds"] as? [String])?.count ?? 0

        HStack(spacing: theme.spacingS) {
            Image(systemName: "storefront")
                .foregroundStyle(selectedWsId == wsId ? theme.accent : theme.textTertiary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(selectedWsId == wsId ? theme.accent : theme.text)
                    .lineLimit(1)
                HStack(spacing: theme.spacingS) {
                    if !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(1)
                    }
                    Text(String(format: i18n.t(.fsb_ws_connWfFmt), connectorCount, wfCount))
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                }
            }
            Spacer()
            wsContextMenu(wsId: wsId, ws: ws)
        }
        .padding(.vertical, theme.spacingXS)
        .contentShape(Rectangle())
        .onTapGesture { selectedWsId = wsId }
    }

    @ViewBuilder
    private func wsContextMenu(wsId: String, ws: [String: Any]) -> some View {
        Menu {
            Button(action: { selectedWsId = wsId }) {
                Label(i18n.t(.fsb_ws_open), systemImage: "arrow.right.circle")
            }
            Button(action: {
                renameWsId = wsId
                renameWsName = ws["title"] as? String ?? ws["name"] as? String ?? ""
                showRenameDialog = true
            }) {
                Label(i18n.t(.fsb_ws_rename), systemImage: "pencil")
            }
            Button(action: { duplicateWorkspace(wsId) }) {
                Label(i18n.t(.fsb_ws_duplicate), systemImage: "doc.on.doc")
            }
            Divider()
            Button(action: { exportWorkspace(wsId) }) {
                Label(i18n.t(.fsb_ws_export), systemImage: "square.and.arrow.up")
            }
            Divider()
            Button(role: .destructive, action: { deleteWorkspace(wsId) }) {
                Label(i18n.t(.delete), systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .foregroundStyle(theme.textTertiary)
                .font(.system(size: 12))
        }
        .menuStyle(.borderlessButton)
        .frame(width: 20, height: 20)
    }

    private var emptyStatePanel: some View {
        VStack(spacing: theme.spacingL) {
            Image(systemName: "storefront")
                .font(.system(size: 56))
                .foregroundStyle(theme.textTertiary)
            VStack(spacing: theme.spacingXS) {
                Text("Fusion Small Business")
                    .font(.system(size: theme.headlineSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Text(i18n.t(.fsb_ws_subtitle))
                    .font(.system(size: theme.textSize))
                    .foregroundStyle(theme.textSecondary)
            }
            if !fsbAvailable {
                Label(i18n.t(.fsb_ws_serviceDown), systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .font(.system(size: theme.footnoteSize))
            }
            HStack(spacing: theme.spacingM) {
                Button(action: { showCreateDialog = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text(i18n.t(.fsb_ws_createWs))
                    }
                }
                .buttonStyle(.borderedProminent)
                Button(action: { showOnboarding = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "book")
                        Text(i18n.t(.fsb_ws_usageGuide))
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.contentBg)
    }

    private var filteredWorkspaces: [[String: Any]] {
        if searchText.isEmpty { return workspaces }
        return workspaces.filter { ws in
            let title = (ws["title"] as? String ?? ws["name"] as? String ?? "").lowercased()
            let desc = (ws["description"] as? String ?? "").lowercased()
            let q = searchText.lowercased()
            return title.contains(q) || desc.contains(q)
        }
    }

    private func checkFSBHealth() {
        Task {
            do {
                _ = try await ipc.fsbHealth()
                await MainActor.run { fsbAvailable = true }
                fsbLog.info("FSB service is available")
            } catch {
                await MainActor.run { fsbAvailable = false }
                fsbLog.warning("FSB service unavailable: \(error.localizedDescription)")
            }
        }
    }

    private func loadWorkspaces() {
        isLoading = true
        Task {
            do {
                let items = try await ipc.fsbListWorkspaces(search: searchText)
                await MainActor.run { workspaces = items }
            } catch {
                fsbLog.error("workspace list failed: \(error.localizedDescription)")
            }
            await MainActor.run { isLoading = false }
        }
    }

    private func createWorkspace(title: String, desc: String, projectId: String?) {
        Task {
            do {
                _ = try await ipc.fsbCreateWorkspace(
                    title: title,
                    description: desc,
                    projectId: projectId?.isEmpty == true ? nil : projectId
                )
                fsbLog.info("workspace created: \(title)")
                loadWorkspaces()
            } catch {
                fsbLog.error("workspace create failed: \(error.localizedDescription)")
            }
        }
    }

    private func renameWorkspace() {
        guard !renameWsName.isEmpty else { return }
        Task {
            do {
                _ = try await ipc.fsbUpdateWorkspace(wsId: renameWsId, title: renameWsName)
                fsbLog.info("workspace renamed: \(renameWsId)")
                loadWorkspaces()
            } catch {
                fsbLog.error("workspace rename failed: \(error.localizedDescription)")
            }
        }
    }

    private func duplicateWorkspace(_ wsId: String) {
        Task {
            do {
                _ = try await ipc.fsbDuplicateWorkspace(wsId: wsId)
                fsbLog.info("workspace duplicated: \(wsId)")
                loadWorkspaces()
            } catch {
                fsbLog.error("workspace duplicate failed: \(error.localizedDescription)")
            }
        }
    }

    private func exportWorkspace(_ wsId: String) {
        Task {
            do {
                let result = try await ipc.fsbExportWorkspace(wsId: wsId)
                let jsonData = try JSONSerialization.data(
                    withJSONObject: result,
                    options: [.prettyPrinted, .sortedKeys]
                )
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
                await MainActor.run {
                    exportData = jsonString
                    showExportSheet = true
                }
            } catch {
                fsbLog.error("workspace export failed: \(error.localizedDescription)")
            }
        }
    }

    private func deleteWorkspace(_ wsId: String) {
        Task {
            do {
                _ = try await ipc.fsbDeleteWorkspace(wsId: wsId)
                fsbLog.info("workspace deleted: \(wsId)")
                if selectedWsId == wsId { selectedWsId = nil }
                loadWorkspaces()
            } catch {
                fsbLog.error("workspace delete failed: \(error.localizedDescription)")
            }
        }
    }
}

struct FSBCreateWorkspaceDialog: View {
    @Environment(\.studioTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @StateObject private var i18n = I18nManager.shared

    let ipc: IPCClient
    let onCreate: (String, String, String?) -> Void

    @State private var title = ""
    @State private var description = ""
    @State private var projectId = ""
    @State private var bindAgentId = ""
    @State private var showTemplateImport = false

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            Text(i18n.t(.fsb_ws_newWs))
                .font(.system(size: theme.headlineSize, weight: .bold))
                .foregroundStyle(theme.text)

            VStack(alignment: .leading, spacing: theme.spacingS) {
                Text(i18n.t(.fsb_ws_name))
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                TextField(i18n.t(.fsb_ws_namePh), text: $title)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: theme.spacingS) {
                Text(i18n.t(.fsb_ws_descOpt))
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                TextField(i18n.t(.fsb_ws_descPh), text: $description)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: theme.spacingS) {
                Text(i18n.t(.fsb_ws_bindProjectOpt))
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                TextField(i18n.t(.fsb_ws_projectIdPh), text: $projectId)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: theme.spacingS) {
                Text(i18n.t(.fsb_ws_bindAgentOpt))
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                TextField("Agent ID", text: $bindAgentId)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button(action: { showTemplateImport = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.badge.plus")
                        Text(i18n.t(.fsb_ws_importTemplate))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Spacer()
                Button(i18n.t(.cancel)) { dismiss() }
                    .controlSize(.small)
                Button(i18n.t(.fsb_ws_createBtn)) {
                    onCreate(title, description, projectId.isEmpty ? nil : projectId)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(title.isEmpty)
            }

            if showTemplateImport {
                Divider()
                Text(i18n.t(.fsb_ws_builtinTemplates))
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                FSBTemplateGallery { templateName in
                    title = templateName
                    showTemplateImport = false
                }
            }
        }
        .padding(theme.spacingL)
        .frame(width: 420)
    }
}

struct FSBTemplateGallery: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    let onSelect: (String) -> Void

    private let templates: [(nameKey: I18nKey, shortKey: I18nKey, descKey: I18nKey, icon: String)] = [
        (.fsb_tpl_crm_name, .fsb_tpl_crm_short, .fsb_tpl_crm_desc, "person.2"),
        (.fsb_tpl_inventory_name, .fsb_tpl_inventory_short, .fsb_tpl_inventory_desc, "archivebox"),
        (.fsb_tpl_finance_name, .fsb_tpl_finance_short, .fsb_tpl_finance_desc, "chart.bar"),
        (.fsb_tpl_email_name, .fsb_tpl_email_short, .fsb_tpl_email_desc, "envelope"),
        (.fsb_tpl_social_name, .fsb_tpl_social_short, .fsb_tpl_social_desc, "shareplay"),
        (.fsb_tpl_ticket_name, .fsb_tpl_ticket_short, .fsb_tpl_ticket_desc, "ticket"),
    ]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: theme.spacingS) {
            ForEach(templates, id: \.nameKey) { tpl in
                Button(action: { onSelect(i18n.t(tpl.nameKey)) }) {
                    VStack(alignment: .leading, spacing: theme.spacingXS) {
                        HStack {
                            Image(systemName: tpl.icon)
                                .foregroundStyle(theme.accent)
                            Text(i18n.t(tpl.shortKey))
                                .font(.system(size: theme.captionSize, weight: .semibold))
                                .foregroundStyle(theme.text)
                        }
                        Text(i18n.t(tpl.descKey))
                            .font(.system(size: 11))
                            .foregroundStyle(theme.textTertiary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(theme.spacingS)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                            .fill(theme.surfaceElevated)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct FSBOnboardingDialog: View {
    @Environment(\.studioTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @StateObject private var i18n = I18nManager.shared

    @State private var step = 0

    private let steps: [(titleKey: I18nKey, descKey: I18nKey, icon: String)] = [
        (.fsb_ob_welcome_title, .fsb_ob_welcome_desc, "storefront"),
        (.fsb_ob_connectors_title, .fsb_ob_connectors_desc, "plug"),
        (.fsb_ob_skills_title, .fsb_ob_skills_desc, "star"),
        (.fsb_ob_workflow_title, .fsb_ob_workflow_desc, "flowchart"),
        (.fsb_ob_start_title, .fsb_ob_start_desc, "rocket"),
    ]

    var body: some View {
        VStack(spacing: theme.spacingL) {
            Spacer()
            Image(systemName: steps[step].icon)
                .font(.system(size: 48))
                .foregroundStyle(theme.accent)
            Text(i18n.t(steps[step].titleKey))
                .font(.system(size: theme.headlineSize, weight: .bold))
                .foregroundStyle(theme.text)
            Text(i18n.t(steps[step].descKey))
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            Spacer()
            HStack {
                if step > 0 {
                    Button(i18n.t(.fsb_ob_prev)) { step -= 1 }
                        .buttonStyle(.bordered)
                }
                Spacer()
                HStack(spacing: 6) {
                    ForEach(0..<steps.count, id: \.self) { i in
                        Circle()
                            .fill(i == step ? theme.accent : theme.separator)
                            .frame(width: 8, height: 8)
                    }
                }
                Spacer()
                if step < steps.count - 1 {
                    Button(i18n.t(.next)) { step += 1 }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button(i18n.t(.fsb_ob_start_title)) { dismiss() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(theme.spacingL)
        .frame(width: 500, height: 420)
    }
}
