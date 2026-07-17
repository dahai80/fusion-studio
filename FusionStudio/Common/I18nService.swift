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
    case code = "code"
    case simulation = "simulation"
    case modelHub = "modelHub"
    case cli = "cli"
    case doc = "doc"
    case kb = "kb"
    case bench = "bench"
    case desk = "desk"
    case settings = "settings"
    case about = "about"

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
    case language = "language"
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