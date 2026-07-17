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

let sampleKBEntries: [KBEntry] = [
    KBEntry(id: "kb-1", title: "Fusion Studio 架构", content: "Fusion Studio 采用五层架构...", source: "ARCHITECTURE.md", relevance: 0.95, lastUpdated: Date(), tags: ["架构"]),
    KBEntry(id: "kb-2", title: "环境自检项说明", content: "环境自检包含 7 项检查...", source: "docs/guide.md", relevance: 0.88, lastUpdated: Date(), tags: ["环境", "配置"]),
    KBEntry(id: "kb-3", title: "IPC 协议详解", content: "JSON-RPC 2.0 over Unix Socket...", source: "docs/api.md", relevance: 0.82, lastUpdated: Date(), tags: ["IPC", "API"]),
]

struct KBView: View {
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
                    TextField("搜索知识库...", text: $searchText)
                        .textFieldStyle(.plain)
                    if isSearching {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))

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
                    Text("选择一条知识条目")
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
                    Text("相关度: \(Int(entry.relevance * 100))%")
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