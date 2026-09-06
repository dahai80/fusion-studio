import Foundation
import Combine
import os.log

// ARCH-1 (审计product-0906 P1, ARCH-1): DesignBridge 38 @Published 拆 10 独立 ObservableObject 域类型。
//   复用 AgentBridge #359 已验模式 (AgentBridgeDomains.swift)。DesignBridge 持 let 域引用 (稳定身份),
//   init() objectWillChange.sink 转发每域 (SwiftUI 不自动追踪嵌套 ObservableObject, P0-1 修)。
//   38 属性经 DesignBridge 计算属性 get/set 转发保 113 view 读站点 0 改。行为按域分阶段迁入
//   extension <Domain>Service.swift (Phase 2-8)。ipcClient 为 internal (非 private): 跨文件 extension 可达。
// 域: ChatState / ArtifactState / PageState / CanvasState / PlanPreviewState / SkillState /
//     VersionState / ThemeState / ExportState / FileSyncState。

private let designDomainLog = Logger(subsystem: "com.fusion.studio", category: "DesignBridgeDomains")

// ARCH-1 Phase 2: antArtifact XML 增量解析状态机。internal: DesignChatState + DesignChatService + DesignBridge 协调器共享。
enum ArtifactParseState {
    case idle
    case inOpenTag
    case inCode
    case inCloseTag
}

// MARK: - Chat State (会话 / 推理进度 / 模型选择)

@MainActor
final class DesignChatState: ObservableObject {
    @Published var messages: [DesignMessage] = []
    @Published var isGenerating: Bool = false
    @Published var inferenceStep: String = ""
    @Published var streamTokenCount: Int = 0
    @Published var streamPreviewText: String = ""
    @Published var errorMessage: String?
    @Published var selectedModel: String = ""
    // ARCH-1 Phase 2: stream 解析态 (antArtifact XML 增量解析) 迁本域。internal: 跨文件 extension + DesignBridge 协调器可达。
    var parseState: ArtifactParseState = .idle
    var parseBuffer: String = ""
    var currentIdentifier: String = ""
    var rawAssistantContent: String = ""
    // ARCH-1: Chat 行为 (sendDesignChat 协调器留 DesignBridge; parse/capMessages/extract* Phase 2 迁入)。
    //   纯 HTTP (URLSession) + CLI, 0 IPC → 无 ipcClient ref。
    //   bridge ref: 跨域读 (artifact/canvas/page) 经 self.bridge?.X reach-through。
    weak var bridge: DesignBridge?
    init() {}
}

// MARK: - Artifact State (当前产物 / 保存状态 / 截图导入)

@MainActor
final class DesignArtifactState: ObservableObject {
    @Published var currentArtifactCode: String = ""
    @Published var currentArtifactType: String = "html"
    @Published var currentArtifactTitle: String = ""
    @Published var artifactSaved: Bool = false
    @Published var artifactId: String = ""
    @Published var isImportingScreenshot: Bool = false
    // ARCH-1 Phase 3: sessionId 迁本域 (artifact 持久化会话标识, saveAsArtifact 唯一读, clearConversation 重置)。
    var sessionId: String = "design-\(UUID().uuidString.prefix(8))"
    // ARCH-1: Artifact 行为 (saveAsArtifact/kindForType/importScreenshot/sanitizeFileName Phase 3 迁入)。
    //   saveAsArtifact 读 ipcClient (artifact 持久化 RPC) → 注入。
    //   跨域写 (page: pages/currentPageIndex; chat: errorMessage) 经 self.bridge?.X reach-through。
    var ipcClient: IPCClient?
    weak var bridge: DesignBridge?
    init() {}
}

// MARK: - Page State (多页文档 / 当前页索引)

@MainActor
final class DesignPageState: ObservableObject {
    @Published var pages: [DesignPage] = []
    @Published var currentPageIndex: Int = -1
    // ARCH-1: Page 行为 (addPage/deletePage/renamePage/saveCurrentPageState/loadDocumentJSON/mutateNode Phase 4 迁入)。
    //   纯本地状态 + canvas 调用, 0 IPC → 无 ipcClient ref。
    weak var bridge: DesignBridge?
    init() {}
}

// MARK: - Canvas State (画布选中 / 渲染文档 / 框选节点)

@MainActor
final class DesignCanvasState: ObservableObject {
    @Published var selectedNodeID: String?
    @Published var lastRenderedDocumentJSON: String?
    @Published var marqueeSelectedNodeIDs: [String] = []
    // ARCH-1: Canvas 行为 (sendCanvasCommand/renderDocumentToCanvas/mutateCanvasNode/undo/redo/... Phase 5 迁入)。
    //   WKWebView only, 0 IPC → 无 ipcClient ref。
    //   canvasWebView(weak)/codeWatchTimer/mutateObserver Phase 5 迁本域 (现暂留 DesignBridge)。
    weak var bridge: DesignBridge?
    init() {}
}

// MARK: - Plan Preview State (待审计划代码 / 预览激活)

@MainActor
final class DesignPlanPreviewState: ObservableObject {
    @Published var pendingPlanCode: String?
    @Published var isPlanPreviewActive: Bool = false
    @Published var pendingPlanTitle: String = ""
    // ARCH-1: PlanPreview 行为 (acceptPlan/rejectPlan Phase 6 迁入)。纯状态, 0 IPC。
    weak var bridge: DesignBridge?
    init() {}
}

// MARK: - Skill State (技能输出 / 运行态 / 多变体页)

@MainActor
final class DesignSkillState: ObservableObject {
    @Published var lastSkillOutput: String = ""
    @Published var isSkillRunning: Bool = false
    @Published var variantPages: [VariantPage] = []
    // ARCH-1: Skill 行为 (skillTextToUI/.../skillHealthCheck/skillTheme Phase 6 迁入)。CLI only, 0 IPC。
    weak var bridge: DesignBridge?
    init() {}
}

// MARK: - Version State (版本历史 / 加载态 / 差异)

@MainActor
final class DesignVersionState: ObservableObject {
    @Published var versionHistory: [[String: Any]] = []
    @Published var isLoadingHistory: Bool = false
    @Published var versionDiffEntries: [DesignDiffEntry] = []
    @Published var isDiffing: Bool = false
    // ARCH-1: Version 行为 (loadVersionHistory/rollbackToVersion[协调器留 DesignBridge]/diffVersions Phase 7 迁入)。
    //   loadVersionHistory/rollback 读 ipcClient (version RPC) → 注入。
    var ipcClient: IPCClient?
    weak var bridge: DesignBridge?
    init() {}
}

// MARK: - Theme State (主题 / 设计系统)

@MainActor
final class DesignThemeState: ObservableObject {
    @Published var activeTheme: String = "dark"
    @Published var activeDesignSystem: String = "apple-hig"
    // ARCH-1: Theme 行为 (switchTheme/switchDesignSystem/ingestDesignTokens/applyDesignTokensToCanvas(systemId:) Phase 7 迁入)。
    //   CLI only, 0 IPC。
    weak var bridge: DesignBridge?
    init() {}
}

// MARK: - Export State (SwiftUI/Codegen 导出 / 批量导出)

@MainActor
final class DesignExportState: ObservableObject {
    @Published var exportedSwiftUICode: String = ""
    @Published var isExportingSwiftUI: Bool = false
    @Published var exportedCodegenCode: String = ""
    @Published var isExportingCodegen: Bool = false
    @Published var isBatchExporting: Bool = false
    @Published var batchExportResult: String = ""
    // ARCH-1: Export 行为 (exportAsSwiftUI/copyExportedSwiftUI/exportAsCodegen/.../batchExportPages/copyCurrentCode Phase 8 迁入)。
    //   CLI only, 0 IPC。
    weak var bridge: DesignBridge?
    init() {}
}

// MARK: - FileSync State (同步目录 / 启用态)

@MainActor
final class DesignFileSyncState: ObservableObject {
    @Published var syncFolderPath: String = ""
    @Published var isFileSyncEnabled: Bool = false
    // ARCH-1: FileSync 行为 (enableFileSync/disableFileSync/syncArtifactToFile/syncFileToArtifact Phase 8 迁入)。
    //   syncArtifactToFile/syncFileToArtifact 读 ipcClient (artifact 持久化回写) → 注入。
    var ipcClient: IPCClient?
    weak var bridge: DesignBridge?
    init() {}
}
