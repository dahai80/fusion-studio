import SwiftUI

struct FCSessionSidebar: View {
    @ObservedObject var bridge: FusionCodeBridge
    @Binding var selectedSessionId: String?
    @Binding var layoutMode: FCLayoutMode
    @State private var groupMode: FCSidebarGroupMode = .byState
    @State private var showNewSession = false
    @State private var searchText = ""
    @State private var hoveredSessionId: String?
    @StateObject private var i18n = I18nManager.shared

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
            Text(i18n.t(.fc_sessions))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            Spacer()
            Button(action: { showNewSession = true }) {
                Image(systemName: "plus")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help(i18n.t(.fc_new_session))
            Menu {
                ForEach(FCSidebarGroupMode.allCases, id: \.self) { mode in
                    Button(mode.localLabel) { groupMode = mode }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help(i18n.t(.fc_group_mode))
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
            TextField(i18n.t(.fc_search_sessions), text: $searchText)
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
                        Text(project.isEmpty ? i18n.t(.fc_no_project2) : project)
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
                    Text(String(format: i18n.t(.fc_messages_count), session.messageCount))
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
            Button(i18n.t(.fc_rename)) {
                bridge.renameSession(id: session.id, name: "Renamed")
            }
            if session.canPause {
                Button(i18n.t(.fc_pause)) { bridge.pauseSession(id: session.id) }
            }
            if session.canResume {
                Button(i18n.t(.fc_resume)) { bridge.resumeSession(id: session.id) }
            }
            Divider()
            Button(i18n.t(.fc_clone)) { bridge.cloneSession(id: session.id) }
            Divider()
            Button(i18n.t(.fc_delete), role: .destructive) {
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
                        Label(mode.localLabel, systemImage: mode.icon)
                    }
                }
            } label: {
                Image(systemName: layoutMode.icon)
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help(i18n.t(.fc_layout_mode))
            Spacer()
            Text(String(format: i18n.t(.fc_sessions_count), bridge.sessions.count))
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
    @StateObject private var i18n = I18nManager.shared

    @State private var name = ""
    @State private var workingDir = ""
    @State private var model = "qwen3.5-9b"
    @State private var temperature = 0.1
    @State private var maxTokens = 4096
    @State private var securityMode = "manual"

    var body: some View {
        VStack(spacing: 12) {
            Text(i18n.t(.fc_new_session_full))
                .font(.system(size: 14, weight: .semibold))

            formRow(i18n.t(.fc_title)) {
                TextField(i18n.t(.fc_session_title_ph), text: $name)
                    .textFieldStyle(.roundedBorder)
            }
            formRow(i18n.t(.fc_working_dir)) {
                TextField("/path/to/project", text: $workingDir)
                    .textFieldStyle(.roundedBorder)
            }
            formRow(i18n.t(.fc_model_label)) {
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
            formRow(i18n.t(.fc_security_mode)) {
                Picker("", selection: $securityMode) {
                    Text(i18n.t(.fc_sm_readonly)).tag("readonly")
                    Text(i18n.t(.fc_sm_manual)).tag("manual")
                    Text(i18n.t(.fc_sm_auto)).tag("auto")
                }
                .labelsHidden()
            }

            HStack(spacing: 12) {
                Button(i18n.t(.fc_cancel)) { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                Button(i18n.t(.fc_create)) {
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
