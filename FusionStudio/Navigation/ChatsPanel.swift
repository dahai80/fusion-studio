// Callers: SectionContentView (case .chats).
// Affected API: ChatsPanel (chat history list with search/filter/select), ChatStore, ChatRecord.
// Data schemas: ChatRecord (id/title/preview/date/module), ChatStore (singleton with records array).
// User instruction: "点击Chats 右侧展示 右上角查询按钮，Filter选项，select按钮和New Chat按钮，下面展示历史聊天记录"

import SwiftUI
import os.log

private let chatsLog = Logger(subsystem: "com.fusion.studio", category: "ChatsPanel")

struct ChatRecord: Identifiable {
    let id = UUID()
    let title: String
    let preview: String
    let date: Date
    let module: String
}

class ChatStore: ObservableObject {
    static let shared = ChatStore()
    @Published var records: [ChatRecord] = []

    init() {
        records = [
            ChatRecord(title: "SwiftUI Layout Help", preview: "How do I create a custom layout...", date: Date().addingTimeInterval(-3600), module: "Code"),
            ChatRecord(title: "Python Data Pipeline", preview: "Can you help me build an ETL...", date: Date().addingTimeInterval(-7200), module: "Code"),
            ChatRecord(title: "React Component Design", preview: "I need a reusable modal...", date: Date().addingTimeInterval(-86400), module: "Code"),
            ChatRecord(title: "Rust WebSocket Server", preview: "Building a real-time chat server...", date: Date().addingTimeInterval(-172800), module: "Code"),
            ChatRecord(title: "SQL Query Optimization", preview: "This query is running slow...", date: Date().addingTimeInterval(-259200), module: "Code"),
        ]
    }

    func deleteRecords(ids: Set<UUID>) {
        records.removeAll { ids.contains($0.id) }
        chatsLog.info("Deleted \(ids.count) chat records")
    }
}

struct ChatsPanel: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var store = ChatStore.shared
    @State private var searchText = ""
    @State private var isSelectMode = false
    @State private var selectedIds: Set<UUID> = []
    @State private var filterOption = "All"

    private var filteredRecords: [ChatRecord] {
        if searchText.isEmpty { return store.records }
        return store.records.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.preview.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Rectangle().fill(theme.separator).frame(height: 1)

            if isSelectMode {
                selectActionBar
                Rectangle().fill(theme.separator).frame(height: 1)
            }

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredRecords) { record in
                        chatRow(record)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var headerBar: some View {
        HStack(spacing: theme.spacingS) {
            Spacer()

            Button(action: { withAnimation { } }) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Search")

            Menu {
                Button("All") { filterOption = "All" }
                Button("Today") { filterOption = "Today" }
                Button("Last 7 Days") { filterOption = "Last 7 Days" }
                Button("Last 30 Days") { filterOption = "Last 30 Days" }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: theme.iconXS))
                    Text("Filter")
                        .font(.system(size: theme.footnoteSize))
                }
                .foregroundStyle(theme.textTertiary)
            }

            Button(action: {
                withAnimation(theme.springSnappy) {
                    isSelectMode.toggle()
                    if !isSelectMode { selectedIds.removeAll() }
                }
            }) {
                Text(isSelectMode ? "Cancel" : "Select")
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)

            Button(action: startNewChat) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: theme.iconXS))
                    Text("New Chat")
                        .font(.system(size: theme.footnoteSize, weight: .medium))
                }
                .foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingS)
    }

    private var selectActionBar: some View {
        HStack(spacing: theme.spacingM) {
            if selectedIds.count == filteredRecords.count && !filteredRecords.isEmpty {
                Button("Deselect All") {
                    selectedIds.removeAll()
                }
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.accent)
                .buttonStyle(.plain)
            } else {
                Button("Select All") {
                    selectedIds = Set(filteredRecords.map(\.id))
                }
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.accent)
                .buttonStyle(.plain)
            }

            Spacer()

            Text("\(selectedIds.count) selected")
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textTertiary)

            Button(action: moveSelectedToProject) {
                Text("Move to Project")
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)
            .disabled(selectedIds.isEmpty)

            Button(action: deleteSelected) {
                Text("Delete")
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(theme.redDot)
            }
            .buttonStyle(.plain)
            .disabled(selectedIds.isEmpty)

            Button("Cancel") {
                isSelectMode = false
                selectedIds.removeAll()
            }
            .font(.system(size: theme.footnoteSize))
            .foregroundStyle(theme.textTertiary)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingXS)
        .background(theme.surfaceSecondary)
    }

    private func chatRow(_ record: ChatRecord) -> some View {
        let isSelected = selectedIds.contains(record.id)
        return Button(action: {
            if isSelectMode {
                withAnimation(theme.springSnappy) {
                    if isSelected {
                        selectedIds.remove(record.id)
                    } else {
                        selectedIds.insert(record.id)
                    }
                }
            }
        }) {
            HStack(spacing: theme.spacingM) {
                if isSelectMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: theme.iconM))
                        .foregroundStyle(isSelected ? theme.accent : theme.textTertiary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(record.title)
                        .font(.system(size: theme.textSize, weight: .medium))
                        .foregroundStyle(theme.text)
                        .lineLimit(1)

                    Text(record.preview)
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(record.date, style: .date)
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)

                    Text(record.module)
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textQuaternary)
                }
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.vertical, theme.spacingM)
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                    .fill(isSelected ? theme.accent.opacity(0.08) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func startNewChat() {
        CodeAgent.shared.clearConversation()
        chatsLog.info("New chat started from ChatsPanel")
    }

    private func deleteSelected() {
        store.deleteRecords(ids: selectedIds)
        selectedIds.removeAll()
        if store.records.isEmpty { isSelectMode = false }
    }

    private func moveSelectedToProject() {
        chatsLog.info("Move \(selectedIds.count) chats to project — placeholder")
        selectedIds.removeAll()
    }
}
