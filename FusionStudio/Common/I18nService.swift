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
    // Batch 4a — ModelHub views
    case hub_rpmMustPositive = "hub_rpmMustPositive"
    case hub_concurrencyMustPositive = "hub_concurrencyMustPositive"
    case hub_idleTooLowWarn = "hub_idleTooLowWarn"
    case hub_nDownloading = "hub_nDownloading"
    case hub_nActiveDeployments = "hub_nActiveDeployments"
    case hub_nItems = "hub_nItems"
    case hub_nModels = "hub_nModels"
    case hub_nRoles = "hub_nRoles"
    case hub_nReplicas = "hub_nReplicas"
    case hub_apiKeyCreated = "hub_apiKeyCreated"
    case hub_apiKeysTitle = "hub_apiKeysTitle"
    case hub_apiKeysAndModelPerms = "hub_apiKeysAndModelPerms"
    case hub_apiThrottleConfig = "hub_apiThrottleConfig"
    case hub_gbMemory = "hub_gbMemory"
    case hub_kvCacheOpt = "hub_kvCacheOpt"
    case hub_qpsLimitZero = "hub_qpsLimitZero"
    case hub_rpmDefault = "hub_rpmDefault"
    case hub_ttlConfigNote = "hub_ttlConfigNote"
    case hub_ttlServeParamNote = "hub_ttlServeParamNote"
    case hub_securityScore = "hub_securityScore"
    case hub_securityScan = "hub_securityScan"
    case hub_perModelSettings = "hub_perModelSettings"
    case hub_autoBenchAfterVersion = "hub_autoBenchAfterVersion"
    case hub_saveBtn = "hub_saveBtn"
    case hub_localResourceClusterHint = "hub_localResourceClusterHint"
    case hub_editRole = "hub_editRole"
    case hub_editPermission = "hub_editPermission"
    case hub_editPermissionModel = "hub_editPermissionModel"
    case hub_concurrencyVal = "hub_concurrencyVal"
    case hub_concurrencyDefault = "hub_concurrencyDefault"
    case hub_deployMetrics = "hub_deployMetrics"
    case hub_auditLog = "hub_auditLog"
    case hub_testModelCount = "hub_testModelCount"
    case hub_testStatus = "hub_testStatus"
    case hub_pinnedNoTTLNote = "hub_pinnedNoTTLNote"
    case hub_pinnedWhitelist = "hub_pinnedWhitelist"
    case hub_heldFlat = "hub_heldFlat"
    case hub_createBtn = "hub_createBtn"
    case hub_createApiKey = "hub_createApiKey"
    case hub_createKey = "hub_createKey"
    case hub_createdAt = "hub_createdAt"
    case hub_disk = "hub_disk"
    case hub_storageDetail = "hub_storageDetail"
    case hub_pendingApproval = "hub_pendingApproval"
    case hub_perModelThrottle = "hub_perModelThrottle"
    case hub_noActiveModels = "hub_noActiveModels"
    case hub_exportCsv = "hub_exportCsv"
    case hub_waiting = "hub_waiting"
    case hub_benchThresholdWarn = "hub_benchThresholdWarn"
    case hub_scheduledBenchNote = "hub_scheduledBenchNote"
    case hub_scheduledBenchmark = "hub_scheduledBenchmark"
    case hub_compare = "hub_compare"
    case hub_compareQuantResults = "hub_compareQuantResults"
    case hub_benchCompareHint = "hub_benchCompareHint"
    case hub_compareSelectedN = "hub_compareSelectedN"
    case hub_layeredQuantHint = "hub_layeredQuantHint"
    case hub_encryptModelWeights = "hub_encryptModelWeights"
    case hub_multiNodeSyncHint = "hub_multiNodeSyncHint"
    case hub_issuesFound = "hub_issuesFound"
    case hub_idleUnloadHint = "hub_idleUnloadHint"
    case hub_peakMemory = "hub_peakMemory"
    case hub_copyAndClose = "hub_copyAndClose"
    case hub_formatBitsMem = "hub_formatBitsMem"
    case hub_redBelowThreshold = "hub_redBelowThreshold"
    case hub_cache = "hub_cache"
    case hub_yellowNearThreshold = "hub_yellowNearThreshold"
    case hub_canaryPercent = "hub_canaryPercent"
    case hub_active = "hub_active"
    case hub_activeSessions = "hub_activeSessions"
    case hub_activeModelCountdown = "hub_activeModelCountdown"
    case hub_clusterSchedConfig = "hub_clusterSchedConfig"
    case hub_clusterNodeHealth = "hub_clusterNodeHealth"
    case hub_clusterSharedCache = "hub_clusterSharedCache"
    case hub_encryption = "hub_encryption"
    case hub_encryptionMgmt = "hub_encryptionMgmt"
    case hub_encryptModel = "hub_encryptModel"
    case hub_loadDetail = "hub_loadDetail"
    case hub_loading = "hub_loading"
    case hub_securityScanTargetHint = "hub_securityScanTargetHint"
    case hub_reject = "hub_reject"
    case hub_enableCrossNodeRouting = "hub_enableCrossNodeRouting"
    case hub_startLayeredQuantize = "hub_startLayeredQuantize"
    case hub_startQuantize = "hub_startQuantize"
    case hub_startScan = "hub_startScan"
    case hub_startDownload = "hub_startDownload"
    case hub_controlModuleModelHint = "hub_controlModuleModelHint"
    case hub_controlRateConcurrencyHint = "hub_controlRateConcurrencyHint"
    case hub_quickPresetHint = "hub_quickPresetHint"
    case hub_typeLabel = "hub_typeLabel"
    case hub_historyBenchRecords = "hub_historyBenchRecords"
    case hub_runBenchmarkNow = "hub_runBenchmarkNow"
    case hub_quantLinkedBench = "hub_quantLinkedBench"
    case hub_quantPostBench = "hub_quantPostBench"
    case hub_quantizedModel = "hub_quantizedModel"
    case hub_quantizeTask = "hub_quantizeTask"
    case hub_quantTaskBenchResult = "hub_quantTaskBenchResult"
    case hub_autoBenchAfterQuantize = "hub_autoBenchAfterQuantize"
    case hub_quantBits = "hub_quantBits"
    case hub_noRunningQuantTask = "hub_noRunningQuantTask"
    case hub_autoRefresh10s = "hub_autoRefresh10s"
    case hub_rpmLabel = "hub_rpmLabel"
    case hub_rpmLabelColon = "hub_rpmLabelColon"
    case hub_pinnedWhitelistNote = "hub_pinnedWhitelistNote"
    case hub_template = "hub_template"
    case hub_moduleAccessPerm = "hub_moduleAccessPerm"
    case hub_model = "hub_model"
    case hub_modelTTL = "hub_modelTTL"
    case hub_modelApprovalOps = "hub_modelApprovalOps"
    case hub_modelJoined = "hub_modelJoined"
    case hub_autoBenchAfterQuantOrDownload = "hub_autoBenchAfterQuantOrDownload"
    case hub_autoBenchQuantOrDownloadShort = "hub_autoBenchQuantOrDownloadShort"
    case hub_autoBenchAfterQuantConvert = "hub_autoBenchAfterQuantConvert"
    case hub_autoBenchAfterVersionLoad = "hub_autoBenchAfterVersionLoad"
    case hub_defaultThrottlePolicy = "hub_defaultThrottlePolicy"
    case hub_targetFormat = "hub_targetFormat"
    case hub_benchIncludedModels = "hub_benchIncludedModels"
    case hub_memory = "hub_memory"
    case hub_benchmark = "hub_benchmark"
    case hub_benchResult = "hub_benchResult"
    case hub_benchResultColon = "hub_benchResultColon"
    case hub_benchType = "hub_benchType"
    case hub_benchTemplate = "hub_benchTemplate"
    case hub_benchModel = "hub_benchModel"
    case hub_score = "hub_score"
    case hub_scoreWarnThreshold = "hub_scoreWarnThreshold"
    case hub_evalResult = "hub_evalResult"
    case hub_evaluateQuant = "hub_evaluateQuant"
    case hub_enableAutoBenchmark = "hub_enableAutoBenchmark"
    case hub_cleanupSystem = "hub_cleanupSystem"
    case hub_apiKeyOnceHint = "hub_apiKeyOnceHint"
    case hub_requestsTotal = "hub_requestsTotal"
    case hub_requestsPerMin = "hub_requestsPerMin"
    case hub_selectTenantFirst = "hub_selectTenantFirst"
    case hub_pleaseSelect = "hub_pleaseSelect"
    case hub_cancelBtn = "hub_cancelBtn"
    case hub_unifiedFusionApp = "hub_unifiedFusionApp"
    case hub_all = "hub_all"
    case hub_globalModelLoadPolicy = "hub_globalModelLoadPolicy"
    case hub_globalThreshold = "hub_globalThreshold"
    case hub_permissionSelect = "hub_permissionSelect"
    case hub_date = "hub_date"
    case hub_scanModel = "hub_scanModel"
    case hub_scanModelSecurity = "hub_scanModelSecurity"
    case hub_scanDuplicates = "hub_scanDuplicates"
    case hub_setIdleUnloadCountdown = "hub_setIdleUnloadCountdown"
    case hub_setThreshold = "hub_setThreshold"
    case hub_requester = "hub_requester"
    case hub_requesterShort = "hub_requesterShort"
    case hub_approval = "hub_approval"
    case hub_approvalWorkflow = "hub_approvalWorkflow"
    case hub_approvalProcess = "hub_approvalProcess"
    case hub_reviewerWithComment = "hub_reviewerWithComment"
    case hub_approvalDetail = "hub_approvalDetail"
    case hub_remainingTime = "hub_remainingTime"
    case hub_failed = "hub_failed"
    case hub_time = "hub_time"
    case hub_realtimeMonitor = "hub_realtimeMonitor"
    case hub_firstToken = "hub_firstToken"
    case hub_firstTokenSec = "hub_firstTokenSec"
    case hub_firstTokenLatency = "hub_firstTokenLatency"
    case hub_refresh = "hub_refresh"
    case hub_watermarkMgmt = "hub_watermarkMgmt"
    case hub_add = "hub_add"
    case hub_addWatermark = "hub_addWatermark"
    case hub_deactivate = "hub_deactivate"
    case hub_approve = "hub_approve"
    case hub_general2 = "hub_general2"
    case hub_done = "hub_done"
    case hub_completionTime = "hub_completionTime"
    case hub_addDigitalWatermarkHint = "hub_addDigitalWatermarkHint"
    case hub_unconfiguredUsesDefault = "hub_unconfiguredUsesDefault"
    case hub_noSecurityIssues = "hub_noSecurityIssues"
    case hub_noClusterNodes = "hub_noClusterNodes"
    case hub_noModelWillTestAll = "hub_noModelWillTestAll"
    case hub_issueSummary = "hub_issueSummary"
    case hub_none = "hub_none"
    case hub_noPermissionConfig = "hub_noPermissionConfig"
    case hub_downloadLabel = "hub_downloadLabel"
    case hub_downloadTask = "hub_downloadTask"
    case hub_downloadNewModel = "hub_downloadNewModel"
    case hub_idle = "hub_idle"
    case hub_idleAfterTTLUnload = "hub_idleAfterTTLUnload"
    case hub_idleAutoReclaim = "hub_idleAutoReclaim"
    case hub_auditLogFirstN = "hub_auditLogFirstN"
    case hub_throttleConfigModel = "hub_throttleConfigModel"
    case hub_newRole = "hub_newRole"
    case hub_newBenchmark = "hub_newBenchmark"
    case hub_newDownload = "hub_newDownload"
    case hub_newTenant = "hub_newTenant"
    case hub_performanceBenchmark = "hub_performanceBenchmark"
    case hub_selectBenchModels = "hub_selectBenchModels"
    case hub_selectModel = "hub_selectModel"
    case hub_selectModelPlaceholder = "hub_selectModelPlaceholder"
    case hub_selectBenchModel = "hub_selectBenchModel"
    case hub_latencyMs = "hub_latencyMs"
    case hub_rejected = "hub_rejected"
    case hub_configuredTTLModels = "hub_configuredTTLModels"
    case hub_deactivated = "hub_deactivated"
    case hub_approved = "hub_approved"
    case hub_selectedNModelsLoading = "hub_selectedNModelsLoading"
    case hub_hardwareInfo = "hub_hardwareInfo"
    case hub_permanentResidentNoTTL = "hub_permanentResidentNoTTL"
    case hub_estimatedReduction = "hub_estimatedReduction"
    case hub_presetScheme = "hub_presetScheme"
    case hub_originalVsQuant = "hub_originalVsQuant"
    case hub_originalModel = "hub_originalModel"
    case hub_allowedModulesHint = "hub_allowedModulesHint"
    case hub_allowedModelsHint = "hub_allowedModelsHint"
    case hub_runningColon = "hub_runningColon"
    case hub_runBenchmark = "hub_runBenchmark"
    case hub_running = "hub_running"
    case hub_noApiKey = "hub_noApiKey"
    case hub_noAuditLogs = "hub_noAuditLogs"
    case hub_noPinnedModels = "hub_noPinnedModels"
    case hub_noActiveDeployments = "hub_noActiveDeployments"
    case hub_noRoles = "hub_noRoles"
    case hub_noHistory = "hub_noHistory"
    case hub_noQuantLinkedBench = "hub_noQuantLinkedBench"
    case hub_noModels = "hub_noModels"
    case hub_noModelData = "hub_noModelData"
    case hub_noBenchRecords = "hub_noBenchRecords"
    case hub_noBenchData = "hub_noBenchData"
    case hub_noApprovalRequests = "hub_noApprovalRequests"
    case hub_noInferenceData = "hub_noInferenceData"
    case hub_noDownloadTasks = "hub_noDownloadTasks"
    case hub_noDownloadedModels = "hub_noDownloadedModels"
    case hub_noTenants = "hub_noTenants"
    case hub_executionFrequency = "hub_executionFrequency"
    case hub_qualityChange = "hub_qualityChange"
    case hub_qualityScore = "hub_qualityScore"
    case hub_reset = "hub_reset"
    case hub_attentionQuant = "hub_attentionQuant"
    case hub_convertQuantize = "hub_convertQuantize"
    case hub_status = "hub_status"
    case hub_statusApproval = "hub_statusApproval"
    case hub_accuracy = "hub_accuracy"
    case hub_accuracyVal = "hub_accuracyVal"
    case hub_accuracyWarnThreshold = "hub_accuracyWarnThreshold"
    case hub_accuracyThresholdSettings = "hub_accuracyThresholdSettings"
    case hub_custom = "hub_custom"
    case hub_autoTest = "hub_autoTest"
    case hub_autoBenchmark = "hub_autoBenchmark"
    case hub_autoBenchRules = "hub_autoBenchRules"
    case hub_autoBenchTemplateLabel = "hub_autoBenchTemplateLabel"
    case hub_tenant = "hub_tenant"
    case hub_tenantsAndRoles = "hub_tenantsAndRoles"
    case hub_maxConcurrency = "hub_maxConcurrency"
    case hub_maxConcurrencyColon = "hub_maxConcurrencyColon"
    case hub_expired = "hub_expired"
    case hub_unknownIssue = "hub_unknownIssue"
    case hub_notYetScanned = "hub_notYetScanned"
    case hub_noWatermarkInfo = "hub_noWatermarkInfo"
    case hub_noEncryptionInfo = "hub_noEncryptionInfo"
    case hub_noApprovalRecords = "hub_noApprovalRecords"
    case hub_modelId = "hub_modelId"
    case hub_watermarkStatus = "hub_watermarkStatus"
    case hub_watermarkId = "hub_watermarkId"
    case hub_verifyStatus = "hub_verifyStatus"
    case hub_verified = "hub_verified"
    case hub_notVerified = "hub_notVerified"
    case hub_embeddedTime = "hub_embeddedTime"
    case hub_encryptionStatus = "hub_encryptionStatus"
    case hub_encryptionAlgorithm = "hub_encryptionAlgorithm"
    case hub_encryptionTime = "hub_encryptionTime"
    case hub_watermarkText = "hub_watermarkText"
    case hub_addBtn = "hub_addBtn"
    case hub_encryptBtn = "hub_encryptBtn"
    case hub_modelIdPlaceholder = "hub_modelIdPlaceholder"
    case hub_downloadUrlPlaceholder = "hub_downloadUrlPlaceholder"
    case hub_downloadSched = "hub_downloadSched"
    case hub_computeSchedPolicy = "hub_computeSchedPolicy"
    case hub_modulePermission = "hub_modulePermission"
    case hub_apiThrottle = "hub_apiThrottle"
    case hub_modelTTLTab = "hub_modelTTLTab"
    case hub_autoBenchmarkTab = "hub_autoBenchmarkTab"
    case hub_policyAuto = "hub_policyAuto"
    case hub_policyAutoDesc = "hub_policyAutoDesc"
    case hub_policyPinned = "hub_policyPinned"
    case hub_policyPinnedDesc = "hub_policyPinnedDesc"
    case hub_policyOnDemand = "hub_policyOnDemand"
    case hub_policyOnDemandDesc = "hub_policyOnDemandDesc"
    case hub_idlePrefix = "hub_idlePrefix"
    case hub_editPermissionBtn = "hub_editPermissionBtn"
    case hub_edit = "hub_edit"
    case hub_daily = "hub_daily"
    case hub_weekly = "hub_weekly"
    case hub_monthly = "hub_monthly"
    case hub_enabled = "hub_enabled"
    case hub_notEnabled = "hub_notEnabled"
    case hub_benchmarkStarted = "hub_benchmarkStarted"
    case hub_evalTaskCreated = "hub_evalTaskCreated"
    case hub_quantizeStarted = "hub_quantizeStarted"
    case hub_layeredQuantizeStarted = "hub_layeredQuantizeStarted"
    case hub_assessFailed = "hub_assessFailed"
    case hub_layeredQuantFailed = "hub_layeredQuantFailed"
    case hub_compareFailed = "hub_compareFailed"
    case hub_evalStartedForModel = "hub_evalStartedForModel"
    case hub_evalFailed = "hub_evalFailed"
    case hub_templateGeneral = "hub_templateGeneral"
    case hub_templateCode = "hub_templateCode"
    case hub_templateReasoning = "hub_templateReasoning"
    case hub_templateMultilingual = "hub_templateMultilingual"
    case hub_templateVision = "hub_templateVision"
    case hub_evalTypeAccuracy = "hub_evalTypeAccuracy"
    case hub_evalTypeAlignment = "hub_evalTypeAlignment"
    case hub_evalTypeSafety = "hub_evalTypeSafety"
    case hub_evalTypeCode = "hub_evalTypeCode"
    case hub_evalTypeReasoning = "hub_evalTypeReasoning"
    case hub_evalTypeGeneral = "hub_evalTypeGeneral"
    case hub_evalTypeComprehensive = "hub_evalTypeComprehensive"
    case hub_unknown = "hub_unknown"
    case hub_unknownModel = "hub_unknownModel"
    case hub_operationDeploy = "hub_operationDeploy"
    case hub_operationDelete = "hub_operationDelete"
    case hub_operationQuantize = "hub_operationQuantize"
    case hub_operationExport = "hub_operationExport"
    case hub_operationServe = "hub_operationServe"
    case hub_operationDownload = "hub_operationDownload"
    case hub_operation = "hub_operation"
    case hub_allSources = "hub_allSources"
    case hub_sourceLocal = "hub_sourceLocal"
    case hub_sourceHub = "hub_sourceHub"
    case hub_sourceCustom = "hub_sourceCustom"
    case hub_source = "hub_source"
    case hub_health_healthy = "hub_health_healthy"
    case hub_health_warning = "hub_health_warning"
    case hub_health_error = "hub_health_error"
    case hub_chip = "hub_chip"
    case hub_cpuCores = "hub_cpuCores"
    case hub_gpuCores = "hub_gpuCores"
    case hub_available = "hub_available"
    case hub_supported = "hub_supported"
    case hub_neCores = "hub_neCores"
    case hub_modelName = "hub_modelName"
    case hub_modelInferenceStats = "hub_modelInferenceStats"
    case hub_noDownloadTasksShort = "hub_noDownloadTasksShort"
    case hub_selectTenantViewRoles = "hub_selectTenantViewRoles"
    case hub_roleList = "hub_roleList"
    case hub_keyName = "hub_keyName"
    case hub_tenantName = "hub_tenantName"
    case hub_defaultRole = "hub_defaultRole"
    case hub_roleName = "hub_roleName"
    case hub_approvalCommentOptional = "hub_approvalCommentOptional"
    case hub_approvalComment = "hub_approvalComment"
    case hub_roleAdmin = "hub_roleAdmin"
    case hub_roleMember = "hub_roleMember"
    case hub_roleGuest = "hub_roleGuest"
    case hub_roleAdminCaps = "hub_roleAdminCaps"
    case hub_roleMemberCaps = "hub_roleMemberCaps"
    case hub_roleGuestCaps = "hub_roleGuestCaps"
    case hub_copyAndClose2 = "hub_copyAndClose2"
    case hub_presetChatLabel = "hub_presetChatLabel"
    case hub_presetCodeLabel = "hub_presetCodeLabel"
    case hub_presetEmbeddingLabel = "hub_presetEmbeddingLabel"
    case hub_presetRagLabel = "hub_presetRagLabel"
    case hub_presetChatMem = "hub_presetChatMem"
    case hub_presetCodeMem = "hub_presetCodeMem"
    case hub_presetEmbeddingMem = "hub_presetEmbeddingMem"
    case hub_presetRagMem = "hub_presetRagMem"
    case hub_presetChatDesc = "hub_presetChatDesc"
    case hub_presetCodeDesc = "hub_presetCodeDesc"
    case hub_presetEmbeddingDesc = "hub_presetEmbeddingDesc"
    case hub_presetRagDesc = "hub_presetRagDesc"
    case hub_scenePreset = "hub_scenePreset"
    case hub_quantConfig = "hub_quantConfig"
    case hub_layeredQuantize = "hub_layeredQuantize"
    case hub_quantCompare = "hub_quantCompare"
    case hub_qualityLabel = "hub_qualityLabel"
    case hub_speedLabel = "hub_speedLabel"
    case hub_memoryLabelFmt = "hub_memoryLabelFmt"
    case hub_firstTokenFmt = "hub_firstTokenFmt"
    case hub_accuracyFmt = "hub_accuracyFmt"
    case hub_benchResultPrefix = "hub_benchResultPrefix"
    case hub_accuracyPrefix = "hub_accuracyPrefix"
    case hub_firstTokenPrefix = "hub_firstTokenPrefix"
    case hub_memoryPrefix = "hub_memoryPrefix"
    case hub_perTokenLatency = "hub_perTokenLatency"
    case hub_firstTokenLatencyLabel = "hub_firstTokenLatencyLabel"
    case hub_prefillLatency = "hub_prefillLatency"
    case hub_decodeLatency = "hub_decodeLatency"
    case hub_throughputBatch1 = "hub_throughputBatch1"
    case hub_throughputBatch2 = "hub_throughputBatch2"
    case hub_throughputBatch4 = "hub_throughputBatch4"
    case hub_throughputBatch8 = "hub_throughputBatch8"
    case hub_memoryFootprint = "hub_memoryFootprint"
    case hub_usedStorageFmt = "hub_usedStorageFmt"
    case hub_tokensPerSecCol = "hub_tokensPerSecCol"
    case hub_accuracyCol = "hub_accuracyCol"
    case hub_scoreCol = "hub_scoreCol"
    case hub_compareCol = "hub_compareCol"
    case hub_templateCol = "hub_templateCol"
    case hub_deployment = "hub_deployment"
    case hub_newEval = "hub_newEval"
    case hub_quantColon = "hub_quantColon"
    case hub_dlColon = "hub_dlColon"
    case hub_modelColon = "hub_modelColon"
    case hub_modelColonJoined = "hub_modelColonJoined"
    case hub_requesterColon = "hub_requesterColon"
    case hub_reviewerColonComment = "hub_reviewerColonComment"
    case hub_statusColon = "hub_statusColon"
    case hub_typeColon = "hub_typeColon"
    case hub_showingFirstN = "hub_showingFirstN"
    case hub_nReplicasFmt = "hub_nReplicasFmt"
    case hub_canaryFmt = "hub_canaryFmt"
    case hub_nActiveDeploymentsFmt = "hub_nActiveDeploymentsFmt"
    case hub_nDownloadingFmt = "hub_nDownloadingFmt"
    case hub_nRolesFmt = "hub_nRolesFmt"
    case hub_nItemsFmt = "hub_nItemsFmt"
    case hub_sevCritical = "hub_sevCritical"
    case hub_sevHigh = "hub_sevHigh"
    case hub_sevMedium = "hub_sevMedium"
    case hub_sevLow = "hub_sevLow"
    case hub_latencyLabel = "hub_latencyLabel"
    case hub_errorRate = "hub_errorRate"
    case hub_grayCanary = "hub_grayCanary"
    case hub_quantLabel = "hub_quantLabel"
    case hub_runningLabel = "hub_runningLabel"
    case hub_activeDeploymentsFmt = "hub_activeDeploymentsFmt"
    case hub_countItemsFmt = "hub_countItemsFmt"
    case hub_copiesFmt = "hub_copiesFmt"
    case hub_auditShowingFmt = "hub_auditShowingFmt"
    case hub_modelSizeFmt = "hub_modelSizeFmt"
    case hub_csvHeader = "hub_csvHeader"
    case hub_roleCountFmt = "hub_roleCountFmt"
    case hub_createdAtFmt = "hub_createdAtFmt"
    case hub_modelsPermListFmt = "hub_modelsPermListFmt"
    case hub_modelPermissions = "hub_modelPermissions"
    case hub_apiKeyCopyOnceWarn = "hub_apiKeyCopyOnceWarn"
    case hub_requestsTotalFmt = "hub_requestsTotalFmt"
    case hub_reviewerCommentFmt = "hub_reviewerCommentFmt"
    case hub_compareSelectedFmt = "hub_compareSelectedFmt"
    case hub_modelBenchmark = "hub_modelBenchmark"
    case hub_scoreWarnThresholdFmt = "hub_scoreWarnThresholdFmt"
    case hub_accuracyFmt2 = "hub_accuracyFmt2"
    case hub_accuracyWarnThresholdFmt = "hub_accuracyWarnThresholdFmt"
    case hub_activeDownloadsFmt = "hub_activeDownloadsFmt"
    case hub_durationHMSFmt = "hub_durationHMSFmt"
    case hub_durationMSFmt = "hub_durationMSFmt"
    case hub_durationSFmt = "hub_durationSFmt"
    case hub_durationZero = "hub_durationZero"
    case hub_rpmDefaultFmt = "hub_rpmDefaultFmt"
    case hub_editPermTitleFmt = "hub_editPermTitleFmt"
    case hub_concurrencyFmt = "hub_concurrencyFmt"
    case hub_concurrencyDefaultFmt = "hub_concurrencyDefaultFmt"
    case hub_throttleConfigTitleFmt = "hub_throttleConfigTitleFmt"
    case hub_selectedModelsLoadingFmt = "hub_selectedModelsLoadingFmt"
    case hub_ls_catAll = "hub_ls_catAll"
    case hub_ls_catChat = "hub_ls_catChat"
    case hub_ls_catCode = "hub_ls_catCode"
    case hub_ls_catEmbed = "hub_ls_catEmbed"
    case hub_ls_catVision = "hub_ls_catVision"
    case hub_ls_catPrivate = "hub_ls_catPrivate"
    case hub_ls_catPinned = "hub_ls_catPinned"
    case hub_ls_catServing = "hub_ls_catServing"
    case hub_ls_catLLM = "hub_ls_catLLM"
    case hub_ls_catVLM = "hub_ls_catVLM"
    case hub_ls_catEmbedM = "hub_ls_catEmbedM"
    case hub_ls_catCodeM = "hub_ls_catCodeM"
    case hub_ls_catAudioM = "hub_ls_catAudioM"
    case hub_ls_catMLX = "hub_ls_catMLX"
    case hub_ls_catGGUF = "hub_ls_catGGUF"
    case hub_ls_category = "hub_ls_category"
    case hub_ls_searchPlaceholder = "hub_ls_searchPlaceholder"
    case hub_ls_batchMode = "hub_ls_batchMode"
    case hub_ls_selectedCountFmt = "hub_ls_selectedCountFmt"
    case hub_ls_selectAll = "hub_ls_selectAll"
    case hub_ls_batchDelete = "hub_ls_batchDelete"
    case hub_ls_batchQuantize = "hub_ls_batchQuantize"
    case hub_ls_syncCluster = "hub_ls_syncCluster"
    case hub_ls_exportPath = "hub_ls_exportPath"
    case hub_ls_currentUse = "hub_ls_currentUse"
    case hub_ls_serving = "hub_ls_serving"
    case hub_ls_compatFormats = "hub_ls_compatFormats"
    case hub_ls_unpin = "hub_ls_unpin"
    case hub_ls_pin = "hub_ls_pin"
    case hub_ls_stopServe = "hub_ls_stopServe"
    case hub_ls_startServe = "hub_ls_startServe"
    case hub_ls_basicInfo = "hub_ls_basicInfo"
    case hub_ls_path = "hub_ls_path"
    case hub_ls_source = "hub_ls_source"
    case hub_ls_engine = "hub_ls_engine"
    case hub_ls_license = "hub_ls_license"
    case hub_ls_allowedModules = "hub_ls_allowedModules"
    case hub_ls_selectModelHint = "hub_ls_selectModelHint"
    case hub_ls_versionMgmt = "hub_ls_versionMgmt"
    case hub_ls_versionList = "hub_ls_versionList"
    case hub_ls_noVersions = "hub_ls_noVersions"
    case hub_ls_rollback = "hub_ls_rollback"
    case hub_ls_publish = "hub_ls_publish"
    case hub_ls_deprecate = "hub_ls_deprecate"
    case hub_ls_retire = "hub_ls_retire"
    case hub_ls_resident = "hub_ls_resident"
    case hub_ls_batchQuantTitle = "hub_ls_batchQuantTitle"
    case hub_ls_batchQuantHintFmt = "hub_ls_batchQuantHintFmt"
    case hub_ls_targetFormat = "hub_ls_targetFormat"
    case hub_ls_quantBits = "hub_ls_quantBits"
    case hub_ls_startQuantize = "hub_ls_startQuantize"
    case hub_ls_batchQuantFailFmt = "hub_ls_batchQuantFailFmt"
    case hub_ls_rollbackFailFmt = "hub_ls_rollbackFailFmt"
    case hub_ls_syncFailFmt = "hub_ls_syncFailFmt"
    case hub_ls_startServeFailFmt = "hub_ls_startServeFailFmt"
    case hub_ls_stopServeFailFmt = "hub_ls_stopServeFailFmt"
    case hub_ls_publishFailFmt = "hub_ls_publishFailFmt"
    case hub_ls_deprecateFailFmt = "hub_ls_deprecateFailFmt"
    case hub_ls_retireFailFmt = "hub_ls_retireFailFmt"
    case hub_cls_nodes = "hub_cls_nodes"
    case hub_cls_onlineFmt = "hub_cls_onlineFmt"
    case hub_cls_syncModel = "hub_cls_syncModel"
    case hub_cls_noNodes = "hub_cls_noNodes"
    case hub_cls_noNodesHint = "hub_cls_noNodesHint"
    case hub_cls_selectNodeHint = "hub_cls_selectNodeHint"
    case hub_cls_nodeInfo = "hub_cls_nodeInfo"
    case hub_cls_addr = "hub_cls_addr"
    case hub_cls_lastSeen = "hub_cls_lastSeen"
    case hub_cls_resourceUsage = "hub_cls_resourceUsage"
    case hub_cls_memory = "hub_cls_memory"
    case hub_cls_localModelsFmt = "hub_cls_localModelsFmt"
    case hub_cls_autoSchedule = "hub_cls_autoSchedule"
    case hub_cls_localFirst = "hub_cls_localFirst"
    case hub_cls_model = "hub_cls_model"
    case hub_cls_selectModelHint = "hub_cls_selectModelHint"
    case hub_cls_routeMode = "hub_cls_routeMode"
    case hub_cls_promptPlaceholder = "hub_cls_promptPlaceholder"
    case hub_cls_sendInfer = "hub_cls_sendInfer"
    case hub_cls_inferResult = "hub_cls_inferResult"
    case hub_cls_routedTo = "hub_cls_routedTo"
    case hub_cls_resultHint = "hub_cls_resultHint"
    case hub_cls_syncToCluster = "hub_cls_syncToCluster"
    case hub_cls_syncHint = "hub_cls_syncHint"
    case hub_cls_startSync = "hub_cls_startSync"
    case hub_cls_modeAuto = "hub_cls_modeAuto"
    case hub_cls_modeLocal = "hub_cls_modeLocal"
    case hub_cls_modeCluster = "hub_cls_modeCluster"
    case hub_cls_modelCountFmt = "hub_cls_modelCountFmt"
    case hub_dash_mlxEngine = "hub_dash_mlxEngine"
    case hub_dash_clusterMode = "hub_dash_clusterMode"
    case hub_dash_modelService = "hub_dash_modelService"
    case hub_dash_localModels = "hub_dash_localModels"
    case hub_dash_activeModels = "hub_dash_activeModels"
    case hub_dash_downloading = "hub_dash_downloading"
    case hub_dash_totalStorage = "hub_dash_totalStorage"
    case hub_dash_pinned = "hub_dash_pinned"
    case hub_dash_quantizing = "hub_dash_quantizing"
    case hub_dash_clusterNodes = "hub_dash_clusterNodes"
    case hub_dash_totalModels = "hub_dash_totalModels"
    case hub_dash_quickActions = "hub_dash_quickActions"
    case hub_dash_searchMarket = "hub_dash_searchMarket"
    case hub_dash_downloadModel = "hub_dash_downloadModel"
    case hub_dash_quantizeModel = "hub_dash_quantizeModel"
    case hub_dash_systemClean = "hub_dash_systemClean"
    case hub_dash_recentModels = "hub_dash_recentModels"
    case hub_dash_noModels = "hub_dash_noModels"
    case hub_dash_resident = "hub_dash_resident"
    case hub_dash_serving = "hub_dash_serving"
    case hub_dash_sysOverview = "hub_dash_sysOverview"
    case hub_dash_memory = "hub_dash_memory"
    case hub_dash_disk = "hub_dash_disk"
    case hub_dash_uptime = "hub_dash_uptime"
    case hub_dash_loading = "hub_dash_loading"
    case hub_mv_descQwen35 = "hub_mv_descQwen35"
    case hub_mv_descLlama3 = "hub_mv_descLlama3"
    case hub_mv_descDeepseek = "hub_mv_descDeepseek"
    case hub_mv_descQwenVL = "hub_mv_descQwenVL"
    case hub_mv_catAll = "hub_mv_catAll"
    case hub_mv_searchPlaceholder = "hub_mv_searchPlaceholder"
    case hub_mv_selectModelHint = "hub_mv_selectModelHint"
    case hub_mv_downloadModel = "hub_mv_downloadModel"
    case hub_mv_refresh = "hub_mv_refresh"
    case hub_mv_active = "hub_mv_active"
    case hub_mv_ready = "hub_mv_ready"
    case hub_mv_notDownloaded = "hub_mv_notDownloaded"
    case hub_mv_currentUse = "hub_mv_currentUse"
    case hub_mv_download = "hub_mv_download"
    case hub_mv_activate = "hub_mv_activate"
    case hub_mv_downloadingFmt = "hub_mv_downloadingFmt"
    case hub_mv_basicInfo = "hub_mv_basicInfo"
    case hub_mv_modelId = "hub_mv_modelId"
    case hub_mv_path = "hub_mv_path"
    case hub_mv_size = "hub_mv_size"
    case hub_mv_format = "hub_mv_format"
    case hub_mv_quant = "hub_mv_quant"
    case hub_mv_family = "hub_mv_family"
    case hub_mv_params = "hub_mv_params"
    case hub_mv_description = "hub_mv_description"
    case hub_mv_searchHF = "hub_mv_searchHF"
    case hub_mv_search = "hub_mv_search"
    case hub_mv_recommended = "hub_mv_recommended"
    case hub_mv_repoIdHint = "hub_mv_repoIdHint"
    case hub_mv_hfTokenOptional = "hub_mv_hfTokenOptional"
    case hub_dep_stPending = "hub_dep_stPending"
    case hub_dep_stRunning = "hub_dep_stRunning"
    case hub_dep_stStopped = "hub_dep_stStopped"
    case hub_dep_stFailed = "hub_dep_stFailed"
    case hub_dep_stUnknown = "hub_dep_stUnknown"
    case hub_dep_management = "hub_dep_management"
    case hub_dep_empty = "hub_dep_empty"
    case hub_dep_selectHint = "hub_dep_selectHint"
    case hub_dep_replicasFmt = "hub_dep_replicasFmt"
    case hub_dep_canaryFmt = "hub_dep_canaryFmt"
    case hub_dep_config = "hub_dep_config"
    case hub_dep_model = "hub_dep_model"
    case hub_dep_modelName = "hub_dep_modelName"
    case hub_dep_strategy = "hub_dep_strategy"
    case hub_dep_replicasCount = "hub_dep_replicasCount"
    case hub_dep_canaryRatio = "hub_dep_canaryRatio"
    case hub_dep_createdAt = "hub_dep_createdAt"
    case hub_dep_updatedAt = "hub_dep_updatedAt"
    case hub_dep_metrics = "hub_dep_metrics"
    case hub_dep_reqPerSec = "hub_dep_reqPerSec"
    case hub_dep_latencyMs = "hub_dep_latencyMs"
    case hub_dep_errorRate = "hub_dep_errorRate"
    case hub_dep_refreshMetrics = "hub_dep_refreshMetrics"
    case hub_dep_actions = "hub_dep_actions"
    case hub_dep_stopDep = "hub_dep_stopDep"
    case hub_dep_scale = "hub_dep_scale"
    case hub_dep_grayRelease = "hub_dep_grayRelease"
    case hub_dep_deleteDep = "hub_dep_deleteDep"
    case hub_dep_stopFailFmt = "hub_dep_stopFailFmt"
    case hub_dep_scaleFailFmt = "hub_dep_scaleFailFmt"
    case hub_dep_grayFailFmt = "hub_dep_grayFailFmt"
    case hub_dep_deleteFailFmt = "hub_dep_deleteFailFmt"
    case hub_dep_metricsFailFmt = "hub_dep_metricsFailFmt"
    case hub_dep_createDep = "hub_dep_createDep"
    case hub_dep_modelId = "hub_dep_modelId"
    case hub_dep_depStrategy = "hub_dep_depStrategy"
    case hub_dep_replicasStepperFmt = "hub_dep_replicasStepperFmt"
    case hub_dep_canaryStepperFmt = "hub_dep_canaryStepperFmt"
    case hub_mkt_searchPlaceholder = "hub_mkt_searchPlaceholder"
    case hub_mkt_sourceAll = "hub_mkt_sourceAll"
    case hub_mkt_sourceLocal = "hub_mkt_sourceLocal"
    case hub_mkt_sourcePrivate = "hub_mkt_sourcePrivate"
    case hub_mkt_taskAll = "hub_mkt_taskAll"
    case hub_mkt_taskTextGen = "hub_mkt_taskTextGen"
    case hub_mkt_taskCode = "hub_mkt_taskCode"
    case hub_mkt_taskVision = "hub_mkt_taskVision"
    case hub_mkt_taskEmbedding = "hub_mkt_taskEmbedding"
    case hub_mkt_taskAudio = "hub_mkt_taskAudio"
    case hub_mkt_taskMultimodal = "hub_mkt_taskMultimodal"
    case hub_mkt_formatAll = "hub_mkt_formatAll"
    case hub_mkt_paramSizeAll = "hub_mkt_paramSizeAll"
    case hub_mkt_localOnly = "hub_mkt_localOnly"
    case hub_mkt_loadMoreFmt = "hub_mkt_loadMoreFmt"
    case hub_mkt_emptyTitle = "hub_mkt_emptyTitle"
    case hub_mkt_emptyHint = "hub_mkt_emptyHint"
    case hub_mkt_download = "hub_mkt_download"
    case hub_mkt_convertMLX = "hub_mkt_convertMLX"
    case hub_mkt_addBenchmark = "hub_mkt_addBenchmark"
    case hub_mkt_ragDefault = "hub_mkt_ragDefault"
    case hub_mkt_ragDefaultCurrent = "hub_mkt_ragDefaultCurrent"
    case hub_mkt_ragDefaultSet = "hub_mkt_ragDefaultSet"
    case hub_mkt_size = "hub_mkt_size"
    case hub_mkt_downloads = "hub_mkt_downloads"
    case hub_mkt_likes = "hub_mkt_likes"
    case hub_mkt_license = "hub_mkt_license"
    case hub_mkt_author = "hub_mkt_author"
    case hub_mkt_selectModelHint = "hub_mkt_selectModelHint"
    case hub_mkt_pickerSource = "hub_mkt_pickerSource"
    case hub_mkt_pickerTask = "hub_mkt_pickerTask"
    case hub_mkt_pickerFormat = "hub_mkt_pickerFormat"
    case hub_mkt_pickerParam = "hub_mkt_pickerParam"
    case hub_mkt_downloadFailFmt = "hub_mkt_downloadFailFmt"
    case hub_mkt_mlxFailFmt = "hub_mkt_mlxFailFmt"
    case hub_mkt_benchFailFmt = "hub_mkt_benchFailFmt"
    case hub_main_secDashboard = "hub_main_secDashboard"
    case hub_main_secMarket = "hub_main_secMarket"
    case hub_main_secLocalStorage = "hub_main_secLocalStorage"
    case hub_main_secConvertQuant = "hub_main_secConvertQuant"
    case hub_main_secSchedule = "hub_main_secSchedule"
    case hub_main_secCluster = "hub_main_secCluster"
    case hub_main_secDeployment = "hub_main_secDeployment"
    case hub_main_secPermission = "hub_main_secPermission"
    case hub_main_secMonitor = "hub_main_secMonitor"
    case hub_main_secBenchmark = "hub_main_secBenchmark"
    case hub_main_secSecurity = "hub_main_secSecurity"
    case hub_main_noKeyMsg = "hub_main_noKeyMsg"
    case hub_main_goCreate = "hub_main_goCreate"
    case hub_main_connected = "hub_main_connected"
    case hub_main_disconnected = "hub_main_disconnected"
    case hub_main_serviceNotConnected = "hub_main_serviceNotConnected"
    case hub_main_serviceHintFmt = "hub_main_serviceHintFmt"
    case hub_main_retry = "hub_main_retry"
    case hub_ver_draft = "hub_ver_draft"
    case hub_ver_testing = "hub_ver_testing"
    case hub_ver_published = "hub_ver_published"
    case hub_ver_deprecated = "hub_ver_deprecated"
    case hub_ver_retired = "hub_ver_retired"
    case hub_role_admin = "hub_role_admin"
    case hub_role_developer = "hub_role_developer"
    case hub_role_viewer = "hub_role_viewer"
    case hub_role_custom = "hub_role_custom"
    case hub_lvl_l1 = "hub_lvl_l1"
    case hub_lvl_l2 = "hub_lvl_l2"
    case hub_lvl_l3 = "hub_lvl_l3"
    case hub_lvl_unknown = "hub_lvl_unknown"
    case doc_tab_editor = "doc_tab_editor"
    case doc_tab_graph = "doc_tab_graph"
    case doc_tab_versions = "doc_tab_versions"
    case doc_tab_office = "doc_tab_office"
    case doc_tab_workflow = "doc_tab_workflow"
    case doc_tab_template = "doc_tab_template"
    case doc_tab_search = "doc_tab_search"
    case doc_tab_comments = "doc_tab_comments"
    case doc_tab_favorites = "doc_tab_favorites"
    case doc_tab_files = "doc_tab_files"
    case doc_tab_rag = "doc_tab_rag"
    case doc_tab_activity = "doc_tab_activity"
    case doc_aiCopilot = "doc_aiCopilot"
    case doc_selPageVersions = "doc_selPageVersions"
    case doc_auth_title = "doc_auth_title"
    case doc_auth_mode = "doc_auth_mode"
    case doc_auth_login = "doc_auth_login"
    case doc_auth_setup = "doc_auth_setup"
    case doc_auth_username = "doc_auth_username"
    case doc_auth_password = "doc_auth_password"
    case doc_auth_confirmPwd = "doc_auth_confirmPwd"
    case doc_auth_createAdmin = "doc_auth_createAdmin"
    case doc_auth_authenticated = "doc_auth_authenticated"
    case doc_cmt_title = "doc_cmt_title"
    case doc_cmt_empty = "doc_cmt_empty"
    case doc_cmt_reply = "doc_cmt_reply"
    case doc_cmt_replyLabel = "doc_cmt_replyLabel"
    case doc_cmt_replyPlaceholder = "doc_cmt_replyPlaceholder"
    case doc_cmt_addPlaceholder = "doc_cmt_addPlaceholder"
    case doc_cmt_selPage = "doc_cmt_selPage"
    case doc_fav_title = "doc_fav_title"
    case doc_fav_empty = "doc_fav_empty"
    case doc_fav_addHint = "doc_fav_addHint"
    case doc_fav_noTitle = "doc_fav_noTitle"
    case doc_file_title = "doc_file_title"
    case doc_file_countFmt = "doc_file_countFmt"
    case doc_file_empty = "doc_file_empty"
    case doc_file_unknown = "doc_file_unknown"
    case doc_file_upload = "doc_file_upload"
    case doc_file_name = "doc_file_name"
    case doc_file_uploadBtn = "doc_file_uploadBtn"
    case doc_file_selPage = "doc_file_selPage"
    case doc_ws_title = "doc_ws_title"
    case doc_ws_empty = "doc_ws_empty"
    case doc_ws_createFirst = "doc_ws_createFirst"
    case doc_ws_name = "doc_ws_name"
    case doc_ws_descOptional = "doc_ws_descOptional"
    case doc_ws_create = "doc_ws_create"
    case doc_ws_delete = "doc_ws_delete"
    case doc_act_title = "doc_act_title"
    case doc_act_empty = "doc_act_empty"
    case doc_act_evPageCreate = "doc_act_evPageCreate"
    case doc_act_evPageUpdate = "doc_act_evPageUpdate"
    case doc_act_evPageDelete = "doc_act_evPageDelete"
    case doc_act_evCommentCreate = "doc_act_evCommentCreate"
    case doc_act_evFavAdd = "doc_act_evFavAdd"
    case doc_act_evFavRemove = "doc_act_evFavRemove"
    case doc_act_evVerCreate = "doc_act_evVerCreate"
    case doc_act_evWorkflowRun = "doc_act_evWorkflowRun"
    case doc_act_evFileUpload = "doc_act_evFileUpload"
    case doc_cp_modeChat = "doc_cp_modeChat"
    case doc_cp_modeCommand = "doc_cp_modeCommand"
    case doc_cp_modeRag = "doc_cp_modeRag"
    case doc_cp_modeRewrite = "doc_cp_modeRewrite"
    case doc_cp_modeTranslate = "doc_cp_modeTranslate"
    case doc_cp_modeSummarize = "doc_cp_modeSummarize"
    case doc_cp_modeExpand = "doc_cp_modeExpand"
    case doc_cp_targetLang = "doc_cp_targetLang"
    case doc_cp_clearChat = "doc_cp_clearChat"
    case doc_cp_thinking = "doc_cp_thinking"
    case doc_cp_phChat = "doc_cp_phChat"
    case doc_cp_phCommand = "doc_cp_phCommand"
    case doc_cp_phRewrite = "doc_cp_phRewrite"
    case doc_cp_phTranslateFmt = "doc_cp_phTranslateFmt"
    case doc_cp_phSummarize = "doc_cp_phSummarize"
    case doc_cp_phExpand = "doc_cp_phExpand"
    case doc_cp_phRag = "doc_cp_phRag"
    case doc_cp_errCopilotURL = "doc_cp_errCopilotURL"
    case doc_cp_errCommandURL = "doc_cp_errCommandURL"
    case doc_cp_errNoData = "doc_cp_errNoData"
    case doc_cp_emptyResp = "doc_cp_emptyResp"
    case doc_cp_ragChunksPrefix = "doc_cp_ragChunksPrefix"
    case doc_cp_ragNoResult = "doc_cp_ragNoResult"
    case doc_cp_rewriteResultPrefix = "doc_cp_rewriteResultPrefix"
    case doc_cp_translateResultFmt = "doc_cp_translateResultFmt"
    case doc_cp_summarizePrefix = "doc_cp_summarizePrefix"
    case doc_cp_expandPrefix = "doc_cp_expandPrefix"
    case doc_cp_noResult = "doc_cp_noResult"
    case doc_cp_errPrefix = "doc_cp_errPrefix"
    case doc_graph_title = "doc_graph_title"
    case doc_graph_filterAll = "doc_graph_filterAll"
    case doc_graph_filterLink = "doc_graph_filterLink"
    case doc_graph_filterSemantic = "doc_graph_filterSemantic"
    case doc_graph_filterTag = "doc_graph_filterTag"
    case doc_graph_searchNode = "doc_graph_searchNode"
    case doc_graph_refreshHelp = "doc_graph_refreshHelp"
    case doc_graph_loading = "doc_graph_loading"
    case doc_graph_linkCountFmt = "doc_graph_linkCountFmt"
    case doc_graph_openPage = "doc_graph_openPage"
    case doc_graph_empty = "doc_graph_empty"
    case doc_graph_emptyHint = "doc_graph_emptyHint"
    case doc_rag_title = "doc_rag_title"
    case doc_rag_semanticQuery = "doc_rag_semanticQuery"
    case doc_rag_queryPlaceholder = "doc_rag_queryPlaceholder"
    case doc_rag_answer = "doc_rag_answer"
    case doc_rag_chunksFmt = "doc_rag_chunksFmt"
    case doc_rag_pageChunks = "doc_rag_pageChunks"
    case doc_rag_noChunks = "doc_rag_noChunks"
    case doc_rag_loadChunks = "doc_rag_loadChunks"
    case doc_rag_indexMgmt = "doc_rag_indexMgmt"
    case doc_rag_reindexAll = "doc_rag_reindexAll"
    case doc_rag_reindexPage = "doc_rag_reindexPage"
    case doc_rag_queryFailFmt = "doc_rag_queryFailFmt"
    case doc_search_placeholder = "doc_search_placeholder"
    case doc_search_type = "doc_search_type"
    case doc_search_typeAll = "doc_search_typeAll"
    case doc_search_typePage = "doc_search_typePage"
    case doc_search_typeBook = "doc_search_typeBook"
    case doc_search_sort = "doc_search_sort"
    case doc_search_sortRelevance = "doc_search_sortRelevance"
    case doc_search_sortDate = "doc_search_sortDate"
    case doc_search_sortTitle = "doc_search_sortTitle"
    case doc_search_resultFmt = "doc_search_resultFmt"
    case doc_search_hintKeyword = "doc_search_hintKeyword"
    case doc_search_noResult = "doc_search_noResult"
    case doc_tpl_newTitle = "doc_tpl_newTitle"
    case doc_tpl_name = "doc_tpl_name"
    case doc_tpl_typeHint = "doc_tpl_typeHint"
    case doc_tpl_category = "doc_tpl_category"
    case doc_tpl_create = "doc_tpl_create"
    case doc_tpl_title = "doc_tpl_title"
    case doc_tpl_newHelp = "doc_tpl_newHelp"
    case doc_tpl_empty = "doc_tpl_empty"
    case doc_tpl_extractVars = "doc_tpl_extractVars"
    case doc_tpl_delete = "doc_tpl_delete"
    case doc_tpl_content = "doc_tpl_content"
    case doc_tpl_variables = "doc_tpl_variables"
    case doc_tpl_inputVarFmt = "doc_tpl_inputVarFmt"
    case doc_tpl_useCreate = "doc_tpl_useCreate"
    case doc_tpl_selDetail = "doc_tpl_selDetail"
    case doc_ver_title = "doc_ver_title"
    case doc_ver_snapshot = "doc_ver_snapshot"
    case doc_ver_snapshotHelp = "doc_ver_snapshotHelp"
    case doc_ver_compare = "doc_ver_compare"
    case doc_ver_compareHelp = "doc_ver_compareHelp"
    case doc_ver_empty = "doc_ver_empty"
    case doc_ver_versionFmt = "doc_ver_versionFmt"
    case doc_ver_setV1 = "doc_ver_setV1"
    case doc_ver_setV2 = "doc_ver_setV2"
    case doc_ver_restore = "doc_ver_restore"
    case doc_ver_compareTitle = "doc_ver_compareTitle"
    case doc_ver_diffFmt = "doc_ver_diffFmt"
    case doc_office_fmtDocx = "doc_office_fmtDocx"
    case doc_office_fmtXlsx = "doc_office_fmtXlsx"
    case doc_office_fmtPptx = "doc_office_fmtPptx"
    case doc_office_title = "doc_office_title"
    case doc_office_cliStatus = "doc_office_cliStatus"
    case doc_office_versionFmt = "doc_office_versionFmt"
    case doc_office_formatsFmt = "doc_office_formatsFmt"
    case doc_office_detecting = "doc_office_detecting"
    case doc_office_create = "doc_office_create"
    case doc_office_filename = "doc_office_filename"
    case doc_office_createBtn = "doc_office_createBtn"
    case doc_office_import = "doc_office_import"
    case doc_office_filePath = "doc_office_filePath"
    case doc_office_importBtn = "doc_office_importBtn"
    case doc_office_export = "doc_office_export"
    case doc_office_pageId = "doc_office_pageId"
    case doc_office_format = "doc_office_format"
    case doc_office_exportBtn = "doc_office_exportBtn"
    case doc_office_merge = "doc_office_merge"
    case doc_office_templateName = "doc_office_templateName"
    case doc_office_dataJson = "doc_office_dataJson"
    case doc_office_mergeBtn = "doc_office_mergeBtn"
    case doc_office_cmdTitle = "doc_office_cmdTitle"
    case doc_office_cmdFile = "doc_office_cmdFile"
    case doc_office_cmdAction = "doc_office_cmdAction"
    case doc_office_executeBtn = "doc_office_executeBtn"
    case doc_office_importDir = "doc_office_importDir"
    case doc_office_dirPath = "doc_office_dirPath"
    case doc_wf_newTitle = "doc_wf_newTitle"
    case doc_wf_name = "doc_wf_name"
    case doc_wf_desc = "doc_wf_desc"
    case doc_wf_create = "doc_wf_create"
    case doc_wf_title = "doc_wf_title"
    case doc_wf_newHelp = "doc_wf_newHelp"
    case doc_wf_seedHelp = "doc_wf_seedHelp"
    case doc_wf_empty = "doc_wf_empty"
    case doc_wf_delete = "doc_wf_delete"
    case doc_wf_yamlDef = "doc_wf_yamlDef"
    case doc_wf_runInput = "doc_wf_runInput"
    case doc_wf_runBtn = "doc_wf_runBtn"
    case doc_wf_runHistory = "doc_wf_runHistory"
    case doc_wf_selDetail = "doc_wf_selDetail"
    case doc_wf_transitionTitle = "doc_wf_transitionTitle"
    case doc_wf_queryBtn = "doc_wf_queryBtn"
    case doc_wf_currentStateFmt = "doc_wf_currentStateFmt"
    case doc_wf_executeBtn = "doc_wf_executeBtn"
    case proj_subtitle = "proj_subtitle"
    case proj_searchPh = "proj_searchPh"
    case proj_newHelp = "proj_newHelp"
    case proj_archivedFmt = "proj_archivedFmt"
    case proj_fileCountFmt = "proj_fileCountFmt"
    case proj_chatCountFmt = "proj_chatCountFmt"
    case proj_archivedSuffix = "proj_archivedSuffix"
    case proj_unarchiveBtn = "proj_unarchiveBtn"
    case proj_upstreamBanner = "proj_upstreamBanner"
    case proj_emptyDetail = "proj_emptyDetail"
    case proj_loadFailFmt = "proj_loadFailFmt"
    case proj_deleteFailFmt = "proj_deleteFailFmt"
    case proj_minAgoFmt = "proj_minAgoFmt"
    case proj_hourAgoFmt = "proj_hourAgoFmt"
    case proj_dayAgoFmt = "proj_dayAgoFmt"
    case proj_sortLastUpdated = "proj_sortLastUpdated"
    case proj_sortDateCreated = "proj_sortDateCreated"
    case proj_sortAlphabetical = "proj_sortAlphabetical"
    case proj_menuUnstar = "proj_menuUnstar"
    case proj_menuStar = "proj_menuStar"
    case proj_menuRename = "proj_menuRename"
    case proj_menuDuplicate = "proj_menuDuplicate"
    case proj_menuExport = "proj_menuExport"
    case proj_menuArchive = "proj_menuArchive"
    case proj_menuDelete = "proj_menuDelete"
    case proj_menuSettings = "proj_menuSettings"
    case proj_deleteAlertTitle = "proj_deleteAlertTitle"
    case proj_deleteConfirm = "proj_deleteConfirm"
    case proj_deleteAlertMsgFmt = "proj_deleteAlertMsgFmt"
    case proj_deleteAlertMsgFullFmt = "proj_deleteAlertMsgFullFmt"
    case proj_renameTitle = "proj_renameTitle"
    case proj_namePh = "proj_namePh"
    case proj_createTitle = "proj_createTitle"
    case proj_createNameLabel = "proj_createNameLabel"
    case proj_createDescLabel = "proj_createDescLabel"
    case proj_createDescPh = "proj_createDescPh"
    case proj_createInstructions = "proj_createInstructions"
    case proj_createCharCountFmt = "proj_createCharCountFmt"
    case proj_createInstructionsHint = "proj_createInstructionsHint"
    case proj_createDefaultAgent = "proj_createDefaultAgent"
    case proj_createNoAgent = "proj_createNoAgent"
    case proj_createNoAgentShort = "proj_createNoAgentShort"
    case proj_createGotoAgentStudio = "proj_createGotoAgentStudio"
    case proj_createPromptMerge = "proj_createPromptMerge"
    case proj_createMergeAgentFirst = "proj_createMergeAgentFirst"
    case proj_createMergeProjectOnly = "proj_createMergeProjectOnly"
    case proj_createRagMode = "proj_createRagMode"
    case proj_createRagAuto = "proj_createRagAuto"
    case proj_createRagManual = "proj_createRagManual"
    case proj_createRagOff = "proj_createRagOff"
    case proj_createBtn = "proj_createBtn"
    case proj_editModeMarkdown = "proj_editModeMarkdown"
    case proj_editModeRichText = "proj_editModeRichText"
    case proj_dupTitle = "proj_dupTitle"
    case proj_dupNameLabel = "proj_dupNameLabel"
    case proj_dupCopySuffix = "proj_dupCopySuffix"
    case proj_dupScope = "proj_dupScope"
    case proj_dupScopeInstructionsOnly = "proj_dupScopeInstructionsOnly"
    case proj_dupScopeWithSnapshots = "proj_dupScopeWithSnapshots"
    case proj_dupBtn = "proj_dupBtn"
    case proj_detailArchived = "proj_detailArchived"
    case proj_detailImportCowork = "proj_detailImportCowork"
    case proj_tabInstructions = "proj_tabInstructions"
    case proj_tabKnowledge = "proj_tabKnowledge"
    case proj_tabChats = "proj_tabChats"
    case proj_instTitle = "proj_instTitle"
    case proj_instEmpty = "proj_instEmpty"
    case proj_instEmptyHint = "proj_instEmptyHint"
    case proj_instHistoryTitle = "proj_instHistoryTitle"
    case proj_instHistoryEmpty = "proj_instHistoryEmpty"
    case proj_instHistoryCurrentFmt = "proj_instHistoryCurrentFmt"
    case proj_instHistoryCurrentTag = "proj_instHistoryCurrentTag"
    case proj_instHistoryRestore = "proj_instHistoryRestore"
    case proj_kbTitle = "proj_kbTitle"
    case proj_kbFileCountFmt = "proj_kbFileCountFmt"
    case proj_kbFolder = "proj_kbFolder"
    case proj_kbAddFile = "proj_kbAddFile"
    case proj_kbEmpty = "proj_kbEmpty"
    case proj_kbEmptyHint = "proj_kbEmptyHint"
    case proj_kbNewFolderAlert = "proj_kbNewFolderAlert"
    case proj_kbFolderNamePh = "proj_kbFolderNamePh"
    case proj_kbCreate = "proj_kbCreate"
    case proj_kbStatusIndexed = "proj_kbStatusIndexed"
    case proj_kbStatusIndexing = "proj_kbStatusIndexing"
    case proj_kbStatusFailed = "proj_kbStatusFailed"
    case proj_kbStatusPending = "proj_kbStatusPending"
    case proj_kbMenuPreview = "proj_kbMenuPreview"
    case proj_kbMenuRename = "proj_kbMenuRename"
    case proj_kbMenuReplace = "proj_kbMenuReplace"
    case proj_kbMenuMove = "proj_kbMenuMove"
    case proj_kbMenuRemove = "proj_kbMenuRemove"
    case proj_chatsTitle = "proj_chatsTitle"
    case proj_chatsSnapshots = "proj_chatsSnapshots"
    case proj_chatsSnapMsgCountFmt = "proj_chatsSnapMsgCountFmt"
    case proj_chatsEmpty = "proj_chatsEmpty"
    case proj_chatsHint = "proj_chatsHint"
    case proj_chatsCreateFailFmt = "proj_chatsCreateFailFmt"
    case proj_chatsSendFailFmt = "proj_chatsSendFailFmt"
    case proj_chatsNoModel = "proj_chatsNoModel"
    case proj_chatsReplyFailFmt = "proj_chatsReplyFailFmt"
    case proj_ragSources = "proj_ragSources"
    case proj_ragModeLabelFmt = "proj_ragModeLabelFmt"
    case proj_ragSwitchAuto = "proj_ragSwitchAuto"
    case proj_ragSwitchManual = "proj_ragSwitchManual"
    case proj_inputUseDefaultAgent = "proj_inputUseDefaultAgent"
    case proj_inputGenericChat = "proj_inputGenericChat"
    case proj_inputPreviewAgent = "proj_inputPreviewAgent"
    case proj_inputRagLabelFmt = "proj_inputRagLabelFmt"
    case proj_inputRagAuto = "proj_inputRagAuto"
    case proj_inputRagManual = "proj_inputRagManual"
    case proj_inputRagOff = "proj_inputRagOff"
    case proj_inputAttachTemp = "proj_inputAttachTemp"
    case proj_inputAttachScreenshot = "proj_inputAttachScreenshot"
    case proj_inputAttachWebSearch = "proj_inputAttachWebSearch"
    case proj_inputAttachSkill = "proj_inputAttachSkill"
    case proj_inputPlaceholder = "proj_inputPlaceholder"
    case proj_budgetLow = "proj_budgetLow"
    case proj_chatMenuUnstar = "proj_chatMenuUnstar"
    case proj_chatMenuStar = "proj_chatMenuStar"
    case proj_chatMenuRename = "proj_chatMenuRename"
    case proj_chatMenuFork = "proj_chatMenuFork"
    case proj_chatMenuSnapshot = "proj_chatMenuSnapshot"
    case proj_chatMenuMove = "proj_chatMenuMove"
    case proj_chatMenuRemove = "proj_chatMenuRemove"
    case proj_chatMenuDelete = "proj_chatMenuDelete"
    case proj_chatDeleteAlertTitle = "proj_chatDeleteAlertTitle"
    case proj_agentConfigTitle = "proj_agentConfigTitle"
    case proj_agentConfigDefault = "proj_agentConfigDefault"
    case proj_agentConfigPromptMerge = "proj_agentConfigPromptMerge"
    case proj_ragConfigTitle = "proj_ragConfigTitle"
    case proj_ragConfigMode = "proj_ragConfigMode"
    case proj_ragConfigTopKFmt = "proj_ragConfigTopKFmt"
    case proj_ragConfigThresholdFmt = "proj_ragConfigThresholdFmt"
    case proj_ragConfigSelectScope = "proj_ragConfigSelectScope"
    case proj_settingsTitleFmt = "proj_settingsTitleFmt"
    case proj_settingsBasicInfo = "proj_settingsBasicInfo"
    case proj_settingsNameLabel = "proj_settingsNameLabel"
    case proj_settingsDescLabel = "proj_settingsDescLabel"
    case proj_settingsDescPh = "proj_settingsDescPh"
    case proj_settingsAgentConfig = "proj_settingsAgentConfig"
    case proj_settingsPromptMerge = "proj_settingsPromptMerge"
    case proj_settingsMergeAgentFirst = "proj_settingsMergeAgentFirst"
    case proj_settingsMergeProjectOnly = "proj_settingsMergeProjectOnly"
    case proj_settingsRagConfig = "proj_settingsRagConfig"
    case proj_settingsRagAuto = "proj_settingsRagAuto"
    case proj_settingsRagManual = "proj_settingsRagManual"
    case proj_settingsTopK = "proj_settingsTopK"
    case proj_settingsThreshold = "proj_settingsThreshold"
    case proj_settingsSaveBtn = "proj_settingsSaveBtn"
    case proj_previewUnbound = "proj_previewUnbound"
    case proj_previewRole = "proj_previewRole"
    case proj_previewActiveConfig = "proj_previewActiveConfig"
    case proj_previewPromptStrategyFmt = "proj_previewPromptStrategyFmt"
    case proj_previewPromptAgentFirst = "proj_previewPromptAgentFirst"
    case proj_previewPromptProjectOnly = "proj_previewPromptProjectOnly"
    case proj_previewRagModeFmt = "proj_previewRagModeFmt"
    case proj_previewAccessKb = "proj_previewAccessKb"
    case proj_previewUnboundHint = "proj_previewUnboundHint"
    case proj_previewGotoAgentStudio = "proj_previewGotoAgentStudio"
    case proj_coworkTitle = "proj_coworkTitle"
    case proj_coworkTarget = "proj_coworkTarget"
    case proj_coworkTargetPlaceholder = "proj_coworkTargetPlaceholder"
    case proj_coworkSyncContent = "proj_coworkSyncContent"
    case proj_coworkSyncKnowledge = "proj_coworkSyncKnowledge"
    case proj_coworkSyncSnapshots = "proj_coworkSyncSnapshots"
    case proj_coworkWarning = "proj_coworkWarning"
    case proj_coworkConfirm = "proj_coworkConfirm"
    case proj_ragScopeTitle = "proj_ragScopeTitle"
    case proj_ragScopeMode = "proj_ragScopeMode"
    case proj_ragScopeAuto = "proj_ragScopeAuto"
    case proj_ragScopeManual = "proj_ragScopeManual"
    case proj_ragScopeSpecify = "proj_ragScopeSpecify"
    case proj_ragScopeConfirm = "proj_ragScopeConfirm"
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

    "hub_rpmMustPositive": "⚠️ RPM 必须 > 0",
    "hub_concurrencyMustPositive": "⚠️ 并发数必须 > 0",
    "hub_idleTooLowWarn": "⚠️ 低于 5 分钟可能导致频繁加载/卸载，影响响应速度",
    "hub_nDownloading": "%@ 个下载中",
    "hub_nActiveDeployments": "%@ 个活跃部署",
    "hub_nItems": "%@ 个",
    "hub_nModels": "%@ 个",
    "hub_nRoles": "%@ 角色",
    "hub_nReplicas": "%@ 副本",
    "hub_apiKeyCreated": "API Key 已创建",
    "hub_apiKeysTitle": "API 密钥",
    "hub_apiKeysAndModelPerms": "API 密钥与模型权限",
    "hub_apiThrottleConfig": "API 限流配置",
    "hub_gbMemory": "GB 内存",
    "hub_kvCacheOpt": "KV-Cache 优化",
    "hub_qpsLimitZero": "QPS 限制 (0=无限)",
    "hub_rpmDefault": "RPM: %@ (默认)",
    "hub_ttlConfigNote": "TTL 配置说明",
    "hub_ttlServeParamNote": "TTL 由模型服务部署时指定 (serve API 的 ttl_seconds 参数)",
    "hub_securityScore": "安全评分",
    "hub_securityScan": "安全扫描",
    "hub_perModelSettings": "按模型设置",
    "hub_autoBenchAfterVersion": "版本更新后自动评测",
    "hub_saveBtn": "保存",
    "hub_localResourceClusterHint": "本机资源不足时自动分配至集群空闲 Mac 执行推理",
    "hub_editRole": "编辑角色",
    "hub_editPermission": "编辑权限",
    "hub_editPermissionModel": "编辑权限 — %@",
    "hub_concurrencyVal": "并发: %@",
    "hub_concurrencyDefault": "并发: %@ (默认)",
    "hub_deployMetrics": "部署指标",
    "hub_auditLog": "操作日志",
    "hub_testModelCount": "测试模型数",
    "hub_testStatus": "测试状态",
    "hub_pinnedNoTTLNote": "常驻模型 (pinned) 不受 TTL 限制，始终保留在内存中",
    "hub_pinnedWhitelist": "常驻内存白名单",
    "hub_heldFlat": "持平",
    "hub_createBtn": "创建",
    "hub_createApiKey": "创建 API 密钥",
    "hub_createKey": "创建密钥",
    "hub_createdAt": "创建于 %@",
    "hub_disk": "磁盘",
    "hub_storageDetail": "存储详情",
    "hub_pendingApproval": "待审批",
    "hub_perModelThrottle": "单模型限流配置",
    "hub_noActiveModels": "当前无活跃模型",
    "hub_exportCsv": "导出 CSV",
    "hub_waiting": "等待中",
    "hub_benchThresholdWarn": "低于阈值的评测结果将标记警告",
    "hub_scheduledBenchNote": "定时测试将在每日凌晨 3:00 或每周一凌晨 3:00 自动执行",
    "hub_scheduledBenchmark": "定时基准测试",
    "hub_compare": "对比",
    "hub_compareQuantResults": "对比量化结果",
    "hub_benchCompareHint": "对比模型推理性能：Tokens/s、首 Token 延迟、峰值内存",
    "hub_compareSelectedN": "对比选中 (%@)",
    "hub_layeredQuantHint": "对不同层应用不同量化策略，平衡精度与速度",
    "hub_encryptModelWeights": "对模型权重进行加密保护",
    "hub_multiNodeSyncHint": "多节点只需下载一次模型文件，自动增量同步",
    "hub_issuesFound": "发现问题",
    "hub_idleUnloadHint": "分钟触发模型卸载，释放统一内存",
    "hub_peakMemory": "峰值内存",
    "hub_copyAndClose": "复制并关闭",
    "hub_formatBitsMem": "格式: %@ | %@-bit | %@",
    "hub_redBelowThreshold": "红色 = 低于阈值",
    "hub_cache": "缓存",
    "hub_yellowNearThreshold": "黄色 = 接近阈值",
    "hub_canaryPercent": "灰度 %@%%",
    "hub_active": "活跃",
    "hub_activeSessions": "活跃会话",
    "hub_activeModelCountdown": "活跃模型倒计时",
    "hub_clusterSchedConfig": "集群调度配置",
    "hub_clusterNodeHealth": "集群节点健康状态",
    "hub_clusterSharedCache": "集群全局共享模型缓存",
    "hub_encryption": "加密",
    "hub_encryptionMgmt": "加密管理",
    "hub_encryptModel": "加密模型",
    "hub_loadDetail": "加载详情...",
    "hub_loading": "加载中...",
    "hub_securityScanTargetHint": "将对指定模型进行安全漏洞扫描",
    "hub_reject": "拒绝",
    "hub_enableCrossNodeRouting": "开启跨节点推理路由",
    "hub_startLayeredQuantize": "开始分层量化",
    "hub_startQuantize": "开始量化",
    "hub_startScan": "开始扫描",
    "hub_startDownload": "开始下载",
    "hub_controlModuleModelHint": "控制各模块可使用的模型，点击编辑权限修改",
    "hub_controlRateConcurrencyHint": "控制每个模型的请求速率与并发限制，防止过载",
    "hub_quickPresetHint": "快速选择适合场景的量化方案",
    "hub_typeLabel": "类型: %@",
    "hub_historyBenchRecords": "历史评测记录",
    "hub_runBenchmarkNow": "立即执行一次基准测试",
    "hub_quantLinkedBench": "量化关联评测",
    "hub_quantPostBench": "量化后基准",
    "hub_quantizedModel": "量化模型",
    "hub_quantizeTask": "量化任务",
    "hub_quantTaskBenchResult": "量化任务完成后的自动评测结果",
    "hub_autoBenchAfterQuantize": "量化完成后自动评测",
    "hub_quantBits": "量化位数",
    "hub_noRunningQuantTask": "没有正在运行的量化任务",
    "hub_autoRefresh10s": "每 10 秒自动刷新",
    "hub_rpmLabel": "每分钟请求数 (RPM)",
    "hub_rpmLabelColon": "每分钟请求数 (RPM):",
    "hub_pinnedWhitelistNote": "名单内模型永久驻留内存，不会被自动卸载",
    "hub_template": "模板",
    "hub_moduleAccessPerm": "模块访问权限",
    "hub_model": "模型",
    "hub_modelTTL": "模型 TTL (存活时间)",
    "hub_modelApprovalOps": "模型: %@",
    "hub_modelJoined": "模型: %@",
    "hub_autoBenchAfterQuantOrDownload": "模型量化或下载完成后自动运行基准测试，持续追踪性能变化",
    "hub_autoBenchQuantOrDownloadShort": "模型量化完成后、新模型下载完成后自动触发基准测试",
    "hub_autoBenchAfterQuantConvert": "模型量化转换成功后，自动运行性能评测",
    "hub_autoBenchAfterVersionLoad": "模型新版本加载后，自动运行性能评测对比",
    "hub_defaultThrottlePolicy": "默认限流策略",
    "hub_targetFormat": "目标格式",
    "hub_benchIncludedModels": "纳入测试的模型",
    "hub_memory": "内存",
    "hub_benchmark": "评测",
    "hub_benchResult": "评测结果",
    "hub_benchResultColon": "评测结果:",
    "hub_benchType": "评测类型",
    "hub_benchTemplate": "评测模板",
    "hub_benchModel": "评测模型",
    "hub_score": "评分",
    "hub_scoreWarnThreshold": "评分警告阈值: %@",
    "hub_evalResult": "评估结果",
    "hub_evaluateQuant": "评估量化",
    "hub_enableAutoBenchmark": "启用自动基准测试",
    "hub_cleanupSystem": "清理系统",
    "hub_apiKeyOnceHint": "请立即复制，此密钥仅显示一次：\n%@",
    "hub_requestsTotal": "请求: %@",
    "hub_requestsPerMin": "请求/分",
    "hub_selectTenantFirst": "请先选择左侧租户",
    "hub_pleaseSelect": "请选择",
    "hub_cancelBtn": "取消",
    "hub_unifiedFusionApp": "全 Fusion 应用统一生效",
    "hub_all": "全部",
    "hub_globalModelLoadPolicy": "全局模型加载策略",
    "hub_globalThreshold": "全局阈值",
    "hub_permissionSelect": "权限选择",
    "hub_date": "日期",
    "hub_scanModel": "扫描模型",
    "hub_scanModelSecurity": "扫描模型安全",
    "hub_scanDuplicates": "扫描重复",
    "hub_setIdleUnloadCountdown": "设置模型自动卸载倒计时，闲置超时后释放统一内存",
    "hub_setThreshold": "设置阈值",
    "hub_requester": "申请人: %@",
    "hub_requesterShort": "申请人: %@",
    "hub_approval": "审批",
    "hub_approvalWorkflow": "审批工作流",
    "hub_approvalProcess": "审批流程",
    "hub_reviewerWithComment": "审批人: %@%@",
    "hub_approvalDetail": "审批详情",
    "hub_remainingTime": "剩余时间",
    "hub_failed": "失败",
    "hub_time": "时间",
    "hub_realtimeMonitor": "实时监控",
    "hub_firstToken": "首Token",
    "hub_firstTokenSec": "首Token(s)",
    "hub_firstTokenLatency": "首Token延迟",
    "hub_refresh": "刷新",
    "hub_watermarkMgmt": "水印管理",
    "hub_add": "添加",
    "hub_addWatermark": "添加水印",
    "hub_deactivate": "停用",
    "hub_approve": "通过",
    "hub_general2": "通用",
    "hub_done": "完成",
    "hub_completionTime": "完成时间",
    "hub_addDigitalWatermarkHint": "为模型添加数字水印以保护知识产权",
    "hub_unconfiguredUsesDefault": "未单独配置的模型使用默认策略",
    "hub_noSecurityIssues": "未发现安全问题",
    "hub_noClusterNodes": "未检测到集群节点",
    "hub_noModelWillTestAll": "未选择模型，将测试所有已下载模型",
    "hub_issueSummary": "问题汇总",
    "hub_none": "无",
    "hub_noPermissionConfig": "无权限配置",
    "hub_downloadLabel": "下载: %@",
    "hub_downloadTask": "下载任务",
    "hub_downloadNewModel": "下载新模型",
    "hub_idle": "闲置",
    "hub_idleAfterTTLUnload": "闲置超过 TTL 后，模型将自动从内存卸载，释放 GPU 统一内存",
    "hub_idleAutoReclaim": "闲置自动回收",
    "hub_auditLogFirstN": "显示前 30 条，共 %@ 条",
    "hub_throttleConfigModel": "限流配置 — %@",
    "hub_newRole": "新建角色",
    "hub_newBenchmark": "新建评测",
    "hub_newDownload": "新建下载",
    "hub_newTenant": "新建租户",
    "hub_performanceBenchmark": "性能评测",
    "hub_selectBenchModels": "选择基准测试模型",
    "hub_selectModel": "选择模型",
    "hub_selectModelPlaceholder": "选择模型...",
    "hub_selectBenchModel": "选择评测模型",
    "hub_latencyMs": "延迟(ms)",
    "hub_rejected": "已拒绝",
    "hub_configuredTTLModels": "已配置 TTL 的模型",
    "hub_deactivated": "已停用",
    "hub_approved": "已通过",
    "hub_selectedNModelsLoading": "已选 %@ 个模型 (加载中...)",
    "hub_hardwareInfo": "硬件信息",
    "hub_permanentResidentNoTTL": "永久驻留 (无 TTL)",
    "hub_estimatedReduction": "预计缩减",
    "hub_presetScheme": "预设方案",
    "hub_originalVsQuant": "原始 vs 量化对比",
    "hub_originalModel": "原始模型",
    "hub_allowedModulesHint": "允许模块（留空=全部）",
    "hub_allowedModelsHint": "允许模型（留空=全部）",
    "hub_runningColon": "运行: %@",
    "hub_runBenchmark": "运行评测",
    "hub_running": "运行中",
    "hub_noApiKey": "暂无 API 密钥",
    "hub_noAuditLogs": "暂无操作日志",
    "hub_noPinnedModels": "暂无常驻模型",
    "hub_noActiveDeployments": "暂无活跃部署",
    "hub_noRoles": "暂无角色",
    "hub_noHistory": "暂无历史记录",
    "hub_noQuantLinkedBench": "暂无量化关联评测数据",
    "hub_noModels": "暂无模型",
    "hub_noModelData": "暂无模型数据",
    "hub_noBenchRecords": "暂无评测记录",
    "hub_noBenchData": "暂无评测数据，选择模型并运行评测",
    "hub_noApprovalRequests": "暂无审批请求",
    "hub_noInferenceData": "暂无推理数据",
    "hub_noDownloadTasks": "暂无下载任务",
    "hub_noDownloadedModels": "暂无已下载模型",
    "hub_noTenants": "暂无租户",
    "hub_executionFrequency": "执行频率",
    "hub_qualityChange": "质量变化: %@",
    "hub_qualityScore": "质量分",
    "hub_reset": "重置",
    "hub_attentionQuant": "注意力层量化",
    "hub_convertQuantize": "转换 & 量化",
    "hub_status": "状态",
    "hub_statusApproval": "状态: %@",
    "hub_accuracy": "准确率",
    "hub_accuracyVal": "准确率: %@",
    "hub_accuracyWarnThreshold": "准确率警告阈值: %@",
    "hub_accuracyThresholdSettings": "准确率阈值设置",
    "hub_custom": "自定义",
    "hub_autoTest": "自动测试",
    "hub_autoBenchmark": "自动基准测试",
    "hub_autoBenchRules": "自动评测规则",
    "hub_autoBenchTemplateLabel": "自动评测模板:",
    "hub_tenant": "租户",
    "hub_tenantsAndRoles": "租户与角色",
    "hub_maxConcurrency": "最大并发数",
    "hub_maxConcurrencyColon": "最大并发数:",
    "hub_expired": "已过期",
    "hub_unknownIssue": "未知问题",
    "hub_notYetScanned": "尚未进行安全扫描",
    "hub_noWatermarkInfo": "暂无水印信息",
    "hub_noEncryptionInfo": "暂无加密信息",
    "hub_noApprovalRecords": "暂无审批记录",
    "hub_modelId": "模型ID",
    "hub_watermarkStatus": "水印状态",
    "hub_watermarkId": "水印ID",
    "hub_verifyStatus": "验证状态",
    "hub_verified": "已验证",
    "hub_notVerified": "未验证",
    "hub_embeddedTime": "嵌入时间",
    "hub_encryptionStatus": "加密状态",
    "hub_encryptionAlgorithm": "加密算法",
    "hub_encryptionTime": "加密时间",
    "hub_watermarkText": "水印文本",
    "hub_addBtn": "添加",
    "hub_encryptBtn": "加密",
    "hub_modelIdPlaceholder": "模型 ID",
    "hub_downloadUrlPlaceholder": "下载地址 (https://...)",
    "hub_downloadSched": "下载调度",
    "hub_computeSchedPolicy": "算力调度策略",
    "hub_modulePermission": "模块权限",
    "hub_apiThrottle": "API 限流",
    "hub_modelTTLTab": "模型 TTL",
    "hub_autoBenchmarkTab": "自动基准测试",
    "hub_policyAuto": "智能自动调度",
    "hub_policyAutoDesc": "根据请求自动加载/卸载，推荐",
    "hub_policyPinned": "手动固定常驻",
    "hub_policyPinnedDesc": "模型常驻内存，不自动卸载",
    "hub_policyOnDemand": "用完即卸载",
    "hub_policyOnDemandDesc": "每次请求后立即卸载，最省内存",
    "hub_idlePrefix": "闲置",
    "hub_editPermissionBtn": "编辑权限",
    "hub_edit": "编辑",
    "hub_daily": "每日",
    "hub_weekly": "每周",
    "hub_monthly": "每月",
    "hub_enabled": "已启用",
    "hub_notEnabled": "未启用",
    "hub_benchmarkStarted": "评测已启动，稍后查看结果",
    "hub_evalTaskCreated": "评测任务已创建",
    "hub_quantizeStarted": "量化任务已启动",
    "hub_layeredQuantizeStarted": "分层量化任务已启动",
    "hub_assessFailed": "评估失败: %@",
    "hub_layeredQuantFailed": "分层量化失败: %@",
    "hub_compareFailed": "对比失败: %@",
    "hub_evalStartedForModel": "评测任务已启动: %@",
    "hub_evalFailed": "评测失败: %@",
    "hub_templateGeneral": "通用",
    "hub_templateCode": "代码",
    "hub_templateReasoning": "推理",
    "hub_templateMultilingual": "多语言",
    "hub_templateVision": "视觉",
    "hub_evalTypeAccuracy": "准确率",
    "hub_evalTypeAlignment": "对齐度",
    "hub_evalTypeSafety": "安全性",
    "hub_evalTypeCode": "代码能力",
    "hub_evalTypeReasoning": "推理能力",
    "hub_evalTypeGeneral": "通用",
    "hub_evalTypeComprehensive": "综合评测",
    "hub_unknown": "未知",
    "hub_unknownModel": "未知模型",
    "hub_operationDeploy": "部署",
    "hub_operationDelete": "删除",
    "hub_operationQuantize": "量化",
    "hub_operationExport": "导出",
    "hub_operationServe": "上线",
    "hub_operationDownload": "下载",
    "hub_operation": "操作",
    "hub_allSources": "全部来源",
    "hub_sourceLocal": "本地",
    "hub_sourceHub": "Hub",
    "hub_sourceCustom": "自定义",
    "hub_source": "来源",
    "hub_health_healthy": "健康",
    "hub_health_warning": "警告/降级",
    "hub_health_error": "错误/过载",
    "hub_chip": "芯片",
    "hub_cpuCores": "CPU 核心",
    "hub_gpuCores": "GPU 核心",
    "hub_available": "可用",
    "hub_supported": "支持",
    "hub_neCores": "NE 核心",
    "hub_modelName": "模型名称",
    "hub_modelInferenceStats": "模型推理统计",
    "hub_noDownloadTasksShort": "暂无下载任务",
    "hub_selectTenantViewRoles": "选择租户查看角色",
    "hub_roleList": "角色列表",
    "hub_keyName": "密钥名称",
    "hub_tenantName": "租户名称",
    "hub_defaultRole": "默认角色",
    "hub_roleName": "角色名称",
    "hub_approvalCommentOptional": "审批意见（可选）",
    "hub_approvalComment": "审批意见",
    "hub_roleAdmin": "管理员",
    "hub_roleMember": "成员",
    "hub_roleGuest": "访客",
    "hub_roleAdminCaps": "全部模型 + 全部模块 + 密钥管理 + 系统配置",
    "hub_roleMemberCaps": "指定模型 + 常规模块 + 无系统配置",
    "hub_roleGuestCaps": "受限模型 + 仅对话 + 速率限制",
    "hub_copyAndClose2": "复制并关闭",
    "hub_presetChatLabel": "对话模型",
    "hub_presetCodeLabel": "代码模型",
    "hub_presetEmbeddingLabel": "嵌入模型",
    "hub_presetRagLabel": "RAG模型",
    "hub_presetChatMem": "低内存",
    "hub_presetCodeMem": "均衡",
    "hub_presetEmbeddingMem": "精度优先",
    "hub_presetRagMem": "推理优化",
    "hub_presetChatDesc": "4-bit MLX 量化，适合对话场景，内存占用最低",
    "hub_presetCodeDesc": "8-bit MLX 量化，代码生成质量与速度均衡",
    "hub_presetEmbeddingDesc": "FP16 MLX 格式，保持嵌入精度，适合检索场景",
    "hub_presetRagDesc": "4-bit GGUF 格式，针对 RAG 推理优化，兼容 llama.cpp",
    "hub_scenePreset": "场景预设",
    "hub_quantConfig": "量化配置",
    "hub_layeredQuantize": "分层量化",
    "hub_quantCompare": "量化对比",
    "hub_qualityLabel": "质量: %.0f%%",
    "hub_speedLabel": "速度: %.1f tok/s",
    "hub_memoryLabelFmt": "内存: %.1f GB",
    "hub_firstTokenFmt": "首Token: %.2fs",
    "hub_accuracyFmt": "准确率: %.1f%%",
    "hub_benchResultPrefix": "评测结果:",
    "hub_accuracyPrefix": "准确率 %.1f%%",
    "hub_firstTokenPrefix": "首Token %.2fs",
    "hub_memoryPrefix": "内存 %.1f GB",
    "hub_perTokenLatency": "每Token延迟",
    "hub_firstTokenLatencyLabel": "首Token延迟",
    "hub_prefillLatency": "Prefill延迟",
    "hub_decodeLatency": "Decode延迟",
    "hub_throughputBatch1": "Batch=1 吞吐",
    "hub_throughputBatch2": "Batch=2 吞吐",
    "hub_throughputBatch4": "Batch=4 吞吐",
    "hub_throughputBatch8": "Batch=8 吞吐",
    "hub_memoryFootprint": "内存占用",
    "hub_usedStorageFmt": "已使用 %.1f / %.1f GB (%.0f%%)",
    "hub_tokensPerSecCol": "Tokens/s",
    "hub_accuracyCol": "准确率",
    "hub_scoreCol": "评分",
    "hub_compareCol": "对比",
    "hub_templateCol": "模板",
    "hub_deployment": "部署",
    "hub_newEval": "新建评测",
    "hub_quantColon": "量化: %@",
    "hub_dlColon": "下载: %@",
    "hub_modelColon": "模型: %@",
    "hub_modelColonJoined": "模型: %@",
    "hub_requesterColon": "申请人: %@",
    "hub_reviewerColonComment": "审批人: %@%@",
    "hub_statusColon": "状态: %@",
    "hub_typeColon": "类型: %@",
    "hub_showingFirstN": "显示前 30 条，共 %@ 条",
    "hub_nReplicasFmt": "%@ 副本",
    "hub_canaryFmt": "灰度 %@%%",
    "hub_nActiveDeploymentsFmt": "%@ 个活跃部署",
    "hub_nDownloadingFmt": "%@ 个下载中",
    "hub_nRolesFmt": "%@ 角色",
    "hub_nItemsFmt": "%@ 个",
    "hub_sevCritical": "严重", "hub_sevHigh": "高危", "hub_sevMedium": "中危", "hub_sevLow": "低危",
    "hub_latencyLabel": "延迟", "hub_errorRate": "错误率", "hub_grayCanary": "灰度 %@%",
    "hub_quantLabel": "量化: %@", "hub_runningLabel": "运行: %@", "hub_activeDeploymentsFmt": "%d 个活跃部署",
    "hub_countItemsFmt": "%d 个", "hub_copiesFmt": "%d 副本", "hub_auditShowingFmt": "显示前 30 条，共 %d 条",
    "hub_modelSizeFmt": "模型: %.1f GB", "hub_csvHeader": "ID,时间,操作,来源,资源,用户,详情\n",
    "hub_roleCountFmt": "%d 角色", "hub_createdAtFmt": "创建于 %@", "hub_modelsPermListFmt": "模型: %@",
    "hub_modelPermissions": "模型权限", "hub_apiKeyCopyOnceWarn": "请立即复制，此密钥仅显示一次：\n%@",
    "hub_requestsTotalFmt": "请求: %d", "hub_reviewerCommentFmt": "审批人: %@%@",
    "hub_compareSelectedFmt": "对比选中 (%d)", "hub_modelBenchmark": "模型评测",
    "hub_scoreWarnThresholdFmt": "评分警告阈值: %@", "hub_accuracyFmt2": "准确率: %@",
    "hub_accuracyWarnThresholdFmt": "准确率警告阈值: %@", "hub_activeDownloadsFmt": "%d 个下载中",
    "hub_durationHMSFmt": "%@时%@分%@秒", "hub_durationMSFmt": "%@分%@秒", "hub_durationSFmt": "%@秒",
    "hub_durationZero": "0秒", "hub_rpmDefaultFmt": "RPM: %d (默认)", "hub_editPermTitleFmt": "编辑权限 — %@",
    "hub_concurrencyFmt": "并发: %d", "hub_concurrencyDefaultFmt": "并发: %d (默认)",
    "hub_throttleConfigTitleFmt": "限流配置 — %@", "hub_selectedModelsLoadingFmt": "已选 %d 个模型 (加载中...)",
    "hub_ls_catAll": "全部", "hub_ls_catChat": "通用对话", "hub_ls_catCode": "代码专属", "hub_ls_catEmbed": "向量嵌入", "hub_ls_catVision": "图像多模态", "hub_ls_catPrivate": "私有模型", "hub_ls_catPinned": "已固定", "hub_ls_catServing": "推理中", "hub_ls_catLLM": "语言模型", "hub_ls_catVLM": "视觉模型", "hub_ls_catEmbedM": "嵌入模型", "hub_ls_catCodeM": "代码模型", "hub_ls_catAudioM": "音频模型", "hub_ls_catMLX": "MLX格式", "hub_ls_catGGUF": "GGUF格式", "hub_ls_category": "分类", "hub_ls_searchPlaceholder": "搜索本地模型...", "hub_ls_batchMode": "批量模式", "hub_ls_selectedCountFmt": "已选 %d 个", "hub_ls_selectAll": "全选", "hub_ls_batchDelete": "批量删除", "hub_ls_batchQuantize": "批量量化", "hub_ls_syncCluster": "同步至集群", "hub_ls_exportPath": "导出路径", "hub_ls_currentUse": "当前使用", "hub_ls_serving": "推理中", "hub_ls_compatFormats": "兼容格式:", "hub_ls_unpin": "取消置顶", "hub_ls_pin": "置顶", "hub_ls_stopServe": "停止推理", "hub_ls_startServe": "启动推理", "hub_ls_basicInfo": "基本信息", "hub_ls_path": "路径", "hub_ls_source": "来源", "hub_ls_engine": "引擎", "hub_ls_license": "许可", "hub_ls_allowedModules": "允许模块", "hub_ls_selectModelHint": "选择模型查看详情", "hub_ls_versionMgmt": "版本管理", "hub_ls_versionList": "版本列表", "hub_ls_noVersions": "暂无版本信息", "hub_ls_rollback": "回滚", "hub_ls_publish": "发布", "hub_ls_deprecate": "废弃", "hub_ls_retire": "下线", "hub_ls_resident": "常驻", "hub_ls_batchQuantTitle": "批量量化", "hub_ls_batchQuantHintFmt": "将对 %d 个模型执行量化转换", "hub_ls_targetFormat": "目标格式", "hub_ls_quantBits": "量化位数", "hub_ls_startQuantize": "开始量化", "hub_ls_batchQuantFailFmt": "批量量化失败: %@", "hub_ls_rollbackFailFmt": "版本回滚失败: %@", "hub_ls_syncFailFmt": "集群同步失败: %@", "hub_ls_startServeFailFmt": "启动推理失败: %@", "hub_ls_stopServeFailFmt": "停止推理失败: %@", "hub_ls_publishFailFmt": "发布版本失败: %@", "hub_ls_deprecateFailFmt": "废弃版本失败: %@", "hub_ls_retireFailFmt": "下线版本失败: %@",
    "hub_cls_nodes": "集群节点", "hub_cls_onlineFmt": "%d/%d 在线", "hub_cls_syncModel": "同步模型", "hub_cls_noNodes": "暂无集群节点", "hub_cls_noNodesHint": "确保多台 Mac 在同一网络并启动 Model Hub 服务", "hub_cls_selectNodeHint": "选择节点查看详情", "hub_cls_nodeInfo": "节点信息", "hub_cls_addr": "地址", "hub_cls_lastSeen": "最近上线", "hub_cls_resourceUsage": "资源使用", "hub_cls_memory": "内存", "hub_cls_localModelsFmt": "本地模型 (%d)", "hub_cls_autoSchedule": "自动调度推理", "hub_cls_localFirst": "本地优先，集群回退", "hub_cls_model": "模型", "hub_cls_selectModelHint": "选择模型...", "hub_cls_routeMode": "调度模式", "hub_cls_promptPlaceholder": "输入推理提示词...", "hub_cls_sendInfer": "发送推理请求", "hub_cls_inferResult": "推理结果", "hub_cls_routedTo": "路由到:", "hub_cls_resultHint": "发送推理请求后查看结果", "hub_cls_syncToCluster": "同步模型至集群", "hub_cls_syncHint": "将指定模型文件同步至所有在线集群节点", "hub_cls_startSync": "开始同步", "hub_cls_modeAuto": "自动", "hub_cls_modeLocal": "本地优先", "hub_cls_modeCluster": "集群",
    "hub_dash_mlxEngine": "MLX推理引擎", "hub_dash_clusterMode": "集群模式", "hub_dash_modelService": "模型服务", "hub_dash_localModels": "本地模型", "hub_dash_activeModels": "活跃模型", "hub_dash_downloading": "下载中", "hub_dash_totalStorage": "总存储", "hub_dash_pinned": "置顶", "hub_dash_quantizing": "量化中", "hub_dash_clusterNodes": "集群节点", "hub_dash_totalModels": "模型总数", "hub_dash_quickActions": "快捷操作", "hub_dash_searchMarket": "搜索市场", "hub_dash_downloadModel": "下载模型", "hub_dash_quantizeModel": "量化模型", "hub_dash_systemClean": "系统清理", "hub_dash_recentModels": "最近模型", "hub_dash_noModels": "暂无模型", "hub_dash_resident": "常驻", "hub_dash_serving": "推理中", "hub_dash_sysOverview": "系统概览", "hub_dash_memory": "内存", "hub_dash_disk": "磁盘", "hub_dash_uptime": "运行时间", "hub_dash_loading": "加载中...",
    "hub_mv_descQwen35": "通义千问 3.5，9B 参数，4bit 量化", "hub_mv_descLlama3": "Meta Llama 3，8B 参数，4bit 量化", "hub_mv_descDeepseek": "DeepSeek 代码专用模型", "hub_mv_descQwenVL": "Qwen2 视觉语言模型", "hub_mv_catAll": "全部", "hub_mv_searchPlaceholder": "搜索模型...", "hub_mv_selectModelHint": "选择一个模型查看详情", "hub_mv_downloadModel": "下载模型", "hub_mv_refresh": "刷新", "hub_mv_active": "活跃", "hub_mv_ready": "就绪", "hub_mv_notDownloaded": "未下载", "hub_mv_currentUse": "当前使用", "hub_mv_download": "下载", "hub_mv_activate": "激活", "hub_mv_downloadingFmt": "下载中... %d%%", "hub_mv_basicInfo": "基本信息", "hub_mv_modelId": "模型 ID", "hub_mv_path": "路径", "hub_mv_size": "大小", "hub_mv_format": "格式", "hub_mv_quant": "量化", "hub_mv_family": "家族", "hub_mv_params": "参数", "hub_mv_description": "描述", "hub_mv_searchHF": "搜索 HuggingFace 模型...", "hub_mv_search": "搜索", "hub_mv_recommended": "推荐模型", "hub_mv_repoIdHint": "或直接输入 HuggingFace repo ID", "hub_mv_hfTokenOptional": "HF Token (可选)",
    "hub_dep_stPending": "等待中",
    "hub_dep_stRunning": "运行中",
    "hub_dep_stStopped": "已停止",
    "hub_dep_stFailed": "失败",
    "hub_dep_stUnknown": "未知",
    "hub_dep_management": "部署管理",
    "hub_dep_empty": "暂无部署",
    "hub_dep_selectHint": "选择一个部署查看详情",
    "hub_dep_replicasFmt": "%@ 副本",
    "hub_dep_canaryFmt": "灰度 %d%%",
    "hub_dep_config": "配置",
    "hub_dep_model": "模型",
    "hub_dep_modelName": "模型名称",
    "hub_dep_strategy": "策略",
    "hub_dep_replicasCount": "副本数",
    "hub_dep_canaryRatio": "灰度比例",
    "hub_dep_createdAt": "创建时间",
    "hub_dep_updatedAt": "更新时间",
    "hub_dep_metrics": "指标",
    "hub_dep_reqPerSec": "请求/秒",
    "hub_dep_latencyMs": "延迟(ms)",
    "hub_dep_errorRate": "错误率",
    "hub_dep_refreshMetrics": "刷新指标",
    "hub_dep_actions": "操作",
    "hub_dep_stopDep": "停止部署",
    "hub_dep_scale": "扩缩容",
    "hub_dep_grayRelease": "灰度发布",
    "hub_dep_deleteDep": "删除部署",
    "hub_dep_stopFailFmt": "停止失败: %@",
    "hub_dep_scaleFailFmt": "扩缩容失败: %@",
    "hub_dep_grayFailFmt": "灰度发布失败: %@",
    "hub_dep_deleteFailFmt": "删除失败: %@",
    "hub_dep_metricsFailFmt": "获取指标失败: %@",
    "hub_dep_createDep": "创建部署",
    "hub_dep_modelId": "模型ID",
    "hub_dep_depStrategy": "部署策略",
    "hub_dep_replicasStepperFmt": "副本数: %d",
    "hub_dep_canaryStepperFmt": "灰度比例: %d%%", "hub_cls_modelCountFmt": "%d 模型",
    "hub_mkt_searchPlaceholder": "搜索模型...",
    "hub_mkt_sourceAll": "全部来源",
    "hub_mkt_sourceLocal": "本地",
    "hub_mkt_sourcePrivate": "私有仓库",
    "hub_mkt_taskAll": "全部任务",
    "hub_mkt_taskTextGen": "文本生成",
    "hub_mkt_taskCode": "代码",
    "hub_mkt_taskVision": "视觉",
    "hub_mkt_taskEmbedding": "嵌入",
    "hub_mkt_taskAudio": "音频",
    "hub_mkt_taskMultimodal": "多模态",
    "hub_mkt_formatAll": "全部格式",
    "hub_mkt_paramSizeAll": "全部参数量",
    "hub_mkt_localOnly": "仅本地",
    "hub_mkt_loadMoreFmt": "加载更多 (%d/%d)",
    "hub_mkt_emptyTitle": "搜索 HuggingFace / ModelScope / 私有仓库模型",
    "hub_mkt_emptyHint": "支持多源搜索、格式筛选、参数量筛选、任务分类",
    "hub_mkt_download": "下载",
    "hub_mkt_convertMLX": "一键转MLX",
    "hub_mkt_addBenchmark": "加入评测",
    "hub_mkt_ragDefault": "RAG 默认",
    "hub_mkt_ragDefaultCurrent": "当前 RAG 默认嵌入模型",
    "hub_mkt_ragDefaultSet": "设为 RAG 默认嵌入模型",
    "hub_mkt_size": "大小",
    "hub_mkt_downloads": "下载量",
    "hub_mkt_likes": "点赞",
    "hub_mkt_license": "许可",
    "hub_mkt_author": "作者",
    "hub_mkt_selectModelHint": "选择模型查看详情",
    "hub_mkt_pickerSource": "来源",
    "hub_mkt_pickerTask": "任务",
    "hub_mkt_pickerFormat": "格式",
    "hub_mkt_pickerParam": "参数量",
    "hub_mkt_downloadFailFmt": "下载失败: %@",
    "hub_mkt_mlxFailFmt": "MLX转换下载失败: %@",
    "hub_mkt_benchFailFmt": "评测触发失败: %@",
    "hub_main_secDashboard": "总览",
    "hub_main_secMarket": "模型市场",
    "hub_main_secLocalStorage": "本地存储",
    "hub_main_secConvertQuant": "转换量化",
    "hub_main_secSchedule": "下载调度",
    "hub_main_secCluster": "集群调度",
    "hub_main_secDeployment": "部署管理",
    "hub_main_secPermission": "权限管控",
    "hub_main_secMonitor": "系统监控",
    "hub_main_secBenchmark": "性能评测",
    "hub_main_secSecurity": "安全中心",
    "hub_main_noKeyMsg": "未配置 API Key，受保护接口将返回 401。请到「权限管控」创建 Key。",
    "hub_main_goCreate": "前往创建",
    "hub_main_connected": "已连接",
    "hub_main_disconnected": "未连接",
    "hub_main_serviceNotConnected": "Model Hub 服务未连接",
    "hub_main_serviceHintFmt": "请确认 fusion-model-hub 服务已启动（端口 %d）",
    "hub_main_retry": "重试连接",
    "hub_ver_draft": "草稿",
    "hub_ver_testing": "测试中",
    "hub_ver_published": "已发布",
    "hub_ver_deprecated": "已废弃",
    "hub_ver_retired": "已下线",
    "hub_role_admin": "管理员",
    "hub_role_developer": "开发者",
    "hub_role_viewer": "只读",
    "hub_role_custom": "自定义",
    "hub_lvl_l1": "L1 自动审批",
    "hub_lvl_l2": "L2 主管审批",
    "hub_lvl_l3": "L3 安全审批",
    "hub_lvl_unknown": "未知",
    "doc_tab_editor": "编辑器",
    "doc_tab_graph": "知识图谱",
    "doc_tab_versions": "版本历史",
    "doc_tab_office": "Office",
    "doc_tab_workflow": "工作流",
    "doc_tab_template": "模板",
    "doc_tab_search": "搜索",
    "doc_tab_comments": "评论",
    "doc_tab_favorites": "收藏",
    "doc_tab_files": "文件",
    "doc_tab_rag": "RAG",
    "doc_tab_activity": "动态",
    "doc_aiCopilot": "AI Copilot",
    "doc_selPageVersions": "选择页面查看版本历史",
    "doc_auth_title": "Fusion Doc 认证",
    "doc_auth_mode": "模式",
    "doc_auth_login": "登录",
    "doc_auth_setup": "初始设置",
    "doc_auth_username": "用户名",
    "doc_auth_password": "密码",
    "doc_auth_confirmPwd": "确认密码",
    "doc_auth_createAdmin": "创建管理员",
    "doc_auth_authenticated": "已认证 ✓",
    "doc_cmt_title": "评论",
    "doc_cmt_empty": "暂无评论",
    "doc_cmt_reply": "回复",
    "doc_cmt_replyLabel": "回复评论",
    "doc_cmt_replyPlaceholder": "回复评论...",
    "doc_cmt_addPlaceholder": "添加评论...",
    "doc_cmt_selPage": "选择页面查看评论",
    "doc_fav_title": "收藏",
    "doc_fav_empty": "暂无收藏",
    "doc_fav_addHint": "在页面中点击星标添加收藏",
    "doc_fav_noTitle": "无标题",
    "doc_file_title": "附件",
    "doc_file_countFmt": "%d 文件",
    "doc_file_empty": "暂无附件",
    "doc_file_unknown": "未知文件",
    "doc_file_upload": "上传附件",
    "doc_file_name": "文件名",
    "doc_file_uploadBtn": "上传",
    "doc_file_selPage": "选择页面查看附件",
    "doc_ws_title": "工作空间",
    "doc_ws_empty": "暂无工作空间",
    "doc_ws_createFirst": "创建第一个工作空间",
    "doc_ws_name": "名称",
    "doc_ws_descOptional": "描述（可选）",
    "doc_ws_create": "创建",
    "doc_ws_delete": "删除",
    "doc_act_title": "活动日志",
    "doc_act_empty": "暂无活动记录",
    "doc_act_evPageCreate": "📄 创建页面",
    "doc_act_evPageUpdate": "✏️ 更新页面",
    "doc_act_evPageDelete": "🗑️ 删除页面",
    "doc_act_evCommentCreate": "💬 添加评论",
    "doc_act_evFavAdd": "⭐ 添加收藏",
    "doc_act_evFavRemove": "☆ 取消收藏",
    "doc_act_evVerCreate": "🔖 创建版本",
    "doc_act_evWorkflowRun": "🔄 运行工作流",
    "doc_act_evFileUpload": "📎 上传附件",
    "doc_cp_modeChat": "对话",
    "doc_cp_modeCommand": "指令",
    "doc_cp_modeRag": "知识",
    "doc_cp_modeRewrite": "改写",
    "doc_cp_modeTranslate": "翻译",
    "doc_cp_modeSummarize": "摘要",
    "doc_cp_modeExpand": "扩展",
    "doc_cp_targetLang": "目标语言",
    "doc_cp_clearChat": "清空对话",
    "doc_cp_thinking": "思考中...",
    "doc_cp_phChat": "输入消息...",
    "doc_cp_phCommand": "/command ...",
    "doc_cp_phRewrite": "输入改写指令...",
    "doc_cp_phTranslateFmt": "输入文本翻译为%@...",
    "doc_cp_phSummarize": "输入文本生成摘要...",
    "doc_cp_phExpand": "输入文本扩展内容...",
    "doc_cp_phRag": "知识检索...",
    "doc_cp_errCopilotURL": "Copilot URL 不可用",
    "doc_cp_errCommandURL": "Command URL 不可用",
    "doc_cp_errNoData": "无响应数据",
    "doc_cp_emptyResp": "(空响应)",
    "doc_cp_ragChunksPrefix": "📚 相关知识片段：",
    "doc_cp_ragNoResult": "无相关结果",
    "doc_cp_rewriteResultPrefix": "✏️ 改写结果：",
    "doc_cp_translateResultFmt": "🌐 翻译结果(%@)：",
    "doc_cp_summarizePrefix": "📋 摘要：",
    "doc_cp_expandPrefix": "📖 扩展内容：",
    "doc_cp_noResult": "(无结果)",
    "doc_cp_errPrefix": "❌ ",
    "doc_graph_title": "知识图谱",
    "doc_graph_filterAll": "全部",
    "doc_graph_filterLink": "链接",
    "doc_graph_filterSemantic": "语义",
    "doc_graph_filterTag": "标签",
    "doc_graph_searchNode": "搜索节点...",
    "doc_graph_refreshHelp": "刷新图谱",
    "doc_graph_loading": "加载图谱...",
    "doc_graph_linkCountFmt": "链接数: %d",
    "doc_graph_openPage": "打开页面",
    "doc_graph_empty": "暂无图谱数据",
    "doc_graph_emptyHint": "创建页面间链接后将自动生成知识图谱",
    "doc_rag_title": "RAG 知识增强",
    "doc_rag_semanticQuery": "语义查询",
    "doc_rag_queryPlaceholder": "输入查询问题...",
    "doc_rag_answer": "回答",
    "doc_rag_chunksFmt": "相关片段 (%d)",
    "doc_rag_pageChunks": "页面索引段落",
    "doc_rag_noChunks": "暂无索引段落",
    "doc_rag_loadChunks": "加载段落",
    "doc_rag_indexMgmt": "索引管理",
    "doc_rag_reindexAll": "全量重建索引",
    "doc_rag_reindexPage": "重建当前页索引",
    "doc_rag_queryFailFmt": "查询失败: %@",
    "doc_search_placeholder": "搜索文档...",
    "doc_search_type": "类型",
    "doc_search_typeAll": "全部",
    "doc_search_typePage": "页面",
    "doc_search_typeBook": "书架",
    "doc_search_sort": "排序",
    "doc_search_sortRelevance": "相关度",
    "doc_search_sortDate": "时间",
    "doc_search_sortTitle": "标题",
    "doc_search_resultFmt": "%d 结果",
    "doc_search_hintKeyword": "输入关键词搜索文档",
    "doc_search_noResult": "无搜索结果",
    "doc_tpl_newTitle": "新建模板",
    "doc_tpl_name": "名称",
    "doc_tpl_typeHint": "类型 (report/letter/...)",
    "doc_tpl_category": "分类",
    "doc_tpl_create": "创建",
    "doc_tpl_title": "模板",
    "doc_tpl_newHelp": "新建模板",
    "doc_tpl_empty": "暂无模板",
    "doc_tpl_extractVars": "提取变量",
    "doc_tpl_delete": "删除模板",
    "doc_tpl_content": "模板内容",
    "doc_tpl_variables": "模板变量",
    "doc_tpl_inputVarFmt": "输入 %@",
    "doc_tpl_useCreate": "使用模板创建",
    "doc_tpl_selDetail": "选择模板查看详情",
    "doc_ver_title": "版本历史",
    "doc_ver_snapshot": "快照",
    "doc_ver_snapshotHelp": "创建版本快照",
    "doc_ver_compare": "对比",
    "doc_ver_compareHelp": "对比选中版本",
    "doc_ver_empty": "暂无版本历史",
    "doc_ver_versionFmt": "版本 %d",
    "doc_ver_setV1": "设为 V1 (旧版)",
    "doc_ver_setV2": "设为 V2 (新版)",
    "doc_ver_restore": "恢复此版本",
    "doc_ver_compareTitle": "版本对比",
    "doc_ver_diffFmt": "V%d → V%d",
    "doc_office_fmtDocx": "Word 文档",
    "doc_office_fmtXlsx": "Excel 表格",
    "doc_office_fmtPptx": "PowerPoint 演示",
    "doc_office_title": "Office 操控",
    "doc_office_cliStatus": "OfficeCLI 状态",
    "doc_office_versionFmt": "版本: %@",
    "doc_office_formatsFmt": "支持格式: %@",
    "doc_office_detecting": "检测中...",
    "doc_office_create": "创建文档",
    "doc_office_filename": "文件名",
    "doc_office_createBtn": "创建",
    "doc_office_import": "导入文档",
    "doc_office_filePath": "文件路径",
    "doc_office_importBtn": "导入",
    "doc_office_export": "导出页面",
    "doc_office_pageId": "页面 ID",
    "doc_office_format": "格式",
    "doc_office_exportBtn": "导出",
    "doc_office_merge": "模板合并",
    "doc_office_templateName": "模板名",
    "doc_office_dataJson": "数据 JSON",
    "doc_office_mergeBtn": "合并",
    "doc_office_cmdTitle": "Office 命令",
    "doc_office_cmdFile": "文件",
    "doc_office_cmdAction": "命令",
    "doc_office_executeBtn": "执行",
    "doc_office_importDir": "批量导入目录",
    "doc_office_dirPath": "目录路径",
    "doc_wf_newTitle": "新建工作流",
    "doc_wf_name": "名称",
    "doc_wf_desc": "描述",
    "doc_wf_create": "创建",
    "doc_wf_title": "工作流",
    "doc_wf_newHelp": "新建",
    "doc_wf_seedHelp": "种子工作流",
    "doc_wf_empty": "暂无工作流",
    "doc_wf_delete": "删除工作流",
    "doc_wf_yamlDef": "YAML 定义",
    "doc_wf_runInput": "运行输入",
    "doc_wf_runBtn": "执行工作流",
    "doc_wf_runHistory": "运行记录",
    "doc_wf_selDetail": "选择工作流查看详情",
    "doc_wf_transitionTitle": "页面状态转换",
    "doc_wf_queryBtn": "查询",
    "doc_wf_currentStateFmt": "当前状态: %@",
    "doc_wf_executeBtn": "执行",
    "proj_subtitle": "管理你的 AI 项目、指令和知识库",
    "proj_searchPh": "搜索项目",
    "proj_newHelp": "新建项目",
    "proj_archivedFmt": "Archived (%d)",
    "proj_fileCountFmt": "%d 文件",
    "proj_chatCountFmt": "%d 会话",
    "proj_archivedSuffix": "（归档）",
    "proj_unarchiveBtn": "取消归档",
    "proj_upstreamBanner": "部分服务不可用",
    "proj_emptyDetail": "选择一个项目查看详情",
    "proj_loadFailFmt": "加载失败: %@",
    "proj_deleteFailFmt": "删除失败: %@",
    "proj_minAgoFmt": "%d分钟前",
    "proj_hourAgoFmt": "%d小时前",
    "proj_dayAgoFmt": "%d天前",
    "proj_sortLastUpdated": "最近更新",
    "proj_sortDateCreated": "创建时间",
    "proj_sortAlphabetical": "名称排序",
    "proj_menuUnstar": "取消收藏",
    "proj_menuStar": "收藏项目",
    "proj_menuRename": "重命名",
    "proj_menuDuplicate": "复制项目",
    "proj_menuExport": "导出项目",
    "proj_menuArchive": "归档项目",
    "proj_menuDelete": "删除项目",
    "proj_menuSettings": "项目设置",
    "proj_deleteAlertTitle": "⚠️ 删除项目",
    "proj_deleteConfirm": "确认删除",
    "proj_deleteAlertMsgFmt": "确定要永久删除项目「%@」？此操作不可恢复。",
    "proj_deleteAlertMsgFullFmt": "确定要永久删除项目「%@」？\n· 项目指令及所有版本快照\n· 知识库全部文件（%d 个文件）\n· 项目内所有会话（%d 个会话）\n此操作不可恢复。",
    "proj_renameTitle": "重命名项目",
    "proj_namePh": "项目名称",
    "proj_createTitle": "Create New Project",
    "proj_createNameLabel": "Project name *",
    "proj_createDescLabel": "Description",
    "proj_createDescPh": "描述（可选）",
    "proj_createInstructions": "项目指令",
    "proj_createCharCountFmt": "字数：%d/%d",
    "proj_createInstructionsHint": "在这里定义角色、输出规范、业务约束，所有对话自动继承",
    "proj_createDefaultAgent": "默认智能体",
    "proj_createNoAgent": "不绑定（纯模型对话）",
    "proj_createNoAgentShort": "不绑定",
    "proj_createGotoAgentStudio": "前往 Agent Studio 创建新智能体",
    "proj_createPromptMerge": "Prompt 合并策略",
    "proj_createMergeAgentFirst": "Agent Prompt 优先（推荐）",
    "proj_createMergeProjectOnly": "仅使用项目 Instructions",
    "proj_createRagMode": "RAG 检索模式",
    "proj_createRagAuto": "AUTO（智能检索）",
    "proj_createRagManual": "MANUAL（手动指定）",
    "proj_createRagOff": "OFF（关闭）",
    "proj_createBtn": "Create Project",
    "proj_editModeMarkdown": "Markdown",
    "proj_editModeRichText": "富文本",
    "proj_dupTitle": "Duplicate Project",
    "proj_dupNameLabel": "New project name",
    "proj_dupCopySuffix": " (副本)",
    "proj_dupScope": "复制范围",
    "proj_dupScopeInstructionsOnly": "仅复制项目指令 + 知识库文件（推荐）",
    "proj_dupScopeWithSnapshots": "复制指令 + 知识库 + 全部会话快照",
    "proj_dupBtn": "Duplicate",
    "proj_detailArchived": "已归档",
    "proj_detailImportCowork": "导入CoWork",
    "proj_tabInstructions": "指令",
    "proj_tabKnowledge": "知识库",
    "proj_tabChats": "会话",
    "proj_instTitle": "项目指令",
    "proj_instEmpty": "暂无项目指令",
    "proj_instEmptyHint": "点击编辑按钮添加指令，所有对话将自动继承",
    "proj_instHistoryTitle": "📋 Instructions 版本历史",
    "proj_instHistoryEmpty": "暂无版本记录",
    "proj_instHistoryCurrentFmt": "V%d",
    "proj_instHistoryCurrentTag": "（当前版本）",
    "proj_instHistoryRestore": "恢复",
    "proj_kbTitle": "知识库",
    "proj_kbFileCountFmt": "%d 文件",
    "proj_kbFolder": "文件夹",
    "proj_kbAddFile": "添加文件",
    "proj_kbEmpty": "暂无知识库文件",
    "proj_kbEmptyHint": "上传文档帮助 AI 更好理解你的项目",
    "proj_kbNewFolderAlert": "新建文件夹",
    "proj_kbFolderNamePh": "文件夹名称",
    "proj_kbCreate": "创建",
    "proj_kbStatusIndexed": "已索引",
    "proj_kbStatusIndexing": "索引中",
    "proj_kbStatusFailed": "解析失败",
    "proj_kbStatusPending": "待索引",
    "proj_kbMenuPreview": "Preview",
    "proj_kbMenuRename": "Rename",
    "proj_kbMenuReplace": "Replace file",
    "proj_kbMenuMove": "Move to folder...",
    "proj_kbMenuRemove": "Remove from knowledge",
    "proj_chatsTitle": "会话",
    "proj_chatsSnapshots": "Snapshots",
    "proj_chatsSnapMsgCountFmt": "%d条消息",
    "proj_chatsEmpty": "选择或创建一个会话",
    "proj_chatsHint": "提示",
    "proj_chatsCreateFailFmt": "创建会话失败：%@\n请确认 fusion-projects 服务已启动。",
    "proj_chatsSendFailFmt": "发送失败：%@",
    "proj_chatsNoModel": "未选择对话模型，请在顶部模型选择器选一个模型后再发送",
    "proj_chatsReplyFailFmt": "AI 回复失败：%@",
    "proj_ragSources": "参考来源：",
    "proj_ragModeLabelFmt": "检索模式: %@",
    "proj_ragSwitchAuto": "切换为 AUTO",
    "proj_ragSwitchManual": "切换为 MANUAL",
    "proj_inputUseDefaultAgent": "使用项目默认智能体",
    "proj_inputGenericChat": "通用对话（不绑定Agent）",
    "proj_inputPreviewAgent": "预览当前Agent",
    "proj_inputRagLabelFmt": "RAG: %@",
    "proj_inputRagAuto": "AUTO（智能检索）",
    "proj_inputRagManual": "MANUAL（手动指定）",
    "proj_inputRagOff": "OFF（关闭检索）",
    "proj_inputAttachTemp": "临时附件",
    "proj_inputAttachScreenshot": "截图",
    "proj_inputAttachWebSearch": "WebSearch",
    "proj_inputAttachSkill": "技能工具",
    "proj_inputPlaceholder": "输入消息…",
    "proj_budgetLow": "⚠️ 预算不足",
    "proj_chatMenuUnstar": "取消收藏",
    "proj_chatMenuStar": "收藏会话",
    "proj_chatMenuRename": "Rename chat",
    "proj_chatMenuFork": "Fork chat",
    "proj_chatMenuSnapshot": "Create snapshot",
    "proj_chatMenuMove": "Move to another project",
    "proj_chatMenuRemove": "Remove from project",
    "proj_chatMenuDelete": "Delete chat",
    "proj_chatDeleteAlertTitle": "删除会话？",
    "proj_agentConfigTitle": "智能体配置",
    "proj_agentConfigDefault": "默认智能体",
    "proj_agentConfigPromptMerge": "Prompt 合并策略",
    "proj_ragConfigTitle": "RAG 配置",
    "proj_ragConfigMode": "检索模式",
    "proj_ragConfigTopKFmt": "Top-K: %d",
    "proj_ragConfigThresholdFmt": "相似度阈值: %@",
    "proj_ragConfigSelectScope": "选择检索范围",
    "proj_settingsTitleFmt": "⚙️ Project Settings — %@",
    "proj_settingsBasicInfo": "项目信息",
    "proj_settingsNameLabel": "项目名称",
    "proj_settingsDescLabel": "描述",
    "proj_settingsDescPh": "描述",
    "proj_settingsAgentConfig": "智能体配置",
    "proj_settingsPromptMerge": "Prompt 合并策略",
    "proj_settingsMergeAgentFirst": "Agent Prompt 优先（推荐）\nAgent 人设 + 项目业务规则组合注入",
    "proj_settingsMergeProjectOnly": "仅使用项目 Instructions\n忽略 Agent 内置 Prompt，完全项目自定义",
    "proj_settingsRagConfig": "RAG 配置",
    "proj_settingsRagAuto": "AUTO（智能检索 — 对标 Claude Projects）",
    "proj_settingsRagManual": "MANUAL（手动指定文件夹/文件检索）",
    "proj_settingsTopK": "TopK",
    "proj_settingsThreshold": "相似度阈值",
    "proj_settingsSaveBtn": "保存设置",
    "proj_previewUnbound": "未绑定",
    "proj_previewRole": "角色简介",
    "proj_previewActiveConfig": "当前生效配置",
    "proj_previewPromptStrategyFmt": "· Prompt策略：%@",
    "proj_previewPromptAgentFirst": "Agent优先",
    "proj_previewPromptProjectOnly": "仅项目Instructions",
    "proj_previewRagModeFmt": "· RAG模式：%@ (TopK=%d, 阈值=%@)",
    "proj_previewAccessKb": "· 允许访问本项目知识库",
    "proj_previewUnboundHint": "未绑定智能体，将使用纯模型对话",
    "proj_previewGotoAgentStudio": "前往 Agent Studio 修改",
    "proj_coworkTitle": "导入到 CoWork 空间",
    "proj_coworkTarget": "目标 CoWork 空间",
    "proj_coworkTargetPlaceholder": "（CoWork 空间列表）",
    "proj_coworkSyncContent": "同步内容",
    "proj_coworkSyncKnowledge": "知识库全部文件",
    "proj_coworkSyncSnapshots": "选中会话快照",
    "proj_coworkWarning": "知识库文件将复制到 CoWork 空间，后续变更不会自动同步",
    "proj_coworkConfirm": "确认导入",
    "proj_ragScopeTitle": "🔍 检索范围设置",
    "proj_ragScopeMode": "检索模式",
    "proj_ragScopeAuto": "AUTO（智能全局检索）",
    "proj_ragScopeManual": "MANUAL（手动指定范围）",
    "proj_ragScopeSpecify": "指定检索范围",
    "proj_ragScopeConfirm": "确认",
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

    "hub_rpmMustPositive": "⚠️ RPM must be > 0",
    "hub_concurrencyMustPositive": "⚠️ Concurrency must be > 0",
    "hub_idleTooLowWarn": "⚠️ Below 5 minutes may cause frequent load/unload and affect responsiveness",
    "hub_nDownloading": "%@ downloading",
    "hub_nActiveDeployments": "%@ active deployments",
    "hub_nItems": "%@ items",
    "hub_nModels": "%@ models",
    "hub_nRoles": "%@ roles",
    "hub_nReplicas": "%@ replicas",
    "hub_apiKeyCreated": "API Key Created",
    "hub_apiKeysTitle": "API Keys",
    "hub_apiKeysAndModelPerms": "API Keys & Model Permissions",
    "hub_apiThrottleConfig": "API Rate Limit Config",
    "hub_gbMemory": "GB Memory",
    "hub_kvCacheOpt": "KV-Cache Optimization",
    "hub_qpsLimitZero": "QPS Limit (0=unlimited)",
    "hub_rpmDefault": "RPM: %@ (default)",
    "hub_ttlConfigNote": "TTL Configuration Notes",
    "hub_ttlServeParamNote": "TTL is specified when the model service is deployed (ttl_seconds param of serve API)",
    "hub_securityScore": "Security Score",
    "hub_securityScan": "Security Scan",
    "hub_perModelSettings": "Per-Model Settings",
    "hub_autoBenchAfterVersion": "Auto-benchmark after version update",
    "hub_saveBtn": "Save",
    "hub_localResourceClusterHint": "When local resources are insufficient, auto-assign to idle Mac in cluster for inference",
    "hub_editRole": "Edit Role",
    "hub_editPermission": "Edit Permission",
    "hub_editPermissionModel": "Edit Permission — %@",
    "hub_concurrencyVal": "Concurrency: %@",
    "hub_concurrencyDefault": "Concurrency: %@ (default)",
    "hub_deployMetrics": "Deployment Metrics",
    "hub_auditLog": "Audit Log",
    "hub_testModelCount": "Test Model Count",
    "hub_testStatus": "Test Status",
    "hub_pinnedNoTTLNote": "Pinned models are not subject to TTL and always remain in memory",
    "hub_pinnedWhitelist": "Pinned Memory Whitelist",
    "hub_heldFlat": "Flat",
    "hub_createBtn": "Create",
    "hub_createApiKey": "Create API Key",
    "hub_createKey": "Create Key",
    "hub_createdAt": "Created at %@",
    "hub_disk": "Disk",
    "hub_storageDetail": "Storage Details",
    "hub_pendingApproval": "Pending Approval",
    "hub_perModelThrottle": "Per-Model Rate Limit",
    "hub_noActiveModels": "No active models",
    "hub_exportCsv": "Export CSV",
    "hub_waiting": "Waiting",
    "hub_benchThresholdWarn": "Benchmark results below the threshold will be flagged with a warning",
    "hub_scheduledBenchNote": "Scheduled tests run automatically at 3:00 AM daily or 3:00 AM every Monday",
    "hub_scheduledBenchmark": "Scheduled Benchmark",
    "hub_compare": "Compare",
    "hub_compareQuantResults": "Compare Quantization Results",
    "hub_benchCompareHint": "Compare model inference performance: Tokens/s, first-token latency, peak memory",
    "hub_compareSelectedN": "Compare Selected (%@)",
    "hub_layeredQuantHint": "Apply different quantization strategies to different layers to balance precision and speed",
    "hub_encryptModelWeights": "Encrypt and protect model weights",
    "hub_multiNodeSyncHint": "Multi-node only needs to download model files once, with automatic incremental sync",
    "hub_issuesFound": "Issues Found",
    "hub_idleUnloadHint": "minutes triggers model unload, releasing unified memory",
    "hub_peakMemory": "Peak Memory",
    "hub_copyAndClose": "Copy & Close",
    "hub_formatBitsMem": "Format: %@ | %@-bit | %@",
    "hub_redBelowThreshold": "Red = Below threshold",
    "hub_cache": "Cache",
    "hub_yellowNearThreshold": "Yellow = Near threshold",
    "hub_canaryPercent": "Canary %@%%",
    "hub_active": "Active",
    "hub_activeSessions": "Active Sessions",
    "hub_activeModelCountdown": "Active Model Countdown",
    "hub_clusterSchedConfig": "Cluster Scheduling Config",
    "hub_clusterNodeHealth": "Cluster Node Health",
    "hub_clusterSharedCache": "Cluster-Wide Shared Model Cache",
    "hub_encryption": "Encryption",
    "hub_encryptionMgmt": "Encryption Management",
    "hub_encryptModel": "Encrypt Model",
    "hub_loadDetail": "Loading details...",
    "hub_loading": "Loading...",
    "hub_securityScanTargetHint": "Will scan the specified model for security vulnerabilities",
    "hub_reject": "Reject",
    "hub_enableCrossNodeRouting": "Enable Cross-Node Inference Routing",
    "hub_startLayeredQuantize": "Start Layered Quantization",
    "hub_startQuantize": "Start Quantization",
    "hub_startScan": "Start Scan",
    "hub_startDownload": "Start Download",
    "hub_controlModuleModelHint": "Control which models each module can use — click Edit Permission to modify",
    "hub_controlRateConcurrencyHint": "Control rate limit and concurrency per model to prevent overload",
    "hub_quickPresetHint": "Quickly choose a quantization preset for your scenario",
    "hub_typeLabel": "Type: %@",
    "hub_historyBenchRecords": "Benchmark History",
    "hub_runBenchmarkNow": "Run a benchmark now",
    "hub_quantLinkedBench": "Quantization-Linked Benchmark",
    "hub_quantPostBench": "Post-Quantization Baseline",
    "hub_quantizedModel": "Quantized Model",
    "hub_quantizeTask": "Quantization Task",
    "hub_quantTaskBenchResult": "Auto-benchmark results after quantization task completes",
    "hub_autoBenchAfterQuantize": "Auto-benchmark after quantization",
    "hub_quantBits": "Quantization Bits",
    "hub_noRunningQuantTask": "No running quantization tasks",
    "hub_autoRefresh10s": "Auto-refresh every 10 seconds",
    "hub_rpmLabel": "Requests per minute (RPM)",
    "hub_rpmLabelColon": "Requests per minute (RPM):",
    "hub_pinnedWhitelistNote": "Models in the list stay permanently in memory and are never auto-unloaded",
    "hub_template": "Template",
    "hub_moduleAccessPerm": "Module Access Permissions",
    "hub_model": "Model",
    "hub_modelTTL": "Model TTL (time-to-live)",
    "hub_modelApprovalOps": "Model: %@",
    "hub_modelJoined": "Model: %@",
    "hub_autoBenchAfterQuantOrDownload": "Auto-run benchmarks after quantization or download to track performance changes",
    "hub_autoBenchQuantOrDownloadShort": "Auto-trigger benchmark after quantization completes or new model download finishes",
    "hub_autoBenchAfterQuantConvert": "After quantization conversion succeeds, auto-run performance benchmark",
    "hub_autoBenchAfterVersionLoad": "After a new model version loads, auto-run performance benchmark comparison",
    "hub_defaultThrottlePolicy": "Default Rate Limit Policy",
    "hub_targetFormat": "Target Format",
    "hub_benchIncludedModels": "Models Included in Test",
    "hub_memory": "Memory",
    "hub_benchmark": "Benchmark",
    "hub_benchResult": "Benchmark Result",
    "hub_benchResultColon": "Benchmark Result:",
    "hub_benchType": "Benchmark Type",
    "hub_benchTemplate": "Benchmark Template",
    "hub_benchModel": "Benchmark Model",
    "hub_score": "Score",
    "hub_scoreWarnThreshold": "Score warning threshold: %@",
    "hub_evalResult": "Assessment Result",
    "hub_evaluateQuant": "Assess Quantization",
    "hub_enableAutoBenchmark": "Enable Auto-Benchmark",
    "hub_cleanupSystem": "Clean Up System",
    "hub_apiKeyOnceHint": "Copy now — this key is shown only once:\n%@",
    "hub_requestsTotal": "Requests: %@",
    "hub_requestsPerMin": "Req/Min",
    "hub_selectTenantFirst": "Select a tenant on the left first",
    "hub_pleaseSelect": "Please select",
    "hub_cancelBtn": "Cancel",
    "hub_unifiedFusionApp": "Applies across all Fusion apps",
    "hub_all": "All",
    "hub_globalModelLoadPolicy": "Global Model Load Policy",
    "hub_globalThreshold": "Global Threshold",
    "hub_permissionSelect": "Permission Selection",
    "hub_date": "Date",
    "hub_scanModel": "Scan Model",
    "hub_scanModelSecurity": "Scan Model Security",
    "hub_scanDuplicates": "Scan Duplicates",
    "hub_setIdleUnloadCountdown": "Set model auto-unload countdown — releases unified memory after idle timeout",
    "hub_setThreshold": "Set Threshold",
    "hub_requester": "Requester: %@",
    "hub_requesterShort": "Requester: %@",
    "hub_approval": "Approval",
    "hub_approvalWorkflow": "Approval Workflow",
    "hub_approvalProcess": "Approval Process",
    "hub_reviewerWithComment": "Reviewer: %@%@",
    "hub_approvalDetail": "Approval Detail",
    "hub_remainingTime": "Remaining Time",
    "hub_failed": "Failed",
    "hub_time": "Time",
    "hub_realtimeMonitor": "Realtime Monitor",
    "hub_firstToken": "First Token",
    "hub_firstTokenSec": "First Token (s)",
    "hub_firstTokenLatency": "First-Token Latency",
    "hub_refresh": "Refresh",
    "hub_watermarkMgmt": "Watermark Management",
    "hub_add": "Add",
    "hub_addWatermark": "Add Watermark",
    "hub_deactivate": "Deactivate",
    "hub_approve": "Approve",
    "hub_general2": "General",
    "hub_done": "Done",
    "hub_completionTime": "Completion Time",
    "hub_addDigitalWatermarkHint": "Add a digital watermark to the model to protect intellectual property",
    "hub_unconfiguredUsesDefault": "Models without custom config use the default policy",
    "hub_noSecurityIssues": "No security issues found",
    "hub_noClusterNodes": "No cluster nodes detected",
    "hub_noModelWillTestAll": "No model selected — all downloaded models will be tested",
    "hub_issueSummary": "Issue Summary",
    "hub_none": "None",
    "hub_noPermissionConfig": "No permission config",
    "hub_downloadLabel": "Download: %@",
    "hub_downloadTask": "Download Tasks",
    "hub_downloadNewModel": "Download New Model",
    "hub_idle": "Idle",
    "hub_idleAfterTTLUnload": "After idle time exceeds TTL, the model is auto-unloaded from memory, releasing GPU unified memory",
    "hub_idleAutoReclaim": "Idle Auto-Reclaim",
    "hub_auditLogFirstN": "Showing first 30 of %@ entries",
    "hub_throttleConfigModel": "Rate Limit Config — %@",
    "hub_newRole": "New Role",
    "hub_newBenchmark": "New Benchmark",
    "hub_newDownload": "New Download",
    "hub_newTenant": "New Tenant",
    "hub_performanceBenchmark": "Performance Benchmark",
    "hub_selectBenchModels": "Select Benchmark Models",
    "hub_selectModel": "Select Model",
    "hub_selectModelPlaceholder": "Select model...",
    "hub_selectBenchModel": "Select Benchmark Model",
    "hub_latencyMs": "Latency (ms)",
    "hub_rejected": "Rejected",
    "hub_configuredTTLModels": "Models with TTL Configured",
    "hub_deactivated": "Deactivated",
    "hub_approved": "Approved",
    "hub_selectedNModelsLoading": "Selected %@ models (loading...)",
    "hub_hardwareInfo": "Hardware Info",
    "hub_permanentResidentNoTTL": "Permanent Resident (no TTL)",
    "hub_estimatedReduction": "Estimated Reduction",
    "hub_presetScheme": "Preset Scheme",
    "hub_originalVsQuant": "Original vs Quantized",
    "hub_originalModel": "Original Model",
    "hub_allowedModulesHint": "Allowed modules (blank = all)",
    "hub_allowedModelsHint": "Allowed models (blank = all)",
    "hub_runningColon": "Running: %@",
    "hub_runBenchmark": "Run Benchmark",
    "hub_running": "Running",
    "hub_noApiKey": "No API keys",
    "hub_noAuditLogs": "No audit logs",
    "hub_noPinnedModels": "No pinned models",
    "hub_noActiveDeployments": "No active deployments",
    "hub_noRoles": "No roles",
    "hub_noHistory": "No history",
    "hub_noQuantLinkedBench": "No quantization-linked benchmark data",
    "hub_noModels": "No models",
    "hub_noModelData": "No model data",
    "hub_noBenchRecords": "No benchmark records",
    "hub_noBenchData": "No benchmark data — select a model and run a benchmark",
    "hub_noApprovalRequests": "No approval requests",
    "hub_noInferenceData": "No inference data",
    "hub_noDownloadTasks": "No download tasks",
    "hub_noDownloadedModels": "No downloaded models",
    "hub_noTenants": "No tenants",
    "hub_executionFrequency": "Execution Frequency",
    "hub_qualityChange": "Quality change: %@",
    "hub_qualityScore": "Quality Score",
    "hub_reset": "Reset",
    "hub_attentionQuant": "Attention Layer Quantization",
    "hub_convertQuantize": "Convert & Quantize",
    "hub_status": "Status",
    "hub_statusApproval": "Status: %@",
    "hub_accuracy": "Accuracy",
    "hub_accuracyVal": "Accuracy: %@",
    "hub_accuracyWarnThreshold": "Accuracy warning threshold: %@",
    "hub_accuracyThresholdSettings": "Accuracy Threshold Settings",
    "hub_custom": "Custom",
    "hub_autoTest": "Auto Test",
    "hub_autoBenchmark": "Auto-Benchmark",
    "hub_autoBenchRules": "Auto-Benchmark Rules",
    "hub_autoBenchTemplateLabel": "Auto-benchmark template:",
    "hub_tenant": "Tenant",
    "hub_tenantsAndRoles": "Tenants & Roles",
    "hub_maxConcurrency": "Max Concurrency",
    "hub_maxConcurrencyColon": "Max Concurrency:",
    "hub_expired": "Expired",
    "hub_unknownIssue": "Unknown issue",
    "hub_notYetScanned": "No security scan yet",
    "hub_noWatermarkInfo": "No watermark info",
    "hub_noEncryptionInfo": "No encryption info",
    "hub_noApprovalRecords": "No approval records",
    "hub_modelId": "Model ID",
    "hub_watermarkStatus": "Watermark Status",
    "hub_watermarkId": "Watermark ID",
    "hub_verifyStatus": "Verification Status",
    "hub_verified": "Verified",
    "hub_notVerified": "Not verified",
    "hub_embeddedTime": "Embedded Time",
    "hub_encryptionStatus": "Encryption Status",
    "hub_encryptionAlgorithm": "Encryption Algorithm",
    "hub_encryptionTime": "Encryption Time",
    "hub_watermarkText": "Watermark Text",
    "hub_addBtn": "Add",
    "hub_encryptBtn": "Encrypt",
    "hub_modelIdPlaceholder": "Model ID",
    "hub_downloadUrlPlaceholder": "Download URL (https://...)",
    "hub_downloadSched": "Download Scheduling",
    "hub_computeSchedPolicy": "Compute Scheduling Policy",
    "hub_modulePermission": "Module Permission",
    "hub_apiThrottle": "API Rate Limit",
    "hub_modelTTLTab": "Model TTL",
    "hub_autoBenchmarkTab": "Auto-Benchmark",
    "hub_policyAuto": "Smart auto scheduling",
    "hub_policyAutoDesc": "Auto load/unload based on requests (recommended)",
    "hub_policyPinned": "Manual pinned",
    "hub_policyPinnedDesc": "Model stays in memory, never auto-unloaded",
    "hub_policyOnDemand": "Unload after use",
    "hub_policyOnDemandDesc": "Unload immediately after each request, saves the most memory",
    "hub_idlePrefix": "Idle",
    "hub_editPermissionBtn": "Edit Permission",
    "hub_edit": "Edit",
    "hub_daily": "Daily",
    "hub_weekly": "Weekly",
    "hub_monthly": "Monthly",
    "hub_enabled": "Enabled",
    "hub_notEnabled": "Not enabled",
    "hub_benchmarkStarted": "Benchmark started — check results later",
    "hub_evalTaskCreated": "Evaluation task created",
    "hub_quantizeStarted": "Quantization task started",
    "hub_layeredQuantizeStarted": "Layered quantization task started",
    "hub_assessFailed": "Assessment failed: %@",
    "hub_layeredQuantFailed": "Layered quantization failed: %@",
    "hub_compareFailed": "Compare failed: %@",
    "hub_evalStartedForModel": "Benchmark started for %@",
    "hub_evalFailed": "Benchmark failed: %@",
    "hub_templateGeneral": "General",
    "hub_templateCode": "Code",
    "hub_templateReasoning": "Reasoning",
    "hub_templateMultilingual": "Multilingual",
    "hub_templateVision": "Vision",
    "hub_evalTypeAccuracy": "Accuracy",
    "hub_evalTypeAlignment": "Alignment",
    "hub_evalTypeSafety": "Safety",
    "hub_evalTypeCode": "Code Capability",
    "hub_evalTypeReasoning": "Reasoning Capability",
    "hub_evalTypeGeneral": "General",
    "hub_evalTypeComprehensive": "Comprehensive",
    "hub_unknown": "Unknown",
    "hub_unknownModel": "Unknown model",
    "hub_operationDeploy": "Deploy",
    "hub_operationDelete": "Delete",
    "hub_operationQuantize": "Quantize",
    "hub_operationExport": "Export",
    "hub_operationServe": "Serve",
    "hub_operationDownload": "Download",
    "hub_operation": "Operation",
    "hub_allSources": "All sources",
    "hub_sourceLocal": "Local",
    "hub_sourceHub": "Hub",
    "hub_sourceCustom": "Custom",
    "hub_source": "Source",
    "hub_health_healthy": "Healthy",
    "hub_health_warning": "Warning/Degraded",
    "hub_health_error": "Error/Overloaded",
    "hub_chip": "Chip",
    "hub_cpuCores": "CPU Cores",
    "hub_gpuCores": "GPU Cores",
    "hub_available": "Available",
    "hub_supported": "Supported",
    "hub_neCores": "NE Cores",
    "hub_modelName": "Model Name",
    "hub_modelInferenceStats": "Model Inference Stats",
    "hub_noDownloadTasksShort": "No download tasks",
    "hub_selectTenantViewRoles": "Select tenant to view roles",
    "hub_roleList": "Role List",
    "hub_keyName": "Key Name",
    "hub_tenantName": "Tenant Name",
    "hub_defaultRole": "Default Role",
    "hub_roleName": "Role Name",
    "hub_approvalCommentOptional": "Approval comment (optional)",
    "hub_approvalComment": "Approval comment",
    "hub_roleAdmin": "Admin",
    "hub_roleMember": "Member",
    "hub_roleGuest": "Guest",
    "hub_roleAdminCaps": "All models + all modules + key management + system config",
    "hub_roleMemberCaps": "Specified models + standard modules + no system config",
    "hub_roleGuestCaps": "Restricted models + chat only + rate limited",
    "hub_copyAndClose2": "Copy & Close",
    "hub_presetChatLabel": "Chat Model",
    "hub_presetCodeLabel": "Code Model",
    "hub_presetEmbeddingLabel": "Embedding Model",
    "hub_presetRagLabel": "RAG Model",
    "hub_presetChatMem": "Low Memory",
    "hub_presetCodeMem": "Balanced",
    "hub_presetEmbeddingMem": "Precision First",
    "hub_presetRagMem": "Inference Optimized",
    "hub_presetChatDesc": "4-bit MLX quantization, suitable for chat, lowest memory",
    "hub_presetCodeDesc": "8-bit MLX quantization, balanced code quality and speed",
    "hub_presetEmbeddingDesc": "FP16 MLX format, preserves embedding precision, suitable for retrieval",
    "hub_presetRagDesc": "4-bit GGUF format, optimized for RAG inference, llama.cpp compatible",
    "hub_scenePreset": "Scene Preset",
    "hub_quantConfig": "Quantization Config",
    "hub_layeredQuantize": "Layered Quantization",
    "hub_quantCompare": "Quantization Compare",
    "hub_qualityLabel": "Quality: %.0f%%",
    "hub_speedLabel": "Speed: %.1f tok/s",
    "hub_memoryLabelFmt": "Memory: %.1f GB",
    "hub_firstTokenFmt": "First Token: %.2fs",
    "hub_accuracyFmt": "Accuracy: %.1f%%",
    "hub_benchResultPrefix": "Benchmark result:",
    "hub_accuracyPrefix": "Accuracy %.1f%%",
    "hub_firstTokenPrefix": "First Token %.2fs",
    "hub_memoryPrefix": "Memory %.1f GB",
    "hub_perTokenLatency": "Per-Token Latency",
    "hub_firstTokenLatencyLabel": "First-Token Latency",
    "hub_prefillLatency": "Prefill Latency",
    "hub_decodeLatency": "Decode Latency",
    "hub_throughputBatch1": "Batch=1 Throughput",
    "hub_throughputBatch2": "Batch=2 Throughput",
    "hub_throughputBatch4": "Batch=4 Throughput",
    "hub_throughputBatch8": "Batch=8 Throughput",
    "hub_memoryFootprint": "Memory Footprint",
    "hub_usedStorageFmt": "Used %.1f / %.1f GB (%.0f%%)",
    "hub_tokensPerSecCol": "Tokens/s",
    "hub_accuracyCol": "Accuracy",
    "hub_scoreCol": "Score",
    "hub_compareCol": "Compare",
    "hub_templateCol": "Template",
    "hub_deployment": "Deployment",
    "hub_newEval": "New Evaluation",
    "hub_quantColon": "Quantize: %@",
    "hub_dlColon": "Download: %@",
    "hub_modelColon": "Model: %@",
    "hub_modelColonJoined": "Model: %@",
    "hub_requesterColon": "Requester: %@",
    "hub_reviewerColonComment": "Reviewer: %@%@",
    "hub_statusColon": "Status: %@",
    "hub_typeColon": "Type: %@",
    "hub_showingFirstN": "Showing first 30 of %@",
    "hub_nReplicasFmt": "%@ replicas",
    "hub_canaryFmt": "Canary %@%%",
    "hub_nActiveDeploymentsFmt": "%@ active deployments",
    "hub_nDownloadingFmt": "%@ downloading",
    "hub_nRolesFmt": "%@ roles",
    "hub_nItemsFmt": "%@ items",
    "hub_sevCritical": "Critical", "hub_sevHigh": "High", "hub_sevMedium": "Medium", "hub_sevLow": "Low",
    "hub_latencyLabel": "Latency", "hub_errorRate": "Error rate", "hub_grayCanary": "Canary %@%",
    "hub_quantLabel": "Quantize: %@", "hub_runningLabel": "Uptime: %@", "hub_activeDeploymentsFmt": "%d active deployments",
    "hub_countItemsFmt": "%d items", "hub_copiesFmt": "%d replicas", "hub_auditShowingFmt": "Showing top 30 of %d entries",
    "hub_modelSizeFmt": "Models: %.1f GB", "hub_csvHeader": "ID,Time,Action,Source,Resource,User,Details\n",
    "hub_roleCountFmt": "%d roles", "hub_createdAtFmt": "Created %@", "hub_modelsPermListFmt": "Models: %@",
    "hub_modelPermissions": "Model permissions", "hub_apiKeyCopyOnceWarn": "Copy now — this key is shown only once:\n%@",
    "hub_requestsTotalFmt": "Requests: %d", "hub_reviewerCommentFmt": "Reviewer: %@%@",
    "hub_compareSelectedFmt": "Compare selected (%d)", "hub_modelBenchmark": "Model benchmark",
    "hub_scoreWarnThresholdFmt": "Score warning threshold: %@", "hub_accuracyFmt2": "Accuracy: %@",
    "hub_accuracyWarnThresholdFmt": "Accuracy warning threshold: %@", "hub_activeDownloadsFmt": "%d downloading",
    "hub_durationHMSFmt": "%@h %@m %@s", "hub_durationMSFmt": "%@m %@s", "hub_durationSFmt": "%@s",
    "hub_durationZero": "0s", "hub_rpmDefaultFmt": "RPM: %d (default)", "hub_editPermTitleFmt": "Edit permission — %@",
    "hub_concurrencyFmt": "Concurrency: %d", "hub_concurrencyDefaultFmt": "Concurrency: %d (default)",
    "hub_throttleConfigTitleFmt": "Throttle config — %@", "hub_selectedModelsLoadingFmt": "%d models selected (loading...)",
    "hub_ls_catAll": "All", "hub_ls_catChat": "General Chat", "hub_ls_catCode": "Code", "hub_ls_catEmbed": "Embedding", "hub_ls_catVision": "Vision Multimodal", "hub_ls_catPrivate": "Private", "hub_ls_catPinned": "Pinned", "hub_ls_catServing": "Serving", "hub_ls_catLLM": "Language Model", "hub_ls_catVLM": "Vision Model", "hub_ls_catEmbedM": "Embedding Model", "hub_ls_catCodeM": "Code Model", "hub_ls_catAudioM": "Audio Model", "hub_ls_catMLX": "MLX Format", "hub_ls_catGGUF": "GGUF Format", "hub_ls_category": "Categories", "hub_ls_searchPlaceholder": "Search local models...", "hub_ls_batchMode": "Batch Mode", "hub_ls_selectedCountFmt": "%d selected", "hub_ls_selectAll": "Select All", "hub_ls_batchDelete": "Batch Delete", "hub_ls_batchQuantize": "Batch Quantize", "hub_ls_syncCluster": "Sync to Cluster", "hub_ls_exportPath": "Export Path", "hub_ls_currentUse": "In Use", "hub_ls_serving": "Serving", "hub_ls_compatFormats": "Compatible formats:", "hub_ls_unpin": "Unpin", "hub_ls_pin": "Pin", "hub_ls_stopServe": "Stop Serving", "hub_ls_startServe": "Start Serving", "hub_ls_basicInfo": "Basic Info", "hub_ls_path": "Path", "hub_ls_source": "Source", "hub_ls_engine": "Engine", "hub_ls_license": "License", "hub_ls_allowedModules": "Allowed Modules", "hub_ls_selectModelHint": "Select a model to view details", "hub_ls_versionMgmt": "Version Management", "hub_ls_versionList": "Version List", "hub_ls_noVersions": "No version info", "hub_ls_rollback": "Rollback", "hub_ls_publish": "Publish", "hub_ls_deprecate": "Deprecate", "hub_ls_retire": "Retire", "hub_ls_resident": "Resident", "hub_ls_batchQuantTitle": "Batch Quantize", "hub_ls_batchQuantHintFmt": "Will quantize %d models", "hub_ls_targetFormat": "Target Format", "hub_ls_quantBits": "Quantization Bits", "hub_ls_startQuantize": "Start Quantize", "hub_ls_batchQuantFailFmt": "Batch quantize failed: %@", "hub_ls_rollbackFailFmt": "Version rollback failed: %@", "hub_ls_syncFailFmt": "Cluster sync failed: %@", "hub_ls_startServeFailFmt": "Start serving failed: %@", "hub_ls_stopServeFailFmt": "Stop serving failed: %@", "hub_ls_publishFailFmt": "Publish version failed: %@", "hub_ls_deprecateFailFmt": "Deprecate version failed: %@", "hub_ls_retireFailFmt": "Retire version failed: %@",
    "hub_cls_nodes": "Cluster Nodes", "hub_cls_onlineFmt": "%d/%d online", "hub_cls_syncModel": "Sync Model", "hub_cls_noNodes": "No cluster nodes", "hub_cls_noNodesHint": "Ensure multiple Macs on same network with Model Hub service running", "hub_cls_selectNodeHint": "Select a node to view details", "hub_cls_nodeInfo": "Node Info", "hub_cls_addr": "Address", "hub_cls_lastSeen": "Last Seen", "hub_cls_resourceUsage": "Resource Usage", "hub_cls_memory": "Memory", "hub_cls_localModelsFmt": "Local Models (%d)", "hub_cls_autoSchedule": "Auto Schedule Inference", "hub_cls_localFirst": "Local first, cluster fallback", "hub_cls_model": "Model", "hub_cls_selectModelHint": "Select model...", "hub_cls_routeMode": "Route Mode", "hub_cls_promptPlaceholder": "Enter inference prompt...", "hub_cls_sendInfer": "Send Inference Request", "hub_cls_inferResult": "Inference Result", "hub_cls_routedTo": "Routed to:", "hub_cls_resultHint": "View result after sending inference request", "hub_cls_syncToCluster": "Sync Model to Cluster", "hub_cls_syncHint": "Sync model files to all online cluster nodes", "hub_cls_startSync": "Start Sync", "hub_cls_modeAuto": "Auto", "hub_cls_modeLocal": "Local First", "hub_cls_modeCluster": "Cluster",
    "hub_dash_mlxEngine": "MLX Inference Engine", "hub_dash_clusterMode": "Cluster Mode", "hub_dash_modelService": "Model Service", "hub_dash_localModels": "Local Models", "hub_dash_activeModels": "Active Models", "hub_dash_downloading": "Downloading", "hub_dash_totalStorage": "Total Storage", "hub_dash_pinned": "Pinned", "hub_dash_quantizing": "Quantizing", "hub_dash_clusterNodes": "Cluster Nodes", "hub_dash_totalModels": "Total Models", "hub_dash_quickActions": "Quick Actions", "hub_dash_searchMarket": "Search Market", "hub_dash_downloadModel": "Download Model", "hub_dash_quantizeModel": "Quantize Model", "hub_dash_systemClean": "System Cleanup", "hub_dash_recentModels": "Recent Models", "hub_dash_noModels": "No models", "hub_dash_resident": "Resident", "hub_dash_serving": "Serving", "hub_dash_sysOverview": "System Overview", "hub_dash_memory": "Memory", "hub_dash_disk": "Disk", "hub_dash_uptime": "Uptime", "hub_dash_loading": "Loading...",
    "hub_mv_descQwen35": "Qwen3.5, 9B params, 4bit quant", "hub_mv_descLlama3": "Meta Llama 3, 8B params, 4bit quant", "hub_mv_descDeepseek": "DeepSeek code model", "hub_mv_descQwenVL": "Qwen2 vision-language model", "hub_mv_catAll": "All", "hub_mv_searchPlaceholder": "Search models...", "hub_mv_selectModelHint": "Select a model to view details", "hub_mv_downloadModel": "Download Model", "hub_mv_refresh": "Refresh", "hub_mv_active": "Active", "hub_mv_ready": "Ready", "hub_mv_notDownloaded": "Not Downloaded", "hub_mv_currentUse": "In Use", "hub_mv_download": "Download", "hub_mv_activate": "Activate", "hub_mv_downloadingFmt": "Downloading... %d%%", "hub_mv_basicInfo": "Basic Info", "hub_mv_modelId": "Model ID", "hub_mv_path": "Path", "hub_mv_size": "Size", "hub_mv_format": "Format", "hub_mv_quant": "Quantization", "hub_mv_family": "Family", "hub_mv_params": "Parameters", "hub_mv_description": "Description", "hub_mv_searchHF": "Search HuggingFace models...", "hub_mv_search": "Search", "hub_mv_recommended": "Recommended Models", "hub_mv_repoIdHint": "Or enter HuggingFace repo ID directly", "hub_mv_hfTokenOptional": "HF Token (optional)",
    "hub_dep_stPending": "Pending",
    "hub_dep_stRunning": "Running",
    "hub_dep_stStopped": "Stopped",
    "hub_dep_stFailed": "Failed",
    "hub_dep_stUnknown": "Unknown",
    "hub_dep_management": "Deployment Management",
    "hub_dep_empty": "No deployments",
    "hub_dep_selectHint": "Select a deployment to view details",
    "hub_dep_replicasFmt": "%@ replicas",
    "hub_dep_canaryFmt": "Canary %d%%",
    "hub_dep_config": "Configuration",
    "hub_dep_model": "Model",
    "hub_dep_modelName": "Model Name",
    "hub_dep_strategy": "Strategy",
    "hub_dep_replicasCount": "Replicas",
    "hub_dep_canaryRatio": "Canary Ratio",
    "hub_dep_createdAt": "Created",
    "hub_dep_updatedAt": "Updated",
    "hub_dep_metrics": "Metrics",
    "hub_dep_reqPerSec": "Req/s",
    "hub_dep_latencyMs": "Latency(ms)",
    "hub_dep_errorRate": "Error Rate",
    "hub_dep_refreshMetrics": "Refresh Metrics",
    "hub_dep_actions": "Actions",
    "hub_dep_stopDep": "Stop",
    "hub_dep_scale": "Scale",
    "hub_dep_grayRelease": "Canary Release",
    "hub_dep_deleteDep": "Delete",
    "hub_dep_stopFailFmt": "Stop failed: %@",
    "hub_dep_scaleFailFmt": "Scale failed: %@",
    "hub_dep_grayFailFmt": "Canary release failed: %@",
    "hub_dep_deleteFailFmt": "Delete failed: %@",
    "hub_dep_metricsFailFmt": "Metrics load failed: %@",
    "hub_dep_createDep": "Create Deployment",
    "hub_dep_modelId": "Model ID",
    "hub_dep_depStrategy": "Deployment Strategy",
    "hub_dep_replicasStepperFmt": "Replicas: %d",
    "hub_dep_canaryStepperFmt": "Canary Ratio: %d%%", "hub_cls_modelCountFmt": "%d models",
    "hub_mkt_searchPlaceholder": "Search models...",
    "hub_mkt_sourceAll": "All Sources",
    "hub_mkt_sourceLocal": "Local",
    "hub_mkt_sourcePrivate": "Private Repo",
    "hub_mkt_taskAll": "All Tasks",
    "hub_mkt_taskTextGen": "Text Generation",
    "hub_mkt_taskCode": "Code",
    "hub_mkt_taskVision": "Vision",
    "hub_mkt_taskEmbedding": "Embedding",
    "hub_mkt_taskAudio": "Audio",
    "hub_mkt_taskMultimodal": "Multimodal",
    "hub_mkt_formatAll": "All Formats",
    "hub_mkt_paramSizeAll": "All Sizes",
    "hub_mkt_localOnly": "Local Only",
    "hub_mkt_loadMoreFmt": "Load More (%d/%d)",
    "hub_mkt_emptyTitle": "Search HuggingFace / ModelScope / private repos",
    "hub_mkt_emptyHint": "Multi-source search, format/size/task filters",
    "hub_mkt_download": "Download",
    "hub_mkt_convertMLX": "Convert to MLX",
    "hub_mkt_addBenchmark": "Add to Benchmark",
    "hub_mkt_ragDefault": "RAG Default",
    "hub_mkt_ragDefaultCurrent": "Current RAG default embedding model",
    "hub_mkt_ragDefaultSet": "Set as RAG default embedding model",
    "hub_mkt_size": "Size",
    "hub_mkt_downloads": "Downloads",
    "hub_mkt_likes": "Likes",
    "hub_mkt_license": "License",
    "hub_mkt_author": "Author",
    "hub_mkt_selectModelHint": "Select a model to view details",
    "hub_mkt_pickerSource": "Source",
    "hub_mkt_pickerTask": "Task",
    "hub_mkt_pickerFormat": "Format",
    "hub_mkt_pickerParam": "Parameters",
    "hub_mkt_downloadFailFmt": "Download failed: %@",
    "hub_mkt_mlxFailFmt": "MLX conversion download failed: %@",
    "hub_mkt_benchFailFmt": "Benchmark trigger failed: %@",
    "hub_main_secDashboard": "Dashboard",
    "hub_main_secMarket": "Market",
    "hub_main_secLocalStorage": "Local Storage",
    "hub_main_secConvertQuant": "Convert & Quantize",
    "hub_main_secSchedule": "Download Schedule",
    "hub_main_secCluster": "Cluster",
    "hub_main_secDeployment": "Deployment",
    "hub_main_secPermission": "Permission",
    "hub_main_secMonitor": "Monitor",
    "hub_main_secBenchmark": "Benchmark",
    "hub_main_secSecurity": "Security",
    "hub_main_noKeyMsg": "No API Key configured. Protected endpoints will return 401. Go to Permission to create a key.",
    "hub_main_goCreate": "Create Now",
    "hub_main_connected": "Connected",
    "hub_main_disconnected": "Disconnected",
    "hub_main_serviceNotConnected": "Model Hub service not connected",
    "hub_main_serviceHintFmt": "Ensure fusion-model-hub service is running (port %d)",
    "hub_main_retry": "Retry",
    "hub_ver_draft": "Draft",
    "hub_ver_testing": "Testing",
    "hub_ver_published": "Published",
    "hub_ver_deprecated": "Deprecated",
    "hub_ver_retired": "Retired",
    "hub_role_admin": "Admin",
    "hub_role_developer": "Developer",
    "hub_role_viewer": "Viewer",
    "hub_role_custom": "Custom",
    "hub_lvl_l1": "L1 Auto Approval",
    "hub_lvl_l2": "L2 Manager Approval",
    "hub_lvl_l3": "L3 Security Approval",
    "hub_lvl_unknown": "Unknown",
    "doc_tab_editor": "Editor",
    "doc_tab_graph": "Knowledge Graph",
    "doc_tab_versions": "Versions",
    "doc_tab_office": "Office",
    "doc_tab_workflow": "Workflow",
    "doc_tab_template": "Templates",
    "doc_tab_search": "Search",
    "doc_tab_comments": "Comments",
    "doc_tab_favorites": "Favorites",
    "doc_tab_files": "Files",
    "doc_tab_rag": "RAG",
    "doc_tab_activity": "Activity",
    "doc_aiCopilot": "AI Copilot",
    "doc_selPageVersions": "Select a page to view version history",
    "doc_auth_title": "Fusion Doc Authentication",
    "doc_auth_mode": "Mode",
    "doc_auth_login": "Login",
    "doc_auth_setup": "Initial Setup",
    "doc_auth_username": "Username",
    "doc_auth_password": "Password",
    "doc_auth_confirmPwd": "Confirm Password",
    "doc_auth_createAdmin": "Create Admin",
    "doc_auth_authenticated": "Authenticated ✓",
    "doc_cmt_title": "Comments",
    "doc_cmt_empty": "No comments yet",
    "doc_cmt_reply": "Reply",
    "doc_cmt_replyLabel": "Reply to comment",
    "doc_cmt_replyPlaceholder": "Reply to comment...",
    "doc_cmt_addPlaceholder": "Add a comment...",
    "doc_cmt_selPage": "Select a page to view comments",
    "doc_fav_title": "Favorites",
    "doc_fav_empty": "No favorites yet",
    "doc_fav_addHint": "Click the star in a page to add a favorite",
    "doc_fav_noTitle": "Untitled",
    "doc_file_title": "Attachments",
    "doc_file_countFmt": "%d files",
    "doc_file_empty": "No attachments yet",
    "doc_file_unknown": "Unknown file",
    "doc_file_upload": "Upload Attachment",
    "doc_file_name": "Filename",
    "doc_file_uploadBtn": "Upload",
    "doc_file_selPage": "Select a page to view attachments",
    "doc_ws_title": "Workspaces",
    "doc_ws_empty": "No workspaces yet",
    "doc_ws_createFirst": "Create your first workspace",
    "doc_ws_name": "Name",
    "doc_ws_descOptional": "Description (optional)",
    "doc_ws_create": "Create",
    "doc_ws_delete": "Delete",
    "doc_act_title": "Activity Log",
    "doc_act_empty": "No activity yet",
    "doc_act_evPageCreate": "📄 Created page",
    "doc_act_evPageUpdate": "✏️ Updated page",
    "doc_act_evPageDelete": "🗑️ Deleted page",
    "doc_act_evCommentCreate": "💬 Added comment",
    "doc_act_evFavAdd": "⭐ Added favorite",
    "doc_act_evFavRemove": "☆ Removed favorite",
    "doc_act_evVerCreate": "🔖 Created version",
    "doc_act_evWorkflowRun": "🔄 Ran workflow",
    "doc_act_evFileUpload": "📎 Uploaded file",
    "doc_cp_modeChat": "Chat",
    "doc_cp_modeCommand": "Command",
    "doc_cp_modeRag": "Knowledge",
    "doc_cp_modeRewrite": "Rewrite",
    "doc_cp_modeTranslate": "Translate",
    "doc_cp_modeSummarize": "Summarize",
    "doc_cp_modeExpand": "Expand",
    "doc_cp_targetLang": "Target Language",
    "doc_cp_clearChat": "Clear chat",
    "doc_cp_thinking": "Thinking...",
    "doc_cp_phChat": "Type a message...",
    "doc_cp_phCommand": "/command ...",
    "doc_cp_phRewrite": "Enter rewrite instruction...",
    "doc_cp_phTranslateFmt": "Enter text to translate to %@...",
    "doc_cp_phSummarize": "Enter text to summarize...",
    "doc_cp_phExpand": "Enter text to expand...",
    "doc_cp_phRag": "Knowledge retrieval...",
    "doc_cp_errCopilotURL": "Copilot URL unavailable",
    "doc_cp_errCommandURL": "Command URL unavailable",
    "doc_cp_errNoData": "No response data",
    "doc_cp_emptyResp": "(empty response)",
    "doc_cp_ragChunksPrefix": "📚 Relevant knowledge chunks:",
    "doc_cp_ragNoResult": "No relevant results",
    "doc_cp_rewriteResultPrefix": "✏️ Rewrite result: ",
    "doc_cp_translateResultFmt": "🌐 Translation (%@): ",
    "doc_cp_summarizePrefix": "📋 Summary: ",
    "doc_cp_expandPrefix": "📖 Expanded content: ",
    "doc_cp_noResult": "(no result)",
    "doc_cp_errPrefix": "❌ ",
    "doc_graph_title": "Knowledge Graph",
    "doc_graph_filterAll": "All",
    "doc_graph_filterLink": "Link",
    "doc_graph_filterSemantic": "Semantic",
    "doc_graph_filterTag": "Tag",
    "doc_graph_searchNode": "Search nodes...",
    "doc_graph_refreshHelp": "Refresh graph",
    "doc_graph_loading": "Loading graph...",
    "doc_graph_linkCountFmt": "Links: %d",
    "doc_graph_openPage": "Open page",
    "doc_graph_empty": "No graph data yet",
    "doc_graph_emptyHint": "Knowledge graph generates automatically after creating links between pages",
    "doc_rag_title": "RAG Knowledge Enhancement",
    "doc_rag_semanticQuery": "Semantic Query",
    "doc_rag_queryPlaceholder": "Enter a query question...",
    "doc_rag_answer": "Answer",
    "doc_rag_chunksFmt": "Relevant chunks (%d)",
    "doc_rag_pageChunks": "Page indexed chunks",
    "doc_rag_noChunks": "No indexed chunks",
    "doc_rag_loadChunks": "Load chunks",
    "doc_rag_indexMgmt": "Index Management",
    "doc_rag_reindexAll": "Rebuild all indexes",
    "doc_rag_reindexPage": "Rebuild current page index",
    "doc_rag_queryFailFmt": "Query failed: %@",
    "doc_search_placeholder": "Search documents...",
    "doc_search_type": "Type",
    "doc_search_typeAll": "All",
    "doc_search_typePage": "Page",
    "doc_search_typeBook": "Book",
    "doc_search_sort": "Sort",
    "doc_search_sortRelevance": "Relevance",
    "doc_search_sortDate": "Date",
    "doc_search_sortTitle": "Title",
    "doc_search_resultFmt": "%d results",
    "doc_search_hintKeyword": "Enter keywords to search documents",
    "doc_search_noResult": "No search results",
    "doc_tpl_newTitle": "New Template",
    "doc_tpl_name": "Name",
    "doc_tpl_typeHint": "Type (report/letter/...)",
    "doc_tpl_category": "Category",
    "doc_tpl_create": "Create",
    "doc_tpl_title": "Templates",
    "doc_tpl_newHelp": "New template",
    "doc_tpl_empty": "No templates yet",
    "doc_tpl_extractVars": "Extract variables",
    "doc_tpl_delete": "Delete template",
    "doc_tpl_content": "Template content",
    "doc_tpl_variables": "Template variables",
    "doc_tpl_inputVarFmt": "Enter %@",
    "doc_tpl_useCreate": "Create from template",
    "doc_tpl_selDetail": "Select a template to view details",
    "doc_ver_title": "Version History",
    "doc_ver_snapshot": "Snapshot",
    "doc_ver_snapshotHelp": "Create version snapshot",
    "doc_ver_compare": "Compare",
    "doc_ver_compareHelp": "Compare selected versions",
    "doc_ver_empty": "No version history yet",
    "doc_ver_versionFmt": "Version %d",
    "doc_ver_setV1": "Set as V1 (old)",
    "doc_ver_setV2": "Set as V2 (new)",
    "doc_ver_restore": "Restore this version",
    "doc_ver_compareTitle": "Version Comparison",
    "doc_ver_diffFmt": "V%d → V%d",
    "doc_office_fmtDocx": "Word Document",
    "doc_office_fmtXlsx": "Excel Spreadsheet",
    "doc_office_fmtPptx": "PowerPoint Presentation",
    "doc_office_title": "Office Control",
    "doc_office_cliStatus": "OfficeCLI Status",
    "doc_office_versionFmt": "Version: %@",
    "doc_office_formatsFmt": "Supported formats: %@",
    "doc_office_detecting": "Detecting...",
    "doc_office_create": "Create Document",
    "doc_office_filename": "Filename",
    "doc_office_createBtn": "Create",
    "doc_office_import": "Import Document",
    "doc_office_filePath": "File path",
    "doc_office_importBtn": "Import",
    "doc_office_export": "Export Page",
    "doc_office_pageId": "Page ID",
    "doc_office_format": "Format",
    "doc_office_exportBtn": "Export",
    "doc_office_merge": "Template Merge",
    "doc_office_templateName": "Template name",
    "doc_office_dataJson": "Data JSON",
    "doc_office_mergeBtn": "Merge",
    "doc_office_cmdTitle": "Office Command",
    "doc_office_cmdFile": "File",
    "doc_office_cmdAction": "Command",
    "doc_office_executeBtn": "Execute",
    "doc_office_importDir": "Batch Import Directory",
    "doc_office_dirPath": "Directory path",
    "doc_wf_newTitle": "New Workflow",
    "doc_wf_name": "Name",
    "doc_wf_desc": "Description",
    "doc_wf_create": "Create",
    "doc_wf_title": "Workflows",
    "doc_wf_newHelp": "New",
    "doc_wf_seedHelp": "Seed workflows",
    "doc_wf_empty": "No workflows yet",
    "doc_wf_delete": "Delete workflow",
    "doc_wf_yamlDef": "YAML Definition",
    "doc_wf_runInput": "Run Input",
    "doc_wf_runBtn": "Run Workflow",
    "doc_wf_runHistory": "Run History",
    "doc_wf_selDetail": "Select a workflow to view details",
    "doc_wf_transitionTitle": "Page State Transition",
    "doc_wf_queryBtn": "Query",
    "doc_wf_currentStateFmt": "Current state: %@",
    "doc_wf_executeBtn": "Execute",
    "proj_subtitle": "Manage your AI projects, instructions and knowledge base",
    "proj_searchPh": "Search projects",
    "proj_newHelp": "New project",
    "proj_archivedFmt": "Archived (%d)",
    "proj_fileCountFmt": "%d files",
    "proj_chatCountFmt": "%d chats",
    "proj_archivedSuffix": " (Archived)",
    "proj_unarchiveBtn": "Unarchive",
    "proj_upstreamBanner": "Some services unavailable",
    "proj_emptyDetail": "Select a project to view details",
    "proj_loadFailFmt": "Load failed: %@",
    "proj_deleteFailFmt": "Delete failed: %@",
    "proj_minAgoFmt": "%dm ago",
    "proj_hourAgoFmt": "%dh ago",
    "proj_dayAgoFmt": "%dd ago",
    "proj_sortLastUpdated": "Last Updated",
    "proj_sortDateCreated": "Date Created",
    "proj_sortAlphabetical": "Alphabetical",
    "proj_menuUnstar": "Unstar",
    "proj_menuStar": "Star project",
    "proj_menuRename": "Rename",
    "proj_menuDuplicate": "Duplicate project",
    "proj_menuExport": "Export project",
    "proj_menuArchive": "Archive project",
    "proj_menuDelete": "Delete project",
    "proj_menuSettings": "Project settings",
    "proj_deleteAlertTitle": "⚠️ Delete project",
    "proj_deleteConfirm": "Confirm delete",
    "proj_deleteAlertMsgFmt": "Are you sure you want to permanently delete project \"%@\"? This cannot be undone.",
    "proj_deleteAlertMsgFullFmt": "Permanently delete project \"%@\"?\n· Project instructions and all version snapshots\n· All knowledge files (%d files)\n· All chats (%d chats)\nThis cannot be undone.",
    "proj_renameTitle": "Rename project",
    "proj_namePh": "Project name",
    "proj_createTitle": "Create New Project",
    "proj_createNameLabel": "Project name *",
    "proj_createDescLabel": "Description",
    "proj_createDescPh": "Description (optional)",
    "proj_createInstructions": "Project instructions",
    "proj_createCharCountFmt": "Chars: %d/%d",
    "proj_createInstructionsHint": "Define roles, output specs, business constraints here. All chats inherit them.",
    "proj_createDefaultAgent": "Default agent",
    "proj_createNoAgent": "None (pure model chat)",
    "proj_createNoAgentShort": "None",
    "proj_createGotoAgentStudio": "Go to Agent Studio to create a new agent",
    "proj_createPromptMerge": "Prompt merge strategy",
    "proj_createMergeAgentFirst": "Agent Prompt first (recommended)",
    "proj_createMergeProjectOnly": "Use project instructions only",
    "proj_createRagMode": "RAG retrieval mode",
    "proj_createRagAuto": "AUTO (smart retrieval)",
    "proj_createRagManual": "MANUAL (manual)",
    "proj_createRagOff": "OFF (disabled)",
    "proj_createBtn": "Create Project",
    "proj_editModeMarkdown": "Markdown",
    "proj_editModeRichText": "Rich text",
    "proj_dupTitle": "Duplicate Project",
    "proj_dupNameLabel": "New project name",
    "proj_dupCopySuffix": " (Copy)",
    "proj_dupScope": "Duplicate scope",
    "proj_dupScopeInstructionsOnly": "Instructions + knowledge files only (recommended)",
    "proj_dupScopeWithSnapshots": "Instructions + knowledge + all chat snapshots",
    "proj_dupBtn": "Duplicate",
    "proj_detailArchived": "Archived",
    "proj_detailImportCowork": "Import CoWork",
    "proj_tabInstructions": "Instructions",
    "proj_tabKnowledge": "Knowledge",
    "proj_tabChats": "Chats",
    "proj_instTitle": "Project instructions",
    "proj_instEmpty": "No project instructions",
    "proj_instEmptyHint": "Click edit to add instructions. All chats inherit them.",
    "proj_instHistoryTitle": "📋 Instructions version history",
    "proj_instHistoryEmpty": "No version history",
    "proj_instHistoryCurrentFmt": "V%d",
    "proj_instHistoryCurrentTag": " (current)",
    "proj_instHistoryRestore": "Restore",
    "proj_kbTitle": "Knowledge base",
    "proj_kbFileCountFmt": "%d files",
    "proj_kbFolder": "Folder",
    "proj_kbAddFile": "Add file",
    "proj_kbEmpty": "No knowledge files",
    "proj_kbEmptyHint": "Upload documents to help AI understand your project",
    "proj_kbNewFolderAlert": "New folder",
    "proj_kbFolderNamePh": "Folder name",
    "proj_kbCreate": "Create",
    "proj_kbStatusIndexed": "Indexed",
    "proj_kbStatusIndexing": "Indexing",
    "proj_kbStatusFailed": "Parse failed",
    "proj_kbStatusPending": "Pending",
    "proj_kbMenuPreview": "Preview",
    "proj_kbMenuRename": "Rename",
    "proj_kbMenuReplace": "Replace file",
    "proj_kbMenuMove": "Move to folder...",
    "proj_kbMenuRemove": "Remove from knowledge",
    "proj_chatsTitle": "Chats",
    "proj_chatsSnapshots": "Snapshots",
    "proj_chatsSnapMsgCountFmt": "%d messages",
    "proj_chatsEmpty": "Select or create a chat",
    "proj_chatsHint": "Notice",
    "proj_chatsCreateFailFmt": "Failed to create chat: %@\nEnsure fusion-projects service is running.",
    "proj_chatsSendFailFmt": "Send failed: %@",
    "proj_chatsNoModel": "No chat model selected. Pick one in the top model picker before sending.",
    "proj_chatsReplyFailFmt": "AI reply failed: %@",
    "proj_ragSources": "Sources: ",
    "proj_ragModeLabelFmt": "Retrieval: %@",
    "proj_ragSwitchAuto": "Switch to AUTO",
    "proj_ragSwitchManual": "Switch to MANUAL",
    "proj_inputUseDefaultAgent": "Use project default agent",
    "proj_inputGenericChat": "Generic chat (no agent)",
    "proj_inputPreviewAgent": "Preview current agent",
    "proj_inputRagLabelFmt": "RAG: %@",
    "proj_inputRagAuto": "AUTO (smart)",
    "proj_inputRagManual": "MANUAL (manual)",
    "proj_inputRagOff": "OFF (off)",
    "proj_inputAttachTemp": "Temporary attachment",
    "proj_inputAttachScreenshot": "Screenshot",
    "proj_inputAttachWebSearch": "WebSearch",
    "proj_inputAttachSkill": "Skill tools",
    "proj_inputPlaceholder": "Type a message…",
    "proj_budgetLow": "⚠️ Budget low",
    "proj_chatMenuUnstar": "Unstar",
    "proj_chatMenuStar": "Star chat",
    "proj_chatMenuRename": "Rename chat",
    "proj_chatMenuFork": "Fork chat",
    "proj_chatMenuSnapshot": "Create snapshot",
    "proj_chatMenuMove": "Move to another project",
    "proj_chatMenuRemove": "Remove from project",
    "proj_chatMenuDelete": "Delete chat",
    "proj_chatDeleteAlertTitle": "Delete chat?",
    "proj_agentConfigTitle": "Agent configuration",
    "proj_agentConfigDefault": "Default agent",
    "proj_agentConfigPromptMerge": "Prompt merge strategy",
    "proj_ragConfigTitle": "RAG configuration",
    "proj_ragConfigMode": "Retrieval mode",
    "proj_ragConfigTopKFmt": "Top-K: %d",
    "proj_ragConfigThresholdFmt": "Similarity threshold: %@",
    "proj_ragConfigSelectScope": "Select retrieval scope",
    "proj_settingsTitleFmt": "⚙️ Project Settings — %@",
    "proj_settingsBasicInfo": "Project info",
    "proj_settingsNameLabel": "Project name",
    "proj_settingsDescLabel": "Description",
    "proj_settingsDescPh": "Description",
    "proj_settingsAgentConfig": "Agent configuration",
    "proj_settingsPromptMerge": "Prompt merge strategy",
    "proj_settingsMergeAgentFirst": "Agent Prompt first (recommended)\nAgent persona + project business rules combined",
    "proj_settingsMergeProjectOnly": "Use project instructions only\nIgnore built-in agent prompt, fully project-customized",
    "proj_settingsRagConfig": "RAG configuration",
    "proj_settingsRagAuto": "AUTO (smart retrieval — like Claude Projects)",
    "proj_settingsRagManual": "MANUAL (manual folder/file retrieval)",
    "proj_settingsTopK": "TopK",
    "proj_settingsThreshold": "Similarity threshold",
    "proj_settingsSaveBtn": "Save settings",
    "proj_previewUnbound": "Unbound",
    "proj_previewRole": "Role profile",
    "proj_previewActiveConfig": "Active configuration",
    "proj_previewPromptStrategyFmt": "· Prompt strategy: %@",
    "proj_previewPromptAgentFirst": "Agent first",
    "proj_previewPromptProjectOnly": "Project instructions only",
    "proj_previewRagModeFmt": "· RAG mode: %@ (TopK=%d, threshold=%@)",
    "proj_previewAccessKb": "· Can access this project's knowledge base",
    "proj_previewUnboundHint": "No agent bound. Pure model chat will be used.",
    "proj_previewGotoAgentStudio": "Go to Agent Studio to edit",
    "proj_coworkTitle": "Import to CoWork space",
    "proj_coworkTarget": "Target CoWork space",
    "proj_coworkTargetPlaceholder": "(CoWork space list)",
    "proj_coworkSyncContent": "Sync content",
    "proj_coworkSyncKnowledge": "All knowledge files",
    "proj_coworkSyncSnapshots": "Selected chat snapshots",
    "proj_coworkWarning": "Knowledge files will be copied to CoWork space. Later changes won't auto-sync.",
    "proj_coworkConfirm": "Confirm import",
    "proj_ragScopeTitle": "🔍 Retrieval scope settings",
    "proj_ragScopeMode": "Retrieval mode",
    "proj_ragScopeAuto": "AUTO (smart global retrieval)",
    "proj_ragScopeManual": "MANUAL (manual scope)",
    "proj_ragScopeSpecify": "Specify retrieval scope",
    "proj_ragScopeConfirm": "Confirm",
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

    "hub_rpmMustPositive": "⚠️ RPM は > 0 である必要があります",
    "hub_concurrencyMustPositive": "⚠️ 同時実行数は > 0 である必要があります",
    "hub_idleTooLowWarn": "⚠️ 5分未満は頻繁なロード/アンロードを招き応答速度に影響します",
    "hub_nDownloading": "%@ 件ダウンロード中",
    "hub_nActiveDeployments": "%@ 件のアクティブデプロイ",
    "hub_nItems": "%@ 件",
    "hub_nModels": "%@ 件",
    "hub_nRoles": "%@ ロール",
    "hub_nReplicas": "%@ レプリカ",
    "hub_apiKeyCreated": "API Key 作成済み",
    "hub_apiKeysTitle": "APIキー",
    "hub_apiKeysAndModelPerms": "APIキーとモデル権限",
    "hub_apiThrottleConfig": "APIレート制限設定",
    "hub_gbMemory": "GB メモリ",
    "hub_kvCacheOpt": "KV-Cache最適化",
    "hub_qpsLimitZero": "QPS制限 (0=無制限)",
    "hub_rpmDefault": "RPM: %@ (デフォルト)",
    "hub_ttlConfigNote": "TTL設定の説明",
    "hub_ttlServeParamNote": "TTLはモデルサービス デプロイ時に指定 (serve API の ttl_seconds パラメータ)",
    "hub_securityScore": "セキュリティスコア",
    "hub_securityScan": "セキュリティスキャン",
    "hub_perModelSettings": "モデル別設定",
    "hub_autoBenchAfterVersion": "バージョン更新後に自動ベンチマーク",
    "hub_saveBtn": "保存",
    "hub_localResourceClusterHint": "ローカルリソース不足時、クラスタの空き Mac に自動割当てし推論実行",
    "hub_editRole": "ロール編集",
    "hub_editPermission": "権限編集",
    "hub_editPermissionModel": "権限編集 — %@",
    "hub_concurrencyVal": "同時実行: %@",
    "hub_concurrencyDefault": "同時実行: %@ (デフォルト)",
    "hub_deployMetrics": "デプロイ指標",
    "hub_auditLog": "操作ログ",
    "hub_testModelCount": "テストモデル数",
    "hub_testStatus": "テストステータス",
    "hub_pinnedNoTTLNote": "常駐モデル (pinned) はTTL制限を受けず常にメモリに保持",
    "hub_pinnedWhitelist": "常駐メモリホワイトリスト",
    "hub_heldFlat": "横ばい",
    "hub_createBtn": "作成",
    "hub_createApiKey": "APIキー作成",
    "hub_createKey": "キー作成",
    "hub_createdAt": "作成日時 %@",
    "hub_disk": "ディスク",
    "hub_storageDetail": "ストレージ詳細",
    "hub_pendingApproval": "承認待ち",
    "hub_perModelThrottle": "モデル別レート制限",
    "hub_noActiveModels": "アクティブモデルなし",
    "hub_exportCsv": "CSVエクスポート",
    "hub_waiting": "待機中",
    "hub_benchThresholdWarn": "閾値未満のベンチマーク結果は警告表示されます",
    "hub_scheduledBenchNote": "定期テストは毎日午前3:00または毎週月曜午前3:00に自動実行",
    "hub_scheduledBenchmark": "定期ベンチマーク",
    "hub_compare": "比較",
    "hub_compareQuantResults": "量子化結果を比較",
    "hub_benchCompareHint": "モデル推論性能を比較: Tokens/s, 初回Token遅延, ピークメモリ",
    "hub_compareSelectedN": "選択を比較 (%@)",
    "hub_layeredQuantHint": "異なる層に異なる量子化戦略を適用し精度と速度をバランス",
    "hub_encryptModelWeights": "モデル重みを暗号化保護",
    "hub_multiNodeSyncHint": "マルチノードはモデルファイルを1回ダウンロードするだけで自動増分同期",
    "hub_issuesFound": "問題を発見",
    "hub_idleUnloadHint": "分でモデルをアンロードしユニファイドメモリを解放",
    "hub_peakMemory": "ピークメモリ",
    "hub_copyAndClose": "コピーして閉じる",
    "hub_formatBitsMem": "形式: %@ | %@-bit | %@",
    "hub_redBelowThreshold": "赤 = 閾値未満",
    "hub_cache": "キャッシュ",
    "hub_yellowNearThreshold": "黄 = 閾値に接近",
    "hub_canaryPercent": "カナリ %@%%",
    "hub_active": "アクティブ",
    "hub_activeSessions": "アクティブセッション",
    "hub_activeModelCountdown": "アクティブモデル カウントダウン",
    "hub_clusterSchedConfig": "クラスタスケジュール設定",
    "hub_clusterNodeHealth": "クラスタノード ヘルス状態",
    "hub_clusterSharedCache": "クラスタ全体 共有モデルキャッシュ",
    "hub_encryption": "暗号化",
    "hub_encryptionMgmt": "暗号化管理",
    "hub_encryptModel": "モデルを暗号化",
    "hub_loadDetail": "詳細を読み込み中...",
    "hub_loading": "読み込み中...",
    "hub_securityScanTargetHint": "指定モデルのセキュリティ脆弱性をスキャン",
    "hub_reject": "拒否",
    "hub_enableCrossNodeRouting": "クロスノード推論ルーティングを有効化",
    "hub_startLayeredQuantize": "階層別量子化を開始",
    "hub_startQuantize": "量子化を開始",
    "hub_startScan": "スキャン開始",
    "hub_startDownload": "ダウンロード開始",
    "hub_controlModuleModelHint": "各モジュールが使用可能なモデルを制御、権限編集で変更",
    "hub_controlRateConcurrencyHint": "モデルごとにリクエスト速率と同時実行制限を制御し過負荷を防止",
    "hub_quickPresetHint": "シーンに合った量子化プリセットを素早く選択",
    "hub_typeLabel": "タイプ: %@",
    "hub_historyBenchRecords": "ベンチマーク履歴",
    "hub_runBenchmarkNow": "今すぐベンチマークを実行",
    "hub_quantLinkedBench": "量子化連携ベンチマーク",
    "hub_quantPostBench": "量子化後ベースライン",
    "hub_quantizedModel": "量子化モデル",
    "hub_quantizeTask": "量子化タスク",
    "hub_quantTaskBenchResult": "量子化タスク完了後の自動ベンチマーク結果",
    "hub_autoBenchAfterQuantize": "量子化完了後に自動ベンチマーク",
    "hub_quantBits": "量子化ビット数",
    "hub_noRunningQuantTask": "実行中の量子化タスクはありません",
    "hub_autoRefresh10s": "10秒ごとに自動更新",
    "hub_rpmLabel": "1分あたりリクエスト数 (RPM)",
    "hub_rpmLabelColon": "1分あたりリクエスト数 (RPM):",
    "hub_pinnedWhitelistNote": "リスト内のモデルは永続的にメモリに常駐し自動アンロードされない",
    "hub_template": "テンプレート",
    "hub_moduleAccessPerm": "モジュールアクセス権限",
    "hub_model": "モデル",
    "hub_modelTTL": "モデル TTL (生存時間)",
    "hub_modelApprovalOps": "モデル: %@",
    "hub_modelJoined": "モデル: %@",
    "hub_autoBenchAfterQuantOrDownload": "量子化またはダウンロード完了後に自動ベンチマーク実行で性能変化を追跡",
    "hub_autoBenchQuantOrDownloadShort": "量子化完了または新モデルダウンロード完了後に自動ベンチマーク",
    "hub_autoBenchAfterQuantConvert": "量子化変換成功後、自動で性能ベンチマークを実行",
    "hub_autoBenchAfterVersionLoad": "モデル新バージョンロード後、自動で性能ベンチマーク比較を実行",
    "hub_defaultThrottlePolicy": "デフォルトレート制限ポリシー",
    "hub_targetFormat": "ターゲット形式",
    "hub_benchIncludedModels": "テスト対象モデル",
    "hub_memory": "メモリ",
    "hub_benchmark": "ベンチマーク",
    "hub_benchResult": "ベンチマーク結果",
    "hub_benchResultColon": "ベンチマーク結果:",
    "hub_benchType": "ベンチマークタイプ",
    "hub_benchTemplate": "ベンチマークテンプレート",
    "hub_benchModel": "ベンチマークモデル",
    "hub_score": "スコア",
    "hub_scoreWarnThreshold": "スコア警告閾値: %@",
    "hub_evalResult": "評価結果",
    "hub_evaluateQuant": "量子化を評価",
    "hub_enableAutoBenchmark": "自動ベンチマークを有効化",
    "hub_cleanupSystem": "システムクリーンアップ",
    "hub_apiKeyOnceHint": "今すぐコピー — このキーは一度だけ表示されます:\n%@",
    "hub_requestsTotal": "リクエスト: %@",
    "hub_requestsPerMin": "リクエスト/分",
    "hub_selectTenantFirst": "左側のテナントを先に選択してください",
    "hub_pleaseSelect": "選択してください",
    "hub_cancelBtn": "キャンセル",
    "hub_unifiedFusionApp": "全Fusionアプリで統一適用",
    "hub_all": "すべて",
    "hub_globalModelLoadPolicy": "グローバルモデル読み込みポリシー",
    "hub_globalThreshold": "グローバル閾値",
    "hub_permissionSelect": "権限選択",
    "hub_date": "日付",
    "hub_scanModel": "モデルをスキャン",
    "hub_scanModelSecurity": "モデルセキュリティスキャン",
    "hub_scanDuplicates": "重複スキャン",
    "hub_setIdleUnloadCountdown": "モデル自動アンロード カウントダウンを設定、アイドル時間超過でユニファイドメモリ解放",
    "hub_setThreshold": "閾値設定",
    "hub_requester": "申請者: %@",
    "hub_requesterShort": "申請者: %@",
    "hub_approval": "承認",
    "hub_approvalWorkflow": "承認ワークフロー",
    "hub_approvalProcess": "承認プロセス",
    "hub_reviewerWithComment": "承認者: %@%@",
    "hub_approvalDetail": "承認詳細",
    "hub_remainingTime": "残り時間",
    "hub_failed": "失敗",
    "hub_time": "時間",
    "hub_realtimeMonitor": "リアルタイムモニター",
    "hub_firstToken": "初回Token",
    "hub_firstTokenSec": "初回Token(s)",
    "hub_firstTokenLatency": "初回Token遅延",
    "hub_refresh": "更新",
    "hub_watermarkMgmt": "透かし管理",
    "hub_add": "追加",
    "hub_addWatermark": "透かし追加",
    "hub_deactivate": "無効化",
    "hub_approve": "承認",
    "hub_general2": "一般",
    "hub_done": "完了",
    "hub_completionTime": "完了時間",
    "hub_addDigitalWatermarkHint": "モデルにデジタル透かしを追加し知的財産を保護",
    "hub_unconfiguredUsesDefault": "個別設定のないモデルはデフォルトポリシーを使用",
    "hub_noSecurityIssues": "セキュリティ問題は見つかりませんでした",
    "hub_noClusterNodes": "クラスタノードは検出されませんでした",
    "hub_noModelWillTestAll": "モデル未選択 — 全ダウンロード済みモデルをテスト",
    "hub_issueSummary": "問題サマリー",
    "hub_none": "なし",
    "hub_noPermissionConfig": "権限設定なし",
    "hub_downloadLabel": "ダウンロード: %@",
    "hub_downloadTask": "ダウンロードタスク",
    "hub_downloadNewModel": "新規モデルダウンロード",
    "hub_idle": "アイドル",
    "hub_idleAfterTTLUnload": "アイドル時間がTTLを超えるとモデルは自動的にメモリからアンロードされGPUユニファイドメモリを解放",
    "hub_idleAutoReclaim": "アイドル自動回収",
    "hub_auditLogFirstN": "先頭30件を表示、全 %@ 件",
    "hub_throttleConfigModel": "レート制限設定 — %@",
    "hub_newRole": "新規ロール",
    "hub_newBenchmark": "新規ベンチマーク",
    "hub_newDownload": "新規ダウンロード",
    "hub_newTenant": "新規テナント",
    "hub_performanceBenchmark": "性能ベンチマーク",
    "hub_selectBenchModels": "ベンチマークモデルを選択",
    "hub_selectModel": "モデルを選択",
    "hub_selectModelPlaceholder": "モデルを選択...",
    "hub_selectBenchModel": "ベンチマークモデルを選択",
    "hub_latencyMs": "遅延(ms)",
    "hub_rejected": "拒否済み",
    "hub_configuredTTLModels": "TTL設定済みモデル",
    "hub_deactivated": "無効化済み",
    "hub_approved": "承認済み",
    "hub_selectedNModelsLoading": "選択済み %@ モデル (読み込み中...)",
    "hub_hardwareInfo": "ハードウェア情報",
    "hub_permanentResidentNoTTL": "永続常駐 (TTLなし)",
    "hub_estimatedReduction": "推定削減",
    "hub_presetScheme": "プリセット方案",
    "hub_originalVsQuant": "オリジナル vs 量子化比較",
    "hub_originalModel": "オリジナルモデル",
    "hub_allowedModulesHint": "許可モジュール（空=すべて）",
    "hub_allowedModelsHint": "許可モデル（空=すべて）",
    "hub_runningColon": "稼働: %@",
    "hub_runBenchmark": "ベンチマーク実行",
    "hub_running": "実行中",
    "hub_noApiKey": "APIキーなし",
    "hub_noAuditLogs": "操作ログなし",
    "hub_noPinnedModels": "常駐モデルなし",
    "hub_noActiveDeployments": "アクティブデプロイなし",
    "hub_noRoles": "ロールなし",
    "hub_noHistory": "履歴なし",
    "hub_noQuantLinkedBench": "量子化連携ベンチマークデータなし",
    "hub_noModels": "モデルなし",
    "hub_noModelData": "モデルデータなし",
    "hub_noBenchRecords": "ベンチマーク記録なし",
    "hub_noBenchData": "ベンチマークデータなし — モデルを選択して実行",
    "hub_noApprovalRequests": "承認リクエストなし",
    "hub_noInferenceData": "推論データなし",
    "hub_noDownloadTasks": "ダウンロードタスクなし",
    "hub_noDownloadedModels": "ダウンロード済みモデルなし",
    "hub_noTenants": "テナントなし",
    "hub_executionFrequency": "実行頻度",
    "hub_qualityChange": "品質変化: %@",
    "hub_qualityScore": "品質スコア",
    "hub_reset": "リセット",
    "hub_attentionQuant": "アテンション層量子化",
    "hub_convertQuantize": "変換 & 量子化",
    "hub_status": "ステータス",
    "hub_statusApproval": "ステータス: %@",
    "hub_accuracy": "正解率",
    "hub_accuracyVal": "正解率: %@",
    "hub_accuracyWarnThreshold": "正解率警告閾値: %@",
    "hub_accuracyThresholdSettings": "正解率閾値設定",
    "hub_custom": "カスタム",
    "hub_autoTest": "自動テスト",
    "hub_autoBenchmark": "自動ベンチマーク",
    "hub_autoBenchRules": "自動ベンチマークルール",
    "hub_autoBenchTemplateLabel": "自動ベンチマークテンプレート:",
    "hub_tenant": "テナント",
    "hub_tenantsAndRoles": "テナントとロール",
    "hub_maxConcurrency": "最大同時実行数",
    "hub_maxConcurrencyColon": "最大同時実行数:",
    "hub_expired": "期限切れ",
    "hub_unknownIssue": "未知の問題",
    "hub_notYetScanned": "セキュリティスキャン未実施",
    "hub_noWatermarkInfo": "透かし情報なし",
    "hub_noEncryptionInfo": "暗号化情報なし",
    "hub_noApprovalRecords": "承認記録なし",
    "hub_modelId": "モデルID",
    "hub_watermarkStatus": "透かしステータス",
    "hub_watermarkId": "透かしID",
    "hub_verifyStatus": "検証ステータス",
    "hub_verified": "検証済み",
    "hub_notVerified": "未検証",
    "hub_embeddedTime": "埋め込み時間",
    "hub_encryptionStatus": "暗号化ステータス",
    "hub_encryptionAlgorithm": "暗号化アルゴリズム",
    "hub_encryptionTime": "暗号化時間",
    "hub_watermarkText": "透かしテキスト",
    "hub_addBtn": "追加",
    "hub_encryptBtn": "暗号化",
    "hub_modelIdPlaceholder": "モデル ID",
    "hub_downloadUrlPlaceholder": "ダウンロードURL (https://...)",
    "hub_downloadSched": "ダウンロードスケジュール",
    "hub_computeSchedPolicy": "コンピュートスケジュールポリシー",
    "hub_modulePermission": "モジュール権限",
    "hub_apiThrottle": "APIレート制限",
    "hub_modelTTLTab": "モデル TTL",
    "hub_autoBenchmarkTab": "自動ベンチマーク",
    "hub_policyAuto": "スマート自動スケジュール",
    "hub_policyAutoDesc": "リクエストに基づき自動ロード/アンロード（推奨）",
    "hub_policyPinned": "手動常駐",
    "hub_policyPinnedDesc": "モデルはメモリに常駐、自動アンロードなし",
    "hub_policyOnDemand": "使用後即時アンロード",
    "hub_policyOnDemandDesc": "各リクエスト後に即時アンロード、最もメモリ節約",
    "hub_idlePrefix": "アイドル",
    "hub_editPermissionBtn": "権限編集",
    "hub_edit": "編集",
    "hub_daily": "毎日",
    "hub_weekly": "毎週",
    "hub_monthly": "毎月",
    "hub_enabled": "有効",
    "hub_notEnabled": "無効",
    "hub_benchmarkStarted": "ベンチマーク開始 — 後で結果を確認",
    "hub_evalTaskCreated": "評価タスクを作成しました",
    "hub_quantizeStarted": "量子化タスクを開始しました",
    "hub_layeredQuantizeStarted": "階層別量子化タスクを開始しました",
    "hub_assessFailed": "評価失敗: %@",
    "hub_layeredQuantFailed": "階層別量子化失敗: %@",
    "hub_compareFailed": "比較失敗: %@",
    "hub_evalStartedForModel": "%@ のベンチマークを開始",
    "hub_evalFailed": "ベンチマーク失敗: %@",
    "hub_templateGeneral": "一般",
    "hub_templateCode": "コード",
    "hub_templateReasoning": "推論",
    "hub_templateMultilingual": "多言語",
    "hub_templateVision": "ビジョン",
    "hub_evalTypeAccuracy": "正解率",
    "hub_evalTypeAlignment": "アライメント",
    "hub_evalTypeSafety": "安全性",
    "hub_evalTypeCode": "コード能力",
    "hub_evalTypeReasoning": "推論能力",
    "hub_evalTypeGeneral": "一般",
    "hub_evalTypeComprehensive": "総合評価",
    "hub_unknown": "不明",
    "hub_unknownModel": "不明なモデル",
    "hub_operationDeploy": "デプロイ",
    "hub_operationDelete": "削除",
    "hub_operationQuantize": "量子化",
    "hub_operationExport": "エクスポート",
    "hub_operationServe": "オンライン",
    "hub_operationDownload": "ダウンロード",
    "hub_operation": "操作",
    "hub_allSources": "すべてのソース",
    "hub_sourceLocal": "ローカル",
    "hub_sourceHub": "Hub",
    "hub_sourceCustom": "カスタム",
    "hub_source": "ソース",
    "hub_health_healthy": "健康",
    "hub_health_warning": "警告/劣化",
    "hub_health_error": "エラー/過負荷",
    "hub_chip": "チップ",
    "hub_cpuCores": "CPUコア",
    "hub_gpuCores": "GPUコア",
    "hub_available": "利用可能",
    "hub_supported": "サポート",
    "hub_neCores": "NEコア",
    "hub_modelName": "モデル名",
    "hub_modelInferenceStats": "モデル推論統計",
    "hub_noDownloadTasksShort": "ダウンロードタスクなし",
    "hub_selectTenantViewRoles": "テナントを選択してロールを表示",
    "hub_roleList": "ロール一覧",
    "hub_keyName": "キー名",
    "hub_tenantName": "テナント名",
    "hub_defaultRole": "デフォルトロール",
    "hub_roleName": "ロール名",
    "hub_approvalCommentOptional": "承認コメント（任意）",
    "hub_approvalComment": "承認コメント",
    "hub_roleAdmin": "管理者",
    "hub_roleMember": "メンバー",
    "hub_roleGuest": "ゲスト",
    "hub_roleAdminCaps": "全モデル + 全モジュール + キー管理 + システム設定",
    "hub_roleMemberCaps": "指定モデル + 標準モジュール + システム設定なし",
    "hub_roleGuestCaps": "制限モデル + チャットのみ + 速度制限",
    "hub_copyAndClose2": "コピーして閉じる",
    "hub_presetChatLabel": "チャットモデル",
    "hub_presetCodeLabel": "コードモデル",
    "hub_presetEmbeddingLabel": "埋め込みモデル",
    "hub_presetRagLabel": "RAGモデル",
    "hub_presetChatMem": "低メモリ",
    "hub_presetCodeMem": "バランス",
    "hub_presetEmbeddingMem": "精度優先",
    "hub_presetRagMem": "推論最適化",
    "hub_presetChatDesc": "4-bit MLX量子化、チャット向け、最低メモリ",
    "hub_presetCodeDesc": "8-bit MLX量子化、コード品質と速度のバランス",
    "hub_presetEmbeddingDesc": "FP16 MLX形式、埋め込み精度保持、検索向け",
    "hub_presetRagDesc": "4-bit GGUF形式、RAG推論最適化、llama.cpp互換",
    "hub_scenePreset": "シーンプリセット",
    "hub_quantConfig": "量子化設定",
    "hub_layeredQuantize": "階層別量子化",
    "hub_quantCompare": "量子化比較",
    "hub_qualityLabel": "品質: %.0f%%",
    "hub_speedLabel": "速度: %.1f tok/s",
    "hub_memoryLabelFmt": "メモリ: %.1f GB",
    "hub_firstTokenFmt": "初回Token: %.2fs",
    "hub_accuracyFmt": "正解率: %.1f%%",
    "hub_benchResultPrefix": "ベンチマーク結果:",
    "hub_accuracyPrefix": "正解率 %.1f%%",
    "hub_firstTokenPrefix": "初回Token %.2fs",
    "hub_memoryPrefix": "メモリ %.1f GB",
    "hub_perTokenLatency": "Tokenごと遅延",
    "hub_firstTokenLatencyLabel": "初回Token遅延",
    "hub_prefillLatency": "Prefill遅延",
    "hub_decodeLatency": "Decode遅延",
    "hub_throughputBatch1": "Batch=1 スループット",
    "hub_throughputBatch2": "Batch=2 スループット",
    "hub_throughputBatch4": "Batch=4 スループット",
    "hub_throughputBatch8": "Batch=8 スループット",
    "hub_memoryFootprint": "メモリ使用量",
    "hub_usedStorageFmt": "使用済み %.1f / %.1f GB (%.0f%%)",
    "hub_tokensPerSecCol": "Tokens/s",
    "hub_accuracyCol": "正解率",
    "hub_scoreCol": "スコア",
    "hub_compareCol": "比較",
    "hub_templateCol": "テンプレート",
    "hub_deployment": "デプロイ",
    "hub_newEval": "新規評価",
    "hub_quantColon": "量子化: %@",
    "hub_dlColon": "ダウンロード: %@",
    "hub_modelColon": "モデル: %@",
    "hub_modelColonJoined": "モデル: %@",
    "hub_requesterColon": "申請者: %@",
    "hub_reviewerColonComment": "承認者: %@%@",
    "hub_statusColon": "ステータス: %@",
    "hub_typeColon": "タイプ: %@",
    "hub_showingFirstN": "先頭30件表示、全 %@ 件",
    "hub_nReplicasFmt": "%@ レプリカ",
    "hub_canaryFmt": "カナリ %@%%",
    "hub_nActiveDeploymentsFmt": "%@ 件のアクティブデプロイ",
    "hub_nDownloadingFmt": "%@ 件ダウンロード中",
    "hub_nRolesFmt": "%@ ロール",
    "hub_nItemsFmt": "%@ 件",
    "hub_sevCritical": "重大", "hub_sevHigh": "高", "hub_sevMedium": "中", "hub_sevLow": "低",
    "hub_latencyLabel": "遅延", "hub_errorRate": "エラー率", "hub_grayCanary": "カナリ %@%",
    "hub_quantLabel": "量子化: %@", "hub_runningLabel": "稼働: %@", "hub_activeDeploymentsFmt": "%d 件のアクティブデプロイ",
    "hub_countItemsFmt": "%d 件", "hub_copiesFmt": "%d レプリカ", "hub_auditShowingFmt": "上位30件 / 全%d件",
    "hub_modelSizeFmt": "モデル: %.1f GB", "hub_csvHeader": "ID,時間,操作,来源,リソース,ユーザー,詳細\n",
    "hub_roleCountFmt": "%d ロール", "hub_createdAtFmt": "作成 %@", "hub_modelsPermListFmt": "モデル: %@",
    "hub_modelPermissions": "モデル権限", "hub_apiKeyCopyOnceWarn": "今すぐコピー — このキーは一度しか表示されません:\n%@",
    "hub_requestsTotalFmt": "リクエスト: %d", "hub_reviewerCommentFmt": "承認者: %@%@",
    "hub_compareSelectedFmt": "選択を比較 (%d)", "hub_modelBenchmark": "モデルベンチマーク",
    "hub_scoreWarnThresholdFmt": "スコア警告しきい値: %@", "hub_accuracyFmt2": "正確率: %@",
    "hub_accuracyWarnThresholdFmt": "正確率警告しきい値: %@", "hub_activeDownloadsFmt": "%d 件ダウンロード中",
    "hub_durationHMSFmt": "%@時間%@分%@秒", "hub_durationMSFmt": "%@分%@秒", "hub_durationSFmt": "%@秒",
    "hub_durationZero": "0秒", "hub_rpmDefaultFmt": "RPM: %d (デフォルト)", "hub_editPermTitleFmt": "権限編集 — %@",
    "hub_concurrencyFmt": "同時実行: %d", "hub_concurrencyDefaultFmt": "同時実行: %d (デフォルト)",
    "hub_throttleConfigTitleFmt": "スロットル設定 — %@", "hub_selectedModelsLoadingFmt": "%d件のモデル選択 (読込中...)",
    "hub_ls_catAll": "すべて", "hub_ls_catChat": "汎用対話", "hub_ls_catCode": "コード", "hub_ls_catEmbed": "埋め込み", "hub_ls_catVision": "画像マルチモーダル", "hub_ls_catPrivate": "プライベート", "hub_ls_catPinned": "固定済み", "hub_ls_catServing": "推論中", "hub_ls_catLLM": "言語モデル", "hub_ls_catVLM": "ビジョンモデル", "hub_ls_catEmbedM": "埋め込みモデル", "hub_ls_catCodeM": "コードモデル", "hub_ls_catAudioM": "音声モデル", "hub_ls_catMLX": "MLX形式", "hub_ls_catGGUF": "GGUF形式", "hub_ls_category": "カテゴリ", "hub_ls_searchPlaceholder": "ローカルモデルを検索...", "hub_ls_batchMode": "バッチモード", "hub_ls_selectedCountFmt": "%d件選択", "hub_ls_selectAll": "すべて選択", "hub_ls_batchDelete": "一括削除", "hub_ls_batchQuantize": "一括量子化", "hub_ls_syncCluster": "クラスタへ同期", "hub_ls_exportPath": "エクスポートパス", "hub_ls_currentUse": "使用中", "hub_ls_serving": "推論中", "hub_ls_compatFormats": "互換形式:", "hub_ls_unpin": "固定解除", "hub_ls_pin": "固定", "hub_ls_stopServe": "停止", "hub_ls_startServe": "開始", "hub_ls_basicInfo": "基本情報", "hub_ls_path": "パス", "hub_ls_source": "ソース", "hub_ls_engine": "エンジン", "hub_ls_license": "ライセンス", "hub_ls_allowedModules": "許可モジュール", "hub_ls_selectModelHint": "モデルを選択して詳細表示", "hub_ls_versionMgmt": "バージョン管理", "hub_ls_versionList": "バージョン一覧", "hub_ls_noVersions": "バージョン情報なし", "hub_ls_rollback": "ロールバック", "hub_ls_publish": "公開", "hub_ls_deprecate": "廃止", "hub_ls_retire": "提供終了", "hub_ls_resident": "常駐", "hub_ls_batchQuantTitle": "一括量子化", "hub_ls_batchQuantHintFmt": "%d個のモデルを量子化します", "hub_ls_targetFormat": "対象形式", "hub_ls_quantBits": "量子化ビット", "hub_ls_startQuantize": "量子化開始", "hub_ls_batchQuantFailFmt": "一括量子化失敗: %@", "hub_ls_rollbackFailFmt": "バージョン戻し失敗: %@", "hub_ls_syncFailFmt": "クラスタ同期失敗: %@", "hub_ls_startServeFailFmt": "推論開始失敗: %@", "hub_ls_stopServeFailFmt": "推論停止失敗: %@", "hub_ls_publishFailFmt": "バージョン公開失敗: %@", "hub_ls_deprecateFailFmt": "バージョン廃止失敗: %@", "hub_ls_retireFailFmt": "バージョン提供終了失敗: %@",
    "hub_cls_nodes": "クラスタノード", "hub_cls_onlineFmt": "%d/%d オンライン", "hub_cls_syncModel": "モデル同期", "hub_cls_noNodes": "クラスタノードなし", "hub_cls_noNodesHint": "同じネットワークでModel Hubサービスを起動してください", "hub_cls_selectNodeHint": "ノードを選択して詳細表示", "hub_cls_nodeInfo": "ノード情報", "hub_cls_addr": "アドレス", "hub_cls_lastSeen": "最終オンライン", "hub_cls_resourceUsage": "リソース使用量", "hub_cls_memory": "メモリ", "hub_cls_localModelsFmt": "ローカルモデル (%d)", "hub_cls_autoSchedule": "自動スケジュール推論", "hub_cls_localFirst": "ローカル優先、クラスタフォールバック", "hub_cls_model": "モデル", "hub_cls_selectModelHint": "モデルを選択...", "hub_cls_routeMode": "ルーティングモード", "hub_cls_promptPlaceholder": "推論プロンプトを入力...", "hub_cls_sendInfer": "推論リクエスト送信", "hub_cls_inferResult": "推論結果", "hub_cls_routedTo": "ルーティング先:", "hub_cls_resultHint": "推論リクエスト送信後に結果表示", "hub_cls_syncToCluster": "クラスタへモデル同期", "hub_cls_syncHint": "すべてのオンラインクラスタノードへモデルファイルを同期", "hub_cls_startSync": "同期開始", "hub_cls_modeAuto": "自動", "hub_cls_modeLocal": "ローカル優先", "hub_cls_modeCluster": "クラスタ",
    "hub_dash_mlxEngine": "MLX推論エンジン", "hub_dash_clusterMode": "クラスタモード", "hub_dash_modelService": "モデルサービス", "hub_dash_localModels": "ローカルモデル", "hub_dash_activeModels": "アクティブモデル", "hub_dash_downloading": "ダウンロード中", "hub_dash_totalStorage": "総ストレージ", "hub_dash_pinned": "固定", "hub_dash_quantizing": "量子化中", "hub_dash_clusterNodes": "クラスタノード", "hub_dash_totalModels": "モデル総数", "hub_dash_quickActions": "クイック操作", "hub_dash_searchMarket": "市場検索", "hub_dash_downloadModel": "モデルダウンロード", "hub_dash_quantizeModel": "モデル量子化", "hub_dash_systemClean": "システムクリーンアップ", "hub_dash_recentModels": "最近のモデル", "hub_dash_noModels": "モデルなし", "hub_dash_resident": "常駐", "hub_dash_serving": "推論中", "hub_dash_sysOverview": "システム概要", "hub_dash_memory": "メモリ", "hub_dash_disk": "ディスク", "hub_dash_uptime": "稼働時間", "hub_dash_loading": "読込中...",
    "hub_mv_descQwen35": "通義千問 3.5、9Bパラメータ、4bit量子化", "hub_mv_descLlama3": "Meta Llama 3、8Bパラメータ、4bit量子化", "hub_mv_descDeepseek": "DeepSeek コード専用モデル", "hub_mv_descQwenVL": "Qwen2 ビジョン言語モデル", "hub_mv_catAll": "すべて", "hub_mv_searchPlaceholder": "モデルを検索...", "hub_mv_selectModelHint": "モデルを選択して詳細表示", "hub_mv_downloadModel": "モデルダウンロード", "hub_mv_refresh": "更新", "hub_mv_active": "アクティブ", "hub_mv_ready": "準備完了", "hub_mv_notDownloaded": "未ダウンロード", "hub_mv_currentUse": "使用中", "hub_mv_download": "ダウンロード", "hub_mv_activate": "有効化", "hub_mv_downloadingFmt": "ダウンロード中... %d%%", "hub_mv_basicInfo": "基本情報", "hub_mv_modelId": "モデル ID", "hub_mv_path": "パス", "hub_mv_size": "サイズ", "hub_mv_format": "形式", "hub_mv_quant": "量子化", "hub_mv_family": "ファミリ", "hub_mv_params": "パラメータ", "hub_mv_description": "説明", "hub_mv_searchHF": "HuggingFaceモデルを検索...", "hub_mv_search": "検索", "hub_mv_recommended": "おすすめモデル", "hub_mv_repoIdHint": "またはHuggingFace repo IDを直接入力", "hub_mv_hfTokenOptional": "HF Token (任意)",
    "hub_dep_stPending": "待機中",
    "hub_dep_stRunning": "実行中",
    "hub_dep_stStopped": "停止済み",
    "hub_dep_stFailed": "失敗",
    "hub_dep_stUnknown": "不明",
    "hub_dep_management": "デプロイ管理",
    "hub_dep_empty": "デプロイなし",
    "hub_dep_selectHint": "詳細を見るにはデプロイを選択",
    "hub_dep_replicasFmt": "%@ レプリカ",
    "hub_dep_canaryFmt": "カナリア %d%%",
    "hub_dep_config": "設定",
    "hub_dep_model": "モデル",
    "hub_dep_modelName": "モデル名",
    "hub_dep_strategy": "戦略",
    "hub_dep_replicasCount": "レプリカ数",
    "hub_dep_canaryRatio": "カナリア比率",
    "hub_dep_createdAt": "作成日時",
    "hub_dep_updatedAt": "更新日時",
    "hub_dep_metrics": "メトリクス",
    "hub_dep_reqPerSec": "要求/秒",
    "hub_dep_latencyMs": "レイテンシ(ms)",
    "hub_dep_errorRate": "エラー率",
    "hub_dep_refreshMetrics": "メトリクス更新",
    "hub_dep_actions": "操作",
    "hub_dep_stopDep": "停止",
    "hub_dep_scale": "スケール",
    "hub_dep_grayRelease": "カナリアリリース",
    "hub_dep_deleteDep": "削除",
    "hub_dep_stopFailFmt": "停止失敗: %@",
    "hub_dep_scaleFailFmt": "スケール失敗: %@",
    "hub_dep_grayFailFmt": "カナリアリリース失敗: %@",
    "hub_dep_deleteFailFmt": "削除失敗: %@",
    "hub_dep_metricsFailFmt": "メトリクス取得失敗: %@",
    "hub_dep_createDep": "デプロイ作成",
    "hub_dep_modelId": "モデルID",
    "hub_dep_depStrategy": "デプロイ戦略",
    "hub_dep_replicasStepperFmt": "レプリカ数: %d",
    "hub_dep_canaryStepperFmt": "カナリア比率: %d%%", "hub_cls_modelCountFmt": "%d モデル",
    "hub_mkt_searchPlaceholder": "モデルを検索...",
    "hub_mkt_sourceAll": "すべてのソース",
    "hub_mkt_sourceLocal": "ローカル",
    "hub_mkt_sourcePrivate": "プライベートリポジトリ",
    "hub_mkt_taskAll": "すべてのタスク",
    "hub_mkt_taskTextGen": "テキスト生成",
    "hub_mkt_taskCode": "コード",
    "hub_mkt_taskVision": "ビジョン",
    "hub_mkt_taskEmbedding": "埋め込み",
    "hub_mkt_taskAudio": "オーディオ",
    "hub_mkt_taskMultimodal": "マルチモーダル",
    "hub_mkt_formatAll": "すべての形式",
    "hub_mkt_paramSizeAll": "すべてのサイズ",
    "hub_mkt_localOnly": "ローカルのみ",
    "hub_mkt_loadMoreFmt": "もっと読み込む (%d/%d)",
    "hub_mkt_emptyTitle": "HuggingFace / ModelScope / プライベートリポジトリを検索",
    "hub_mkt_emptyHint": "マルチソース検索・形式・サイズ・タスク絞り込み",
    "hub_mkt_download": "ダウンロード",
    "hub_mkt_convertMLX": "MLXに変換",
    "hub_mkt_addBenchmark": "ベンチマークに追加",
    "hub_mkt_ragDefault": "RAGデフォルト",
    "hub_mkt_ragDefaultCurrent": "現在のRAGデフォルト埋め込みモデル",
    "hub_mkt_ragDefaultSet": "RAGデフォルト埋め込みモデルに設定",
    "hub_mkt_size": "サイズ",
    "hub_mkt_downloads": "ダウンロード数",
    "hub_mkt_likes": "いいね",
    "hub_mkt_license": "ライセンス",
    "hub_mkt_author": "作者",
    "hub_mkt_selectModelHint": "モデルを選択して詳細表示",
    "hub_mkt_pickerSource": "ソース",
    "hub_mkt_pickerTask": "タスク",
    "hub_mkt_pickerFormat": "形式",
    "hub_mkt_pickerParam": "パラメータ",
    "hub_mkt_downloadFailFmt": "ダウンロード失敗: %@",
    "hub_mkt_mlxFailFmt": "MLX変換ダウンロード失敗: %@",
    "hub_mkt_benchFailFmt": "ベンチマークトリガー失敗: %@",
    "hub_main_secDashboard": "ダッシュボード",
    "hub_main_secMarket": "モデル市場",
    "hub_main_secLocalStorage": "ローカルストレージ",
    "hub_main_secConvertQuant": "変換・量子化",
    "hub_main_secSchedule": "ダウンロードスケジュール",
    "hub_main_secCluster": "クラスタ",
    "hub_main_secDeployment": "デプロイ",
    "hub_main_secPermission": "パーミッション",
    "hub_main_secMonitor": "モニタ",
    "hub_main_secBenchmark": "ベンチマーク",
    "hub_main_secSecurity": "セキュリティ",
    "hub_main_noKeyMsg": "API Key未設定。保護対象エンドポイントは401を返します。パーミッションでKeyを作成してください。",
    "hub_main_goCreate": "作成へ",
    "hub_main_connected": "接続済み",
    "hub_main_disconnected": "未接続",
    "hub_main_serviceNotConnected": "Model Hubサービス未接続",
    "hub_main_serviceHintFmt": "fusion-model-hubサービスが起動しているか確認（ポート %d）",
    "hub_main_retry": "再接続",
    "hub_ver_draft": "ドラフト",
    "hub_ver_testing": "テスト中",
    "hub_ver_published": "公開済み",
    "hub_ver_deprecated": "非推奨",
    "hub_ver_retired": "提供終了",
    "hub_role_admin": "管理者",
    "hub_role_developer": "開発者",
    "hub_role_viewer": "閲覧者",
    "hub_role_custom": "カスタム",
    "hub_lvl_l1": "L1 自動承認",
    "hub_lvl_l2": "L2 管理者承認",
    "hub_lvl_l3": "L3 セキュリティ承認",
    "hub_lvl_unknown": "不明",
    "doc_tab_editor": "エディタ",
    "doc_tab_graph": "ナレッジグラフ",
    "doc_tab_versions": "バージョン履歴",
    "doc_tab_office": "Office",
    "doc_tab_workflow": "ワークフロー",
    "doc_tab_template": "テンプレート",
    "doc_tab_search": "検索",
    "doc_tab_comments": "コメント",
    "doc_tab_favorites": "お気に入り",
    "doc_tab_files": "ファイル",
    "doc_tab_rag": "RAG",
    "doc_tab_activity": "アクティビティ",
    "doc_aiCopilot": "AI Copilot",
    "doc_selPageVersions": "ページを選択してバージョン履歴を表示",
    "doc_auth_title": "Fusion Doc 認証",
    "doc_auth_mode": "モード",
    "doc_auth_login": "ログイン",
    "doc_auth_setup": "初期設定",
    "doc_auth_username": "ユーザー名",
    "doc_auth_password": "パスワード",
    "doc_auth_confirmPwd": "パスワード確認",
    "doc_auth_createAdmin": "管理者作成",
    "doc_auth_authenticated": "認証済み ✓",
    "doc_cmt_title": "コメント",
    "doc_cmt_empty": "コメントはまだありません",
    "doc_cmt_reply": "返信",
    "doc_cmt_replyLabel": "コメントに返信",
    "doc_cmt_replyPlaceholder": "コメントに返信...",
    "doc_cmt_addPlaceholder": "コメントを追加...",
    "doc_cmt_selPage": "ページを選択してコメントを表示",
    "doc_fav_title": "お気に入り",
    "doc_fav_empty": "お気に入りはまだありません",
    "doc_fav_addHint": "ページ内のスターをクリックしてお気に入りに追加",
    "doc_fav_noTitle": "無題",
    "doc_file_title": "添付ファイル",
    "doc_file_countFmt": "%d ファイル",
    "doc_file_empty": "添付ファイルはまだありません",
    "doc_file_unknown": "不明なファイル",
    "doc_file_upload": "添付ファイルをアップロード",
    "doc_file_name": "ファイル名",
    "doc_file_uploadBtn": "アップロード",
    "doc_file_selPage": "ページを選択して添付ファイルを表示",
    "doc_ws_title": "ワークスペース",
    "doc_ws_empty": "ワークスペースはまだありません",
    "doc_ws_createFirst": "最初のワークスペースを作成",
    "doc_ws_name": "名称",
    "doc_ws_descOptional": "説明（任意）",
    "doc_ws_create": "作成",
    "doc_ws_delete": "削除",
    "doc_act_title": "アクティビティログ",
    "doc_act_empty": "アクティビティはまだありません",
    "doc_act_evPageCreate": "📄 ページ作成",
    "doc_act_evPageUpdate": "✏️ ページ更新",
    "doc_act_evPageDelete": "🗑️ ページ削除",
    "doc_act_evCommentCreate": "💬 コメント追加",
    "doc_act_evFavAdd": "⭐ お気に入り追加",
    "doc_act_evFavRemove": "☆ お気に入り解除",
    "doc_act_evVerCreate": "🔖 バージョン作成",
    "doc_act_evWorkflowRun": "🔄 ワークフロー実行",
    "doc_act_evFileUpload": "📎 ファイルアップロード",
    "doc_cp_modeChat": "チャット",
    "doc_cp_modeCommand": "コマンド",
    "doc_cp_modeRag": "ナレッジ",
    "doc_cp_modeRewrite": "書き換え",
    "doc_cp_modeTranslate": "翻訳",
    "doc_cp_modeSummarize": "要約",
    "doc_cp_modeExpand": "拡張",
    "doc_cp_targetLang": "翻訳先言語",
    "doc_cp_clearChat": "チャット消去",
    "doc_cp_thinking": "考え中...",
    "doc_cp_phChat": "メッセージを入力...",
    "doc_cp_phCommand": "/command ...",
    "doc_cp_phRewrite": "書き換え指示を入力...",
    "doc_cp_phTranslateFmt": "%@に翻訳するテキスト入力...",
    "doc_cp_phSummarize": "要約するテキスト入力...",
    "doc_cp_phExpand": "拡張するテキスト入力...",
    "doc_cp_phRag": "ナレッジ検索...",
    "doc_cp_errCopilotURL": "Copilot URL が利用不可",
    "doc_cp_errCommandURL": "Command URL が利用不可",
    "doc_cp_errNoData": "応答データなし",
    "doc_cp_emptyResp": "(空の応答)",
    "doc_cp_ragChunksPrefix": "📚 関連ナレッジ断片：",
    "doc_cp_ragNoResult": "関連する結果なし",
    "doc_cp_rewriteResultPrefix": "✏️ 書き換え結果：",
    "doc_cp_translateResultFmt": "🌐 翻訳結果(%@)：",
    "doc_cp_summarizePrefix": "📋 要約：",
    "doc_cp_expandPrefix": "📖 拡張内容：",
    "doc_cp_noResult": "(結果なし)",
    "doc_cp_errPrefix": "❌ ",
    "doc_graph_title": "ナレッジグラフ",
    "doc_graph_filterAll": "すべて",
    "doc_graph_filterLink": "リンク",
    "doc_graph_filterSemantic": "セマンティック",
    "doc_graph_filterTag": "タグ",
    "doc_graph_searchNode": "ノードを検索...",
    "doc_graph_refreshHelp": "グラフ更新",
    "doc_graph_loading": "グラフを読み込み中...",
    "doc_graph_linkCountFmt": "リンク数: %d",
    "doc_graph_openPage": "ページを開く",
    "doc_graph_empty": "グラフデータはまだありません",
    "doc_graph_emptyHint": "ページ間リンクを作成するとナレッジグラフが自動生成されます",
    "doc_rag_title": "RAG ナレッジ強化",
    "doc_rag_semanticQuery": "セマンティック検索",
    "doc_rag_queryPlaceholder": "検索質問を入力...",
    "doc_rag_answer": "回答",
    "doc_rag_chunksFmt": "関連断片 (%d)",
    "doc_rag_pageChunks": "ページ索引段落",
    "doc_rag_noChunks": "索引段落はまだありません",
    "doc_rag_loadChunks": "段落を読み込む",
    "doc_rag_indexMgmt": "インデックス管理",
    "doc_rag_reindexAll": "全インデックス再構築",
    "doc_rag_reindexPage": "現在のページ索引を再構築",
    "doc_rag_queryFailFmt": "検索失敗: %@",
    "doc_search_placeholder": "ドキュメントを検索...",
    "doc_search_type": "タイプ",
    "doc_search_typeAll": "すべて",
    "doc_search_typePage": "ページ",
    "doc_search_typeBook": "ブック",
    "doc_search_sort": "並び替え",
    "doc_search_sortRelevance": "関連度",
    "doc_search_sortDate": "日時",
    "doc_search_sortTitle": "タイトル",
    "doc_search_resultFmt": "%d 件",
    "doc_search_hintKeyword": "キーワードを入力してドキュメントを検索",
    "doc_search_noResult": "検索結果なし",
    "doc_tpl_newTitle": "新規テンプレート",
    "doc_tpl_name": "名称",
    "doc_tpl_typeHint": "タイプ (report/letter/...)",
    "doc_tpl_category": "カテゴリ",
    "doc_tpl_create": "作成",
    "doc_tpl_title": "テンプレート",
    "doc_tpl_newHelp": "新規テンプレート",
    "doc_tpl_empty": "テンプレートはまだありません",
    "doc_tpl_extractVars": "変数を抽出",
    "doc_tpl_delete": "テンプレート削除",
    "doc_tpl_content": "テンプレート内容",
    "doc_tpl_variables": "テンプレート変数",
    "doc_tpl_inputVarFmt": "%@ を入力",
    "doc_tpl_useCreate": "テンプレートから作成",
    "doc_tpl_selDetail": "テンプレートを選択して詳細を表示",
    "doc_ver_title": "バージョン履歴",
    "doc_ver_snapshot": "スナップショット",
    "doc_ver_snapshotHelp": "バージョンスナップショット作成",
    "doc_ver_compare": "比較",
    "doc_ver_compareHelp": "選択バージョンを比較",
    "doc_ver_empty": "バージョン履歴はまだありません",
    "doc_ver_versionFmt": "バージョン %d",
    "doc_ver_setV1": "V1(旧版)に設定",
    "doc_ver_setV2": "V2(新版)に設定",
    "doc_ver_restore": "このバージョンを復元",
    "doc_ver_compareTitle": "バージョン比較",
    "doc_ver_diffFmt": "V%d → V%d",
    "doc_office_fmtDocx": "Word 文書",
    "doc_office_fmtXlsx": "Excel 表",
    "doc_office_fmtPptx": "PowerPoint プレゼン",
    "doc_office_title": "Office 操作",
    "doc_office_cliStatus": "OfficeCLI ステータス",
    "doc_office_versionFmt": "バージョン: %@",
    "doc_office_formatsFmt": "サポート形式: %@",
    "doc_office_detecting": "検出中...",
    "doc_office_create": "ドキュメント作成",
    "doc_office_filename": "ファイル名",
    "doc_office_createBtn": "作成",
    "doc_office_import": "ドキュメントインポート",
    "doc_office_filePath": "ファイルパス",
    "doc_office_importBtn": "インポート",
    "doc_office_export": "ページ書き出し",
    "doc_office_pageId": "ページ ID",
    "doc_office_format": "形式",
    "doc_office_exportBtn": "書き出し",
    "doc_office_merge": "テンプレート結合",
    "doc_office_templateName": "テンプレート名",
    "doc_office_dataJson": "データ JSON",
    "doc_office_mergeBtn": "結合",
    "doc_office_cmdTitle": "Office コマンド",
    "doc_office_cmdFile": "ファイル",
    "doc_office_cmdAction": "コマンド",
    "doc_office_executeBtn": "実行",
    "doc_office_importDir": "一括インポートディレクトリ",
    "doc_office_dirPath": "ディレクトリパス",
    "doc_wf_newTitle": "新規ワークフロー",
    "doc_wf_name": "名称",
    "doc_wf_desc": "説明",
    "doc_wf_create": "作成",
    "doc_wf_title": "ワークフロー",
    "doc_wf_newHelp": "新規",
    "doc_wf_seedHelp": "シードワークフロー",
    "doc_wf_empty": "ワークフローはまだありません",
    "doc_wf_delete": "ワークフロー削除",
    "doc_wf_yamlDef": "YAML 定義",
    "doc_wf_runInput": "実行入力",
    "doc_wf_runBtn": "ワークフロー実行",
    "doc_wf_runHistory": "実行履歴",
    "doc_wf_selDetail": "ワークフローを選択して詳細を表示",
    "doc_wf_transitionTitle": "ページ状態遷移",
    "doc_wf_queryBtn": "照会",
    "doc_wf_currentStateFmt": "現在の状態: %@",
    "doc_wf_executeBtn": "実行",
    "proj_subtitle": "AIプロジェクト・指示・ナレッジベースを管理",
    "proj_searchPh": "プロジェクトを検索",
    "proj_newHelp": "新規プロジェクト",
    "proj_archivedFmt": "アーカイブ (%d)",
    "proj_fileCountFmt": "%d ファイル",
    "proj_chatCountFmt": "%d チャット",
    "proj_archivedSuffix": "（アーカイブ）",
    "proj_unarchiveBtn": "アーカイブ解除",
    "proj_upstreamBanner": "一部サービス利用不可",
    "proj_emptyDetail": "プロジェクトを選択して詳細を表示",
    "proj_loadFailFmt": "読み込み失敗: %@",
    "proj_deleteFailFmt": "削除失敗: %@",
    "proj_minAgoFmt": "%d分前",
    "proj_hourAgoFmt": "%d時間前",
    "proj_dayAgoFmt": "%d日前",
    "proj_sortLastUpdated": "最近更新",
    "proj_sortDateCreated": "作成日時",
    "proj_sortAlphabetical": "名前順",
    "proj_menuUnstar": "お気に入り解除",
    "proj_menuStar": "プロジェクトをお気に入り",
    "proj_menuRename": "名前変更",
    "proj_menuDuplicate": "プロジェクトを複製",
    "proj_menuExport": "プロジェクトをエクスポート",
    "proj_menuArchive": "プロジェクトをアーカイブ",
    "proj_menuDelete": "プロジェクトを削除",
    "proj_menuSettings": "プロジェクト設定",
    "proj_deleteAlertTitle": "⚠️ プロジェクトを削除",
    "proj_deleteConfirm": "削除を確認",
    "proj_deleteAlertMsgFmt": "プロジェクト「%@」を完全に削除しますか？この操作は取り消せません。",
    "proj_deleteAlertMsgFullFmt": "プロジェクト「%@」を完全に削除しますか？\n· プロジェクト指示と全バージョンスナップショット\n· ナレッジベース全ファイル（%d ファイル）\n· プロジェクト内全会話（%d チャット）\nこの操作は取り消せません。",
    "proj_renameTitle": "プロジェクト名変更",
    "proj_namePh": "プロジェクト名",
    "proj_createTitle": "新規プロジェクト作成",
    "proj_createNameLabel": "プロジェクト名 *",
    "proj_createDescLabel": "説明",
    "proj_createDescPh": "説明（任意）",
    "proj_createInstructions": "プロジェクト指示",
    "proj_createCharCountFmt": "文字数：%d/%d",
    "proj_createInstructionsHint": "ここでロール・出力仕様・業務制約を定義。全チャットに自動継承。",
    "proj_createDefaultAgent": "デフォルトエージェント",
    "proj_createNoAgent": "バインドなし（純モデル対話）",
    "proj_createNoAgentShort": "バインドなし",
    "proj_createGotoAgentStudio": "Agent Studio で新規エージェント作成",
    "proj_createPromptMerge": "Prompt マージ戦略",
    "proj_createMergeAgentFirst": "Agent Prompt 優先（推奨）",
    "proj_createMergeProjectOnly": "プロジェクト Instructions のみ使用",
    "proj_createRagMode": "RAG 検索モード",
    "proj_createRagAuto": "AUTO（スマート検索）",
    "proj_createRagManual": "MANUAL（手動指定）",
    "proj_createRagOff": "OFF（無効）",
    "proj_createBtn": "プロジェクト作成",
    "proj_editModeMarkdown": "Markdown",
    "proj_editModeRichText": "リッチテキスト",
    "proj_dupTitle": "プロジェクト複製",
    "proj_dupNameLabel": "新プロジェクト名",
    "proj_dupCopySuffix": " (コピー)",
    "proj_dupScope": "複製範囲",
    "proj_dupScopeInstructionsOnly": "プロジェクト指示 + ナレッジファイルのみ（推奨）",
    "proj_dupScopeWithSnapshots": "指示 + ナレッジ + 全チャットスナップショット",
    "proj_dupBtn": "複製",
    "proj_detailArchived": "アーカイブ済み",
    "proj_detailImportCowork": "CoWorkにインポート",
    "proj_tabInstructions": "指示",
    "proj_tabKnowledge": "ナレッジベース",
    "proj_tabChats": "チャット",
    "proj_instTitle": "プロジェクト指示",
    "proj_instEmpty": "プロジェクト指示なし",
    "proj_instEmptyHint": "編集ボタンで指示を追加。全チャットに自動継承。",
    "proj_instHistoryTitle": "📋 Instructions バージョン履歴",
    "proj_instHistoryEmpty": "バージョン履歴なし",
    "proj_instHistoryCurrentFmt": "V%d",
    "proj_instHistoryCurrentTag": "（現在のバージョン）",
    "proj_instHistoryRestore": "復元",
    "proj_kbTitle": "ナレッジベース",
    "proj_kbFileCountFmt": "%d ファイル",
    "proj_kbFolder": "フォルダ",
    "proj_kbAddFile": "ファイル追加",
    "proj_kbEmpty": "ナレッジファイルなし",
    "proj_kbEmptyHint": "ドキュメントをアップロードしてAIの理解を支援",
    "proj_kbNewFolderAlert": "新規フォルダ",
    "proj_kbFolderNamePh": "フォルダ名",
    "proj_kbCreate": "作成",
    "proj_kbStatusIndexed": "索引済み",
    "proj_kbStatusIndexing": "索引中",
    "proj_kbStatusFailed": "解析失敗",
    "proj_kbStatusPending": "索引待ち",
    "proj_kbMenuPreview": "プレビュー",
    "proj_kbMenuRename": "名前変更",
    "proj_kbMenuReplace": "ファイル差替",
    "proj_kbMenuMove": "フォルダに移動...",
    "proj_kbMenuRemove": "ナレッジから削除",
    "proj_chatsTitle": "チャット",
    "proj_chatsSnapshots": "スナップショット",
    "proj_chatsSnapMsgCountFmt": "%dメッセージ",
    "proj_chatsEmpty": "チャットを選択または作成",
    "proj_chatsHint": "通知",
    "proj_chatsCreateFailFmt": "チャット作成失敗：%@\nfusion-projects サービスの起動を確認。",
    "proj_chatsSendFailFmt": "送信失敗：%@",
    "proj_chatsNoModel": "対話モデル未選択。上部モデル選択で選んでから送信。",
    "proj_chatsReplyFailFmt": "AI応答失敗：%@",
    "proj_ragSources": "参照元：",
    "proj_ragModeLabelFmt": "検索モード: %@",
    "proj_ragSwitchAuto": "AUTOに切替",
    "proj_ragSwitchManual": "MANUALに切替",
    "proj_inputUseDefaultAgent": "プロジェクトデフォルトエージェントを使用",
    "proj_inputGenericChat": "汎用対話（Agent非バインド）",
    "proj_inputPreviewAgent": "現在のAgentをプレビュー",
    "proj_inputRagLabelFmt": "RAG: %@",
    "proj_inputRagAuto": "AUTO（スマート）",
    "proj_inputRagManual": "MANUAL（手動）",
    "proj_inputRagOff": "OFF（無効）",
    "proj_inputAttachTemp": "一時添付",
    "proj_inputAttachScreenshot": "スクリーンショット",
    "proj_inputAttachWebSearch": "WebSearch",
    "proj_inputAttachSkill": "スキルツール",
    "proj_inputPlaceholder": "メッセージを入力…",
    "proj_budgetLow": "⚠️ 予算不足",
    "proj_chatMenuUnstar": "お気に入り解除",
    "proj_chatMenuStar": "チャットをお気に入り",
    "proj_chatMenuRename": "チャット名変更",
    "proj_chatMenuFork": "チャットをフォーク",
    "proj_chatMenuSnapshot": "スナップショット作成",
    "proj_chatMenuMove": "別プロジェクトに移動",
    "proj_chatMenuRemove": "プロジェクトから削除",
    "proj_chatMenuDelete": "チャットを削除",
    "proj_chatDeleteAlertTitle": "チャットを削除？",
    "proj_agentConfigTitle": "エージェント設定",
    "proj_agentConfigDefault": "デフォルトエージェント",
    "proj_agentConfigPromptMerge": "Prompt マージ戦略",
    "proj_ragConfigTitle": "RAG設定",
    "proj_ragConfigMode": "検索モード",
    "proj_ragConfigTopKFmt": "Top-K: %d",
    "proj_ragConfigThresholdFmt": "類似度しきい値: %@",
    "proj_ragConfigSelectScope": "検索範囲を選択",
    "proj_settingsTitleFmt": "⚙️ プロジェクト設定 — %@",
    "proj_settingsBasicInfo": "プロジェクト情報",
    "proj_settingsNameLabel": "プロジェクト名",
    "proj_settingsDescLabel": "説明",
    "proj_settingsDescPh": "説明",
    "proj_settingsAgentConfig": "エージェント設定",
    "proj_settingsPromptMerge": "Prompt マージ戦略",
    "proj_settingsMergeAgentFirst": "Agent Prompt 優先（推奨）\nAgent ペルソナ + プロジェクト業務ルール統合",
    "proj_settingsMergeProjectOnly": "プロジェクト Instructions のみ\nAgent 内蔵 Prompt を無視、完全プロジェクト独自",
    "proj_settingsRagConfig": "RAG設定",
    "proj_settingsRagAuto": "AUTO（スマート検索 — Claude Projects 対抗）",
    "proj_settingsRagManual": "MANUAL（手動フォルダ/ファイル検索）",
    "proj_settingsTopK": "TopK",
    "proj_settingsThreshold": "類似度しきい値",
    "proj_settingsSaveBtn": "設定を保存",
    "proj_previewUnbound": "バインドなし",
    "proj_previewRole": "ロール概要",
    "proj_previewActiveConfig": "現在の有効設定",
    "proj_previewPromptStrategyFmt": "· Prompt戦略：%@",
    "proj_previewPromptAgentFirst": "Agent優先",
    "proj_previewPromptProjectOnly": "プロジェクトInstructionsのみ",
    "proj_previewRagModeFmt": "· RAGモード：%@ (TopK=%d, しきい値=%@)",
    "proj_previewAccessKb": "· このプロジェクトのナレッジベースにアクセス可能",
    "proj_previewUnboundHint": "エージェント未バインド。純モデル対話を使用。",
    "proj_previewGotoAgentStudio": "Agent Studio で編集",
    "proj_coworkTitle": "CoWork スペースにインポート",
    "proj_coworkTarget": "ターゲット CoWork スペース",
    "proj_coworkTargetPlaceholder": "（CoWork スペースリスト）",
    "proj_coworkSyncContent": "同期内容",
    "proj_coworkSyncKnowledge": "ナレッジ全ファイル",
    "proj_coworkSyncSnapshots": "選択チャットスナップショット",
    "proj_coworkWarning": "ナレッジファイルはCoWorkスペースにコピーされ、以降の変更は自動同期されません。",
    "proj_coworkConfirm": "インポート確認",
    "proj_ragScopeTitle": "🔍 検索範囲設定",
    "proj_ragScopeMode": "検索モード",
    "proj_ragScopeAuto": "AUTO（スマート全体検索）",
    "proj_ragScopeManual": "MANUAL（手動範囲指定）",
    "proj_ragScopeSpecify": "検索範囲を指定",
    "proj_ragScopeConfirm": "確認",
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

    "hub_rpmMustPositive": "⚠️ RPM은 > 0이어야 합니다",
    "hub_concurrencyMustPositive": "⚠️ 동시실행 수는 > 0이어야 합니다",
    "hub_idleTooLowWarn": "⚠️ 5분 미만은 잦은 로드/언로드로 응답 속도에 영향을 줍니다",
    "hub_nDownloading": "%@개 다운로드 중",
    "hub_nActiveDeployments": "%@개 활성 배포",
    "hub_nItems": "%@개",
    "hub_nModels": "%@개",
    "hub_nRoles": "%@ 역할",
    "hub_nReplicas": "%@ 복제본",
    "hub_apiKeyCreated": "API Key 생성됨",
    "hub_apiKeysTitle": "API 키",
    "hub_apiKeysAndModelPerms": "API 키와 모델 권한",
    "hub_apiThrottleConfig": "API 속도 제한 설정",
    "hub_gbMemory": "GB 메모리",
    "hub_kvCacheOpt": "KV-Cache 최적화",
    "hub_qpsLimitZero": "QPS 제한 (0=무제한)",
    "hub_rpmDefault": "RPM: %@ (기본)",
    "hub_ttlConfigNote": "TTL 설정 설명",
    "hub_ttlServeParamNote": "TTL은 모델 서비스 배포 시 지정 (serve API의 ttl_seconds 매개변수)",
    "hub_securityScore": "보안 점수",
    "hub_securityScan": "보안 스캔",
    "hub_perModelSettings": "모델별 설정",
    "hub_autoBenchAfterVersion": "버전 업데이트 후 자동 벤치마크",
    "hub_saveBtn": "저장",
    "hub_localResourceClusterHint": "로컬 자원 부족 시 클러스터 여유 Mac에 자동 할당하여 추론 실행",
    "hub_editRole": "역할 편집",
    "hub_editPermission": "권한 편집",
    "hub_editPermissionModel": "권한 편집 — %@",
    "hub_concurrencyVal": "동시실행: %@",
    "hub_concurrencyDefault": "동시실행: %@ (기본)",
    "hub_deployMetrics": "배포 지표",
    "hub_auditLog": "감사 로그",
    "hub_testModelCount": "테스트 모델 수",
    "hub_testStatus": "테스트 상태",
    "hub_pinnedNoTTLNote": "상주 모델(pinned)은 TTL 제한을 받지 않고 항상 메모리에 유지",
    "hub_pinnedWhitelist": "상주 메모리 화이트리스트",
    "hub_heldFlat": "보합",
    "hub_createBtn": "생성",
    "hub_createApiKey": "API 키 생성",
    "hub_createKey": "키 생성",
    "hub_createdAt": "생성일 %@",
    "hub_disk": "디스크",
    "hub_storageDetail": "저장소 상세",
    "hub_pendingApproval": "승인 대기",
    "hub_perModelThrottle": "모델별 속도 제한",
    "hub_noActiveModels": "활성 모델 없음",
    "hub_exportCsv": "CSV 내보내기",
    "hub_waiting": "대기 중",
    "hub_benchThresholdWarn": "임계값 미만 벤치마크 결과는 경고로 표시됩니다",
    "hub_scheduledBenchNote": "예약 테스트는 매일 오전 3:00 또는 매주 월요일 오전 3:00에 자동 실행",
    "hub_scheduledBenchmark": "예약 벤치마크",
    "hub_compare": "비교",
    "hub_compareQuantResults": "양자화 결과 비교",
    "hub_benchCompareHint": "모델 추론 성능 비교: Tokens/s, 첫 Token 지연, 피크 메모리",
    "hub_compareSelectedN": "선택 비교 (%@)",
    "hub_layeredQuantHint": "각 레이어에 다른 양자화 전략을 적용해 정밀도와 속도 균형",
    "hub_encryptModelWeights": "모델 가중치 암호화 보호",
    "hub_multiNodeSyncHint": "멀티노드는 모델 파일을 한 번만 다운로드하고 자동 증분 동기화",
    "hub_issuesFound": "문제 발견",
    "hub_idleUnloadHint": "분 후 모델 언로드, 통합 메모리 해제",
    "hub_peakMemory": "피크 메모리",
    "hub_copyAndClose": "복사 후 닫기",
    "hub_formatBitsMem": "형식: %@ | %@-bit | %@",
    "hub_redBelowThreshold": "빨강 = 임계값 미만",
    "hub_cache": "캐시",
    "hub_yellowNearThreshold": "노랑 = 임계값 근접",
    "hub_canaryPercent": "카나리 %@%%",
    "hub_active": "활성",
    "hub_activeSessions": "활성 세션",
    "hub_activeModelCountdown": "활성 모델 카운트다운",
    "hub_clusterSchedConfig": "클러스터 스케줄 설정",
    "hub_clusterNodeHealth": "클러스터 노드 상태",
    "hub_clusterSharedCache": "클러스터 전역 공유 모델 캐시",
    "hub_encryption": "암호화",
    "hub_encryptionMgmt": "암호화 관리",
    "hub_encryptModel": "모델 암호화",
    "hub_loadDetail": "상세 로딩 중...",
    "hub_loading": "로딩 중...",
    "hub_securityScanTargetHint": "지정 모델의 보안 취약점 스캔",
    "hub_reject": "거절",
    "hub_enableCrossNodeRouting": "교차 노드 추론 라우팅 활성화",
    "hub_startLayeredQuantize": "계층별 양자화 시작",
    "hub_startQuantize": "양자화 시작",
    "hub_startScan": "스캔 시작",
    "hub_startDownload": "다운로드 시작",
    "hub_controlModuleModelHint": "각 모듈이 사용할 모델 제어, 권한 편집 클릭하여 변경",
    "hub_controlRateConcurrencyHint": "모델별 요청 속도와 동시실행 제한으로 과부하 방지",
    "hub_quickPresetHint": "시나리오에 맞는 양자화 프리셋 빠른 선택",
    "hub_typeLabel": "유형: %@",
    "hub_historyBenchRecords": "벤치마크 기록",
    "hub_runBenchmarkNow": "지금 벤치마크 실행",
    "hub_quantLinkedBench": "양자화 연계 벤치마크",
    "hub_quantPostBench": "양자화 후 베이스라인",
    "hub_quantizedModel": "양자화 모델",
    "hub_quantizeTask": "양자화 작업",
    "hub_quantTaskBenchResult": "양자화 작업 완료 후 자동 벤치마크 결과",
    "hub_autoBenchAfterQuantize": "양자화 완료 후 자동 벤치마크",
    "hub_quantBits": "양자화 비트 수",
    "hub_noRunningQuantTask": "실행 중인 양자화 작업 없음",
    "hub_autoRefresh10s": "10초마다 자동 새로고침",
    "hub_rpmLabel": "분당 요청 수 (RPM)",
    "hub_rpmLabelColon": "분당 요청 수 (RPM):",
    "hub_pinnedWhitelistNote": "목록 내 모델은 영구 메모리 상주, 자동 언로드 안 함",
    "hub_template": "템플릿",
    "hub_moduleAccessPerm": "모듈 접근 권한",
    "hub_model": "모델",
    "hub_modelTTL": "모델 TTL (생존 시간)",
    "hub_modelApprovalOps": "모델: %@",
    "hub_modelJoined": "모델: %@",
    "hub_autoBenchAfterQuantOrDownload": "양자화 또는 다운로드 후 자동 벤치마크로 성능 변화 추적",
    "hub_autoBenchQuantOrDownloadShort": "양자화 완료 또는 새 모델 다운로드 완료 시 자동 벤치마크",
    "hub_autoBenchAfterQuantConvert": "양자화 변환 성공 후 자동 성능 벤치마크 실행",
    "hub_autoBenchAfterVersionLoad": "모델 새 버전 로드 후 자동 성능 벤치마크 비교",
    "hub_defaultThrottlePolicy": "기본 속도 제한 정책",
    "hub_targetFormat": "대상 형식",
    "hub_benchIncludedModels": "테스트 포함 모델",
    "hub_memory": "메모리",
    "hub_benchmark": "벤치마크",
    "hub_benchResult": "벤치마크 결과",
    "hub_benchResultColon": "벤치마크 결과:",
    "hub_benchType": "벤치마크 유형",
    "hub_benchTemplate": "벤치마크 템플릿",
    "hub_benchModel": "벤치마크 모델",
    "hub_score": "점수",
    "hub_scoreWarnThreshold": "점수 경고 임계값: %@",
    "hub_evalResult": "평가 결과",
    "hub_evaluateQuant": "양자화 평가",
    "hub_enableAutoBenchmark": "자동 벤치마크 활성화",
    "hub_cleanupSystem": "시스템 정리",
    "hub_apiKeyOnceHint": "지금 복사 — 이 키는 한 번만 표시됩니다:\n%@",
    "hub_requestsTotal": "요청: %@",
    "hub_requestsPerMin": "요청/분",
    "hub_selectTenantFirst": "왼쪽 테넌트를 먼저 선택하세요",
    "hub_pleaseSelect": "선택하세요",
    "hub_cancelBtn": "취소",
    "hub_unifiedFusionApp": "모든 Fusion 앱에 통일 적용",
    "hub_all": "전체",
    "hub_globalModelLoadPolicy": "전역 모델 로드 정책",
    "hub_globalThreshold": "전역 임계값",
    "hub_permissionSelect": "권한 선택",
    "hub_date": "날짜",
    "hub_scanModel": "모델 스캔",
    "hub_scanModelSecurity": "모델 보안 스캔",
    "hub_scanDuplicates": "중복 스캔",
    "hub_setIdleUnloadCountdown": "모델 자동 언로드 카운트다운 설정, 유휴 시간 초과 시 통합 메모리 해제",
    "hub_setThreshold": "임계값 설정",
    "hub_requester": "신청자: %@",
    "hub_requesterShort": "신청자: %@",
    "hub_approval": "승인",
    "hub_approvalWorkflow": "승인 워크플로우",
    "hub_approvalProcess": "승인 프로세스",
    "hub_reviewerWithComment": "승인자: %@%@",
    "hub_approvalDetail": "승인 상세",
    "hub_remainingTime": "남은 시간",
    "hub_failed": "실패",
    "hub_time": "시간",
    "hub_realtimeMonitor": "실시간 모니터",
    "hub_firstToken": "첫 Token",
    "hub_firstTokenSec": "첫 Token(s)",
    "hub_firstTokenLatency": "첫 Token 지연",
    "hub_refresh": "새로고침",
    "hub_watermarkMgmt": "워터마크 관리",
    "hub_add": "추가",
    "hub_addWatermark": "워터마크 추가",
    "hub_deactivate": "비활성화",
    "hub_approve": "승인",
    "hub_general2": "일반",
    "hub_done": "완료",
    "hub_completionTime": "완료 시간",
    "hub_addDigitalWatermarkHint": "모델에 디지털 워터마크 추가로 지식재산 보호",
    "hub_unconfiguredUsesDefault": "개별 설정 없는 모델은 기본 정책 사용",
    "hub_noSecurityIssues": "보안 문제 없음",
    "hub_noClusterNodes": "클러스터 노드 없음",
    "hub_noModelWillTestAll": "모델 미선택 — 모든 다운로드된 모델 테스트",
    "hub_issueSummary": "문제 요약",
    "hub_none": "없음",
    "hub_noPermissionConfig": "권한 설정 없음",
    "hub_downloadLabel": "다운로드: %@",
    "hub_downloadTask": "다운로드 작업",
    "hub_downloadNewModel": "새 모델 다운로드",
    "hub_idle": "유휴",
    "hub_idleAfterTTLUnload": "유휴 시간이 TTL을 초과하면 모델은 메모리에서 자동 언로드되어 GPU 통합 메모리 해제",
    "hub_idleAutoReclaim": "유휴 자동 회수",
    "hub_auditLogFirstN": "앞 30건 표시, 총 %@건",
    "hub_throttleConfigModel": "속도 제한 설정 — %@",
    "hub_newRole": "새 역할",
    "hub_newBenchmark": "새 벤치마크",
    "hub_newDownload": "새 다운로드",
    "hub_newTenant": "새 테넌트",
    "hub_performanceBenchmark": "성능 벤치마크",
    "hub_selectBenchModels": "벤치마크 모델 선택",
    "hub_selectModel": "모델 선택",
    "hub_selectModelPlaceholder": "모델 선택...",
    "hub_selectBenchModel": "벤치마크 모델 선택",
    "hub_latencyMs": "지연(ms)",
    "hub_rejected": "거절됨",
    "hub_configuredTTLModels": "TTL 설정된 모델",
    "hub_deactivated": "비활성화됨",
    "hub_approved": "승인됨",
    "hub_selectedNModelsLoading": "선택 %@ 모델 (로딩 중...)",
    "hub_hardwareInfo": "하드웨어 정보",
    "hub_permanentResidentNoTTL": "영구 상주 (TTL 없음)",
    "hub_estimatedReduction": "예상 감소",
    "hub_presetScheme": "프리셋 방안",
    "hub_originalVsQuant": "원본 vs 양자화 비교",
    "hub_originalModel": "원본 모델",
    "hub_allowedModulesHint": "허용 모듈 (공백=전체)",
    "hub_allowedModelsHint": "허용 모델 (공백=전체)",
    "hub_runningColon": "실행: %@",
    "hub_runBenchmark": "벤치마크 실행",
    "hub_running": "실행 중",
    "hub_noApiKey": "API 키 없음",
    "hub_noAuditLogs": "감사 로그 없음",
    "hub_noPinnedModels": "상주 모델 없음",
    "hub_noActiveDeployments": "활성 배포 없음",
    "hub_noRoles": "역할 없음",
    "hub_noHistory": "기록 없음",
    "hub_noQuantLinkedBench": "양자화 연계 벤치마크 데이터 없음",
    "hub_noModels": "모델 없음",
    "hub_noModelData": "모델 데이터 없음",
    "hub_noBenchRecords": "벤치마크 기록 없음",
    "hub_noBenchData": "벤치마크 데이터 없음 — 모델 선택 후 실행",
    "hub_noApprovalRequests": "승인 요청 없음",
    "hub_noInferenceData": "추론 데이터 없음",
    "hub_noDownloadTasks": "다운로드 작업 없음",
    "hub_noDownloadedModels": "다운로드된 모델 없음",
    "hub_noTenants": "테넌트 없음",
    "hub_executionFrequency": "실행 빈도",
    "hub_qualityChange": "품질 변화: %@",
    "hub_qualityScore": "품질 점수",
    "hub_reset": "재설정",
    "hub_attentionQuant": "어텐션 레이어 양자화",
    "hub_convertQuantize": "변환 & 양자화",
    "hub_status": "상태",
    "hub_statusApproval": "상태: %@",
    "hub_accuracy": "정확도",
    "hub_accuracyVal": "정확도: %@",
    "hub_accuracyWarnThreshold": "정확도 경고 임계값: %@",
    "hub_accuracyThresholdSettings": "정확도 임계값 설정",
    "hub_custom": "사용자 정의",
    "hub_autoTest": "자동 테스트",
    "hub_autoBenchmark": "자동 벤치마크",
    "hub_autoBenchRules": "자동 벤치마크 규칙",
    "hub_autoBenchTemplateLabel": "자동 벤치마크 템플릿:",
    "hub_tenant": "테넌트",
    "hub_tenantsAndRoles": "테넌트와 역할",
    "hub_maxConcurrency": "최대 동시실행",
    "hub_maxConcurrencyColon": "최대 동시실행:",
    "hub_expired": "만료됨",
    "hub_unknownIssue": "알 수 없는 문제",
    "hub_notYetScanned": "보안 스캔 미실행",
    "hub_noWatermarkInfo": "워터마크 정보 없음",
    "hub_noEncryptionInfo": "암호화 정보 없음",
    "hub_noApprovalRecords": "승인 기록 없음",
    "hub_modelId": "모델 ID",
    "hub_watermarkStatus": "워터마크 상태",
    "hub_watermarkId": "워터마크 ID",
    "hub_verifyStatus": "검증 상태",
    "hub_verified": "검증됨",
    "hub_notVerified": "미검증",
    "hub_embeddedTime": "임베드 시간",
    "hub_encryptionStatus": "암호화 상태",
    "hub_encryptionAlgorithm": "암호화 알고리즘",
    "hub_encryptionTime": "암호화 시간",
    "hub_watermarkText": "워터마크 텍스트",
    "hub_addBtn": "추가",
    "hub_encryptBtn": "암호화",
    "hub_modelIdPlaceholder": "모델 ID",
    "hub_downloadUrlPlaceholder": "다운로드 URL (https://...)",
    "hub_downloadSched": "다운로드 스케줄",
    "hub_computeSchedPolicy": "연산 스케줄 정책",
    "hub_modulePermission": "모듈 권한",
    "hub_apiThrottle": "API 속도 제한",
    "hub_modelTTLTab": "모델 TTL",
    "hub_autoBenchmarkTab": "자동 벤치마크",
    "hub_policyAuto": "스마트 자동 스케줄",
    "hub_policyAutoDesc": "요청에 따라 자동 로드/언로드 (권장)",
    "hub_policyPinned": "수동 상주",
    "hub_policyPinnedDesc": "모델 메모리 상주, 자동 언로드 없음",
    "hub_policyOnDemand": "사용 후 즉시 언로드",
    "hub_policyOnDemandDesc": "각 요청 후 즉시 언로드, 메모리 최대 절약",
    "hub_idlePrefix": "유휴",
    "hub_editPermissionBtn": "권한 편집",
    "hub_edit": "편집",
    "hub_daily": "매일",
    "hub_weekly": "매주",
    "hub_monthly": "매월",
    "hub_enabled": "활성화됨",
    "hub_notEnabled": "비활성화됨",
    "hub_benchmarkStarted": "벤치마크 시작 — 나중에 결과 확인",
    "hub_evalTaskCreated": "평가 작업 생성됨",
    "hub_quantizeStarted": "양자화 작업 시작됨",
    "hub_layeredQuantizeStarted": "계층별 양자화 작업 시작됨",
    "hub_assessFailed": "평가 실패: %@",
    "hub_layeredQuantFailed": "계층별 양자화 실패: %@",
    "hub_compareFailed": "비교 실패: %@",
    "hub_evalStartedForModel": "%@ 벤치마크 시작됨",
    "hub_evalFailed": "벤치마크 실패: %@",
    "hub_templateGeneral": "일반",
    "hub_templateCode": "코드",
    "hub_templateReasoning": "추론",
    "hub_templateMultilingual": "다국어",
    "hub_templateVision": "비전",
    "hub_evalTypeAccuracy": "정확도",
    "hub_evalTypeAlignment": "정렬도",
    "hub_evalTypeSafety": "안전성",
    "hub_evalTypeCode": "코드 능력",
    "hub_evalTypeReasoning": "추론 능력",
    "hub_evalTypeGeneral": "일반",
    "hub_evalTypeComprehensive": "종합 평가",
    "hub_unknown": "알 수 없음",
    "hub_unknownModel": "알 수 없는 모델",
    "hub_operationDeploy": "배포",
    "hub_operationDelete": "삭제",
    "hub_operationQuantize": "양자화",
    "hub_operationExport": "내보내기",
    "hub_operationServe": "온라인",
    "hub_operationDownload": "다운로드",
    "hub_operation": "작업",
    "hub_allSources": "모든 소스",
    "hub_sourceLocal": "로컬",
    "hub_sourceHub": "Hub",
    "hub_sourceCustom": "사용자 정의",
    "hub_source": "소스",
    "hub_health_healthy": "정상",
    "hub_health_warning": "경고/저하",
    "hub_health_error": "오류/과부하",
    "hub_chip": "칩",
    "hub_cpuCores": "CPU 코어",
    "hub_gpuCores": "GPU 코어",
    "hub_available": "사용 가능",
    "hub_supported": "지원",
    "hub_neCores": "NE 코어",
    "hub_modelName": "모델 이름",
    "hub_modelInferenceStats": "모델 추론 통계",
    "hub_noDownloadTasksShort": "다운로드 작업 없음",
    "hub_selectTenantViewRoles": "테넌트 선택하여 역할 표시",
    "hub_roleList": "역할 목록",
    "hub_keyName": "키 이름",
    "hub_tenantName": "테넌트 이름",
    "hub_defaultRole": "기본 역할",
    "hub_roleName": "역할 이름",
    "hub_approvalCommentOptional": "승인 의견 (선택)",
    "hub_approvalComment": "승인 의견",
    "hub_roleAdmin": "관리자",
    "hub_roleMember": "멤버",
    "hub_roleGuest": "게스트",
    "hub_roleAdminCaps": "전체 모델 + 전체 모듈 + 키 관리 + 시스템 설정",
    "hub_roleMemberCaps": "지정 모델 + 일반 모듈 + 시스템 설정 없음",
    "hub_roleGuestCaps": "제한 모델 + 채팅 전용 + 속도 제한",
    "hub_copyAndClose2": "복사 후 닫기",
    "hub_presetChatLabel": "채팅 모델",
    "hub_presetCodeLabel": "코드 모델",
    "hub_presetEmbeddingLabel": "임베딩 모델",
    "hub_presetRagLabel": "RAG 모델",
    "hub_presetChatMem": "저메모리",
    "hub_presetCodeMem": "균형",
    "hub_presetEmbeddingMem": "정밀도 우선",
    "hub_presetRagMem": "추론 최적화",
    "hub_presetChatDesc": "4-bit MLX 양자화, 채팅 적합, 최저 메모리",
    "hub_presetCodeDesc": "8-bit MLX 양자화, 코드 품질과 속도 균형",
    "hub_presetEmbeddingDesc": "FP16 MLX 형식, 임베딩 정밀도 유지, 검색 적합",
    "hub_presetRagDesc": "4-bit GGUF 형식, RAG 추론 최적화, llama.cpp 호환",
    "hub_scenePreset": "시나리오 프리셋",
    "hub_quantConfig": "양자화 설정",
    "hub_layeredQuantize": "계층별 양자화",
    "hub_quantCompare": "양자화 비교",
    "hub_qualityLabel": "품질: %.0f%%",
    "hub_speedLabel": "속도: %.1f tok/s",
    "hub_memoryLabelFmt": "메모리: %.1f GB",
    "hub_firstTokenFmt": "첫 Token: %.2fs",
    "hub_accuracyFmt": "정확도: %.1f%%",
    "hub_benchResultPrefix": "벤치마크 결과:",
    "hub_accuracyPrefix": "정확도 %.1f%%",
    "hub_firstTokenPrefix": "첫 Token %.2fs",
    "hub_memoryPrefix": "메모리 %.1f GB",
    "hub_perTokenLatency": "Token당 지연",
    "hub_firstTokenLatencyLabel": "첫 Token 지연",
    "hub_prefillLatency": "Prefill 지연",
    "hub_decodeLatency": "Decode 지연",
    "hub_throughputBatch1": "Batch=1 처리량",
    "hub_throughputBatch2": "Batch=2 처리량",
    "hub_throughputBatch4": "Batch=4 처리량",
    "hub_throughputBatch8": "Batch=8 처리량",
    "hub_memoryFootprint": "메모리 사용량",
    "hub_usedStorageFmt": "사용됨 %.1f / %.1f GB (%.0f%%)",
    "hub_tokensPerSecCol": "Tokens/s",
    "hub_accuracyCol": "정확도",
    "hub_scoreCol": "점수",
    "hub_compareCol": "비교",
    "hub_templateCol": "템플릿",
    "hub_deployment": "배포",
    "hub_newEval": "새 평가",
    "hub_quantColon": "양자화: %@",
    "hub_dlColon": "다운로드: %@",
    "hub_modelColon": "모델: %@",
    "hub_modelColonJoined": "모델: %@",
    "hub_requesterColon": "신청자: %@",
    "hub_reviewerColonComment": "승인자: %@%@",
    "hub_statusColon": "상태: %@",
    "hub_typeColon": "유형: %@",
    "hub_showingFirstN": "앞 30건 표시, 총 %@건",
    "hub_nReplicasFmt": "%@ 복제본",
    "hub_canaryFmt": "카나리 %@%%",
    "hub_nActiveDeploymentsFmt": "%@개 활성 배포",
    "hub_nDownloadingFmt": "%@개 다운로드 중",
    "hub_nRolesFmt": "%@ 역할",
    "hub_nItemsFmt": "%@개",
    "hub_sevCritical": "치명적", "hub_sevHigh": "높음", "hub_sevMedium": "보통", "hub_sevLow": "낮음",
    "hub_latencyLabel": "지연", "hub_errorRate": "오류율", "hub_grayCanary": "카나리 %@%",
    "hub_quantLabel": "양자화: %@", "hub_runningLabel": "가동: %@", "hub_activeDeploymentsFmt": "%d개 활성 배포",
    "hub_countItemsFmt": "%d개", "hub_copiesFmt": "%d 복제본", "hub_auditShowingFmt": "상위 30건 / 전체 %d건",
    "hub_modelSizeFmt": "모델: %.1f GB", "hub_csvHeader": "ID,시간,작업,출처,리소스,사용자,상세\n",
    "hub_roleCountFmt": "%d 역할", "hub_createdAtFmt": "생성 %@", "hub_modelsPermListFmt": "모델: %@",
    "hub_modelPermissions": "모델 권한", "hub_apiKeyCopyOnceWarn": "지금 복사 — 이 키는 한 번만 표시됩니다:\n%@",
    "hub_requestsTotalFmt": "요청: %d", "hub_reviewerCommentFmt": "승인자: %@%@",
    "hub_compareSelectedFmt": "선택 비교 (%d)", "hub_modelBenchmark": "모델 벤치마크",
    "hub_scoreWarnThresholdFmt": "점수 경고 임계값: %@", "hub_accuracyFmt2": "정확도: %@",
    "hub_accuracyWarnThresholdFmt": "정확도 경고 임계값: %@", "hub_activeDownloadsFmt": "%d개 다운로드 중",
    "hub_durationHMSFmt": "%@시 %@분 %@초", "hub_durationMSFmt": "%@분 %@초", "hub_durationSFmt": "%@초",
    "hub_durationZero": "0초", "hub_rpmDefaultFmt": "RPM: %d (기본값)", "hub_editPermTitleFmt": "권한 편집 — %@",
    "hub_concurrencyFmt": "동시 실행: %d", "hub_concurrencyDefaultFmt": "동시 실행: %d (기본값)",
    "hub_throttleConfigTitleFmt": "스로틀 설정 — %@", "hub_selectedModelsLoadingFmt": "%d개 모델 선택 (로딩 중...)",
    "hub_ls_catAll": "전체", "hub_ls_catChat": "일반 대화", "hub_ls_catCode": "코드", "hub_ls_catEmbed": "임베딩", "hub_ls_catVision": "이미지 멀티모달", "hub_ls_catPrivate": "프라이빗", "hub_ls_catPinned": "고정됨", "hub_ls_catServing": "추론 중", "hub_ls_catLLM": "언어 모델", "hub_ls_catVLM": "비전 모델", "hub_ls_catEmbedM": "임베딩 모델", "hub_ls_catCodeM": "코드 모델", "hub_ls_catAudioM": "오디오 모델", "hub_ls_catMLX": "MLX 형식", "hub_ls_catGGUF": "GGUF 형식", "hub_ls_category": "카테고리", "hub_ls_searchPlaceholder": "로컬 모델 검색...", "hub_ls_batchMode": "배치 모드", "hub_ls_selectedCountFmt": "%d개 선택", "hub_ls_selectAll": "전체 선택", "hub_ls_batchDelete": "일괄 삭제", "hub_ls_batchQuantize": "일괄 양자화", "hub_ls_syncCluster": "클러스터 동기화", "hub_ls_exportPath": "내보내기 경로", "hub_ls_currentUse": "사용 중", "hub_ls_serving": "추론 중", "hub_ls_compatFormats": "호환 형식:", "hub_ls_unpin": "고정 해제", "hub_ls_pin": "고정", "hub_ls_stopServe": "추론 중지", "hub_ls_startServe": "추론 시작", "hub_ls_basicInfo": "기본 정보", "hub_ls_path": "경로", "hub_ls_source": "소스", "hub_ls_engine": "엔진", "hub_ls_license": "라이선스", "hub_ls_allowedModules": "허용 모듈", "hub_ls_selectModelHint": "모델을 선택해 상세 보기", "hub_ls_versionMgmt": "버전 관리", "hub_ls_versionList": "버전 목록", "hub_ls_noVersions": "버전 정보 없음", "hub_ls_rollback": "롤백", "hub_ls_publish": "게시", "hub_ls_deprecate": "폐기", "hub_ls_retire": "서비스 중단", "hub_ls_resident": "상주", "hub_ls_batchQuantTitle": "일괄 양자화", "hub_ls_batchQuantHintFmt": "%d개 모델 양자화 실행", "hub_ls_targetFormat": "대상 형식", "hub_ls_quantBits": "양자화 비트", "hub_ls_startQuantize": "양자화 시작", "hub_ls_batchQuantFailFmt": "일괄 양자화 실패: %@", "hub_ls_rollbackFailFmt": "버전 롤백 실패: %@", "hub_ls_syncFailFmt": "클러스터 동기화 실패: %@", "hub_ls_startServeFailFmt": "추론 시작 실패: %@", "hub_ls_stopServeFailFmt": "추론 중지 실패: %@", "hub_ls_publishFailFmt": "버전 게시 실패: %@", "hub_ls_deprecateFailFmt": "버전 폐기 실패: %@", "hub_ls_retireFailFmt": "버전 서비스중단 실패: %@",
    "hub_cls_nodes": "클러스터 노드", "hub_cls_onlineFmt": "%d/%d 온라인", "hub_cls_syncModel": "모델 동기화", "hub_cls_noNodes": "클러스터 노드 없음", "hub_cls_noNodesHint": "같은 네트워크에서 Model Hub 서비스를 실행하세요", "hub_cls_selectNodeHint": "노드를 선택해 상세 보기", "hub_cls_nodeInfo": "노드 정보", "hub_cls_addr": "주소", "hub_cls_lastSeen": "최근 온라인", "hub_cls_resourceUsage": "리소스 사용량", "hub_cls_memory": "메모리", "hub_cls_localModelsFmt": "로컬 모델 (%d)", "hub_cls_autoSchedule": "자동 스케줄 추론", "hub_cls_localFirst": "로컬 우선, 클러스터 폴백", "hub_cls_model": "모델", "hub_cls_selectModelHint": "모델 선택...", "hub_cls_routeMode": "라우팅 모드", "hub_cls_promptPlaceholder": "추론 프롬프트 입력...", "hub_cls_sendInfer": "추론 요청 전송", "hub_cls_inferResult": "추론 결과", "hub_cls_routedTo": "라우팅:", "hub_cls_resultHint": "추론 요청 전송 후 결과 확인", "hub_cls_syncToCluster": "클러스터로 모델 동기화", "hub_cls_syncHint": "모든 온라인 클러스터 노드로 모델 파일 동기화", "hub_cls_startSync": "동기화 시작", "hub_cls_modeAuto": "자동", "hub_cls_modeLocal": "로컬 우선", "hub_cls_modeCluster": "클러스터",
    "hub_dash_mlxEngine": "MLX 추론 엔진", "hub_dash_clusterMode": "클러스터 모드", "hub_dash_modelService": "모델 서비스", "hub_dash_localModels": "로컬 모델", "hub_dash_activeModels": "활성 모델", "hub_dash_downloading": "다운로드 중", "hub_dash_totalStorage": "총 저장공간", "hub_dash_pinned": "고정", "hub_dash_quantizing": "양자화 중", "hub_dash_clusterNodes": "클러스터 노드", "hub_dash_totalModels": "전체 모델", "hub_dash_quickActions": "빠른 작업", "hub_dash_searchMarket": "마켓 검색", "hub_dash_downloadModel": "모델 다운로드", "hub_dash_quantizeModel": "모델 양자화", "hub_dash_systemClean": "시스템 정리", "hub_dash_recentModels": "최근 모델", "hub_dash_noModels": "모델 없음", "hub_dash_resident": "상주", "hub_dash_serving": "추론 중", "hub_dash_sysOverview": "시스템 개요", "hub_dash_memory": "메모리", "hub_dash_disk": "디스크", "hub_dash_uptime": "가동 시간", "hub_dash_loading": "로딩 중...",
    "hub_mv_descQwen35": "통의천문 3.5, 9B 파라미터, 4bit 양자화", "hub_mv_descLlama3": "Meta Llama 3, 8B 파라미터, 4bit 양자화", "hub_mv_descDeepseek": "DeepSeek 코드 전용 모델", "hub_mv_descQwenVL": "Qwen2 비전 언어 모델", "hub_mv_catAll": "전체", "hub_mv_searchPlaceholder": "모델 검색...", "hub_mv_selectModelHint": "모델을 선택해 상세 보기", "hub_mv_downloadModel": "모델 다운로드", "hub_mv_refresh": "새로고침", "hub_mv_active": "활성", "hub_mv_ready": "준비", "hub_mv_notDownloaded": "미다운로드", "hub_mv_currentUse": "사용 중", "hub_mv_download": "다운로드", "hub_mv_activate": "활성화", "hub_mv_downloadingFmt": "다운로드 중... %d%%", "hub_mv_basicInfo": "기본 정보", "hub_mv_modelId": "모델 ID", "hub_mv_path": "경로", "hub_mv_size": "크기", "hub_mv_format": "형식", "hub_mv_quant": "양자화", "hub_mv_family": "패밀리", "hub_mv_params": "파라미터", "hub_mv_description": "설명", "hub_mv_searchHF": "HuggingFace 모델 검색...", "hub_mv_search": "검색", "hub_mv_recommended": "추천 모델", "hub_mv_repoIdHint": "또는 HuggingFace repo ID 직접 입력", "hub_mv_hfTokenOptional": "HF Token (선택)",
    "hub_dep_stPending": "대기 중",
    "hub_dep_stRunning": "실행 중",
    "hub_dep_stStopped": "중지됨",
    "hub_dep_stFailed": "실패",
    "hub_dep_stUnknown": "알 수 없음",
    "hub_dep_management": "배포 관리",
    "hub_dep_empty": "배포 없음",
    "hub_dep_selectHint": "세부 정보를 보려면 배포 선택",
    "hub_dep_replicasFmt": "%@ 복제본",
    "hub_dep_canaryFmt": "카나리 %d%%",
    "hub_dep_config": "구성",
    "hub_dep_model": "모델",
    "hub_dep_modelName": "모델 이름",
    "hub_dep_strategy": "전략",
    "hub_dep_replicasCount": "복제본 수",
    "hub_dep_canaryRatio": "카나리 비율",
    "hub_dep_createdAt": "생성 시간",
    "hub_dep_updatedAt": "업데이트 시간",
    "hub_dep_metrics": "메트릭",
    "hub_dep_reqPerSec": "요청/초",
    "hub_dep_latencyMs": "지연(ms)",
    "hub_dep_errorRate": "오류율",
    "hub_dep_refreshMetrics": "메트릭 새로고침",
    "hub_dep_actions": "작업",
    "hub_dep_stopDep": "중지",
    "hub_dep_scale": "스케일",
    "hub_dep_grayRelease": "카나리 릴리스",
    "hub_dep_deleteDep": "삭제",
    "hub_dep_stopFailFmt": "중지 실패: %@",
    "hub_dep_scaleFailFmt": "스케일 실패: %@",
    "hub_dep_grayFailFmt": "카나리 릴리스 실패: %@",
    "hub_dep_deleteFailFmt": "삭제 실패: %@",
    "hub_dep_metricsFailFmt": "메트릭 로드 실패: %@",
    "hub_dep_createDep": "배포 생성",
    "hub_dep_modelId": "모델 ID",
    "hub_dep_depStrategy": "배포 전략",
    "hub_dep_replicasStepperFmt": "복제본 수: %d",
    "hub_dep_canaryStepperFmt": "카나리 비율: %d%%", "hub_cls_modelCountFmt": "%d 모델",
    "hub_mkt_searchPlaceholder": "모델 검색...",
    "hub_mkt_sourceAll": "모든 소스",
    "hub_mkt_sourceLocal": "로컬",
    "hub_mkt_sourcePrivate": "개인 저장소",
    "hub_mkt_taskAll": "모든 작업",
    "hub_mkt_taskTextGen": "텍스트 생성",
    "hub_mkt_taskCode": "코드",
    "hub_mkt_taskVision": "비전",
    "hub_mkt_taskEmbedding": "임베딩",
    "hub_mkt_taskAudio": "오디오",
    "hub_mkt_taskMultimodal": "멀티모달",
    "hub_mkt_formatAll": "모든 형식",
    "hub_mkt_paramSizeAll": "모든 크기",
    "hub_mkt_localOnly": "로컬만",
    "hub_mkt_loadMoreFmt": "더 불러오기 (%d/%d)",
    "hub_mkt_emptyTitle": "HuggingFace / ModelScope / 개인 저장소 검색",
    "hub_mkt_emptyHint": "다중 소스 검색, 형식/크기/작업 필터",
    "hub_mkt_download": "다운로드",
    "hub_mkt_convertMLX": "MLX로 변환",
    "hub_mkt_addBenchmark": "벤치마크 추가",
    "hub_mkt_ragDefault": "RAG 기본",
    "hub_mkt_ragDefaultCurrent": "현재 RAG 기본 임베딩 모델",
    "hub_mkt_ragDefaultSet": "RAG 기본 임베딩 모델로 설정",
    "hub_mkt_size": "크기",
    "hub_mkt_downloads": "다운로드 수",
    "hub_mkt_likes": "좋아요",
    "hub_mkt_license": "라이선스",
    "hub_mkt_author": "작성자",
    "hub_mkt_selectModelHint": "모델을 선택해 상세 보기",
    "hub_mkt_pickerSource": "소스",
    "hub_mkt_pickerTask": "작업",
    "hub_mkt_pickerFormat": "형식",
    "hub_mkt_pickerParam": "파라미터",
    "hub_mkt_downloadFailFmt": "다운로드 실패: %@",
    "hub_mkt_mlxFailFmt": "MLX 변환 다운로드 실패: %@",
    "hub_mkt_benchFailFmt": "벤치마크 트리거 실패: %@",
    "hub_main_secDashboard": "대시보드",
    "hub_main_secMarket": "모델 마켓",
    "hub_main_secLocalStorage": "로컬 저장소",
    "hub_main_secConvertQuant": "변환 및 양자화",
    "hub_main_secSchedule": "다운로드 스케줄",
    "hub_main_secCluster": "클러스터",
    "hub_main_secDeployment": "배포",
    "hub_main_secPermission": "권한",
    "hub_main_secMonitor": "모니터",
    "hub_main_secBenchmark": "벤치마크",
    "hub_main_secSecurity": "보안 센터",
    "hub_main_noKeyMsg": "API Key 미설정. 보호된 엔드포인트는 401 반환. 권한에서 Key 생성하세요.",
    "hub_main_goCreate": "생성하러 가기",
    "hub_main_connected": "연결됨",
    "hub_main_disconnected": "연결 안 됨",
    "hub_main_serviceNotConnected": "Model Hub 서비스 미연결",
    "hub_main_serviceHintFmt": "fusion-model-hub 서비스 실행 확인 (포트 %d)",
    "hub_main_retry": "재연결",
    "hub_ver_draft": "초안",
    "hub_ver_testing": "테스트 중",
    "hub_ver_published": "게시됨",
    "hub_ver_deprecated": "폐기됨",
    "hub_ver_retired": "단종",
    "hub_role_admin": "관리자",
    "hub_role_developer": "개발자",
    "hub_role_viewer": "조회자",
    "hub_role_custom": "사용자 정의",
    "hub_lvl_l1": "L1 자동 승인",
    "hub_lvl_l2": "L2 관리자 승인",
    "hub_lvl_l3": "L3 보안 승인",
    "hub_lvl_unknown": "알 수 없음",
    "doc_tab_editor": "에디터",
    "doc_tab_graph": "지식 그래프",
    "doc_tab_versions": "버전 기록",
    "doc_tab_office": "Office",
    "doc_tab_workflow": "워크플로우",
    "doc_tab_template": "템플릿",
    "doc_tab_search": "검색",
    "doc_tab_comments": "댓글",
    "doc_tab_favorites": "즐겨찾기",
    "doc_tab_files": "파일",
    "doc_tab_rag": "RAG",
    "doc_tab_activity": "활동",
    "doc_aiCopilot": "AI Copilot",
    "doc_selPageVersions": "페이지를 선택해 버전 기록 보기",
    "doc_auth_title": "Fusion Doc 인증",
    "doc_auth_mode": "모드",
    "doc_auth_login": "로그인",
    "doc_auth_setup": "초기 설정",
    "doc_auth_username": "사용자명",
    "doc_auth_password": "비밀번호",
    "doc_auth_confirmPwd": "비밀번호 확인",
    "doc_auth_createAdmin": "관리자 생성",
    "doc_auth_authenticated": "인증됨 ✓",
    "doc_cmt_title": "댓글",
    "doc_cmt_empty": "댓글이 아직 없습니다",
    "doc_cmt_reply": "답글",
    "doc_cmt_replyLabel": "댓글에 답글",
    "doc_cmt_replyPlaceholder": "댓글에 답글...",
    "doc_cmt_addPlaceholder": "댓글 추가...",
    "doc_cmt_selPage": "페이지를 선택해 댓글 보기",
    "doc_fav_title": "즐겨찾기",
    "doc_fav_empty": "즐겨찾기가 아직 없습니다",
    "doc_fav_addHint": "페이지에서 별을 눌러 즐겨찾기 추가",
    "doc_fav_noTitle": "제목 없음",
    "doc_file_title": "첨부파일",
    "doc_file_countFmt": "%d 파일",
    "doc_file_empty": "첨부파일이 아직 없습니다",
    "doc_file_unknown": "알 수 없는 파일",
    "doc_file_upload": "첨부파일 업로드",
    "doc_file_name": "파일명",
    "doc_file_uploadBtn": "업로드",
    "doc_file_selPage": "페이지를 선택해 첨부파일 보기",
    "doc_ws_title": "워크스페이스",
    "doc_ws_empty": "워크스페이스가 아직 없습니다",
    "doc_ws_createFirst": "첫 워크스페이스 만들기",
    "doc_ws_name": "이름",
    "doc_ws_descOptional": "설명（선택）",
    "doc_ws_create": "만들기",
    "doc_ws_delete": "삭제",
    "doc_act_title": "활동 로그",
    "doc_act_empty": "활동 기록이 아직 없습니다",
    "doc_act_evPageCreate": "📄 페이지 생성",
    "doc_act_evPageUpdate": "✏️ 페이지 수정",
    "doc_act_evPageDelete": "🗑️ 페이지 삭제",
    "doc_act_evCommentCreate": "💬 댓글 추가",
    "doc_act_evFavAdd": "⭐ 즐겨찾기 추가",
    "doc_act_evFavRemove": "☆ 즐겨찾기 해제",
    "doc_act_evVerCreate": "🔖 버전 생성",
    "doc_act_evWorkflowRun": "🔄 워크플로우 실행",
    "doc_act_evFileUpload": "📎 파일 업로드",
    "doc_cp_modeChat": "대화",
    "doc_cp_modeCommand": "명령",
    "doc_cp_modeRag": "지식",
    "doc_cp_modeRewrite": "수정",
    "doc_cp_modeTranslate": "번역",
    "doc_cp_modeSummarize": "요약",
    "doc_cp_modeExpand": "확장",
    "doc_cp_targetLang": "대상 언어",
    "doc_cp_clearChat": "대화 비우기",
    "doc_cp_thinking": "생각 중...",
    "doc_cp_phChat": "메시지 입력...",
    "doc_cp_phCommand": "/command ...",
    "doc_cp_phRewrite": "수정 지시 입력...",
    "doc_cp_phTranslateFmt": "%@로 번역할 텍스트 입력...",
    "doc_cp_phSummarize": "요약할 텍스트 입력...",
    "doc_cp_phExpand": "확장할 텍스트 입력...",
    "doc_cp_phRag": "지식 검색...",
    "doc_cp_errCopilotURL": "Copilot URL 사용 불가",
    "doc_cp_errCommandURL": "Command URL 사용 불가",
    "doc_cp_errNoData": "응답 데이터 없음",
    "doc_cp_emptyResp": "(빈 응답)",
    "doc_cp_ragChunksPrefix": "📚 관련 지식 조각:",
    "doc_cp_ragNoResult": "관련 결과 없음",
    "doc_cp_rewriteResultPrefix": "✏️ 수정 결과: ",
    "doc_cp_translateResultFmt": "🌐 번역 결과(%@): ",
    "doc_cp_summarizePrefix": "📋 요약: ",
    "doc_cp_expandPrefix": "📖 확장 내용: ",
    "doc_cp_noResult": "(결과 없음)",
    "doc_cp_errPrefix": "❌ ",
    "doc_graph_title": "지식 그래프",
    "doc_graph_filterAll": "전체",
    "doc_graph_filterLink": "링크",
    "doc_graph_filterSemantic": "의미",
    "doc_graph_filterTag": "태그",
    "doc_graph_searchNode": "노드 검색...",
    "doc_graph_refreshHelp": "그래프 새로고침",
    "doc_graph_loading": "그래프 로딩 중...",
    "doc_graph_linkCountFmt": "링크 수: %d",
    "doc_graph_openPage": "페이지 열기",
    "doc_graph_empty": "그래프 데이터가 아직 없습니다",
    "doc_graph_emptyHint": "페이지 간 링크를 만들면 지식 그래프가 자동 생성됩니다",
    "doc_rag_title": "RAG 지식 강화",
    "doc_rag_semanticQuery": "의미 검색",
    "doc_rag_queryPlaceholder": "질문 입력...",
    "doc_rag_answer": "답변",
    "doc_rag_chunksFmt": "관련 조각 (%d)",
    "doc_rag_pageChunks": "페이지 인덱스 단락",
    "doc_rag_noChunks": "인덱스 단락이 아직 없습니다",
    "doc_rag_loadChunks": "단락 불러오기",
    "doc_rag_indexMgmt": "인덱스 관리",
    "doc_rag_reindexAll": "전체 인덱스 재구축",
    "doc_rag_reindexPage": "현재 페이지 인덱스 재구축",
    "doc_rag_queryFailFmt": "검색 실패: %@",
    "doc_search_placeholder": "문서 검색...",
    "doc_search_type": "유형",
    "doc_search_typeAll": "전체",
    "doc_search_typePage": "페이지",
    "doc_search_typeBook": "북",
    "doc_search_sort": "정렬",
    "doc_search_sortRelevance": "관련도",
    "doc_search_sortDate": "날짜",
    "doc_search_sortTitle": "제목",
    "doc_search_resultFmt": "%d건",
    "doc_search_hintKeyword": "키워드 입력해 문서 검색",
    "doc_search_noResult": "검색 결과 없음",
    "doc_tpl_newTitle": "새 템플릿",
    "doc_tpl_name": "이름",
    "doc_tpl_typeHint": "유형 (report/letter/...)",
    "doc_tpl_category": "분류",
    "doc_tpl_create": "만들기",
    "doc_tpl_title": "템플릿",
    "doc_tpl_newHelp": "새 템플릿",
    "doc_tpl_empty": "템플릿이 아직 없습니다",
    "doc_tpl_extractVars": "변수 추출",
    "doc_tpl_delete": "템플릿 삭제",
    "doc_tpl_content": "템플릿 내용",
    "doc_tpl_variables": "템플릿 변수",
    "doc_tpl_inputVarFmt": "%@ 입력",
    "doc_tpl_useCreate": "템플릿으로 만들기",
    "doc_tpl_selDetail": "템플릿 선택해 상세 보기",
    "doc_ver_title": "버전 기록",
    "doc_ver_snapshot": "스냅샷",
    "doc_ver_snapshotHelp": "버전 스냅샷 생성",
    "doc_ver_compare": "비교",
    "doc_ver_compareHelp": "선택 버전 비교",
    "doc_ver_empty": "버전 기록이 아직 없습니다",
    "doc_ver_versionFmt": "버전 %d",
    "doc_ver_setV1": "V1(이전 버전)로 설정",
    "doc_ver_setV2": "V2(새 버전)로 설정",
    "doc_ver_restore": "이 버전 복원",
    "doc_ver_compareTitle": "버전 비교",
    "doc_ver_diffFmt": "V%d → V%d",
    "doc_office_fmtDocx": "Word 문서",
    "doc_office_fmtXlsx": "Excel 스프레드시트",
    "doc_office_fmtPptx": "PowerPoint 프레젠테이션",
    "doc_office_title": "Office 제어",
    "doc_office_cliStatus": "OfficeCLI 상태",
    "doc_office_versionFmt": "버전: %@",
    "doc_office_formatsFmt": "지원 형식: %@",
    "doc_office_detecting": "감지 중...",
    "doc_office_create": "문서 만들기",
    "doc_office_filename": "파일명",
    "doc_office_createBtn": "만들기",
    "doc_office_import": "문서 가져오기",
    "doc_office_filePath": "파일 경로",
    "doc_office_importBtn": "가져오기",
    "doc_office_export": "페이지 내보내기",
    "doc_office_pageId": "페이지 ID",
    "doc_office_format": "형식",
    "doc_office_exportBtn": "내보내기",
    "doc_office_merge": "템플릿 병합",
    "doc_office_templateName": "템플릿명",
    "doc_office_dataJson": "데이터 JSON",
    "doc_office_mergeBtn": "병합",
    "doc_office_cmdTitle": "Office 명령",
    "doc_office_cmdFile": "파일",
    "doc_office_cmdAction": "명령",
    "doc_office_executeBtn": "실행",
    "doc_office_importDir": "일괄 가져오기 디렉터리",
    "doc_office_dirPath": "디렉터리 경로",
    "doc_wf_newTitle": "새 워크플로우",
    "doc_wf_name": "이름",
    "doc_wf_desc": "설명",
    "doc_wf_create": "만들기",
    "doc_wf_title": "워크플로우",
    "doc_wf_newHelp": "새로 만들기",
    "doc_wf_seedHelp": "시드 워크플로우",
    "doc_wf_empty": "워크플로우가 아직 없습니다",
    "doc_wf_delete": "워크플로우 삭제",
    "doc_wf_yamlDef": "YAML 정의",
    "doc_wf_runInput": "실행 입력",
    "doc_wf_runBtn": "워크플로우 실행",
    "doc_wf_runHistory": "실행 기록",
    "doc_wf_selDetail": "워크플로우 선택해 상세 보기",
    "doc_wf_transitionTitle": "페이지 상태 전환",
    "doc_wf_queryBtn": "조회",
    "doc_wf_currentStateFmt": "현재 상태: %@",
    "doc_wf_executeBtn": "실행",
    "proj_subtitle": "AI 프로젝트·지시·지식베이스 관리",
    "proj_searchPh": "프로젝트 검색",
    "proj_newHelp": "새 프로젝트",
    "proj_archivedFmt": "보관됨 (%d)",
    "proj_fileCountFmt": "%d 파일",
    "proj_chatCountFmt": "%d 채팅",
    "proj_archivedSuffix": " (보관됨)",
    "proj_unarchiveBtn": "보관 해제",
    "proj_upstreamBanner": "일부 서비스 사용 불가",
    "proj_emptyDetail": "프로젝트를 선택해 상세 보기",
    "proj_loadFailFmt": "로드 실패: %@",
    "proj_deleteFailFmt": "삭제 실패: %@",
    "proj_minAgoFmt": "%d분 전",
    "proj_hourAgoFmt": "%d시간 전",
    "proj_dayAgoFmt": "%d일 전",
    "proj_sortLastUpdated": "최근 업데이트",
    "proj_sortDateCreated": "생성 시간",
    "proj_sortAlphabetical": "이름순",
    "proj_menuUnstar": "즐겨찾기 해제",
    "proj_menuStar": "프로젝트 즐겨찾기",
    "proj_menuRename": "이름 변경",
    "proj_menuDuplicate": "프로젝트 복제",
    "proj_menuExport": "프로젝트 내보내기",
    "proj_menuArchive": "프로젝트 보관",
    "proj_menuDelete": "프로젝트 삭제",
    "proj_menuSettings": "프로젝트 설정",
    "proj_deleteAlertTitle": "⚠️ 프로젝트 삭제",
    "proj_deleteConfirm": "삭제 확인",
    "proj_deleteAlertMsgFmt": "프로젝트 \"%@\"를 영구 삭제하시겠습니까? 되돌릴 수 없습니다.",
    "proj_deleteAlertMsgFullFmt": "프로젝트 \"%@\"를 영구 삭제하시겠습니까?\n· 프로젝트 지시와 모든 버전 스냅샷\n· 지식베이스 전체 파일(%d 파일)\n· 프로젝트 내 전체 채팅(%d 채팅)\n되돌릴 수 없습니다.",
    "proj_renameTitle": "프로젝트 이름 변경",
    "proj_namePh": "프로젝트 이름",
    "proj_createTitle": "새 프로젝트 만들기",
    "proj_createNameLabel": "프로젝트 이름 *",
    "proj_createDescLabel": "설명",
    "proj_createDescPh": "설명 (선택)",
    "proj_createInstructions": "프로젝트 지시",
    "proj_createCharCountFmt": "글자 수: %d/%d",
    "proj_createInstructionsHint": "여기서 역할·출력 사양·비즈니스 제약 정의. 모든 채팅에 자동 상속.",
    "proj_createDefaultAgent": "기본 에이전트",
    "proj_createNoAgent": "바인딩 안 함 (순수 모델 대화)",
    "proj_createNoAgentShort": "바인딩 안 함",
    "proj_createGotoAgentStudio": "Agent Studio에서 새 에이전트 만들기",
    "proj_createPromptMerge": "Prompt 병합 전략",
    "proj_createMergeAgentFirst": "Agent Prompt 우선 (권장)",
    "proj_createMergeProjectOnly": "프로젝트 Instructions만 사용",
    "proj_createRagMode": "RAG 검색 모드",
    "proj_createRagAuto": "AUTO (스마트 검색)",
    "proj_createRagManual": "MANUAL (수동 지정)",
    "proj_createRagOff": "OFF (사용 안 함)",
    "proj_createBtn": "프로젝트 만들기",
    "proj_editModeMarkdown": "Markdown",
    "proj_editModeRichText": "리치 텍스트",
    "proj_dupTitle": "프로젝트 복제",
    "proj_dupNameLabel": "새 프로젝트 이름",
    "proj_dupCopySuffix": " (사본)",
    "proj_dupScope": "복제 범위",
    "proj_dupScopeInstructionsOnly": "지시 + 지식베이스 파일만 (권장)",
    "proj_dupScopeWithSnapshots": "지시 + 지식베이스 + 모든 채팅 스냅샷",
    "proj_dupBtn": "복제",
    "proj_detailArchived": "보관됨",
    "proj_detailImportCowork": "CoWork 가져오기",
    "proj_tabInstructions": "지시",
    "proj_tabKnowledge": "지식베이스",
    "proj_tabChats": "채팅",
    "proj_instTitle": "프로젝트 지시",
    "proj_instEmpty": "프로젝트 지시 없음",
    "proj_instEmptyHint": "편집 버튼으로 지시 추가. 모든 채팅에 자동 상속.",
    "proj_instHistoryTitle": "📋 Instructions 버전 기록",
    "proj_instHistoryEmpty": "버전 기록 없음",
    "proj_instHistoryCurrentFmt": "V%d",
    "proj_instHistoryCurrentTag": " (현재 버전)",
    "proj_instHistoryRestore": "복원",
    "proj_kbTitle": "지식베이스",
    "proj_kbFileCountFmt": "%d 파일",
    "proj_kbFolder": "폴더",
    "proj_kbAddFile": "파일 추가",
    "proj_kbEmpty": "지식베이스 파일 없음",
    "proj_kbEmptyHint": "문서 업로드로 AI가 프로젝트를 더 잘 이해하도록",
    "proj_kbNewFolderAlert": "새 폴더",
    "proj_kbFolderNamePh": "폴더 이름",
    "proj_kbCreate": "만들기",
    "proj_kbStatusIndexed": "인덱싱됨",
    "proj_kbStatusIndexing": "인덱싱 중",
    "proj_kbStatusFailed": "파싱 실패",
    "proj_kbStatusPending": "인덱싱 대기",
    "proj_kbMenuPreview": "미리보기",
    "proj_kbMenuRename": "이름 변경",
    "proj_kbMenuReplace": "파일 교체",
    "proj_kbMenuMove": "폴더로 이동...",
    "proj_kbMenuRemove": "지식베이스에서 제거",
    "proj_chatsTitle": "채팅",
    "proj_chatsSnapshots": "스냅샷",
    "proj_chatsSnapMsgCountFmt": "%d 메시지",
    "proj_chatsEmpty": "채팅을 선택하거나 만드세요",
    "proj_chatsHint": "알림",
    "proj_chatsCreateFailFmt": "채팅 생성 실패: %@\nfusion-projects 서비스 실행을 확인하세요.",
    "proj_chatsSendFailFmt": "전송 실패: %@",
    "proj_chatsNoModel": "대화 모델 미선택. 상단 모델 선택기에서 선택 후 전송.",
    "proj_chatsReplyFailFmt": "AI 응답 실패: %@",
    "proj_ragSources": "출처: ",
    "proj_ragModeLabelFmt": "검색 모드: %@",
    "proj_ragSwitchAuto": "AUTO로 전환",
    "proj_ragSwitchManual": "MANUAL로 전환",
    "proj_inputUseDefaultAgent": "프로젝트 기본 에이전트 사용",
    "proj_inputGenericChat": "일반 대화 (에이전트 바인딩 없음)",
    "proj_inputPreviewAgent": "현재 에이전트 미리보기",
    "proj_inputRagLabelFmt": "RAG: %@",
    "proj_inputRagAuto": "AUTO (스마트)",
    "proj_inputRagManual": "MANUAL (수동)",
    "proj_inputRagOff": "OFF (끄기)",
    "proj_inputAttachTemp": "임시 첨부",
    "proj_inputAttachScreenshot": "스크린샷",
    "proj_inputAttachWebSearch": "WebSearch",
    "proj_inputAttachSkill": "스킬 도구",
    "proj_inputPlaceholder": "메시지 입력…",
    "proj_budgetLow": "⚠️ 예산 부족",
    "proj_chatMenuUnstar": "즐겨찾기 해제",
    "proj_chatMenuStar": "채팅 즐겨찾기",
    "proj_chatMenuRename": "채팅 이름 변경",
    "proj_chatMenuFork": "채팅 포크",
    "proj_chatMenuSnapshot": "스냅샷 만들기",
    "proj_chatMenuMove": "다른 프로젝트로 이동",
    "proj_chatMenuRemove": "프로젝트에서 제거",
    "proj_chatMenuDelete": "채팅 삭제",
    "proj_chatDeleteAlertTitle": "채팅 삭제?",
    "proj_agentConfigTitle": "에이전트 설정",
    "proj_agentConfigDefault": "기본 에이전트",
    "proj_agentConfigPromptMerge": "Prompt 병합 전략",
    "proj_ragConfigTitle": "RAG 설정",
    "proj_ragConfigMode": "검색 모드",
    "proj_ragConfigTopKFmt": "Top-K: %d",
    "proj_ragConfigThresholdFmt": "유사도 임계값: %@",
    "proj_ragConfigSelectScope": "검색 범위 선택",
    "proj_settingsTitleFmt": "⚙️ 프로젝트 설정 — %@",
    "proj_settingsBasicInfo": "프로젝트 정보",
    "proj_settingsNameLabel": "프로젝트 이름",
    "proj_settingsDescLabel": "설명",
    "proj_settingsDescPh": "설명",
    "proj_settingsAgentConfig": "에이전트 설정",
    "proj_settingsPromptMerge": "Prompt 병합 전략",
    "proj_settingsMergeAgentFirst": "Agent Prompt 우선 (권장)\n에이전트 페르소나 + 프로젝트 비즈니스 규칙 결합",
    "proj_settingsMergeProjectOnly": "프로젝트 Instructions만\n에이전트 내장 Prompt 무시, 완전 프로젝트 맞춤",
    "proj_settingsRagConfig": "RAG 설정",
    "proj_settingsRagAuto": "AUTO (스마트 검색 — Claude Projects 대응)",
    "proj_settingsRagManual": "MANUAL (수동 폴더/파일 검색)",
    "proj_settingsTopK": "TopK",
    "proj_settingsThreshold": "유사도 임계값",
    "proj_settingsSaveBtn": "설정 저장",
    "proj_previewUnbound": "바인딩 없음",
    "proj_previewRole": "역할 소개",
    "proj_previewActiveConfig": "현재 적용 설정",
    "proj_previewPromptStrategyFmt": "· Prompt 전략: %@",
    "proj_previewPromptAgentFirst": "에이전트 우선",
    "proj_previewPromptProjectOnly": "프로젝트 Instructions만",
    "proj_previewRagModeFmt": "· RAG 모드: %@ (TopK=%d, 임계값=%@)",
    "proj_previewAccessKb": "· 이 프로젝트 지식베이스 접근 가능",
    "proj_previewUnboundHint": "에이전트 미바인딩. 순수 모델 대화 사용.",
    "proj_previewGotoAgentStudio": "Agent Studio에서 편집",
    "proj_coworkTitle": "CoWork 스페이스로 가져오기",
    "proj_coworkTarget": "대상 CoWork 스페이스",
    "proj_coworkTargetPlaceholder": "(CoWork 스페이스 목록)",
    "proj_coworkSyncContent": "동기화 내용",
    "proj_coworkSyncKnowledge": "지식베이스 전체 파일",
    "proj_coworkSyncSnapshots": "선택한 채팅 스냅샷",
    "proj_coworkWarning": "지식베이스 파일은 CoWork 스페이스로 복사되며, 이후 변경사항은 자동 동기화되지 않습니다.",
    "proj_coworkConfirm": "가져오기 확인",
    "proj_ragScopeTitle": "🔍 검색 범위 설정",
    "proj_ragScopeMode": "검색 모드",
    "proj_ragScopeAuto": "AUTO (스마트 전역 검색)",
    "proj_ragScopeManual": "MANUAL (수동 범위 지정)",
    "proj_ragScopeSpecify": "검색 범위 지정",
    "proj_ragScopeConfirm": "확인",
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