// Callers: ModuleDetailView routing.
// Affected API: RealTimeService (replacing NSColor with StudioTheme tokens).
// Data schemas: None changed.
// User instruction: "帮我用 UI/UX Pro Max 重新设计 fusion-studio 的整体 GUI - macOS 原生风格 - 三栏 - 暗色模式优先 - 主色 #007AFF"

import SwiftUI
import Combine

// MARK: - 实时消息

struct RTChatMessage: Identifiable {
    let id = UUID()
    let sender: String
    let content: String
    let timestamp: Date
    let type: MessageType

    enum MessageType: String { case text = "文本", code = "代码", file = "文件", system = "系统" }
}

struct RTPresence: Identifiable, Hashable {
    let id: String
    let name: String
    var status: PresenceStatus
    let lastSeen: Date
    var currentModule: String?

    enum PresenceStatus: String { case online = "在线", away = "离开", busy = "忙碌", editing = "编辑中" }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: RTPresence, rhs: RTPresence) -> Bool { lhs.id == rhs.id }
}

struct RTCollaborationSession: Identifiable {
    let id: String
    var name: String
    var members: [RTPresence]
    var messages: [RTChatMessage]
    var sharedCursor: [String: CursorPosition]

    struct CursorPosition: Codable {
        let line: Int; let column: Int; let file: String
    }
}

// MARK: - 实时协作管理器

class RealTimeCollaboration: ObservableObject {
    static let shared = RealTimeCollaboration()

    @Published var isConnected = false
    @Published var session: RTCollaborationSession?
    @Published var presenceList: [RTPresence] = []
    @Published var unreadCount = 0

    private let host = "localhost"
    private let port: UInt16 = 9000
    private var pingTimer: Timer?

    init() {
        // 假在线状态已清理：仅展示真实协作成员
    }

    func connect() {
        isConnected = true
        session = RTCollaborationSession(
            id: "session-\(UUID().uuidString.prefix(6))",
            name: "Fusion Studio 协作",
            members: presenceList,
            messages: [
                RTChatMessage(sender: "系统", content: "欢迎加入协作会话", timestamp: Date(), type: .system),
            ],
            sharedCursor: [:]
        )
        startPing()
        objectWillChange.send()
    }

    func disconnect() {
        isConnected = false
        session = nil
        pingTimer?.invalidate()
        objectWillChange.send()
    }

    private func startPing() {
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.sendHeartbeat()
        }
    }

    private func sendHeartbeat() {
        guard isConnected else { return }
        // 发送心跳包
    }

    func sendMessage(_ content: String, type: RTChatMessage.MessageType = .text) {
        guard var session = session else { return }
        let msg = RTChatMessage(sender: "我", content: content, timestamp: Date(), type: type)
        session.messages.append(msg)
        self.session = session
        objectWillChange.send()
    }

    func updatePresence(status: RTPresence.PresenceStatus, module: String?) {
        guard var session = session else { return }
        if let idx = session.members.firstIndex(where: { $0.id == "local" }) {
            session.members[idx].status = status
            session.members[idx].currentModule = module
        }
        self.session = session
        objectWillChange.send()
    }

    func clearUnread() { unreadCount = 0 }
}

// MARK: - 实时协作面板

struct RealTimeView: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var rt = RealTimeCollaboration.shared
    @State private var messageText = ""
    @State private var selectedTab: RTTab = .chat

    enum RTTab: String, CaseIterable {
        case chat     = "聊天"
        case presence = "在线成员"
        case activity = "活动"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Circle().fill(rt.isConnected ? Color.green : Color.red).frame(width: 8, height: 8)
                Text("实时协作").font(.headline)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { rt.isConnected },
                    set: { $0 ? rt.connect() : rt.disconnect() }
                )).toggleStyle(.switch).controlSize(.small)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(theme.surfaceSecondary)

            Divider()

            Picker("", selection: $selectedTab) {
                ForEach(RTTab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tabIcon(tab)).tag(tab)
                }
            }
            .pickerStyle(.segmented).padding(8)

            if rt.isConnected {
                switch selectedTab {
                case .chat:     ChatView()
                case .presence: PresenceListView()
                case .activity: ActivityView()
                }
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "wifi.slash").font(.system(size: 40)).foregroundColor(.secondary)
                    Text("未连接").foregroundColor(.secondary)
                    Text("开启协作以使用实时聊天和同步功能").font(.caption).foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
    }

    private func tabIcon(_ tab: RTTab) -> String {
        switch tab { case .chat: return "bubble.left.and.bubble.right"; case .presence: return "person.2"; case .activity: return "bell" }
    }
}

// MARK: - 聊天视图

struct ChatView: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var rt = RealTimeCollaboration.shared
    @State private var messageText = ""
    @State private var showCodeInput = false

    var body: some View {
        VStack(spacing: 0) {
            // 消息列表
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(rt.session?.messages ?? []) { msg in
                            ChatBubble(message: msg)
                                .id(msg.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: rt.session?.messages.count ?? 0) { _, _ in
                    withAnimation { proxy.scrollTo(rt.session?.messages.last?.id, anchor: .bottom) }
                }
            }

            Divider()

            // 输入栏
            HStack(spacing: 8) {
                Button(action: { showCodeInput.toggle() }) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                }
                .buttonStyle(.bordered).controlSize(.small)
                .popover(isPresented: $showCodeInput) {
                    VStack {
                        Text("发送代码片段").font(.headline)
                        TextEditor(text: $messageText)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 100)
                        Button("发送") { sendMessage(type: .code) }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding().frame(width: 300)
                }

                TextField("输入消息...", text: $messageText)
                    .textFieldStyle(.plain)
                    .onSubmit { sendMessage() }

                Button(action: { sendMessage() }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(8)
            .background(theme.surfaceSecondary)
        }
    }

    private func sendMessage(type: RTChatMessage.MessageType = .text) {
        let text = messageText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        rt.sendMessage(text, type: type)
        messageText = ""
    }
}

// MARK: - 聊天气泡

struct ChatBubble: View {
    @Environment(\.studioTheme) private var theme
    let message: RTChatMessage
    @State private var isVisible = false

    var body: some View {
        HStack {
            if message.sender == "我" { Spacer() }

            VStack(alignment: message.sender == "我" ? .trailing : .leading, spacing: 2) {
                if message.sender != "我" && message.type != .system {
                    Text(message.sender)
                        .font(.caption).fontWeight(.bold).foregroundColor(.accentColor)
                }

                HStack {
                    if message.type == .code {
                        Text(message.content)
                            .font(.system(.caption, design: .monospaced))
                            .padding(8)
                            .background(Color.black.opacity(0.08))
                            .cornerRadius(6)
                    } else {
                        Text(message.content)
                            .font(.body)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(message.sender == "我" ? Color(red: 0, green: 122.0 / 255.0, blue: 1.0) : theme.surfaceSecondary)
                            .foregroundColor(message.sender == "我" ? .white : .primary)
                            .cornerRadius(12)
                    }
                }

                if message.type != .system {
                    Text(message.timestamp, style: .time)
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 4)

            if message.sender != "我" && message.sender != "系统" { Spacer() }
        }
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 10)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3).delay(0.1)) { isVisible = true }
        }
    }
}

// MARK: - 成员列表

struct PresenceListView: View {
    @StateObject private var rt = RealTimeCollaboration.shared

    var body: some View {
        List {
            ForEach(rt.session?.members ?? rt.presenceList) { member in
                HStack(spacing: 10) {
                    Circle()
                        .fill(statusColor(member.status))
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(member.name).font(.headline)
                        Text(member.status.rawValue)
                            .font(.caption).foregroundColor(.secondary)
                    }

                    Spacer()

                    if let module = member.currentModule {
                        Text(module)
                            .font(.caption2)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(4)
                    }

                    Text(member.lastSeen, style: .time)
                        .font(.caption2).foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func statusColor(_ status: RTPresence.PresenceStatus) -> Color {
        switch status { case .online: return .green; case .away: return .orange; case .busy: return .red; case .editing: return .blue }
    }
}

// MARK: - 活动视图

struct ActivityView: View {
    let activities: [(String, String, Date)]

    init(activities: [(String, String, Date)] = []) {
        self.activities = activities
    }

    var body: some View {
        Group {
            if activities.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("暂无协作活动")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
                .padding(.vertical, 30)
            } else {
                List(activities, id: \.2) { (user, action, time) in
                    HStack(spacing: 10) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundColor(time > Date().addingTimeInterval(-120) ? .green : .secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(user).font(.headline)
                                Text(action).font(.subheadline).foregroundColor(.secondary)
                            }
                            Text(time.formatted(date: .numeric, time: .shortened))
                                .font(.caption2).foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

// MARK: - 实时光标覆盖

struct RemoteCursorOverlay: View {
    let cursors: [String: RTCollaborationSession.CursorPosition]

    var body: some View {
        ZStack {
            ForEach(Array(cursors.keys), id: \.self) { userId in
                if let pos = cursors[userId] {
                    RemoteCursorView(userId: userId, position: pos)
                }
            }
        }
    }
}

struct RemoteCursorView: View {
    let userId: String
    let position: RTCollaborationSession.CursorPosition

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 10))
                .foregroundColor(.accentColor)
            Text(userId)
                .font(.system(size: 8))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(3)
        }
        .position(x: CGFloat(position.column) * 8, y: CGFloat(position.line) * 20)
        .opacity(0.7)
    }
}

// MARK: - 实时同步状态指示器

struct SyncStatusIndicator: View {
    @StateObject private var rt = RealTimeCollaboration.shared

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(rt.isConnected ? Color.green : Color.gray)
                .frame(width: 6, height: 6)
            Text(rt.isConnected ? "已同步" : "未同步")
                .font(.caption)
            if rt.unreadCount > 0 {
                Text("\(rt.unreadCount)")
                    .font(.system(size: 10))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
    }
}