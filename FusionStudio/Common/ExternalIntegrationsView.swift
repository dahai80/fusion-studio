// Callers: ModuleDetailView routing.
// Affected API: ExternalIntegrationsView (replacing NSColor with StudioTheme tokens).
// Data schemas: None changed.
// User instruction: "帮我用 UI/UX Pro Max 重新设计 fusion-studio 的整体 GUI - macOS 原生风格 - 三栏 - 暗色模式优先 - 主色 #007AFF"

import SwiftUI

// MARK: - 外部服务类型

enum ExternalService: String, CaseIterable {
    case github   = "GitHub"
    case jira     = "Jira"
    case gitlab   = "GitLab"
    case slack    = "Slack"
    case openai   = "OpenAI (兼容)"
    case custom   = "自定义 API"

    var icon: String {
        switch self {
        case .github: return "chevron.left.forwardslash.chevron.right"
        case .jira:   return "square.grid.3x3"
        case .gitlab: return "gitlab"
        case .slack:  return "bubble.left.and.bubble.right"
        case .openai: return "cpu"
        case .custom: return "gearshape.2"
        }
    }
    var color: Color {
        switch self {
        case .github: return .gray; case .jira: return .blue; case .gitlab: return .orange
        case .slack: return .purple; case .openai: return .green; case .custom: return .accentColor
        }
    }
}

// MARK: - 服务连接配置

struct ServiceConnection: Identifiable, Hashable {
    let id: String
    var service: ExternalService
    var name: String
    var url: String
    var token: String
    var isConnected: Bool
    var lastSync: Date?
    var config: [String: String]

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: ServiceConnection, rhs: ServiceConnection) -> Bool { lhs.id == rhs.id }
}

// MARK: - 外部集成管理器

class ExternalIntegrationManager: ObservableObject {
    static let shared = ExternalIntegrationManager()

    @Published var connections: [ServiceConnection] = []
    @Published var isSyncing = false
    @Published var syncProgress: Double = 0
    @Published var syncLog: [String] = []

    init() {
        loadSampleConnections()
    }

    private func loadSampleConnections() {
        connections = [
            ServiceConnection(id: "gh-1", service: .github, name: "dahai80/fusion-studio", url: "https://github.com/dahai80/fusion-studio", token: "ghp_***", isConnected: true, lastSync: Date(), config: ["repo": "dahai80/fusion-studio", "branch": "master"]),
            ServiceConnection(id: "ji-1", service: .jira, name: "Fusion Studio Project", url: "https://fusion.atlassian.net", token: "jira_***", isConnected: false, lastSync: nil, config: ["project": "FUSION", "board": "Sprint 1"]),
            ServiceConnection(id: "oa-1", service: .openai, name: "Local MLX (兼容)", url: FusionConfig.shared.mlxBaseURL + "/v1", token: "", isConnected: true, lastSync: Date(), config: ["model": "qwen3.5-9b-4bit"]),
        ]
    }

    func connect(_ id: String) {
        guard let idx = connections.firstIndex(where: { $0.id == id }) else { return }
        connections[idx].isConnected = true
        connections[idx].lastSync = Date()
        objectWillChange.send()
    }

    func disconnect(_ id: String) {
        guard let idx = connections.firstIndex(where: { $0.id == id }) else { return }
        connections[idx].isConnected = false
        objectWillChange.send()
    }

    func addConnection(service: ExternalService, name: String, url: String, token: String) {
        let conn = ServiceConnection(
            id: "conn-\(UUID().uuidString.prefix(6))",
            service: service,
            name: name,
            url: url,
            token: token,
            isConnected: false,
            lastSync: nil,
            config: [:]
        )
        connections.append(conn)
        objectWillChange.send()
    }

    func removeConnection(_ id: String) {
        connections.removeAll { $0.id == id }
        objectWillChange.send()
    }

    func syncAll() {
        isSyncing = true
        syncProgress = 0
        syncLog = ["开始同步所有服务..."]

        for (i, conn) in connections.enumerated() where conn.isConnected {
            syncLog.append("  [\(conn.service.rawValue)] 同步 \(conn.name)...")
            syncProgress = Double(i + 1) / Double(connections.filter { $0.isConnected }.count)
        }
        syncLog.append("✅ 同步完成")

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.isSyncing = false
            self?.objectWillChange.send()
        }
    }

    func testConnection(_ id: String) async -> Bool {
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        return true
    }
}

// MARK: - 外部集成面板

struct ExternalIntegrationsView: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var manager = ExternalIntegrationManager.shared
    @State private var showAddSheet = false
    @State private var selectedService: ExternalService = .github

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("外部工具集成", systemImage: "link.circle").font(.headline)
                Spacer()
                Button(action: { showAddSheet = true }) {
                    Label("添加服务", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent).controlSize(.small)
                Button(action: { manager.syncAll() }) {
                    Label("同步全部", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.bordered).controlSize(.small)
                .disabled(manager.isSyncing)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(theme.surfaceSecondary)

            Divider()

            if manager.isSyncing {
                VStack(spacing: 8) {
                    ProgressView(value: manager.syncProgress)
                    ForEach(manager.syncLog, id: \.self) { line in
                        Text(line).font(.system(.caption, design: .monospaced)).foregroundColor(.secondary)
                    }
                }
                .padding()
            }

            List {
                ForEach(ExternalService.allCases, id: \.rawValue) { service in
                    let serviceConns = manager.connections.filter { $0.service == service }
                    if !serviceConns.isEmpty {
                        Section(service.rawValue) {
                            ForEach(serviceConns) { conn in
                                ServiceRow(connection: conn)
                            }
                        }
                    }
                }
                // 未连接的服务提示
                ForEach(ExternalService.allCases, id: \.rawValue) { service in
                    if !manager.connections.contains(where: { $0.service == service }) {
                        Section(service.rawValue) {
                            Button(action: {
                                selectedService = service
                                showAddSheet = true
                            }) {
                                HStack {
                                    Image(systemName: service.icon).foregroundColor(service.color)
                                    Text("连接 \(service.rawValue)")
                                    Spacer()
                                    Image(systemName: "plus.circle").foregroundColor(.accentColor)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddServiceSheet(initialService: selectedService)
        }
    }
}

// MARK: - 服务行

struct ServiceRow: View {
    let connection: ServiceConnection
    @StateObject private var manager = ExternalIntegrationManager.shared
    @State private var showDetail = false

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Image(systemName: connection.service.icon)
                    .foregroundColor(connection.service.color)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(connection.name).font(.headline)
                    Text(connection.url).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                if connection.isConnected {
                    Circle().fill(Color.green).frame(width: 8, height: 8)
                }
                Button(action: { showDetail.toggle() }) {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showDetail) {
                    ServiceDetailView(connection: connection)
                }
            }
            if connection.isConnected, let last = connection.lastSync {
                HStack {
                    Spacer()
                    Text("上次同步: \(last.formatted(date: .numeric, time: .shortened))")
                        .font(.caption2).foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            if connection.isConnected {
                Button("断开") { manager.disconnect(connection.id) }
            } else {
                Button("连接") { manager.connect(connection.id) }
            }
            Button("删除", role: .destructive) { manager.removeConnection(connection.id) }
        }
    }
}

// MARK: - 服务详情

struct ServiceDetailView: View {
    let connection: ServiceConnection
    @StateObject private var manager = ExternalIntegrationManager.shared
    @State private var isTesting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: connection.service.icon).foregroundColor(connection.service.color)
                Text(connection.name).font(.headline)
            }
            Divider()
            GroupBox("配置") {
                VStack(alignment: .leading, spacing: 6) {
                    ExtDetailRow("服务", connection.service.rawValue)
                    ExtDetailRow("URL", connection.url)
                    ExtDetailRow("Token", String(repeating: "•", count: 12))
                    ExtDetailRow("状态", connection.isConnected ? "已连接" : "未连接")
                    if let last = connection.lastSync {
                        ExtDetailRow("上次同步", last.formatted(date: .numeric, time: .shortened))
                    }
                }
                .padding(8)
            }
            HStack(spacing: 12) {
                if connection.isConnected {
                    Button("断开") { manager.disconnect(connection.id) }
                        .buttonStyle(.bordered)
                    Button("同步") { manager.syncAll() }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("连接") { manager.connect(connection.id) }
                        .buttonStyle(.borderedProminent)
                }
                Button("测试连接") {
                    isTesting = true
                    Task {
                        _ = await manager.testConnection(connection.id)
                        isTesting = false
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isTesting)
                if isTesting { ProgressView().controlSize(.small) }
            }
        }
        .padding()
        .frame(width: 300)
    }
}

struct ExtDetailRow: View {
    let label: String; let value: String
    init(_ label: String, _ value: String) { self.label = label; self.value = value }
    var body: some View {
        HStack {
            Text(label).foregroundColor(.secondary).frame(width: 80, alignment: .leading)
            Text(value).font(.system(.body, design: .monospaced))
            Spacer()
        }
    }
}

// MARK: - 添加服务

struct AddServiceSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var manager = ExternalIntegrationManager.shared
    @State private var name = ""
    @State private var url = ""
    @State private var token = ""
    let initialService: ExternalService

    var body: some View {
        VStack(spacing: 16) {
            Text("添加服务连接").font(.title2).bold()
            HStack {
                Image(systemName: initialService.icon).foregroundColor(initialService.color)
                Text(initialService.rawValue).font(.headline)
            }
            TextField("连接名称", text: $name).textFieldStyle(.roundedBorder)
            TextField("URL", text: $url).textFieldStyle(.roundedBorder)
                .help(initialService == .github ? "https://github.com/owner/repo" : "")
            SecureField("Token / API Key", text: $token).textFieldStyle(.roundedBorder)
            HStack {
                Button("取消") { dismiss() }.buttonStyle(.bordered)
                Button("添加") {
                    manager.addConnection(service: initialService, name: name, url: url, token: token)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || url.isEmpty)
            }
        }
        .padding().frame(width: 320)
    }
}

// MARK: - GitHub 集成

struct GitHubIntegrationView: View {
    @StateObject private var manager = ExternalIntegrationManager.shared
    @State private var issues: [(title: String, state: String, date: String)] = [
        ("添加暗黑模式支持", "open", "2d ago"),
        ("修复 MLX 内存泄漏", "open", "5d ago"),
        ("优化启动速度", "closed", "1w ago"),
        ("添加单元测试", "open", "1w ago"),
        ("更新文档", "merged", "2w ago"),
    ]

    var body: some View {
        let github = manager.connections.first { $0.service == .github }

        if let conn = github, conn.isConnected {
            List {
                Section("仓库信息") {
                    HStack { Text("仓库"); Spacer(); Text(conn.name).font(.system(.body, design: .monospaced)) }
                    HStack { Text("分支"); Spacer(); Text(conn.config["branch"] ?? "master").font(.system(.body, design: .monospaced)) }
                }

                Section("最近 Issues (\(issues.filter { $0.state == "open" }.count) 开放)") {
                    ForEach(issues, id: \.title) { issue in
                        HStack {
                            Circle()
                                .fill(issue.state == "open" ? Color.green : (issue.state == "closed" ? Color.red : Color.purple))
                                .frame(width: 8, height: 8)
                            Text(issue.title).font(.subheadline)
                            Spacer()
                            Text(issue.state).font(.caption2).foregroundColor(.secondary)
                            Text(issue.date).font(.caption2).foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        } else {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "chevron.left.forwardslash.chevron.right").font(.system(size: 40)).foregroundColor(.secondary)
                Text("未连接 GitHub").foregroundColor(.secondary)
                Text("在外部集成中添加 GitHub 连接以查看仓库信息").font(.caption).foregroundColor(.secondary)
                Spacer()
            }
        }
    }
}

// MARK: - API 端点测试

struct APITestView: View {
    @State private var endpoint = ""
    @State private var method = "GET"
    @State private var headers = ""
    @State private var body_text = ""
    @State private var response = ""
    @State private var isLoading = false

    let methods = ["GET", "POST", "PUT", "DELETE", "PATCH"]

    var body: some View {
        VStack(spacing: 12) {
            GroupBox("API 测试工具") {
                VStack(spacing: 8) {
                    HStack {
                        Picker("", selection: $method) {
                            ForEach(methods, id: \.self) { m in Text(m).tag(m) }
                        }
                        .pickerStyle(.menu).frame(width: 80)
                        TextField("https://api.example.com/v1/endpoint", text: $endpoint)
                            .textFieldStyle(.roundedBorder)
                        Button("发送") { sendRequest() }
                            .buttonStyle(.borderedProminent)
                            .disabled(endpoint.isEmpty || isLoading)
                    }

                    if isLoading {
                        ProgressView()
                    }

                    HStack {
                        VStack(alignment: .leading) {
                            Text("Headers").font(.caption)
                            TextEditor(text: $headers)
                                .font(.system(.caption, design: .monospaced))
                                .frame(minHeight: 60)
                                .border(Color.gray.opacity(0.2))
                        }
                        VStack(alignment: .leading) {
                            Text("Body").font(.caption)
                            TextEditor(text: $body_text)
                                .font(.system(.caption, design: .monospaced))
                                .frame(minHeight: 60)
                                .border(Color.gray.opacity(0.2))
                        }
                    }
                }
                .padding(8)
            }
            .padding(.horizontal)

            GroupBox("响应") {
                ScrollView {
                    Text(response.isEmpty ? "等待请求..." : response)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(response.hasPrefix("Error") ? .red : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 100)
                .padding(8)
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding(.vertical)
    }

    private func sendRequest() {
        isLoading = true
        response = ""
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                response = "\(method) \(endpoint)\nStatus: 200 OK\n\n{\n  \"status\": \"success\",\n  \"message\": \"API 测试端点响应示例\"\n}"
                isLoading = false
            }
        }
    }
}