import SwiftUI
import os.log

private let dlgLog = Logger(subsystem: "com.fusion.studio", category: "FSB.Dialogs")

struct FSBConnectorDialog: View {
    @Environment(\.studioTheme) private var theme
    @ObservedObject var ipc: IPCClient
    @Environment(\.dismiss) private var dismiss
    @StateObject private var i18n = I18nManager.shared

    let workspaceId: String
    let connectorMeta: [[String: Any]]
    let onDone: () -> Void

    @State private var selectedKey = ""
    @State private var authType = "oauth2"
    @State private var apiKey = ""
    @State private var clientId = ""
    @State private var clientSecret = ""
    @State private var redirectUri = ""
    @State private var scopes = ""
    @State private var isConnecting = false
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            dialogHeader(title: i18n.t(.fsb_dlg_addConnector))
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacingM) {
                    connectorPicker
                    if !selectedKey.isEmpty {
                        authTypeSection
                        if authType == "api_key" {
                            apiKeyFields
                        } else if authType == "oauth2" {
                            oauth2Fields
                        }
                    }
                    if let err = errorMessage {
                        Text(err)
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(.red)
                    }
                }
                .padding(theme.spacingL)
            }

            Divider()
            dialogFooter(
                primaryTitle: isConnecting ? i18n.t(.fsb_dlg_connecting) : i18n.t(.fsb_dlg_connect),
                primaryDisabled: selectedKey.isEmpty || isConnecting,
                onPrimary: connectConnector
            )
        }
        .frame(width: 480, height: 520)
    }

    private var connectorPicker: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text(i18n.t(.fsb_dlg_selectConnector))
                .font(.system(size: theme.footnoteSize, weight: .medium))
                .foregroundStyle(theme.text)
            Picker(i18n.t(.fsb_dlg_connector), selection: $selectedKey) {
                Text(i18n.t(.fsb_dlg_selectPh)).tag("")
                ForEach(connectorMeta.indices, id: \.self) { idx in
                    let key = connectorMeta[idx]["connectorKey"] as? String ?? ""
                    let display = connectorMeta[idx]["displayName"] as? String ?? key
                    Text(display).tag(key)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity)

            if !selectedKey.isEmpty {
                let meta = connectorMeta.first { ($0["connectorKey"] as? String ?? "") == selectedKey }
                if let desc = meta?["description"] as? String, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textSecondary)
                }
                if let authTypes = meta?["supportedAuthTypes"] as? [String] {
                    Text(String(format: i18n.t(.fsb_dlg_supportFmt), authTypes.joined(separator: ", ")))
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textTertiary)
                }
            }
        }
    }

    private var authTypeSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text(i18n.t(.fsb_dlg_authMethod))
                .font(.system(size: theme.footnoteSize, weight: .medium))
                .foregroundStyle(theme.text)
            Picker(i18n.t(.fsb_dlg_auth), selection: $authType) {
                Text("OAuth 2.0").tag("oauth2")
                Text("API Key").tag("api_key")
                Text(i18n.t(.fsb_dlg_noAuth)).tag("none")
            }
            .pickerStyle(.segmented)
        }
    }

    private var apiKeyFields: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            fieldLabel("API Key")
            SecureField(i18n.t(.fsb_dlg_enterApiKey), text: $apiKey)
                .textFieldStyle(.plain)
                .padding(theme.spacingS)
                .background(fieldBg)
                .overlay(fieldBorder)
        }
    }

    private var oauth2Fields: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            fieldLabel("Client ID")
            TextField("Client ID", text: $clientId)
                .textFieldStyle(.plain)
                .padding(theme.spacingS)
                .background(fieldBg)
                .overlay(fieldBorder)

            fieldLabel("Client Secret")
            SecureField("Client Secret", text: $clientSecret)
                .textFieldStyle(.plain)
                .padding(theme.spacingS)
                .background(fieldBg)
                .overlay(fieldBorder)

            fieldLabel("Redirect URI")
            TextField("https://...", text: $redirectUri)
                .textFieldStyle(.plain)
                .padding(theme.spacingS)
                .background(fieldBg)
                .overlay(fieldBorder)

            fieldLabel(i18n.t(.fsb_dlg_scopesHint))
            TextField("read,write", text: $scopes)
                .textFieldStyle(.plain)
                .padding(theme.spacingS)
                .background(fieldBg)
                .overlay(fieldBorder)
        }
    }

    private func connectConnector() {
        isConnecting = true
        errorMessage = nil
        var authConfig: [String: Any] = [:]
        if authType == "api_key" {
            authConfig = ["apiKey": apiKey]
        } else if authType == "oauth2" {
            authConfig = [
                "clientId": clientId,
                "clientSecret": clientSecret,
                "redirectUri": redirectUri,
                "scopes": scopes
            ]
        }
        Task {
            do {
                _ = try await ipc.fsbCreateConnector(
                    wsId: workspaceId,
                    connectorKey: selectedKey,
                    authType: authType,
                    authConfig: authConfig
                )
                dlgLog.info("connector created: \(selectedKey)")
                await MainActor.run {
                    isConnecting = false
                    onDone()
                    dismiss()
                }
            } catch {
                dlgLog.error("connector create failed: \(error.localizedDescription)")
                await MainActor.run {
                    isConnecting = false
                    errorMessage = BridgeError.sanitize(error)
                }
            }
        }
    }

    @ViewBuilder private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: theme.captionSize, weight: .medium))
            .foregroundStyle(theme.textSecondary)
    }

    private var fieldBg: some View {
        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
            .fill(theme.surfaceElevated)
    }

    private var fieldBorder: some View {
        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
            .stroke(theme.separator, lineWidth: 0.5)
    }

    @ViewBuilder private func dialogHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: theme.textSize, weight: .semibold))
                .foregroundStyle(theme.text)
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(theme.spacingM)
    }

    @ViewBuilder private func dialogFooter(primaryTitle: String, primaryDisabled: Bool = false, onPrimary: @escaping () -> Void) -> some View {
        HStack {
            Button(i18n.t(.cancel)) { dismiss() }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            Spacer()
            Button(action: onPrimary) {
                Text(primaryTitle)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(primaryDisabled)
        }
        .padding(theme.spacingM)
    }
}

struct FSBSkillDialog: View {
    @Environment(\.studioTheme) private var theme
    @ObservedObject var ipc: IPCClient
    @Environment(\.dismiss) private var dismiss
    @StateObject private var i18n = I18nManager.shared

    let workspaceId: String
    let onDone: () -> Void

    @State private var skillName = ""
    @State private var displayName = ""
    @State private var skillType = "prompt"
    @State private var definition = ""
    @State private var inputSchema = ""
    @State private var outputFormat = "text"
    @State private var isSaving = false
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            dialogHeader(title: i18n.t(.fsb_dlg_createSkill))
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacingM) {
                    fieldLabel(i18n.t(.fsb_dlg_skillName))
                    TextField("skill_name", text: $skillName)
                        .textFieldStyle(.plain)
                        .font(.system(size: theme.captionSize, design: .monospaced))
                        .padding(theme.spacingS)
                        .background(fieldBg)
                        .overlay(fieldBorder)

                    fieldLabel(i18n.t(.fsb_dlg_displayName))
                    TextField(i18n.t(.fsb_dlg_mySkill), text: $displayName)
                        .textFieldStyle(.plain)
                        .padding(theme.spacingS)
                        .background(fieldBg)
                        .overlay(fieldBorder)

                    fieldLabel(i18n.t(.fsb_dlg_type))
                    Picker(i18n.t(.fsb_dlg_type), selection: $skillType) {
                        Text(i18n.t(.fsb_dlg_prompt)).tag("prompt")
                        Text(i18n.t(.fsb_dlg_function)).tag("function")
                        Text(i18n.t(.fsb_dlg_chain)).tag("chain")
                    }
                    .pickerStyle(.segmented)

                    fieldLabel(i18n.t(.fsb_dlg_definition))
                    TextEditor(text: $definition)
                        .font(.system(size: theme.captionSize, design: .monospaced))
                        .frame(height: 120)
                        .padding(theme.spacingXS)
                        .background(fieldBg)
                        .overlay(fieldBorder)

                    fieldLabel(i18n.t(.fsb_dlg_inputSchema))
                    TextEditor(text: $inputSchema)
                        .font(.system(size: theme.captionSize, design: .monospaced))
                        .frame(height: 80)
                        .padding(theme.spacingXS)
                        .background(fieldBg)
                        .overlay(fieldBorder)

                    fieldLabel(i18n.t(.fsb_dlg_outputFormat))
                    Picker(i18n.t(.fsb_dlg_outputFormat), selection: $outputFormat) {
                        Text(i18n.t(.fsb_dlg_plainText)).tag("text")
                        Text("JSON").tag("json")
                        Text("Markdown").tag("markdown")
                    }
                    .pickerStyle(.segmented)

                    if let err = errorMessage {
                        Text(err)
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(.red)
                    }
                }
                .padding(theme.spacingL)
            }

            Divider()
            dialogFooter(
                primaryTitle: isSaving ? i18n.t(.fsb_dlg_saving) : i18n.t(.fsb_dlg_create),
                primaryDisabled: skillName.isEmpty || isSaving,
                onPrimary: createSkill
            )
        }
        .frame(width: 480, height: 600)
    }

    private func createSkill() {
        isSaving = true
        errorMessage = nil
        var schemaDict: [String: Any] = [:]
        if !inputSchema.isEmpty,
           let data = inputSchema.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            schemaDict = obj
        }
        Task {
            do {
                _ = try await ipc.fsbCreateSkill(
                    wsId: workspaceId,
                    name: skillName,
                    displayName: displayName.isEmpty ? skillName : displayName,
                    type: skillType,
                    definition: definition
                )
                dlgLog.info("skill created: \(skillName)")
                await MainActor.run {
                    isSaving = false
                    onDone()
                    dismiss()
                }
            } catch {
                dlgLog.error("skill create failed: \(error.localizedDescription)")
                await MainActor.run {
                    isSaving = false
                    errorMessage = BridgeError.sanitize(error)
                }
            }
        }
    }

    @ViewBuilder private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: theme.captionSize, weight: .medium))
            .foregroundStyle(theme.textSecondary)
    }

    private var fieldBg: some View {
        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
            .fill(theme.surfaceElevated)
    }

    private var fieldBorder: some View {
        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
            .stroke(theme.separator, lineWidth: 0.5)
    }

    @ViewBuilder private func dialogHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: theme.textSize, weight: .semibold))
                .foregroundStyle(theme.text)
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(theme.spacingM)
    }

    @ViewBuilder private func dialogFooter(primaryTitle: String, primaryDisabled: Bool = false, onPrimary: @escaping () -> Void) -> some View {
        HStack {
            Button(i18n.t(.cancel)) { dismiss() }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            Spacer()
            Button(action: onPrimary) {
                Text(primaryTitle)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(primaryDisabled)
        }
        .padding(theme.spacingM)
    }
}

struct FSBScheduleDialog: View {
    @Environment(\.studioTheme) private var theme
    @ObservedObject var ipc: IPCClient
    @Environment(\.dismiss) private var dismiss
    @StateObject private var i18n = I18nManager.shared

    let workspaceId: String
    let wfId: String
    let onDone: () -> Void

    @State private var scheduleType = "manual"
    @State private var cronExpr = "0 9 * * 1-5"
    @State private var eventTrigger = ""
    @State private var isSaving = false
    @State private var errorMessage: String? = nil

    private let cronPresets: [(labelKey: I18nKey, expr: String)] = [
        (.fsb_dlg_preset_weekday9, "0 9 * * 1-5"),
        (.fsb_dlg_preset_hourly, "0 * * * *"),
        (.fsb_dlg_preset_daily8, "0 8 * * *"),
        (.fsb_dlg_preset_monday9, "0 9 * * 1"),
        (.fsb_dlg_preset_month1, "0 9 1 * *"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            dialogHeader(title: i18n.t(.fsb_dlg_setSchedule))
            Divider()

            VStack(alignment: .leading, spacing: theme.spacingM) {
                fieldLabel(i18n.t(.fsb_dlg_triggerMethod))
                Picker(i18n.t(.fsb_dlg_triggerMethod), selection: $scheduleType) {
                    Text(i18n.t(.fsb_dlg_manual)).tag("manual")
                    Text(i18n.t(.fsb_dlg_cron)).tag("cron")
                    Text(i18n.t(.fsb_dlg_eventDriven)).tag("event")
                }
                .pickerStyle(.segmented)

                if scheduleType == "cron" {
                    cronSection
                } else if scheduleType == "event" {
                    eventSection
                } else {
                    Text(i18n.t(.fsb_dlg_manualOnly))
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                        .padding(theme.spacingS)
                }

                if let err = errorMessage {
                    Text(err)
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(.red)
                }
            }
            .padding(theme.spacingL)

            Spacer()
            Divider()
            dialogFooter(
                primaryTitle: isSaving ? i18n.t(.fsb_dlg_saving) : i18n.t(.save),
                primaryDisabled: isSaving,
                onPrimary: saveSchedule
            )
        }
        .frame(width: 440, height: 440)
    }

    private var cronSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            fieldLabel(i18n.t(.fsb_dlg_cronExpr))
            TextField("0 9 * * 1-5", text: $cronExpr)
                .textFieldStyle(.plain)
                .font(.system(size: theme.footnoteSize, design: .monospaced))
                .padding(theme.spacingS)
                .background(fieldBg)
                .overlay(fieldBorder)

            fieldLabel(i18n.t(.fsb_dlg_commonPresets))
            ForEach(cronPresets.indices, id: \.self) { idx in
                Button(action: { cronExpr = cronPresets[idx].expr }) {
                    HStack {
                        Text(i18n.t(cronPresets[idx].labelKey))
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(theme.text)
                        Spacer()
                        Text(cronPresets[idx].expr)
                            .font(.system(size: theme.captionSize, design: .monospaced))
                            .foregroundStyle(theme.textTertiary)
                    }
                    .padding(theme.spacingXS)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                            .fill(theme.surfaceElevated)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var eventSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            fieldLabel(i18n.t(.fsb_dlg_eventTrigger))
            TextField(i18n.t(.fsb_dlg_eventPh), text: $eventTrigger)
                .textFieldStyle(.plain)
                .font(.system(size: theme.footnoteSize))
                .padding(theme.spacingS)
                .background(fieldBg)
                .overlay(fieldBorder)

            Text(i18n.t(.fsb_dlg_eventHint))
                .font(.system(size: 11))
                .foregroundStyle(theme.textTertiary)
        }
    }

    private func saveSchedule() {
        isSaving = true
        errorMessage = nil
        Task {
            do {
                _ = try await ipc.fsbSetSchedule(
                    wsId: workspaceId,
                    wfId: wfId,
                    type: scheduleType,
                    cron: scheduleType == "cron" ? cronExpr : nil,
                    eventTrigger: scheduleType == "event" ? eventTrigger : nil
                )
                dlgLog.info("schedule set for workflow: \(wfId)")
                await MainActor.run {
                    isSaving = false
                    onDone()
                    dismiss()
                }
            } catch {
                dlgLog.error("schedule set failed: \(error.localizedDescription)")
                await MainActor.run {
                    isSaving = false
                    errorMessage = BridgeError.sanitize(error)
                }
            }
        }
    }

    @ViewBuilder private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: theme.captionSize, weight: .medium))
            .foregroundStyle(theme.textSecondary)
    }

    private var fieldBg: some View {
        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
            .fill(theme.surfaceElevated)
    }

    private var fieldBorder: some View {
        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
            .stroke(theme.separator, lineWidth: 0.5)
    }

    @ViewBuilder private func dialogHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: theme.textSize, weight: .semibold))
                .foregroundStyle(theme.text)
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(theme.spacingM)
    }

    @ViewBuilder private func dialogFooter(primaryTitle: String, primaryDisabled: Bool = false, onPrimary: @escaping () -> Void) -> some View {
        HStack {
            Button(i18n.t(.cancel)) { dismiss() }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            Spacer()
            Button(action: onPrimary) {
                Text(primaryTitle)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(primaryDisabled)
        }
        .padding(theme.spacingM)
    }
}

struct FSBApprovalDialog: View {
    @Environment(\.studioTheme) private var theme
    @ObservedObject var ipc: IPCClient
    @Environment(\.dismiss) private var dismiss
    @StateObject private var i18n = I18nManager.shared

    let workspaceId: String
    let task: [String: Any]
    let onDone: () -> Void

    @State private var editContent = ""
    @State private var isProcessing = false
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            dialogHeader(title: i18n.t(.fsb_dlg_approvalRequest))
            Divider()

            VStack(alignment: .leading, spacing: theme.spacingM) {
                let taskTitle = task["title"] as? String ?? i18n.t(.fsb_dlg_approvalRequest)
                let content = task["content"] as? String ?? ""
                let status = task["status"] as? String ?? "pending"

                HStack {
                    Image(systemName: "hand.raised")
                        .foregroundStyle(.orange)
                    Text(taskTitle)
                        .font(.system(size: theme.textSize, weight: .semibold))
                        .foregroundStyle(theme.text)
                    Spacer()
                    Text(status)
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                        .padding(.horizontal, theme.spacingXS)
                        .padding(.vertical, 2)
                        .background(theme.accentSoft)
                        .cornerRadius(4)
                }

                if !content.isEmpty {
                    VStack(alignment: .leading, spacing: theme.spacingXS) {
                        fieldLabel(i18n.t(.fsb_dlg_requestContent))
                        Text(content)
                            .font(.system(size: theme.footnoteSize))
                            .foregroundStyle(theme.text)
                            .padding(theme.spacingS)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(fieldBg)
                            .overlay(fieldBorder)
                    }
                }

                fieldLabel(i18n.t(.fsb_dlg_editContent))
                TextEditor(text: $editContent)
                    .font(.system(size: theme.footnoteSize))
                    .frame(height: 80)
                    .padding(theme.spacingXS)
                    .background(fieldBg)
                    .overlay(fieldBorder)

                if let err = errorMessage {
                    Text(err)
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(.red)
                }
            }
            .padding(theme.spacingL)

            Spacer()
            Divider()

            HStack(spacing: theme.spacingM) {
                Button(i18n.t(.cancel)) { dismiss() }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                Spacer()
                Button(role: .destructive, action: { denyApproval() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                        Text(i18n.t(.fsb_dlg_reject))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(isProcessing)

                Button(action: { approveWithEdit() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                        Text(isProcessing ? i18n.t(.fsb_dlg_processing) : i18n.t(.fsb_dlg_approve))
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(isProcessing)
            }
            .padding(theme.spacingM)
        }
        .frame(width: 480, height: 400)
    }

    private func approveWithEdit() {
        guard let taskId = task["taskId"] as? String else { return }
        isProcessing = true
        errorMessage = nil
        Task {
            do {
                if !editContent.isEmpty {
                    _ = try await ipc.fsbEditTask(wsId: workspaceId, taskId: taskId, editContent: ["content": editContent])
                    dlgLog.info("task edited: \(taskId)")
                }
                _ = try await ipc.fsbApproveTask(wsId: workspaceId, taskId: taskId)
                dlgLog.info("task approved: \(taskId)")
                await MainActor.run {
                    isProcessing = false
                    onDone()
                    dismiss()
                }
            } catch {
                dlgLog.error("approval failed: \(error.localizedDescription)")
                await MainActor.run {
                    isProcessing = false
                    errorMessage = BridgeError.sanitize(error)
                }
            }
        }
    }

    private func denyApproval() {
        guard let taskId = task["taskId"] as? String else { return }
        isProcessing = true
        errorMessage = nil
        Task {
            do {
                _ = try await ipc.fsbDenyTask(wsId: workspaceId, taskId: taskId)
                dlgLog.info("task denied: \(taskId)")
                await MainActor.run {
                    isProcessing = false
                    onDone()
                    dismiss()
                }
            } catch {
                dlgLog.error("deny failed: \(error.localizedDescription)")
                await MainActor.run {
                    isProcessing = false
                    errorMessage = BridgeError.sanitize(error)
                }
            }
        }
    }

    @ViewBuilder private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: theme.captionSize, weight: .medium))
            .foregroundStyle(theme.textSecondary)
    }

    private var fieldBg: some View {
        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
            .fill(theme.surfaceElevated)
    }

    private var fieldBorder: some View {
        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
            .stroke(theme.separator, lineWidth: 0.5)
    }

    @ViewBuilder private func dialogHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: theme.textSize, weight: .semibold))
                .foregroundStyle(theme.text)
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(theme.spacingM)
    }
}
