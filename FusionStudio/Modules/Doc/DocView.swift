import SwiftUI

/// 文档条目
struct DocEntry: Identifiable, Hashable {
    let id: String
    var title: String
    var content: String
    var lastModified: Date
    var tags: [String]
    var category: DocCategory

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: DocEntry, rhs: DocEntry) -> Bool {
        lhs.id == rhs.id
    }

    enum DocCategory: String, CaseIterable {
        case note    = "笔记"
        case design  = "设计文档"
        case api     = "API 文档"
        case guide   = "使用指南"
        case other   = "其他"

        var icon: String {
            switch self {
            case .note:   return "note.text"
            case .design: return "pencil.and.outline"
            case .api:    return "doc.text.magnifyingglass"
            case .guide:  return "book"
            case .other:  return "doc"
            }
        }
    }
}

let sampleDocs: [DocEntry] = [
    DocEntry(id: "doc-1", title: "Fusion Studio 架构设计", content: "# 架构设计\n\n## 分层架构\n\nFusion Studio 采用五层架构...", lastModified: Date(), tags: ["架构", "设计"], category: .design),
    DocEntry(id: "doc-2", title: "IPC 通信协议", content: "# IPC 协议\n\n## JSON-RPC 2.0\n\n通信基于 Unix Socket...", lastModified: Date(), tags: ["IPC", "协议"], category: .api),
    DocEntry(id: "doc-3", title: "快速开始指南", content: "# 快速开始\n\n## 安装\n\n1. 克隆仓库...", lastModified: Date(), tags: ["指南", "入门"], category: .guide),
    DocEntry(id: "doc-4", title: "开发笔记", content: "## 待办事项\n\n- [ ] 完善仿真模块\n- [ ] 优化性能\n- [ ] 编写测试", lastModified: Date(), tags: ["笔记", "待办"], category: .note),
]

struct DocView: View {
    @State private var documents: [DocEntry] = sampleDocs
    @State private var selectedDoc: DocEntry?
    @State private var searchText = ""
    @State private var selectedCategory: DocEntry.DocCategory?

    var filteredDocs: [DocEntry] {
        var result = documents
        if let cat = selectedCategory {
            result = result.filter { $0.category == cat }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
        return result
    }

    var body: some View {
        HSplitView {
            // 左侧列表
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("搜索文档...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))

                Divider()

                List(selection: $selectedDoc) {
                    ForEach(DocEntry.DocCategory.allCases, id: \.self) { cat in
                        Section {
                            let docs = filteredDocs.filter { $0.category == cat }
                            ForEach(docs) { doc in
                                Label(doc.title, systemImage: cat.icon)
                                    .tag(doc)
                                    .font(.subheadline)
                            }
                        } header: {
                            Label(cat.rawValue, systemImage: cat.icon)
                        }
                    }
                }
                .listStyle(.sidebar)
            }
            .frame(minWidth: 200, maxWidth: 300)

            // 右侧编辑器
            if let doc = selectedDoc {
                DocEditor(doc: Binding(
                    get: { doc },
                    set: { newValue in
                        if let idx = documents.firstIndex(where: { $0.id == doc.id }) {
                            documents[idx] = newValue
                        }
                    }
                ))
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("选择或创建文档")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

struct DocEditor: View {
    @Binding var doc: DocEntry

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            HStack {
                TextField("标题", text: $doc.title)
                    .font(.title2)
                    .textFieldStyle(.plain)
                Spacer()
                Text(doc.lastModified, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Markdown 编辑器
            ScrollView {
                TextEditor(text: $doc.content)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 300)
                    .padding(8)
            }
        }
    }
}