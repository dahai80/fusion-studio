import SwiftUI
import os.log

private let eventStreamViewLog = Logger(subsystem: "com.fusion.studio", category: "EventStreamView")

// #346: fusion-event 事件感知面板。
// EventBridge 长连接消费 event.notification → SystemEvent, 规则管理 rule.add/remove/list。
// 状态: 守护在线/离线 (green/gray) + 版本 + uptime + triggers。近期事件 LRU 500 列表。
// 规则 CRUD: 列表 + 删除 (确认弹窗) + 添加表单 (sheet)。错误显示 sanitize 后 lastError。

struct EventStreamView: View {
    @EnvironmentObject var eventBridge: EventBridge
    @Environment(\.studioTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @StateObject private var i18n = I18nManager.shared
    @State private var showAddRule = false
    @State private var pendingDelete: EventRule?
    @State private var isRefreshing = false

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            headerRow
            if let error = eventBridge.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(theme.warningText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            statusSection
            eventsSection
            rulesSection
            Spacer()
        }
        .padding()
        .frame(width: 560, height: 560)
        .background(theme.windowBg)
        .sheet(isPresented: $showAddRule) {
            EventRuleAddForm(eventBridge: eventBridge)
        }
        .confirmationDialog(
            i18n.t(.event_rule_delete_confirm),
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { rule in
            Button(i18n.t(.event_rule_delete), role: .destructive) {
                Task {
                    do { try await eventBridge.removeRule(name: rule.ruleName) }
                    catch { eventStreamViewLog.error("removeRule failed: \(error.localizedDescription)") }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear {
            eventStreamViewLog.info("EventStreamView appeared ready=\(eventBridge.isDaemonReady) rules=\(eventBridge.rules.count) events=\(eventBridge.events.count)")
        }
    }

    private var headerRow: some View {
        HStack {
            Text(i18n.t(.event_title))
                .font(.title2)
                .bold()
            Spacer()
            Button(action: refresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: theme.iconS))
            }
            .buttonStyle(.plain)
            .disabled(isRefreshing)
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: theme.iconS))
            }
            .buttonStyle(.plain)
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle()
                    .fill(eventBridge.isDaemonReady ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                Text(eventBridge.isDaemonReady ? i18n.t(.event_status_live) : i18n.t(.event_status_degraded))
                    .font(.system(size: theme.textSize, weight: .semibold))
                Spacer()
                if let h = eventBridge.health {
                    Text("v\(h.version ?? "-") · uptime \(h.uptimeSec ?? 0)s · triggers \(h.triggers ?? 0)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(8)
        .background(theme.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(i18n.t(.event_recent))
                .font(.headline)
            if eventBridge.events.isEmpty {
                Text("—")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(eventBridge.events.reversed()) { ev in
                            eventRow(ev)
                        }
                    }
                }
                .frame(maxHeight: 160)
            }
        }
        .padding(8)
        .background(theme.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func eventRow(_ ev: SystemEvent) -> some View {
        HStack(spacing: 6) {
            Text(ev.type.rawValue)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(typeColor(ev.type).opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 3))
            Text(ev.targetPath ?? "(no path)")
                .font(.system(size: 10, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Text("t=\(ev.timestamp)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private func typeColor(_ t: SystemEventType) -> Color {
        switch t {
        case .fileModified: return .blue
        case .processTerminated: return .orange
        case .clipboardChanged: return .purple
        case .networkStatusChanged: return .teal
        case .unknown: return .secondary
        }
    }

    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(i18n.t(.event_rules))
                    .font(.headline)
                Spacer()
                Button(i18n.t(.event_rule_add)) { showAddRule = true }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            if eventBridge.rules.isEmpty {
                Text("—")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(eventBridge.rules) { rule in
                    ruleRow(rule)
                }
            }
        }
        .padding(8)
        .background(theme.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func ruleRow(_ rule: EventRule) -> some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Text(rule.ruleName)
                    .font(.system(size: 11, weight: .semibold))
                Text("\(rule.eventType) → \(rule.targetAgent)")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                if let pp = rule.pathPattern { Text(pp).font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary) }
            }
            Spacer()
            Button(action: { pendingDelete = rule }) {
                Image(systemName: "trash")
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }

    private func refresh() {
        isRefreshing = true
        Task {
            await eventBridge.checkDaemonStatus()
            await eventBridge.listRules()
            await MainActor.run { isRefreshing = false }
        }
    }
}

// MARK: - 添加规则表单

struct EventRuleAddForm: View {
    @ObservedObject var eventBridge: EventBridge
    @Environment(\.studioTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @StateObject private var i18n = I18nManager.shared
    @State private var ruleName = ""
    @State private var eventType: SystemEventType = .fileModified
    @State private var targetAgent = "fusion-code"
    @State private var pathPattern = ""
    @State private var debounceMs: Int = 300
    @State private var isSubmitting = false
    @State private var formError: String?

    private let typeOptions: [SystemEventType] = [
        .fileModified, .processTerminated, .clipboardChanged, .networkStatusChanged,
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            Text(i18n.t(.event_rule_add))
                .font(.title2)
                .bold()

            formField(i18n.t(.event_rule_name)) {
                TextField("rule-1", text: $ruleName)
            }
            formField(i18n.t(.event_rule_eventType)) {
                Picker("", selection: $eventType) {
                    ForEach(typeOptions, id: \.self) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            formField(i18n.t(.event_rule_targetAgent)) {
                TextField("fusion-code", text: $targetAgent)
            }
            formField(i18n.t(.event_rule_pathPattern)) {
                TextField("/tmp/*.log", text: $pathPattern)
            }
            formField(i18n.t(.event_rule_debounce)) {
                Stepper("\(debounceMs)", value: $debounceMs, in: 0...60000, step: 50)
            }

            if let error = formError {
                Text(error).font(.caption).foregroundStyle(theme.warningText)
            }

            Spacer()

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .disabled(isSubmitting)
                Button(i18n.t(.event_rule_add)) { submit() }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSubmitting || ruleName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(width: 420, height: 460)
        .background(theme.windowBg)
    }

    private func formField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            content()
        }
    }

    private func submit() {
        isSubmitting = true
        formError = nil
        Task {
            do {
                try await eventBridge.addRule(
                    name: ruleName.trimmingCharacters(in: .whitespaces),
                    eventType: eventType.rawValue,
                    targetAgent: targetAgent.trimmingCharacters(in: .whitespaces).isEmpty ? "fusion-code" : targetAgent.trimmingCharacters(in: .whitespaces),
                    pathPattern: pathPattern.isEmpty ? nil : pathPattern,
                    debounceMs: debounceMs
                )
                await MainActor.run {
                    isSubmitting = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    formError = BridgeError.sanitize(error)
                }
            }
        }
    }
}
