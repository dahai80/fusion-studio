import SwiftUI

struct FCSessionSidebar: View {
    @ObservedObject var bridge: FusionCodeBridge
    @Binding var selectedSessionId: String?
    @Binding var layoutMode: FCLayoutMode
    @State private var groupMode: FCSidebarGroupMode = .byState
    @State private var showNewSession = false
    @State private var searchText = ""
    @State private var hoveredSessionId: String?

    private let sidebarWidth: CGFloat = 220

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            searchBar
            sessionList
            footerBar
        }
        .frame(width: sidebarWidth)
        .background(Color(nsColor: .controlBackgroundColor))
        .sheet(isPresented: $showNewSession) {
            FCNewSessionSheet(bridge: bridge, isPresented: $showNewSession) { newId in
                selectedSessionId = newId
            }
        }
    }

    private var headerBar: some View {
        HStack(spacing: 4) {
            Text("Sessions")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            Spacer()
            Button(action: { showNewSession = true }) {
                Image(systemName: "plus")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help("新建会话")
            Menu {
                ForEach(FCSidebarGroupMode.allCases, id: \.self) { mode in
                    Button(mode.rawValue) { groupMode = mode }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help("分组方式")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    private var searchBar: some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            TextField("搜索会话...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.3))
        .cornerRadius(4)
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
    }

    private var sessionList: some View {
        ScrollView {
            switch groupMode {
            case .byState:
                sessionListByState
            case .byProject:
                sessionListByProject
            case .flat:
                sessionListFlat
            }
        }
    }

    private var sessionListByState: some View {
        let grouped = Dictionary(grouping: filteredSessions) { $0.state }
        let orderedStates = FCSessionState.allCases.filter { grouped[$0] != nil }
        return ForEach(orderedStates, id: \.self) { state in
            if let sessions = grouped[state] {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: state.icon)
                            .font(.system(size: 9))
                            .foregroundColor(colorForName(state.color))
                        Text(state.label)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        Text("(\(sessions.count))")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 6)
                    .padding(.bottom, 2)

                    ForEach(sessions) { session in
                        sessionRow(session)
                    }
                }
            }
        }
    }

    private var sessionListByProject: some View {
        let grouped = Dictionary(grouping: filteredSessions) { session in
            URL(fileURLWithPath: session.config.workingDir).lastPathComponent
        }
        let sorted = grouped.keys.sorted()
        return ForEach(sorted, id: \.self) { project in
            if let sessions = grouped[project] {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Text(project.isEmpty ? "无项目" : project)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        Text("(\(sessions.count))")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 6)
                    .padding(.bottom, 2)

                    ForEach(sessions) { session in
                        sessionRow(session)
                    }
                }
            }
        }
    }

    private var sessionListFlat: some View {
        ForEach(filteredSessions) { session in
            sessionRow(session)
        }
    }

    private func sessionRow(_ session: FCSessionDetail) -> some View {
        let isSelected = selectedSessionId == session.id
        let isHovered = hoveredSessionId == session.id
        return HStack(spacing: 6) {
            Image(systemName: session.state.icon)
                .font(.system(size: 8))
                .foregroundColor(colorForName(session.state.color))
            VStack(alignment: .leading, spacing: 1) {
                Text(session.displayTitle)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                if session.messageCount > 0 {
                    Text("\(session.messageCount) 条消息")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? Color.accentColor.opacity(0.2) :
                      isHovered ? Color(nsColor: .controlBackgroundColor).opacity(0.5) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectedSessionId = session.id
        }
        .onHover { hovering in
            hoveredSessionId = hovering ? session.id : nil
        }
        .contextMenu { sessionContextMenu(session) }
    }

    private func sessionContextMenu(_ session: FCSessionDetail) -> some View {
        Group {
            Button("重命名") {
                bridge.renameSession(id: session.id, name: "Renamed")
            }
            if session.canPause {
                Button("暂停") { bridge.pauseSession(id: session.id) }
            }
            if session.canResume {
                Button("恢复") { bridge.resumeSession(id: session.id) }
            }
            Divider()
            Button("克隆") { bridge.cloneSession(id: session.id) }
            Divider()
            Button("删除", role: .destructive) {
                bridge.deleteSession(id: session.id)
                if selectedSessionId == session.id {
                    selectedSessionId = nil
                }
            }
        }
    }

    private var footerBar: some View {
        HStack(spacing: 4) {
            Menu {
                ForEach(FCLayoutMode.allCases, id: \.self) { mode in
                    Button(action: { layoutMode = mode }) {
                        Label(mode.rawValue, systemImage: mode.icon)
                    }
                }
            } label: {
                Image(systemName: layoutMode.icon)
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help("布局模式")
            Spacer()
            Text("\(bridge.sessions.count) 个会话")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    private var filteredSessions: [FCSessionDetail] {
        if searchText.isEmpty { return bridge.sessions }
        return bridge.sessions.filter {
            $0.displayTitle.localizedCaseInsensitiveContains(searchText) ||
            $0.config.workingDir.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func colorForName(_ name: String) -> Color {
        switch name {
        case "green": return .green
        case "yellow": return .yellow
        case "orange": return .orange
        case "blue": return .blue
        case "red": return .red
        case "purple": return .purple
        default: return .gray
        }
    }
}

struct FCNewSessionSheet: View {
    @ObservedObject var bridge: FusionCodeBridge
    @Binding var isPresented: Bool
    let onCreated: (String) -> Void

    @State private var name = ""
    @State private var workingDir = ""
    @State private var model = "qwen3.5-9b"
    @State private var temperature = 0.1
    @State private var maxTokens = 4096
    @State private var securityMode = "manual"

    var body: some View {
        VStack(spacing: 12) {
            Text("新建编码会话")
                .font(.system(size: 14, weight: .semibold))

            formRow("名称") {
                TextField("会话名称", text: $name)
                    .textFieldStyle(.roundedBorder)
            }
            formRow("工作目录") {
                TextField("/path/to/project", text: $workingDir)
                    .textFieldStyle(.roundedBorder)
            }
            formRow("模型") {
                Picker("", selection: $model) {
                    ForEach(bridge.availableModels, id: \.self) { m in
                        Text(m).tag(m)
                    }
                }
                .labelsHidden()
            }
            formRow("Temperature") {
                HStack {
                    Slider(value: $temperature, in: 0...1, step: 0.05)
                    Text(String(format: "%.2f", temperature))
                        .font(.system(size: 10))
                        .frame(width: 35)
                }
            }
            formRow("Max Tokens") {
                TextField("4096", value: $maxTokens, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
            }
            formRow("安全模式") {
                Picker("", selection: $securityMode) {
                    Text("只读").tag("readonly")
                    Text("手动审批").tag("manual")
                    Text("自动").tag("auto")
                }
                .labelsHidden()
            }

            HStack(spacing: 12) {
                Button("取消") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                Button("创建") {
                    let config = FCSessionConfig(
                        name: name,
                        workingDir: workingDir,
                        model: model,
                        temperature: temperature,
                        maxTokens: maxTokens,
                        securityMode: securityMode
                    )
                    let newId = bridge.createSession(config: config)
                    onCreated(newId)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty && workingDir.isEmpty)
            }
            .padding(.top, 8)
        }
        .padding(20)
        .frame(width: 380)
    }

    private func formRow(_ label: String, content: () -> some View) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 12))
                .frame(width: 70, alignment: .trailing)
                .padding(.top, 4)
            content()
        }
    }
}
