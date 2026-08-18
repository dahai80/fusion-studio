import SwiftUI

// MARK: - 支持的语言

enum AppLanguage: String, CaseIterable, Identifiable {
    case zhCN = "zh-CN"
    case enUS = "en-US"
    case jaJP = "ja-JP"
    case koKR = "ko-KR"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .zhCN: return "简体中文"
        case .enUS: return "English"
        case .jaJP: return "日本語"
        case .koKR: return "한국어"
        }
    }
    var localName: String {
        switch self {
        case .zhCN: return "中文"
        case .enUS: return "English"
        case .jaJP: return "日本語"
        case .koKR: return "한국어"
        }
    }
    var flag: String {
        switch self {
        case .zhCN: return "🇨🇳"
        case .enUS: return "🇺🇸"
        case .jaJP: return "🇯🇵"
        case .koKR: return "🇰🇷"
        }
    }
}

// MARK: - 翻译键

enum I18nKey: String, CaseIterable {
    // 通用
    case ok = "ok"
    case cancel = "cancel"
    case save = "save"
    case delete = "delete"
    case edit = "edit"
    case close = "close"
    case search = "search"
    case refresh = "refresh"
    case loading = "loading"
    case error = "error"
    case success = "success"
    case warning = "warning"
    case info = "info"
    case confirm = "confirm"
    case back = "back"
    case next = "next"
    case done = "done"

    // 导航
    case dashboard = "dashboard"
    case design = "design"
    case newChat = "newChat"
    case toggleSidebar = "toggleSidebar"
    case hideSidebar = "hideSidebar"
    case getApps = "getApps"
    case scrollUp = "scrollUp"
    case scrollDown = "scrollDown"
    case settings = "settings"
    case about = "about"
    case language = "language"
    case code = "code"
    case simulation = "simulation"
    case modelHub = "modelHub"
    case cli = "cli"
    case doc = "doc"
    case kb = "kb"
    case bench = "bench"
    case desk = "desk"

    // 环境
    case healthCheck = "healthCheck"
    case environmentHealthy = "environmentHealthy"
    case issuesFound = "issuesFound"
    case repair = "repair"
    case repairing = "repairing"
    case runHealthCheck = "runHealthCheck"

    // 任务
    case taskQueue = "taskQueue"
    case noTasks = "noTasks"
    case running = "running"
    case pending = "pending"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"

    // 设置
    case general = "general"
    case hardware = "hardware"
    case network = "network"
    case offlineMode = "offlineMode"
    case workspace = "workspace"
    case autoStart = "autoStart"
    case quantization = "quantization"

    // 硬件
    case cpu = "cpu"
    case memory = "memory"
    case gpu = "gpu"
    case mlx = "mlx"
    case metal = "metal"
    case ane = "ane"

    // 模块
    case moduleDesign = "moduleDesign"
    case moduleCode = "moduleCode"
    case moduleSimulation = "moduleSimulation"
    case moduleModelHub = "moduleModelHub"
    case moduleCLI = "moduleCLI"
    case moduleDoc = "moduleDoc"
    case moduleKB = "moduleKB"
    case moduleBench = "moduleBench"
    case moduleDesk = "moduleDesk"

    // 导航区段
    case secChats = "secChats"
    case secAgent = "secAgent"
    case secProjects = "secProjects"
    case secArtifacts = "secArtifacts"
    case secCode = "secCode"
    case secDesign = "secDesign"
    case secDoc = "secDoc"
    case secRag = "secRag"
    case secAIAgent = "secAIAgent"
    case secCowork = "secCowork"
    case secFsb = "secFsb"
    case secMlx = "secMlx"
    case secScience = "secScience"
    case secFinance = "secFinance"
    case secHealth = "secHealth"
    case secCliService = "secCliService"
    case secSimulation = "secSimulation"
    case secDouyin = "secDouyin"
    case secModelHub = "secModelHub"
    case secMultiNode = "secMultiNode"
    case secPlugin = "secPlugin"

    // 导航 UI 杂项
    case newProject = "newProject"
    case openLocalFolder = "openLocalFolder"
    case newWorkspace = "newWorkspace"
    case newWorkbench = "newWorkbench"
    case noConversationsYet = "noConversationsYet"
    case noArtifactsYet = "noArtifactsYet"
    case openArtifacts = "openArtifacts"
    case recents = "recents"
    case download = "download"
    case getHelp = "getHelp"
    case upgradePlan = "upgradePlan"
    case learnMore = "learnMore"
    case logout = "logout"
    case runDashboard = "runDashboard"
    case pendingPublish = "pendingPublish"
    case published = "published"
    case hitProduct = "hitProduct"
    case douyinHint = "douyinHint"

    // 模块标签 (Module 62 cases)
    case mod_dashboard = "mod_dashboard"
    case mod_design = "mod_design"
    case mod_code = "mod_code"
    case mod_simulation = "mod_simulation"
    case mod_modelHub = "mod_modelHub"
    case mod_multimodal = "mod_multimodal"
    case mod_training = "mod_training"
    case mod_cli = "mod_cli"
    case mod_doc = "mod_doc"
    case mod_bench = "mod_bench"
    case mod_desk = "mod_desk"
    case mod_dataTools = "mod_dataTools"
    case mod_agent = "mod_agent"
    case mod_plugin = "mod_plugin"
    case mod_security = "mod_security"
    case mod_analytics = "mod_analytics"
    case mod_collab = "mod_collab"
    case mod_tuning = "mod_tuning"
    case mod_external = "mod_external"
    case mod_docgen = "mod_docgen"
    case mod_clusterOverview = "mod_clusterOverview"
    case mod_clusterTopology = "mod_clusterTopology"
    case mod_clusterSync = "mod_clusterSync"
    case mod_taskMonitor = "mod_taskMonitor"
    case mod_alertCenter = "mod_alertCenter"
    case mod_nodeActions = "mod_nodeActions"
    case mod_submitTask = "mod_submitTask"
    case mod_taskProgress = "mod_taskProgress"
    case mod_routingStrategy = "mod_routingStrategy"
    case mod_kvCache = "mod_kvCache"
    case mod_serviceWeb = "mod_serviceWeb"
    case mod_rag = "mod_rag"
    case mod_memory = "mod_memory"
    case mod_planner = "mod_planner"
    case mod_deploy = "mod_deploy"
    case mod_operations = "mod_operations"
    case mod_eduK12 = "mod_eduK12"
    case mod_verification = "mod_verification"
    case mod_tokenBudget = "mod_tokenBudget"
    case mod_safety = "mod_safety"
    case mod_tools = "mod_tools"
    case mod_agentDashboard = "mod_agentDashboard"
    case mod_teamCollab = "mod_teamCollab"
    case mod_chat = "mod_chat"
    case mod_fusionProjects = "mod_fusionProjects"
    case mod_cowork = "mod_cowork"
    case mod_artifactsRepo = "mod_artifactsRepo"
    case mod_fsb = "mod_fsb"
    case mod_aiAgentDashboard = "mod_aiAgentDashboard"
    case mod_aiAgentList = "mod_aiAgentList"
    case mod_aiAgentChat = "mod_aiAgentChat"
    case mod_aiAgentObserver = "mod_aiAgentObserver"
    case mod_aiAgentKnowledgeBase = "mod_aiAgentKnowledgeBase"
    case mod_science = "mod_science"
    case mod_finance = "mod_finance"
    case mod_health = "mod_health"
    case mod_pluginConfig = "mod_pluginConfig"
    case mod_pluginStatus = "mod_pluginStatus"
    case mod_pluginToken = "mod_pluginToken"
    case mod_pluginVram = "mod_pluginVram"
    case mod_pluginLog = "mod_pluginLog"
    case mod_pluginMcp = "mod_pluginMcp"

    // Batch 2 — 设置面板 + Inspector
    case tab_general = "tab_general"
    case tab_modelSlots = "tab_modelSlots"
    case tab_hardware = "tab_hardware"
    case tab_network = "tab_network"
    case tab_quant = "tab_quant"
    case tab_workspace = "tab_workspace"
    case sec_startup = "sec_startup"
    case launchAtLogin = "launchAtLogin"
    case autoStartMLX = "autoStartMLX"
    case reselectMainModel = "reselectMainModel"
    case sec_window = "sec_window"
    case minimizeToMenuBar = "minimizeToMenuBar"
    case sec_language = "sec_language"
    case interfaceLanguage = "interfaceLanguage"
    case sec_hwPref = "sec_hwPref"
    case preferredDevice = "preferredDevice"
    case dev_auto = "dev_auto"
    case dev_metal = "dev_metal"
    case dev_ane = "dev_ane"
    case dev_cpu = "dev_cpu"
    case enableMetal = "enableMetal"
    case enableANE = "enableANE"
    case sec_memLimit = "sec_memLimit"
    case maxUnifiedMemory = "maxUnifiedMemory"
    case mlxMemoryHint = "mlxMemoryHint"
    case sec_offlinePolicy = "sec_offlinePolicy"
    case forceOffline = "forceOffline"
    case forceOfflineHelp = "forceOfflineHelp"
    case offlineActive = "offlineActive"
    case sec_netPerms = "sec_netPerms"
    case allowModelDownload = "allowModelDownload"
    case checkUpdates = "checkUpdates"
    case sec_quantPreset = "sec_quantPreset"
    case defaultQuant = "defaultQuant"
    case defaultFormat = "defaultFormat"
    case sec_note = "sec_note"
    case quantNote = "quantNote"
    case sec_wsDir = "sec_wsDir"
    case path = "path"
    case browse = "browse"
    case wsHint = "wsHint"
    case sec_autoMgmt = "sec_autoMgmt"
    case autoProjectSubdir = "autoProjectSubdir"
    case enableGit = "enableGit"
    case autoBackup = "autoBackup"
    case sec_slotModels = "sec_slotModels"
    case noLocalModels = "noLocalModels"
    case notSet = "notSet"
    case sec_sceneDefault = "sec_sceneDefault"
    case slotNote = "slotNote"
    case closeBtn = "closeBtn"
    case toggleInspector = "toggleInspector"

    // Batch 2 — 通用组件
    case prevTab = "prevTab"
    case nextTab = "nextTab"
    case defaultModelSlot = "defaultModelSlot"
    case moreModelsEmpty = "moreModelsEmpty"
    case loadingTemplates = "loadingTemplates"
    case currentModeClear = "currentModeClear"
    case currentStyleClear = "currentStyleClear"
    case linkedProjectClear = "linkedProjectClear"
    case releaseToAddAttachment = "releaseToAddAttachment"
    case voiceModeHelp = "voiceModeHelp"
    case selectModel = "selectModel"
    case slotNotSet = "slotNotSet"
    case moreModelsLabel = "moreModelsLabel"
    case toggleLightMode = "toggleLightMode"
    case toggleDarkMode = "toggleDarkMode"
}

// MARK: - 翻译管理器

class I18nManager: ObservableObject {
    static let shared = I18nManager()

    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "app_language")
            objectWillChange.send()
        }
    }

    private var translations: [AppLanguage: [String: String]] = [:]

    init() {
        let saved = UserDefaults.standard.string(forKey: "app_language") ?? "zh-CN"
        currentLanguage = AppLanguage(rawValue: saved) ?? .zhCN
        loadTranslations()
    }

    private func loadTranslations() {
        translations = [
            .zhCN: zhCNTranslations,
            .enUS: enUSTranslations,
            .jaJP: jaJPTranslations,
            .koKR: koKRTranslations,
        ]
    }

    func t(_ key: I18nKey) -> String {
        translations[currentLanguage]?[key.rawValue] ?? translations[.enUS]?[key.rawValue] ?? key.rawValue
    }

    func t(_ key: String) -> String {
        translations[currentLanguage]?[key] ?? translations[.enUS]?[key] ?? key
    }

    func tf(_ key: I18nKey, _ args: CVarArg...) -> String {
        let format = t(key)
        return String(format: format, arguments: args)
    }
}

// MARK: - 翻译数据

let zhCNTranslations: [String: String] = [
    "ok": "确定", "cancel": "取消", "save": "保存", "delete": "删除", "edit": "编辑",
    "close": "关闭", "search": "搜索", "refresh": "刷新", "loading": "加载中...",
    "error": "错误", "success": "成功", "warning": "警告", "info": "信息",
    "confirm": "确认", "back": "返回", "next": "下一步", "done": "完成",

    "dashboard": "控制台", "design": "设计", "code": "编码", "simulation": "仿真",
    "modelHub": "模型", "cli": "命令行", "doc": "文档", "kb": "知识库",
    "bench": "测评", "desk": "自动化", "settings": "设置", "about": "关于",

    "healthCheck": "环境健康检查", "environmentHealthy": "环境正常",
    "issuesFound": "环境异常", "repair": "修复", "repairing": "修复中...",
    "runHealthCheck": "运行环境检测",

    "taskQueue": "任务队列", "noTasks": "暂无任务",
    "running": "运行中", "pending": "排队中", "completed": "已完成",
    "failed": "失败", "cancelled": "已取消",

    "general": "通用", "hardware": "硬件加速", "network": "网络 & 离线",
    "offlineMode": "离线模式", "language": "语言", "workspace": "工作区",
    "autoStart": "自动启动", "quantization": "量化预设",

    "cpu": "CPU", "memory": "内存", "gpu": "GPU", "mlx": "MLX",
    "metal": "Metal", "ane": "神经网络引擎",

    "moduleDesign": "AI 设计画布", "moduleCode": "AI 编码助手",
    "moduleSimulation": "机器人仿真", "moduleModelHub": "模型管理",
    "moduleCLI": "命令行工具", "moduleDoc": "文档管理",
    "moduleKB": "知识库", "moduleBench": "基准测试", "moduleDesk": "桌面自动化",

    "newChat": "新建对话", "toggleSidebar": "切换侧边栏 (⌘\\)", "hideSidebar": "隐藏侧边栏 (⌘\\)",
    "getApps": "获取应用与扩展", "scrollUp": "上移", "scrollDown": "下移",
    "recents": "最近项目", "download": "下载",
    "getHelp": "获取帮助", "upgradePlan": "升级方案", "learnMore": "了解更多", "logout": "退出登录",

    "secChats": "对话", "secAgent": "Agent 工作台", "secProjects": "项目",
    "secArtifacts": "Artifacts", "secCode": "编码", "secDesign": "设计",
    "secDoc": "Fusion Doc", "secRag": "RAG", "secAIAgent": "AI 控制台",
    "secCowork": "CoWork", "secFsb": "FSB", "secMlx": "Fusion-MLX",
    "secScience": "科研", "secFinance": "金融", "secHealth": "健康",
    "secCliService": "CLI Service", "secSimulation": "Fusion Simulation",
    "secDouyin": "抖音运营", "secModelHub": "Model Hub", "secMultiNode": "Multi-Node",
    "secPlugin": "Plugin Ecosystem",

    "newProject": "新建项目", "openLocalFolder": "打开本地文件夹",
    "newWorkspace": "新建协作空间", "newWorkbench": "新建工作台",
    "noConversationsYet": "暂无对话", "noArtifactsYet": "暂无 Artifacts",
    "openArtifacts": "打开 Artifacts",
    "runDashboard": "运营看板", "pendingPublish": "待发布", "published": "已发布",
    "hitProduct": "爆款", "douyinHint": "点击「运营看板」进入主区操作造片 / 发布 / 评论 / 进化",

    "mod_dashboard": "控制台", "mod_design": "设计", "mod_code": "编码", "mod_simulation": "仿真", "mod_modelHub": "模型", "mod_multimodal": "多模态", "mod_training": "训练", "mod_cli": "命令行", "mod_doc": "文档", "mod_bench": "测评", "mod_desk": "自动化", "mod_dataTools": "数据工具", "mod_agent": "智能体", "mod_plugin": "插件", "mod_security": "安全", "mod_analytics": "分析", "mod_collab": "协作", "mod_tuning": "调优", "mod_external": "外部集成", "mod_docgen": "文档生成", "mod_clusterOverview": "集群总览", "mod_clusterTopology": "拓扑图", "mod_clusterSync": "集群同步", "mod_taskMonitor": "任务监控", "mod_alertCenter": "告警中心", "mod_nodeActions": "节点管理", "mod_submitTask": "提交任务", "mod_taskProgress": "任务详情", "mod_routingStrategy": "路由策略", "mod_kvCache": "KV缓存", "mod_serviceWeb": "服务面板", "mod_rag": "RAG", "mod_memory": "记忆", "mod_planner": "规划", "mod_deploy": "部署", "mod_operations": "运维", "mod_eduK12": "教育", "mod_verification": "验证", "mod_tokenBudget": "预算", "mod_safety": "安全审批", "mod_tools": "工具", "mod_agentDashboard": "Agent监控", "mod_teamCollab": "团队协作", "mod_chat": "对话", "mod_fusionProjects": "项目管理", "mod_cowork": "协作空间", "mod_artifactsRepo": "Artifacts仓库", "mod_fsb": "FSB", "mod_aiAgentDashboard": "AI总览", "mod_aiAgentList": "Agent列表", "mod_aiAgentChat": "AI对话", "mod_aiAgentObserver": "AI监控", "mod_aiAgentKnowledgeBase": "AI知识库", "mod_science": "科研", "mod_finance": "金融", "mod_health": "健康", "mod_pluginConfig": "插件配置", "mod_pluginStatus": "插件状态", "mod_pluginToken": "Token", "mod_pluginVram": "VRAM", "mod_pluginLog": "插件日志", "mod_pluginMcp": "MCP",

    "tab_general": "通用", "tab_modelSlots": "模型档位", "tab_hardware": "硬件加速", "tab_network": "网络 & 离线", "tab_quant": "量化预设", "tab_workspace": "工作区",
    "sec_startup": "启动", "launchAtLogin": "登录时启动 Fusion Studio", "autoStartMLX": "自动启动 fusion-mlx 服务", "reselectMainModel": "重新选择主模型",
    "sec_window": "窗口", "minimizeToMenuBar": "最小化到菜单栏", "sec_language": "语言", "interfaceLanguage": "界面语言",
    "sec_hwPref": "硬件偏好", "preferredDevice": "首选设备", "dev_auto": "自动", "dev_metal": "GPU (Metal)", "dev_ane": "ANE", "dev_cpu": "CPU Only",
    "enableMetal": "启用 Metal 加速", "enableANE": "启用 ANE 加速", "sec_memLimit": "内存限制",
    "maxUnifiedMemory": "最大统一内存: %d GB", "mlxMemoryHint": "fusion-mlx 推理可用最大内存",
    "sec_offlinePolicy": "离线策略", "forceOffline": "强制离线模式", "forceOfflineHelp": "开启后，所有网络请求将被拦截", "offlineActive": "✅ 当前为离线模式，数据不会离开本机",
    "sec_netPerms": "网络权限", "allowModelDownload": "允许模型下载", "checkUpdates": "检查版本更新",
    "sec_quantPreset": "量化预设", "defaultQuant": "默认量化精度", "defaultFormat": "默认模型格式", "sec_note": "说明",
    "quantNote": "4bit 是精度与性能的最佳平衡点\n2bit 极端压缩（适合 8GB 内存设备）\n8bit/fp16 最高精度（需要 32GB+ 内存）",
    "sec_wsDir": "工作区目录", "path": "路径", "browse": "浏览...", "wsHint": "所有设计文件、代码工程、仿真场景、模型权重将统一存放于此",
    "sec_autoMgmt": "自动管理", "autoProjectSubdir": "自动创建项目子目录", "enableGit": "启用 Git 版本管理", "autoBackup": "自动本地备份",
    "sec_slotModels": "档位模型（小 / 代码 / 复杂）", "noLocalModels": "未加载到本地模型，请先启动 fusion-mlx 服务", "notSet": "未设置",
    "sec_sceneDefault": "场景默认档位", "slotNote": "三档模型在所有选模型处顶部展示；More Models 子菜单列出其余本地模型。各场景（对话/代码/Agent/Artifacts）首次默认使用此处设定的档位。",
    "closeBtn": "关闭", "toggleInspector": "切换检查器",
    "prevTab": "上一个", "nextTab": "下一个", "defaultModelSlot": "默认（%@）", "moreModelsEmpty": "More Models（暂无）",
    "loadingTemplates": "加载模板中...", "currentModeClear": "当前模式：%@，点击清除", "currentStyleClear": "当前风格：%@，点击清除",
    "linkedProjectClear": "关联项目：%@，点击解除", "releaseToAddAttachment": "释放以添加附件", "voiceModeHelp": "语音模式（说完即发送）",
    "selectModel": "选择模型", "slotNotSet": "%@（未设置）", "moreModelsLabel": "More Models",
    "toggleLightMode": "切换到亮色模式", "toggleDarkMode": "切换到暗色模式",
]

let enUSTranslations: [String: String] = [
    "ok": "OK", "cancel": "Cancel", "save": "Save", "delete": "Delete", "edit": "Edit",
    "close": "Close", "search": "Search", "refresh": "Refresh", "loading": "Loading...",
    "error": "Error", "success": "Success", "warning": "Warning", "info": "Info",
    "confirm": "Confirm", "back": "Back", "next": "Next", "done": "Done",

    "dashboard": "Dashboard", "design": "Design", "code": "Code", "simulation": "Simulation",
    "modelHub": "Model Hub", "cli": "CLI", "doc": "Documents", "kb": "Knowledge Base",
    "bench": "Benchmark", "desk": "Automation", "settings": "Settings", "about": "About",

    "healthCheck": "Environment Health Check", "environmentHealthy": "Environment Healthy",
    "issuesFound": "Issues Found", "repair": "Repair", "repairing": "Repairing...",
    "runHealthCheck": "Run Health Check",

    "taskQueue": "Task Queue", "noTasks": "No Tasks",
    "running": "Running", "pending": "Pending", "completed": "Completed",
    "failed": "Failed", "cancelled": "Cancelled",

    "general": "General", "hardware": "Hardware", "network": "Network & Offline",
    "offlineMode": "Offline Mode", "language": "Language", "workspace": "Workspace",
    "autoStart": "Auto Start", "quantization": "Quantization",

    "cpu": "CPU", "memory": "Memory", "gpu": "GPU", "mlx": "MLX",
    "metal": "Metal", "ane": "Neural Engine",

    "moduleDesign": "AI Design Canvas", "moduleCode": "AI Coding Assistant",
    "moduleSimulation": "Robot Simulation", "moduleModelHub": "Model Management",
    "moduleCLI": "Command Line", "moduleDoc": "Document Management",
    "moduleKB": "Knowledge Base", "moduleBench": "Benchmark", "moduleDesk": "Desktop Automation",

    "newChat": "New Chat", "toggleSidebar": "Toggle Sidebar (⌘\\)", "hideSidebar": "Hide Sidebar (⌘\\)",
    "getApps": "Get App & Extensions", "scrollUp": "Scroll Up", "scrollDown": "Scroll Down",
    "recents": "Recents", "download": "Download",
    "getHelp": "Get Help", "upgradePlan": "Upgrade Plan", "learnMore": "Learn More", "logout": "Logout",

    "secChats": "Chats", "secAgent": "Agent Studio", "secProjects": "Projects",
    "secArtifacts": "Artifacts", "secCode": "Code", "secDesign": "Design",
    "secDoc": "Fusion Doc", "secRag": "RAG", "secAIAgent": "AI Console",
    "secCowork": "CoWork", "secFsb": "FSB", "secMlx": "Fusion-MLX",
    "secScience": "Science", "secFinance": "Finance", "secHealth": "Health",
    "secCliService": "CLI Service", "secSimulation": "Fusion Simulation",
    "secDouyin": "Douyin Ops", "secModelHub": "Model Hub", "secMultiNode": "Multi-Node",
    "secPlugin": "Plugin Ecosystem",

    "newProject": "New Project", "openLocalFolder": "Open Local Folder",
    "newWorkspace": "New Workspace", "newWorkbench": "New Workbench",
    "noConversationsYet": "No conversations yet", "noArtifactsYet": "No artifacts yet",
    "openArtifacts": "Open Artifacts",
    "runDashboard": "Operations Dashboard", "pendingPublish": "Pending", "published": "Published",
    "hitProduct": "Hits", "douyinHint": "Click \"Operations Dashboard\" to create / publish / comment / evolve",

    "mod_dashboard": "Dashboard", "mod_design": "Design", "mod_code": "Code", "mod_simulation": "Simulation", "mod_modelHub": "Models", "mod_multimodal": "Multimodal", "mod_training": "Training", "mod_cli": "CLI", "mod_doc": "Documents", "mod_bench": "Benchmark", "mod_desk": "Automation", "mod_dataTools": "Data Tools", "mod_agent": "Agents", "mod_plugin": "Plugins", "mod_security": "Security", "mod_analytics": "Analytics", "mod_collab": "Collaboration", "mod_tuning": "Tuning", "mod_external": "Integrations", "mod_docgen": "Doc Generation", "mod_clusterOverview": "Cluster Overview", "mod_clusterTopology": "Topology", "mod_clusterSync": "Cluster Sync", "mod_taskMonitor": "Task Monitor", "mod_alertCenter": "Alert Center", "mod_nodeActions": "Node Mgmt", "mod_submitTask": "Submit Task", "mod_taskProgress": "Task Detail", "mod_routingStrategy": "Routing", "mod_kvCache": "KV Cache", "mod_serviceWeb": "Service Panel", "mod_rag": "RAG", "mod_memory": "Memory", "mod_planner": "Planner", "mod_deploy": "Deploy", "mod_operations": "Operations", "mod_eduK12": "K-12 Education", "mod_verification": "Verification", "mod_tokenBudget": "Token Budget", "mod_safety": "Safety Approval", "mod_tools": "Tools", "mod_agentDashboard": "Agent Monitor", "mod_teamCollab": "Team Collab", "mod_chat": "Chat", "mod_fusionProjects": "Projects", "mod_cowork": "CoWork", "mod_artifactsRepo": "Artifacts", "mod_fsb": "FSB", "mod_aiAgentDashboard": "AI Overview", "mod_aiAgentList": "Agent List", "mod_aiAgentChat": "AI Chat", "mod_aiAgentObserver": "AI Observer", "mod_aiAgentKnowledgeBase": "AI Knowledge Base", "mod_science": "Science", "mod_finance": "Finance", "mod_health": "Health", "mod_pluginConfig": "Plugin Config", "mod_pluginStatus": "Plugin Status", "mod_pluginToken": "Token", "mod_pluginVram": "VRAM", "mod_pluginLog": "Plugin Log", "mod_pluginMcp": "MCP",

    "tab_general": "General", "tab_modelSlots": "Model Tiers", "tab_hardware": "Hardware", "tab_network": "Network & Offline", "tab_quant": "Quantization", "tab_workspace": "Workspace",
    "sec_startup": "Startup", "launchAtLogin": "Launch Fusion Studio at Login", "autoStartMLX": "Auto-start fusion-mlx service", "reselectMainModel": "Reselect Main Model",
    "sec_window": "Window", "minimizeToMenuBar": "Minimize to Menu Bar", "sec_language": "Language", "interfaceLanguage": "Interface Language",
    "sec_hwPref": "Hardware Preferences", "preferredDevice": "Preferred Device", "dev_auto": "Auto", "dev_metal": "GPU (Metal)", "dev_ane": "ANE", "dev_cpu": "CPU Only",
    "enableMetal": "Enable Metal Acceleration", "enableANE": "Enable ANE Acceleration", "sec_memLimit": "Memory Limit",
    "maxUnifiedMemory": "Max Unified Memory: %d GB", "mlxMemoryHint": "Max memory available for fusion-mlx inference",
    "sec_offlinePolicy": "Offline Policy", "forceOffline": "Force Offline Mode", "forceOfflineHelp": "When on, all network requests are blocked", "offlineActive": "✅ Offline mode active — data stays on-device",
    "sec_netPerms": "Network Permissions", "allowModelDownload": "Allow Model Downloads", "checkUpdates": "Check for Updates",
    "sec_quantPreset": "Quantization Preset", "defaultQuant": "Default Quantization", "defaultFormat": "Default Model Format", "sec_note": "Notes",
    "quantNote": "4-bit: best precision/performance balance\n2-bit: extreme compression (8 GB devices)\n8-bit/fp16: highest precision (32 GB+)",
    "sec_wsDir": "Workspace Directory", "path": "Path", "browse": "Browse...", "wsHint": "All designs, code, simulations, and model weights are stored here",
    "sec_autoMgmt": "Auto Management", "autoProjectSubdir": "Auto-create project subdirectories", "enableGit": "Enable Git Versioning", "autoBackup": "Auto Local Backup",
    "sec_slotModels": "Tier Models (Small / Code / Complex)", "noLocalModels": "No local models loaded — start fusion-mlx first", "notSet": "Not Set",
    "sec_sceneDefault": "Scene Default Tier", "slotNote": "Three tiers shown atop every model picker; More Models lists the rest. Each scene (chat/code/agent/artifacts) defaults to its tier here.",
    "closeBtn": "Close", "toggleInspector": "Toggle Inspector",
    "prevTab": "Previous", "nextTab": "Next", "defaultModelSlot": "Default (%@)", "moreModelsEmpty": "More Models (none)",
    "loadingTemplates": "Loading templates...", "currentModeClear": "Current mode: %@ — click to clear", "currentStyleClear": "Current style: %@ — click to clear",
    "linkedProjectClear": "Linked project: %@ — click to unlink", "releaseToAddAttachment": "Release to add attachment", "voiceModeHelp": "Voice mode (send on done)",
    "selectModel": "Select model", "slotNotSet": "%@ (not set)", "moreModelsLabel": "More Models",
    "toggleLightMode": "Switch to Light Mode", "toggleDarkMode": "Switch to Dark Mode",
]

let jaJPTranslations: [String: String] = [
    "ok": "確認", "cancel": "キャンセル", "save": "保存", "delete": "削除", "edit": "編集",
    "close": "閉じる", "search": "検索", "refresh": "更新", "loading": "読み込み中...",
    "error": "エラー", "success": "成功", "warning": "警告", "info": "情報",
    "confirm": "確認", "back": "戻る", "next": "次へ", "done": "完了",
    "dashboard": "ダッシュボード", "design": "デザイン", "code": "コード", "simulation": "シミュレーション",
    "modelHub": "モデル", "cli": "CLI", "doc": "ドキュメント", "kb": "ナレッジベース",
    "bench": "ベンチマーク", "desk": "自動化", "settings": "設定", "about": "情報",
    "healthCheck": "環境ヘルスチェック", "environmentHealthy": "環境正常",
    "issuesFound": "問題あり", "repair": "修復", "repairing": "修復中...",
    "runHealthCheck": "ヘルスチェック実行",
    "general": "一般", "hardware": "ハードウェア", "network": "ネットワーク",
    "offlineMode": "オフラインモード", "language": "言語", "workspace": "ワークスペース",
    "cpu": "CPU", "memory": "メモリ", "gpu": "GPU", "mlx": "MLX",
    "metal": "Metal", "ane": "ニューラルエンジン",
    "autoStart": "自動起動", "quantization": "量子化プリセット",
    "taskQueue": "タスクキュー", "noTasks": "タスクなし",
    "running": "実行中", "pending": "待機中", "completed": "完了",
    "failed": "失敗", "cancelled": "キャンセル済み",
    "moduleDesign": "AIデザインキャンバス", "moduleCode": "AIコーディングアシスタント",
    "moduleSimulation": "ロボットシミュレーション", "moduleModelHub": "モデル管理",
    "moduleCLI": "コマンドライン", "moduleDoc": "ドキュメント管理",
    "moduleKB": "ナレッジベース", "moduleBench": "ベンチマーク", "moduleDesk": "デスクトップ自動化",

    "newChat": "新規チャット", "toggleSidebar": "サイドバー切替 (⌘\\)", "hideSidebar": "サイドバー非表示 (⌘\\)",
    "getApps": "アプリと拡張を取得", "scrollUp": "上へ", "scrollDown": "下へ",
    "recents": "最近", "download": "ダウンロード",
    "getHelp": "ヘルプ", "upgradePlan": "プランアップグレード", "learnMore": "詳細", "logout": "ログアウト",

    "secChats": "チャット", "secAgent": "Agentワークベンチ", "secProjects": "プロジェクト",
    "secArtifacts": "Artifacts", "secCode": "コード", "secDesign": "デザイン",
    "secDoc": "Fusion Doc", "secRag": "RAG", "secAIAgent": "AIコンソール",
    "secCowork": "CoWork", "secFsb": "FSB", "secMlx": "Fusion-MLX",
    "secScience": "サイエンス", "secFinance": "ファイナンス", "secHealth": "ヘルス",
    "secCliService": "CLI Service", "secSimulation": "Fusion Simulation",
    "secDouyin": "Douyin運営", "secModelHub": "Model Hub", "secMultiNode": "Multi-Node",
    "secPlugin": "Plugin Ecosystem",

    "newProject": "新規プロジェクト", "openLocalFolder": "ローカルフォルダを開く",
    "newWorkspace": "新規ワークスペース", "newWorkbench": "新規ワークベンチ",
    "noConversationsYet": "チャットなし", "noArtifactsYet": "Artifactsなし",
    "openArtifacts": "Artifactsを開く",
    "runDashboard": "運営ダッシュボード", "pendingPublish": "公開待ち", "published": "公開済み",
    "hitProduct": "ヒット", "douyinHint": "「運営ダッシュボード」で作成 / 公開 / コメント / 進化",

    "mod_dashboard": "ダッシュボード", "mod_design": "デザイン", "mod_code": "コード", "mod_simulation": "シミュレーション", "mod_modelHub": "モデル", "mod_multimodal": "マルチモーダル", "mod_training": "トレーニング", "mod_cli": "コマンドライン", "mod_doc": "ドキュメント", "mod_bench": "ベンチマーク", "mod_desk": "自動化", "mod_dataTools": "データツール", "mod_agent": "エージェント", "mod_plugin": "プラグイン", "mod_security": "セキュリティ", "mod_analytics": "分析", "mod_collab": "コラボレーション", "mod_tuning": "チューニング", "mod_external": "外部連携", "mod_docgen": "ドキュメント生成", "mod_clusterOverview": "クラスタ概要", "mod_clusterTopology": "トポロジー", "mod_clusterSync": "クラスタ同期", "mod_taskMonitor": "タスク監視", "mod_alertCenter": "アラートセンター", "mod_nodeActions": "ノード管理", "mod_submitTask": "タスク送信", "mod_taskProgress": "タスク詳細", "mod_routingStrategy": "ルーティング", "mod_kvCache": "KVキャッシュ", "mod_serviceWeb": "サービスパネル", "mod_rag": "RAG", "mod_memory": "メモリ", "mod_planner": "プランナー", "mod_deploy": "デプロイ", "mod_operations": "運用", "mod_eduK12": "K-12教育", "mod_verification": "検証", "mod_tokenBudget": "トークン予算", "mod_safety": "安全承認", "mod_tools": "ツール", "mod_agentDashboard": "エージェント監視", "mod_teamCollab": "チームコラボ", "mod_chat": "チャット", "mod_fusionProjects": "プロジェクト", "mod_cowork": "コラボスペース", "mod_artifactsRepo": "Artifacts", "mod_fsb": "FSB", "mod_aiAgentDashboard": "AI概要", "mod_aiAgentList": "エージェント一覧", "mod_aiAgentChat": "AIチャット", "mod_aiAgentObserver": "AIオブザーバー", "mod_aiAgentKnowledgeBase": "AIナレッジベース", "mod_science": "サイエンス", "mod_finance": "ファイナンス", "mod_health": "ヘルス", "mod_pluginConfig": "プラグイン設定", "mod_pluginStatus": "プラグイン状態", "mod_pluginToken": "Token", "mod_pluginVram": "VRAM", "mod_pluginLog": "プラグインログ", "mod_pluginMcp": "MCP",

    "tab_general": "一般", "tab_modelSlots": "モデルティア", "tab_hardware": "ハードウェア", "tab_network": "ネットワーク", "tab_quant": "量子化プリセット", "tab_workspace": "ワークスペース",
    "sec_startup": "起動", "launchAtLogin": "ログイン時にFusion Studioを起動", "autoStartMLX": "fusion-mlxを自動起動", "reselectMainModel": "メインモデルを再選択",
    "sec_window": "ウィンドウ", "minimizeToMenuBar": "メニューバーに最小化", "sec_language": "言語", "interfaceLanguage": "インターフェイス言語",
    "sec_hwPref": "ハードウェア設定", "preferredDevice": "優先デバイス", "dev_auto": "自動", "dev_metal": "GPU (Metal)", "dev_ane": "ANE", "dev_cpu": "CPUのみ",
    "enableMetal": "Metalアクセラレーション", "enableANE": "ANEアクセラレーション", "sec_memLimit": "メモリ制限",
    "maxUnifiedMemory": "最大ユニファイドメモリ: %d GB", "mlxMemoryHint": "fusion-mlx推論の最大メモリ",
    "sec_offlinePolicy": "オフラインポリシー", "forceOffline": "強制オフラインモード", "forceOfflineHelp": "オン時、全ネットワーク要求を遮断", "offlineActive": "✅ オフラインモード：データは端末内留保",
    "sec_netPerms": "ネットワーク権限", "allowModelDownload": "モデルダウンロード許可", "checkUpdates": "アップデート確認",
    "sec_quantPreset": "量子化プリセット", "defaultQuant": "デフォルト量子化精度", "defaultFormat": "デフォルトモデル形式", "sec_note": "説明",
    "quantNote": "4bitは精度と性能の最適バランス\n2bitは極端圧縮（8GB端末向）\n8bit/fp16は最高精度（32GB+必要）",
    "sec_wsDir": "ワークスペースディレクトリ", "path": "パス", "browse": "参照...", "wsHint": "全デザイン/コード/シミュレーション/モデル重みはここに保存",
    "sec_autoMgmt": "自動管理", "autoProjectSubdir": "プロジェクトサブディレクトリ自動作成", "enableGit": "Gitバージョン管理", "autoBackup": "自動ローカルバックアップ",
    "sec_slotModels": "ティアモデル（小/コード/複雑）", "noLocalModels": "ローカルモデル未ロード — fusion-mlxを先に起動", "notSet": "未設定",
    "sec_sceneDefault": "シーンデフォルトティア", "slotNote": "3ティアは全モデル選択の上部に表示、More Modelsに残り。各シーンはここで設定したティアがデフォルト。",
    "closeBtn": "閉じる", "toggleInspector": "インスペクタ切替",
    "prevTab": "前へ", "nextTab": "次へ", "defaultModelSlot": "デフォルト（%@）", "moreModelsEmpty": "More Models（なし）",
    "loadingTemplates": "テンプレート読込中...", "currentModeClear": "現在のモード：%@ — クリックで解除", "currentStyleClear": "現在のスタイル：%@ — クリックで解除",
    "linkedProjectClear": "関連プロジェクト：%@ — クリックで解除", "releaseToAddAttachment": "離して添付", "voiceModeHelp": "音声モード（話終わりで送信）",
    "selectModel": "モデルを選択", "slotNotSet": "%@（未設定）", "moreModelsLabel": "More Models",
    "toggleLightMode": "ライトモードへ切替", "toggleDarkMode": "ダークモードへ切替",
]

let koKRTranslations: [String: String] = [
    "ok": "확인", "cancel": "취소", "save": "저장", "delete": "삭제", "edit": "편집",
    "close": "닫기", "search": "검색", "refresh": "새로고침", "loading": "로딩 중...",
    "error": "오류", "success": "성공", "warning": "경고", "info": "정보",
    "confirm": "확인", "back": "뒤로", "next": "다음", "done": "완료",
    "dashboard": "대시보드", "design": "디자인", "code": "코드", "simulation": "시뮬레이션",
    "modelHub": "모델", "cli": "CLI", "doc": "문서", "kb": "지식베이스",
    "bench": "벤치마크", "desk": "자동화", "settings": "설정", "about": "정보",
    "healthCheck": "환경 건강 검사", "environmentHealthy": "환경 정상",
    "issuesFound": "문제 발견", "repair": "수리", "repairing": "수리 중...",
    "general": "일반", "hardware": "하드웨어", "network": "네트워크",
    "offlineMode": "오프라인 모드", "language": "언어", "workspace": "작업 공간",
    "cpu": "CPU", "memory": "메모리", "gpu": "GPU", "mlx": "MLX",
    "metal": "Metal", "ane": "뉴럴 엔진",
    "autoStart": "자동 시작", "quantization": "양자화 프리셋",
    "taskQueue": "태스크 대기열", "noTasks": "태스크 없음",
    "running": "실행 중", "pending": "대기 중", "completed": "완료",
    "failed": "실패", "cancelled": "취소됨",
    "runHealthCheck": "건강 검사 실행",
    "moduleDesign": "AI 디자인 캔버스", "moduleCode": "AI 코딩 어시스턴트",
    "moduleSimulation": "로봇 시뮬레이션", "moduleModelHub": "모델 관리",
    "moduleCLI": "명령줄", "moduleDoc": "문서 관리",
    "moduleKB": "지식베이스", "moduleBench": "벤치마크", "moduleDesk": "데스크톱 자동화",

    "newChat": "새 채팅", "toggleSidebar": "사이드바 전환 (⌘\\)", "hideSidebar": "사이드바 숨기기 (⌘\\)",
    "getApps": "앱 및 확장 받기", "scrollUp": "위로", "scrollDown": "아래로",
    "recents": "최근", "download": "다운로드",
    "getHelp": "도움말", "upgradePlan": "플랜 업그레이드", "learnMore": "더 보기", "logout": "로그아웃",

    "secChats": "채팅", "secAgent": "Agent 워크벤치", "secProjects": "프로젝트",
    "secArtifacts": "Artifacts", "secCode": "코드", "secDesign": "디자인",
    "secDoc": "Fusion Doc", "secRag": "RAG", "secAIAgent": "AI 콘솔",
    "secCowork": "CoWork", "secFsb": "FSB", "secMlx": "Fusion-MLX",
    "secScience": "사이언스", "secFinance": "파이낸스", "secHealth": "헬스",
    "secCliService": "CLI Service", "secSimulation": "Fusion Simulation",
    "secDouyin": "Douyin 운영", "secModelHub": "Model Hub", "secMultiNode": "Multi-Node",
    "secPlugin": "Plugin Ecosystem",

    "newProject": "새 프로젝트", "openLocalFolder": "로컬 폴더 열기",
    "newWorkspace": "새 워크스페이스", "newWorkbench": "새 워크벤치",
    "noConversationsYet": "대화 없음", "noArtifactsYet": "Artifacts 없음",
    "openArtifacts": "Artifacts 열기",
    "runDashboard": "운영 대시보드", "pendingPublish": "발행 대기", "published": "발행됨",
    "hitProduct": "히트", "douyinHint": "「운영 대시보드」에서 제작 / 발행 / 댓글 / 진화",

    "mod_dashboard": "대시보드", "mod_design": "디자인", "mod_code": "코드", "mod_simulation": "시뮬레이션", "mod_modelHub": "모델", "mod_multimodal": "멀티모달", "mod_training": "트레이닝", "mod_cli": "명령줄", "mod_doc": "문서", "mod_bench": "벤치마크", "mod_desk": "자동화", "mod_dataTools": "데이터 도구", "mod_agent": "에이전트", "mod_plugin": "플러그인", "mod_security": "보안", "mod_analytics": "분석", "mod_collab": "협업", "mod_tuning": "튜닝", "mod_external": "외부 연동", "mod_docgen": "문서 생성", "mod_clusterOverview": "클러스터 개요", "mod_clusterTopology": "토폴로지", "mod_clusterSync": "클러스터 동기화", "mod_taskMonitor": "태스크 모니터", "mod_alertCenter": "알림 센터", "mod_nodeActions": "노드 관리", "mod_submitTask": "태스크 제출", "mod_taskProgress": "태스크 상세", "mod_routingStrategy": "라우팅", "mod_kvCache": "KV 캐시", "mod_serviceWeb": "서비스 패널", "mod_rag": "RAG", "mod_memory": "메모리", "mod_planner": "플래너", "mod_deploy": "배포", "mod_operations": "운영", "mod_eduK12": "K-12 교육", "mod_verification": "검증", "mod_tokenBudget": "토큰 예산", "mod_safety": "안전 승인", "mod_tools": "도구", "mod_agentDashboard": "에이전트 모니터", "mod_teamCollab": "팀 협업", "mod_chat": "채팅", "mod_fusionProjects": "프로젝트", "mod_cowork": "협업 공간", "mod_artifactsRepo": "Artifacts", "mod_fsb": "FSB", "mod_aiAgentDashboard": "AI 개요", "mod_aiAgentList": "에이전트 목록", "mod_aiAgentChat": "AI 채팅", "mod_aiAgentObserver": "AI 옵저버", "mod_aiAgentKnowledgeBase": "AI 지식베이스", "mod_science": "사이언스", "mod_finance": "파이낸스", "mod_health": "헬스", "mod_pluginConfig": "플러그인 설정", "mod_pluginStatus": "플러그인 상태", "mod_pluginToken": "Token", "mod_pluginVram": "VRAM", "mod_pluginLog": "플러그인 로그", "mod_pluginMcp": "MCP",

    "tab_general": "일반", "tab_modelSlots": "모델 티어", "tab_hardware": "하드웨어", "tab_network": "네트워크", "tab_quant": "양자화", "tab_workspace": "작업 공간",
    "sec_startup": "시작", "launchAtLogin": "로그인 시 Fusion Studio 실행", "autoStartMLX": "fusion-mlx 자동 시작", "reselectMainModel": "메인 모델 재선택",
    "sec_window": "창", "minimizeToMenuBar": "메뉴 막대로 최소화", "sec_language": "언어", "interfaceLanguage": "인터페이스 언어",
    "sec_hwPref": "하드웨어 설정", "preferredDevice": "선호 디바이스", "dev_auto": "자동", "dev_metal": "GPU (Metal)", "dev_ane": "ANE", "dev_cpu": "CPU 전용",
    "enableMetal": "Metal 가속 사용", "enableANE": "ANE 가속 사용", "sec_memLimit": "메모리 제한",
    "maxUnifiedMemory": "최대 통합 메모리: %d GB", "mlxMemoryHint": "fusion-mlx 추론 최대 메모리",
    "sec_offlinePolicy": "오프라인 정책", "forceOffline": "강제 오프라인 모드", "forceOfflineHelp": "켜면 모든 네트워크 요청 차단", "offlineActive": "✅ 오프라인 모드 — 데이터는 기기 내 저장",
    "sec_netPerms": "네트워크 권한", "allowModelDownload": "모델 다운로드 허용", "checkUpdates": "업데이트 확인",
    "sec_quantPreset": "양자화 프리셋", "defaultQuant": "기본 양자화 정밀도", "defaultFormat": "기본 모델 형식", "sec_note": "설명",
    "quantNote": "4비트: 정밀도/성능 최적 균형\n2비트: 극단 압축(8GB 기기)\n8비트/fp16: 최고 정밀도(32GB+)",
    "sec_wsDir": "작업 공간 디렉터리", "path": "경로", "browse": "찾아보기...", "wsHint": "모든 디자인/코드/시뮬레이션/모델 가중치 저장",
    "sec_autoMgmt": "자동 관리", "autoProjectSubdir": "프로젝트 하위 디렉터리 자동 생성", "enableGit": "Git 버전 관리 사용", "autoBackup": "자동 로컬 백업",
    "sec_slotModels": "티어 모델(소형/코드/복합)", "noLocalModels": "로컬 모델 없음 — fusion-mlx 먼저 시작", "notSet": "미설정",
    "sec_sceneDefault": "씬 기본 티어", "slotNote": "3개 티어는 모든 모델 선택 상단 표시, More Models에 나머지. 각 씬은 여기서 설정한 티어가 기본.",
    "closeBtn": "닫기", "toggleInspector": "인스펙터 전환",
    "prevTab": "이전", "nextTab": "다음", "defaultModelSlot": "기본 (%@)", "moreModelsEmpty": "More Models (없음)",
    "loadingTemplates": "템플릿 로딩 중...", "currentModeClear": "현재 모드: %@ — 클릭하여 해제", "currentStyleClear": "현재 스타일: %@ — 클릭하여 해제",
    "linkedProjectClear": "연결된 프로젝트: %@ — 클릭하여 해제", "releaseToAddAttachment": "놓아서 첨부", "voiceModeHelp": "음성 모드 (말 끝나면 전송)",
    "selectModel": "모델 선택", "slotNotSet": "%@ (미설정)", "moreModelsLabel": "More Models",
    "toggleLightMode": "라이트 모드로 전환", "toggleDarkMode": "다크 모드로 전환",
]

// MARK: - 国际化文本视图

struct I18nText: View {
    let key: I18nKey
    @StateObject private var i18n = I18nManager.shared

    init(_ key: I18nKey) { self.key = key }

    var body: some View {
        Text(i18n.t(key))
    }
}

struct I18nLabel: View {
    let key: I18nKey
    let icon: String
    @StateObject private var i18n = I18nManager.shared

    init(_ key: I18nKey, icon: String) { self.key = key; self.icon = icon }

    var body: some View {
        Label(i18n.t(key), systemImage: icon)
    }
}

// MARK: - 语言选择器

struct LanguagePickerView: View {
    @StateObject private var i18n = I18nManager.shared
    @State private var selectedLanguage: AppLanguage

    init() { _selectedLanguage = State(initialValue: I18nManager.shared.currentLanguage) }

    var body: some View {
        List {
            ForEach(AppLanguage.allCases) { lang in
                Button(action: {
                    selectedLanguage = lang
                    i18n.currentLanguage = lang
                }) {
                    HStack {
                        Text(lang.flag)
                            .font(.title)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(lang.displayName)
                                .font(.headline)
                            Text(lang.localName)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if selectedLanguage == lang {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("语言 / Language")
    }
}