// Callers: ModuleDetailView routing.
// Affected API: CollaborationService (replacing NSColor with StudioTheme tokens).
// Data schemas: None changed.
// User instruction: "帮我用 UI/UX Pro Max 重新设计 fusion-studio 的整体 GUI - macOS 原生风格 - 三栏 - 暗色模式优先 - 主色 #007AFF"

import Foundation
import SwiftUI
import Combine
import Network
import os.log

private let collabLog = Logger(subsystem: "com.fusion.studio", category: "CollaborationService")

// MARK: - 协作节点

struct Collaborator: Identifiable, Hashable {
    let id: String
    var name: String
    var host: String
    var port: UInt16
    var status: PeerStatus
    var lastSeen: Date
    var sharedModules: [String]
    var version: String

    enum PeerStatus: String, Codable {
        case online  = "online"
        case away    = "away"
        case busy    = "busy"
        case offline = "offline"

        var color: Color {
            switch self {
            case .online:  return .green
            case .away:    return .orange
            case .busy:    return .red
            case .offline: return .gray
            }
        }

        var localizedName: String {
            switch self {
            case .online:  return I18nManager.shared.t(.col_status_online)
            case .away:    return I18nManager.shared.t(.col_status_away)
            case .busy:    return I18nManager.shared.t(.col_status_busy)
            case .offline: return I18nManager.shared.t(.col_status_offline)
            }
        }
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Collaborator, rhs: Collaborator) -> Bool { lhs.id == rhs.id }
}

// MARK: - 协作会话

struct CollaborationSession: Identifiable, Hashable {
    let id: String
    var name: String
    var host: String
    var members: [Collaborator]
    var sharedResources: [SharedResource]
    var createdAt: Date
    var isActive: Bool

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: CollaborationSession, rhs: CollaborationSession) -> Bool { lhs.id == rhs.id }
}

struct SharedResource: Identifiable, Hashable {
    let id: String
    var name: String
    var type: ResourceType
    var size: Int64
    var ownerId: String
    var lastModified: Date

    enum ResourceType: String, CaseIterable {
        case design     = "design"
        case code       = "code"
        case model      = "model"
        case simulation = "simulation"
        case document   = "document"

        var icon: String {
            switch self {
            case .design:     return "pencil.and.outline"
            case .code:       return "chevron.left.forwardslash.chevron.right"
            case .model:      return "cpu"
            case .simulation: return "gearshape.2"
            case .document:   return "doc.text"
            }
        }

        var localizedName: String {
            switch self {
            case .design:     return I18nManager.shared.t(.col_type_design)
            case .code:       return I18nManager.shared.t(.col_type_code)
            case .model:      return I18nManager.shared.t(.col_type_model)
            case .simulation: return I18nManager.shared.t(.col_type_simulation)
            case .document:   return I18nManager.shared.t(.col_type_document)
            }
        }
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: SharedResource, rhs: SharedResource) -> Bool { lhs.id == rhs.id }
}

// MARK: - 协作消息

enum CollaborationMessage {
    case discovery(peer: String, version: String, modules: [String])
    case join(sessionId: String, peer: String)
    case leave(sessionId: String, peer: String)
    case share(sessionId: String, resource: SharedResource)
    case sync(sessionId: String, data: [String: String])
    case ping
    case pong

    var data: Data? {
        let dict: [String: Any] = self.dictionary
        return try? JSONSerialization.data(withJSONObject: dict)
    }

    private var dictionary: [String: Any] {
        switch self {
        case .discovery(let peer, let version, let modules):
            return ["type": "discovery", "peer": peer, "version": version, "modules": modules]
        case .join(let sessionId, let peer):
            return ["type": "join", "sessionId": sessionId, "peer": peer]
        case .leave(let sessionId, let peer):
            return ["type": "leave", "sessionId": sessionId, "peer": peer]
        case .share(let sessionId, let resource):
            return ["type": "share", "sessionId": sessionId, "resource": ["id": resource.id, "name": resource.name, "type": resource.type.rawValue, "ownerId": resource.ownerId]]
        case .sync(let sessionId, let data):
            var dict: [String: Any] = ["type": "sync", "sessionId": sessionId]
            dict.merge(data) { $1 }
            return dict
        case .ping:
            return ["type": "ping"]
        case .pong:
            return ["type": "pong"]
        }
    }
}

// MARK: - 协作服务

class CollaborationService: ObservableObject {
    static let shared = CollaborationService()

    @Published var peers: [Collaborator] = []
    @Published var activeSession: CollaborationSession?
    @Published var isEnabled = false
    @Published var serviceName = "Fusion Studio"

    private var listener: NWListener?
    private var connection: NWConnection?
    private var browser: NWBrowser?
    private let serviceType = "_fusionstudio._tcp"
    private let queue = DispatchQueue(label: "com.fusion-studio.collab", qos: .utility)
    private var pingTimer: Timer?

    var localPeer: Collaborator {
        Collaborator(
            id: "local-\(UUID().uuidString.prefix(8))",
            name: "\(Host.current().localizedName ?? "Me")",
            host: "localhost",
            port: 0,
            status: .online,
            lastSeen: Date(),
            sharedModules: ["design", "code", "simulation"],
            version: "1.0.0"
        )
    }

    // MARK: - 启动/停止

    func start() {
        guard !isEnabled else { return }
        isEnabled = true
        startAdvertising()
        startBrowsing()
        startPing()
        // 假 peer 已清理：仅展示 Bonjour 真实发现的局域网协作节点
        objectWillChange.send()
    }

    func stop() {
        isEnabled = false
        listener?.cancel()
        browser?.cancel()
        pingTimer?.invalidate()
        peers.removeAll()
        activeSession = nil
        objectWillChange.send()
    }

    // MARK: - 广播

    private func startAdvertising() {
        let param = NWParameters.tcp
        param.includePeerToPeer = true

        do {
            listener = try NWListener(using: param)
            listener?.service = NWListener.Service(
                type: serviceType,
                domain: "local.",
                txtRecord: NWTXTRecord([
                    "version": "1.0.0",
                    "modules": "design,code,simulation",
                    "name": serviceName
                ])
            )

            listener?.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    collabLog.info("\(I18nManager.shared.t(.col_log_advertise_start), privacy: .public)")
                case .failed(let error):
                    collabLog.error("\(I18nManager.shared.tf(.col_log_advertise_failed, error.localizedDescription), privacy: .public)")
                case .cancelled:
                    collabLog.info("\(I18nManager.shared.t(.col_log_advertise_stopped), privacy: .public)")
                default: break
                }
            }

            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }

            listener?.start(queue: queue)
        } catch {
            collabLog.error("\(I18nManager.shared.tf(.col_log_advertise_error, error.localizedDescription), privacy: .public)")
        }
    }

    private func startBrowsing() {
        let param = NWParameters.tcp
        param.includePeerToPeer = true

        browser = NWBrowser(
            for: .bonjour(type: serviceType, domain: "local."),
            using: param
        )

        browser?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                collabLog.info("\(I18nManager.shared.t(.col_log_browse_start), privacy: .public)")
            case .failed(let error):
                collabLog.error("\(I18nManager.shared.tf(.col_log_browse_failed, error.localizedDescription), privacy: .public)")
            default: break
            }
        }

        browser?.browseResultsChangedHandler = { [weak self] results, changes in
            self?.handleBrowseResults(results)
        }

        browser?.start(queue: queue)
    }

    private func startPing() {
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.removeStalePeers()
        }
    }

    // MARK: - 连接处理

    private func handleConnection(_ connection: NWConnection) {
        // 处理入站连接
        connection.stateUpdateHandler = { state in
            if state == .ready {
                collabLog.info("\(I18nManager.shared.tf(.col_log_conn_ready, connection.endpoint.debugDescription), privacy: .public)")
            }
        }
        connection.start(queue: queue)
    }

    private func handleBrowseResults(_ results: Set<NWBrowser.Result>) {
        for result in results {
            let endpoint = result.endpoint
            if case .service(let name, let type, let domain, _) = endpoint {
                let peer = Collaborator(
                    id: "peer-\(name)",
                    name: name,
                    host: "\(name).\(domain)",
                    port: 0,
                    status: .online,
                    lastSeen: Date(),
                    sharedModules: ["design", "code", "simulation"],
                    version: "1.0.0"
                )
                DispatchQueue.main.async {
                    if !self.peers.contains(where: { $0.id == peer.id }) {
                        self.peers.append(peer)
                    } else if let idx = self.peers.firstIndex(where: { $0.id == peer.id }) {
                        self.peers[idx].lastSeen = Date()
                        self.peers[idx].status = .online
                    }
                }
            }
        }
    }

    // MARK: - 会话管理

    func createSession(name: String) {
        let session = CollaborationSession(
            id: "session-\(UUID().uuidString.prefix(8))",
            name: name,
            host: localPeer.name,
            members: [localPeer],
            sharedResources: [],
            createdAt: Date(),
            isActive: true
        )
        activeSession = session
        objectWillChange.send()
    }

    func joinSession(_ session: CollaborationSession) {
        activeSession = session
        objectWillChange.send()
    }

    func leaveSession() {
        activeSession = nil
        objectWillChange.send()
    }

    // MARK: - 资源分享

    func shareResource(_ resource: SharedResource) {
        guard var session = activeSession else { return }
        session.sharedResources.append(resource)
        activeSession = session
        objectWillChange.send()
    }

    // MARK: - 辅助方法

    private func removeStalePeers() {
        let threshold = Date().addingTimeInterval(-120)
        peers.removeAll { $0.lastSeen < threshold && $0.status == .online }
        objectWillChange.send()
    }
}

// MARK: - 协作面板

struct CollaborateView: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var collab = CollaborationService.shared
    @State private var selectedTab: CollabTab = .peers
    @State private var showCreateSession = false
    @State private var newSessionName = ""

    enum CollabTab: String, CaseIterable {
        case peers    = "peers"
        case session  = "session"
        case share    = "share"
        case settings = "settings"

        var localizedName: String {
            switch self {
            case .peers:    return I18nManager.shared.t(.col_tab_peers)
            case .session:  return I18nManager.shared.t(.col_tab_session)
            case .share:    return I18nManager.shared.t(.col_tab_share)
            case .settings: return I18nManager.shared.t(.col_tab_settings)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 开关
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(collab.isEnabled ? .green : .gray)
                Text(I18nManager.shared.t(.col_title))
                    .font(.headline)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { collab.isEnabled },
                    set: { $0 ? collab.start() : collab.stop() }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(theme.surfaceSecondary)

            Divider()

            Picker("", selection: $selectedTab) {
                ForEach(CollabTab.allCases, id: \.self) { tab in
                    Label(tab.localizedName, systemImage: tabIcon(tab)).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(8)

            switch selectedTab {
            case .peers:
                PeerListView()
            case .session:
                SessionView()
            case .share:
                SharedResourcesView()
            case .settings:
                CollabSettingsView()
            }
        }
        .sheet(isPresented: $showCreateSession) {
            VStack(spacing: 16) {
                Text(I18nManager.shared.t(.col_create_session))
                    .font(.title2)
                    .bold()
                TextField(I18nManager.shared.t(.col_session_name), text: $newSessionName)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button(I18nManager.shared.t(.col_cancel)) { showCreateSession = false }
                        .buttonStyle(.bordered)
                    Button(I18nManager.shared.t(.col_create)) {
                        collab.createSession(name: newSessionName)
                        newSessionName = ""
                        showCreateSession = false
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newSessionName.isEmpty)
                }
            }
            .padding()
            .frame(width: 300)
        }
    }

    private func tabIcon(_ tab: CollabTab) -> String {
        switch tab {
        case .peers:    return "person.2"
        case .session:  return "bubble.left.and.bubble.right"
        case .share:    return "square.and.arrow.up"
        case .settings: return "gearshape"
        }
    }
}

// MARK: - 成员列表

struct PeerListView: View {
    @StateObject private var collab = CollaborationService.shared

    var body: some View {
        if collab.peers.isEmpty {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "wifi.slash")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                Text(I18nManager.shared.t(.col_no_peers))
                    .foregroundColor(.secondary)
                Text(I18nManager.shared.t(.col_no_peers_hint))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Spacer()
            }
        } else {
            List {
                // 本地节点
                Section(I18nManager.shared.t(.col_section_local)) {
                    PeerRow(peer: collab.localPeer, isLocal: true)
                }

                Section(I18nManager.shared.tf(.col_section_peers_fmt, collab.peers.count)) {
                    ForEach(collab.peers) { peer in
                        PeerRow(peer: peer, isLocal: false)
                    }
                }
            }
        }
    }
}

struct PeerRow: View {
    let peer: Collaborator
    let isLocal: Bool

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(peer.status.color)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(peer.name)
                        .font(.headline)
                    if isLocal {
                        Text(I18nManager.shared.t(.col_local_tag))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                HStack(spacing: 6) {
                    Text(peer.status.localizedName)
                        .font(.caption)
                        .foregroundColor(peer.status.color)
                    Text("·")
                        .foregroundColor(.secondary)
                    Text(peer.host)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if !peer.sharedModules.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(peer.sharedModules, id: \.self) { mod in
                            Text(mod)
                                .font(.system(size: 8))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.accentColor.opacity(0.1))
                                .cornerRadius(3)
                        }
                    }
                }
            }

            Spacer()

            if !isLocal {
                Button(I18nManager.shared.t(.col_invite)) {}
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 会话视图

struct SessionView: View {
    @StateObject private var collab = CollaborationService.shared
    @State private var showCreateSession = false

    var body: some View {
        if let session = collab.activeSession {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .foregroundColor(.green)
                    Text(session.name)
                        .font(.title2)
                        .bold()
                    Spacer()
                    Button(action: { collab.leaveSession() }) {
                        Label(I18nManager.shared.t(.col_leave), systemImage: "xmark")
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
                .padding(.horizontal)

                GroupBox(I18nManager.shared.tf(.col_members_fmt, session.members.count)) {
                    ForEach(session.members) { member in
                        PeerRow(peer: member, isLocal: member.id == collab.localPeer.id)
                    }
                    .padding(8)
                }
                .padding(.horizontal)

                GroupBox(I18nManager.shared.tf(.col_resources_fmt, session.sharedResources.count)) {
                    if session.sharedResources.isEmpty {
                        Text(I18nManager.shared.t(.col_no_resources))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(8)
                    } else {
                        ForEach(session.sharedResources) { resource in
                            HStack {
                                Image(systemName: resource.type.icon)
                                Text(resource.name)
                                Spacer()
                                Text(resource.ownerId)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.vertical)
        } else {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                Text(I18nManager.shared.t(.col_no_session))
                    .foregroundColor(.secondary)
                Text(I18nManager.shared.t(.col_no_session_hint))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button(action: { showCreateSession = true }) {
                    Label(I18nManager.shared.t(.col_new_session), systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                Spacer()
            }
            .sheet(isPresented: $showCreateSession) {
                createSessionSheet
            }
        }
    }

    private var createSessionSheet: some View {
        @State var name = ""
        return VStack(spacing: 16) {
            Text(I18nManager.shared.t(.col_create_session))
                .font(.title2)
                .bold()
            TextField(I18nManager.shared.t(.col_session_name), text: $name)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button(I18nManager.shared.t(.col_cancel)) { showCreateSession = false }
                    .buttonStyle(.bordered)
                Button(I18nManager.shared.t(.col_create)) {
                    collab.createSession(name: name)
                    showCreateSession = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
    }
}

// MARK: - 共享资源

struct SharedResourcesView: View {
    @StateObject private var collab = CollaborationService.shared
    @State private var selectedType: SharedResource.ResourceType?

    var body: some View {
        VStack(spacing: 0) {
            // 筛选
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(SharedResource.ResourceType.allCases, id: \.self) { type in
                        let isSelected = selectedType == type
                        Button(action: { selectedType = isSelected ? nil : type }) {
                            Label(type.localizedName, systemImage: type.icon)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(isSelected ? Color.accentColor : nil)
                    }
                }
                .padding(8)
            }

            Divider()

            if let session = collab.activeSession, !session.sharedResources.isEmpty {
                List(session.sharedResources) { resource in
                    HStack(spacing: 10) {
                        Image(systemName: resource.type.icon)
                            .foregroundColor(.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(resource.name)
                                .font(.subheadline)
                            Text("\(resource.ownerId) · \(resource.lastModified.formatted(date: .numeric, time: .shortened))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(I18nManager.shared.t(.col_download)) {}
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                    .padding(.vertical, 4)
                }
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text(I18nManager.shared.t(.col_no_resources))
                        .foregroundColor(.secondary)
                    Text(I18nManager.shared.t(.col_no_resources_hint))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
    }
}

// MARK: - 协作设置

struct CollabSettingsView: View {
    @StateObject private var collab = CollaborationService.shared
    @AppStorage("collab.serviceName") private var serviceName = "Fusion Studio"
    @AppStorage("collab.autoAccept") private var autoAccept = false
    @AppStorage("collab.shareDesign") private var shareDesign = true
    @AppStorage("collab.shareCode") private var shareCode = true
    @AppStorage("collab.shareModels") private var shareModels = false
    @AppStorage("collab.port") private var port = 8000

    var body: some View {
        Form {
            Section(I18nManager.shared.t(.col_section_identity)) {
                TextField(I18nManager.shared.t(.col_service_name), text: $serviceName)
                    .textFieldStyle(.roundedBorder)
                Stepper(I18nManager.shared.tf(.col_port_fmt, port), value: $port, in: 1024...65535, step: 1)
            }

            Section(I18nManager.shared.t(.col_section_auto)) {
                Toggle(I18nManager.shared.t(.col_auto_accept), isOn: $autoAccept)
            }

            Section(I18nManager.shared.t(.col_section_share)) {
                Toggle(I18nManager.shared.t(.col_share_design), isOn: $shareDesign)
                Toggle(I18nManager.shared.t(.col_share_code), isOn: $shareCode)
                Toggle(I18nManager.shared.t(.col_share_model), isOn: $shareModels)
            }

            Section(I18nManager.shared.t(.col_section_security)) {
                Toggle(I18nManager.shared.t(.col_password), isOn: .constant(false))
                Toggle(I18nManager.shared.t(.col_encrypt), isOn: .constant(true))
                    .disabled(true)
            }

            Section(I18nManager.shared.t(.col_section_note)) {
                Text(I18nManager.shared.t(.col_note_desc))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .formStyle(.grouped)
    }
}