// Callers: RAGPipelineView (tab within existing module view, replaces old documents tab)
// API: RAGAPIClient.shared for CRUD operations on knowledge bases
// schema: KBInfo model — id/name/description/chunkStrategy/embeddingModel/fileCount/chunkCount/createdAt
// user instruction: "完成所有待办任务"

import SwiftUI
import os

struct KBListView: View {
    @StateObject private var client = RAGAPIClient.shared
    @State private var showCreate = false
    @State private var newName = ""
    @State private var newDesc = ""
    @State private var newChunkStrategy = "semantic"
    @State private var newEmbedModel = "BGE-M3"
    @State private var selectedKB: KBInfo?
    @State private var showScanDir = false
    @State private var scanDirPath = ""

    private let logger = Logger(subsystem: "com.fusion.studio", category: "KBListView")

    let chunkStrategies = ["semantic", "fixed", "code"]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("知识库")
                    .font(.headline)
                Spacer()
                Button {
                    Task { await client.listBases() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("刷新列表")
                Button {
                    showCreate = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("创建知识库")
            }
            .padding(12)
            Divider()

            if client.isLoading && client.knowledgeBases.isEmpty {
                Spacer()
                ProgressView("加载中...")
                Spacer()
            } else if client.knowledgeBases.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "books.vertical")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("暂无知识库")
                        .foregroundStyle(.secondary)
                    Button("创建知识库") { showCreate = true }
                }
                Spacer()
            } else {
                List(client.knowledgeBases, selection: $selectedKB) { kb in
                    KBRowView(kb: kb, client: client)
                        .tag(kb)
                        .contextMenu {
                            Button("扫描目录导入") {
                                selectedKB = kb
                                scanDirPath = ""
                                showScanDir = true
                            }
                            Divider()
                            Button("删除", role: .destructive) {
                                Task {
                                    let ok = await client.deleteBase(kbId: kb.id)
                                    if ok { await client.listBases() }
                                }
                            }
                        }
                }
                .listStyle(.sidebar)
            }

            if let err = client.lastError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(8)
            }
        }
        .sheet(isPresented: $showCreate) {
            createSheet
        }
        .sheet(isPresented: $showScanDir) {
            scanDirSheet
        }
        .task {
            await client.listBases()
        }
    }

    private var createSheet: some View {
        VStack(spacing: 16) {
            Text("创建知识库").font(.headline)
            TextField("名称", text: $newName)
            TextField("描述", text: $newDesc)
            Picker("分块策略", selection: $newChunkStrategy) {
                ForEach(chunkStrategies, id: \.self) { s in
                    Text(s).tag(s)
                }
            }
            TextField("嵌入模型", text: $newEmbedModel)
            HStack {
                Button("取消") {
                    showCreate = false
                    newName = ""
                    newDesc = ""
                }
                Spacer()
                Button("创建") {
                    guard !newName.isEmpty else { return }
                    Task {
                        if let _ = await client.createBase(
                            name: newName,
                            description: newDesc,
                            chunkStrategy: newChunkStrategy,
                            embeddingModel: newEmbedModel
                        ) {
                            await client.listBases()
                            showCreate = false
                            newName = ""
                            newDesc = ""
                        }
                    }
                }
                .disabled(newName.isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 400)
    }

    private var scanDirSheet: some View {
        VStack(spacing: 16) {
            Text("扫描目录导入").font(.headline)
            if let kb = selectedKB {
                Text("知识库: \(kb.name)")
                    .foregroundStyle(.secondary)
            }
            TextField("目录路径", text: $scanDirPath)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("取消") { showScanDir = false }
                Spacer()
                Button("开始扫描") {
                    guard let kb = selectedKB, !scanDirPath.isEmpty else { return }
                    Task {
                        let result = await client.scanDirectory(kbId: kb.id, dirPath: scanDirPath)
                        if result != nil {
                            showScanDir = false
                            await client.listBases()
                        }
                    }
                }
                .disabled(scanDirPath.isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 400)
    }
}

struct KBRowView: View {
    let kb: KBInfo
    let client: RAGAPIClient

    var body: some View {
        HStack {
            Image(systemName: "book.closed")
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(kb.name)
                    .font(.body)
                HStack(spacing: 8) {
                    if let fc = kb.fileCount, fc > 0 {
                        Label("\(fc) 文件", systemImage: "doc")
                            .font(.caption2)
                    }
                    if let cc = kb.chunkCount, cc > 0 {
                        Label("\(cc) 分块", systemImage: "square.grid.2x2")
                            .font(.caption2)
                    }
                    if let model = kb.embeddingModel {
                        Text(model)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }
}
