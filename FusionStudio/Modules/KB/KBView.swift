// Callers: ModuleDetailView routing.
// Affected API: KBView (replacing NSColor with StudioTheme tokens).
// Data schemas: None changed.
// User instruction: "帮我用 UI/UX Pro Max 重新设计 fusion-studio 的整体 GUI - macOS 原生风格 - 三栏 - 暗色模式优先 - 主色 #007AFF"

import SwiftUI

/// 知识库条目
struct KBEntry: Identifiable, Hashable {
    let id: String
    var title: String
    var content: String
    var source: String
    var relevance: Double
    var lastUpdated: Date
    var tags: [String]

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: KBEntry, rhs: KBEntry) -> Bool {
        lhs.id == rhs.id
    }
}

var sampleKBEntries: [KBEntry] {
    [
    KBEntry(id: "kb-1", title: I18nManager.shared.t(.kb_sample_1_title), content: I18nManager.shared.t(.kb_sample_1_content), source: "ARCHITECTURE.md", relevance: 0.95, lastUpdated: Date(), tags: [I18nManager.shared.t(.kb_sample_1_tag_arch)]),
    KBEntry(id: "kb-2", title: I18nManager.shared.t(.kb_sample_2_title), content: I18nManager.shared.t(.kb_sample_2_content), source: "docs/guide.md", relevance: 0.88, lastUpdated: Date(), tags: [I18nManager.shared.t(.kb_sample_2_tag_env), I18nManager.shared.t(.kb_sample_2_tag_config)]),
    KBEntry(id: "kb-3", title: I18nManager.shared.t(.kb_sample_3_title), content: I18nManager.shared.t(.kb_sample_3_content), source: "docs/api.md", relevance: 0.82, lastUpdated: Date(), tags: ["IPC", "API"]),
    ]
}

struct KBView: View {
    @Environment(\.studioTheme) private var theme
    @State private var entries: [KBEntry] = sampleKBEntries
    @State private var searchText = ""
    @State private var selectedEntry: KBEntry?
    @State private var isSearching = false

    var filteredEntries: [KBEntry] {
        if searchText.isEmpty { return entries }
        return entries.filter { entry in
            entry.title.localizedCaseInsensitiveContains(searchText) ||
            entry.content.localizedCaseInsensitiveContains(searchText) ||
            entry.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        HSplitView {
            // 左侧：条目列表
            VStack(spacing: 0) {
                // 搜索栏
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField(I18nManager.shared.t(.kb_ph_search), text: $searchText)
                        .textFieldStyle(.plain)
                    if isSearching {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .padding(8)
                .background(theme.surfaceSecondary)

                Divider()

                List(selection: $selectedEntry) {
                    ForEach(filteredEntries) { entry in
                        KBEntryRow(entry: entry)
                            .tag(entry)
                    }
                }
                .listStyle(.plain)
            }
            .frame(minWidth: 250, maxWidth: 350)

            // 右侧：详情
            if let entry = selectedEntry {
                KBEntryDetail(entry: entry)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "books.vertical")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text(I18nManager.shared.t(.kb_msg_select_entry))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

struct KBEntryRow: View {
    let entry: KBEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.title)
                    .font(.headline)
                Spacer()
                Text("\(Int(entry.relevance * 100))%")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            Text(entry.content.prefix(80))
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            HStack {
                Text(entry.source)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text(entry.lastUpdated, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct KBEntryDetail: View {
    let entry: KBEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(entry.title)
                    .font(.largeTitle)
                    .bold()

                HStack(spacing: 12) {
                    Label(entry.source, systemImage: "doc.text")
                    Spacer()
                    Text(String(format: I18nManager.shared.t(.kb_label_relevance), Int(entry.relevance * 100)))
                        .foregroundColor(.blue)
                }
                .font(.subheadline)
                .foregroundColor(.secondary)

                HStack {
                    ForEach(entry.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(4)
                    }
                }

                Divider()

                Text(entry.content)
                    .font(.body)
            }
            .padding()
        }
    }
}