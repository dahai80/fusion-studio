import SwiftUI
import os.log

private let healthViewLog = Logger(subsystem: "com.fusion.studio", category: "HealthWorkbenchView")

enum HealthModuleTab: String, CaseIterable, Identifiable {
    case dashboard = "概览"
    case ehr = "病历摘要"
    case vitals = "体征提取"
    case copilot = "AI 咨询"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .dashboard: return "heart.text.square"
        case .ehr: return "doc.text.magnifyingglass"
        case .vitals: return "waveform.path.ecg"
        case .copilot: return "stethoscope"
        }
    }
}

struct HealthWorkbenchView: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var healthBridge: HealthBridge
    @State private var selectedTab: HealthModuleTab = .dashboard

    var body: some View {
        HSplitView {
            HealthNavigationView(selectedTab: $selectedTab)
                .frame(minWidth: 160, idealWidth: 200, maxWidth: 240)

            HealthContentView(selectedTab: selectedTab)
                .frame(minWidth: 400, idealWidth: 600)

            HealthCopilotPanel()
                .frame(minWidth: 260, idealWidth: 320, maxWidth: 380)
        }
        .background(theme.contentBg)
        .onAppear {
            healthBridge.refreshBaseURL()
            healthBridge.checkHealth()
            healthBridge.startChat()
            healthViewLog.info("HealthWorkbenchView appeared")
        }
    }
}

struct HealthNavigationView: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var healthBridge: HealthBridge
    @Binding var selectedTab: HealthModuleTab

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("健康助手")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ForEach(HealthModuleTab.allCases) { tab in
                Button(action: { selectedTab = tab }) {
                    HStack(spacing: 8) {
                        Image(systemName: tab.icon)
                            .frame(width: 20)
                        Text(tab.rawValue)
                            .font(.subheadline)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(selectedTab == tab ? theme.accent.opacity(0.15) : Color.clear)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(healthBridge.isConnected ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                Text(healthBridge.isConnected ? "服务在线" : "离线")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
        .frame(maxHeight: .infinity)
        .background(theme.sidebarBg)
    }
}

struct HealthContentView: View {
    let selectedTab: HealthModuleTab

    var body: some View {
        switch selectedTab {
        case .dashboard:
            HealthDashboardView()
        case .ehr:
            HealthEhrSummaryView()
        case .vitals:
            HealthVitalsView()
        case .copilot:
            HealthCopilotPanel()
        }
    }
}

struct HealthDashboardView: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var healthBridge: HealthBridge

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Fusion Health 概览")
                .font(.title2.bold())
                .padding(.top, 16)

            HStack(spacing: 16) {
                HealthMetricCard(title: "服务状态", value: healthBridge.isConnected ? "在线" : "离线", icon: "heart.text.square", color: healthBridge.isConnected ? .green : .gray)
                HealthMetricCard(title: "服务名称", value: healthBridge.serviceStatus?.service ?? "fusion-health", icon: "server.rack", color: .blue)
                HealthMetricCard(title: "版本", value: healthBridge.serviceStatus?.version ?? "-", icon: "tag", color: .purple)
                HealthMetricCard(title: "模型", value: healthBridge.serviceStatus?.model ?? "-", icon: "cpu", color: .orange)
            }

            if let err = healthBridge.lastError {
                Label(err, systemImage: "exclamationmark.triangle")
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal, 16)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.contentBg)
    }
}

struct HealthMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.body.bold())
                .lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }
}

struct HealthEhrSummaryView: View {
    @EnvironmentObject var healthBridge: HealthBridge
    @State private var notes: String = ""
    @State private var loading: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("病历摘要生成").font(.title3.bold()).padding(.top, 16)
            Text("粘贴临床记录，生成结构化摘要。").font(.caption).foregroundColor(.secondary)

            TextEditor(text: $notes)
                .frame(minHeight: 160)
                .padding(4)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))

            Button(action: generate) {
                Label(loading ? "生成中…" : "生成摘要", systemImage: "wand.and.stars")
            }
            .buttonStyle(.borderedProminent)
            .disabled(notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || loading)

            if let summary = healthBridge.ehrSummary {
                GroupBox("摘要") {
                    ScrollView {
                        Text(summary)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(4)
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func generate() {
        loading = true
        healthBridge.generateEhrSummary(clinicalNotes: notes) { _ in
            loading = false
        }
    }
}

struct HealthVitalsView: View {
    @EnvironmentObject var healthBridge: HealthBridge
    @State private var text: String = ""
    @State private var vitals: [String: String] = [:]
    @State private var loading: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("体征提取").font(.title3.bold()).padding(.top, 16)
            Text("从文本中抽取生命体征（血压/心率/体温等）。").font(.caption).foregroundColor(.secondary)

            TextEditor(text: $text)
                .frame(minHeight: 120)
                .padding(4)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))

            Button(action: extract) {
                Label(loading ? "抽取中…" : "提取体征", systemImage: "waveform.path.ecg")
            }
            .buttonStyle(.borderedProminent)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || loading)

            if !vitals.isEmpty {
                GroupBox("体征") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(vitals.keys.sorted(), id: \.self) { key in
                            HStack {
                                Text(key).font(.caption).foregroundColor(.secondary)
                                Spacer()
                                Text(vitals[key] ?? "").font(.body.bold())
                            }
                        }
                    }
                    .padding(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func extract() {
        loading = true
        healthBridge.extractVitals(text: text) { result in
            if case .success(let v) = result { vitals = v }
            loading = false
        }
    }
}

struct HealthCopilotPanel: View {
    @EnvironmentObject var healthBridge: HealthBridge
    @State private var inputText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            Text("AI 医疗咨询")
                .font(.headline)
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(Color.accentColor.opacity(0.1))

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(healthBridge.chatMessages) { msg in
                            messageBubble(msg)
                        }
                        if healthBridge.isGenerating {
                            HStack { Spacer(); ProgressView().padding(8); Spacer() }
                        }
                    }
                    .padding(10)
                }
                .onChange(of: healthBridge.chatMessages.count) { _ in
                    if let last = healthBridge.chatMessages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            Divider()

            HStack(spacing: 8) {
                TextField("输入健康问题…", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { send() }
                Button(action: send) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || healthBridge.isGenerating)
            }
            .padding(10)
        }
        .frame(minWidth: 240)
    }

    private func messageBubble(_ msg: HealthChatMessage) -> some View {
        let isUser = msg.role == "user"
        return HStack {
            if isUser { Spacer() }
            Text(msg.content)
                .font(.subheadline)
                .padding(8)
                .background(isUser ? Color.accentColor.opacity(0.15) : Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .frame(maxWidth: 260, alignment: isUser ? .trailing : .leading)
                .textSelection(.enabled)
            if !isUser { Spacer() }
        }
    }

    private func send() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        inputText = ""
        healthBridge.sendChat(text)
    }
}
