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
    case filter = "filter"
    case clear = "clear"
    case retry = "retry"
    case add = "add"

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
    case secTrainer = "secTrainer"

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
    case mod_trainer = "mod_trainer"

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
    case proj_panelTitle = "proj_panelTitle"
    case proj_panelSort = "proj_panelSort"
    case proj_panelNew = "proj_panelNew"
    case proj_emptyTitle = "proj_emptyTitle"
    case proj_emptyHint = "proj_emptyHint"
    case proj_panelNewProject = "proj_panelNewProject"
    case proj_tokensFmt = "proj_tokensFmt"
    case proj_panelKbEmpty = "proj_panelKbEmpty"
    case proj_panelAutoScan = "proj_panelAutoScan"
    case proj_panelCustomInst = "proj_panelCustomInst"
    case proj_panelChatHistory = "proj_panelChatHistory"
    case proj_panelNewChat = "proj_panelNewChat"
    case proj_sessionsFmt = "proj_sessionsFmt"
    case proj_panelChatEmpty = "proj_panelChatEmpty"
    case proj_panelStartConv = "proj_panelStartConv"
    case proj_msgsFmt = "proj_msgsFmt"
    case proj_panelSelect = "proj_panelSelect"
    case proj_panelOpenFolder = "proj_panelOpenFolder"
    case proj_panelOpen = "proj_panelOpen"
    case proj_panelAddKbFiles = "proj_panelAddKbFiles"
    case proj_panelDefaultModel = "proj_panelDefaultModel"
    case proj_panelModelPh = "proj_panelModelPh"
    case proj_panelDefault = "proj_panelDefault"
    case proj_panelTempFmt = "proj_panelTempFmt"
    case proj_panelMaxTokensFmt = "proj_panelMaxTokensFmt"
    case proj_panelAutoLoadClaude = "proj_panelAutoLoadClaude"
    case proj_panelAutoScanKb = "proj_panelAutoScanKb"
    case proj_tabSessions = "proj_tabSessions"
    case proj_tabSettings = "proj_tabSettings"
    case cw_snap_title = "cw_snap_title"
    case cw_snap_create = "cw_snap_create"
    case cw_snap_empty = "cw_snap_empty"
    case cw_snap_emptyHint = "cw_snap_emptyHint"
    case cw_snap_labelPh = "cw_snap_labelPh"
    case cw_snap_createBtn = "cw_snap_createBtn"
    case cw_snap_forkAlert = "cw_snap_forkAlert"
    case cw_snap_forkBtn = "cw_snap_forkBtn"
    case cw_snap_msgFmt = "cw_snap_msgFmt"
    case cw_snap_restoreHelp = "cw_snap_restoreHelp"
    case cw_snap_forkHelp = "cw_snap_forkHelp"
    case cw_snap_deleteHelp = "cw_snap_deleteHelp"
    case cw_snap_forkAlertBtn = "cw_snap_forkAlertBtn"
    case cw_list_subtitle = "cw_list_subtitle"
    case cw_list_searchPh = "cw_list_searchPh"
    case cw_list_newHelp = "cw_list_newHelp"
    case cw_list_marketHelp = "cw_list_marketHelp"
    case cw_filter_all = "cw_filter_all"
    case cw_filter_created = "cw_filter_created"
    case cw_filter_joined = "cw_filter_joined"
    case cw_filter_archived = "cw_filter_archived"
    case cw_list_onboardingTitle = "cw_list_onboardingTitle"
    case cw_list_onboardingBody = "cw_list_onboardingBody"
    case cw_list_createLabel = "cw_list_createLabel"
    case cw_list_archivedTag = "cw_list_archivedTag"
    case cw_list_emptyTitle = "cw_list_emptyTitle"
    case cw_list_emptyHint = "cw_list_emptyHint"
    case cw_list_loadFail = "cw_list_loadFail"
    case cw_create_title = "cw_create_title"
    case cw_create_basic = "cw_create_basic"
    case cw_create_namePh = "cw_create_namePh"
    case cw_create_descPh = "cw_create_descPh"
    case cw_create_mode = "cw_create_mode"
    case cw_create_modeLocal = "cw_create_modeLocal"
    case cw_create_modeP2p = "cw_create_modeP2p"
    case cw_create_modeGateway = "cw_create_modeGateway"
    case cw_create_modeLocalDesc = "cw_create_modeLocalDesc"
    case cw_create_modeP2pDesc = "cw_create_modeP2pDesc"
    case cw_create_modeGatewayDesc = "cw_create_modeGatewayDesc"
    case cw_create_kb = "cw_create_kb"
    case cw_create_kbPh = "cw_create_kbPh"
    case cw_create_ability = "cw_create_ability"
    case cw_create_webSearch = "cw_create_webSearch"
    case cw_create_deepResearch = "cw_create_deepResearch"
    case cw_create_computerUse = "cw_create_computerUse"
    case cw_create_memberUpload = "cw_create_memberUpload"
    case cw_create_memberAgent = "cw_create_memberAgent"
    case cw_create_memberWorkflow = "cw_create_memberWorkflow"
    case cw_create_advanced = "cw_create_advanced"
    case cw_create_maxMembers = "cw_create_maxMembers"
    case cw_create_btn = "cw_create_btn"
    case cw_main_loading = "cw_main_loading"
    case cw_main_deepResearch = "cw_main_deepResearch"
    case cw_main_computerUse = "cw_main_computerUse"
    case cw_main_createSnap = "cw_main_createSnap"
    case cw_main_archive = "cw_main_archive"
    case cw_main_archivedBanner = "cw_main_archivedBanner"
    case cw_side_members = "cw_side_members"
    case cw_side_files = "cw_side_files"
    case cw_side_knowledge = "cw_side_knowledge"
    case cw_side_agents = "cw_side_agents"
    case cw_side_artifacts = "cw_side_artifacts"
    case cw_side_workflows = "cw_side_workflows"
    case cw_side_snapshots = "cw_side_snapshots"
    case cw_side_desktop = "cw_side_desktop"
    case cw_side_settings = "cw_side_settings"
    case cw_chat_emptyTitle = "cw_chat_emptyTitle"
    case cw_chat_emptyHint = "cw_chat_emptyHint"
    case cw_chat_thinking = "cw_chat_thinking"
    case cw_chat_copy = "cw_chat_copy"
    case cw_chat_retry = "cw_chat_retry"
    case cw_chat_attach = "cw_chat_attach"
    case cw_chat_screenshot = "cw_chat_screenshot"
    case cw_chat_noAgent = "cw_chat_noAgent"
    case cw_chat_inputPh = "cw_chat_inputPh"
    case cw_chat_relay = "cw_chat_relay"
    case cw_chat_relayHint = "cw_chat_relayHint"
    case cw_chat_relayClear = "cw_chat_relayClear"
    case cw_chat_relayDone = "cw_chat_relayDone"
    case cw_chat_streamErr = "cw_chat_streamErr"
    case cw_chat_sendFail = "cw_chat_sendFail"
    case cw_chat_relayFail = "cw_chat_relayFail"
    case cw_system_name = "cw_system_name"
    case cw_comment_title = "cw_comment_title"
    case cw_comment_addPh = "cw_comment_addPh"
    case cw_comment_send = "cw_comment_send"
    case cw_member_title = "cw_member_title"
    case cw_member_lanDiscovery = "cw_member_lanDiscovery"
    case cw_member_scanning = "cw_member_scanning"
    case cw_member_scan = "cw_member_scan"
    case cw_member_inviteTitle = "cw_member_inviteTitle"
    case cw_member_inviteRole = "cw_member_inviteRole"
    case cw_member_inviteMaxUses = "cw_member_inviteMaxUses"
    case cw_member_inviteExpires = "cw_member_inviteExpires"
    case cw_member_inviteGen = "cw_member_inviteGen"
    case cw_member_inviteCode = "cw_member_inviteCode"
    case cw_member_remove = "cw_member_remove"
    case cw_role_owner = "cw_role_owner"
    case cw_role_admin = "cw_role_admin"
    case cw_role_member = "cw_role_member"
    case cw_role_viewer = "cw_role_viewer"
    case cw_files_title = "cw_files_title"
    case cw_files_empty = "cw_files_empty"
    case cw_agent_title = "cw_agent_title"
    case cw_agent_empty = "cw_agent_empty"
    case cw_agent_add = "cw_agent_add"
    case cw_agent_edit = "cw_agent_edit"
    case cw_agent_copyToProject = "cw_agent_copyToProject"
    case cw_agent_remove = "cw_agent_remove"
    case cw_agent_addTitle = "cw_agent_addTitle"
    case cw_agent_editTitle = "cw_agent_editTitle"
    case cw_agent_name = "cw_agent_name"
    case cw_agent_namePh = "cw_agent_namePh"
    case cw_agent_model = "cw_agent_model"
    case cw_agent_modelPh = "cw_agent_modelPh"
    case cw_agent_perm = "cw_agent_perm"
    case cw_agent_permAll = "cw_agent_permAll"
    case cw_agent_permAdmin = "cw_agent_permAdmin"
    case cw_agent_permCustom = "cw_agent_permCustom"
    case cw_agent_permAllLabel = "cw_agent_permAllLabel"
    case cw_agent_permCustomLabel = "cw_agent_permCustomLabel"
    case cw_snap2_title = "cw_snap2_title"
    case cw_snap2_empty = "cw_snap2_empty"
    case cw_snap2_createTitle = "cw_snap2_createTitle"
    case cw_snap2_namePh = "cw_snap2_namePh"
    case cw_snap2_forkTitle = "cw_snap2_forkTitle"
    case cw_snap2_forkSpacePh = "cw_snap2_forkSpacePh"
    case cw_snap2_restore = "cw_snap2_restore"
    case cw_snap2_forkNew = "cw_snap2_forkNew"
    case cw_snap2_msgCount = "cw_snap2_msgCount"
    case cw_snap2_dagName = "cw_snap2_dagName"
    case cw_art_title = "cw_art_title"
    case cw_art_kindAll = "cw_art_kindAll"
    case cw_art_kindCode = "cw_art_kindCode"
    case cw_art_kindDoc = "cw_art_kindDoc"
    case cw_art_kindViz = "cw_art_kindViz"
    case cw_art_kindData = "cw_art_kindData"
    case cw_art_createTitle = "cw_art_createTitle"
    case cw_art_kindPicker = "cw_art_kindPicker"
    case cw_wf_title = "cw_wf_title"
    case cw_wf_empty = "cw_wf_empty"
    case cw_wf_create = "cw_wf_create"
    case cw_wf_createTitle = "cw_wf_createTitle"
    case cw_wf_namePh = "cw_wf_namePh"
    case cw_wf_descPh = "cw_wf_descPh"
    case cw_wf_nodeCount = "cw_wf_nodeCount"
    case cw_wf_status_running = "cw_wf_status_running"
    case cw_wf_status_completed = "cw_wf_status_completed"
    case cw_wf_status_failed = "cw_wf_status_failed"
    case cw_wf_status_idle = "cw_wf_status_idle"
    case cw_desk_title = "cw_desk_title"
    case cw_desk_role = "cw_desk_role"
    case cw_desk_roleObserver = "cw_desk_roleObserver"
    case cw_desk_roleController = "cw_desk_roleController"
    case cw_desk_roleApprover = "cw_desk_roleApprover"
    case cw_desk_notSharing = "cw_desk_notSharing"
    case cw_desk_controlReq = "cw_desk_controlReq"
    case cw_desk_approve = "cw_desk_approve"
    case cw_desk_reject = "cw_desk_reject"
    case cw_desk_auditLog = "cw_desk_auditLog"
    case cw_desk_sharing = "cw_desk_sharing"
    case cw_set_title = "cw_set_title"
    case cw_set_streamResp = "cw_set_streamResp"
    case cw_research_running = "cw_research_running"
    case cw_research_queryPh = "cw_research_queryPh"
    case cw_research_depth = "cw_research_depth"
    case cw_research_depthShallow = "cw_research_depthShallow"
    case cw_research_depthMedium = "cw_research_depthMedium"
    case cw_research_depthDeep = "cw_research_depthDeep"
    case cw_research_start = "cw_research_start"
    case cw_research_multiAgent = "cw_research_multiAgent"
    case cw_research_autoSelect = "cw_research_autoSelect"
    case cw_research_agentCountFmt = "cw_research_agentCountFmt"
    case cw_research_zeroToken = "cw_research_zeroToken"
    case cw_research_runningProgress = "cw_research_runningProgress"
    case cw_research_desc = "cw_research_desc"
    case cw_research_vsClaude = "cw_research_vsClaude"
    case cw_research_track = "cw_research_track"
    case cw_research_agentProgress = "cw_research_agentProgress"
    case cw_research_noResult = "cw_research_noResult"
    case cw_research_failFmt = "cw_research_failFmt"
    case cw_research_done = "cw_research_done"
    case cw_research_runningStatus = "cw_research_runningStatus"
    case cw_preview_empty = "cw_preview_empty"
    case cw_notif_title = "cw_notif_title"
    case cw_notif_markAll = "cw_notif_markAll"
    case cw_notif_empty = "cw_notif_empty"
    case cw_kb_title = "cw_kb_title"
    case cw_kb_unbound = "cw_kb_unbound"
    case cw_kb_bindHint = "cw_kb_bindHint"
    case cw_kb_bind = "cw_kb_bind"
    case cw_kb_statsFmt = "cw_kb_statsFmt"
    case cw_kb_searchPh = "cw_kb_searchPh"
    case cw_kb_results = "cw_kb_results"
    case cw_kb_ragAnswer = "cw_kb_ragAnswer"
    case cw_kb_upload = "cw_kb_upload"
    case cw_kb_uploadTitle = "cw_kb_uploadTitle"
    case cw_kb_pathPh = "cw_kb_pathPh"
    case cw_kb_uploadBtn = "cw_kb_uploadBtn"
    case cw_kb_docFmt = "cw_kb_docFmt"
    case cw_mkt_title = "cw_mkt_title"
    case cw_mkt_type = "cw_mkt_type"
    case cw_mkt_typeWorkflow = "cw_mkt_typeWorkflow"
    case cw_mkt_typeArtifact = "cw_mkt_typeArtifact"
    case cw_mkt_install = "cw_mkt_install"
    case cw_home_mode_chat = "cw_home_mode_chat"
    case cw_home_mode_cowork = "cw_home_mode_cowork"
    case cw_home_pick_title = "cw_home_pick_title"
    case cw_home_pick_prompt = "cw_home_pick_prompt"
    case cw_home_pick_confirm = "cw_home_pick_confirm"
    case cw_home_no_scoped = "cw_home_no_scoped"
    case cw_home_svc_down = "cw_home_svc_down"
    case cw_home_submit_fail = "cw_home_submit_fail"
    case cw_home_bubble_step = "cw_home_bubble_step"
    case cw_home_bubble_done = "cw_home_bubble_done"
    case cw_home_bubble_error = "cw_home_bubble_error"
    case cw_home_bubble_artifact = "cw_home_bubble_artifact"
    case ai_offline_badge = "ai_offline_badge"
    case ai_offline_helpOff = "ai_offline_helpOff"
    case ai_offline_helpOn = "ai_offline_helpOn"
    case ai_offline_netStatus = "ai_offline_netStatus"
    case ai_offline_offMode = "ai_offline_offMode"
    case ai_offline_onMode = "ai_offline_onMode"
    case ai_offline_reasonFmt = "ai_offline_reasonFmt"
    case ai_offline_disabledTitle = "ai_offline_disabledTitle"
    case ai_offline_featInfer = "ai_offline_featInfer"
    case ai_offline_featKb = "ai_offline_featKb"
    case ai_offline_featCode = "ai_offline_featCode"
    case ai_offline_manual = "ai_offline_manual"
    case ai_audit_title = "ai_audit_title"
    case ai_audit_toolPh = "ai_audit_toolPh"
    case ai_audit_typePh = "ai_audit_typePh"
    case ai_audit_sincePh = "ai_audit_sincePh"
    case ai_audit_sinceHint = "ai_audit_sinceHint"
    case ai_audit_apply = "ai_audit_apply"
    case ai_audit_freq = "ai_audit_freq"
    case ai_audit_empty = "ai_audit_empty"
    case ai_monitor_title = "ai_monitor_title"
    case ai_monitor_refreshFmt = "ai_monitor_refreshFmt"
    case ai_monitor_manualRefresh = "ai_monitor_manualRefresh"
    case ai_monitor_connected = "ai_monitor_connected"
    case ai_monitor_disconnected = "ai_monitor_disconnected"
    case ai_monitor_startMlx = "ai_monitor_startMlx"
    case ai_monitor_availModels = "ai_monitor_availModels"
    case ai_monitor_noModels = "ai_monitor_noModels"
    case ai_monitor_loaded = "ai_monitor_loaded"
    case ai_monitor_load = "ai_monitor_load"
    case ai_monitor_loadingStatus = "ai_monitor_loadingStatus"
    case ai_monitor_errFmt = "ai_monitor_errFmt"
    case ai_perm_title = "ai_perm_title"
    case ai_perm_capsTitle = "ai_perm_capsTitle"
    case ai_perm_empty = "ai_perm_empty"
    case ai_perm_agentFmt = "ai_perm_agentFmt"
    case ai_perm_deniedTitle = "ai_perm_deniedTitle"
    case ai_perm_toolPh = "ai_perm_toolPh"
    case ai_perm_sensitiveTitle = "ai_perm_sensitiveTitle"
    case ai_perm_sensitiveTag = "ai_perm_sensitiveTag"
    case ai_perm_capRead = "ai_perm_capRead"
    case ai_perm_capWrite = "ai_perm_capWrite"
    case ai_perm_capDelete = "ai_perm_capDelete"
    case ai_perm_capCode = "ai_perm_capCode"
    case ai_perm_capNet = "ai_perm_capNet"
    case ai_review_title = "ai_review_title"
    case ai_review_export = "ai_review_export"
    case ai_review_sevCritical = "ai_review_sevCritical"
    case ai_review_sevWarning = "ai_review_sevWarning"
    case ai_review_sevInfo = "ai_review_sevInfo"
    case ai_review_empty = "ai_review_empty"
    case ai_review_exportTitle = "ai_review_exportTitle"
    case ai_review_copy = "ai_review_copy"
    case ai_dash_title = "ai_dash_title"
    case ai_dash_subtitle = "ai_dash_subtitle"
    case ai_dash_statToday = "ai_dash_statToday"
    case ai_dash_statToken = "ai_dash_statToken"
    case ai_dash_statActive = "ai_dash_statActive"
    case ai_dash_statError = "ai_dash_statError"
    case ai_dash_quickTitle = "ai_dash_quickTitle"
    case ai_dash_qaCreate = "ai_dash_qaCreate"
    case ai_dash_qaKb = "ai_dash_qaKb"
    case ai_dash_qaConnector = "ai_dash_qaConnector"
    case ai_dash_qaApiDoc = "ai_dash_qaApiDoc"
    case ai_dash_recentTitle = "ai_dash_recentTitle"
    case ai_dash_recentViewAll = "ai_dash_recentViewAll"
    case ai_dash_empty = "ai_dash_empty"
    case ai_dash_alertTitle = "ai_dash_alertTitle"
    case ai_dash_alertEmpty = "ai_dash_alertEmpty"
    case ai_dash_alertUnknown = "ai_dash_alertUnknown"
    case ai_list_create = "ai_list_create"
    case ai_list_searchPh = "ai_list_searchPh"
    case ai_list_delTitle = "ai_list_delTitle"
    case ai_list_delMsgFmt = "ai_list_delMsgFmt"
    case ai_list_filterFmt = "ai_list_filterFmt"
    case ai_list_hName = "ai_list_hName"
    case ai_list_hStatus = "ai_list_hStatus"
    case ai_list_hModel = "ai_list_hModel"
    case ai_list_hKb = "ai_list_hKb"
    case ai_list_hUpdated = "ai_list_hUpdated"
    case ai_list_hAction = "ai_list_hAction"
    case ai_list_empty = "ai_list_empty"
    case ai_list_emptyHint = "ai_list_emptyHint"
    case ai_list_actDebug = "ai_list_actDebug"
    case ai_list_actEdit = "ai_list_actEdit"
    case ai_list_actClone = "ai_list_actClone"
    case ai_list_actArchive = "ai_list_actArchive"
    case ai_list_actDelete = "ai_list_actDelete"
    case ai_list_scopeAll = "ai_list_scopeAll"
    case ai_list_scopeDraft = "ai_list_scopeDraft"
    case ai_list_scopePublished = "ai_list_scopePublished"
    case ai_list_sortUpdated = "ai_list_sortUpdated"
    case ai_list_sortCreated = "ai_list_sortCreated"
    case ai_list_sortName = "ai_list_sortName"
    case ai_kb_title = "ai_kb_title"
    case ai_kb_searchPh = "ai_kb_searchPh"
    case ai_kb_newBtn = "ai_kb_newBtn"
    case ai_kb_unnamed = "ai_kb_unnamed"
    case ai_kb_createdFmt = "ai_kb_createdFmt"
    case ai_kb_detail = "ai_kb_detail"
    case ai_kb_statusActive = "ai_kb_statusActive"
    case ai_kb_empty = "ai_kb_empty"
    case ai_kb_emptyHint = "ai_kb_emptyHint"
    case ai_kb_sheetTitle = "ai_kb_sheetTitle"
    case ai_kb_sheetName = "ai_kb_sheetName"
    case ai_kb_sheetNamePh = "ai_kb_sheetNamePh"
    case ai_kb_sheetDesc = "ai_kb_sheetDesc"
    case ai_kb_sheetCreate = "ai_kb_sheetCreate"
    case ai_kb_detTitle = "ai_kb_detTitle"
    case ai_kb_detTabFiles = "ai_kb_detTabFiles"
    case ai_kb_detTabInstruction = "ai_kb_detTabInstruction"
    case ai_kb_detTabAgents = "ai_kb_detTabAgents"
    case ai_kb_filesEmpty = "ai_kb_filesEmpty"
    case ai_kb_artRemove = "ai_kb_artRemove"
    case ai_kb_instrTitle = "ai_kb_instrTitle"
    case ai_kb_instrSave = "ai_kb_instrSave"
    case ai_kb_agentsTitle = "ai_kb_agentsTitle"
    case ai_kb_agentsEmpty = "ai_kb_agentsEmpty"
    case ai_chat_welcomeTitle = "ai_chat_welcomeTitle"
    case ai_chat_welcomeHint = "ai_chat_welcomeHint"
    case ai_chat_noAgent = "ai_chat_noAgent"
    case ai_chat_streaming = "ai_chat_streaming"
    case ai_chat_qaSummarize = "ai_chat_qaSummarize"
    case ai_chat_qaCode = "ai_chat_qaCode"
    case ai_chat_qaData = "ai_chat_qaData"
    case ai_chat_qaTranslate = "ai_chat_qaTranslate"
    case ai_chat_qaWrite = "ai_chat_qaWrite"
    case ai_chat_inputPh = "ai_chat_inputPh"
    case ai_chat_toolbox = "ai_chat_toolbox"
    case ai_chat_toolWebSearch = "ai_chat_toolWebSearch"
    case ai_chat_toolResearch = "ai_chat_toolResearch"
    case ai_chat_toolCode = "ai_chat_toolCode"
    case ai_chat_toolKb = "ai_chat_toolKb"
    case ai_chat_pickTitle = "ai_chat_pickTitle"
    case ai_chat_pickEmpty = "ai_chat_pickEmpty"
    case ai_chat_noResponse = "ai_chat_noResponse"
    case ai_chat_rtTitle = "ai_chat_rtTitle"
    case ai_chat_rtMaxTokens = "ai_chat_rtMaxTokens"
    case ai_chat_rtApply = "ai_chat_rtApply"
    case ai_chat_reqFailedFmt = "ai_chat_reqFailedFmt"
    case ai_debug_title = "ai_debug_title"
    case ai_debug_agentFmt = "ai_debug_agentFmt"
    case ai_debug_executing = "ai_debug_executing"
    case ai_debug_ready = "ai_debug_ready"
    case ai_debug_chatEmpty = "ai_debug_chatEmpty"
    case ai_debug_chatEmptyHint = "ai_debug_chatEmptyHint"
    case ai_debug_inputPh = "ai_debug_inputPh"
    case ai_debug_logsTitle = "ai_debug_logsTitle"
    case ai_debug_loadHistory = "ai_debug_loadHistory"
    case ai_debug_logsEmpty = "ai_debug_logsEmpty"
    case ai_debug_logsEmptyHint = "ai_debug_logsEmptyHint"
    case ai_debug_tasksEmpty = "ai_debug_tasksEmpty"
    case ai_debug_tasksEmptyHint = "ai_debug_tasksEmptyHint"
    case ai_debug_lang = "ai_debug_lang"
    case ai_debug_submit = "ai_debug_submit"
    case ai_debug_logReceiveFmt = "ai_debug_logReceiveFmt"
    case ai_debug_noResponse = "ai_debug_noResponse"
    case ai_debug_logExecDone = "ai_debug_logExecDone"
    case ai_debug_logToolFmt = "ai_debug_logToolFmt"
    case ai_debug_logExecFallback = "ai_debug_logExecFallback"
    case ai_debug_logFailFmt = "ai_debug_logFailFmt"
    case ai_debug_tabChat = "ai_debug_tabChat"
    case ai_debug_tabLogs = "ai_debug_tabLogs"
    case ai_debug_tabTasks = "ai_debug_tabTasks"
    case ai_obs_tabUsage = "ai_obs_tabUsage"
    case ai_obs_tabLogs = "ai_obs_tabLogs"
    case ai_obs_tabApikeys = "ai_obs_tabApikeys"
    case ai_obs_tabConnectors = "ai_obs_tabConnectors"
    case ai_obs_tabPermissions = "ai_obs_tabPermissions"
    case ai_obs_tabAudit = "ai_obs_tabAudit"
    case ai_obs_title = "ai_obs_title"
    case ai_obs_subtitle = "ai_obs_subtitle"
    case ai_obs_statToday = "ai_obs_statToday"
    case ai_obs_statToken = "ai_obs_statToken"
    case ai_obs_statActive = "ai_obs_statActive"
    case ai_obs_statError = "ai_obs_statError"
    case ai_obs_alerts = "ai_obs_alerts"
    case ai_obs_logsEmpty = "ai_obs_logsEmpty"
    case ai_obs_apikeysTitle = "ai_obs_apikeysTitle"
    case ai_obs_apikeyCreate = "ai_obs_apikeyCreate"
    case ai_obs_apikeysEmpty = "ai_obs_apikeysEmpty"
    case ai_obs_createdFmt = "ai_obs_createdFmt"
    case ai_obs_rotate = "ai_obs_rotate"
    case ai_obs_revoke = "ai_obs_revoke"
    case ai_obs_connTitle = "ai_obs_connTitle"
    case ai_obs_connAdd = "ai_obs_connAdd"
    case ai_obs_connEmpty = "ai_obs_connEmpty"
    case ai_obs_connConnected = "ai_obs_connConnected"
    case ai_obs_connDisconnected = "ai_obs_connDisconnected"
    case ai_obs_connect = "ai_obs_connect"
    case ai_obs_unnamedKey = "ai_obs_unnamedKey"
    case ai_obs_unnamedConn = "ai_obs_unnamedConn"
    case ai_cfg_tabBasic = "ai_cfg_tabBasic"
    case ai_cfg_tabInstructions = "ai_cfg_tabInstructions"
    case ai_cfg_tabSoul = "ai_cfg_tabSoul"
    case ai_cfg_tabKnowledge = "ai_cfg_tabKnowledge"
    case ai_cfg_tabTools = "ai_cfg_tabTools"
    case ai_cfg_tabAdvanced = "ai_cfg_tabAdvanced"
    case ai_cfg_tabPublish = "ai_cfg_tabPublish"
    case ai_cfg_skillAddTitle = "ai_cfg_skillAddTitle"
    case ai_cfg_skillNamePh = "ai_cfg_skillNamePh"
    case ai_cfg_skillDescPh = "ai_cfg_skillDescPh"
    case ai_cfg_modeCreate = "ai_cfg_modeCreate"
    case ai_cfg_modeEditFmt = "ai_cfg_modeEditFmt"
    case ai_cfg_subCreate = "ai_cfg_subCreate"
    case ai_cfg_subEdit = "ai_cfg_subEdit"
    case ai_cfg_nameLabel = "ai_cfg_nameLabel"
    case ai_cfg_namePh = "ai_cfg_namePh"
    case ai_cfg_descLabel = "ai_cfg_descLabel"
    case ai_cfg_descPh = "ai_cfg_descPh"
    case ai_cfg_modelLabel = "ai_cfg_modelLabel"
    case ai_cfg_modelPicker = "ai_cfg_modelPicker"
    case ai_cfg_modelChoose = "ai_cfg_modelChoose"
    case ai_cfg_visLabel = "ai_cfg_visLabel"
    case ai_cfg_visPrivate = "ai_cfg_visPrivate"
    case ai_cfg_visOrg = "ai_cfg_visOrg"
    case ai_cfg_instrHint = "ai_cfg_instrHint"
    case ai_cfg_charFmt = "ai_cfg_charFmt"
    case ai_cfg_instrSaveTpl = "ai_cfg_instrSaveTpl"
    case ai_cfg_instrRestore = "ai_cfg_instrRestore"
    case ai_cfg_soulHint = "ai_cfg_soulHint"
    case ai_cfg_soulSave = "ai_cfg_soulSave"
    case ai_cfg_soulAfterCreate = "ai_cfg_soulAfterCreate"
    case ai_cfg_kbLabel = "ai_cfg_kbLabel"
    case ai_cfg_kbAdd = "ai_cfg_kbAdd"
    case ai_cfg_ragLabel = "ai_cfg_ragLabel"
    case ai_cfg_ragVector = "ai_cfg_ragVector"
    case ai_cfg_ragFulltext = "ai_cfg_ragFulltext"
    case ai_cfg_ragHybrid = "ai_cfg_ragHybrid"
    case ai_cfg_autoQueryLabel = "ai_cfg_autoQueryLabel"
    case ai_cfg_autoQueryToggle = "ai_cfg_autoQueryToggle"
    case ai_cfg_toolsBuiltin = "ai_cfg_toolsBuiltin"
    case ai_cfg_toolWebSearch = "ai_cfg_toolWebSearch"
    case ai_cfg_toolDeepResearch = "ai_cfg_toolDeepResearch"
    case ai_cfg_skillsLabel = "ai_cfg_skillsLabel"
    case ai_cfg_skillCountFmt = "ai_cfg_skillCountFmt"
    case ai_cfg_skillsEmpty = "ai_cfg_skillsEmpty"
    case ai_cfg_skillsAfterCreate = "ai_cfg_skillsAfterCreate"
    case ai_cfg_connLabel = "ai_cfg_connLabel"
    case ai_cfg_connEmpty = "ai_cfg_connEmpty"
    case ai_cfg_connUnknown = "ai_cfg_connUnknown"
    case ai_cfg_tempHint = "ai_cfg_tempHint"
    case ai_cfg_maxTokenLabel = "ai_cfg_maxTokenLabel"
    case ai_cfg_ctxLabel = "ai_cfg_ctxLabel"
    case ai_cfg_styleLabel = "ai_cfg_styleLabel"
    case ai_cfg_stylePicker = "ai_cfg_stylePicker"
    case ai_cfg_styleDefault = "ai_cfg_styleDefault"
    case ai_cfg_qpsLabel = "ai_cfg_qpsLabel"
    case ai_cfg_qpsUnit = "ai_cfg_qpsUnit"
    case ai_cfg_pubLabel = "ai_cfg_pubLabel"
    case ai_cfg_pubBtn = "ai_cfg_pubBtn"
    case ai_cfg_pubGetApi = "ai_cfg_pubGetApi"
    case ai_cfg_pubSaveFirst = "ai_cfg_pubSaveFirst"
    case ai_cfg_summaryTitle = "ai_cfg_summaryTitle"
    case ai_cfg_sumName = "ai_cfg_sumName"
    case ai_cfg_sumModel = "ai_cfg_sumModel"
    case ai_cfg_sumVis = "ai_cfg_sumVis"
    case ai_cfg_sumKb = "ai_cfg_sumKb"
    case ai_cfg_sumKbUnbound = "ai_cfg_sumKbUnbound"
    case ai_cfg_sumTools = "ai_cfg_sumTools"
    case ai_cfg_sumMaxToken = "ai_cfg_sumMaxToken"
    case ai_cfg_sumConnFmt = "ai_cfg_sumConnFmt"
    case ai_cfg_sumToolsNone = "ai_cfg_sumToolsNone"
    case ai_cfg_deleteBtn = "ai_cfg_deleteBtn"
    case ai_cfg_saveDraft = "ai_cfg_saveDraft"
    case fsb_ws_renameAlertTitle = "fsb_ws_renameAlertTitle"
    case fsb_ws_name = "fsb_ws_name"
    case fsb_ws_exportTitle = "fsb_ws_exportTitle"
    case fsb_ws_copyClipboard = "fsb_ws_copyClipboard"
    case fsb_ws_emptyWorkspaces = "fsb_ws_emptyWorkspaces"
    case fsb_ws_noMatch = "fsb_ws_noMatch"
    case fsb_ws_createWs = "fsb_ws_createWs"
    case fsb_ws_headerTitle = "fsb_ws_headerTitle"
    case fsb_ws_newWs = "fsb_ws_newWs"
    case fsb_ws_listView = "fsb_ws_listView"
    case fsb_ws_gridView = "fsb_ws_gridView"
    case fsb_ws_searchPh = "fsb_ws_searchPh"
    case fsb_unnamed = "fsb_unnamed"
    case fsb_ws_connWfFmt = "fsb_ws_connWfFmt"
    case fsb_ws_open = "fsb_ws_open"
    case fsb_ws_rename = "fsb_ws_rename"
    case fsb_ws_duplicate = "fsb_ws_duplicate"
    case fsb_ws_export = "fsb_ws_export"
    case fsb_ws_subtitle = "fsb_ws_subtitle"
    case fsb_ws_serviceDown = "fsb_ws_serviceDown"
    case fsb_ws_usageGuide = "fsb_ws_usageGuide"
    case fsb_ws_namePh = "fsb_ws_namePh"
    case fsb_ws_descOpt = "fsb_ws_descOpt"
    case fsb_ws_descPh = "fsb_ws_descPh"
    case fsb_ws_bindProjectOpt = "fsb_ws_bindProjectOpt"
    case fsb_ws_projectIdPh = "fsb_ws_projectIdPh"
    case fsb_ws_bindAgentOpt = "fsb_ws_bindAgentOpt"
    case fsb_ws_importTemplate = "fsb_ws_importTemplate"
    case fsb_ws_createBtn = "fsb_ws_createBtn"
    case fsb_ws_builtinTemplates = "fsb_ws_builtinTemplates"
    case fsb_tpl_crm_name = "fsb_tpl_crm_name"
    case fsb_tpl_crm_short = "fsb_tpl_crm_short"
    case fsb_tpl_crm_desc = "fsb_tpl_crm_desc"
    case fsb_tpl_inventory_name = "fsb_tpl_inventory_name"
    case fsb_tpl_inventory_short = "fsb_tpl_inventory_short"
    case fsb_tpl_inventory_desc = "fsb_tpl_inventory_desc"
    case fsb_tpl_finance_name = "fsb_tpl_finance_name"
    case fsb_tpl_finance_short = "fsb_tpl_finance_short"
    case fsb_tpl_finance_desc = "fsb_tpl_finance_desc"
    case fsb_tpl_email_name = "fsb_tpl_email_name"
    case fsb_tpl_email_short = "fsb_tpl_email_short"
    case fsb_tpl_email_desc = "fsb_tpl_email_desc"
    case fsb_tpl_social_name = "fsb_tpl_social_name"
    case fsb_tpl_social_short = "fsb_tpl_social_short"
    case fsb_tpl_social_desc = "fsb_tpl_social_desc"
    case fsb_tpl_ticket_name = "fsb_tpl_ticket_name"
    case fsb_tpl_ticket_short = "fsb_tpl_ticket_short"
    case fsb_tpl_ticket_desc = "fsb_tpl_ticket_desc"
    case fsb_ob_welcome_title = "fsb_ob_welcome_title"
    case fsb_ob_welcome_desc = "fsb_ob_welcome_desc"
    case fsb_ob_connectors_title = "fsb_ob_connectors_title"
    case fsb_ob_connectors_desc = "fsb_ob_connectors_desc"
    case fsb_ob_skills_title = "fsb_ob_skills_title"
    case fsb_ob_skills_desc = "fsb_ob_skills_desc"
    case fsb_ob_workflow_title = "fsb_ob_workflow_title"
    case fsb_ob_workflow_desc = "fsb_ob_workflow_desc"
    case fsb_ob_start_title = "fsb_ob_start_title"
    case fsb_ob_start_desc = "fsb_ob_start_desc"
    case fsb_ob_prev = "fsb_ob_prev"
    case fsb_dlg_addConnector = "fsb_dlg_addConnector"
    case fsb_dlg_connecting = "fsb_dlg_connecting"
    case fsb_dlg_connect = "fsb_dlg_connect"
    case fsb_dlg_selectConnector = "fsb_dlg_selectConnector"
    case fsb_dlg_connector = "fsb_dlg_connector"
    case fsb_dlg_selectPh = "fsb_dlg_selectPh"
    case fsb_dlg_supportFmt = "fsb_dlg_supportFmt"
    case fsb_dlg_authMethod = "fsb_dlg_authMethod"
    case fsb_dlg_auth = "fsb_dlg_auth"
    case fsb_dlg_noAuth = "fsb_dlg_noAuth"
    case fsb_dlg_enterApiKey = "fsb_dlg_enterApiKey"
    case fsb_dlg_scopesHint = "fsb_dlg_scopesHint"
    case fsb_dlg_createSkill = "fsb_dlg_createSkill"
    case fsb_dlg_saving = "fsb_dlg_saving"
    case fsb_dlg_create = "fsb_dlg_create"
    case fsb_dlg_skillName = "fsb_dlg_skillName"
    case fsb_dlg_displayName = "fsb_dlg_displayName"
    case fsb_dlg_mySkill = "fsb_dlg_mySkill"
    case fsb_dlg_type = "fsb_dlg_type"
    case fsb_dlg_prompt = "fsb_dlg_prompt"
    case fsb_dlg_function = "fsb_dlg_function"
    case fsb_dlg_chain = "fsb_dlg_chain"
    case fsb_dlg_definition = "fsb_dlg_definition"
    case fsb_dlg_inputSchema = "fsb_dlg_inputSchema"
    case fsb_dlg_outputFormat = "fsb_dlg_outputFormat"
    case fsb_dlg_plainText = "fsb_dlg_plainText"
    case fsb_dlg_setSchedule = "fsb_dlg_setSchedule"
    case fsb_dlg_triggerMethod = "fsb_dlg_triggerMethod"
    case fsb_dlg_manual = "fsb_dlg_manual"
    case fsb_dlg_cron = "fsb_dlg_cron"
    case fsb_dlg_eventDriven = "fsb_dlg_eventDriven"
    case fsb_dlg_manualOnly = "fsb_dlg_manualOnly"
    case fsb_dlg_cronExpr = "fsb_dlg_cronExpr"
    case fsb_dlg_commonPresets = "fsb_dlg_commonPresets"
    case fsb_dlg_preset_weekday9 = "fsb_dlg_preset_weekday9"
    case fsb_dlg_preset_hourly = "fsb_dlg_preset_hourly"
    case fsb_dlg_preset_daily8 = "fsb_dlg_preset_daily8"
    case fsb_dlg_preset_monday9 = "fsb_dlg_preset_monday9"
    case fsb_dlg_preset_month1 = "fsb_dlg_preset_month1"
    case fsb_dlg_eventTrigger = "fsb_dlg_eventTrigger"
    case fsb_dlg_eventPh = "fsb_dlg_eventPh"
    case fsb_dlg_eventHint = "fsb_dlg_eventHint"
    case fsb_dlg_approvalRequest = "fsb_dlg_approvalRequest"
    case fsb_dlg_requestContent = "fsb_dlg_requestContent"
    case fsb_dlg_editContent = "fsb_dlg_editContent"
    case fsb_dlg_reject = "fsb_dlg_reject"
    case fsb_dlg_processing = "fsb_dlg_processing"
    case fsb_dlg_approve = "fsb_dlg_approve"
    case fsb_wb_sec_connectors = "fsb_wb_sec_connectors"
    case fsb_wb_sec_skills = "fsb_wb_sec_skills"
    case fsb_wb_sec_workflows = "fsb_wb_sec_workflows"
    case fsb_wb_sec_variables = "fsb_wb_sec_variables"
    case fsb_wb_sec_templates = "fsb_wb_sec_templates"
    case fsb_wb_tab_approval = "fsb_wb_tab_approval"
    case fsb_wb_tab_scheduled = "fsb_wb_tab_scheduled"
    case fsb_wb_tab_history = "fsb_wb_tab_history"
    case fsb_wb_tab_sandbox = "fsb_wb_tab_sandbox"
    case fsb_wb_workspace = "fsb_wb_workspace"
    case fsb_wb_connected = "fsb_wb_connected"
    case fsb_wb_noConnector = "fsb_wb_noConnector"
    case fsb_wb_available = "fsb_wb_available"
    case fsb_wb_disconnect = "fsb_wb_disconnect"
    case fsb_wb_connect = "fsb_wb_connect"
    case fsb_wb_skillList = "fsb_wb_skillList"
    case fsb_wb_noSkill = "fsb_wb_noSkill"
    case fsb_wb_test = "fsb_wb_test"
    case fsb_wb_wfList = "fsb_wb_wfList"
    case fsb_wb_noWorkflow = "fsb_wb_noWorkflow"
    case fsb_wb_createWf = "fsb_wb_createWf"
    case fsb_wb_run = "fsb_wb_run"
    case fsb_wb_schedule = "fsb_wb_schedule"
    case fsb_wb_variables = "fsb_wb_variables"
    case fsb_wb_noVariable = "fsb_wb_noVariable"
    case fsb_wb_templates = "fsb_wb_templates"
    case fsb_wb_newWf = "fsb_wb_newWf"
    case fsb_wb_createFirstWf = "fsb_wb_createFirstWf"
    case fsb_wb_nodeCountFmt = "fsb_wb_nodeCountFmt"
    case fsb_wb_taskCenter = "fsb_wb_taskCenter"
    case fsb_wb_noApproval = "fsb_wb_noApproval"
    case fsb_wb_approvalReq = "fsb_wb_approvalReq"
    case fsb_wb_approve = "fsb_wb_approve"
    case fsb_wb_deny = "fsb_wb_deny"
    case fsb_wb_noScheduled = "fsb_wb_noScheduled"
    case fsb_wb_noHistory = "fsb_wb_noHistory"
    case fsb_wb_inputData = "fsb_wb_inputData"
    case fsb_wb_sandboxVars = "fsb_wb_sandboxVars"
    case fsb_wb_snapshots = "fsb_wb_snapshots"
    case fsb_wb_sandboxEmpty = "fsb_wb_sandboxEmpty"
    case fsb_wb_sandboxHint = "fsb_wb_sandboxHint"
    case rag_sec_dashboard = "rag_sec_dashboard"
    case rag_sec_files = "rag_sec_files"
    case rag_sec_chat = "rag_sec_chat"
    case rag_sec_embedConfig = "rag_sec_embedConfig"
    case rag_sec_searchConfig = "rag_sec_searchConfig"
    case rag_sec_permissions = "rag_sec_permissions"
    case rag_sec_vectorOps = "rag_sec_vectorOps"
    case rag_sec_callLog = "rag_sec_callLog"
    case rag_sec_benchEval = "rag_sec_benchEval"
    case rag_currentKb = "rag_currentKb"
    case rag_all = "rag_all"
    case rag_tab_bases = "rag_tab_bases"
    case rag_tab_chat = "rag_tab_chat"
    case rag_tab_search = "rag_tab_search"
    case rag_tab_config = "rag_tab_config"
    case rag_log_title = "rag_log_title"
    case rag_log_total = "rag_log_total"
    case rag_log_successRate = "rag_log_successRate"
    case rag_log_avgLatency = "rag_log_avgLatency"
    case rag_log_search = "rag_log_search"
    case rag_log_ask = "rag_log_ask"
    case rag_log_searchPh = "rag_log_searchPh"
    case rag_log_opPicker = "rag_log_opPicker"
    case rag_log_export = "rag_log_export"
    case rag_log_empty = "rag_log_empty"
    case rag_log_h_time = "rag_log_h_time"
    case rag_log_h_kb = "rag_log_h_kb"
    case rag_log_h_op = "rag_log_h_op"
    case rag_log_h_query = "rag_log_h_query"
    case rag_log_h_result = "rag_log_h_result"
    case rag_log_h_latency = "rag_log_h_latency"
    case rag_log_h_status = "rag_log_h_status"
    case rag_log_exportTitle = "rag_log_exportTitle"
    case rag_log_exportDescFmt = "rag_log_exportDescFmt"
    case rag_log_exportBtn = "rag_log_exportBtn"
    case rag_op_all = "rag_op_all"
    case rag_op_search = "rag_op_search"
    case rag_op_ask = "rag_op_ask"
    case rag_op_ingest = "rag_op_ingest"
    case rag_op_delete = "rag_op_delete"
    case rag_op_watch = "rag_op_watch"
    case rag_op_sync = "rag_op_sync"
    case rag_perm_title = "rag_perm_title"
    case rag_perm_authStatus = "rag_perm_authStatus"
    case rag_perm_apiKeyAuth = "rag_perm_apiKeyAuth"
    case rag_perm_disabled = "rag_perm_disabled"
    case rag_perm_enabled = "rag_perm_enabled"
    case rag_perm_activeKeys = "rag_perm_activeKeys"
    case rag_perm_keyMgmt = "rag_perm_keyMgmt"
    case rag_perm_createKey = "rag_perm_createKey"
    case rag_perm_noKey = "rag_perm_noKey"
    case rag_perm_noKeyHint = "rag_perm_noKeyHint"
    case rag_perm_h_name = "rag_perm_h_name"
    case rag_perm_h_hash = "rag_perm_h_hash"
    case rag_perm_h_createdAt = "rag_perm_h_createdAt"
    case rag_perm_memberRole = "rag_perm_memberRole"
    case rag_perm_role_admin = "rag_perm_role_admin"
    case rag_perm_role_admin_desc = "rag_perm_role_admin_desc"
    case rag_perm_role_edit = "rag_perm_role_edit"
    case rag_perm_role_edit_desc = "rag_perm_role_edit_desc"
    case rag_perm_role_query = "rag_perm_role_query"
    case rag_perm_role_query_desc = "rag_perm_role_query_desc"
    case rag_perm_role_api = "rag_perm_role_api"
    case rag_perm_role_api_desc = "rag_perm_role_api_desc"
    case rag_perm_audit = "rag_perm_audit"
    case rag_perm_auditNote = "rag_perm_auditNote"
    case rag_perm_createTitle = "rag_perm_createTitle"
    case rag_perm_keyNamePh = "rag_perm_keyNamePh"
    case rag_perm_keyCreated = "rag_perm_keyCreated"
    case rag_perm_createBtn = "rag_perm_createBtn"
    case rag_emb_title = "rag_emb_title"
    case rag_emb_model = "rag_emb_model"
    case rag_emb_modelName = "rag_emb_modelName"
    case rag_emb_runMode = "rag_emb_runMode"
    case rag_emb_localMlx = "rag_emb_localMlx"
    case rag_emb_dim768 = "rag_emb_dim768"
    case rag_emb_multilang = "rag_emb_multilang"
    case rag_emb_chunkStrategy = "rag_emb_chunkStrategy"
    case rag_emb_strategyPicker = "rag_emb_strategyPicker"
    case rag_emb_chunkSize = "rag_emb_chunkSize"
    case rag_emb_overlap = "rag_emb_overlap"
    case rag_emb_strategy_semantic = "rag_emb_strategy_semantic"
    case rag_emb_strategy_fixed = "rag_emb_strategy_fixed"
    case rag_emb_strategy_code = "rag_emb_strategy_code"
    case rag_emb_strategy_sentence = "rag_emb_strategy_sentence"
    case rag_emb_tip_semantic = "rag_emb_tip_semantic"
    case rag_emb_tip_fixed = "rag_emb_tip_fixed"
    case rag_emb_tip_code = "rag_emb_tip_code"
    case rag_emb_tip_sentence = "rag_emb_tip_sentence"
    case rag_emb_context = "rag_emb_context"
    case rag_emb_contextToggle = "rag_emb_contextToggle"
    case rag_emb_contextDesc = "rag_emb_contextDesc"
    case rag_emb_saved = "rag_emb_saved"
    case rag_emb_reset = "rag_emb_reset"
    case rag_vec_title = "rag_vec_title"
    case rag_vec_syncAlertTitle = "rag_vec_syncAlertTitle"
    case rag_vec_syncAlertBtn = "rag_vec_syncAlertBtn"
    case rag_vec_syncAlertMsg = "rag_vec_syncAlertMsg"
    case rag_vec_createSnapTitle = "rag_vec_createSnapTitle"
    case rag_vec_snapDescPh = "rag_vec_snapDescPh"
    case rag_vec_create = "rag_vec_create"
    case rag_vec_svcLabel = "rag_vec_svcLabel"
    case rag_vec_embEngine = "rag_vec_embEngine"
    case rag_vec_avail = "rag_vec_avail"
    case rag_vec_unavail = "rag_vec_unavail"
    case rag_vec_kbCount = "rag_vec_kbCount"
    case rag_vec_vecStatsLabel = "rag_vec_vecStatsLabel"
    case rag_vec_docCount = "rag_vec_docCount"
    case rag_vec_chunkCount = "rag_vec_chunkCount"
    case rag_vec_vecCount = "rag_vec_vecCount"
    case rag_vec_fileCount = "rag_vec_fileCount"
    case rag_vec_selectKbHint = "rag_vec_selectKbHint"
    case rag_vec_opsLabel = "rag_vec_opsLabel"
    case rag_vec_opSync = "rag_vec_opSync"
    case rag_vec_opSyncDesc = "rag_vec_opSyncDesc"
    case rag_vec_opSnap = "rag_vec_opSnap"
    case rag_vec_opSnapDesc = "rag_vec_opSnapDesc"
    case rag_vec_opHealth = "rag_vec_opHealth"
    case rag_vec_opHealthDesc = "rag_vec_opHealthDesc"
    case rag_vec_opRefresh = "rag_vec_opRefresh"
    case rag_vec_opRefreshDesc = "rag_vec_opRefreshDesc"
    case rag_vec_snapLabel = "rag_vec_snapLabel"
    case rag_vec_snapCountFmt = "rag_vec_snapCountFmt"
    case rag_vec_snapEmpty = "rag_vec_snapEmpty"
    case rag_vec_snapNote = "rag_vec_snapNote"
    case rag_vec_snapFallback = "rag_vec_snapFallback"
    case rag_vec_rollback = "rag_vec_rollback"
    case rag_vec_syncing = "rag_vec_syncing"
    case rag_vec_syncDoneFmt = "rag_vec_syncDoneFmt"
    case rag_vec_syncFail = "rag_vec_syncFail"
    case rag_vec_creatingSnap = "rag_vec_creatingSnap"
    case rag_vec_snapDoneFmt = "rag_vec_snapDoneFmt"
    case rag_vec_snapFail = "rag_vec_snapFail"
    case rag_vec_rollingBack = "rag_vec_rollingBack"
    case rag_vec_rollbackDoneFmt = "rag_vec_rollbackDoneFmt"
    case rag_vec_rollbackFail = "rag_vec_rollbackFail"
    case rag_vec_svcHealthy = "rag_vec_svcHealthy"
    case rag_vec_svcUnhealthy = "rag_vec_svcUnhealthy"
    case rag_dash_kbTitle = "rag_dash_kbTitle"
    case rag_dash_newBtn = "rag_dash_newBtn"
    case rag_dash_svcHealthy = "rag_dash_svcHealthy"
    case rag_dash_svcUnhealthy = "rag_dash_svcUnhealthy"
    case rag_dash_kbCountFmt = "rag_dash_kbCountFmt"
    case rag_dash_emptyTitle = "rag_dash_emptyTitle"
    case rag_dash_createKb = "rag_dash_createKb"
    case rag_dash_namePh = "rag_dash_namePh"
    case rag_dash_descPh = "rag_dash_descPh"
    case rag_dash_chunkStrategyPh = "rag_dash_chunkStrategyPh"
    case rag_dash_embedModelPh = "rag_dash_embedModelPh"
    case rag_dash_create = "rag_dash_create"
    case rag_dash_scanTitle = "rag_dash_scanTitle"
    case rag_dash_kbPrefix = "rag_dash_kbPrefix"
    case rag_dash_dirPathPh = "rag_dash_dirPathPh"
    case rag_dash_scanBtn = "rag_dash_scanBtn"
    case rag_dash_statFile = "rag_dash_statFile"
    case rag_dash_statChunk = "rag_dash_statChunk"
    case rag_dash_statVec = "rag_dash_statVec"
    case rag_dash_enterBtn = "rag_dash_enterBtn"
    case rag_dash_importBtn = "rag_dash_importBtn"
    case rag_dash_chatMenu = "rag_dash_chatMenu"
    case rag_dash_scanMenu = "rag_dash_scanMenu"
    case rag_file_searchPh = "rag_file_searchPh"
    case rag_file_watchBtn = "rag_file_watchBtn"
    case rag_file_addFileBtn = "rag_file_addFileBtn"
    case rag_file_selectKbHint = "rag_file_selectKbHint"
    case rag_file_emptyDoc = "rag_file_emptyDoc"
    case rag_file_h_name = "rag_file_h_name"
    case rag_file_h_type = "rag_file_h_type"
    case rag_file_h_size = "rag_file_h_size"
    case rag_file_h_chunk = "rag_file_h_chunk"
    case rag_file_h_status = "rag_file_h_status"
    case rag_file_indexed = "rag_file_indexed"
    case rag_file_watchLabel = "rag_file_watchLabel"
    case rag_file_watchEmpty = "rag_file_watchEmpty"
    case rag_file_watchFileFmt = "rag_file_watchFileFmt"
    case rag_file_changesFmt = "rag_file_changesFmt"
    case rag_file_lastReindexFmt = "rag_file_lastReindexFmt"
    case rag_file_stopBtn = "rag_file_stopBtn"
    case rag_file_addFileTitle = "rag_file_addFileTitle"
    case rag_file_addFilePathPh = "rag_file_addFilePathPh"
    case rag_file_addBtn = "rag_file_addBtn"
    case rag_file_watchTitle = "rag_file_watchTitle"
    case rag_file_watchPathPh = "rag_file_watchPathPh"
    case rag_file_pollInterval = "rag_file_pollInterval"
    case rag_file_startWatchBtn = "rag_file_startWatchBtn"
    case rag_srch_title = "rag_srch_title"
    case rag_srch_presetLabel = "rag_srch_presetLabel"
    case rag_srch_preset_general = "rag_srch_preset_general"
    case rag_srch_preset_code = "rag_srch_preset_code"
    case rag_srch_preset_design = "rag_srch_preset_design"
    case rag_srch_presetDesc_general = "rag_srch_presetDesc_general"
    case rag_srch_presetDesc_code = "rag_srch_presetDesc_code"
    case rag_srch_presetDesc_design = "rag_srch_presetDesc_design"
    case rag_srch_weightLabel = "rag_srch_weightLabel"
    case rag_srch_hybridToggle = "rag_srch_hybridToggle"
    case rag_srch_sparseLabel = "rag_srch_sparseLabel"
    case rag_srch_denseLabel = "rag_srch_denseLabel"
    case rag_srch_alphaLabel = "rag_srch_alphaLabel"
    case rag_srch_rerankToggle = "rag_srch_rerankToggle"
    case rag_srch_rerankTip = "rag_srch_rerankTip"
    case rag_srch_paramsLabel = "rag_srch_paramsLabel"
    case rag_srch_topKLabel = "rag_srch_topKLabel"
    case rag_srch_thresholdLabel = "rag_srch_thresholdLabel"
    case rag_srch_rewriteCard = "rag_srch_rewriteCard"
    case rag_srch_rewriteModePicker = "rag_srch_rewriteModePicker"
    case rag_srch_rewriteDesc_none = "rag_srch_rewriteDesc_none"
    case rag_srch_rewriteDesc_expand = "rag_srch_rewriteDesc_expand"
    case rag_srch_rewriteDesc_decompose = "rag_srch_rewriteDesc_decompose"
    case rag_srch_rewriteDesc_hyde = "rag_srch_rewriteDesc_hyde"
    case rag_srch_testLabel = "rag_srch_testLabel"
    case rag_srch_testQueryPh = "rag_srch_testQueryPh"
    case rag_srch_testBtn = "rag_srch_testBtn"
    case rag_srch_rw_none = "rag_srch_rw_none"
    case rag_srch_rw_expand = "rag_srch_rw_expand"
    case rag_srch_rw_decompose = "rag_srch_rw_decompose"
    case rag_srch_rw_hyde = "rag_srch_rw_hyde"
    case rag_bench_title = "rag_bench_title"
    case rag_bench_adv_local = "rag_bench_adv_local"
    case rag_bench_adv_ast = "rag_bench_adv_ast"
    case rag_bench_adv_rrf = "rag_bench_adv_rrf"
    case rag_bench_adv_context = "rag_bench_adv_context"
    case rag_bench_adv_sync = "rag_bench_adv_sync"
    case rag_bench_adv_snap = "rag_bench_adv_snap"
    case rag_bench_presetLabel = "rag_bench_presetLabel"
    case rag_bench_preset_standard = "rag_bench_preset_standard"
    case rag_bench_preset_code = "rag_bench_preset_code"
    case rag_bench_preset_design = "rag_bench_preset_design"
    case rag_bench_customQueryLabel = "rag_bench_customQueryLabel"
    case rag_bench_customEmpty = "rag_bench_customEmpty"
    case rag_bench_addQueryTitle = "rag_bench_addQueryTitle"
    case rag_bench_queryPh = "rag_bench_queryPh"
    case rag_bench_expectedPh = "rag_bench_expectedPh"
    case rag_bench_addBtn = "rag_bench_addBtn"
    case rag_bench_runBtn = "rag_bench_runBtn"
    case rag_bench_hitRateFmt = "rag_bench_hitRateFmt"
    case rag_bench_clearResultsBtn = "rag_bench_clearResultsBtn"
    case rag_bench_resultsLabel = "rag_bench_resultsLabel"
    case rag_bench_resultsEmpty = "rag_bench_resultsEmpty"
    case rag_bench_miniHit = "rag_bench_miniHit"
    case rag_bench_miniLatency = "rag_bench_miniLatency"
    case rag_bench_miniTopScore = "rag_bench_miniTopScore"
    case rag_bench_historyLabel = "rag_bench_historyLabel"
    case rag_bench_historyEmpty = "rag_bench_historyEmpty"
    case fsb_cv_node_start = "fsb_cv_node_start"
    case fsb_cv_node_connector = "fsb_cv_node_connector"
    case fsb_cv_node_skill = "fsb_cv_node_skill"
    case fsb_cv_node_condition = "fsb_cv_node_condition"
    case fsb_cv_node_approval = "fsb_cv_node_approval"
    case fsb_cv_node_output = "fsb_cv_node_output"
    case fsb_cv_node_end = "fsb_cv_node_end"
    case fsb_cv_wfName = "fsb_cv_wfName"
    case fsb_cv_autoLayout = "fsb_cv_autoLayout"
    case fsb_cv_running = "fsb_cv_running"
    case fsb_cv_testRun = "fsb_cv_testRun"
    case fsb_cv_saving = "fsb_cv_saving"
    case fsb_cv_nodeTypes = "fsb_cv_nodeTypes"
    case fsb_cv_hintDrag = "fsb_cv_hintDrag"
    case fsb_cv_hintRightClick = "fsb_cv_hintRightClick"
    case fsb_cv_hintConnect = "fsb_cv_hintConnect"
    case fsb_cv_nodeName = "fsb_cv_nodeName"
    case fsb_cv_deleteNode = "fsb_cv_deleteNode"
    case fsb_cv_connector = "fsb_cv_connector"
    case fsb_cv_selectConnector = "fsb_cv_selectConnector"
    case fsb_cv_notSelected = "fsb_cv_notSelected"
    case fsb_cv_action = "fsb_cv_action"
    case fsb_cv_skill = "fsb_cv_skill"
    case fsb_cv_selectSkill = "fsb_cv_selectSkill"
    case fsb_cv_promptTpl = "fsb_cv_promptTpl"
    case fsb_cv_conditionExpr = "fsb_cv_conditionExpr"
    case fsb_cv_conditionHint = "fsb_cv_conditionHint"
    case fsb_cv_approvalConfig = "fsb_cv_approvalConfig"
    case fsb_cv_approvalMode = "fsb_cv_approvalMode"
    case fsb_cv_writeOnly = "fsb_cv_writeOnly"
    case fsb_cv_allOps = "fsb_cv_allOps"
    case fsb_cv_approvalNote = "fsb_cv_approvalNote"
    case fsb_cv_timeoutFmt = "fsb_cv_timeoutFmt"
    case fsb_cv_outputFormat = "fsb_cv_outputFormat"
    case fsb_cv_format = "fsb_cv_format"
    case fsb_cv_plainText = "fsb_cv_plainText"
    case fsb_cv_addNode = "fsb_cv_addNode"
    case fsb_cv_newWorkflow = "fsb_cv_newWorkflow"
    case mn_kv_title = "mn_kv_title"
    case mn_kv_subtitle = "mn_kv_subtitle"
    case mn_kv_totalEntries = "mn_kv_totalEntries"
    case mn_kv_cacheEntries = "mn_kv_cacheEntries"
    case mn_kv_totalSize = "mn_kv_totalSize"
    case mn_kv_cacheSpace = "mn_kv_cacheSpace"
    case mn_kv_hitRate = "mn_kv_hitRate"
    case mn_kv_hitRateSub = "mn_kv_hitRateSub"
    case mn_kv_findCache = "mn_kv_findCache"
    case mn_kv_searchPh = "mn_kv_searchPh"
    case mn_kv_findBtn = "mn_kv_findBtn"
    case mn_kv_notFoundFmt = "mn_kv_notFoundFmt"
    case mn_kv_hwTitle = "mn_kv_hwTitle"
    case mn_kv_node = "mn_kv_node"
    case mn_kv_memory = "mn_kv_memory"
    case mn_kv_device = "mn_kv_device"
    case mn_kv_agentOnline = "mn_kv_agentOnline"
    case mn_kv_agentOffline = "mn_kv_agentOffline"
    case mn_kv_checking = "mn_kv_checking"
    case mn_kv_warmTitle = "mn_kv_warmTitle"
    case mn_kv_modelName = "mn_kv_modelName"
    case mn_kv_warmPrompt = "mn_kv_warmPrompt"
    case mn_kv_warmBtn = "mn_kv_warmBtn"
    case mn_kv_warmedFmt = "mn_kv_warmedFmt"
    case mn_kv_transferTitle = "mn_kv_transferTitle"
    case mn_kv_targetNode = "mn_kv_targetNode"
    case mn_kv_transferBtn = "mn_kv_transferBtn"
    case mn_kv_byModelTitle = "mn_kv_byModelTitle"
    case mn_kv_countFmt = "mn_kv_countFmt"
    case mn_task_title = "mn_task_title"
    case mn_task_subtitle = "mn_task_subtitle"
    case mn_task_tab_all = "mn_task_tab_all"
    case mn_task_tab_running = "mn_task_tab_running"
    case mn_task_tab_completed = "mn_task_tab_completed"
    case mn_task_tab_failed = "mn_task_tab_failed"
    case mn_task_migrateTitle = "mn_task_migrateTitle"
    case mn_task_taskId = "mn_task_taskId"
    case mn_task_targetNode = "mn_task_targetNode"
    case mn_task_selectNode = "mn_task_selectNode"
    case mn_task_confirmMigrate = "mn_task_confirmMigrate"
    case mn_task_total = "mn_task_total"
    case mn_task_allTasks = "mn_task_allTasks"
    case mn_task_running = "mn_task_running"
    case mn_task_executing = "mn_task_executing"
    case mn_task_failed = "mn_task_failed"
    case mn_task_needsAttention = "mn_task_needsAttention"
    case mn_task_listTitleFmt = "mn_task_listTitleFmt"
    case mn_task_searchPh = "mn_task_searchPh"
    case mn_task_cancelTask = "mn_task_cancelTask"
    case mn_task_degradeTask = "mn_task_degradeTask"
    case mn_task_migrateTask = "mn_task_migrateTask"
    case mn_task_emptyFmt = "mn_task_emptyFmt"
    case mn_sync_title = "mn_sync_title"
    case mn_sync_subtitle = "mn_sync_subtitle"
    case mn_sync_partitionState = "mn_sync_partitionState"
    case mn_sync_partitionNodes = "mn_sync_partitionNodes"
    case mn_sync_isDegraded = "mn_sync_isDegraded"
    case mn_sync_degraded = "mn_sync_degraded"
    case mn_sync_normal = "mn_sync_normal"
    case mn_sync_syncAvailable = "mn_sync_syncAvailable"
    case mn_sync_available = "mn_sync_available"
    case mn_sync_unavailable = "mn_sync_unavailable"
    case mn_sync_incrementalTitle = "mn_sync_incrementalTitle"
    case mn_sync_modelName = "mn_sync_modelName"
    case mn_sync_modelPh = "mn_sync_modelPh"
    case mn_sync_sourceHost = "mn_sync_sourceHost"
    case mn_sync_sourcePort = "mn_sync_sourcePort"
    case mn_sync_syncing = "mn_sync_syncing"
    case mn_sync_triggerBtn = "mn_sync_triggerBtn"
    case mn_sync_manifestTitle = "mn_sync_manifestTitle"
    case mn_sync_manifestPh = "mn_sync_manifestPh"
    case mn_sync_viewBtn = "mn_sync_viewBtn"
    case mn_sync_upToDateFmt = "mn_sync_upToDateFmt"
    case mn_sync_syncDoneFmt = "mn_sync_syncDoneFmt"
    case mn_sync_syncFailFmt = "mn_sync_syncFailFmt"
    case mn_route_title = "mn_route_title"
    case mn_route_subtitle = "mn_route_subtitle"
    case mn_route_currentTitle = "mn_route_currentTitle"
    case mn_route_strategy = "mn_route_strategy"
    case mn_route_applyBtn = "mn_route_applyBtn"
    case mn_route_loadTitle = "mn_route_loadTitle"
    case mn_route_avgLoad = "mn_route_avgLoad"
    case mn_route_updatedFmt = "mn_route_updatedFmt"
    case mn_route_desc_least_loaded = "mn_route_desc_least_loaded"
    case mn_route_desc_round_robin = "mn_route_desc_round_robin"
    case mn_route_desc_random = "mn_route_desc_random"
    case mn_route_desc_capability_aware = "mn_route_desc_capability_aware"
    case mn_alert_title = "mn_alert_title"
    case mn_alert_subtitle = "mn_alert_subtitle"
    case mn_alert_tab_active = "mn_alert_tab_active"
    case mn_alert_tab_suggestions = "mn_alert_tab_suggestions"
    case mn_alert_tab_history = "mn_alert_tab_history"
    case mn_alert_exportBtn = "mn_alert_exportBtn"
    case mn_alert_activeTitleFmt = "mn_alert_activeTitleFmt"
    case mn_alert_activeEmpty = "mn_alert_activeEmpty"
    case mn_alert_suggestTitleFmt = "mn_alert_suggestTitleFmt"
    case mn_alert_suggestEmpty = "mn_alert_suggestEmpty"
    case mn_alert_historyTitle = "mn_alert_historyTitle"
    case mn_alert_historyEmpty = "mn_alert_historyEmpty"
    case mn_alert_ackBtn = "mn_alert_ackBtn"
    case mn_err_invalidURL = "mn_err_invalidURL"
    case mn_err_noData = "mn_err_noData"
    case mn_overview_title = "mn_overview_title"
    case mn_overview_subtitle = "mn_overview_subtitle"
    case mn_overview_disconnectedFmt = "mn_overview_disconnectedFmt"
    case mn_overview_metricNodes = "mn_overview_metricNodes"
    case mn_overview_metricTotal = "mn_overview_metricTotal"
    case mn_overview_metricOnline = "mn_overview_metricOnline"
    case mn_overview_metricOnlineRun = "mn_overview_metricOnlineRun"
    case mn_overview_metricActiveTasks = "mn_overview_metricActiveTasks"
    case mn_overview_metricExecuting = "mn_overview_metricExecuting"
    case mn_overview_metricClusterMem = "mn_overview_metricClusterMem"
    case mn_overview_metricTotalMemFmt = "mn_overview_metricTotalMemFmt"
    case mn_overview_submitTaskBtn = "mn_overview_submitTaskBtn"
    case mn_overview_searchPh = "mn_overview_searchPh"
    case mn_overview_nodeListFmt = "mn_overview_nodeListFmt"
    case mn_overview_viewMetrics = "mn_overview_viewMetrics"
    case mn_overview_removeNode = "mn_overview_removeNode"
    case mn_overview_degradedFmt = "mn_overview_degradedFmt"
    case mn_overview_normalFmt = "mn_overview_normalFmt"
    case mn_overview_detailLink = "mn_overview_detailLink"
    case mn_submit_title = "mn_submit_title"
    case mn_submit_subtitle = "mn_submit_subtitle"
    case mn_submit_configTitle = "mn_submit_configTitle"
    case mn_submit_taskNameLabel = "mn_submit_taskNameLabel"
    case mn_submit_taskNameSub = "mn_submit_taskNameSub"
    case mn_submit_taskNamePh = "mn_submit_taskNamePh"
    case mn_submit_execModeLabel = "mn_submit_execModeLabel"
    case mn_submit_execModeSub = "mn_submit_execModeSub"
    case mn_submit_modelLabel = "mn_submit_modelLabel"
    case mn_submit_modelSub = "mn_submit_modelSub"
    case mn_submit_modelPh = "mn_submit_modelPh"
    case mn_submit_priorityLabel = "mn_submit_priorityLabel"
    case mn_submit_prioritySub = "mn_submit_prioritySub"
    case mn_submit_capabilityLabel = "mn_submit_capabilityLabel"
    case mn_submit_capabilitySub = "mn_submit_capabilitySub"
    case mn_submit_capabilityPh = "mn_submit_capabilityPh"
    case mn_submit_submitBtn = "mn_submit_submitBtn"
    case mn_submit_successFmt = "mn_submit_successFmt"
    case mn_node_title = "mn_node_title"
    case mn_node_subtitle = "mn_node_subtitle"
    case mn_node_autoscalerTitle = "mn_node_autoscalerTitle"
    case mn_node_mgmtTitle = "mn_node_mgmtTitle"
    case mn_node_removeBtn = "mn_node_removeBtn"
    case mn_node_emptyNodes = "mn_node_emptyNodes"
    case mn_node_minNodes = "mn_node_minNodes"
    case mn_node_maxNodes = "mn_node_maxNodes"
    case mn_node_scaleUpThreshold = "mn_node_scaleUpThreshold"
    case mn_node_scaleDownThreshold = "mn_node_scaleDownThreshold"
    case mn_node_cooldownLabel = "mn_node_cooldownLabel"
    case mn_node_strategyLabel = "mn_node_strategyLabel"
    case mn_node_applying = "mn_node_applying"
    case mn_node_applyBtn = "mn_node_applyBtn"
    case mn_node_pendingTitle = "mn_node_pendingTitle"
    case mn_node_pendingEmpty = "mn_node_pendingEmpty"
    case mn_node_approveBtn = "mn_node_approveBtn"
    case mn_node_rejectBtn = "mn_node_rejectBtn"
    case mn_progress_title = "mn_progress_title"
    case mn_progress_subtitle = "mn_progress_subtitle"
    case mn_progress_selectTaskTitle = "mn_progress_selectTaskTitle"
    case mn_progress_taskPicker = "mn_progress_taskPicker"
    case mn_progress_inspectorSelect = "mn_progress_inspectorSelect"
    case mn_progress_loadDetailsBtn = "mn_progress_loadDetailsBtn"
    case mn_progress_execProgressTitle = "mn_progress_execProgressTitle"
    case mn_progress_remainingFmt = "mn_progress_remainingFmt"
    case mn_progress_timelineTitle = "mn_progress_timelineTitle"
    case mn_progress_subTasksFmt = "mn_progress_subTasksFmt"
    case mn_progress_emptyHint = "mn_progress_emptyHint"
    case mn_progress_loadFailFmt = "mn_progress_loadFailFmt"
    case mn_web_title = "mn_web_title"
    case mn_web_subtitle = "mn_web_subtitle"
    case mn_web_tab_docs = "mn_web_tab_docs"
    case mn_web_tab_bench = "mn_web_tab_bench"
    case mn_web_tab_security = "mn_web_tab_security"
    case mn_web_docsDescFmt = "mn_web_docsDescFmt"
    case mn_web_benchDesc = "mn_web_benchDesc"
    case mn_web_securityDesc = "mn_web_securityDesc"
    case mn_web_connectingFmt = "mn_web_connectingFmt"
    case mn_web_loadFailFmt = "mn_web_loadFailFmt"
    case mn_web_retryBtn = "mn_web_retryBtn"
    case mn_topo_title = "mn_topo_title"
    case mn_topo_subtitle = "mn_topo_subtitle"
    case mn_topo_legendOnline = "mn_topo_legendOnline"
    case mn_topo_legendBusy = "mn_topo_legendBusy"
    case mn_topo_legendOffline = "mn_topo_legendOffline"
    case mn_topo_legendFault = "mn_topo_legendFault"
    case mn_topo_statsFmt = "mn_topo_statsFmt"
    case mn_node_statusA11yFmt = "mn_node_statusA11yFmt"
    case mn_task_degradedFmt = "mn_task_degradedFmt"
    case design_swiftUITitle = "design_swiftUITitle"
    case design_codegenTitle = "design_codegenTitle"
    case design_copy = "design_copy"
    case design_close = "design_close"
    case design_helpPageMgmt = "design_helpPageMgmt"
    case design_helpCopyCode = "design_helpCopyCode"
    case design_helpExportCode = "design_helpExportCode"
    case design_helpClear = "design_helpClear"
    case design_welcomeDesc = "design_welcomeDesc"
    case design_inputPh = "design_inputPh"
    case design_emptyTitle = "design_emptyTitle"
    case design_emptyDesc = "design_emptyDesc"
    case design_clearInput = "design_clearInput"
    case design_clearConv = "design_clearConv"
    case design_copyCurrentCode = "design_copyCurrentCode"
    case design_helpSave = "design_helpSave"
    case design_helpCopy = "design_helpCopy"
    case design_helpHistory = "design_helpHistory"
    case design_helpSwiftUI = "design_helpSwiftUI"
    case design_helpStop = "design_helpStop"
    case design_helpSend = "design_helpSend"
    case design_roleUser = "design_roleUser"
    case design_roleDesigner = "design_roleDesigner"
    case design_parsedFmt = "design_parsedFmt"
    case design_noVersions = "design_noVersions"
    case design_rollback = "design_rollback"
    case design_errMLXNotRunning = "design_errMLXNotRunning"
    case design_errNoModel = "design_errNoModel"
    case design_marqueeFmt = "design_marqueeFmt"
    case design_previewFmt = "design_previewFmt"
    case design_previewHint = "design_previewHint"
    case design_reject = "design_reject"
    case design_accept = "design_accept"
    case design_pages = "design_pages"
    case design_newPage = "design_newPage"
    case design_noPages = "design_noPages"
    case design_deletePage = "design_deletePage"
    case design_batchExport = "design_batchExport"
    case design_exporting = "design_exporting"
    case design_selectFormat = "design_selectFormat"
    case design_skillUseFmt = "design_skillUseFmt"
    case design_stepConnecting = "design_stepConnecting"
    case design_stepGenerating = "design_stepGenerating"
    case design_stepStreaming = "design_stepStreaming"
    case design_stepRendering = "design_stepRendering"
    case design_stepConnShort = "design_stepConnShort"
    case design_stepGenShort = "design_stepGenShort"
    case design_stepStreamShort = "design_stepStreamShort"
    case design_stepRenderShort = "design_stepRenderShort"
    case design_grp_pages = "design_grp_pages"
    case design_grp_components = "design_grp_components"
    case design_grp_skills = "design_grp_skills"
    case design_tpl_login = "design_tpl_login"
    case design_tpl_dashboard = "design_tpl_dashboard"
    case design_tpl_landing = "design_tpl_landing"
    case design_tpl_settings = "design_tpl_settings"
    case design_tpl_chat = "design_tpl_chat"
    case design_tpl_profile = "design_tpl_profile"
    case design_tpl_card = "design_tpl_card"
    case design_tpl_form = "design_tpl_form"
    case design_tpl_table = "design_tpl_table"
    case design_tpl_nav = "design_tpl_nav"
    case design_tpl_modal = "design_tpl_modal"
    case design_tpl_buttons = "design_tpl_buttons"
    case design_tpl_textToUI = "design_tpl_textToUI"
    case design_tpl_imageToUI = "design_tpl_imageToUI"
    case design_tpl_partialEdit = "design_tpl_partialEdit"
    case design_tpl_localEdit = "design_tpl_localEdit"
    case design_tpl_simPanel = "design_tpl_simPanel"
    case design_tpl_multiVariants = "design_tpl_multiVariants"
    case design_tpl_specDoc = "design_tpl_specDoc"
    case design_tpl_pageFlow = "design_tpl_pageFlow"
    case design_ds_compLibrary = "design_ds_compLibrary"
    case design_ds_searchCompPh = "design_ds_searchCompPh"
    case design_ds_catAll = "design_ds_catAll"
    case design_ds_template = "design_ds_template"
    case design_ds_sizeSM = "design_ds_sizeSM"
    case design_ds_sizeMD = "design_ds_sizeMD"
    case design_ds_sizeLG = "design_ds_sizeLG"
    case design_ds_cat_button = "design_ds_cat_button"
    case design_ds_cat_card = "design_ds_cat_card"
    case design_ds_cat_input = "design_ds_cat_input"
    case design_ds_cat_select = "design_ds_cat_select"
    case design_ds_cat_modal = "design_ds_cat_modal"
    case design_ds_cat_nav = "design_ds_cat_nav"
    case design_ds_cat_table = "design_ds_cat_table"
    case design_ds_cat_chart = "design_ds_cat_chart"
    case design_ds_cat_form = "design_ds_cat_form"
    case design_ds_desc_button = "design_ds_desc_button"
    case design_ds_desc_card = "design_ds_desc_card"
    case design_ds_desc_input = "design_ds_desc_input"
    case design_ds_desc_select = "design_ds_desc_select"
    case design_ds_desc_modal = "design_ds_desc_modal"
    case design_ds_desc_nav = "design_ds_desc_nav"
    case design_ds_desc_table = "design_ds_desc_table"
    case design_ds_desc_chart = "design_ds_desc_chart"
    case design_ds_desc_form = "design_ds_desc_form"
    case design_lint_title = "design_lint_title"
    case design_lint_ruleLock = "design_lint_ruleLock"
    case design_lint_run = "design_lint_run"
    case design_lint_genDocFirst = "design_lint_genDocFirst"
    case design_lint_noResult = "design_lint_noResult"
    case design_lint_noViolation = "design_lint_noViolation"
    case design_lint_errCountFmt = "design_lint_errCountFmt"
    case design_lint_warnCountFmt = "design_lint_warnCountFmt"
    case design_lint_infoCountFmt = "design_lint_infoCountFmt"
    case design_lint_violationCountFmt = "design_lint_violationCountFmt"
    case design_lint_nodeFmt = "design_lint_nodeFmt"
    case design_lint_rule_contrastCheck = "design_lint_rule_contrastCheck"
    case design_lint_rule_unlabeledInput = "design_lint_rule_unlabeledInput"
    case design_lint_rule_textEffects = "design_lint_rule_textEffects"
    case design_lint_rule_abnormalRotation = "design_lint_rule_abnormalRotation"
    case design_lint_rule_emptyEffects = "design_lint_rule_emptyEffects"
    case design_lint_rule_tokenInconsistency = "design_lint_rule_tokenInconsistency"
    case design_lint_rule_unnamedNode = "design_lint_rule_unnamedNode"
    case design_lint_rule_textOverflow = "design_lint_rule_textOverflow"
    case design_lint_rule_overlappingNodes = "design_lint_rule_overlappingNodes"
    case design_lint_rule_hardcodedSpacing = "design_lint_rule_hardcodedSpacing"
    case design_lint_rule_hardcodedFontSize = "design_lint_rule_hardcodedFontSize"
    case design_lint_rule_missingInteractionState = "design_lint_rule_missingInteractionState"
    case design_lint_rule_layoutInconsistency = "design_lint_rule_layoutInconsistency"
    case design_lint_lockTitle = "design_lint_lockTitle"
    case design_lint_done = "design_lint_done"
    case design_lint_lockHint = "design_lint_lockHint"
    case design_lint_lockedCountFmt = "design_lint_lockedCountFmt"
    case design_lint_unlockAll = "design_lint_unlockAll"
    case design_eco_tabSync = "design_eco_tabSync"
    case design_eco_tabTpl = "design_eco_tabTpl"
    case design_eco_syncToCode = "design_eco_syncToCode"
    case design_eco_compName = "design_eco_compName"
    case design_eco_syncing = "design_eco_syncing"
    case design_eco_syncCode = "design_eco_syncCode"
    case design_eco_watchCode = "design_eco_watchCode"
    case design_eco_checking = "design_eco_checking"
    case design_eco_checkChange = "design_eco_checkChange"
    case design_eco_noMutation = "design_eco_noMutation"
    case design_eco_applyCanvas = "design_eco_applyCanvas"
    case design_eco_saveAsTpl = "design_eco_saveAsTpl"
    case design_eco_tplNamePh = "design_eco_tplNamePh"
    case design_eco_tplTagsPh = "design_eco_tplTagsPh"
    case design_eco_tplCatPh = "design_eco_tplCatPh"
    case design_eco_save = "design_eco_save"
    case design_eco_searchTpl = "design_eco_searchTpl"
    case design_eco_searchPh = "design_eco_searchPh"
    case design_eco_search = "design_eco_search"
    case design_eco_noMatchTpl = "design_eco_noMatchTpl"
    case design_eco_load = "design_eco_load"
    case design_eco_syncDone = "design_eco_syncDone"
    case design_eco_syncFailFmt = "design_eco_syncFailFmt"
    case design_eco_appliedFmt = "design_eco_appliedFmt"
    case design_eco_tplSavedFmt = "design_eco_tplSavedFmt"
    case design_eco_tplSaveFailFmt = "design_eco_tplSaveFailFmt"
    case design_eco_tplLoadedFmt = "design_eco_tplLoadedFmt"
    case design_theme_modeSystem = "design_theme_modeSystem"
    case design_theme_modeLight = "design_theme_modeLight"
    case design_theme_modeDark = "design_theme_modeDark"
    case design_theme_modeCustom = "design_theme_modeCustom"
    case design_theme_title = "design_theme_title"
    case design_theme_modeLabel = "design_theme_modeLabel"
    case design_theme_customAccent = "design_theme_customAccent"
    case design_theme_accentBlue = "design_theme_accentBlue"
    case design_theme_accentRed = "design_theme_accentRed"
    case design_theme_accentGreen = "design_theme_accentGreen"
    case design_theme_accentOrange = "design_theme_accentOrange"
    case design_theme_accentPurple = "design_theme_accentPurple"
    case design_theme_accentPink = "design_theme_accentPink"
    case design_theme_preview = "design_theme_preview"
    case design_theme_previewLight = "design_theme_previewLight"
    case design_theme_previewDark = "design_theme_previewDark"
    case design_theme_reset = "design_theme_reset"
    case design_wf_recipe_designToCode = "design_wf_recipe_designToCode"
    case design_wf_recipe_codeToDesign = "design_wf_recipe_codeToDesign"
    case design_wf_recipe_screenshot = "design_wf_recipe_screenshot"
    case design_wf_recipe_designToCodeDesc = "design_wf_recipe_designToCodeDesc"
    case design_wf_recipe_codeToDesignDesc = "design_wf_recipe_codeToDesignDesc"
    case design_wf_recipe_screenshotDesc = "design_wf_recipe_screenshotDesc"
    case design_wf_step_createDesign = "design_wf_step_createDesign"
    case design_wf_step_previewDesign = "design_wf_step_previewDesign"
    case design_wf_step_exportToCode = "design_wf_step_exportToCode"
    case design_wf_step_openInEditor = "design_wf_step_openInEditor"
    case design_wf_step_selectCodeFile = "design_wf_step_selectCodeFile"
    case design_wf_step_importToDesign = "design_wf_step_importToDesign"
    case design_wf_step_editDesign = "design_wf_step_editDesign"
    case design_wf_step_syncBack = "design_wf_step_syncBack"
    case design_wf_step_captureScreenshot = "design_wf_step_captureScreenshot"
    case design_wf_step_analyzeScreenshot = "design_wf_step_analyzeScreenshot"
    case design_wf_step_generateDesign = "design_wf_step_generateDesign"
    case design_wf_startFmt = "design_wf_startFmt"
    case design_wf_cancelled = "design_wf_cancelled"
    case design_wf_doneFmt = "design_wf_doneFmt"
    case design_wf_execFmt = "design_wf_execFmt"
    case design_wf_ssSaved = "design_wf_ssSaved"
    case design_wf_canvasCleared = "design_wf_canvasCleared"
    case design_wf_previewing = "design_wf_previewing"
    case design_wf_editHint = "design_wf_editHint"
    case design_wf_generating = "design_wf_generating"
    case design_wf_analyzing = "design_wf_analyzing"
    case design_wf_noScreenshot = "design_wf_noScreenshot"
    case design_wf_selectCodeFile = "design_wf_selectCodeFile"
    case design_wf_selectedFmt = "design_wf_selectedFmt"
    case design_wf_notSelected = "design_wf_notSelected"
    case design_wf_importedFmt = "design_wf_importedFmt"
    case design_wf_importedDoc = "design_wf_importedDoc"
    case design_wf_noFileSelected = "design_wf_noFileSelected"
    case design_wf_panelTitle = "design_wf_panelTitle"
    case design_wf_cancelBtn = "design_wf_cancelBtn"
    case design_ins_sec_layout = "design_ins_sec_layout"
    case design_ins_sec_spacing = "design_ins_sec_spacing"
    case design_ins_sec_typography = "design_ins_sec_typography"
    case design_ins_sec_colors = "design_ins_sec_colors"
    case design_ins_sec_borders = "design_ins_sec_borders"
    case design_ins_sec_effects = "design_ins_sec_effects"
    case design_ins_alignStart = "design_ins_alignStart"
    case design_ins_alignCenter = "design_ins_alignCenter"
    case design_ins_alignEnd = "design_ins_alignEnd"
    case design_ins_justifyBetween = "design_ins_justifyBetween"
    case design_ins_justifyAround = "design_ins_justifyAround"
    case design_ins_alignStretch = "design_ins_alignStretch"
    case design_ins_preset_card = "design_ins_preset_card"
    case design_ins_preset_button = "design_ins_preset_button"
    case design_ins_preset_inputField = "design_ins_preset_inputField"
    case design_ins_preset_navBar = "design_ins_preset_navBar"
    case design_ins_preset_heroSection = "design_ins_preset_heroSection"
    case design_ins_title = "design_ins_title"
    case design_ins_presetLabel = "design_ins_presetLabel"
    case design_ins_layoutMode = "design_ins_layoutMode"
    case design_ins_direction = "design_ins_direction"
    case design_ins_mainAxis = "design_ins_mainAxis"
    case design_ins_crossAxis = "design_ins_crossAxis"
    case design_ins_width = "design_ins_width"
    case design_ins_height = "design_ins_height"
    case design_ins_padding = "design_ins_padding"
    case design_ins_margin = "design_ins_margin"
    case design_ins_gap = "design_ins_gap"
    case design_ins_fontFamily = "design_ins_fontFamily"
    case design_ins_fontSize = "design_ins_fontSize"
    case design_ins_fontWeight = "design_ins_fontWeight"
    case design_ins_lineHeight = "design_ins_lineHeight"
    case design_ins_textAlign = "design_ins_textAlign"
    case design_ins_textColor = "design_ins_textColor"
    case design_ins_bgColor = "design_ins_bgColor"
    case design_ins_borderColor = "design_ins_borderColor"
    case design_ins_borderWidth = "design_ins_borderWidth"
    case design_ins_borderRadius = "design_ins_borderRadius"
    case design_ins_opacity = "design_ins_opacity"
    case design_ins_shadow = "design_ins_shadow"
    case design_ins_overflow = "design_ins_overflow"
    case design_ins_cssOutput = "design_ins_cssOutput"
    case design_tok_preset_appleHIG = "design_tok_preset_appleHIG"
    case design_tok_preset_adminMinimal = "design_tok_preset_adminMinimal"
    case design_tok_preset_robotSim = "design_tok_preset_robotSim"
    case design_tok_cat_colors = "design_tok_cat_colors"
    case design_tok_cat_spacing = "design_tok_cat_spacing"
    case design_tok_cat_typography = "design_tok_cat_typography"
    case design_tok_cat_radius = "design_tok_cat_radius"
    case design_tok_cat_shadows = "design_tok_cat_shadows"
    case design_tok_cat_animation = "design_tok_cat_animation"
    case design_tok_designSpec = "design_tok_designSpec"
    case design_cv_menu_duplicate = "design_cv_menu_duplicate"
    case design_cv_menu_delete = "design_cv_menu_delete"
    case design_cv_menu_toggleLock = "design_cv_menu_toggleLock"
    case design_cv_menu_toggleVisibility = "design_cv_menu_toggleVisibility"
    case design_cv_menu_partialRepaint = "design_cv_menu_partialRepaint"
    case design_cv_menu_bringToFront = "design_cv_menu_bringToFront"
    case design_cv_menu_sendToBack = "design_cv_menu_sendToBack"
    case design_cv_menu_selectAll = "design_cv_menu_selectAll"
    case design_cv_menu_fitZoom = "design_cv_menu_fitZoom"
    case design_cv_menu_paste = "design_cv_menu_paste"
    case design_cg_targetLabel = "design_cg_targetLabel"
    case design_cg_componentName = "design_cg_componentName"
    case design_cg_generating = "design_cg_generating"
    case design_cg_generate = "design_cg_generate"
    case design_cg_copied = "design_cg_copied"
    case design_cg_copy = "design_cg_copy"
    case design_cg_emptyHint = "design_cg_emptyHint"
    case design_cg_charCount = "design_cg_charCount"
    case design_cg_genFailFmt = "design_cg_genFailFmt"
    case design_cg_desc_html = "design_cg_desc_html"
    case design_cg_desc_react = "design_cg_desc_react"
    case design_cg_desc_tailwind = "design_cg_desc_tailwind"
    case design_cg_desc_swiftui = "design_cg_desc_swiftui"
    case design_ds_title = "design_ds_title"
    case design_ds_refresh = "design_ds_refresh"
    case design_ds_activeFmt = "design_ds_activeFmt"
    case design_ds_applyToCanvas = "design_ds_applyToCanvas"
    case design_ds_activateFailFmt = "design_ds_activateFailFmt"
    case design_ds_listFailFmt = "design_ds_listFailFmt"
    case design_ds_name_appleHIG = "design_ds_name_appleHIG"
    case design_ds_name_adminMinimal = "design_ds_name_adminMinimal"
    case design_ds_name_robotSim = "design_ds_name_robotSim"
    case design_ds_desc_appleHIG = "design_ds_desc_appleHIG"
    case design_ds_desc_adminMinimal = "design_ds_desc_adminMinimal"
    case design_ds_desc_robotSim = "design_ds_desc_robotSim"
    case design_ds_customDesc = "design_ds_customDesc"
    case design_ly_title = "design_ly_title"
    case design_ly_countFmt = "design_ly_countFmt"
    case design_ly_empty = "design_ly_empty"
    case design_ly_emptyHint = "design_ly_emptyHint"
    case design_avd_exportReview = "design_avd_exportReview"
    case design_ae_multiFormat = "design_ae_multiFormat"
    case design_ae_cancel = "design_ae_cancel"
    case design_ae_exportFmt = "design_ae_exportFmt"
    case design_cl_conflictFmt = "design_cl_conflictFmt"
    case design_si_selectScreenshot = "design_si_selectScreenshot"
    case art_pc_open = "art_pc_open"
    case art_pc_copy = "art_pc_copy"
    case art_pc_versionHistory = "art_pc_versionHistory"
    case art_pc_share = "art_pc_share"
    case art_pc_unpin = "art_pc_unpin"
    case art_pc_pin = "art_pc_pin"
    case art_pc_duplicate = "art_pc_duplicate"
    case art_pc_moveToKb = "art_pc_moveToKb"
    case art_pc_delete = "art_pc_delete"
    case art_pc_copySuffix = "art_pc_copySuffix"
    case art_sd_title = "art_sd_title"
    case art_sd_permission = "art_sd_permission"
    case art_sd_permView = "art_sd_permView"
    case art_sd_permComment = "art_sd_permComment"
    case art_sd_permEdit = "art_sd_permEdit"
    case art_sd_expiry = "art_sd_expiry"
    case art_sd_exp1h = "art_sd_exp1h"
    case art_sd_exp1d = "art_sd_exp1d"
    case art_sd_exp7d = "art_sd_exp7d"
    case art_sd_exp30d = "art_sd_exp30d"
    case art_sd_expNever = "art_sd_expNever"
    case art_sd_generate = "art_sd_generate"
    case art_sd_done = "art_sd_done"
    case art_sd_shareLink = "art_sd_shareLink"
    case art_sd_existingShares = "art_sd_existingShares"
    case art_sd_expires = "art_sd_expires"
    case art_sd_revoke = "art_sd_revoke"
    case art_tf_tags = "art_tf_tags"
    case art_tf_addTag = "art_tf_addTag"
    case art_tf_folders = "art_tf_folders"
    case art_tf_noFolders = "art_tf_noFolders"
    case art_vh_rollbackConfirm = "art_vh_rollbackConfirm"
    case art_vh_rollback = "art_vh_rollback"
    case art_vh_cancel = "art_vh_cancel"
    case art_vh_rollbackMsg = "art_vh_rollbackMsg"
    case art_vh_createSnapshot = "art_vh_createSnapshot"
    case art_vh_snapshotName = "art_vh_snapshotName"
    case art_vh_create = "art_vh_create"
    case art_vh_title = "art_vh_title"
    case art_vh_empty = "art_vh_empty"
    case art_vh_current = "art_vh_current"
    case art_vh_chars = "art_vh_chars"
    case art_vh_diffCurrent = "art_vh_diffCurrent"
    case art_vh_incremental = "art_vh_incremental"
    case art_vh_noDiff = "art_vh_noDiff"
    case art_vh_diffFail = "art_vh_diffFail"
    case art_rv_sortUpdated = "art_rv_sortUpdated"
    case art_rv_sortCreated = "art_rv_sortCreated"
    case art_rv_sortName = "art_rv_sortName"
    case art_rv_scopeAll = "art_rv_scopeAll"
    case art_rv_scopeMine = "art_rv_scopeMine"
    case art_rv_scopeStarred = "art_rv_scopeStarred"
    case art_rv_scopePinned = "art_rv_scopePinned"
    case art_rv_subtitle = "art_rv_subtitle"
    case art_rv_newFolder = "art_rv_newFolder"
    case art_rv_folderName = "art_rv_folderName"
    case art_rv_create = "art_rv_create"
    case art_rv_search = "art_rv_search"
    case art_rv_typeAll = "art_rv_typeAll"
    case art_rv_recycle = "art_rv_recycle"
    case art_rv_folders = "art_rv_folders"
    case art_rv_allArtifacts = "art_rv_allArtifacts"
    case art_rv_rename = "art_rv_rename"
    case art_rv_delete = "art_rv_delete"
    case art_rv_retry = "art_rv_retry"
    case art_rv_empty = "art_rv_empty"
    case art_rv_open = "art_rv_open"
    case art_rv_unstar = "art_rv_unstar"
    case art_rv_star = "art_rv_star"
    case art_rv_copyContent = "art_rv_copyContent"
    case art_rv_download = "art_rv_download"
    case art_rv_copy = "art_rv_copy"
    case art_rv_moveToKb = "art_rv_moveToKb"
    case art_rv_loadFail = "art_rv_loadFail"
    case art_rb_title = "art_rb_title"
    case art_rb_purge = "art_rb_purge"
    case art_rb_empty = "art_rb_empty"
    case art_rb_restore = "art_rb_restore"
    case art_cv_rename = "art_cv_rename"
    case art_cv_newName = "art_cv_newName"
    case art_cv_confirm = "art_cv_confirm"
    case art_cv_cancel = "art_cv_cancel"
    case art_cv_deleteConfirm = "art_cv_deleteConfirm"
    case art_cv_delete = "art_cv_delete"
    case art_cv_deleteMsg = "art_cv_deleteMsg"
    case art_cv_unsaved = "art_cv_unsaved"
    case art_cv_discard = "art_cv_discard"
    case art_cv_save = "art_cv_save"
    case art_cv_noPreview = "art_cv_noPreview"
    case art_cv_chars = "art_cv_chars"
    case art_cv_discardChanges = "art_cv_discardChanges"
    case art_cv_createSnapshot = "art_cv_createSnapshot"
    case art_cv_snapshotLabel = "art_cv_snapshotLabel"
    case art_cv_create = "art_cv_create"
    case art_cv_sections = "art_cv_sections"
    case art_cv_toc = "art_cv_toc"
    case desk_tab_templates = "desk_tab_templates"
    case desk_tab_workflows = "desk_tab_workflows"
    case desk_tab_agents = "desk_tab_agents"
    case desk_tab_sessions = "desk_tab_sessions"
    case desk_tab_permissions = "desk_tab_permissions"
    case desk_tab_mlx = "desk_tab_mlx"
    case desk_tab_system = "desk_tab_system"
    case desk_tab_events = "desk_tab_events"
    case desk_close = "desk_close"
    case desk_loading = "desk_loading"
    case desk_name = "desk_name"
    case desk_category = "desk_category"
    case desk_description = "desk_description"
    case desk_create = "desk_create"
    case desk_cancel = "desk_cancel"
    case desk_save = "desk_save"
    case desk_edit = "desk_edit"
    case desk_delete = "desk_delete"
    case desk_status = "desk_status"
    case desk_refresh = "desk_refresh"
    case desk_svc_notConnected = "desk_svc_notConnected"
    case desk_svc_notConnectedHint = "desk_svc_notConnectedHint"
    case desk_reconnect = "desk_reconnect"
    case desk_svc_notReady = "desk_svc_notReady"
    case desk_searchTemplates = "desk_searchTemplates"
    case desk_tpl_count = "desk_tpl_count"
    case desk_noTemplates = "desk_noTemplates"
    case desk_tpl_detail = "desk_tpl_detail"
    case desk_steps = "desk_steps"
    case desk_tpl_runResult = "desk_tpl_runResult"
    case desk_tpl_runFail = "desk_tpl_runFail"
    case desk_wf_promptPlaceholder = "desk_wf_promptPlaceholder"
    case desk_wf_count = "desk_wf_count"
    case desk_wf_execStatus = "desk_wf_execStatus"
    case desk_noWorkflows = "desk_noWorkflows"
    case desk_wf_execStatusTitle = "desk_wf_execStatusTitle"
    case desk_wf_noRunning = "desk_wf_noRunning"
    case desk_wf_currentNode = "desk_wf_currentNode"
    case desk_agent_taskPlaceholder = "desk_agent_taskPlaceholder"
    case desk_submit = "desk_submit"
    case desk_agent_count = "desk_agent_count"
    case desk_noAgents = "desk_noAgents"
    case desk_agent_id = "desk_agent_id"
    case desk_agent_taskSubmitted = "desk_agent_taskSubmitted"
    case desk_agent_viewStatus = "desk_agent_viewStatus"
    case desk_agent_status = "desk_agent_status"
    case desk_agent_progress = "desk_agent_progress"
    case desk_session_new = "desk_session_new"
    case desk_session_count = "desk_session_count"
    case desk_noSessions = "desk_noSessions"
    case desk_session_steps = "desk_session_steps"
    case desk_session_fork = "desk_session_fork"
    case desk_session_edit = "desk_session_edit"
    case desk_session_namePlaceholder = "desk_session_namePlaceholder"
    case desk_session_detail = "desk_session_detail"
    case desk_session_stepCount = "desk_session_stepCount"
    case desk_perm_rules = "desk_perm_rules"
    case desk_perm_checkTool = "desk_perm_checkTool"
    case desk_perm_check = "desk_perm_check"
    case desk_perm_resetAll = "desk_perm_resetAll"
    case desk_perm_checkResult = "desk_perm_checkResult"
    case desk_perm_allowed = "desk_perm_allowed"
    case desk_perm_denied = "desk_perm_denied"
    case desk_perm_noRules = "desk_perm_noRules"
    case desk_perm_scope = "desk_perm_scope"
    case desk_perm_toggle = "desk_perm_toggle"
    case desk_mlx_status = "desk_mlx_status"
    case desk_mlx_running = "desk_mlx_running"
    case desk_mlx_stopped = "desk_mlx_stopped"
    case desk_mlx_noModels = "desk_mlx_noModels"
    case desk_mlx_modelList = "desk_mlx_modelList"
    case desk_mlx_modelCount = "desk_mlx_modelCount"
    case desk_mlx_runningTitle = "desk_mlx_runningTitle"
    case desk_mlx_stoppedTitle = "desk_mlx_stoppedTitle"
    case desk_mlx_manageHint = "desk_mlx_manageHint"
    case desk_sys_info = "desk_sys_info"
    case desk_sys_platform = "desk_sys_platform"
    case desk_sys_cpuCores = "desk_sys_cpuCores"
    case desk_sys_memoryTotal = "desk_sys_memoryTotal"
    case desk_sys_memoryUsed = "desk_sys_memoryUsed"
    case desk_sys_diskFree = "desk_sys_diskFree"
    case desk_sys_nodeCategories = "desk_sys_nodeCategories"
    case desk_sys_nodeList = "desk_sys_nodeList"
    case desk_sys_loading = "desk_sys_loading"
    case desk_sys_nodeDetail = "desk_sys_nodeDetail"
    case desk_sys_inputs = "desk_sys_inputs"
    case desk_sys_outputs = "desk_sys_outputs"
    case desk_evt_stream = "desk_evt_stream"
    case desk_evt_polling = "desk_evt_polling"
    case desk_evt_subscribed = "desk_evt_subscribed"
    case desk_evt_count = "desk_evt_count"
    case desk_evt_stopPoll = "desk_evt_stopPoll"
    case desk_evt_startPoll = "desk_evt_startPoll"
    case desk_noEvents = "desk_noEvents"
    case desk_evt_source = "desk_evt_source"
    case dy_tab_inventory = "dy_tab_inventory"
    case dy_tab_produce = "dy_tab_produce"
    case dy_tab_publish = "dy_tab_publish"
    case dy_tab_plan = "dy_tab_plan"
    case dy_tab_comment = "dy_tab_comment"
    case dy_tab_evolve = "dy_tab_evolve"
    case dy_tab_stats = "dy_tab_stats"
    case dy_queue_pending = "dy_queue_pending"
    case dy_queue_published = "dy_queue_published"
    case dy_queue_failed = "dy_queue_failed"
    case dy_queue_refresh = "dy_queue_refresh"
    case dy_inv_pending_queue = "dy_inv_pending_queue"
    case dy_inv_pending_empty = "dy_inv_pending_empty"
    case dy_inv_published_recent = "dy_inv_published_recent"
    case dy_inv_published_empty = "dy_inv_published_empty"
    case dy_inv_failed_queue = "dy_inv_failed_queue"
    case dy_inv_variant_label = "dy_inv_variant_label"
    case dy_prod_title = "dy_prod_title"
    case dy_prod_desc = "dy_prod_desc"
    case dy_prod_topic_label = "dy_prod_topic_label"
    case dy_prod_topic_ph = "dy_prod_topic_ph"
    case dy_prod_variant_label = "dy_prod_variant_label"
    case dy_prod_hint_a = "dy_prod_hint_a"
    case dy_prod_hint_b = "dy_prod_hint_b"
    case dy_prod_hint_c = "dy_prod_hint_c"
    case dy_prod_start = "dy_prod_start"
    case dy_pub_title = "dy_pub_title"
    case dy_pub_desc = "dy_pub_desc"
    case dy_pub_dryrun_toggle = "dy_pub_dryrun_toggle"
    case dy_pub_dryrun_btn = "dy_pub_dryrun_btn"
    case dy_pub_real_btn = "dy_pub_real_btn"
    case dy_pub_real_warn = "dy_pub_real_warn"
    case dy_plan_title = "dy_plan_title"
    case dy_plan_desc = "dy_plan_desc"
    case dy_plan_expr_label = "dy_plan_expr_label"
    case dy_plan_expr_default = "dy_plan_expr_default"
    case dy_plan_dryrun_toggle = "dy_plan_dryrun_toggle"
    case dy_plan_real_warn = "dy_plan_real_warn"
    case dy_plan_register = "dy_plan_register"
    case dy_plan_refresh = "dy_plan_refresh"
    case dy_plan_empty = "dy_plan_empty"
    case dy_plan_registered = "dy_plan_registered"
    case dy_plan_history = "dy_plan_history"
    case dy_cron_next = "dy_cron_next"
    case dy_cron_last = "dy_cron_last"
    case dy_cron_params = "dy_cron_params"
    case dy_cron_cancel = "dy_cron_cancel"
    case dy_comment_title = "dy_comment_title"
    case dy_comment_desc = "dy_comment_desc"
    case dy_comment_start = "dy_comment_start"
    case dy_comment_replied_title = "dy_comment_replied_title"
    case dy_evolve_title = "dy_evolve_title"
    case dy_evolve_desc = "dy_evolve_desc"
    case dy_evolve_run = "dy_evolve_run"
    case dy_evolve_repair_title = "dy_evolve_repair_title"
    case dy_evolve_repair_desc = "dy_evolve_repair_desc"
    case dy_evolve_repair_scan = "dy_evolve_repair_scan"
    case dy_win_title = "dy_win_title"
    case dy_win_summary = "dy_win_summary"
    case dy_win_title_formula = "dy_win_title_formula"
    case dy_win_hot_topic = "dy_win_hot_topic"
    case dy_win_hot_hook = "dy_win_hot_hook"
    case dy_win_lose = "dy_win_lose"
    case dy_stats_title = "dy_stats_title"
    case dy_stats_desc = "dy_stats_desc"
    case dy_stats_empty = "dy_stats_empty"
    case dy_stats_detail_title = "dy_stats_detail_title"
    case dy_stats_total_plays = "dy_stats_total_plays"
    case dy_stats_total_likes = "dy_stats_total_likes"
    case dy_stats_total_comments = "dy_stats_total_comments"
    case dy_stats_total_shares = "dy_stats_total_shares"
    case dy_stats_count = "dy_stats_count"
    case dy_stats_avg_plays = "dy_stats_avg_plays"
    case dy_stats_avg_ir = "dy_stats_avg_ir"
    case dy_stats_hot_count = "dy_stats_hot_count"
    case dy_stats_dist_hot = "dy_stats_dist_hot"
    case dy_stats_dist_mid = "dy_stats_dist_mid"
    case dy_stats_dist_cold = "dy_stats_dist_cold"
    case dy_stats_variant_dist = "dy_stats_variant_dist"
    case dy_stats_variant_count = "dy_stats_variant_count"
    case dy_stats_row_plays = "dy_stats_row_plays"
    case dy_stats_row_likes = "dy_stats_row_likes"
    case dy_stats_row_comments = "dy_stats_row_comments"
    case dy_stats_row_shares = "dy_stats_row_shares"
    case dy_stats_row_ir = "dy_stats_row_ir"
    case dy_action_running = "dy_action_running"
    case dy_action_produce = "dy_action_produce"
    case dy_action_publish = "dy_action_publish"
    case dy_action_comment_reply = "dy_action_comment_reply"
    case dy_action_evolve = "dy_action_evolve"
    case dy_action_repair = "dy_action_repair"
    case dy_err_ops_not_found = "dy_err_ops_not_found"
    case dy_err_ipc_disconnected = "dy_err_ipc_disconnected"
    case dy_err_ipc_register = "dy_err_ipc_register"
    case dy_res_done = "dy_res_done"
    case dy_res_status = "dy_res_status"
    case dy_res_plan_registered = "dy_res_plan_registered"
    case dy_res_register_failed = "dy_res_register_failed"
    case dy_err_rungraph = "dy_err_rungraph"
    case dy_err_graph_missing = "dy_err_graph_missing"
    case dy_err_graph_parse = "dy_err_graph_parse"
    case dy_err_graph_no_id = "dy_err_graph_no_id"
    case dy_err_register = "dy_err_register"
    case dy_err_unregister = "dy_err_unregister"
    case dy_cron_name = "dy_cron_name"
    case fc_mode_ask = "fc_mode_ask"
    case fc_mode_auto = "fc_mode_auto"
    case fc_mode_plan = "fc_mode_plan"
    case fc_layout_four_column = "fc_layout_four_column"
    case fc_layout_three_column = "fc_layout_three_column"
    case fc_layout_two_column = "fc_layout_two_column"
    case fc_layout_chat_only = "fc_layout_chat_only"
    case fc_pane_editor = "fc_pane_editor"
    case fc_pane_diff = "fc_pane_diff"
    case fc_pane_preview = "fc_pane_preview"
    case fc_pane_terminal = "fc_pane_terminal"
    case fc_pane_snapshot = "fc_pane_snapshot"
    case fc_pane_workflow = "fc_pane_workflow"
    case fc_pane_sandbox = "fc_pane_sandbox"
    case fc_cmd_help = "fc_cmd_help"
    case fc_cmd_clear = "fc_cmd_clear"
    case fc_cmd_compact = "fc_cmd_compact"
    case fc_cmd_model = "fc_cmd_model"
    case fc_cmd_kb = "fc_cmd_kb"
    case fc_cmd_memory = "fc_cmd_memory"
    case fc_cmd_template = "fc_cmd_template"
    case fc_cmd_init = "fc_cmd_init"
    case fc_cmd_review = "fc_cmd_review"
    case fc_cmd_test = "fc_cmd_test"
    case fc_cmd_deploy = "fc_cmd_deploy"
    case fc_cmd_explain = "fc_cmd_explain"
    case fc_cmd_refactor = "fc_cmd_refactor"
    case fc_cmd_debug = "fc_cmd_debug"
    case fc_no_project_title = "fc_no_project_title"
    case fc_open_folder = "fc_open_folder"
    case fc_offline_mlx = "fc_offline_mlx"
    case fc_thinking = "fc_thinking"
    case fc_connected = "fc_connected"
    case fc_offline = "fc_offline"
    case fc_hide_session_bar = "fc_hide_session_bar"
    case fc_show_session_bar = "fc_show_session_bar"
    case fc_greeting_morning = "fc_greeting_morning"
    case fc_greeting_afternoon = "fc_greeting_afternoon"
    case fc_greeting_evening = "fc_greeting_evening"
    case fc_greeting_night = "fc_greeting_night"
    case fc_welcome_subtitle = "fc_welcome_subtitle"
    case fc_card_open_title = "fc_card_open_title"
    case fc_card_open_sub = "fc_card_open_sub"
    case fc_card_code_title = "fc_card_code_title"
    case fc_card_code_sub = "fc_card_code_sub"
    case fc_card_debug_title = "fc_card_debug_title"
    case fc_card_debug_sub = "fc_card_debug_sub"
    case fc_card_kb_title = "fc_card_kb_title"
    case fc_card_kb_sub = "fc_card_kb_sub"
    case fc_card_memory_title = "fc_card_memory_title"
    case fc_card_memory_sub = "fc_card_memory_sub"
    case fc_card_template_title = "fc_card_template_title"
    case fc_card_template_sub = "fc_card_template_sub"
    case fc_card_review_title = "fc_card_review_title"
    case fc_card_review_sub = "fc_card_review_sub"
    case fc_card_test_title = "fc_card_test_title"
    case fc_card_test_sub = "fc_card_test_sub"
    case fc_prompt_write = "fc_prompt_write"
    case fc_prompt_debug = "fc_prompt_debug"
    case fc_add_folder = "fc_add_folder"
    case fc_add_file = "fc_add_file"
    case fc_query_kb = "fc_query_kb"
    case fc_templates = "fc_templates"
    case fc_web_search = "fc_web_search"
    case fc_input_placeholder = "fc_input_placeholder"
    case fc_select_file_edit = "fc_select_file_edit"
    case fc_select_session_snapshot = "fc_select_session_snapshot"
    case fc_undo = "fc_undo"
    case fc_save = "fc_save"
    case fc_project_context = "fc_project_context"
    case fc_ctx_project = "fc_ctx_project"
    case fc_ctx_branch = "fc_ctx_branch"
    case fc_ctx_files = "fc_ctx_files"
    case fc_ctx_model = "fc_ctx_model"
    case fc_ctx_mode = "fc_ctx_mode"
    case fc_ctx_kb = "fc_ctx_kb"
    case fc_not_selected = "fc_not_selected"
    case fc_no_project_open = "fc_no_project_open"
    case fc_project_memory = "fc_project_memory"
    case fc_load_memory = "fc_load_memory"
    case fc_write_memory = "fc_write_memory"
    case fc_sessions = "fc_sessions"
    case fc_no_sessions = "fc_no_sessions"
    case fc_messages_count = "fc_messages_count"
    case fc_workflow_templates = "fc_workflow_templates"
    case fc_tpl_review = "fc_tpl_review"
    case fc_tpl_test = "fc_tpl_test"
    case fc_tpl_debug = "fc_tpl_debug"
    case fc_tpl_refactor = "fc_tpl_refactor"
    case fc_tpl_explain = "fc_tpl_explain"
    case fc_tpl_deploy = "fc_tpl_deploy"
    case fc_msg_model_switched = "fc_msg_model_switched"
    case fc_msg_current_model = "fc_msg_current_model"
    case fc_msg_context_compacted = "fc_msg_context_compacted"
    case fc_msg_unknown_cmd = "fc_msg_unknown_cmd"
    case fc_msg_kb_usage = "fc_msg_kb_usage"
    case fc_msg_no_project_open = "fc_msg_no_project_open"
    case fc_msg_kb_no_results = "fc_msg_kb_no_results"
    case fc_msg_kb_results = "fc_msg_kb_results"
    case fc_msg_kb_failed = "fc_msg_kb_failed"
    case fc_msg_no_project = "fc_msg_no_project"
    case fc_msg_no_memory = "fc_msg_no_memory"
    case fc_msg_memory_files = "fc_msg_memory_files"
    case fc_msg_memory_failed = "fc_msg_memory_failed"
    case fc_kb_building = "fc_kb_building"
    case fc_kb_build_failed = "fc_kb_build_failed"
    case fc_tool_edit = "fc_tool_edit"
    case fc_tool_write = "fc_tool_write"
    case fc_tool_run = "fc_tool_run"
    case fc_tool_multi_edit = "fc_tool_multi_edit"
    case fc_denied_by_user = "fc_denied_by_user"
    case fc_approve = "fc_approve"
    case fc_deny = "fc_deny"
    case fc_apply_code = "fc_apply_code"
    case fc_apply_code_n = "fc_apply_code_n"
    case fc_status_pending = "fc_status_pending"
    case fc_status_running = "fc_status_running"
    case fc_status_approved = "fc_status_approved"
    case fc_status_denied = "fc_status_denied"
    case fc_status_completed = "fc_status_completed"
    case fc_status_failed = "fc_status_failed"
    case fc_code = "fc_code"
    case fc_copied = "fc_copied"
    case fc_copy = "fc_copy"
    case fc_no_matching_commands = "fc_no_matching_commands"
    case fc_new_session = "fc_new_session"
    case fc_title = "fc_title"
    case fc_session_title_ph = "fc_session_title_ph"
    case fc_cancel = "fc_cancel"
    case fc_create = "fc_create"
    case fc_permission_request = "fc_permission_request"
    case fc_tool_label = "fc_tool_label"
    case fc_open_project_folder = "fc_open_project_folder"
    case fc_open_file = "fc_open_file"
    case fc_scanning = "fc_scanning"
    case fc_loaded_files = "fc_loaded_files"
    case fc_loading = "fc_loading"
    case fc_loaded_one_file = "fc_loaded_one_file"
    case fc_load_failed = "fc_load_failed"
    case fc_scanning_n = "fc_scanning_n"
    case fc_ai_unavailable = "fc_ai_unavailable"
    case fc_sidebar_chat = "fc_sidebar_chat"
    case fc_sidebar_files = "fc_sidebar_files"
    case fc_sidebar_git = "fc_sidebar_git"
    case fc_sidebar_design = "fc_sidebar_design"
    case fc_toggle_sidebar = "fc_toggle_sidebar"
    case fc_input_ask_anything = "fc_input_ask_anything"
    case fc_attach_file = "fc_attach_file"
    case fc_menu_add_folder = "fc_menu_add_folder"
    case fc_menu_add_file = "fc_menu_add_file"
    case fc_menu_add_github = "fc_menu_add_github"
    case fc_git_url_detected = "fc_git_url_detected"
    case fc_send = "fc_send"
    case fc_open_project = "fc_open_project"
    case fc_local_folder = "fc_local_folder"
    case fc_local_folder_desc = "fc_local_folder_desc"
    case fc_choose = "fc_choose"
    case fc_single_file = "fc_single_file"
    case fc_single_file_desc = "fc_single_file_desc"
    case fc_github_repo = "fc_github_repo"
    case fc_github_repo_desc = "fc_github_repo_desc"
    case fc_url = "fc_url"
    case fc_branch = "fc_branch"
    case fc_clone_open = "fc_clone_open"
    case fc_or = "fc_or"
    case fc_drop_here = "fc_drop_here"
    case fc_search_conversations = "fc_search_conversations"
    case fc_no_conversations = "fc_no_conversations"
    case fc_files_count = "fc_files_count"
    case fc_close_project = "fc_close_project"
    case fc_open_another = "fc_open_another"
    case fc_search_files = "fc_search_files"
    case fc_open_folder_browse = "fc_open_folder_browse"
    case fc_show_in_finder = "fc_show_in_finder"
    case fc_copy_path = "fc_copy_path"
    case fc_remove_context = "fc_remove_context"
    case fc_add_to_context = "fc_add_to_context"
    case fc_add_to_kb = "fc_add_to_kb"
    case fc_index_to_rag = "fc_index_to_rag"
    case fc_add_dir_to_kb = "fc_add_dir_to_kb"
    case fc_not_git_repo = "fc_not_git_repo"
    case fc_open_for_git = "fc_open_for_git"
    case fc_no_changes = "fc_no_changes"
    case fc_welcome_title = "fc_welcome_title"
    case fc_welcome_tagline = "fc_welcome_tagline"
    case fc_wc_open_title = "fc_wc_open_title"
    case fc_wc_open_desc = "fc_wc_open_desc"
    case fc_wc_explain_title = "fc_wc_explain_title"
    case fc_wc_explain_desc = "fc_wc_explain_desc"
    case fc_wc_review_title = "fc_wc_review_title"
    case fc_wc_review_desc = "fc_wc_review_desc"
    case fc_wc_test_title = "fc_wc_test_title"
    case fc_wc_test_desc = "fc_wc_test_desc"
    case fc_recent = "fc_recent"
    case fc_min_ago = "fc_min_ago"
    case fc_hour_ago = "fc_hour_ago"
    case fc_day_ago = "fc_day_ago"
    case fc_term_banner = "fc_term_banner"
    case fc_term_help_hint = "fc_term_help_hint"
    case fc_terminal = "fc_terminal"
    case fc_clear = "fc_clear"
    case fc_term_commands = "fc_term_commands"
    case fc_term_unknown = "fc_term_unknown"
    case fc_you = "fc_you"
    case fc_clone = "fc_clone"
    case fc_group_mode = "fc_group_mode"
    case fc_search_sessions = "fc_search_sessions"
    case fc_no_project2 = "fc_no_project2"
    case fc_rename = "fc_rename"
    case fc_pause = "fc_pause"
    case fc_resume = "fc_resume"
    case fc_delete = "fc_delete"
    case fc_layout_mode = "fc_layout_mode"
    case fc_sessions_count = "fc_sessions_count"
    case fc_new_session_full = "fc_new_session_full"
    case fc_working_dir = "fc_working_dir"
    case fc_model_label = "fc_model_label"
    case fc_security_mode = "fc_security_mode"
    case fc_sm_readonly = "fc_sm_readonly"
    case fc_sm_manual = "fc_sm_manual"
    case fc_sm_auto = "fc_sm_auto"
    case fc_gm_by_project = "fc_gm_by_project"
    case fc_gm_by_state = "fc_gm_by_state"
    case fc_gm_flat = "fc_gm_flat"
    case fc_state_idle = "fc_state_idle"
    case fc_state_running = "fc_state_running"
    case fc_state_waiting = "fc_state_waiting"
    case fc_state_paused = "fc_state_paused"
    case fc_state_completed = "fc_state_completed"
    case fc_state_failed = "fc_state_failed"
    case fc_state_cluster = "fc_state_cluster"
    case fc_sm_auto_full = "fc_sm_auto_full"
    case fc_policy = "fc_policy"
    case fc_audit = "fc_audit"
    case fc_allow_dirs = "fc_allow_dirs"
    case fc_add_dir_ph = "fc_add_dir_ph"
    case fc_add = "fc_add"
    case fc_ignore_patterns = "fc_ignore_patterns"
    case fc_add_pattern_ph = "fc_add_pattern_ph"
    case fc_no_audit = "fc_no_audit"
    case fc_records_count = "fc_records_count"
    case fc_export = "fc_export"
    case fc_wf_empty_desc = "fc_wf_empty_desc"
    case fc_wf_new = "fc_wf_new"
    case fc_wf_goal_ph = "fc_wf_goal_ph"
    case fc_wf_select_template = "fc_wf_select_template"
    case fc_wf_template_generic = "fc_wf_template_generic"
    case fc_wf_template_legacy = "fc_wf_template_legacy"
    case fc_wf_template_security = "fc_wf_template_security"
    case fc_wf_template_batch = "fc_wf_template_batch"
    case fc_wf_template_refactor = "fc_wf_template_refactor"
    case fc_wf_template_test = "fc_wf_template_test"
    case fc_wf_status_failed = "fc_wf_status_failed"
    case fc_wf_status_running = "fc_wf_status_running"
    case fc_wf_status_completed = "fc_wf_status_completed"
    case fc_wf_status_pending = "fc_wf_status_pending"
    case fc_preview = "fc_preview"
    case fc_live = "fc_live"
    case fc_html_preview_empty = "fc_html_preview_empty"
    case fc_original = "fc_original"
    case fc_modified = "fc_modified"
    case fc_design_open_in_module = "fc_design_open_in_module"
    case fc_design_no_content = "fc_design_no_content"
    case fc_design_create_hint = "fc_design_create_hint"
    case fc_design_sync_on = "fc_design_sync_on"
    case fc_design_sync_off = "fc_design_sync_off"
    case fc_design_export_file = "fc_design_export_file"
    case fc_tier_global = "fc_tier_global"
    case fc_tier_project = "fc_tier_project"
    case fc_tier_directory = "fc_tier_directory"
    case fc_diff_split = "fc_diff_split"
    case fc_diff_unified = "fc_diff_unified"
    case fc_diff_line_numbers = "fc_diff_line_numbers"
    case fc_snapshots = "fc_snapshots"
    case fc_no_snapshots = "fc_no_snapshots"
    case fc_create_snapshot = "fc_create_snapshot"
    case fc_label_optional = "fc_label_optional"
    case fc_restore = "fc_restore"
    case fc_rewind_here = "fc_rewind_here"
    case fc_snap_deltas_fmt = "fc_snap_deltas_fmt"
    case fc_snap_not_found = "fc_snap_not_found"
    case fc_pty_stopped = "fc_pty_stopped"
    case fc_pty_clear = "fc_pty_clear"
    case fc_pty_stop = "fc_pty_stop"
    case fc_pty_restart = "fc_pty_restart"
    case fc_pty_shell_started = "fc_pty_shell_started"
    case fc_pty_shell_exited = "fc_pty_shell_exited"
    case fc_pty_start_fail = "fc_pty_start_fail"
    case fc_pty_alloc_fail = "fc_pty_alloc_fail"
    case fc_copy_suffix = "fc_copy_suffix"
    case fc_untitled = "fc_untitled"
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
    "close": "关闭", "search": "搜索", "refresh": "刷新", "loading": "加载中...", "filter": "筛选", "clear": "清除", "retry": "重试", "add": "添加",
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
    "secPlugin": "Plugin Ecosystem", "secTrainer": "Trainer",

    "newProject": "新建项目", "openLocalFolder": "打开本地文件夹",
    "newWorkspace": "新建协作空间", "newWorkbench": "新建工作台",
    "noConversationsYet": "暂无对话", "noArtifactsYet": "暂无 Artifacts",
    "openArtifacts": "打开 Artifacts",
    "runDashboard": "运营看板", "pendingPublish": "待发布", "published": "已发布",
    "hitProduct": "爆款", "douyinHint": "点击「运营看板」进入主区操作造片 / 发布 / 评论 / 进化",

    "mod_dashboard": "控制台", "mod_design": "设计", "mod_code": "编码", "mod_simulation": "仿真", "mod_modelHub": "模型", "mod_multimodal": "多模态", "mod_training": "训练", "mod_cli": "命令行", "mod_doc": "文档", "mod_bench": "测评", "mod_desk": "自动化", "mod_dataTools": "数据工具", "mod_agent": "智能体", "mod_plugin": "插件", "mod_security": "安全", "mod_analytics": "分析", "mod_collab": "协作", "mod_tuning": "调优", "mod_external": "外部集成", "mod_docgen": "文档生成", "mod_clusterOverview": "集群总览", "mod_clusterTopology": "拓扑图", "mod_clusterSync": "集群同步", "mod_taskMonitor": "任务监控", "mod_alertCenter": "告警中心", "mod_nodeActions": "节点管理", "mod_submitTask": "提交任务", "mod_taskProgress": "任务详情", "mod_routingStrategy": "路由策略", "mod_kvCache": "KV缓存", "mod_serviceWeb": "服务面板", "mod_rag": "RAG", "mod_memory": "记忆", "mod_planner": "规划", "mod_deploy": "部署", "mod_operations": "运维", "mod_eduK12": "教育", "mod_verification": "验证", "mod_tokenBudget": "预算", "mod_safety": "安全审批", "mod_tools": "工具", "mod_agentDashboard": "Agent监控", "mod_teamCollab": "团队协作", "mod_chat": "对话", "mod_fusionProjects": "项目管理", "mod_cowork": "协作空间", "mod_artifactsRepo": "Artifacts仓库", "mod_fsb": "FSB", "mod_aiAgentDashboard": "AI总览", "mod_aiAgentList": "Agent列表", "mod_aiAgentChat": "AI对话", "mod_aiAgentObserver": "AI监控", "mod_aiAgentKnowledgeBase": "AI知识库", "mod_science": "科研", "mod_finance": "金融", "mod_health": "健康", "mod_pluginConfig": "插件配置", "mod_pluginStatus": "插件状态", "mod_pluginToken": "Token", "mod_pluginVram": "VRAM", "mod_pluginLog": "插件日志", "mod_pluginMcp": "MCP", "mod_trainer": "训练管理",

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
    "proj_panelTitle": "项目",
    "proj_panelSort": "排序：",
    "proj_panelNew": "新建",
    "proj_emptyTitle": "想开始一个项目吗？",
    "proj_emptyHint": "在一个空间内上传素材、设置自定义指令并整理对话。",
    "proj_panelNewProject": "新建项目",
    "proj_tokensFmt": "%d tokens",
    "proj_panelKbEmpty": "暂无知识库文件",
    "proj_panelAutoScan": "自动扫描",
    "proj_panelCustomInst": "自定义指令",
    "proj_panelChatHistory": "聊天记录",
    "proj_panelNewChat": "新建会话",
    "proj_sessionsFmt": "%d 个会话",
    "proj_panelChatEmpty": "暂无会话",
    "proj_panelStartConv": "开始对话",
    "proj_msgsFmt": "%d 条消息",
    "proj_panelSelect": "选择一个项目",
    "proj_panelOpenFolder": "打开项目文件夹",
    "proj_panelOpen": "打开",
    "proj_panelAddKbFiles": "添加知识库文件",
    "proj_panelDefaultModel": "默认模型",
    "proj_panelModelPh": "例如 qwen3-9b",
    "proj_panelDefault": "默认",
    "proj_panelTempFmt": "温度: %@",
    "proj_panelMaxTokensFmt": "最大 Tokens: %d",
    "proj_panelAutoLoadClaude": "自动加载 CLAUDE.md",
    "proj_panelAutoScanKb": "自动扫描知识库文件",
    "proj_tabSessions": "会话",
    "proj_tabSettings": "设置",
    "cw_snap_title": "会话快照",
    "cw_snap_create": "创建快照",
    "cw_snap_empty": "暂无快照",
    "cw_list_subtitle": "协作空间 — 团队对话、共享 Agent、工作流协同",
    "cw_list_searchPh": "搜索空间...",
    "cw_list_newHelp": "新建协作空间",
    "cw_list_marketHelp": "工作流/模板市场",
    "cw_filter_all": "全部",
    "cw_filter_created": "我创建的",
    "cw_filter_joined": "我加入的",
    "cw_filter_archived": "已归档",
    "cw_list_onboardingTitle": "开始你的第一个协作空间",
    "cw_list_onboardingBody": "CoWork 让团队实时对话、共享 Agent、协同工作流。支持离线空间、深度研究、桌面共享等差异化能力。",
    "cw_list_createLabel": "创建协作空间",
    "cw_list_archivedTag": "已归档",
    "cw_list_emptyTitle": "选择一个协作空间",
    "cw_list_emptyHint": "或创建新空间开始协作",
    "cw_list_loadFail": "加载失败: %@",
    "cw_create_title": "新建协作空间",
    "cw_create_basic": "基本信息",
    "cw_create_namePh": "空间名称",
    "cw_create_descPh": "描述（可选）",
    "cw_create_mode": "协作模式",
    "cw_create_modeLocal": "本机",
    "cw_create_modeP2p": "局域网",
    "cw_create_modeGateway": "远程",
    "cw_create_modeLocalDesc": "单机离线协作",
    "cw_create_modeP2pDesc": "Bonjour 局域网发现",
    "cw_create_modeGatewayDesc": "通过 Fusion Gateway",
    "cw_create_kb": "知识库绑定",
    "cw_create_kbPh": "KB 路径（可选，如项目目录）",
    "cw_create_ability": "空间能力",
    "cw_create_webSearch": "联网搜索",
    "cw_create_deepResearch": "深度研究",
    "cw_create_computerUse": "桌面操控",
    "cw_create_memberUpload": "成员上传",
    "cw_create_memberAgent": "成员自建Agent",
    "cw_create_memberWorkflow": "成员运行工作流",
    "cw_create_advanced": "高级设置",
    "cw_create_maxMembers": "最大成员数",
    "cw_create_btn": "创建",
    "cw_main_loading": "加载中...",
    "cw_main_deepResearch": "深度研究",
    "cw_main_computerUse": "桌面操控",
    "cw_main_createSnap": "创建快照",
    "cw_main_archive": "归档空间",
    "cw_main_archivedBanner": "此空间已归档 — 只读模式",
    "cw_side_members": "成员",
    "cw_side_files": "文件",
    "cw_side_knowledge": "知识库",
    "cw_side_agents": "Agent",
    "cw_side_artifacts": "产物",
    "cw_side_workflows": "工作流",
    "cw_side_snapshots": "快照",
    "cw_side_desktop": "桌面",
    "cw_side_settings": "设置",
    "cw_chat_emptyTitle": "空间对话",
    "cw_chat_emptyHint": "发送第一条消息，或 @Agent 开始协作",
    "cw_chat_thinking": "思考中...",
    "cw_chat_copy": "复制",
    "cw_chat_retry": "重试",
    "cw_chat_attach": "附件",
    "cw_chat_screenshot": "截图",
    "cw_chat_noAgent": "无 (直接发送)",
    "cw_chat_inputPh": "输入消息，@Agent 协作...",
    "cw_chat_relay": "Agent 接力",
    "cw_chat_relayHint": "选择多个 Agent 依次处理消息",
    "cw_chat_relayClear": "清除",
    "cw_chat_relayDone": "完成",
    "cw_chat_streamErr": "错误: %@",
    "cw_chat_sendFail": "发送失败: %@",
    "cw_chat_relayFail": "接力失败: %@",
    "cw_system_name": "系统",
    "cw_comment_title": "批注",
    "cw_comment_addPh": "添加批注...",
    "cw_comment_send": "发送",
    "cw_member_title": "成员",
    "cw_member_lanDiscovery": "局域网发现",
    "cw_member_scanning": "扫描中...",
    "cw_member_scan": "扫描",
    "cw_member_inviteTitle": "邀请成员",
    "cw_member_inviteRole": "角色",
    "cw_member_inviteMaxUses": "最大使用次数: %d",
    "cw_member_inviteExpires": "过期时间(小时): %d",
    "cw_member_inviteGen": "生成邀请链接",
    "cw_member_inviteCode": "邀请码: %@",
    "cw_member_remove": "移除",
    "cw_role_owner": "所有者",
    "cw_role_admin": "管理员",
    "cw_role_member": "成员",
    "cw_role_viewer": "观察者",
    "cw_files_title": "文件",
    "cw_files_empty": "暂无文件",
    "cw_agent_title": "Agent",
    "cw_agent_empty": "暂无共享 Agent",
    "cw_agent_add": "添加 Agent",
    "cw_agent_edit": "编辑",
    "cw_agent_copyToProject": "复制到项目",
    "cw_agent_remove": "移除",
    "cw_agent_addTitle": "添加 Agent",
    "cw_agent_editTitle": "编辑 Agent",
    "cw_agent_name": "名称",
    "cw_agent_namePh": "Agent 名称",
    "cw_agent_model": "模型",
    "cw_agent_modelPh": "模型（留空使用默认）",
    "cw_agent_perm": "权限",
    "cw_agent_permAll": "全部成员可用",
    "cw_agent_permAdmin": "仅管理员",
    "cw_agent_permCustom": "指定成员",
    "cw_agent_permAllLabel": "全部成员",
    "cw_agent_permCustomLabel": "自定义",
    "cw_snap2_title": "快照",
    "cw_snap2_empty": "暂无快照",
    "cw_snap2_createTitle": "创建快照",
    "cw_snap2_namePh": "名称",
    "cw_snap2_forkTitle": "Fork 快照",
    "cw_snap2_forkSpacePh": "新空间名称",
    "cw_snap2_restore": "恢复此快照",
    "cw_snap2_forkNew": "Fork 为新空间",
    "cw_snap2_msgCount": "%d 条消息",
    "cw_snap2_dagName": "DAG: %@",
    "cw_art_title": "产物",
    "cw_art_kindAll": "全部",
    "cw_art_kindCode": "代码",
    "cw_art_kindDoc": "文档",
    "cw_art_kindViz": "可视化",
    "cw_art_kindData": "数据",
    "cw_art_createTitle": "创建产物",
    "cw_art_kindPicker": "类型",
    "cw_wf_title": "工作流",
    "cw_wf_empty": "暂无工作流",
    "cw_wf_create": "创建工作流",
    "cw_wf_createTitle": "创建工作流",
    "cw_wf_namePh": "工作流名称",
    "cw_wf_descPh": "描述 (可选)",
    "cw_wf_nodeCount": "%d 节点",
    "cw_wf_status_running": "运行中",
    "cw_wf_status_completed": "已完成",
    "cw_wf_status_failed": "失败",
    "cw_wf_status_idle": "空闲",
    "cw_snap_emptyHint": "创建快照以保存当前会话状态，可随时回溯或 Fork",
    "cw_snap_labelPh": "标签（可选）",
    "cw_snap_createBtn": "创建",
    "cw_snap_forkAlert": "Fork 此快照为新会话？",
    "cw_snap_forkBtn": "Fork",
    "cw_snap_msgFmt": "%d 条消息",
    "cw_snap_restoreHelp": "恢复到此快照",
    "cw_snap_forkHelp": "Fork 为新会话",
    "cw_snap_deleteHelp": "删除快照",
    "cw_snap_forkAlertBtn": "Fork",
    "cw_desk_title": "桌面",
    "cw_desk_role": "角色",
    "cw_desk_roleObserver": "观察者",
    "cw_desk_roleController": "控制者",
    "cw_desk_roleApprover": "审批者",
    "cw_desk_notSharing": "桌面共享未开启",
    "cw_desk_controlReq": "控制请求",
    "cw_desk_approve": "批准",
    "cw_desk_reject": "拒绝",
    "cw_desk_auditLog": "操作记录",
    "cw_desk_sharing": "共享中",
    "cw_set_title": "设置",
    "cw_set_streamResp": "流式响应",
    "cw_research_running": "进行中...",
    "cw_research_queryPh": "输入研究问题...",
    "cw_research_depth": "深度",
    "cw_research_depthShallow": "浅",
    "cw_research_depthMedium": "中",
    "cw_research_depthDeep": "深",
    "cw_research_start": "开始研究",
    "cw_research_multiAgent": "多Agent并行",
    "cw_research_autoSelect": "自动选择",
    "cw_research_agentCountFmt": "%d Agents",
    "cw_research_zeroToken": "零Token成本 · 本地推理",
    "cw_research_runningProgress": "深度研究进行中...",
    "cw_research_desc": "深度研究利用多Agent并行推理，自动完成复杂调研",
    "cw_research_vsClaude": "相比 Claude CoWork：零 Token 成本 · 本地模型推理 · 可选多Agent并行",
    "cw_research_track": "研究路径",
    "cw_research_agentProgress": "Agent 研究进度",
    "cw_research_noResult": "研究完成，无结果文本",
    "cw_research_failFmt": "研究失败: %@",
    "cw_research_done": "完成",
    "cw_research_runningStatus": "研究中...",
    "cw_preview_empty": "暂无预览内容",
    "cw_notif_title": "通知",
    "cw_notif_markAll": "全部已读",
    "cw_notif_empty": "暂无通知",
    "cw_kb_title": "知识库",
    "cw_kb_unbound": "知识库未绑定",
    "cw_kb_bindHint": "绑定知识库后，Agent 对话将自动检索相关文档",
    "cw_kb_bind": "绑定知识库",
    "cw_kb_statsFmt": "%d 文档, %d 分块",
    "cw_kb_searchPh": "搜索知识库...",
    "cw_kb_results": "搜索结果",
    "cw_kb_ragAnswer": "RAG 回答",
    "cw_kb_upload": "上传文档",
    "cw_kb_uploadTitle": "上传文档到知识库",
    "cw_kb_pathPh": "文件路径",
    "cw_kb_uploadBtn": "上传",
    "cw_kb_docFmt": "文档 %d",
    "cw_mkt_title": "市场",
    "cw_mkt_type": "类型",
    "cw_mkt_typeWorkflow": "工作流",
    "cw_mkt_typeArtifact": "产物模板",
    "cw_mkt_install": "安装",
    "cw_home_mode_chat": "Chat",
    "cw_home_mode_cowork": "CoWork",
    "cw_home_pick_title": "选择授权文件夹",
    "cw_home_pick_prompt": "CoWork 将只能访问你授权的文件夹",
    "cw_home_pick_confirm": "授权",
    "cw_home_no_scoped": "请选择授权文件夹后开始",
    "cw_home_svc_down": "fusion-cowork 未启动（设置 → 上游服务）",
    "cw_home_submit_fail": "提交失败：",
    "cw_home_bubble_step": "步骤",
    "cw_home_bubble_done": "完成",
    "cw_home_bubble_error": "错误",
    "cw_home_bubble_artifact": "产物",
    "ai_offline_badge": "离线",
    "ai_offline_helpOff": "离线模式 — 点击查看详情",
    "ai_offline_helpOn": "在线模式",
    "ai_offline_netStatus": "网络状态",
    "ai_offline_offMode": "离线模式",
    "ai_offline_onMode": "在线模式",
    "ai_offline_reasonFmt": "原因: %@",
    "ai_offline_disabledTitle": "离线模式下不可用的功能:",
    "ai_offline_featInfer": "模型推理",
    "ai_offline_featKb": "知识库查询",
    "ai_offline_featCode": "代码生成",
    "ai_offline_manual": "用户手动切换",
    "ai_audit_title": "审计日志",
    "ai_audit_toolPh": "工具名",
    "ai_audit_typePh": "操作类型",
    "ai_audit_sincePh": "起始时间",
    "ai_audit_sinceHint": "如 2025-01-01",
    "ai_audit_apply": "应用",
    "ai_audit_freq": "工具调用频率",
    "ai_audit_empty": "暂无审计日志",
    "ai_monitor_title": "模型负载监控",
    "ai_monitor_refreshFmt": "每 %ds 刷新",
    "ai_monitor_manualRefresh": "手动刷新",
    "ai_monitor_connected": "MLX 已连接",
    "ai_monitor_disconnected": "MLX 未连接",
    "ai_monitor_startMlx": "启动 MLX",
    "ai_monitor_availModels": "可用模型",
    "ai_monitor_noModels": "暂无模型",
    "ai_monitor_loaded": "已加载",
    "ai_monitor_load": "加载",
    "ai_monitor_loadingStatus": "加载模型状态...",
    "ai_monitor_errFmt": "无法获取模型状态: %@",
    "ai_perm_title": "权限标签",
    "ai_perm_capsTitle": "能力权限",
    "ai_perm_empty": "暂无权限数据",
    "ai_perm_agentFmt": "Agent %@",
    "ai_perm_deniedTitle": "FUSION.rules 禁用工具",
    "ai_perm_toolPh": "工具名",
    "ai_perm_sensitiveTitle": "敏感文件模式",
    "ai_perm_sensitiveTag": "敏感",
    "ai_perm_capRead": "读取知识库",
    "ai_perm_capWrite": "写入知识库",
    "ai_perm_capDelete": "删除知识库",
    "ai_perm_capCode": "执行代码",
    "ai_perm_capNet": "访问网络",
    "ai_review_title": "Diff 审查",
    "ai_review_export": "导出 review.md",
    "ai_review_sevCritical": "严重",
    "ai_review_sevWarning": "警告",
    "ai_review_sevInfo": "信息",
    "ai_review_empty": "暂无 Diff 数据",
    "ai_review_exportTitle": "导出 review.md",
    "ai_review_copy": "复制到剪贴板",
    "ai_dash_title": "控制台总览",
    "ai_dash_subtitle": "Agent 管理控制台 — 全局数据看板与快捷入口",
    "ai_dash_statToday": "今日请求",
    "ai_dash_statToken": "Token 消耗",
    "ai_dash_statActive": "活跃 Agent",
    "ai_dash_statError": "异常请求",
    "ai_dash_quickTitle": "快捷入口",
    "ai_dash_qaCreate": "创建新 Agent",
    "ai_dash_qaKb": "新建知识库",
    "ai_dash_qaConnector": "管理连接器",
    "ai_dash_qaApiDoc": "API 文档",
    "ai_dash_recentTitle": "最近 Agent",
    "ai_dash_recentViewAll": "查看全部",
    "ai_dash_empty": "暂无 Agent，点击上方创建",
    "ai_dash_alertTitle": "告警通知",
    "ai_dash_alertEmpty": "一切正常，无告警",
    "ai_dash_alertUnknown": "未知告警",
    "ai_list_create": "创建 Agent",
    "ai_list_searchPh": "搜索 Agent 名称...",
    "ai_list_delTitle": "确认删除",
    "ai_list_delMsgFmt": "确定要删除 Agent「%@」吗？此操作不可撤销。",
    "ai_list_filterFmt": "筛选: %@",
    "ai_list_hName": "Agent 名称",
    "ai_list_hStatus": "状态",
    "ai_list_hModel": "模型",
    "ai_list_hKb": "关联知识库",
    "ai_list_hUpdated": "最后更新",
    "ai_list_hAction": "操作",
    "ai_list_empty": "暂无 Agent",
    "ai_list_emptyHint": "点击「创建 Agent」开始构建智能体",
    "ai_list_actDebug": "调试",
    "ai_list_actEdit": "编辑",
    "ai_list_actClone": "复制",
    "ai_list_actArchive": "归档",
    "ai_list_actDelete": "删除",
    "ai_list_scopeAll": "全部",
    "ai_list_scopeDraft": "草稿",
    "ai_list_scopePublished": "已发布",
    "ai_list_sortUpdated": "最近更新",
    "ai_list_sortCreated": "创建时间",
    "ai_list_sortName": "名称",
    "ai_kb_title": "知识库管理",
    "ai_kb_searchPh": "搜索项目...",
    "ai_kb_newBtn": "新建项目",
    "ai_kb_unnamed": "未命名",
    "ai_kb_createdFmt": "创建于 %@",
    "ai_kb_detail": "详情",
    "ai_kb_statusActive": "活跃",
    "ai_kb_empty": "暂无知识库项目",
    "ai_kb_emptyHint": "创建项目，上传文档，为 Agent 提供知识支撑",
    "ai_kb_sheetTitle": "新建知识库项目",
    "ai_kb_sheetName": "项目名称",
    "ai_kb_sheetNamePh": "输入项目名称",
    "ai_kb_sheetDesc": "项目描述",
    "ai_kb_sheetCreate": "创建",
    "ai_kb_detTitle": "项目详情",
    "ai_kb_detTabFiles": "文件",
    "ai_kb_detTabInstruction": "指令",
    "ai_kb_detTabAgents": "关联Agent",
    "ai_kb_filesEmpty": "暂无文件",
    "ai_kb_artRemove": "移除",
    "ai_kb_instrTitle": "项目指令",
    "ai_kb_instrSave": "保存指令",
    "ai_kb_agentsTitle": "绑定此知识库的 Agent",
    "ai_kb_agentsEmpty": "暂无 Agent 绑定此知识库",
    "ai_chat_welcomeTitle": "开始与 Agent 对话",
    "ai_chat_welcomeHint": "选择一个 Agent，输入消息即可开始",
    "ai_chat_noAgent": "暂无可用 Agent，请先创建",
    "ai_chat_streaming": "生成中...",
    "ai_chat_qaSummarize": "总结文档",
    "ai_chat_qaCode": "代码生成",
    "ai_chat_qaData": "数据分析",
    "ai_chat_qaTranslate": "翻译",
    "ai_chat_qaWrite": "创意写作",
    "ai_chat_inputPh": "输入消息...",
    "ai_chat_toolbox": "工具箱",
    "ai_chat_toolWebSearch": "网页搜索",
    "ai_chat_toolResearch": "深度调研",
    "ai_chat_toolCode": "代码执行",
    "ai_chat_toolKb": "知识库查询",
    "ai_chat_pickTitle": "选择 Agent",
    "ai_chat_pickEmpty": "暂无可用 Agent",
    "ai_chat_noResponse": "（无响应）",
    "ai_chat_rtTitle": "运行时配置",
    "ai_chat_rtMaxTokens": "最大 Token",
    "ai_chat_rtApply": "应用到当前会话",
    "ai_chat_reqFailedFmt": "请求失败：%@",
    "ai_debug_title": "调试面板",
    "ai_debug_agentFmt": "Agent %@",
    "ai_debug_executing": "执行中",
    "ai_debug_ready": "就绪",
    "ai_debug_chatEmpty": "发送消息测试 Agent 响应",
    "ai_debug_chatEmptyHint": "调试模式下可实时查看执行步骤和工具调用",
    "ai_debug_inputPh": "输入测试消息...",
    "ai_debug_logsTitle": "当前会话日志",
    "ai_debug_loadHistory": "加载历史",
    "ai_debug_logsEmpty": "执行日志为空",
    "ai_debug_logsEmptyHint": "发送测试消息后，执行步骤将出现在这里",
    "ai_debug_tasksEmpty": "暂无代码任务",
    "ai_debug_tasksEmptyHint": "提交代码让 Agent 执行并查看结果",
    "ai_debug_lang": "语言",
    "ai_debug_submit": "提交",
    "ai_debug_logReceiveFmt": "收到用户消息：%@",
    "ai_debug_noResponse": "（无响应内容）",
    "ai_debug_logExecDone": "Agent 执行完成",
    "ai_debug_logToolFmt": "调用工具：%@",
    "ai_debug_logExecFallback": "Agent 执行完成(fallback)",
    "ai_debug_logFailFmt": "执行失败：%@",
    "ai_debug_tabChat": "对话测试",
    "ai_debug_tabLogs": "执行日志",
    "ai_debug_tabTasks": "代码任务",
    "ai_obs_tabUsage": "用量统计",
    "ai_obs_tabLogs": "执行日志",
    "ai_obs_tabApikeys": "API 密钥",
    "ai_obs_tabConnectors": "连接器",
    "ai_obs_tabPermissions": "权限标签",
    "ai_obs_tabAudit": "审计日志",
    "ai_obs_title": "监控与管理",
    "ai_obs_subtitle": "用量统计 · 执行日志 · API 密钥 · 连接器",
    "ai_obs_statToday": "今日请求",
    "ai_obs_statToken": "总 Token",
    "ai_obs_statActive": "活跃 Agent",
    "ai_obs_statError": "错误率",
    "ai_obs_alerts": "告警",
    "ai_obs_logsEmpty": "暂无执行日志",
    "ai_obs_apikeysTitle": "API 密钥管理",
    "ai_obs_apikeyCreate": "创建密钥",
    "ai_obs_apikeysEmpty": "暂无 API 密钥",
    "ai_obs_createdFmt": "创建于 %@",
    "ai_obs_rotate": "轮换",
    "ai_obs_revoke": "吊销",
    "ai_obs_connTitle": "外部连接器",
    "ai_obs_connAdd": "添加连接器",
    "ai_obs_connEmpty": "暂无已配置的连接器",
    "ai_obs_connConnected": "已连接",
    "ai_obs_connDisconnected": "未连接",
    "ai_obs_connect": "连接",
    "ai_obs_unnamedKey": "未命名密钥",
    "ai_obs_unnamedConn": "未命名",
    "ai_cfg_tabBasic": "基础信息",
    "ai_cfg_tabInstructions": "系统指令",
    "ai_cfg_tabSoul": "人格 Soul",
    "ai_cfg_tabKnowledge": "知识库",
    "ai_cfg_tabTools": "工具配置",
    "ai_cfg_tabAdvanced": "高级参数",
    "ai_cfg_tabPublish": "发布",
    "ai_cfg_skillAddTitle": "添加技能",
    "ai_cfg_skillNamePh": "技能名称",
    "ai_cfg_skillDescPh": "技能描述（可选）",
    "ai_cfg_modeCreate": "创建新 Agent",
    "ai_cfg_modeEditFmt": "编辑 Agent：%@",
    "ai_cfg_subCreate": "配置智能体的基础信息、指令、工具和参数",
    "ai_cfg_subEdit": "修改 Agent 配置后保存或发布",
    "ai_cfg_nameLabel": "Agent 名称",
    "ai_cfg_namePh": "输入 Agent 名称",
    "ai_cfg_descLabel": "简介",
    "ai_cfg_descPh": "描述 Agent 的功能和用途",
    "ai_cfg_modelLabel": "模型选择",
    "ai_cfg_modelPicker": "模型",
    "ai_cfg_modelChoose": "选择模型",
    "ai_cfg_visLabel": "可见范围",
    "ai_cfg_visPrivate": "仅本人可见",
    "ai_cfg_visOrg": "组织共享",
    "ai_cfg_instrHint": "编写 Agent 基础角色、行为约束、输出规范",
    "ai_cfg_charFmt": "%d 字符",
    "ai_cfg_instrSaveTpl": "保存模板",
    "ai_cfg_instrRestore": "恢复历史版本",
    "ai_cfg_soulHint": "定义 Agent 的人格特质、说话风格、情感偏好",
    "ai_cfg_soulSave": "保存 Soul",
    "ai_cfg_soulAfterCreate": "创建 Agent 后可编辑 Soul",
    "ai_cfg_kbLabel": "绑定知识库 Project",
    "ai_cfg_kbAdd": "+ 添加知识库",
    "ai_cfg_ragLabel": "检索策略",
    "ai_cfg_ragVector": "向量检索",
    "ai_cfg_ragFulltext": "全文检索",
    "ai_cfg_ragHybrid": "混合检索",
    "ai_cfg_autoQueryLabel": "自主查询",
    "ai_cfg_autoQueryToggle": "允许 Agent 主动查询知识库内容",
    "ai_cfg_toolsBuiltin": "内置工具",
    "ai_cfg_toolWebSearch": "网页搜索",
    "ai_cfg_toolDeepResearch": "深度调研模式",
    "ai_cfg_skillsLabel": "技能 Skills",
    "ai_cfg_skillCountFmt": "已添加 %d 个技能",
    "ai_cfg_skillsEmpty": "暂无技能，点击「添加技能」为 Agent 增加能力",
    "ai_cfg_skillsAfterCreate": "创建 Agent 后可管理技能",
    "ai_cfg_connLabel": "外部连接器 Connectors",
    "ai_cfg_connEmpty": "暂无已授权连接器",
    "ai_cfg_connUnknown": "未知",
    "ai_cfg_tempHint": "低=精确 高=创造",
    "ai_cfg_maxTokenLabel": "最大输出 Token",
    "ai_cfg_ctxLabel": "上下文窗口",
    "ai_cfg_styleLabel": "输出风格 Style",
    "ai_cfg_stylePicker": "风格",
    "ai_cfg_styleDefault": "默认",
    "ai_cfg_qpsLabel": "QPS 限流",
    "ai_cfg_qpsUnit": "请求/秒",
    "ai_cfg_pubLabel": "发布操作",
    "ai_cfg_pubBtn": "发布 Agent",
    "ai_cfg_pubGetApi": "获取 API 地址",
    "ai_cfg_pubSaveFirst": "请先保存草稿后再发布",
    "ai_cfg_summaryTitle": "配置摘要",
    "ai_cfg_sumName": "名称",
    "ai_cfg_sumModel": "模型",
    "ai_cfg_sumVis": "可见范围",
    "ai_cfg_sumKb": "知识库",
    "ai_cfg_sumKbUnbound": "未绑定",
    "ai_cfg_sumTools": "工具",
    "ai_cfg_sumMaxToken": "最大 Token",
    "ai_cfg_sumConnFmt": "%d 连接器",
    "ai_cfg_sumToolsNone": "未启用",
    "ai_cfg_deleteBtn": "删除 Agent",
    "ai_cfg_saveDraft": "保存草稿",
    "fsb_ws_renameAlertTitle": "重命名工作台",
    "fsb_ws_name": "名称",
    "fsb_ws_exportTitle": "导出工作台",
    "fsb_ws_copyClipboard": "复制到剪贴板",
    "fsb_ws_emptyWorkspaces": "暂无工作台",
    "fsb_ws_noMatch": "没有匹配的工作台",
    "fsb_ws_createWs": "创建工作台",
    "fsb_ws_headerTitle": "FSB 工作台",
    "fsb_ws_newWs": "新建工作台",
    "fsb_ws_listView": "列表视图",
    "fsb_ws_gridView": "网格视图",
    "fsb_ws_searchPh": "搜索工作台...",
    "fsb_unnamed": "未命名",
    "fsb_ws_connWfFmt": "%d连·%d流",
    "fsb_ws_open": "打开",
    "fsb_ws_rename": "重命名",
    "fsb_ws_duplicate": "复制",
    "fsb_ws_export": "导出",
    "fsb_ws_subtitle": "跨 SaaS 智能业务工作台",
    "fsb_ws_serviceDown": "FSB 服务未启动",
    "fsb_ws_usageGuide": "使用指南",
    "fsb_ws_namePh": "例如：客户管理系统",
    "fsb_ws_descOpt": "描述（可选）",
    "fsb_ws_descPh": "工作台用途说明",
    "fsb_ws_bindProjectOpt": "绑定项目（可选）",
    "fsb_ws_projectIdPh": "项目 ID",
    "fsb_ws_bindAgentOpt": "绑定 Agent（可选）",
    "fsb_ws_importTemplate": "从模板导入",
    "fsb_ws_createBtn": "创建",
    "fsb_ws_builtinTemplates": "内置模板",
    "fsb_tpl_crm_name": "客户关系管理",
    "fsb_tpl_crm_short": "CRM",
    "fsb_tpl_crm_desc": "管理客户信息、跟进记录、销售漏斗",
    "fsb_tpl_inventory_name": "库存管理",
    "fsb_tpl_inventory_short": "库存",
    "fsb_tpl_inventory_desc": "商品库存跟踪、补货提醒、出入库记录",
    "fsb_tpl_finance_name": "财务记账",
    "fsb_tpl_finance_short": "财务",
    "fsb_tpl_finance_desc": "收支记录、发票管理、财务报表生成",
    "fsb_tpl_email_name": "邮件营销",
    "fsb_tpl_email_short": "营销",
    "fsb_tpl_email_desc": "邮件模板、受众分组、发送排期、效果分析",
    "fsb_tpl_social_name": "社交媒体管理",
    "fsb_tpl_social_short": "社媒",
    "fsb_tpl_social_desc": "多平台发布、排期、互动监控、数据分析",
    "fsb_tpl_ticket_name": "工单系统",
    "fsb_tpl_ticket_short": "工单",
    "fsb_tpl_ticket_desc": "客户工单、分配、SLA 跟踪、满意度调查",
    "fsb_ob_welcome_title": "欢迎使用 FSB",
    "fsb_ob_welcome_desc": "Fusion Small Business 是一个跨 SaaS 的智能业务自动化工作台。\n无需编程，通过可视化工作流连接你的业务工具。",
    "fsb_ob_connectors_title": "连接器",
    "fsb_ob_connectors_desc": "连接你已有的 SaaS 工具：\nGoogle Workspace、Shopify、QuickBooks、Stripe 等。\n读操作自动执行，写操作需审批。",
    "fsb_ob_skills_title": "技能",
    "fsb_ob_skills_desc": "内置 15+ 智能技能：\n邮件摘要、数据提取、报表生成、翻译等。\n可自定义 Prompt 技能和 API 调用技能。",
    "fsb_ob_workflow_title": "工作流",
    "fsb_ob_workflow_desc": "可视化编排工作流：\n拖拽节点构建 DAG，条件分支，审批关卡。\n支持定时触发、事件触发、外部 API 触发。",
    "fsb_ob_start_title": "开始使用",
    "fsb_ob_start_desc": "创建一个工作台，选择模板或从零开始。\n所有数据本地运行，隐私安全。",
    "fsb_ob_prev": "上一步",
    "fsb_dlg_addConnector": "添加连接器",
    "fsb_dlg_connecting": "连接中...",
    "fsb_dlg_connect": "连接",
    "fsb_dlg_selectConnector": "选择连接器",
    "fsb_dlg_connector": "连接器",
    "fsb_dlg_selectPh": "请选择...",
    "fsb_dlg_supportFmt": "支持: %@",
    "fsb_dlg_authMethod": "认证方式",
    "fsb_dlg_auth": "认证",
    "fsb_dlg_noAuth": "无认证",
    "fsb_dlg_enterApiKey": "输入 API Key",
    "fsb_dlg_scopesHint": "Scopes (逗号分隔)",
    "fsb_dlg_createSkill": "创建技能",
    "fsb_dlg_saving": "保存中...",
    "fsb_dlg_create": "创建",
    "fsb_dlg_skillName": "技能名称",
    "fsb_dlg_displayName": "显示名称",
    "fsb_dlg_mySkill": "我的技能",
    "fsb_dlg_type": "类型",
    "fsb_dlg_prompt": "提示词",
    "fsb_dlg_function": "函数",
    "fsb_dlg_chain": "链式",
    "fsb_dlg_definition": "定义",
    "fsb_dlg_inputSchema": "输入 Schema (JSON)",
    "fsb_dlg_outputFormat": "输出格式",
    "fsb_dlg_plainText": "纯文本",
    "fsb_dlg_setSchedule": "设置排期",
    "fsb_dlg_triggerMethod": "触发方式",
    "fsb_dlg_manual": "手动",
    "fsb_dlg_cron": "定时 (Cron)",
    "fsb_dlg_eventDriven": "事件驱动",
    "fsb_dlg_manualOnly": "仅在工作台手动触发运行",
    "fsb_dlg_cronExpr": "Cron 表达式",
    "fsb_dlg_commonPresets": "常用预设",
    "fsb_dlg_preset_weekday9": "工作日9点",
    "fsb_dlg_preset_hourly": "每小时",
    "fsb_dlg_preset_daily8": "每天8点",
    "fsb_dlg_preset_monday9": "每周一9点",
    "fsb_dlg_preset_month1": "每月1号",
    "fsb_dlg_eventTrigger": "事件触发器",
    "fsb_dlg_eventPh": "如: data.updated, order.created",
    "fsb_dlg_eventHint": "支持事件类型: 数据变更、新记录、状态更新等",
    "fsb_dlg_approvalRequest": "审批请求",
    "fsb_dlg_requestContent": "请求内容",
    "fsb_dlg_editContent": "修改内容 (可选)",
    "fsb_dlg_reject": "拒绝",
    "fsb_dlg_processing": "处理中...",
    "fsb_dlg_approve": "批准",
    "fsb_wb_sec_connectors": "连接器",
    "fsb_wb_sec_skills": "技能",
    "fsb_wb_sec_workflows": "工作流",
    "fsb_wb_sec_variables": "变量",
    "fsb_wb_sec_templates": "模板",
    "fsb_wb_tab_approval": "待审批",
    "fsb_wb_tab_scheduled": "定时任务",
    "fsb_wb_tab_history": "执行历史",
    "fsb_wb_tab_sandbox": "上下文沙盒",
    "fsb_wb_workspace": "工作台",
    "fsb_wb_connected": "已连接",
    "fsb_wb_noConnector": "暂无连接器",
    "fsb_wb_available": "可用连接器",
    "fsb_wb_disconnect": "断开",
    "fsb_wb_connect": "连接",
    "fsb_wb_skillList": "技能列表",
    "fsb_wb_noSkill": "暂无技能",
    "fsb_wb_test": "测试",
    "fsb_wb_wfList": "工作流列表",
    "fsb_wb_noWorkflow": "暂无工作流",
    "fsb_wb_createWf": "创建工作流",
    "fsb_wb_run": "运行",
    "fsb_wb_schedule": "排期",
    "fsb_wb_variables": "变量",
    "fsb_wb_noVariable": "暂无变量",
    "fsb_wb_templates": "模板",
    "fsb_wb_newWf": "新建工作流",
    "fsb_wb_createFirstWf": "创建你的第一个工作流",
    "fsb_wb_nodeCountFmt": "%d 节点",
    "fsb_wb_taskCenter": "任务中心",
    "fsb_wb_noApproval": "无待审批任务",
    "fsb_wb_approvalReq": "审批请求",
    "fsb_wb_approve": "批准",
    "fsb_wb_deny": "拒绝",
    "fsb_wb_noScheduled": "无定时任务",
    "fsb_wb_noHistory": "暂无执行记录",
    "fsb_wb_inputData": "输入数据",
    "fsb_wb_sandboxVars": "沙盒变量",
    "fsb_wb_snapshots": "快照",
    "fsb_wb_sandboxEmpty": "上下文沙盒为空",
    "fsb_wb_sandboxHint": "运行工作流后，沙盒将记录\n执行上下文和数据快照",
    "rag_sec_dashboard": "知识库总览",
    "rag_sec_files": "文件目录管理",
    "rag_sec_chat": "RAG 对话",
    "rag_sec_embedConfig": "嵌入模型配置",
    "rag_sec_searchConfig": "检索策略配置",
    "rag_sec_permissions": "权限管控",
    "rag_sec_vectorOps": "向量库运维",
    "rag_sec_callLog": "RAG调用日志",
    "rag_sec_benchEval": "检索性能评测",
    "rag_currentKb": "当前知识库",
    "rag_all": "全部",
    "rag_tab_bases": "知识库",
    "rag_tab_chat": "对话",
    "rag_tab_search": "搜索",
    "rag_tab_config": "配置",
    "rag_log_title": "RAG 调用日志",
    "rag_log_total": "总调用",
    "rag_log_successRate": "成功率",
    "rag_log_avgLatency": "平均延迟",
    "rag_log_search": "搜索",
    "rag_log_ask": "问答",
    "rag_log_searchPh": "搜索日志...",
    "rag_log_opPicker": "操作",
    "rag_log_export": "导出 CSV",
    "rag_log_empty": "暂无调用日志",
    "rag_log_h_time": "时间",
    "rag_log_h_kb": "知识库",
    "rag_log_h_op": "操作",
    "rag_log_h_query": "查询",
    "rag_log_h_result": "结果",
    "rag_log_h_latency": "延迟",
    "rag_log_h_status": "状态",
    "rag_log_exportTitle": "导出 RAG 调用日志",
    "rag_log_exportDescFmt": "将筛选后的 %d 条日志导出为 CSV 文件",
    "rag_log_exportBtn": "导出",
    "rag_op_all": "全部",
    "rag_op_search": "搜索",
    "rag_op_ask": "问答",
    "rag_op_ingest": "导入",
    "rag_op_delete": "删除",
    "rag_op_watch": "监控",
    "rag_op_sync": "同步",
    "rag_perm_title": "权限管控",
    "rag_perm_authStatus": "鉴权状态",
    "rag_perm_apiKeyAuth": "API Key 认证",
    "rag_perm_disabled": "未启用",
    "rag_perm_enabled": "已启用",
    "rag_perm_activeKeys": "活跃密钥",
    "rag_perm_keyMgmt": "API 密钥管理",
    "rag_perm_createKey": "创建密钥",
    "rag_perm_noKey": "暂无 API 密钥",
    "rag_perm_noKeyHint": "未设置 API Key 时，鉴权功能不启用",
    "rag_perm_h_name": "名称",
    "rag_perm_h_hash": "密钥哈希",
    "rag_perm_h_createdAt": "创建时间",
    "rag_perm_memberRole": "成员角色",
    "rag_perm_role_admin": "管理员",
    "rag_perm_role_admin_desc": "全量读写、密钥管理、删除知识库",
    "rag_perm_role_edit": "编辑者",
    "rag_perm_role_edit_desc": "上传文档、修改配置、触发重建索引",
    "rag_perm_role_query": "查询者",
    "rag_perm_role_query_desc": "搜索、RAG 问答、只读访问",
    "rag_perm_role_api": "API 调用",
    "rag_perm_role_api_desc": "仅通过 API Key 调用搜索/问答接口",
    "rag_perm_audit": "审计日志",
    "rag_perm_auditNote": "上游 API 暂未提供审计日志接口，需要提 Issue 追踪",
    "rag_perm_createTitle": "创建 API 密钥",
    "rag_perm_keyNamePh": "密钥名称",
    "rag_perm_keyCreated": "密钥已创建（仅显示一次）",
    "rag_perm_createBtn": "创建",
    "rag_emb_title": "嵌入模型配置",
    "rag_emb_model": "嵌入模型",
    "rag_emb_modelName": "模型名称",
    "rag_emb_runMode": "运行方式",
    "rag_emb_localMlx": "本地 MLX 推理",
    "rag_emb_dim768": "768 维",
    "rag_emb_multilang": "多语言",
    "rag_emb_chunkStrategy": "分块策略",
    "rag_emb_strategyPicker": "策略",
    "rag_emb_chunkSize": "分块大小",
    "rag_emb_overlap": "重叠大小",
    "rag_emb_strategy_semantic": "语义分块",
    "rag_emb_strategy_fixed": "固定分块",
    "rag_emb_strategy_code": "代码分块",
    "rag_emb_strategy_sentence": "句子分块",
    "rag_emb_tip_semantic": "按语义边界分块，适合自然语言文档",
    "rag_emb_tip_fixed": "固定 token 数分块，适合均匀内容",
    "rag_emb_tip_code": "按 AST 函数/类边界分块，适合代码",
    "rag_emb_tip_sentence": "按句子边界分块，适合短文本",
    "rag_emb_context": "上下文增强",
    "rag_emb_contextToggle": "Contextual Retrieval（上下文检索增强）",
    "rag_emb_contextDesc": "为每个分块生成上下文摘要，显著提升检索准确率。Fusion-RAG 独有优势：本地 MLX 生成上下文，无需云端 API。",
    "rag_emb_saved": "✓ 配置已保存",
    "rag_emb_reset": "恢复默认",
    "rag_vec_title": "向量库运维",
    "rag_vec_syncAlertTitle": "确认增量同步",
    "rag_vec_syncAlertBtn": "同步",
    "rag_vec_syncAlertMsg": "将对知识库目录执行增量同步，检测文件变更并重新索引。确定继续？",
    "rag_vec_createSnapTitle": "创建版本快照",
    "rag_vec_snapDescPh": "快照描述（可选）",
    "rag_vec_create": "创建",
    "rag_vec_svcLabel": "服务状态",
    "rag_vec_embEngine": "嵌入引擎",
    "rag_vec_avail": "可用",
    "rag_vec_unavail": "不可用",
    "rag_vec_kbCount": "知识库数",
    "rag_vec_vecStatsLabel": "向量统计",
    "rag_vec_docCount": "文档数",
    "rag_vec_chunkCount": "分块数",
    "rag_vec_vecCount": "向量数",
    "rag_vec_fileCount": "文件数",
    "rag_vec_selectKbHint": "请先选择知识库",
    "rag_vec_opsLabel": "运维操作",
    "rag_vec_opSync": "增量同步",
    "rag_vec_opSyncDesc": "检测文件变更并重新索引",
    "rag_vec_opSnap": "创建快照",
    "rag_vec_opSnapDesc": "保存当前知识库状态到版本快照",
    "rag_vec_opHealth": "健康检查",
    "rag_vec_opHealthDesc": "检查向量存储和嵌入服务状态",
    "rag_vec_opRefresh": "刷新统计",
    "rag_vec_opRefreshDesc": "重新获取知识库统计信息",
    "rag_vec_snapLabel": "版本快照",
    "rag_vec_snapCountFmt": "%d 个快照",
    "rag_vec_snapEmpty": "暂无快照，点击「创建快照」保存当前知识库状态",
    "rag_vec_snapNote": "版本快照是 Fusion-RAG 相对 Claude RAG 的关键竞争力：支持时间点回滚、增量对比、数据恢复。",
    "rag_vec_snapFallback": "快照",
    "rag_vec_rollback": "回滚",
    "rag_vec_syncing": "同步中...",
    "rag_vec_syncDoneFmt": "✓ 同步完成: %d 文件已更新",
    "rag_vec_syncFail": "✗ 同步失败",
    "rag_vec_creatingSnap": "创建快照中...",
    "rag_vec_snapDoneFmt": "✓ 快照已创建: %@",
    "rag_vec_snapFail": "✗ 快照创建失败",
    "rag_vec_rollingBack": "回滚中...",
    "rag_vec_rollbackDoneFmt": "✓ 已回滚到快照 %@",
    "rag_vec_rollbackFail": "✗ 回滚失败",
    "rag_vec_svcHealthy": "✓ 服务健康",
    "rag_vec_svcUnhealthy": "✗ 服务异常",
    "rag_dash_kbTitle": "知识库",
    "rag_dash_newBtn": "新建",
    "rag_dash_svcHealthy": "Fusion-RAG 服务正常",
    "rag_dash_svcUnhealthy": "Fusion-RAG 服务不可用",
    "rag_dash_kbCountFmt": "%d 个知识库",
    "rag_dash_emptyTitle": "暂无知识库",
    "rag_dash_createKb": "创建知识库",
    "rag_dash_namePh": "名称",
    "rag_dash_descPh": "描述",
    "rag_dash_chunkStrategyPh": "分块策略",
    "rag_dash_embedModelPh": "嵌入模型",
    "rag_dash_create": "创建",
    "rag_dash_scanTitle": "扫描目录导入",
    "rag_dash_kbPrefix": "知识库: %@",
    "rag_dash_dirPathPh": "目录路径",
    "rag_dash_scanBtn": "开始扫描",
    "rag_dash_statFile": "文件",
    "rag_dash_statChunk": "分块",
    "rag_dash_statVec": "向量",
    "rag_dash_enterBtn": "进入",
    "rag_dash_importBtn": "导入",
    "rag_dash_chatMenu": "RAG 对话",
    "rag_dash_scanMenu": "扫描目录",
    "rag_file_searchPh": "搜索文件...",
    "rag_file_watchBtn": "监控",
    "rag_file_addFileBtn": "添加文件",
    "rag_file_selectKbHint": "请先选择知识库",
    "rag_file_emptyDoc": "暂无文档",
    "rag_file_h_name": "文件名",
    "rag_file_h_type": "类型",
    "rag_file_h_size": "大小",
    "rag_file_h_chunk": "分块",
    "rag_file_h_status": "状态",
    "rag_file_indexed": "已索引",
    "rag_file_watchLabel": "文件监控",
    "rag_file_watchEmpty": "无活跃监控",
    "rag_file_watchFileFmt": "监控 %d 个文件",
    "rag_file_changesFmt": "%d 次变更",
    "rag_file_lastReindexFmt": "上次重建: %@",
    "rag_file_stopBtn": "停止",
    "rag_file_addFileTitle": "添加文件",
    "rag_file_addFilePathPh": "文件路径（逗号分隔多个）",
    "rag_file_addBtn": "添加",
    "rag_file_watchTitle": "设置文件监控",
    "rag_file_watchPathPh": "文件路径（逗号分隔）",
    "rag_file_pollInterval": "轮询间隔(秒)",
    "rag_file_startWatchBtn": "开始监控",
    "rag_srch_title": "检索策略配置",
    "rag_srch_presetLabel": "场景预设",
    "rag_srch_preset_general": "通用",
    "rag_srch_preset_code": "代码",
    "rag_srch_preset_design": "设计",
    "rag_srch_presetDesc_general": "通用场景：均衡稀疏+稠密检索，适合文档问答",
    "rag_srch_presetDesc_code": "代码场景：提升稀疏权重（BM25 精确匹配函数名），开启查询分解",
    "rag_srch_presetDesc_design": "设计场景：提升稠密权重（语义理解设计描述），开启查询扩展",
    "rag_srch_weightLabel": "检索权重",
    "rag_srch_hybridToggle": "混合检索（BM25 + 向量 RRF）",
    "rag_srch_sparseLabel": "稀疏检索（BM25）",
    "rag_srch_denseLabel": "稠密检索（向量）",
    "rag_srch_alphaLabel": "混合 Alpha（RRF 权重）",
    "rag_srch_rerankToggle": "重排序（Rerank）",
    "rag_srch_rerankTip": "重排序使用 BGE-Reranker 对初步结果二次打分，显著提升 Top-5 准确率",
    "rag_srch_paramsLabel": "检索参数",
    "rag_srch_topKLabel": "Top-K 返回数",
    "rag_srch_thresholdLabel": "相似度阈值",
    "rag_srch_rewriteCard": "查询改写",
    "rag_srch_rewriteModePicker": "改写模式",
    "rag_srch_rewriteDesc_none": "不进行查询改写，直接使用原始查询",
    "rag_srch_rewriteDesc_expand": "查询扩展：生成同义表述增加召回率",
    "rag_srch_rewriteDesc_decompose": "查询分解：将复杂查询拆解为子问题分别检索",
    "rag_srch_rewriteDesc_hyde": "HyDE：先用 LLM 生成假设性答案，再用假设答案检索",
    "rag_srch_testLabel": "检索测试",
    "rag_srch_testQueryPh": "输入测试查询...",
    "rag_srch_testBtn": "测试",
    "rag_srch_rw_none": "无",
    "rag_srch_rw_expand": "扩展",
    "rag_srch_rw_decompose": "分解",
    "rag_srch_rw_hyde": "HyDE",
    "rag_bench_title": "检索性能评测",
    "rag_bench_adv_local": "本地离线向量",
    "rag_bench_adv_ast": "代码 AST 解析",
    "rag_bench_adv_rrf": "混合检索 RRF",
    "rag_bench_adv_context": "Contextual Retrieval",
    "rag_bench_adv_sync": "增量同步",
    "rag_bench_adv_snap": "版本快照",
    "rag_bench_presetLabel": "评测预设",
    "rag_bench_preset_standard": "标准评测",
    "rag_bench_preset_code": "代码检索",
    "rag_bench_preset_design": "设计检索",
    "rag_bench_customQueryLabel": "自定义评测集",
    "rag_bench_customEmpty": "点击 + 添加评测查询和期望文档",
    "rag_bench_addQueryTitle": "添加评测查询",
    "rag_bench_queryPh": "查询文本",
    "rag_bench_expectedPh": "期望包含的文档名",
    "rag_bench_addBtn": "添加",
    "rag_bench_runBtn": "运行评测",
    "rag_bench_hitRateFmt": "Top-5 命中率: %@",
    "rag_bench_clearResultsBtn": "清除结果",
    "rag_bench_resultsLabel": "评测结果",
    "rag_bench_resultsEmpty": "点击「运行评测」开始",
    "rag_bench_miniHit": "命中",
    "rag_bench_miniLatency": "平均延迟",
    "rag_bench_miniTopScore": "最高分",
    "rag_bench_historyLabel": "历史评测记录",
    "rag_bench_historyEmpty": "暂无历史评测记录",
    "fsb_cv_node_start": "开始",
    "fsb_cv_node_connector": "连接器",
    "fsb_cv_node_skill": "技能",
    "fsb_cv_node_condition": "条件",
    "fsb_cv_node_approval": "审批",
    "fsb_cv_node_output": "输出",
    "fsb_cv_node_end": "结束",
    "fsb_cv_wfName": "工作流名称",
    "fsb_cv_autoLayout": "自动布局",
    "fsb_cv_running": "运行中...",
    "fsb_cv_testRun": "测试运行",
    "fsb_cv_saving": "保存中...",
    "fsb_cv_nodeTypes": "节点类型",
    "fsb_cv_hintDrag": "提示：拖拽节点到画布",
    "fsb_cv_hintRightClick": "右键画布添加节点",
    "fsb_cv_hintConnect": "拖拽端口连接节点",
    "fsb_cv_nodeName": "节点名称",
    "fsb_cv_deleteNode": "删除节点",
    "fsb_cv_connector": "连接器",
    "fsb_cv_selectConnector": "选择连接器",
    "fsb_cv_notSelected": "未选择",
    "fsb_cv_action": "动作",
    "fsb_cv_skill": "技能",
    "fsb_cv_selectSkill": "选择技能",
    "fsb_cv_promptTpl": "提示词模板",
    "fsb_cv_conditionExpr": "条件表达式",
    "fsb_cv_conditionHint": "True 分支连向下方节点，False 分支连向右侧节点",
    "fsb_cv_approvalConfig": "审批配置",
    "fsb_cv_approvalMode": "审批模式",
    "fsb_cv_writeOnly": "仅写操作 (推荐)",
    "fsb_cv_allOps": "全部操作",
    "fsb_cv_approvalNote": "审批说明",
    "fsb_cv_timeoutFmt": "超时: %ds",
    "fsb_cv_outputFormat": "输出格式",
    "fsb_cv_format": "格式",
    "fsb_cv_plainText": "纯文本",
    "fsb_cv_addNode": "添加节点",
    "fsb_cv_newWorkflow": "新工作流",
    "mn_kv_title": "KV 缓存",
    "mn_kv_subtitle": "管理集群 KV 缓存、查看命中率和节点分布",
    "mn_kv_totalEntries": "总条目",
    "mn_kv_cacheEntries": "缓存条目数",
    "mn_kv_totalSize": "总大小",
    "mn_kv_cacheSpace": "缓存占用空间",
    "mn_kv_hitRate": "命中率",
    "mn_kv_hitRateSub": "KV 缓存命中",
    "mn_kv_findCache": "查找缓存",
    "mn_kv_searchPh": "输入模型名称查找 KV 缓存...",
    "mn_kv_findBtn": "查找",
    "mn_kv_notFoundFmt": "未找到该模型的 KV 缓存: %@",
    "mn_kv_hwTitle": "Agent 硬件",
    "mn_kv_node": "节点",
    "mn_kv_memory": "内存",
    "mn_kv_device": "设备",
    "mn_kv_agentOnline": "Agent 在线",
    "mn_kv_agentOffline": "Agent 离线",
    "mn_kv_checking": "检测中...",
    "mn_kv_warmTitle": "KV 预热",
    "mn_kv_modelName": "模型名称",
    "mn_kv_warmPrompt": "预热 Prompt",
    "mn_kv_warmBtn": "预热",
    "mn_kv_warmedFmt": "已预热 %d 条缓存",
    "mn_kv_transferTitle": "KV 迁移",
    "mn_kv_targetNode": "目标节点ID",
    "mn_kv_transferBtn": "迁移",
    "mn_kv_byModelTitle": "按模型分布",
    "mn_kv_countFmt": "%d 条",
    "mn_task_title": "任务监控",
    "mn_task_subtitle": "实时跟踪任务执行状态与进度",
    "mn_task_tab_all": "全部",
    "mn_task_tab_running": "运行中",
    "mn_task_tab_completed": "已完成",
    "mn_task_tab_failed": "失败",
    "mn_task_migrateTitle": "迁移任务",
    "mn_task_taskId": "任务ID",
    "mn_task_targetNode": "目标节点",
    "mn_task_selectNode": "请选择",
    "mn_task_confirmMigrate": "确认迁移",
    "mn_task_total": "总任务",
    "mn_task_allTasks": "全部任务",
    "mn_task_running": "运行中",
    "mn_task_executing": "正在执行",
    "mn_task_failed": "失败",
    "mn_task_needsAttention": "需要关注",
    "mn_task_listTitleFmt": "任务列表 (%d)",
    "mn_task_searchPh": "搜索任务...",
    "mn_task_cancelTask": "取消任务",
    "mn_task_degradeTask": "降级任务",
    "mn_task_migrateTask": "迁移任务",
    "mn_task_emptyFmt": "暂无%@任务",
    "mn_sync_title": "集群同步",
    "mn_sync_subtitle": "模型增量同步与集群分区状态",
    "mn_sync_partitionState": "分区状态",
    "mn_sync_partitionNodes": "分区节点",
    "mn_sync_isDegraded": "是否降级",
    "mn_sync_degraded": "降级中",
    "mn_sync_normal": "正常",
    "mn_sync_syncAvailable": "同步可用",
    "mn_sync_available": "可用",
    "mn_sync_unavailable": "不可用",
    "mn_sync_incrementalTitle": "增量同步",
    "mn_sync_modelName": "模型名称",
    "mn_sync_modelPh": "例: Qwen2.5-7B-Instruct",
    "mn_sync_sourceHost": "源节点 Host",
    "mn_sync_sourcePort": "源端口",
    "mn_sync_syncing": "同步中...",
    "mn_sync_triggerBtn": "触发同步",
    "mn_sync_manifestTitle": "模型 Manifest",
    "mn_sync_manifestPh": "输入模型名称查看 Manifest",
    "mn_sync_viewBtn": "查看",
    "mn_sync_upToDateFmt": "模型 %@ 已是最新",
    "mn_sync_syncDoneFmt": "同步完成: %d 个文件已更新",
    "mn_sync_syncFailFmt": "同步失败: %@",
    "mn_route_title": "路由策略",
    "mn_route_subtitle": "配置集群任务路由策略与负载均衡",
    "mn_route_currentTitle": "当前策略",
    "mn_route_strategy": "路由策略",
    "mn_route_applyBtn": "应用策略",
    "mn_route_loadTitle": "节点负载分布",
    "mn_route_avgLoad": "平均负载",
    "mn_route_updatedFmt": "策略已更新为 %@",
    "mn_route_desc_least_loaded": "优先分配给负载最低的节点",
    "mn_route_desc_round_robin": "轮流分配到各节点",
    "mn_route_desc_random": "随机选择节点",
    "mn_route_desc_capability_aware": "根据节点能力和任务需求匹配",
    "mn_alert_title": "告警中心",
    "mn_alert_subtitle": "集群异常检测与智能建议",
    "mn_alert_tab_active": "活跃告警",
    "mn_alert_tab_suggestions": "智能建议",
    "mn_alert_tab_history": "告警历史",
    "mn_alert_exportBtn": "导出日志",
    "mn_alert_activeTitleFmt": "活跃告警 (%d)",
    "mn_alert_activeEmpty": "无活跃告警，集群运行正常",
    "mn_alert_suggestTitleFmt": "智能建议 (%d)",
    "mn_alert_suggestEmpty": "暂无优化建议",
    "mn_alert_historyTitle": "告警历史",
    "mn_alert_historyEmpty": "暂无告警历史",
    "mn_alert_ackBtn": "确认",
    "mn_err_invalidURL": "无效 URL",
    "mn_err_noData": "无数据返回",
    "mn_overview_title": "集群总览",
    "mn_overview_subtitle": "实时监控集群节点状态与资源",
    "mn_overview_disconnectedFmt": "Multi-Node 服务未连接 — 请确认服务已启动 (port %d)",
    "mn_overview_metricNodes": "节点",
    "mn_overview_metricTotal": "总计",
    "mn_overview_metricOnline": "在线",
    "mn_overview_metricOnlineRun": "在线运行",
    "mn_overview_metricActiveTasks": "活跃任务",
    "mn_overview_metricExecuting": "正在执行",
    "mn_overview_metricClusterMem": "集群内存",
    "mn_overview_metricTotalMemFmt": "共 %@GB",
    "mn_overview_submitTaskBtn": "提交任务",
    "mn_overview_searchPh": "搜索节点...",
    "mn_overview_nodeListFmt": "节点列表 (%d)",
    "mn_overview_viewMetrics": "查看指标",
    "mn_overview_removeNode": "移除节点",
    "mn_overview_degradedFmt": "集群处于降级状态 — 分区: %@",
    "mn_overview_normalFmt": "集群同步正常 — 分区: %@",
    "mn_overview_detailLink": "详情",
    "mn_submit_title": "提交任务",
    "mn_submit_subtitle": "向集群提交新的推理或计算任务",
    "mn_submit_configTitle": "任务配置",
    "mn_submit_taskNameLabel": "任务名称",
    "mn_submit_taskNameSub": "用于标识任务的描述性名称",
    "mn_submit_taskNamePh": "例: llama-inference-batch",
    "mn_submit_execModeLabel": "执行模式",
    "mn_submit_execModeSub": "pipeline=流水线, data_parallel=数据并行, inference=单节点推理",
    "mn_submit_modelLabel": "模型名称",
    "mn_submit_modelSub": "目标推理模型",
    "mn_submit_modelPh": "例: mlx-community/Llama-3.2-1B",
    "mn_submit_priorityLabel": "优先级",
    "mn_submit_prioritySub": "1=最低, 10=最高",
    "mn_submit_capabilityLabel": "所需能力",
    "mn_submit_capabilitySub": "可选: 如 gpu, high_memory 等",
    "mn_submit_capabilityPh": "可选",
    "mn_submit_submitBtn": "提交",
    "mn_submit_successFmt": "任务已提交 (ID: %@)",
    "mn_node_title": "节点操作",
    "mn_node_subtitle": "弹性伸缩配置与节点管理",
    "mn_node_autoscalerTitle": "Autoscaler 弹性配置",
    "mn_node_mgmtTitle": "节点管理",
    "mn_node_removeBtn": "移除",
    "mn_node_emptyNodes": "暂无节点",
    "mn_node_minNodes": "最小节点",
    "mn_node_maxNodes": "最大节点",
    "mn_node_scaleUpThreshold": "扩容阈值",
    "mn_node_scaleDownThreshold": "缩容阈值",
    "mn_node_cooldownLabel": "冷却时间 (s)",
    "mn_node_strategyLabel": "策略",
    "mn_node_applying": "应用中...",
    "mn_node_applyBtn": "应用配置",
    "mn_node_pendingTitle": "待审批节点",
    "mn_node_pendingEmpty": "暂无待审批节点",
    "mn_node_approveBtn": "通过",
    "mn_node_rejectBtn": "拒绝",
    "mn_progress_title": "任务详情",
    "mn_progress_subtitle": "查看任务进度、时间线和子任务状态",
    "mn_progress_selectTaskTitle": "选择任务",
    "mn_progress_taskPicker": "任务",
    "mn_progress_inspectorSelect": "从 Inspector 选择",
    "mn_progress_loadDetailsBtn": "加载详情",
    "mn_progress_execProgressTitle": "执行进度",
    "mn_progress_remainingFmt": "剩余 %@",
    "mn_progress_timelineTitle": "时间线",
    "mn_progress_subTasksFmt": "子任务 (%d)",
    "mn_progress_emptyHint": "请从任务监控面板选择任务，或在上方下拉选择",
    "mn_progress_loadFailFmt": "进度加载失败: %@",
    "mn_web_title": "服务面板",
    "mn_web_subtitle": "通过 WebView 嵌入外部服务界面",
    "mn_web_tab_docs": "Master API",
    "mn_web_tab_bench": "Benchmark",
    "mn_web_tab_security": "Security",
    "mn_web_docsDescFmt": "FastAPI 自动文档 — 需启动 fusion-multi-node Master 服务 (端口 %d)",
    "mn_web_benchDesc": "基准测试面板 — 需启动 fusion-bench bench-site (端口 3000, npm run dev)",
    "mn_web_securityDesc": "安全审计面板 — 需启动 fusion-security 前端 (端口 3000)",
    "mn_web_connectingFmt": "正在连接 %@...",
    "mn_web_loadFailFmt": "无法加载 %@",
    "mn_web_retryBtn": "重试",
    "mn_topo_title": "拓扑图",
    "mn_topo_subtitle": "可视化 Master-Worker 连接关系",
    "mn_topo_legendOnline": "在线",
    "mn_topo_legendBusy": "忙碌",
    "mn_topo_legendOffline": "离线",
    "mn_topo_legendFault": "故障",
    "mn_topo_statsFmt": "%d 节点 · 在线率 %d%%",
    "mn_node_statusA11yFmt": "节点%@",
    "mn_task_degradedFmt": "降级: %@→%@",
    "design_swiftUITitle": "SwiftUI 导出",
    "design_codegenTitle": "代码导出",
    "design_copy": "复制",
    "design_close": "关闭",
    "design_helpPageMgmt": "页面管理",
    "design_helpCopyCode": "复制代码 (⇧⌘C)",
    "design_helpExportCode": "导出代码 (⇧⌘E)",
    "design_helpClear": "清空对话",
    "design_welcomeDesc": "描述你想设计的界面，AI 将为你生成可交互的代码",
    "design_inputPh": "描述你想设计的界面...",
    "design_emptyTitle": "描述你想设计的界面",
    "design_emptyDesc": "AI 将为你生成可交互的 HTML 代码，右侧实时预览",
    "design_clearInput": "清空输入",
    "design_clearConv": "清空对话",
    "design_copyCurrentCode": "复制当前代码",
    "design_helpSave": "保存",
    "design_helpCopy": "复制代码",
    "design_helpHistory": "历史",
    "design_helpSwiftUI": "导出 SwiftUI",
    "design_helpStop": "停止",
    "design_helpSend": "发送",
    "design_roleUser": "你",
    "design_roleDesigner": "设计师",
    "design_parsedFmt": "已解析: %@",
    "design_noVersions": "暂无版本记录",
    "design_rollback": "回退",
    "design_errMLXNotRunning": "MLX 服务未运行，请先在 MLX 面板启动服务后再发送",
    "design_errNoModel": "未选择对话模型，请在顶部模型选择器选一个模型后再发送",
    "design_marqueeFmt": "已框选 %d 个节点",
    "design_previewFmt": "预览: %@",
    "design_previewHint": "AI 建议的更改，确认后写入画布",
    "design_reject": "拒绝",
    "design_accept": "确认",
    "design_pages": "页面",
    "design_newPage": "新建页面",
    "design_noPages": "暂无页面，生成设计后自动创建",
    "design_deletePage": "删除页面",
    "design_batchExport": "批量导出",
    "design_exporting": "正在导出...",
    "design_selectFormat": "选择导出格式",
    "design_skillUseFmt": "使用%@技能: %@",
    "design_stepConnecting": "连接中...",
    "design_stepGenerating": "推理中...",
    "design_stepStreaming": "生成中...",
    "design_stepRendering": "渲染画布...",
    "design_stepConnShort": "连接",
    "design_stepGenShort": "推理",
    "design_stepStreamShort": "生成",
    "design_stepRenderShort": "渲染",
    "design_grp_pages": "页面",
    "design_grp_components": "组件",
    "design_grp_skills": "AI 技能",
    "design_tpl_login": "登录页",
    "design_tpl_dashboard": "仪表盘",
    "design_tpl_landing": "落地页",
    "design_tpl_settings": "设置页",
    "design_tpl_chat": "聊天界面",
    "design_tpl_profile": "个人主页",
    "design_tpl_card": "卡片组件",
    "design_tpl_form": "表单",
    "design_tpl_table": "数据表格",
    "design_tpl_nav": "导航栏",
    "design_tpl_modal": "弹窗/对话框",
    "design_tpl_buttons": "按钮组",
    "design_tpl_textToUI": "文生 UI",
    "design_tpl_imageToUI": "图生 UI",
    "design_tpl_partialEdit": "局部编辑",
    "design_tpl_localEdit": "精准修改",
    "design_tpl_simPanel": "相似面板",
    "design_tpl_multiVariants": "多方案",
    "design_tpl_specDoc": "规范文档",
    "design_tpl_pageFlow": "页面流",
    "design_ds_compLibrary": "组件库",
    "design_ds_searchCompPh": "搜索组件...",
    "design_ds_catAll": "全部",
    "design_ds_template": "模板",
    "design_ds_sizeSM": "小",
    "design_ds_sizeMD": "中",
    "design_ds_sizeLG": "大",
    "design_ds_cat_button": "按钮",
    "design_ds_cat_card": "卡片",
    "design_ds_cat_input": "输入",
    "design_ds_cat_select": "选择",
    "design_ds_cat_modal": "弹窗",
    "design_ds_cat_nav": "导航",
    "design_ds_cat_table": "表格",
    "design_ds_cat_chart": "图表",
    "design_ds_cat_form": "表单",
    "design_ds_desc_button": "操作按钮组件，支持多种样式变体和尺寸",
    "design_ds_desc_card": "内容卡片组件，支持标准/描边/特色样式",
    "design_ds_desc_input": "文本输入组件，支持多种输入类型",
    "design_ds_desc_select": "下拉选择组件，支持单选/多选",
    "design_ds_desc_modal": "弹窗组件，支持信息/确认/表单模式",
    "design_ds_desc_nav": "导航组件，支持顶栏/侧边栏/标签页",
    "design_ds_desc_table": "数据表格组件，支持基础/可排序/分页",
    "design_ds_desc_chart": "图表组件，支持折线/柱状/饼图",
    "design_ds_desc_form": "表单组件，支持登录/注册/联系表单",
    "design_lint_title": "规范检查",
    "design_lint_ruleLock": "规则锁定",
    "design_lint_run": "运行 Lint",
    "design_lint_genDocFirst": "请先生成设计文档",
    "design_lint_noResult": "Lint 未返回结果",
    "design_lint_noViolation": "无违规",
    "design_lint_errCountFmt": "%d 错误",
    "design_lint_warnCountFmt": "%d 警告",
    "design_lint_infoCountFmt": "%d 提示",
    "design_lint_violationCountFmt": "%d 条违规",
    "design_lint_nodeFmt": "节点: %@",
    "design_lint_rule_contrastCheck": "对比度检查",
    "design_lint_rule_unlabeledInput": "无标签输入",
    "design_lint_rule_textEffects": "文字特效",
    "design_lint_rule_abnormalRotation": "异常旋转",
    "design_lint_rule_emptyEffects": "空特效",
    "design_lint_rule_tokenInconsistency": "Token 不一致",
    "design_lint_rule_unnamedNode": "未命名节点",
    "design_lint_rule_textOverflow": "文字溢出",
    "design_lint_rule_overlappingNodes": "节点重叠",
    "design_lint_rule_hardcodedSpacing": "硬编码间距",
    "design_lint_rule_hardcodedFontSize": "硬编码字号",
    "design_lint_rule_missingInteractionState": "缺少交互状态",
    "design_lint_rule_layoutInconsistency": "布局不一致",
    "design_lint_lockTitle": "设计规则锁定",
    "design_lint_done": "完成",
    "design_lint_lockHint": "锁定的规则在 Lint 时将被忽略，违规不会显示",
    "design_lint_lockedCountFmt": "%d 条规则已锁定",
    "design_lint_unlockAll": "全部解锁",
    "design_eco_tabSync": "代码同步",
    "design_eco_tabTpl": "模板库",
    "design_eco_syncToCode": "正向同步 → Fusion Code",
    "design_eco_compName": "组件名",
    "design_eco_syncing": "同步中...",
    "design_eco_syncCode": "同步代码",
    "design_eco_watchCode": "反向监听 ← Fusion Code",
    "design_eco_checking": "检查中...",
    "design_eco_checkChange": "检查变更",
    "design_eco_noMutation": "无待处理样式变更",
    "design_eco_applyCanvas": "应用到画布",
    "design_eco_saveAsTpl": "保存当前设计为模板",
    "design_eco_tplNamePh": "模板名称",
    "design_eco_tplTagsPh": "标签(逗号分隔)",
    "design_eco_tplCatPh": "分类",
    "design_eco_save": "保存",
    "design_eco_searchTpl": "检索模板",
    "design_eco_searchPh": "搜索名称/标签/分类",
    "design_eco_search": "搜索",
    "design_eco_noMatchTpl": "无匹配模板",
    "design_eco_load": "加载",
    "design_eco_syncDone": "代码同步完成",
    "design_eco_syncFailFmt": "同步失败: %@",
    "design_eco_appliedFmt": "已应用 %d 个样式变更",
    "design_eco_tplSavedFmt": "模板 '%@' 已保存",
    "design_eco_tplSaveFailFmt": "保存模板失败: %@",
    "design_eco_tplLoadedFmt": "已加载模板 '%@'",
    "design_theme_modeSystem": "跟随系统",
    "design_theme_modeLight": "浅色",
    "design_theme_modeDark": "深色",
    "design_theme_modeCustom": "自定义",
    "design_theme_title": "主题切换",
    "design_theme_modeLabel": "外观模式",
    "design_theme_customAccent": "自定义强调色",
    "design_theme_accentBlue": "蓝",
    "design_theme_accentRed": "红",
    "design_theme_accentGreen": "绿",
    "design_theme_accentOrange": "橙",
    "design_theme_accentPurple": "紫",
    "design_theme_accentPink": "粉",
    "design_theme_preview": "预览",
    "design_theme_previewLight": "浅色",
    "design_theme_previewDark": "深色",
    "design_theme_reset": "重置为默认",
    "design_wf_recipe_designToCode": "Design → Code",
    "design_wf_recipe_codeToDesign": "Code → Design",
    "design_wf_recipe_screenshot": "Screenshot → Design → Code",
    "design_wf_recipe_designToCodeDesc": "在 Design 模块创建设计，导出为代码文件",
    "design_wf_recipe_codeToDesignDesc": "导入现有代码到 Design 模块进行可视化编辑",
    "design_wf_recipe_screenshotDesc": "截取屏幕截图，AI 生成设计，导出为代码",
    "design_wf_step_createDesign": "创建设计",
    "design_wf_step_previewDesign": "预览设计",
    "design_wf_step_exportToCode": "导出为代码",
    "design_wf_step_openInEditor": "在编辑器中打开",
    "design_wf_step_selectCodeFile": "选择代码文件",
    "design_wf_step_importToDesign": "导入到设计",
    "design_wf_step_editDesign": "编辑设计",
    "design_wf_step_syncBack": "同步回文件",
    "design_wf_step_captureScreenshot": "截取屏幕截图",
    "design_wf_step_analyzeScreenshot": "分析截图",
    "design_wf_step_generateDesign": "生成设计",
    "design_wf_startFmt": "开始工作流: %@",
    "design_wf_cancelled": "工作流已取消",
    "design_wf_doneFmt": "✅ 工作流完成: %@",
    "design_wf_execFmt": "执行: %@",
    "design_wf_ssSaved": "截图已保存到剪贴板，请粘贴到 Design 聊天中",
    "design_wf_canvasCleared": "画布已清空，请在聊天中描述您的设计",
    "design_wf_previewing": "正在预览设计...",
    "design_wf_editHint": "请在聊天中描述修改需求",
    "design_wf_generating": "AI 正在生成设计...",
    "design_wf_analyzing": "正在分析截图并生成设计...",
    "design_wf_noScreenshot": "剪贴板无截图，请先截图 (⌘⇧4)",
    "design_wf_selectCodeFile": "选择代码文件",
    "design_wf_selectedFmt": "已选择: %@",
    "design_wf_notSelected": "未选择文件",
    "design_wf_importedFmt": "已导入: %@",
    "design_wf_importedDoc": "已导入文档",
    "design_wf_noFileSelected": "无已选文件，请先选择代码文件",
    "design_wf_panelTitle": "设计工作流",
    "design_wf_cancelBtn": "取消工作流",
    "design_ins_sec_layout": "布局",
    "design_ins_sec_spacing": "间距",
    "design_ins_sec_typography": "排版",
    "design_ins_sec_colors": "颜色",
    "design_ins_sec_borders": "边框",
    "design_ins_sec_effects": "效果",
    "design_ins_alignStart": "起始",
    "design_ins_alignCenter": "居中",
    "design_ins_alignEnd": "末尾",
    "design_ins_justifyBetween": "两端对齐",
    "design_ins_justifyAround": "均匀分布",
    "design_ins_alignStretch": "拉伸",
    "design_ins_preset_card": "卡片",
    "design_ins_preset_button": "按钮",
    "design_ins_preset_inputField": "输入框",
    "design_ins_preset_navBar": "导航栏",
    "design_ins_preset_heroSection": "Hero 区域",
    "design_ins_title": "样式检查器",
    "design_ins_presetLabel": "样式预设",
    "design_ins_layoutMode": "布局模式",
    "design_ins_direction": "方向",
    "design_ins_mainAxis": "主轴",
    "design_ins_crossAxis": "交叉轴",
    "design_ins_width": "宽度",
    "design_ins_height": "高度",
    "design_ins_padding": "内边距 (Padding)",
    "design_ins_margin": "外边距 (Margin)",
    "design_ins_gap": "间距 (Gap)",
    "design_ins_fontFamily": "字体",
    "design_ins_fontSize": "字号",
    "design_ins_fontWeight": "字重",
    "design_ins_lineHeight": "行高",
    "design_ins_textAlign": "对齐",
    "design_ins_textColor": "文字颜色",
    "design_ins_bgColor": "背景颜色",
    "design_ins_borderColor": "边框颜色",
    "design_ins_borderWidth": "边框宽度",
    "design_ins_borderRadius": "圆角",
    "design_ins_opacity": "透明度",
    "design_ins_shadow": "阴影",
    "design_ins_overflow": "溢出",
    "design_ins_cssOutput": "CSS 输出",
    "design_tok_preset_appleHIG": "Apple HIG",
    "design_tok_preset_adminMinimal": "极简后台",
    "design_tok_preset_robotSim": "机器人仿真",
    "design_tok_cat_colors": "颜色",
    "design_tok_cat_spacing": "间距",
    "design_tok_cat_typography": "排版",
    "design_tok_cat_radius": "圆角",
    "design_tok_cat_shadows": "阴影",
    "design_tok_cat_animation": "动画",
    "design_tok_designSpec": "设计规范",
    "design_cv_menu_duplicate": "复制节点",
    "design_cv_menu_delete": "删除节点",
    "design_cv_menu_toggleLock": "锁定/解锁",
    "design_cv_menu_toggleVisibility": "隐藏/显示",
    "design_cv_menu_partialRepaint": "局部重绘",
    "design_cv_menu_bringToFront": "置顶",
    "design_cv_menu_sendToBack": "置底",
    "design_cv_menu_selectAll": "全选",
    "design_cv_menu_fitZoom": "缩放适配",
    "design_cv_menu_paste": "粘贴",
    "design_cg_targetLabel": "导出目标",
    "design_cg_componentName": "组件名",
    "design_cg_generating": "生成中...",
    "design_cg_generate": "生成代码",
    "design_cg_copied": "已复制",
    "design_cg_copy": "复制",
    "design_cg_emptyHint": "选择导出目标\n点击生成代码",
    "design_cg_charCount": "字符",
    "design_cg_genFailFmt": "代码生成失败: %@",
    "design_cg_desc_html": "纯 HTML + CSS 导出",
    "design_cg_desc_react": "React 组件 + Tailwind CSS",
    "design_cg_desc_tailwind": "纯 Tailwind CSS 类名",
    "design_cg_desc_swiftui": "SwiftUI View 代码",
    "design_ds_title": "设计系统",
    "design_ds_refresh": "刷新",
    "design_ds_activeFmt": "当前激活: %@",
    "design_ds_applyToCanvas": "应用到画布",
    "design_ds_activateFailFmt": "激活失败: %@",
    "design_ds_listFailFmt": "获取设计系统列表失败: %@",
    "design_ds_name_appleHIG": "Apple HIG",
    "design_ds_name_adminMinimal": "极简后台",
    "design_ds_name_robotSim": "机器人仿真",
    "design_ds_desc_appleHIG": "Apple Human Interface Guidelines",
    "design_ds_desc_adminMinimal": "极简风格后台管理",
    "design_ds_desc_robotSim": "工业仿真控制面板",
    "design_ds_customDesc": "自定义设计系统",
    "design_ly_title": "图层",
    "design_ly_countFmt": "%d 个元素",
    "design_ly_empty": "暂无图层",
    "design_ly_emptyHint": "使用 AI 对话生成设计后\n图层将在此处显示",
    "design_avd_exportReview": "导出审查",
    "design_ae_multiFormat": "多格式导出",
    "design_ae_cancel": "取消",
    "design_ae_exportFmt": "导出 %d 格式",
    "design_cl_conflictFmt": "文件与设计存在近时修改，已采用文件版本: %@",
    "design_si_selectScreenshot": "选择截图文件",
    "art_pc_open": "打开",
    "art_pc_copy": "复制",
    "art_pc_versionHistory": "版本历史",
    "art_pc_share": "分享",
    "art_pc_unpin": "取消置顶",
    "art_pc_pin": "置顶",
    "art_pc_duplicate": "复制为副本",
    "art_pc_moveToKb": "移至项目KB",
    "art_pc_delete": "删除",
    "art_pc_copySuffix": " (副本)",
    "art_sd_title": "分享 Artifact",
    "art_sd_permission": "权限",
    "art_sd_permView": "仅查看",
    "art_sd_permComment": "可评论",
    "art_sd_permEdit": "可编辑",
    "art_sd_expiry": "有效期",
    "art_sd_exp1h": "1 小时",
    "art_sd_exp1d": "1 天",
    "art_sd_exp7d": "7 天",
    "art_sd_exp30d": "30 天",
    "art_sd_expNever": "永不过期",
    "art_sd_generate": "生成分享链接",
    "art_sd_done": "完成",
    "art_sd_shareLink": "分享链接",
    "art_sd_existingShares": "已有分享 (%d)",
    "art_sd_expires": "过期: %@",
    "art_sd_revoke": "撤销",
    "art_tf_tags": "标签",
    "art_tf_addTag": "添加标签",
    "art_tf_folders": "文件夹",
    "art_tf_noFolders": "无可用文件夹",
    "art_vh_rollbackConfirm": "确认回滚？",
    "art_vh_rollback": "回滚",
    "art_vh_cancel": "取消",
    "art_vh_rollbackMsg": "将回滚到版本 v%d，当前版本将保存为命名快照",
    "art_vh_createSnapshot": "创建快照",
    "art_vh_snapshotName": "快照名称",
    "art_vh_create": "创建",
    "art_vh_title": "版本历史",
    "art_vh_empty": "暂无版本记录",
    "art_vh_current": "当前",
    "art_vh_chars": "%d 字符",
    "art_vh_diffCurrent": "对比当前版本",
    "art_vh_incremental": "增量变更",
    "art_vh_noDiff": "无差异",
    "art_vh_diffFail": "对比加载失败: %@",
    "art_rv_sortUpdated": "最近更新",
    "art_rv_sortCreated": "创建时间",
    "art_rv_sortName": "名称",
    "art_rv_scopeAll": "全部",
    "art_rv_scopeMine": "我的",
    "art_rv_scopeStarred": "星标",
    "art_rv_scopePinned": "置顶",
    "art_rv_subtitle": "全局产物仓库 — 跨会话管理所有 Artifacts",
    "art_rv_newFolder": "新建文件夹",
    "art_rv_folderName": "文件夹名称",
    "art_rv_create": "创建",
    "art_rv_search": "搜索产物…",
    "art_rv_typeAll": "全部",
    "art_rv_recycle": "回收站",
    "art_rv_folders": "文件夹",
    "art_rv_allArtifacts": "全部产物",
    "art_rv_rename": "重命名",
    "art_rv_delete": "删除",
    "art_rv_retry": "重试",
    "art_rv_empty": "暂无产物",
    "art_rv_open": "打开",
    "art_rv_unstar": "取消星标",
    "art_rv_star": "星标",
    "art_rv_copyContent": "复制内容",
    "art_rv_download": "下载",
    "art_rv_copy": "复制",
    "art_rv_moveToKb": "移至项目KB",
    "art_rv_loadFail": "加载失败: %@",
    "art_rb_title": "回收站",
    "art_rb_purge": "清空过期",
    "art_rb_empty": "回收站为空",
    "art_rb_restore": "恢复",
    "art_cv_rename": "重命名",
    "art_cv_newName": "新名称",
    "art_cv_confirm": "确认",
    "art_cv_cancel": "取消",
    "art_cv_deleteConfirm": "确认删除？",
    "art_cv_delete": "删除",
    "art_cv_deleteMsg": "此操作将移入回收站，可恢复",
    "art_cv_unsaved": "有未保存的更改",
    "art_cv_discard": "放弃",
    "art_cv_save": "保存",
    "art_cv_noPreview": "无预览内容",
    "art_cv_chars": "%d 字符",
    "art_cv_discardChanges": "放弃更改",
    "art_cv_createSnapshot": "创建版本快照",
    "art_cv_snapshotLabel": "快照标签（可选）",
    "art_cv_create": "创建",
    "art_cv_sections": "%d 章节",
    "art_cv_toc": "章节目录",
    "desk_tab_templates": "模板",
    "desk_tab_workflows": "工作流",
    "desk_tab_agents": "智能体",
    "desk_tab_sessions": "会话",
    "desk_tab_permissions": "权限",
    "desk_tab_mlx": "MLX",
    "desk_tab_system": "系统",
    "desk_tab_events": "事件",
    "desk_close": "关闭",
    "desk_loading": "加载中...",
    "desk_name": "名称",
    "desk_category": "分类",
    "desk_description": "描述",
    "desk_create": "创建",
    "desk_cancel": "取消",
    "desk_save": "保存",
    "desk_edit": "编辑",
    "desk_delete": "删除",
    "desk_status": "状态",
    "desk_refresh": "刷新",
    "desk_svc_notConnected": "Fusion-CoWork 服务未连接",
    "desk_svc_notConnectedHint": "请启动 fusion-cowork 服务后重试（终端运行 ./start.sh start，或在 设置→上游服务 中启动）",
    "desk_reconnect": "重新连接",
    "desk_svc_notReady": "服务未就绪",
    "desk_searchTemplates": "搜索模板...",
    "desk_tpl_count": "%d 个模板",
    "desk_noTemplates": "暂无模板",
    "desk_tpl_detail": "模板详情",
    "desk_steps": "步骤",
    "desk_tpl_runResult": "模板 %@: %@",
    "desk_tpl_runFail": "模板 %@: 执行失败",
    "desk_wf_promptPlaceholder": "输入自然语言创建工作流...",
    "desk_wf_count": "%d 个工作流",
    "desk_wf_execStatus": "执行状态",
    "desk_noWorkflows": "暂无工作流，输入提示语创建",
    "desk_wf_execStatusTitle": "工作流执行状态",
    "desk_wf_noRunning": "当前无执行中的工作流",
    "desk_wf_currentNode": "当前节点: %@",
    "desk_agent_taskPlaceholder": "提交任务给智能体...",
    "desk_submit": "提交",
    "desk_agent_count": "%d 个智能体",
    "desk_noAgents": "暂无智能体",
    "desk_agent_id": "ID: %@",
    "desk_agent_taskSubmitted": "任务 %@ 已提交",
    "desk_agent_viewStatus": "查看状态",
    "desk_agent_status": "状态: %@",
    "desk_agent_progress": "进度: %@",
    "desk_session_new": "新建会话",
    "desk_session_count": "%d 个会话",
    "desk_noSessions": "暂无会话",
    "desk_session_steps": "步骤: %d",
    "desk_session_fork": "分叉",
    "desk_session_edit": "编辑会话",
    "desk_session_namePlaceholder": "会话名称",
    "desk_session_detail": "会话详情",
    "desk_session_stepCount": "步骤数",
    "desk_perm_rules": "权限规则",
    "desk_perm_checkTool": "检查工具",
    "desk_perm_check": "检查",
    "desk_perm_resetAll": "重置全部",
    "desk_perm_checkResult": "工具 %@: %@",
    "desk_perm_allowed": "允许",
    "desk_perm_denied": "拒绝",
    "desk_perm_noRules": "暂无权限规则",
    "desk_perm_scope": "范围: %@",
    "desk_perm_toggle": "切换",
    "desk_mlx_status": "Fusion-MLX 状态",
    "desk_mlx_running": "运行中",
    "desk_mlx_stopped": "已停止",
    "desk_mlx_noModels": "无可用模型",
    "desk_mlx_modelList": "模型列表",
    "desk_mlx_modelCount": "%d 个模型",
    "desk_mlx_runningTitle": "Fusion-MLX 运行中",
    "desk_mlx_stoppedTitle": "Fusion-MLX 未启动",
    "desk_mlx_manageHint": "请通过 UpstreamServiceManager 管理 MLX 生命周期",
    "desk_sys_info": "系统信息",
    "desk_sys_platform": "平台",
    "desk_sys_cpuCores": "CPU 核心数",
    "desk_sys_memoryTotal": "内存总量",
    "desk_sys_memoryUsed": "内存使用",
    "desk_sys_diskFree": "磁盘剩余",
    "desk_sys_nodeCategories": "节点分类",
    "desk_sys_nodeList": "节点列表",
    "desk_sys_loading": "系统信息加载中...",
    "desk_sys_nodeDetail": "节点详情",
    "desk_sys_inputs": "输入参数",
    "desk_sys_outputs": "输出",
    "desk_evt_stream": "事件流",
    "desk_evt_polling": "轮询中",
    "desk_evt_subscribed": "已订阅",
    "desk_evt_count": "%d 个事件",
    "desk_evt_stopPoll": "停止轮询",
    "desk_evt_startPoll": "开始轮询",
    "desk_noEvents": "暂无事件",
    "desk_evt_source": "来源: %@",
    "dy_tab_inventory": "库存",
    "dy_tab_produce": "造片",
    "dy_tab_publish": "发布",
    "dy_tab_plan": "计划",
    "dy_tab_comment": "评论",
    "dy_tab_evolve": "进化",
    "dy_tab_stats": "统计",
    "dy_queue_pending": "待发布",
    "dy_queue_published": "已发布",
    "dy_queue_failed": "失败",
    "dy_queue_refresh": "刷新数据",
    "dy_inv_pending_queue": "待发布队列",
    "dy_inv_pending_empty": "暂无待发布视频，去「造片」补充库存",
    "dy_inv_published_recent": "已发布（最近 20 条）",
    "dy_inv_published_empty": "暂无已发布视频",
    "dy_inv_failed_queue": "失败队列",
    "dy_inv_variant_label": "variant %@",
    "dy_prod_title": "一键造片",
    "dy_prod_desc": "调 agent-studio 跑 Graph C（script→img→tts→compose→enqueue），单轮造 1 条入待发布队列。",
    "dy_prod_topic_label": "选题（留空则自动 topic_gen）",
    "dy_prod_topic_ph": "如：如果你掉进黑洞会发生什么",
    "dy_prod_variant_label": "钩子变体",
    "dy_prod_hint_a": "%@：数字+反常：首句用一个极端数字搭配反常识结论",
    "dy_prod_hint_b": "%@：提问+代入：首句用第二人称提问把观众代入场景",
    "dy_prod_hint_c": "%@：悬念+冲突：首句抛出一个待解的悬念冲突",
    "dy_prod_start": "开始造片",
    "dy_pub_title": "库存发布",
    "dy_pub_desc": "调 agent-studio 跑 Graph D（dequeue→gate_stock→publish→archive），从待发布队列取 1 条发布。",
    "dy_pub_dryrun_toggle": "Dry-run（不真实发布，停在发布前）",
    "dy_pub_dryrun_btn": "Dry-run 发布",
    "dy_pub_real_btn": "真实发布",
    "dy_pub_real_warn": "⚠️ 真实发布会上传视频到抖音账号，请确认库存与登录态。",
    "dy_plan_title": "高峰时段发布计划",
    "dy_plan_desc": "注册 cron 计划，每天高峰窗口（12-13 / 19-21）自动跑 Graph D 从库存取片发布，无需人工点按钮。底层为 agent-studio cron 运行时（PR #140）。",
    "dy_plan_expr_label": "Cron 表达式（分 时 日 月 周）",
    "dy_plan_expr_default": "默认 `5 12,19 * * *` = 每天 12:05 与 19:05 各触发一次（高峰窗口开场后 5 分钟）。",
    "dy_plan_dryrun_toggle": "Dry-run（不真实发布，验证计划触发）",
    "dy_plan_real_warn": "⚠️ 真实计划会在高峰时段自动上传视频到抖音，请确认库存与登录态。",
    "dy_plan_register": "注册发布计划",
    "dy_plan_refresh": "刷新",
    "dy_plan_empty": "暂无发布计划，注册后将在此显示下次触发时间与执行历史",
    "dy_plan_registered": "已注册计划",
    "dy_plan_history": "执行历史",
    "dy_cron_next": "下次: %@",
    "dy_cron_last": "上次: %@",
    "dy_cron_params": "参数: %@",
    "dy_cron_cancel": "取消计划",
    "dy_comment_title": "评论回复",
    "dy_comment_desc": "调 agent-studio 跑 Graph B（fetch→gate→draft→reply），抓取新评论并批量回复，幂等。",
    "dy_comment_start": "开始评论回复",
    "dy_comment_replied_title": "已回复评论 ID",
    "dy_evolve_title": "进化分析",
    "dy_evolve_desc": "调 agent-studio 跑 Graph E（snapshot→rank→analyze→repair_scan），更新爆款模式与差片扫描。",
    "dy_evolve_run": "运行进化闭环",
    "dy_evolve_repair_title": "差片修复重发",
    "dy_evolve_repair_desc": "调 agent-studio 跑 Graph F（scan→gate→retitle），对差片换标题重入队列。",
    "dy_evolve_repair_scan": "扫描并修复",
    "dy_win_title": "爆款模式（winning_patterns）",
    "dy_win_summary": "样本 %d · 爆款 %d · 更新于 %@",
    "dy_win_title_formula": "标题公式",
    "dy_win_hot_topic": "✅ 爆款选题",
    "dy_win_hot_hook": "✅ 爆款钩子",
    "dy_win_lose": "❌ 失败模式",
    "dy_stats_title": "统计报表 · 全貌",
    "dy_stats_desc": "账号整体表现概览：汇总指标 + 表现分布 + 钩子变体对比。",
    "dy_stats_empty": "暂无统计快照，先运行「进化分析」抓取 snapshot",
    "dy_stats_detail_title": "逐视频细节（按播放降序，优秀在前）",
    "dy_stats_total_plays": "总播放",
    "dy_stats_total_likes": "总点赞",
    "dy_stats_total_comments": "总评论",
    "dy_stats_total_shares": "总分享",
    "dy_stats_count": "作品数",
    "dy_stats_avg_plays": "均播放",
    "dy_stats_avg_ir": "均互动率",
    "dy_stats_hot_count": "爆款数",
    "dy_stats_dist_hot": "爆款 %d",
    "dy_stats_dist_mid": "平稳 %d",
    "dy_stats_dist_cold": "差片 %d",
    "dy_stats_variant_dist": "钩子变体样本分布",
    "dy_stats_variant_count": "%@：%d 条",
    "dy_stats_row_plays": "播放 %d",
    "dy_stats_row_likes": "赞 %d",
    "dy_stats_row_comments": "评 %d",
    "dy_stats_row_shares": "转 %d",
    "dy_stats_row_ir": "互动率 %.2f%%",
    "dy_action_running": "执行中…",
    "dy_action_produce": "造片",
    "dy_action_publish": "发布",
    "dy_action_comment_reply": "评论回复",
    "dy_action_evolve": "进化分析",
    "dy_action_repair": "差片修复",
    "dy_err_ops_not_found": "未找到 %@，请确认 fusion-operation 已运行并产出 out/ 数据",
    "dy_err_ipc_disconnected": "IPC 未连接，无法调用 agent-studio",
    "dy_err_ipc_register": "IPC 未连接，无法注册发布计划",
    "dy_res_done": "执行完成，共 %d 个事件",
    "dy_res_status": "执行状态: %@",
    "dy_res_plan_registered": "发布计划已注册，等待高峰时段自动触发",
    "dy_res_register_failed": "注册失败",
    "dy_err_rungraph": "runGraph %@ 失败: %@",
    "dy_err_graph_missing": "Graph 文件不存在: %@",
    "dy_err_graph_parse": "Graph JSON 解析失败: %@",
    "dy_err_graph_no_id": "graph.create 未返回 graph_id",
    "dy_err_register": "注册发布计划失败: %@",
    "dy_err_unregister": "取消计划失败: %@",
    "dy_cron_name": "抖音高峰发布计划",
    "fc_mode_ask": "询问",
    "fc_mode_auto": "自动",
    "fc_mode_plan": "计划",
    "fc_layout_four_column": "四栏",
    "fc_layout_three_column": "三栏",
    "fc_layout_two_column": "双栏",
    "fc_layout_chat_only": "纯对话",
    "fc_pane_editor": "编辑器",
    "fc_pane_diff": "差异",
    "fc_pane_preview": "预览",
    "fc_pane_terminal": "终端",
    "fc_pane_snapshot": "快照",
    "fc_pane_workflow": "工作流",
    "fc_pane_sandbox": "沙箱",
    "fc_cmd_help": "显示可用命令",
    "fc_cmd_clear": "清空对话",
    "fc_cmd_compact": "压缩对话上下文",
    "fc_cmd_model": "切换模型",
    "fc_cmd_kb": "查询知识库",
    "fc_cmd_memory": "管理项目记忆",
    "fc_cmd_template": "应用工作流模板",
    "fc_cmd_init": "初始化项目上下文",
    "fc_cmd_review": "审查当前改动",
    "fc_cmd_test": "生成并运行测试",
    "fc_cmd_deploy": "部署项目",
    "fc_cmd_explain": "解释代码",
    "fc_cmd_refactor": "重构代码",
    "fc_cmd_debug": "调试问题",
    "fc_no_project_title": "打开项目文件夹",
    "fc_open_folder": "打开文件夹",
    "fc_offline_mlx": "fusion-code 离线 — 使用 MLX 推理",
    "fc_thinking": "思考中...",
    "fc_connected": "已连接",
    "fc_offline": "离线",
    "fc_hide_session_bar": "隐藏会话栏",
    "fc_show_session_bar": "显示会话栏",
    "fc_greeting_morning": "早上好",
    "fc_greeting_afternoon": "下午好",
    "fc_greeting_evening": "晚上好",
    "fc_greeting_night": "夜深了",
    "fc_welcome_subtitle": "Fusion Code — 本地 AI 编程助手",
    "fc_card_open_title": "打开项目",
    "fc_card_open_sub": "从本地文件夹开始",
    "fc_card_code_title": "代码",
    "fc_card_code_sub": "生成与编辑代码",
    "fc_card_debug_title": "调试",
    "fc_card_debug_sub": "查找并修复问题",
    "fc_card_kb_title": "知识库查询",
    "fc_card_kb_sub": "向你的代码库提问",
    "fc_card_memory_title": "记忆",
    "fc_card_memory_sub": "管理上下文",
    "fc_card_template_title": "模板",
    "fc_card_template_sub": "工作流模板",
    "fc_card_review_title": "审查",
    "fc_card_review_sub": "代码审查",
    "fc_card_test_title": "测试",
    "fc_card_test_sub": "生成测试",
    "fc_prompt_write": "写一个 ",
    "fc_prompt_debug": "帮我调试这个问题",
    "fc_add_folder": "添加文件夹",
    "fc_add_file": "添加文件",
    "fc_query_kb": "查询知识库",
    "fc_templates": "模板",
    "fc_web_search": "网页搜索",
    "fc_input_placeholder": "随便问 — / 召唤命令...",
    "fc_select_file_edit": "选择文件进行编辑",
    "fc_select_session_snapshot": "选择会话查看快照",
    "fc_undo": "撤销",
    "fc_save": "保存",
    "fc_project_context": "项目上下文",
    "fc_ctx_project": "项目",
    "fc_ctx_branch": "分支",
    "fc_ctx_files": "文件",
    "fc_ctx_model": "模型",
    "fc_ctx_mode": "模式",
    "fc_ctx_kb": "知识库",
    "fc_not_selected": "未选择",
    "fc_no_project_open": "未打开项目",
    "fc_project_memory": "项目记忆",
    "fc_load_memory": "加载记忆文件",
    "fc_write_memory": "写入记忆",
    "fc_sessions": "会话",
    "fc_no_sessions": "无会话",
    "fc_messages_count": "%d 条消息",
    "fc_workflow_templates": "工作流模板",
    "fc_tpl_review": "代码审查",
    "fc_tpl_test": "生成测试",
    "fc_tpl_debug": "调试问题",
    "fc_tpl_refactor": "重构",
    "fc_tpl_explain": "解释代码",
    "fc_tpl_deploy": "部署",
    "fc_msg_model_switched": "已切换模型: %@",
    "fc_msg_current_model": "当前模型: %@",
    "fc_msg_context_compacted": "上下文已压缩",
    "fc_msg_unknown_cmd": "未知命令: %@。输入 /help 查看可用命令。",
    "fc_msg_kb_usage": "用法: /kb <查询>",
    "fc_msg_no_project_open": "未打开项目。请先打开文件夹。",
    "fc_msg_kb_no_results": "未找到结果: %@",
    "fc_msg_kb_results": "知识库结果:\n\n%@",
    "fc_msg_kb_failed": "知识库查询失败: %@",
    "fc_msg_no_project": "未打开项目。",
    "fc_msg_no_memory": "未找到记忆文件。",
    "fc_msg_memory_files": "记忆文件:\n%@",
    "fc_msg_memory_failed": "记忆加载失败: %@",
    "fc_kb_building": "知识库: 构建中...",
    "fc_kb_build_failed": "知识库: 构建失败",
    "fc_tool_edit": "编辑文件: %@",
    "fc_tool_write": "写入文件: %@",
    "fc_tool_run": "运行: %@",
    "fc_tool_multi_edit": "编辑多个文件",
    "fc_denied_by_user": "已被用户拒绝",
    "fc_approve": "批准",
    "fc_deny": "拒绝",
    "fc_apply_code": "应用代码",
    "fc_apply_code_n": "应用代码 #%d",
    "fc_status_pending": "待定",
    "fc_status_running": "运行中",
    "fc_status_approved": "已批准",
    "fc_status_denied": "已拒绝",
    "fc_status_completed": "完成",
    "fc_status_failed": "失败",
    "fc_code": "代码",
    "fc_copied": "已复制",
    "fc_copy": "复制",
    "fc_no_matching_commands": "无匹配命令",
    "fc_new_session": "新建会话",
    "fc_title": "标题",
    "fc_session_title_ph": "会话标题",
    "fc_cancel": "取消",
    "fc_create": "创建",
    "fc_permission_request": "权限请求",
    "fc_tool_label": "工具:",
    "fc_open_project_folder": "打开项目文件夹",
    "fc_open_file": "打开文件",
    "fc_scanning": "扫描 %@...",
    "fc_loaded_files": "已加载 %d 个文件",
    "fc_loading": "加载 %@...",
    "fc_loaded_one_file": "已加载 1 个文件",
    "fc_load_failed": "加载失败: %@",
    "fc_scanning_n": "扫描 %d/%d...",
    "fc_ai_unavailable": "AI 服务暂时不可用，请稍后重试。",
    "fc_sidebar_chat": "聊天",
    "fc_sidebar_files": "文件",
    "fc_sidebar_git": "Git",
    "fc_sidebar_design": "设计",
    "fc_toggle_sidebar": "切换侧边栏",
    "fc_input_ask_anything": "随便问 — code, explain, debug, refactor...",
    "fc_attach_file": "附加文件",
    "fc_menu_add_folder": "添加文件夹...",
    "fc_menu_add_file": "添加文件...",
    "fc_menu_add_github": "添加 GitHub 仓库...",
    "fc_git_url_detected": "检测到 Git 仓库 URL",
    "fc_send": "发送",
    "fc_open_project": "打开项目",
    "fc_local_folder": "本地文件夹",
    "fc_local_folder_desc": "选择本地文件夹，自动扫描代码文件",
    "fc_choose": "选择...",
    "fc_single_file": "单个文件",
    "fc_single_file_desc": "打开单个文件进行编辑和 AI 辅助",
    "fc_github_repo": "GitHub 仓库",
    "fc_github_repo_desc": "克隆远程仓库到本地工作区",
    "fc_url": "URL",
    "fc_branch": "分支",
    "fc_clone_open": "克隆并打开",
    "fc_or": "或",
    "fc_drop_here": "拖拽文件或文件夹到此处",
    "fc_search_conversations": "搜索对话...",
    "fc_no_conversations": "暂无对话",
    "fc_files_count": "%d 个文件",
    "fc_close_project": "关闭项目",
    "fc_open_another": "打开其他项目",
    "fc_search_files": "搜索文件...",
    "fc_open_folder_browse": "打开文件夹以浏览文件",
    "fc_show_in_finder": "在 Finder 中显示",
    "fc_copy_path": "复制路径",
    "fc_remove_context": "移除上下文",
    "fc_add_to_context": "添加到上下文",
    "fc_add_to_kb": "添加到知识库",
    "fc_index_to_rag": "索引到 RAG",
    "fc_add_dir_to_kb": "添加目录到知识库",
    "fc_not_git_repo": "非 git 仓库",
    "fc_open_for_git": "打开项目以查看 Git 状态",
    "fc_no_changes": "无改动",
    "fc_welcome_title": "Fusion Code — AI 编程助手",
    "fc_welcome_tagline": "兼容 Claude Code · 由 fusion-mlx 驱动",
    "fc_wc_open_title": "打开项目",
    "fc_wc_open_desc": "加载本地/Git代码",
    "fc_wc_explain_title": "解释",
    "fc_wc_explain_desc": "解释代码功能",
    "fc_wc_review_title": "审查",
    "fc_wc_review_desc": "查找代码缺陷",
    "fc_wc_test_title": "测试",
    "fc_wc_test_desc": "生成单元测试",
    "fc_recent": "最近打开",
    "fc_min_ago": "%d 分钟前",
    "fc_hour_ago": "%d 小时前",
    "fc_day_ago": "%d 天前",
    "fc_term_banner": "Fusion Studio 终端 v1.0",
    "fc_term_help_hint": "输入 'help' 查看可用命令",
    "fc_terminal": "终端",
    "fc_clear": "清空",
    "fc_term_commands": "命令: help, clear, status, mlx, python, swift",
    "fc_term_unknown": "未知: %@。输入 'help'",
    "fc_you": "你",
    "fc_clone": "克隆",
    "fc_group_mode": "分组方式",
    "fc_search_sessions": "搜索会话...",
    "fc_no_project2": "无项目",
    "fc_rename": "重命名",
    "fc_pause": "暂停",
    "fc_resume": "恢复",
    "fc_delete": "删除",
    "fc_layout_mode": "布局模式",
    "fc_sessions_count": "%d 个会话",
    "fc_new_session_full": "新建编码会话",
    "fc_working_dir": "工作目录",
    "fc_model_label": "模型",
    "fc_security_mode": "安全模式",
    "fc_sm_readonly": "只读",
    "fc_sm_manual": "手动审批",
    "fc_sm_auto": "自动",
    "fc_gm_by_project": "按项目",
    "fc_gm_by_state": "按状态",
    "fc_gm_flat": "平铺",
    "fc_state_idle": "空闲",
    "fc_state_running": "运行中",
    "fc_state_waiting": "等待审批",
    "fc_state_paused": "已暂停",
    "fc_state_completed": "已完成",
    "fc_state_failed": "异常",
    "fc_state_cluster": "集群运行中",
    "fc_sm_auto_full": "自动批准",
    "fc_policy": "策略",
    "fc_audit": "审计",
    "fc_allow_dirs": "允许目录",
    "fc_add_dir_ph": "添加目录...",
    "fc_add": "Add",
    "fc_ignore_patterns": "忽略模式 (.fusionignore)",
    "fc_add_pattern_ph": "添加模式...",
    "fc_no_audit": "暂无审计记录",
    "fc_records_count": "%d 条记录",
    "fc_export": "导出",
    "fc_wf_empty_desc": "创建工作流自动化执行复杂任务",
    "fc_wf_new": "新建工作流",
    "fc_wf_goal_ph": "目标描述",
    "fc_wf_select_template": "选择模板",
    "fc_wf_template_generic": "通用任务分解",
    "fc_wf_template_legacy": "遗留系统迁移",
    "fc_wf_template_security": "安全扫描审计",
    "fc_wf_template_batch": "批量API处理",
    "fc_wf_template_refactor": "代码重构",
    "fc_wf_template_test": "测试生成",
    "fc_wf_status_failed": "%d 失败",
    "fc_wf_status_running": "运行中 (%d/%d)",
    "fc_wf_status_completed": "已完成",
    "fc_wf_status_pending": "排队中 (%d/%d)",
    "fc_preview": "预览",
    "fc_live": "实时",
    "fc_html_preview_empty": "生成HTML后此处显示预览",
    "fc_original": "原始",
    "fc_modified": "已修改",
    "fc_design_open_in_module": "在 Design 模块中打开",
    "fc_design_no_content": "没有设计内容",
    "fc_design_create_hint": "在 Design 模块中创建设计后\n可在此预览",
    "fc_design_sync_on": "双向同步已开启",
    "fc_design_sync_off": "同步未连接",
    "fc_design_export_file": "导出到文件",
    "fc_tier_global": "全局",
    "fc_tier_project": "项目",
    "fc_tier_directory": "目录",
    "fc_diff_split": "分屏",
    "fc_diff_unified": "合并",
    "fc_diff_line_numbers": "行号",
    "fc_snapshots": "快照",
    "fc_no_snapshots": "暂无快照",
    "fc_create_snapshot": "创建快照",
    "fc_label_optional": "标签（可选）",
    "fc_restore": "恢复",
    "fc_rewind_here": "回退到此处",
    "fc_snap_deltas_fmt": "%d 个增量 · %@",
    "fc_snap_not_found": "未找到快照：%@",
    "fc_pty_stopped": "已停止",
    "fc_pty_clear": "清空",
    "fc_pty_stop": "停止",
    "fc_pty_restart": "重启",
    "fc_pty_shell_started": "Shell 已启动：%@",
    "fc_pty_shell_exited": "Shell 已退出。",
    "fc_pty_start_fail": "启动 Shell 失败：%@",
    "fc_pty_alloc_fail": "分配 PTY 失败：%@",
    "fc_copy_suffix": " (副本)",
    "fc_untitled": "未命名"
]

let enUSTranslations: [String: String] = [
    "ok": "OK", "cancel": "Cancel", "save": "Save", "delete": "Delete", "edit": "Edit",
    "close": "Close", "search": "Search", "refresh": "Refresh", "loading": "Loading...", "filter": "Filter", "clear": "Clear", "retry": "Retry", "add": "Add",
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
    "secPlugin": "Plugin Ecosystem", "secTrainer": "Trainer",

    "newProject": "New Project", "openLocalFolder": "Open Local Folder",
    "newWorkspace": "New Workspace", "newWorkbench": "New Workbench",
    "noConversationsYet": "No conversations yet", "noArtifactsYet": "No artifacts yet",
    "openArtifacts": "Open Artifacts",
    "runDashboard": "Operations Dashboard", "pendingPublish": "Pending", "published": "Published",
    "hitProduct": "Hits", "douyinHint": "Click \"Operations Dashboard\" to create / publish / comment / evolve",

    "mod_dashboard": "Dashboard", "mod_design": "Design", "mod_code": "Code", "mod_simulation": "Simulation", "mod_modelHub": "Models", "mod_multimodal": "Multimodal", "mod_training": "Training", "mod_cli": "CLI", "mod_doc": "Documents", "mod_bench": "Benchmark", "mod_desk": "Automation", "mod_dataTools": "Data Tools", "mod_agent": "Agents", "mod_plugin": "Plugins", "mod_security": "Security", "mod_analytics": "Analytics", "mod_collab": "Collaboration", "mod_tuning": "Tuning", "mod_external": "Integrations", "mod_docgen": "Doc Generation", "mod_clusterOverview": "Cluster Overview", "mod_clusterTopology": "Topology", "mod_clusterSync": "Cluster Sync", "mod_taskMonitor": "Task Monitor", "mod_alertCenter": "Alert Center", "mod_nodeActions": "Node Mgmt", "mod_submitTask": "Submit Task", "mod_taskProgress": "Task Detail", "mod_routingStrategy": "Routing", "mod_kvCache": "KV Cache", "mod_serviceWeb": "Service Panel", "mod_rag": "RAG", "mod_memory": "Memory", "mod_planner": "Planner", "mod_deploy": "Deploy", "mod_operations": "Operations", "mod_eduK12": "K-12 Education", "mod_verification": "Verification", "mod_tokenBudget": "Token Budget", "mod_safety": "Safety Approval", "mod_tools": "Tools", "mod_agentDashboard": "Agent Monitor", "mod_teamCollab": "Team Collab", "mod_chat": "Chat", "mod_fusionProjects": "Projects", "mod_cowork": "CoWork", "mod_artifactsRepo": "Artifacts", "mod_fsb": "FSB", "mod_aiAgentDashboard": "AI Overview", "mod_aiAgentList": "Agent List", "mod_aiAgentChat": "AI Chat", "mod_aiAgentObserver": "AI Observer", "mod_aiAgentKnowledgeBase": "AI Knowledge Base", "mod_science": "Science", "mod_finance": "Finance", "mod_health": "Health", "mod_pluginConfig": "Plugin Config", "mod_pluginStatus": "Plugin Status", "mod_pluginToken": "Token", "mod_pluginVram": "VRAM", "mod_pluginLog": "Plugin Log", "mod_pluginMcp": "MCP", "mod_trainer": "Trainer",

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
    "proj_panelTitle": "Projects",
    "proj_panelSort": "Sort:",
    "proj_panelNew": "New",
    "proj_emptyTitle": "Looking to start a project?",
    "proj_emptyHint": "Upload materials, set custom instructions, and organize conversations in one space.",
    "proj_panelNewProject": "New Project",
    "proj_tokensFmt": "%d tokens",
    "proj_panelKbEmpty": "No knowledge files yet",
    "proj_panelAutoScan": "Auto Scan",
    "proj_panelCustomInst": "Custom Instructions",
    "proj_panelChatHistory": "Chat History",
    "proj_panelNewChat": "New Chat",
    "proj_sessionsFmt": "%d sessions",
    "proj_panelChatEmpty": "No chat sessions yet",
    "proj_panelStartConv": "Start a Conversation",
    "proj_msgsFmt": "%d msgs",
    "proj_panelSelect": "Select a project",
    "proj_panelOpenFolder": "Open Project Folder",
    "proj_panelOpen": "Open",
    "proj_panelAddKbFiles": "Add Knowledge Files",
    "proj_panelDefaultModel": "Default Model",
    "proj_panelModelPh": "e.g. qwen3-9b",
    "proj_panelDefault": "Default",
    "proj_panelTempFmt": "Temperature: %@",
    "proj_panelMaxTokensFmt": "Max Tokens: %d",
    "proj_panelAutoLoadClaude": "Auto-load CLAUDE.md",
    "proj_panelAutoScanKb": "Auto-scan knowledge files",
    "proj_tabSessions": "Sessions",
    "proj_tabSettings": "Settings",
    "cw_snap_title": "Session Snapshots",
    "cw_snap_create": "Create Snapshot",
    "cw_snap_empty": "No snapshots",
    "cw_list_subtitle": "Collaboration space — team chat, shared agents, workflow coordination",
    "cw_list_searchPh": "Search spaces...",
    "cw_list_newHelp": "New collaboration space",
    "cw_list_marketHelp": "Workflow / template marketplace",
    "cw_filter_all": "All",
    "cw_filter_created": "Created by me",
    "cw_filter_joined": "Joined by me",
    "cw_filter_archived": "Archived",
    "cw_list_onboardingTitle": "Start your first collaboration space",
    "cw_list_onboardingBody": "CoWork lets teams chat in real time, share agents, and coordinate workflows. Supports offline spaces, deep research, desktop sharing and more.",
    "cw_list_createLabel": "Create collaboration space",
    "cw_list_archivedTag": "Archived",
    "cw_list_emptyTitle": "Select a collaboration space",
    "cw_list_emptyHint": "Or create a new space to start collaborating",
    "cw_list_loadFail": "Load failed: %@",
    "cw_create_title": "New collaboration space",
    "cw_create_basic": "Basic info",
    "cw_create_namePh": "Space name",
    "cw_create_descPh": "Description (optional)",
    "cw_create_mode": "Collaboration mode",
    "cw_create_modeLocal": "Local",
    "cw_create_modeP2p": "LAN",
    "cw_create_modeGateway": "Remote",
    "cw_create_modeLocalDesc": "Single-machine offline collaboration",
    "cw_create_modeP2pDesc": "Bonjour LAN discovery",
    "cw_create_modeGatewayDesc": "Via Fusion Gateway",
    "cw_create_kb": "Knowledge base binding",
    "cw_create_kbPh": "KB path (optional, e.g. project dir)",
    "cw_create_ability": "Space capabilities",
    "cw_create_webSearch": "Web search",
    "cw_create_deepResearch": "Deep research",
    "cw_create_computerUse": "Desktop control",
    "cw_create_memberUpload": "Member uploads",
    "cw_create_memberAgent": "Member-created agents",
    "cw_create_memberWorkflow": "Member-run workflows",
    "cw_create_advanced": "Advanced settings",
    "cw_create_maxMembers": "Max members",
    "cw_create_btn": "Create",
    "cw_main_loading": "Loading...",
    "cw_main_deepResearch": "Deep research",
    "cw_main_computerUse": "Desktop control",
    "cw_main_createSnap": "Create snapshot",
    "cw_main_archive": "Archive space",
    "cw_main_archivedBanner": "This space is archived — read-only",
    "cw_side_members": "Members",
    "cw_side_files": "Files",
    "cw_side_knowledge": "Knowledge base",
    "cw_side_agents": "Agent",
    "cw_side_artifacts": "Artifacts",
    "cw_side_workflows": "Workflows",
    "cw_side_snapshots": "Snapshots",
    "cw_side_desktop": "Desktop",
    "cw_side_settings": "Settings",
    "cw_chat_emptyTitle": "Space chat",
    "cw_chat_emptyHint": "Send the first message, or @Agent to start collaborating",
    "cw_chat_thinking": "Thinking...",
    "cw_chat_copy": "Copy",
    "cw_chat_retry": "Retry",
    "cw_chat_attach": "Attachment",
    "cw_chat_screenshot": "Screenshot",
    "cw_chat_noAgent": "None (send directly)",
    "cw_chat_inputPh": "Type a message, @Agent to collaborate...",
    "cw_chat_relay": "Agent relay",
    "cw_chat_relayHint": "Select multiple agents to process the message in turn",
    "cw_chat_relayClear": "Clear",
    "cw_chat_relayDone": "Done",
    "cw_chat_streamErr": "Error: %@",
    "cw_chat_sendFail": "Send failed: %@",
    "cw_chat_relayFail": "Relay failed: %@",
    "cw_system_name": "System",
    "cw_comment_title": "Comments",
    "cw_comment_addPh": "Add a comment...",
    "cw_comment_send": "Send",
    "cw_member_title": "Members",
    "cw_member_lanDiscovery": "LAN discovery",
    "cw_member_scanning": "Scanning...",
    "cw_member_scan": "Scan",
    "cw_member_inviteTitle": "Invite member",
    "cw_member_inviteRole": "Role",
    "cw_member_inviteMaxUses": "Max uses: %d",
    "cw_member_inviteExpires": "Expires (hours): %d",
    "cw_member_inviteGen": "Generate invite link",
    "cw_member_inviteCode": "Invite code: %@",
    "cw_member_remove": "Remove",
    "cw_role_owner": "Owner",
    "cw_role_admin": "Admin",
    "cw_role_member": "Member",
    "cw_role_viewer": "Viewer",
    "cw_files_title": "Files",
    "cw_files_empty": "No files",
    "cw_agent_title": "Agent",
    "cw_agent_empty": "No shared agents",
    "cw_agent_add": "Add agent",
    "cw_agent_edit": "Edit",
    "cw_agent_copyToProject": "Copy to project",
    "cw_agent_remove": "Remove",
    "cw_agent_addTitle": "Add agent",
    "cw_agent_editTitle": "Edit agent",
    "cw_agent_name": "Name",
    "cw_agent_namePh": "Agent name",
    "cw_agent_model": "Model",
    "cw_agent_modelPh": "Model (leave empty for default)",
    "cw_agent_perm": "Permission",
    "cw_agent_permAll": "Available to all members",
    "cw_agent_permAdmin": "Admin only",
    "cw_agent_permCustom": "Custom members",
    "cw_agent_permAllLabel": "All members",
    "cw_agent_permCustomLabel": "Custom",
    "cw_snap2_title": "Snapshots",
    "cw_snap2_empty": "No snapshots",
    "cw_snap2_createTitle": "Create snapshot",
    "cw_snap2_namePh": "Name",
    "cw_snap2_forkTitle": "Fork snapshot",
    "cw_snap2_forkSpacePh": "New space name",
    "cw_snap2_restore": "Restore this snapshot",
    "cw_snap2_forkNew": "Fork to new space",
    "cw_snap2_msgCount": "%d messages",
    "cw_snap2_dagName": "DAG: %@",
    "cw_art_title": "Artifacts",
    "cw_art_kindAll": "All",
    "cw_art_kindCode": "Code",
    "cw_art_kindDoc": "Doc",
    "cw_art_kindViz": "Visualization",
    "cw_art_kindData": "Data",
    "cw_art_createTitle": "Create artifact",
    "cw_art_kindPicker": "Type",
    "cw_wf_title": "Workflows",
    "cw_wf_empty": "No workflows",
    "cw_wf_create": "Create workflow",
    "cw_wf_createTitle": "Create workflow",
    "cw_wf_namePh": "Workflow name",
    "cw_wf_descPh": "Description (optional)",
    "cw_wf_nodeCount": "%d nodes",
    "cw_wf_status_running": "Running",
    "cw_wf_status_completed": "Completed",
    "cw_wf_status_failed": "Failed",
    "cw_wf_status_idle": "Idle",
    "cw_snap_emptyHint": "Create a snapshot to save the current session state. Roll back or fork anytime.",
    "cw_snap_labelPh": "Label (optional)",
    "cw_snap_createBtn": "Create",
    "cw_snap_forkAlert": "Fork this snapshot into a new session?",
    "cw_snap_forkBtn": "Fork",
    "cw_snap_msgFmt": "%d messages",
    "cw_snap_restoreHelp": "Restore to this snapshot",
    "cw_snap_forkHelp": "Fork into a new session",
    "cw_snap_deleteHelp": "Delete snapshot",
    "cw_snap_forkAlertBtn": "Fork",
    "cw_desk_title": "Desktop",
    "cw_desk_role": "Role",
    "cw_desk_roleObserver": "Observer",
    "cw_desk_roleController": "Controller",
    "cw_desk_roleApprover": "Approver",
    "cw_desk_notSharing": "Desktop sharing off",
    "cw_desk_controlReq": "Control requests",
    "cw_desk_approve": "Approve",
    "cw_desk_reject": "Reject",
    "cw_desk_auditLog": "Audit log",
    "cw_desk_sharing": "Sharing",
    "cw_set_title": "Settings",
    "cw_set_streamResp": "Stream response",
    "cw_research_running": "In progress...",
    "cw_research_queryPh": "Enter research question...",
    "cw_research_depth": "Depth",
    "cw_research_depthShallow": "Shallow",
    "cw_research_depthMedium": "Medium",
    "cw_research_depthDeep": "Deep",
    "cw_research_start": "Start research",
    "cw_research_multiAgent": "Multi-agent parallel",
    "cw_research_autoSelect": "Auto select",
    "cw_research_agentCountFmt": "%d Agents",
    "cw_research_zeroToken": "Zero token cost · local inference",
    "cw_research_runningProgress": "Deep research in progress...",
    "cw_research_desc": "Deep research uses multi-agent parallel reasoning to automate complex investigations",
    "cw_research_vsClaude": "Compared to Claude CoWork: zero token cost · local model inference · optional multi-agent parallel",
    "cw_research_track": "Research path",
    "cw_research_agentProgress": "Agent research progress",
    "cw_research_noResult": "Research complete, no result text",
    "cw_research_failFmt": "Research failed: %@",
    "cw_research_done": "Done",
    "cw_research_runningStatus": "Researching...",
    "cw_preview_empty": "No preview content",
    "cw_notif_title": "Notifications",
    "cw_notif_markAll": "Mark all read",
    "cw_notif_empty": "No notifications",
    "cw_kb_title": "Knowledge base",
    "cw_kb_unbound": "Knowledge base not bound",
    "cw_kb_bindHint": "After binding, agent chat auto-retrieves related docs",
    "cw_kb_bind": "Bind knowledge base",
    "cw_kb_statsFmt": "%d docs, %d chunks",
    "cw_kb_searchPh": "Search knowledge base...",
    "cw_kb_results": "Search results",
    "cw_kb_ragAnswer": "RAG answer",
    "cw_kb_upload": "Upload document",
    "cw_kb_uploadTitle": "Upload document to knowledge base",
    "cw_kb_pathPh": "File path",
    "cw_kb_uploadBtn": "Upload",
    "cw_kb_docFmt": "Document %d",
    "cw_mkt_title": "Marketplace",
    "cw_mkt_type": "Type",
    "cw_mkt_typeWorkflow": "Workflow",
    "cw_mkt_typeArtifact": "Artifact template",
    "cw_mkt_install": "Install",
    "cw_home_mode_chat": "Chat",
    "cw_home_mode_cowork": "CoWork",
    "cw_home_pick_title": "Choose Authorized Folders",
    "cw_home_pick_prompt": "CoWork will only access folders you authorize",
    "cw_home_pick_confirm": "Authorize",
    "cw_home_no_scoped": "Select an authorized folder to start",
    "cw_home_svc_down": "fusion-cowork not running (Settings → Upstream Services)",
    "cw_home_submit_fail": "Submit failed: ",
    "cw_home_bubble_step": "Step",
    "cw_home_bubble_done": "Done",
    "cw_home_bubble_error": "Error",
    "cw_home_bubble_artifact": "Artifact",
    "ai_offline_badge": "Offline",
    "ai_offline_helpOff": "Offline mode — click for details",
    "ai_offline_helpOn": "Online mode",
    "ai_offline_netStatus": "Network status",
    "ai_offline_offMode": "Offline mode",
    "ai_offline_onMode": "Online mode",
    "ai_offline_reasonFmt": "Reason: %@",
    "ai_offline_disabledTitle": "Features unavailable offline:",
    "ai_offline_featInfer": "Model inference",
    "ai_offline_featKb": "Knowledge base query",
    "ai_offline_featCode": "Code generation",
    "ai_offline_manual": "Manually toggled",
    "ai_audit_title": "Audit log",
    "ai_audit_toolPh": "Tool name",
    "ai_audit_typePh": "Operation type",
    "ai_audit_sincePh": "Since",
    "ai_audit_sinceHint": "e.g. 2025-01-01",
    "ai_audit_apply": "Apply",
    "ai_audit_freq": "Tool call frequency",
    "ai_audit_empty": "No audit logs",
    "ai_monitor_title": "Model load monitor",
    "ai_monitor_refreshFmt": "Refresh every %ds",
    "ai_monitor_manualRefresh": "Manual refresh",
    "ai_monitor_connected": "MLX connected",
    "ai_monitor_disconnected": "MLX not connected",
    "ai_monitor_startMlx": "Start MLX",
    "ai_monitor_availModels": "Available models",
    "ai_monitor_noModels": "No models",
    "ai_monitor_loaded": "Loaded",
    "ai_monitor_load": "Load",
    "ai_monitor_loadingStatus": "Loading model status...",
    "ai_monitor_errFmt": "Failed to get model status: %@",
    "ai_perm_title": "Permission tags",
    "ai_perm_capsTitle": "Capability permissions",
    "ai_perm_empty": "No permission data",
    "ai_perm_agentFmt": "Agent %@",
    "ai_perm_deniedTitle": "FUSION.rules denied tools",
    "ai_perm_toolPh": "Tool name",
    "ai_perm_sensitiveTitle": "Sensitive file patterns",
    "ai_perm_sensitiveTag": "Sensitive",
    "ai_perm_capRead": "Read knowledge base",
    "ai_perm_capWrite": "Write knowledge base",
    "ai_perm_capDelete": "Delete knowledge base",
    "ai_perm_capCode": "Execute code",
    "ai_perm_capNet": "Access network",
    "ai_review_title": "Diff Review",
    "ai_review_export": "Export review.md",
    "ai_review_sevCritical": "Critical",
    "ai_review_sevWarning": "Warning",
    "ai_review_sevInfo": "Info",
    "ai_review_empty": "No Diff data",
    "ai_review_exportTitle": "Export review.md",
    "ai_review_copy": "Copy to clipboard",
    "ai_dash_title": "Console Overview",
    "ai_dash_subtitle": "Agent management console — global dashboard and quick access",
    "ai_dash_statToday": "Today's requests",
    "ai_dash_statToken": "Token usage",
    "ai_dash_statActive": "Active agents",
    "ai_dash_statError": "Error requests",
    "ai_dash_quickTitle": "Quick access",
    "ai_dash_qaCreate": "Create new agent",
    "ai_dash_qaKb": "New knowledge base",
    "ai_dash_qaConnector": "Manage connectors",
    "ai_dash_qaApiDoc": "API docs",
    "ai_dash_recentTitle": "Recent agents",
    "ai_dash_recentViewAll": "View all",
    "ai_dash_empty": "No agents yet, click above to create",
    "ai_dash_alertTitle": "Alerts",
    "ai_dash_alertEmpty": "All clear, no alerts",
    "ai_dash_alertUnknown": "Unknown alert",
    "ai_list_create": "Create agent",
    "ai_list_searchPh": "Search agent name...",
    "ai_list_delTitle": "Confirm delete",
    "ai_list_delMsgFmt": "Are you sure you want to delete agent \"%@\"? This cannot be undone.",
    "ai_list_filterFmt": "Filter: %@",
    "ai_list_hName": "Agent name",
    "ai_list_hStatus": "Status",
    "ai_list_hModel": "Model",
    "ai_list_hKb": "Knowledge base",
    "ai_list_hUpdated": "Last updated",
    "ai_list_hAction": "Actions",
    "ai_list_empty": "No agents",
    "ai_list_emptyHint": "Click \"Create agent\" to start building",
    "ai_list_actDebug": "Debug",
    "ai_list_actEdit": "Edit",
    "ai_list_actClone": "Clone",
    "ai_list_actArchive": "Archive",
    "ai_list_actDelete": "Delete",
    "ai_list_scopeAll": "All",
    "ai_list_scopeDraft": "Draft",
    "ai_list_scopePublished": "Published",
    "ai_list_sortUpdated": "Last updated",
    "ai_list_sortCreated": "Created time",
    "ai_list_sortName": "Name",
    "ai_kb_title": "Knowledge base management",
    "ai_kb_searchPh": "Search projects...",
    "ai_kb_newBtn": "New project",
    "ai_kb_unnamed": "Untitled",
    "ai_kb_createdFmt": "Created on %@",
    "ai_kb_detail": "Details",
    "ai_kb_statusActive": "Active",
    "ai_kb_empty": "No knowledge base projects",
    "ai_kb_emptyHint": "Create a project, upload documents to provide knowledge for agents",
    "ai_kb_sheetTitle": "New knowledge base project",
    "ai_kb_sheetName": "Project name",
    "ai_kb_sheetNamePh": "Enter project name",
    "ai_kb_sheetDesc": "Project description",
    "ai_kb_sheetCreate": "Create",
    "ai_kb_detTitle": "Project details",
    "ai_kb_detTabFiles": "Files",
    "ai_kb_detTabInstruction": "Instructions",
    "ai_kb_detTabAgents": "Linked agents",
    "ai_kb_filesEmpty": "No files",
    "ai_kb_artRemove": "Remove",
    "ai_kb_instrTitle": "Project instructions",
    "ai_kb_instrSave": "Save instructions",
    "ai_kb_agentsTitle": "Agents linked to this knowledge base",
    "ai_kb_agentsEmpty": "No agents linked to this knowledge base",
    "ai_chat_welcomeTitle": "Start chatting with Agent",
    "ai_chat_welcomeHint": "Select an Agent and type a message to begin",
    "ai_chat_noAgent": "No agents available, please create one first",
    "ai_chat_streaming": "Generating...",
    "ai_chat_qaSummarize": "Summarize document",
    "ai_chat_qaCode": "Generate code",
    "ai_chat_qaData": "Data analysis",
    "ai_chat_qaTranslate": "Translate",
    "ai_chat_qaWrite": "Creative writing",
    "ai_chat_inputPh": "Type a message...",
    "ai_chat_toolbox": "Toolbox",
    "ai_chat_toolWebSearch": "Web search",
    "ai_chat_toolResearch": "Deep research",
    "ai_chat_toolCode": "Code execution",
    "ai_chat_toolKb": "Knowledge query",
    "ai_chat_pickTitle": "Select Agent",
    "ai_chat_pickEmpty": "No agents available",
    "ai_chat_noResponse": "(No response)",
    "ai_chat_rtTitle": "Runtime config",
    "ai_chat_rtMaxTokens": "Max tokens",
    "ai_chat_rtApply": "Apply to current session",
    "ai_chat_reqFailedFmt": "Request failed: %@",
    "ai_debug_title": "Debug panel",
    "ai_debug_agentFmt": "Agent %@",
    "ai_debug_executing": "Executing",
    "ai_debug_ready": "Ready",
    "ai_debug_chatEmpty": "Send a message to test Agent response",
    "ai_debug_chatEmptyHint": "Debug mode shows execution steps and tool calls in real time",
    "ai_debug_inputPh": "Type a test message...",
    "ai_debug_logsTitle": "Current session logs",
    "ai_debug_loadHistory": "Load history",
    "ai_debug_logsEmpty": "Execution logs empty",
    "ai_debug_logsEmptyHint": "Execution steps will appear here after sending a test message",
    "ai_debug_tasksEmpty": "No code tasks",
    "ai_debug_tasksEmptyHint": "Submit code for Agent to execute and view results",
    "ai_debug_lang": "Language",
    "ai_debug_submit": "Submit",
    "ai_debug_logReceiveFmt": "Received user message: %@",
    "ai_debug_noResponse": "(No response content)",
    "ai_debug_logExecDone": "Agent execution complete",
    "ai_debug_logToolFmt": "Tool call: %@",
    "ai_debug_logExecFallback": "Agent execution complete (fallback)",
    "ai_debug_logFailFmt": "Execution failed: %@",
    "ai_debug_tabChat": "Chat test",
    "ai_debug_tabLogs": "Execution logs",
    "ai_debug_tabTasks": "Code tasks",
    "ai_obs_tabUsage": "Usage",
    "ai_obs_tabLogs": "Execution Logs",
    "ai_obs_tabApikeys": "API Keys",
    "ai_obs_tabConnectors": "Connectors",
    "ai_obs_tabPermissions": "Permission Tags",
    "ai_obs_tabAudit": "Audit Logs",
    "ai_obs_title": "Monitoring & Management",
    "ai_obs_subtitle": "Usage · Logs · API Keys · Connectors",
    "ai_obs_statToday": "Today's Requests",
    "ai_obs_statToken": "Total Tokens",
    "ai_obs_statActive": "Active Agents",
    "ai_obs_statError": "Error Rate",
    "ai_obs_alerts": "Alerts",
    "ai_obs_logsEmpty": "No execution logs",
    "ai_obs_apikeysTitle": "API Key Management",
    "ai_obs_apikeyCreate": "Create Key",
    "ai_obs_apikeysEmpty": "No API keys",
    "ai_obs_createdFmt": "Created %@",
    "ai_obs_rotate": "Rotate",
    "ai_obs_revoke": "Revoke",
    "ai_obs_connTitle": "External Connectors",
    "ai_obs_connAdd": "Add Connector",
    "ai_obs_connEmpty": "No connectors configured",
    "ai_obs_connConnected": "Connected",
    "ai_obs_connDisconnected": "Disconnected",
    "ai_obs_connect": "Connect",
    "ai_obs_unnamedKey": "Unnamed Key",
    "ai_obs_unnamedConn": "Unnamed",
    "ai_cfg_tabBasic": "Basic Info",
    "ai_cfg_tabInstructions": "System Instructions",
    "ai_cfg_tabSoul": "Soul",
    "ai_cfg_tabKnowledge": "Knowledge Base",
    "ai_cfg_tabTools": "Tools",
    "ai_cfg_tabAdvanced": "Advanced",
    "ai_cfg_tabPublish": "Publish",
    "ai_cfg_skillAddTitle": "Add Skill",
    "ai_cfg_skillNamePh": "Skill name",
    "ai_cfg_skillDescPh": "Skill description (optional)",
    "ai_cfg_modeCreate": "Create New Agent",
    "ai_cfg_modeEditFmt": "Edit Agent: %@",
    "ai_cfg_subCreate": "Configure the agent's basic info, instructions, tools and params",
    "ai_cfg_subEdit": "Modify agent config then save or publish",
    "ai_cfg_nameLabel": "Agent Name",
    "ai_cfg_namePh": "Enter agent name",
    "ai_cfg_descLabel": "Description",
    "ai_cfg_descPh": "Describe the agent's function and purpose",
    "ai_cfg_modelLabel": "Model Selection",
    "ai_cfg_modelPicker": "Model",
    "ai_cfg_modelChoose": "Select model",
    "ai_cfg_visLabel": "Visibility",
    "ai_cfg_visPrivate": "Private",
    "ai_cfg_visOrg": "Organization",
    "ai_cfg_instrHint": "Write the agent's base role, behavior constraints, output specs",
    "ai_cfg_charFmt": "%d chars",
    "ai_cfg_instrSaveTpl": "Save Template",
    "ai_cfg_instrRestore": "Restore Version",
    "ai_cfg_soulHint": "Define the agent's personality, speaking style, emotion preferences",
    "ai_cfg_soulSave": "Save Soul",
    "ai_cfg_soulAfterCreate": "Edit Soul after creating the agent",
    "ai_cfg_kbLabel": "Bind Knowledge Base Project",
    "ai_cfg_kbAdd": "+ Add Knowledge Base",
    "ai_cfg_ragLabel": "Retrieval Strategy",
    "ai_cfg_ragVector": "Vector",
    "ai_cfg_ragFulltext": "Full-text",
    "ai_cfg_ragHybrid": "Hybrid",
    "ai_cfg_autoQueryLabel": "Auto Query",
    "ai_cfg_autoQueryToggle": "Allow agent to query knowledge base proactively",
    "ai_cfg_toolsBuiltin": "Built-in Tools",
    "ai_cfg_toolWebSearch": "Web Search",
    "ai_cfg_toolDeepResearch": "Deep Research",
    "ai_cfg_skillsLabel": "Skills",
    "ai_cfg_skillCountFmt": "%d skills added",
    "ai_cfg_skillsEmpty": "No skills yet. Click Add Skill to add capabilities",
    "ai_cfg_skillsAfterCreate": "Manage skills after creating the agent",
    "ai_cfg_connLabel": "External Connectors",
    "ai_cfg_connEmpty": "No authorized connectors",
    "ai_cfg_connUnknown": "Unknown",
    "ai_cfg_tempHint": "Low=precise, High=creative",
    "ai_cfg_maxTokenLabel": "Max Output Tokens",
    "ai_cfg_ctxLabel": "Context Window",
    "ai_cfg_styleLabel": "Output Style",
    "ai_cfg_stylePicker": "Style",
    "ai_cfg_styleDefault": "Default",
    "ai_cfg_qpsLabel": "QPS Rate Limit",
    "ai_cfg_qpsUnit": "req/s",
    "ai_cfg_pubLabel": "Publish Actions",
    "ai_cfg_pubBtn": "Publish Agent",
    "ai_cfg_pubGetApi": "Get API Endpoint",
    "ai_cfg_pubSaveFirst": "Save draft before publishing",
    "ai_cfg_summaryTitle": "Config Summary",
    "ai_cfg_sumName": "Name",
    "ai_cfg_sumModel": "Model",
    "ai_cfg_sumVis": "Visibility",
    "ai_cfg_sumKb": "Knowledge Base",
    "ai_cfg_sumKbUnbound": "Unbound",
    "ai_cfg_sumTools": "Tools",
    "ai_cfg_sumMaxToken": "Max Tokens",
    "ai_cfg_sumConnFmt": "%d connectors",
    "ai_cfg_sumToolsNone": "Disabled",
    "ai_cfg_deleteBtn": "Delete Agent",
    "ai_cfg_saveDraft": "Save Draft",
    "fsb_ws_renameAlertTitle": "Rename Workspace",
    "fsb_ws_name": "Name",
    "fsb_ws_exportTitle": "Export Workspace",
    "fsb_ws_copyClipboard": "Copy to Clipboard",
    "fsb_ws_emptyWorkspaces": "No workspaces",
    "fsb_ws_noMatch": "No matching workspaces",
    "fsb_ws_createWs": "Create Workspace",
    "fsb_ws_headerTitle": "FSB Workbench",
    "fsb_ws_newWs": "New Workspace",
    "fsb_ws_listView": "List View",
    "fsb_ws_gridView": "Grid View",
    "fsb_ws_searchPh": "Search workspaces...",
    "fsb_unnamed": "Unnamed",
    "fsb_ws_connWfFmt": "%d conn · %d wf",
    "fsb_ws_open": "Open",
    "fsb_ws_rename": "Rename",
    "fsb_ws_duplicate": "Duplicate",
    "fsb_ws_export": "Export",
    "fsb_ws_subtitle": "Cross-SaaS smart business workbench",
    "fsb_ws_serviceDown": "FSB service not running",
    "fsb_ws_usageGuide": "User Guide",
    "fsb_ws_namePh": "e.g. Customer Management System",
    "fsb_ws_descOpt": "Description (optional)",
    "fsb_ws_descPh": "Describe the workspace purpose",
    "fsb_ws_bindProjectOpt": "Bind project (optional)",
    "fsb_ws_projectIdPh": "Project ID",
    "fsb_ws_bindAgentOpt": "Bind agent (optional)",
    "fsb_ws_importTemplate": "Import from template",
    "fsb_ws_createBtn": "Create",
    "fsb_ws_builtinTemplates": "Built-in templates",
    "fsb_tpl_crm_name": "Customer Relationship Management",
    "fsb_tpl_crm_short": "CRM",
    "fsb_tpl_crm_desc": "Manage customers, follow-ups, sales pipeline",
    "fsb_tpl_inventory_name": "Inventory Management",
    "fsb_tpl_inventory_short": "Inventory",
    "fsb_tpl_inventory_desc": "Track stock, restock alerts, in/out records",
    "fsb_tpl_finance_name": "Finance & Bookkeeping",
    "fsb_tpl_finance_short": "Finance",
    "fsb_tpl_finance_desc": "Income/expense, invoices, financial reports",
    "fsb_tpl_email_name": "Email Marketing",
    "fsb_tpl_email_short": "Marketing",
    "fsb_tpl_email_desc": "Email templates, segments, scheduling, analytics",
    "fsb_tpl_social_name": "Social Media Management",
    "fsb_tpl_social_short": "Social",
    "fsb_tpl_social_desc": "Multi-platform publish, schedule, engagement, analytics",
    "fsb_tpl_ticket_name": "Ticket System",
    "fsb_tpl_ticket_short": "Tickets",
    "fsb_tpl_ticket_desc": "Tickets, assignment, SLA tracking, surveys",
    "fsb_ob_welcome_title": "Welcome to FSB",
    "fsb_ob_welcome_desc": "Fusion Small Business is a cross-SaaS smart business automation workbench.\nNo coding needed — connect your tools via visual workflows.",
    "fsb_ob_connectors_title": "Connectors",
    "fsb_ob_connectors_desc": "Connect your existing SaaS tools:\nGoogle Workspace, Shopify, QuickBooks, Stripe, etc.\nReads run automatically; writes need approval.",
    "fsb_ob_skills_title": "Skills",
    "fsb_ob_skills_desc": "15+ built-in skills:\nEmail summaries, data extraction, report generation, translation, etc.\nCustomize prompt skills and API-call skills.",
    "fsb_ob_workflow_title": "Workflows",
    "fsb_ob_workflow_desc": "Build workflows visually:\nDrag nodes to form a DAG, conditional branches, approval gates.\nSchedule, event, and external API triggers.",
    "fsb_ob_start_title": "Get Started",
    "fsb_ob_start_desc": "Create a workspace from a template or from scratch.\nAll data runs locally — private and secure.",
    "fsb_ob_prev": "Previous",
    "fsb_dlg_addConnector": "Add Connector",
    "fsb_dlg_connecting": "Connecting...",
    "fsb_dlg_connect": "Connect",
    "fsb_dlg_selectConnector": "Select connector",
    "fsb_dlg_connector": "Connector",
    "fsb_dlg_selectPh": "Select...",
    "fsb_dlg_supportFmt": "Supports: %@",
    "fsb_dlg_authMethod": "Auth method",
    "fsb_dlg_auth": "Auth",
    "fsb_dlg_noAuth": "No auth",
    "fsb_dlg_enterApiKey": "Enter API Key",
    "fsb_dlg_scopesHint": "Scopes (comma-separated)",
    "fsb_dlg_createSkill": "Create Skill",
    "fsb_dlg_saving": "Saving...",
    "fsb_dlg_create": "Create",
    "fsb_dlg_skillName": "Skill name",
    "fsb_dlg_displayName": "Display name",
    "fsb_dlg_mySkill": "My Skill",
    "fsb_dlg_type": "Type",
    "fsb_dlg_prompt": "Prompt",
    "fsb_dlg_function": "Function",
    "fsb_dlg_chain": "Chain",
    "fsb_dlg_definition": "Definition",
    "fsb_dlg_inputSchema": "Input Schema (JSON)",
    "fsb_dlg_outputFormat": "Output format",
    "fsb_dlg_plainText": "Plain text",
    "fsb_dlg_setSchedule": "Set schedule",
    "fsb_dlg_triggerMethod": "Trigger method",
    "fsb_dlg_manual": "Manual",
    "fsb_dlg_cron": "Scheduled (Cron)",
    "fsb_dlg_eventDriven": "Event-driven",
    "fsb_dlg_manualOnly": "Only triggered manually in workspace",
    "fsb_dlg_cronExpr": "Cron expression",
    "fsb_dlg_commonPresets": "Common presets",
    "fsb_dlg_preset_weekday9": "Weekdays 9AM",
    "fsb_dlg_preset_hourly": "Every hour",
    "fsb_dlg_preset_daily8": "Daily 8AM",
    "fsb_dlg_preset_monday9": "Every Monday 9AM",
    "fsb_dlg_preset_month1": "1st of month",
    "fsb_dlg_eventTrigger": "Event trigger",
    "fsb_dlg_eventPh": "e.g. data.updated, order.created",
    "fsb_dlg_eventHint": "Supported events: data change, new record, status update, etc.",
    "fsb_dlg_approvalRequest": "Approval request",
    "fsb_dlg_requestContent": "Request content",
    "fsb_dlg_editContent": "Edit content (optional)",
    "fsb_dlg_reject": "Reject",
    "fsb_dlg_processing": "Processing...",
    "fsb_dlg_approve": "Approve",
    "fsb_wb_sec_connectors": "Connectors",
    "fsb_wb_sec_skills": "Skills",
    "fsb_wb_sec_workflows": "Workflows",
    "fsb_wb_sec_variables": "Variables",
    "fsb_wb_sec_templates": "Templates",
    "fsb_wb_tab_approval": "Pending",
    "fsb_wb_tab_scheduled": "Scheduled",
    "fsb_wb_tab_history": "History",
    "fsb_wb_tab_sandbox": "Context Sandbox",
    "fsb_wb_workspace": "Workbench",
    "fsb_wb_connected": "Connected",
    "fsb_wb_noConnector": "No connectors",
    "fsb_wb_available": "Available connectors",
    "fsb_wb_disconnect": "Disconnect",
    "fsb_wb_connect": "Connect",
    "fsb_wb_skillList": "Skills",
    "fsb_wb_noSkill": "No skills",
    "fsb_wb_test": "Test",
    "fsb_wb_wfList": "Workflows",
    "fsb_wb_noWorkflow": "No workflows",
    "fsb_wb_createWf": "Create workflow",
    "fsb_wb_run": "Run",
    "fsb_wb_schedule": "Schedule",
    "fsb_wb_variables": "Variables",
    "fsb_wb_noVariable": "No variables",
    "fsb_wb_templates": "Templates",
    "fsb_wb_newWf": "New workflow",
    "fsb_wb_createFirstWf": "Create your first workflow",
    "fsb_wb_nodeCountFmt": "%d nodes",
    "fsb_wb_taskCenter": "Task center",
    "fsb_wb_noApproval": "No pending approvals",
    "fsb_wb_approvalReq": "Approval request",
    "fsb_wb_approve": "Approve",
    "fsb_wb_deny": "Deny",
    "fsb_wb_noScheduled": "No scheduled tasks",
    "fsb_wb_noHistory": "No execution history",
    "fsb_wb_inputData": "Input data",
    "fsb_wb_sandboxVars": "Sandbox variables",
    "fsb_wb_snapshots": "Snapshots",
    "fsb_wb_sandboxEmpty": "Context sandbox is empty",
    "fsb_wb_sandboxHint": "After running a workflow, the sandbox records\nexecution context and data snapshots",
    "rag_sec_dashboard": "Knowledge Base Overview",
    "rag_sec_files": "File Directory Management",
    "rag_sec_chat": "RAG Chat",
    "rag_sec_embedConfig": "Embedding Model Config",
    "rag_sec_searchConfig": "Retrieval Strategy Config",
    "rag_sec_permissions": "Permissions",
    "rag_sec_vectorOps": "Vector DB Ops",
    "rag_sec_callLog": "RAG Call Log",
    "rag_sec_benchEval": "Retrieval Bench",
    "rag_currentKb": "Current KB",
    "rag_all": "All",
    "rag_tab_bases": "Knowledge Bases",
    "rag_tab_chat": "Chat",
    "rag_tab_search": "Search",
    "rag_tab_config": "Config",
    "rag_log_title": "RAG Call Log",
    "rag_log_total": "Total calls",
    "rag_log_successRate": "Success rate",
    "rag_log_avgLatency": "Avg latency",
    "rag_log_search": "Search",
    "rag_log_ask": "Q&A",
    "rag_log_searchPh": "Search logs...",
    "rag_log_opPicker": "Operation",
    "rag_log_export": "Export CSV",
    "rag_log_empty": "No call logs",
    "rag_log_h_time": "Time",
    "rag_log_h_kb": "KB",
    "rag_log_h_op": "Op",
    "rag_log_h_query": "Query",
    "rag_log_h_result": "Result",
    "rag_log_h_latency": "Latency",
    "rag_log_h_status": "Status",
    "rag_log_exportTitle": "Export RAG Call Log",
    "rag_log_exportDescFmt": "Export %d filtered logs to CSV",
    "rag_log_exportBtn": "Export",
    "rag_op_all": "All",
    "rag_op_search": "Search",
    "rag_op_ask": "Q&A",
    "rag_op_ingest": "Ingest",
    "rag_op_delete": "Delete",
    "rag_op_watch": "Watch",
    "rag_op_sync": "Sync",
    "rag_perm_title": "Permissions",
    "rag_perm_authStatus": "Auth Status",
    "rag_perm_apiKeyAuth": "API Key Auth",
    "rag_perm_disabled": "Disabled",
    "rag_perm_enabled": "Enabled",
    "rag_perm_activeKeys": "Active keys",
    "rag_perm_keyMgmt": "API Key Management",
    "rag_perm_createKey": "Create key",
    "rag_perm_noKey": "No API keys",
    "rag_perm_noKeyHint": "Auth disabled when no API Key is set",
    "rag_perm_h_name": "Name",
    "rag_perm_h_hash": "Key hash",
    "rag_perm_h_createdAt": "Created",
    "rag_perm_memberRole": "Member Roles",
    "rag_perm_role_admin": "Admin",
    "rag_perm_role_admin_desc": "Full read/write, key mgmt, delete KB",
    "rag_perm_role_edit": "Editor",
    "rag_perm_role_edit_desc": "Upload docs, edit config, reindex",
    "rag_perm_role_query": "Viewer",
    "rag_perm_role_query_desc": "Search, RAG Q&A, read-only",
    "rag_perm_role_api": "API Caller",
    "rag_perm_role_api_desc": "API Key only: search/Q&A",
    "rag_perm_audit": "Audit Log",
    "rag_perm_auditNote": "Upstream API has no audit log endpoint yet; needs an Issue",
    "rag_perm_createTitle": "Create API Key",
    "rag_perm_keyNamePh": "Key name",
    "rag_perm_keyCreated": "Key created (shown once)",
    "rag_perm_createBtn": "Create",
    "rag_emb_title": "Embedding Model Config",
    "rag_emb_model": "Embedding Model",
    "rag_emb_modelName": "Model name",
    "rag_emb_runMode": "Runtime",
    "rag_emb_localMlx": "Local MLX inference",
    "rag_emb_dim768": "768-dim",
    "rag_emb_multilang": "Multilingual",
    "rag_emb_chunkStrategy": "Chunking Strategy",
    "rag_emb_strategyPicker": "Strategy",
    "rag_emb_chunkSize": "Chunk size",
    "rag_emb_overlap": "Overlap",
    "rag_emb_strategy_semantic": "Semantic",
    "rag_emb_strategy_fixed": "Fixed",
    "rag_emb_strategy_code": "Code",
    "rag_emb_strategy_sentence": "Sentence",
    "rag_emb_tip_semantic": "Chunk by semantic boundary, for natural language",
    "rag_emb_tip_fixed": "Fixed token count, for uniform content",
    "rag_emb_tip_code": "Chunk by AST function/class boundary, for code",
    "rag_emb_tip_sentence": "Chunk by sentence boundary, for short text",
    "rag_emb_context": "Context Enhancement",
    "rag_emb_contextToggle": "Contextual Retrieval (context-aware)",
    "rag_emb_contextDesc": "Generate context summary per chunk, boosting retrieval accuracy. Fusion-RAG exclusive: local MLX context generation, no cloud API.",
    "rag_emb_saved": "✓ Config saved",
    "rag_emb_reset": "Reset to default",
    "rag_vec_title": "Vector Store Ops",
    "rag_vec_syncAlertTitle": "Confirm Incremental Sync",
    "rag_vec_syncAlertBtn": "Sync",
    "rag_vec_syncAlertMsg": "Incremental sync will run on the knowledge base directory, detecting file changes and re-indexing. Continue?",
    "rag_vec_createSnapTitle": "Create Version Snapshot",
    "rag_vec_snapDescPh": "Snapshot description (optional)",
    "rag_vec_create": "Create",
    "rag_vec_svcLabel": "Service Status",
    "rag_vec_embEngine": "Embedding Engine",
    "rag_vec_avail": "Available",
    "rag_vec_unavail": "Unavailable",
    "rag_vec_kbCount": "Knowledge Bases",
    "rag_vec_vecStatsLabel": "Vector Stats",
    "rag_vec_docCount": "Documents",
    "rag_vec_chunkCount": "Chunks",
    "rag_vec_vecCount": "Vectors",
    "rag_vec_fileCount": "Files",
    "rag_vec_selectKbHint": "Please select a knowledge base first",
    "rag_vec_opsLabel": "Operations",
    "rag_vec_opSync": "Incremental Sync",
    "rag_vec_opSyncDesc": "Detect file changes and re-index",
    "rag_vec_opSnap": "Create Snapshot",
    "rag_vec_opSnapDesc": "Save current KB state to a version snapshot",
    "rag_vec_opHealth": "Health Check",
    "rag_vec_opHealthDesc": "Check vector store and embedding service status",
    "rag_vec_opRefresh": "Refresh Stats",
    "rag_vec_opRefreshDesc": "Re-fetch KB statistics",
    "rag_vec_snapLabel": "Version Snapshots",
    "rag_vec_snapCountFmt": "%d snapshots",
    "rag_vec_snapEmpty": "No snapshots yet. Click 「Create Snapshot」 to save current KB state",
    "rag_vec_snapNote": "Version snapshots are a key competitive advantage of Fusion-RAG over Claude RAG: point-in-time rollback, incremental diff, data recovery.",
    "rag_vec_snapFallback": "Snapshot",
    "rag_vec_rollback": "Rollback",
    "rag_vec_syncing": "Syncing...",
    "rag_vec_syncDoneFmt": "✓ Sync complete: %d files updated",
    "rag_vec_syncFail": "✗ Sync failed",
    "rag_vec_creatingSnap": "Creating snapshot...",
    "rag_vec_snapDoneFmt": "✓ Snapshot created: %@",
    "rag_vec_snapFail": "✗ Snapshot creation failed",
    "rag_vec_rollingBack": "Rolling back...",
    "rag_vec_rollbackDoneFmt": "✓ Rolled back to snapshot %@",
    "rag_vec_rollbackFail": "✗ Rollback failed",
    "rag_vec_svcHealthy": "✓ Service healthy",
    "rag_vec_svcUnhealthy": "✗ Service unhealthy",
    "rag_dash_kbTitle": "Knowledge Bases",
    "rag_dash_newBtn": "New",
    "rag_dash_svcHealthy": "Fusion-RAG service normal",
    "rag_dash_svcUnhealthy": "Fusion-RAG service unavailable",
    "rag_dash_kbCountFmt": "%d knowledge bases",
    "rag_dash_emptyTitle": "No knowledge bases",
    "rag_dash_createKb": "Create Knowledge Base",
    "rag_dash_namePh": "Name",
    "rag_dash_descPh": "Description",
    "rag_dash_chunkStrategyPh": "Chunk Strategy",
    "rag_dash_embedModelPh": "Embedding Model",
    "rag_dash_create": "Create",
    "rag_dash_scanTitle": "Scan Directory Import",
    "rag_dash_kbPrefix": "Knowledge base: %@",
    "rag_dash_dirPathPh": "Directory path",
    "rag_dash_scanBtn": "Start Scan",
    "rag_dash_statFile": "Files",
    "rag_dash_statChunk": "Chunks",
    "rag_dash_statVec": "Vectors",
    "rag_dash_enterBtn": "Enter",
    "rag_dash_importBtn": "Import",
    "rag_dash_chatMenu": "RAG Chat",
    "rag_dash_scanMenu": "Scan Directory",
    "rag_file_searchPh": "Search files...",
    "rag_file_watchBtn": "Watch",
    "rag_file_addFileBtn": "Add File",
    "rag_file_selectKbHint": "Please select a knowledge base first",
    "rag_file_emptyDoc": "No documents",
    "rag_file_h_name": "File Name",
    "rag_file_h_type": "Type",
    "rag_file_h_size": "Size",
    "rag_file_h_chunk": "Chunks",
    "rag_file_h_status": "Status",
    "rag_file_indexed": "Indexed",
    "rag_file_watchLabel": "File Watch",
    "rag_file_watchEmpty": "No active watches",
    "rag_file_watchFileFmt": "Watching %d files",
    "rag_file_changesFmt": "%d changes",
    "rag_file_lastReindexFmt": "Last reindex: %@",
    "rag_file_stopBtn": "Stop",
    "rag_file_addFileTitle": "Add File",
    "rag_file_addFilePathPh": "File paths (comma-separated)",
    "rag_file_addBtn": "Add",
    "rag_file_watchTitle": "Set File Watch",
    "rag_file_watchPathPh": "File paths (comma-separated)",
    "rag_file_pollInterval": "Poll interval (sec)",
    "rag_file_startWatchBtn": "Start Watch",
    "rag_srch_title": "Search Strategy Config",
    "rag_srch_presetLabel": "Scenario Presets",
    "rag_srch_preset_general": "General",
    "rag_srch_preset_code": "Code",
    "rag_srch_preset_design": "Design",
    "rag_srch_presetDesc_general": "General: balanced sparse+dense retrieval, suited for document Q&A",
    "rag_srch_presetDesc_code": "Code: higher sparse weight (BM25 exact function-name match), enable query decomposition",
    "rag_srch_presetDesc_design": "Design: higher dense weight (semantic understanding of design descriptions), enable query expansion",
    "rag_srch_weightLabel": "Retrieval Weights",
    "rag_srch_hybridToggle": "Hybrid retrieval (BM25 + vector RRF)",
    "rag_srch_sparseLabel": "Sparse retrieval (BM25)",
    "rag_srch_denseLabel": "Dense retrieval (vector)",
    "rag_srch_alphaLabel": "Hybrid Alpha (RRF weight)",
    "rag_srch_rerankToggle": "Rerank",
    "rag_srch_rerankTip": "Rerank uses BGE-Reranker to re-score initial results, significantly boosting Top-5 accuracy",
    "rag_srch_paramsLabel": "Retrieval Params",
    "rag_srch_topKLabel": "Top-K results",
    "rag_srch_thresholdLabel": "Similarity threshold",
    "rag_srch_rewriteCard": "Query Rewrite",
    "rag_srch_rewriteModePicker": "Rewrite mode",
    "rag_srch_rewriteDesc_none": "No query rewrite; use the raw query directly",
    "rag_srch_rewriteDesc_expand": "Query expansion: generate synonyms to increase recall",
    "rag_srch_rewriteDesc_decompose": "Query decomposition: split complex queries into sub-questions and retrieve separately",
    "rag_srch_rewriteDesc_hyde": "HyDE: generate a hypothetical answer with LLM first, then retrieve using it",
    "rag_srch_testLabel": "Search Test",
    "rag_srch_testQueryPh": "Enter test query...",
    "rag_srch_testBtn": "Test",
    "rag_srch_rw_none": "None",
    "rag_srch_rw_expand": "Expand",
    "rag_srch_rw_decompose": "Decompose",
    "rag_srch_rw_hyde": "HyDE",
    "rag_bench_title": "Retrieval Performance Eval",
    "rag_bench_adv_local": "Local offline vectors",
    "rag_bench_adv_ast": "Code AST parsing",
    "rag_bench_adv_rrf": "Hybrid retrieval RRF",
    "rag_bench_adv_context": "Contextual Retrieval",
    "rag_bench_adv_sync": "Incremental Sync",
    "rag_bench_adv_snap": "Version Snapshots",
    "rag_bench_presetLabel": "Eval Presets",
    "rag_bench_preset_standard": "Standard",
    "rag_bench_preset_code": "Code Retrieval",
    "rag_bench_preset_design": "Design Retrieval",
    "rag_bench_customQueryLabel": "Custom Eval Set",
    "rag_bench_customEmpty": "Click + to add eval queries and expected docs",
    "rag_bench_addQueryTitle": "Add Eval Query",
    "rag_bench_queryPh": "Query text",
    "rag_bench_expectedPh": "Expected document name",
    "rag_bench_addBtn": "Add",
    "rag_bench_runBtn": "Run Eval",
    "rag_bench_hitRateFmt": "Top-5 hit rate: %@",
    "rag_bench_clearResultsBtn": "Clear Results",
    "rag_bench_resultsLabel": "Eval Results",
    "rag_bench_resultsEmpty": "Click 「Run Eval」 to start",
    "rag_bench_miniHit": "Hits",
    "rag_bench_miniLatency": "Avg latency",
    "rag_bench_miniTopScore": "Top score",
    "rag_bench_historyLabel": "Eval History",
    "rag_bench_historyEmpty": "No eval history",
    "fsb_cv_node_start": "Start",
    "fsb_cv_node_connector": "Connector",
    "fsb_cv_node_skill": "Skill",
    "fsb_cv_node_condition": "Condition",
    "fsb_cv_node_approval": "Approval",
    "fsb_cv_node_output": "Output",
    "fsb_cv_node_end": "End",
    "fsb_cv_wfName": "Workflow name",
    "fsb_cv_autoLayout": "Auto layout",
    "fsb_cv_running": "Running...",
    "fsb_cv_testRun": "Test run",
    "fsb_cv_saving": "Saving...",
    "fsb_cv_nodeTypes": "Node types",
    "fsb_cv_hintDrag": "Tip: drag nodes to canvas",
    "fsb_cv_hintRightClick": "Right-click canvas to add node",
    "fsb_cv_hintConnect": "Drag ports to connect nodes",
    "fsb_cv_nodeName": "Node name",
    "fsb_cv_deleteNode": "Delete node",
    "fsb_cv_connector": "Connector",
    "fsb_cv_selectConnector": "Select connector",
    "fsb_cv_notSelected": "Not selected",
    "fsb_cv_action": "Action",
    "fsb_cv_skill": "Skill",
    "fsb_cv_selectSkill": "Select skill",
    "fsb_cv_promptTpl": "Prompt template",
    "fsb_cv_conditionExpr": "Condition expression",
    "fsb_cv_conditionHint": "True branch goes down, False branch goes right",
    "fsb_cv_approvalConfig": "Approval config",
    "fsb_cv_approvalMode": "Approval mode",
    "fsb_cv_writeOnly": "Write-only (recommended)",
    "fsb_cv_allOps": "All operations",
    "fsb_cv_approvalNote": "Approval note",
    "fsb_cv_timeoutFmt": "Timeout: %ds",
    "fsb_cv_outputFormat": "Output format",
    "fsb_cv_format": "Format",
    "fsb_cv_plainText": "Plain text",
    "fsb_cv_addNode": "Add node",
    "fsb_cv_newWorkflow": "New workflow",
    "mn_kv_title": "KV Cache",
    "mn_kv_subtitle": "Manage cluster KV cache, view hit rate and node distribution",
    "mn_kv_totalEntries": "Total Entries",
    "mn_kv_cacheEntries": "Cache entries",
    "mn_kv_totalSize": "Total Size",
    "mn_kv_cacheSpace": "Cache space",
    "mn_kv_hitRate": "Hit Rate",
    "mn_kv_hitRateSub": "KV cache hits",
    "mn_kv_findCache": "Find Cache",
    "mn_kv_searchPh": "Enter model name to find KV cache...",
    "mn_kv_findBtn": "Find",
    "mn_kv_notFoundFmt": "No KV cache found for model: %@",
    "mn_kv_hwTitle": "Agent Hardware",
    "mn_kv_node": "Node",
    "mn_kv_memory": "Memory",
    "mn_kv_device": "Device",
    "mn_kv_agentOnline": "Agent Online",
    "mn_kv_agentOffline": "Agent Offline",
    "mn_kv_checking": "Checking...",
    "mn_kv_warmTitle": "KV Warmup",
    "mn_kv_modelName": "Model Name",
    "mn_kv_warmPrompt": "Warmup Prompt",
    "mn_kv_warmBtn": "Warm",
    "mn_kv_warmedFmt": "Warmed %d cache entries",
    "mn_kv_transferTitle": "KV Transfer",
    "mn_kv_targetNode": "Target Node ID",
    "mn_kv_transferBtn": "Transfer",
    "mn_kv_byModelTitle": "By Model",
    "mn_kv_countFmt": "%d entries",
    "mn_task_title": "Task Monitor",
    "mn_task_subtitle": "Track task execution status and progress in real time",
    "mn_task_tab_all": "All",
    "mn_task_tab_running": "Running",
    "mn_task_tab_completed": "Completed",
    "mn_task_tab_failed": "Failed",
    "mn_task_migrateTitle": "Migrate Task",
    "mn_task_taskId": "Task ID",
    "mn_task_targetNode": "Target Node",
    "mn_task_selectNode": "Select",
    "mn_task_confirmMigrate": "Confirm Migration",
    "mn_task_total": "Total Tasks",
    "mn_task_allTasks": "All tasks",
    "mn_task_running": "Running",
    "mn_task_executing": "Executing",
    "mn_task_failed": "Failed",
    "mn_task_needsAttention": "Needs Attention",
    "mn_task_listTitleFmt": "Task List (%d)",
    "mn_task_searchPh": "Search tasks...",
    "mn_task_cancelTask": "Cancel Task",
    "mn_task_degradeTask": "Degrade Task",
    "mn_task_migrateTask": "Migrate Task",
    "mn_task_emptyFmt": "No %@ tasks",
    "mn_sync_title": "Cluster Sync",
    "mn_sync_subtitle": "Model incremental sync and cluster partition status",
    "mn_sync_partitionState": "Partition State",
    "mn_sync_partitionNodes": "Partition Nodes",
    "mn_sync_isDegraded": "Degraded",
    "mn_sync_degraded": "Degraded",
    "mn_sync_normal": "Normal",
    "mn_sync_syncAvailable": "Sync Available",
    "mn_sync_available": "Available",
    "mn_sync_unavailable": "Unavailable",
    "mn_sync_incrementalTitle": "Incremental Sync",
    "mn_sync_modelName": "Model Name",
    "mn_sync_modelPh": "e.g. Qwen2.5-7B-Instruct",
    "mn_sync_sourceHost": "Source Node Host",
    "mn_sync_sourcePort": "Source Port",
    "mn_sync_syncing": "Syncing...",
    "mn_sync_triggerBtn": "Trigger Sync",
    "mn_sync_manifestTitle": "Model Manifest",
    "mn_sync_manifestPh": "Enter model name to view Manifest",
    "mn_sync_viewBtn": "View",
    "mn_sync_upToDateFmt": "Model %@ is up to date",
    "mn_sync_syncDoneFmt": "Sync complete: %d files updated",
    "mn_sync_syncFailFmt": "Sync failed: %@",
    "mn_route_title": "Routing Strategy",
    "mn_route_subtitle": "Configure cluster task routing strategy and load balancing",
    "mn_route_currentTitle": "Current Strategy",
    "mn_route_strategy": "Routing Strategy",
    "mn_route_applyBtn": "Apply Strategy",
    "mn_route_loadTitle": "Node Load Distribution",
    "mn_route_avgLoad": "Average Load",
    "mn_route_updatedFmt": "Strategy updated to %@",
    "mn_route_desc_least_loaded": "Prefer assigning to the least loaded node",
    "mn_route_desc_round_robin": "Round-robin assignment to each node",
    "mn_route_desc_random": "Randomly select a node",
    "mn_route_desc_capability_aware": "Match by node capability and task requirements",
    "mn_alert_title": "Alert Center",
    "mn_alert_subtitle": "Cluster anomaly detection and smart suggestions",
    "mn_alert_tab_active": "Active Alerts",
    "mn_alert_tab_suggestions": "Smart Suggestions",
    "mn_alert_tab_history": "Alert History",
    "mn_alert_exportBtn": "Export Log",
    "mn_alert_activeTitleFmt": "Active Alerts (%d)",
    "mn_alert_activeEmpty": "No active alerts, cluster running normally",
    "mn_alert_suggestTitleFmt": "Smart Suggestions (%d)",
    "mn_alert_suggestEmpty": "No optimization suggestions",
    "mn_alert_historyTitle": "Alert History",
    "mn_alert_historyEmpty": "No alert history",
    "mn_alert_ackBtn": "Acknowledge",
    "mn_err_invalidURL": "Invalid URL",
    "mn_err_noData": "No data returned",
    "mn_overview_title": "Cluster Overview",
    "mn_overview_subtitle": "Monitor cluster node status and resources in real time",
    "mn_overview_disconnectedFmt": "Multi-Node service not connected — ensure the service is running (port %d)",
    "mn_overview_metricNodes": "Nodes",
    "mn_overview_metricTotal": "Total",
    "mn_overview_metricOnline": "Online",
    "mn_overview_metricOnlineRun": "Running online",
    "mn_overview_metricActiveTasks": "Active Tasks",
    "mn_overview_metricExecuting": "Executing",
    "mn_overview_metricClusterMem": "Cluster Memory",
    "mn_overview_metricTotalMemFmt": "Total %@GB",
    "mn_overview_submitTaskBtn": "Submit Task",
    "mn_overview_searchPh": "Search nodes...",
    "mn_overview_nodeListFmt": "Node List (%d)",
    "mn_overview_viewMetrics": "View Metrics",
    "mn_overview_removeNode": "Remove Node",
    "mn_overview_degradedFmt": "Cluster is degraded — partition: %@",
    "mn_overview_normalFmt": "Cluster sync normal — partition: %@",
    "mn_overview_detailLink": "Details",
    "mn_submit_title": "Submit Task",
    "mn_submit_subtitle": "Submit a new inference or compute task to the cluster",
    "mn_submit_configTitle": "Task Configuration",
    "mn_submit_taskNameLabel": "Task Name",
    "mn_submit_taskNameSub": "Descriptive name to identify the task",
    "mn_submit_taskNamePh": "e.g. llama-inference-batch",
    "mn_submit_execModeLabel": "Execution Mode",
    "mn_submit_execModeSub": "pipeline=pipeline, data_parallel=data parallel, inference=single-node inference",
    "mn_submit_modelLabel": "Model Name",
    "mn_submit_modelSub": "Target inference model",
    "mn_submit_modelPh": "e.g. mlx-community/Llama-3.2-1B",
    "mn_submit_priorityLabel": "Priority",
    "mn_submit_prioritySub": "1=lowest, 10=highest",
    "mn_submit_capabilityLabel": "Required Capability",
    "mn_submit_capabilitySub": "Optional: e.g. gpu, high_memory",
    "mn_submit_capabilityPh": "Optional",
    "mn_submit_submitBtn": "Submit",
    "mn_submit_successFmt": "Task submitted (ID: %@)",
    "mn_node_title": "Node Actions",
    "mn_node_subtitle": "Elastic scaling config and node management",
    "mn_node_autoscalerTitle": "Autoscaler Elastic Config",
    "mn_node_mgmtTitle": "Node Management",
    "mn_node_removeBtn": "Remove",
    "mn_node_emptyNodes": "No nodes",
    "mn_node_minNodes": "Min Nodes",
    "mn_node_maxNodes": "Max Nodes",
    "mn_node_scaleUpThreshold": "Scale-Up Threshold",
    "mn_node_scaleDownThreshold": "Scale-Down Threshold",
    "mn_node_cooldownLabel": "Cooldown (s)",
    "mn_node_strategyLabel": "Strategy",
    "mn_node_applying": "Applying...",
    "mn_node_applyBtn": "Apply Config",
    "mn_node_pendingTitle": "Pending Approval",
    "mn_node_pendingEmpty": "No pending nodes",
    "mn_node_approveBtn": "Approve",
    "mn_node_rejectBtn": "Reject",
    "mn_progress_title": "Task Details",
    "mn_progress_subtitle": "View task progress, timeline and subtask status",
    "mn_progress_selectTaskTitle": "Select Task",
    "mn_progress_taskPicker": "Task",
    "mn_progress_inspectorSelect": "Select from Inspector",
    "mn_progress_loadDetailsBtn": "Load Details",
    "mn_progress_execProgressTitle": "Execution Progress",
    "mn_progress_remainingFmt": "Remaining %@",
    "mn_progress_timelineTitle": "Timeline",
    "mn_progress_subTasksFmt": "Subtasks (%d)",
    "mn_progress_emptyHint": "Select a task from the task monitor panel, or choose from the dropdown above",
    "mn_progress_loadFailFmt": "Failed to load progress: %@",
    "mn_web_title": "Service Panel",
    "mn_web_subtitle": "Embed external service UI via WebView",
    "mn_web_tab_docs": "Master API",
    "mn_web_tab_bench": "Benchmark",
    "mn_web_tab_security": "Security",
    "mn_web_docsDescFmt": "FastAPI auto docs — requires fusion-multi-node Master service (port %d)",
    "mn_web_benchDesc": "Benchmark panel — requires fusion-bench bench-site (port 3000, npm run dev)",
    "mn_web_securityDesc": "Security audit panel — requires fusion-security frontend (port 3000)",
    "mn_web_connectingFmt": "Connecting to %@...",
    "mn_web_loadFailFmt": "Failed to load %@",
    "mn_web_retryBtn": "Retry",
    "mn_topo_title": "Topology",
    "mn_topo_subtitle": "Visualize Master-Worker connections",
    "mn_topo_legendOnline": "Online",
    "mn_topo_legendBusy": "Busy",
    "mn_topo_legendOffline": "Offline",
    "mn_topo_legendFault": "Fault",
    "mn_topo_statsFmt": "%d nodes · %d%% online",
    "mn_node_statusA11yFmt": "Node %@",
    "mn_task_degradedFmt": "Degraded: %@→%@",
    "design_swiftUITitle": "SwiftUI Export",
    "design_codegenTitle": "Code Export",
    "design_copy": "Copy",
    "design_close": "Close",
    "design_helpPageMgmt": "Page Management",
    "design_helpCopyCode": "Copy Code (⇧⌘C)",
    "design_helpExportCode": "Export Code (⇧⌘E)",
    "design_helpClear": "Clear Conversation",
    "design_welcomeDesc": "Describe the interface you want and AI generates interactive code",
    "design_inputPh": "Describe the interface you want...",
    "design_emptyTitle": "Describe the interface you want",
    "design_emptyDesc": "AI generates interactive HTML code with live preview on the right",
    "design_clearInput": "Clear Input",
    "design_clearConv": "Clear Conversation",
    "design_copyCurrentCode": "Copy Current Code",
    "design_helpSave": "Save",
    "design_helpCopy": "Copy Code",
    "design_helpHistory": "History",
    "design_helpSwiftUI": "Export SwiftUI",
    "design_helpStop": "Stop",
    "design_helpSend": "Send",
    "design_roleUser": "You",
    "design_roleDesigner": "Designer",
    "design_parsedFmt": "Parsed: %@",
    "design_noVersions": "No version history",
    "design_rollback": "Rollback",
    "design_errMLXNotRunning": "MLX service is not running, start it in the MLX panel before sending",
    "design_errNoModel": "No chat model selected, pick one in the top model selector before sending",
    "design_marqueeFmt": "%d nodes selected",
    "design_previewFmt": "Preview: %@",
    "design_previewHint": "AI-suggested changes, confirm to apply to canvas",
    "design_reject": "Reject",
    "design_accept": "Accept",
    "design_pages": "Pages",
    "design_newPage": "New Page",
    "design_noPages": "No pages yet, auto-created after generating a design",
    "design_deletePage": "Delete Page",
    "design_batchExport": "Batch Export",
    "design_exporting": "Exporting...",
    "design_selectFormat": "Select Export Format",
    "design_skillUseFmt": "Use %@ skill: %@",
    "design_stepConnecting": "Connecting...",
    "design_stepGenerating": "Inferring...",
    "design_stepStreaming": "Generating...",
    "design_stepRendering": "Rendering canvas...",
    "design_stepConnShort": "Connect",
    "design_stepGenShort": "Infer",
    "design_stepStreamShort": "Generate",
    "design_stepRenderShort": "Render",
    "design_grp_pages": "Pages",
    "design_grp_components": "Components",
    "design_grp_skills": "AI Skills",
    "design_tpl_login": "Login Page",
    "design_tpl_dashboard": "Dashboard",
    "design_tpl_landing": "Landing Page",
    "design_tpl_settings": "Settings Page",
    "design_tpl_chat": "Chat UI",
    "design_tpl_profile": "Profile Page",
    "design_tpl_card": "Card Component",
    "design_tpl_form": "Form",
    "design_tpl_table": "Data Table",
    "design_tpl_nav": "Navigation",
    "design_tpl_modal": "Modal/Dialog",
    "design_tpl_buttons": "Buttons",
    "design_tpl_textToUI": "Text to UI",
    "design_tpl_imageToUI": "Image to UI",
    "design_tpl_partialEdit": "Partial Edit",
    "design_tpl_localEdit": "Precise Edit",
    "design_tpl_simPanel": "Similar Panel",
    "design_tpl_multiVariants": "Multi Variants",
    "design_tpl_specDoc": "Spec Document",
    "design_tpl_pageFlow": "Page Flow",
    "design_ds_compLibrary": "Component Library",
    "design_ds_searchCompPh": "Search components...",
    "design_ds_catAll": "All",
    "design_ds_template": "Templates",
    "design_ds_sizeSM": "S",
    "design_ds_sizeMD": "M",
    "design_ds_sizeLG": "L",
    "design_ds_cat_button": "Button",
    "design_ds_cat_card": "Card",
    "design_ds_cat_input": "Input",
    "design_ds_cat_select": "Select",
    "design_ds_cat_modal": "Modal",
    "design_ds_cat_nav": "Navigation",
    "design_ds_cat_table": "Table",
    "design_ds_cat_chart": "Chart",
    "design_ds_cat_form": "Form",
    "design_ds_desc_button": "Action button component supporting multiple style variants and sizes",
    "design_ds_desc_card": "Content card component supporting standard/outlined/featured styles",
    "design_ds_desc_input": "Text input component supporting multiple input types",
    "design_ds_desc_select": "Dropdown select component supporting single/multi-select",
    "design_ds_desc_modal": "Modal component supporting info/confirm/form modes",
    "design_ds_desc_nav": "Navigation component supporting top bar/sidebar/tabs",
    "design_ds_desc_table": "Data table component supporting basic/sortable/pagination",
    "design_ds_desc_chart": "Chart component supporting line/bar/pie",
    "design_ds_desc_form": "Form component supporting login/register/contact forms",
    "design_lint_title": "Lint Check",
    "design_lint_ruleLock": "Rule Lock",
    "design_lint_run": "Run Lint",
    "design_lint_genDocFirst": "Please generate a design document first",
    "design_lint_noResult": "Lint returned no results",
    "design_lint_noViolation": "No violations",
    "design_lint_errCountFmt": "%d errors",
    "design_lint_warnCountFmt": "%d warnings",
    "design_lint_infoCountFmt": "%d info",
    "design_lint_violationCountFmt": "%d violations",
    "design_lint_nodeFmt": "Node: %@",
    "design_lint_rule_contrastCheck": "Contrast check",
    "design_lint_rule_unlabeledInput": "Unlabeled input",
    "design_lint_rule_textEffects": "Text effects",
    "design_lint_rule_abnormalRotation": "Abnormal rotation",
    "design_lint_rule_emptyEffects": "Empty effects",
    "design_lint_rule_tokenInconsistency": "Token inconsistency",
    "design_lint_rule_unnamedNode": "Unnamed node",
    "design_lint_rule_textOverflow": "Text overflow",
    "design_lint_rule_overlappingNodes": "Overlapping nodes",
    "design_lint_rule_hardcodedSpacing": "Hardcoded spacing",
    "design_lint_rule_hardcodedFontSize": "Hardcoded font size",
    "design_lint_rule_missingInteractionState": "Missing interaction state",
    "design_lint_rule_layoutInconsistency": "Layout inconsistency",
    "design_lint_lockTitle": "Design Rule Lock",
    "design_lint_done": "Done",
    "design_lint_lockHint": "Locked rules are ignored during Lint and violations will not be shown",
    "design_lint_lockedCountFmt": "%d rules locked",
    "design_lint_unlockAll": "Unlock all",
    "design_eco_tabSync": "Code Sync",
    "design_eco_tabTpl": "Templates",
    "design_eco_syncToCode": "Forward Sync → Fusion Code",
    "design_eco_compName": "Component name",
    "design_eco_syncing": "Syncing...",
    "design_eco_syncCode": "Sync code",
    "design_eco_watchCode": "Reverse Watch ← Fusion Code",
    "design_eco_checking": "Checking...",
    "design_eco_checkChange": "Check changes",
    "design_eco_noMutation": "No pending style changes",
    "design_eco_applyCanvas": "Apply to canvas",
    "design_eco_saveAsTpl": "Save current design as template",
    "design_eco_tplNamePh": "Template name",
    "design_eco_tplTagsPh": "Tags (comma-separated)",
    "design_eco_tplCatPh": "Category",
    "design_eco_save": "Save",
    "design_eco_searchTpl": "Search templates",
    "design_eco_searchPh": "Search name/tags/category",
    "design_eco_search": "Search",
    "design_eco_noMatchTpl": "No matching templates",
    "design_eco_load": "Load",
    "design_eco_syncDone": "Code sync completed",
    "design_eco_syncFailFmt": "Sync failed: %@",
    "design_eco_appliedFmt": "Applied %d style changes",
    "design_eco_tplSavedFmt": "Template '%@' saved",
    "design_eco_tplSaveFailFmt": "Failed to save template: %@",
    "design_eco_tplLoadedFmt": "Template '%@' loaded",
    "design_theme_modeSystem": "System",
    "design_theme_modeLight": "Light",
    "design_theme_modeDark": "Dark",
    "design_theme_modeCustom": "Custom",
    "design_theme_title": "Theme",
    "design_theme_modeLabel": "Appearance",
    "design_theme_customAccent": "Custom Accent",
    "design_theme_accentBlue": "Blue",
    "design_theme_accentRed": "Red",
    "design_theme_accentGreen": "Green",
    "design_theme_accentOrange": "Orange",
    "design_theme_accentPurple": "Purple",
    "design_theme_accentPink": "Pink",
    "design_theme_preview": "Preview",
    "design_theme_previewLight": "Light",
    "design_theme_previewDark": "Dark",
    "design_theme_reset": "Reset to Default",
    "design_wf_recipe_designToCode": "Design → Code",
    "design_wf_recipe_codeToDesign": "Code → Design",
    "design_wf_recipe_screenshot": "Screenshot → Design → Code",
    "design_wf_recipe_designToCodeDesc": "Create design in Design module, export to code files",
    "design_wf_recipe_codeToDesignDesc": "Import existing code into Design module for visual editing",
    "design_wf_recipe_screenshotDesc": "Capture screenshot, AI-generate design, export to code",
    "design_wf_step_createDesign": "Create Design",
    "design_wf_step_previewDesign": "Preview Design",
    "design_wf_step_exportToCode": "Export to Code",
    "design_wf_step_openInEditor": "Open in Editor",
    "design_wf_step_selectCodeFile": "Select Code File",
    "design_wf_step_importToDesign": "Import to Design",
    "design_wf_step_editDesign": "Edit Design",
    "design_wf_step_syncBack": "Sync Back to File",
    "design_wf_step_captureScreenshot": "Capture Screenshot",
    "design_wf_step_analyzeScreenshot": "Analyze Screenshot",
    "design_wf_step_generateDesign": "Generate Design",
    "design_wf_startFmt": "Starting workflow: %@",
    "design_wf_cancelled": "Workflow cancelled",
    "design_wf_doneFmt": "✅ Workflow complete: %@",
    "design_wf_execFmt": "Executing: %@",
    "design_wf_ssSaved": "Screenshot saved to clipboard, paste into Design chat",
    "design_wf_canvasCleared": "Canvas cleared, describe your design in chat",
    "design_wf_previewing": "Previewing design...",
    "design_wf_editHint": "Describe your edit needs in chat",
    "design_wf_generating": "AI is generating design...",
    "design_wf_analyzing": "Analyzing screenshot and generating design...",
    "design_wf_noScreenshot": "No screenshot in clipboard, capture one first (⌘⇧4)",
    "design_wf_selectCodeFile": "Select Code File",
    "design_wf_selectedFmt": "Selected: %@",
    "design_wf_notSelected": "No file selected",
    "design_wf_importedFmt": "Imported: %@",
    "design_wf_importedDoc": "Document imported",
    "design_wf_noFileSelected": "No file selected, choose a code file first",
    "design_wf_panelTitle": "Design Workflow",
    "design_wf_cancelBtn": "Cancel Workflow",
    "design_ins_sec_layout": "Layout",
    "design_ins_sec_spacing": "Spacing",
    "design_ins_sec_typography": "Typography",
    "design_ins_sec_colors": "Colors",
    "design_ins_sec_borders": "Borders",
    "design_ins_sec_effects": "Effects",
    "design_ins_alignStart": "Start",
    "design_ins_alignCenter": "Center",
    "design_ins_alignEnd": "End",
    "design_ins_justifyBetween": "Space Between",
    "design_ins_justifyAround": "Space Around",
    "design_ins_alignStretch": "Stretch",
    "design_ins_preset_card": "Card",
    "design_ins_preset_button": "Button",
    "design_ins_preset_inputField": "Input Field",
    "design_ins_preset_navBar": "Nav Bar",
    "design_ins_preset_heroSection": "Hero Section",
    "design_ins_title": "Style Inspector",
    "design_ins_presetLabel": "Style Presets",
    "design_ins_layoutMode": "Layout Mode",
    "design_ins_direction": "Direction",
    "design_ins_mainAxis": "Main Axis",
    "design_ins_crossAxis": "Cross Axis",
    "design_ins_width": "Width",
    "design_ins_height": "Height",
    "design_ins_padding": "Padding",
    "design_ins_margin": "Margin",
    "design_ins_gap": "Gap",
    "design_ins_fontFamily": "Font",
    "design_ins_fontSize": "Font Size",
    "design_ins_fontWeight": "Font Weight",
    "design_ins_lineHeight": "Line Height",
    "design_ins_textAlign": "Alignment",
    "design_ins_textColor": "Text Color",
    "design_ins_bgColor": "Background Color",
    "design_ins_borderColor": "Border Color",
    "design_ins_borderWidth": "Border Width",
    "design_ins_borderRadius": "Corner Radius",
    "design_ins_opacity": "Opacity",
    "design_ins_shadow": "Shadow",
    "design_ins_overflow": "Overflow",
    "design_ins_cssOutput": "CSS Output",
    "design_tok_preset_appleHIG": "Apple HIG",
    "design_tok_preset_adminMinimal": "Minimal Admin",
    "design_tok_preset_robotSim": "Robot Simulation",
    "design_tok_cat_colors": "Colors",
    "design_tok_cat_spacing": "Spacing",
    "design_tok_cat_typography": "Typography",
    "design_tok_cat_radius": "Corner Radius",
    "design_tok_cat_shadows": "Shadows",
    "design_tok_cat_animation": "Animation",
    "design_tok_designSpec": "Design Spec",
    "design_cv_menu_duplicate": "Duplicate Node",
    "design_cv_menu_delete": "Delete Node",
    "design_cv_menu_toggleLock": "Lock/Unlock",
    "design_cv_menu_toggleVisibility": "Hide/Show",
    "design_cv_menu_partialRepaint": "Partial Repaint",
    "design_cv_menu_bringToFront": "Bring to Front",
    "design_cv_menu_sendToBack": "Send to Back",
    "design_cv_menu_selectAll": "Select All",
    "design_cv_menu_fitZoom": "Fit Zoom",
    "design_cv_menu_paste": "Paste",
    "design_cg_targetLabel": "Export Target",
    "design_cg_componentName": "Component Name",
    "design_cg_generating": "Generating...",
    "design_cg_generate": "Generate Code",
    "design_cg_copied": "Copied",
    "design_cg_copy": "Copy",
    "design_cg_emptyHint": "Select export target\nClick to generate code",
    "design_cg_charCount": "chars",
    "design_cg_genFailFmt": "Code generation failed: %@",
    "design_cg_desc_html": "Pure HTML + CSS Export",
    "design_cg_desc_react": "React Component + Tailwind CSS",
    "design_cg_desc_tailwind": "Pure Tailwind CSS Classes",
    "design_cg_desc_swiftui": "SwiftUI View Code",
    "design_ds_title": "Design Systems",
    "design_ds_refresh": "Refresh",
    "design_ds_activeFmt": "Active: %@",
    "design_ds_applyToCanvas": "Apply to Canvas",
    "design_ds_activateFailFmt": "Activation failed: %@",
    "design_ds_listFailFmt": "Failed to load design systems: %@",
    "design_ds_name_appleHIG": "Apple HIG",
    "design_ds_name_adminMinimal": "Minimal Admin",
    "design_ds_name_robotSim": "Robot Simulation",
    "design_ds_desc_appleHIG": "Apple Human Interface Guidelines",
    "design_ds_desc_adminMinimal": "Minimal-style admin management",
    "design_ds_desc_robotSim": "Industrial simulation control panel",
    "design_ds_customDesc": "Custom Design System",
    "design_ly_title": "Layers",
    "design_ly_countFmt": "%d elements",
    "design_ly_empty": "No Layers",
    "design_ly_emptyHint": "Layers appear here after generating\na design via AI chat",
    "design_avd_exportReview": "Export Review",
    "design_ae_multiFormat": "Multi-format Export",
    "design_ae_cancel": "Cancel",
    "design_ae_exportFmt": "Export %d format(s)",
    "design_cl_conflictFmt": "File and design both modified recently; using file version: %@",
    "design_si_selectScreenshot": "Select Screenshot File",
    "art_pc_open": "Open",
    "art_pc_copy": "Copy",
    "art_pc_versionHistory": "Version History",
    "art_pc_share": "Share",
    "art_pc_unpin": "Unpin",
    "art_pc_pin": "Pin",
    "art_pc_duplicate": "Duplicate",
    "art_pc_moveToKb": "Move to Project KB",
    "art_pc_delete": "Delete",
    "art_pc_copySuffix": " (Copy)",
    "art_sd_title": "Share Artifact",
    "art_sd_permission": "Permission",
    "art_sd_permView": "View only",
    "art_sd_permComment": "Can comment",
    "art_sd_permEdit": "Can edit",
    "art_sd_expiry": "Expiry",
    "art_sd_exp1h": "1 hour",
    "art_sd_exp1d": "1 day",
    "art_sd_exp7d": "7 days",
    "art_sd_exp30d": "30 days",
    "art_sd_expNever": "Never",
    "art_sd_generate": "Generate Share Link",
    "art_sd_done": "Done",
    "art_sd_shareLink": "Share Link",
    "art_sd_existingShares": "Existing Shares (%d)",
    "art_sd_expires": "Expires: %@",
    "art_sd_revoke": "Revoke",
    "art_tf_tags": "Tags",
    "art_tf_addTag": "Add tag",
    "art_tf_folders": "Folders",
    "art_tf_noFolders": "No folders available",
    "art_vh_rollbackConfirm": "Confirm rollback?",
    "art_vh_rollback": "Rollback",
    "art_vh_cancel": "Cancel",
    "art_vh_rollbackMsg": "Roll back to v%d; current version saved as named snapshot",
    "art_vh_createSnapshot": "Create Snapshot",
    "art_vh_snapshotName": "Snapshot name",
    "art_vh_create": "Create",
    "art_vh_title": "Version History",
    "art_vh_empty": "No version history",
    "art_vh_current": "Current",
    "art_vh_chars": "%d chars",
    "art_vh_diffCurrent": "Compare with current",
    "art_vh_incremental": "Incremental changes",
    "art_vh_noDiff": "No diff",
    "art_vh_diffFail": "Diff load failed: %@",
    "art_rv_sortUpdated": "Recently updated",
    "art_rv_sortCreated": "Created time",
    "art_rv_sortName": "Name",
    "art_rv_scopeAll": "All",
    "art_rv_scopeMine": "Mine",
    "art_rv_scopeStarred": "Starred",
    "art_rv_scopePinned": "Pinned",
    "art_rv_subtitle": "Global artifact repository — manage all artifacts across sessions",
    "art_rv_newFolder": "New Folder",
    "art_rv_folderName": "Folder name",
    "art_rv_create": "Create",
    "art_rv_search": "Search artifacts…",
    "art_rv_typeAll": "All",
    "art_rv_recycle": "Recycle Bin",
    "art_rv_folders": "Folders",
    "art_rv_allArtifacts": "All Artifacts",
    "art_rv_rename": "Rename",
    "art_rv_delete": "Delete",
    "art_rv_retry": "Retry",
    "art_rv_empty": "No artifacts",
    "art_rv_open": "Open",
    "art_rv_unstar": "Unstar",
    "art_rv_star": "Star",
    "art_rv_copyContent": "Copy Content",
    "art_rv_download": "Download",
    "art_rv_copy": "Duplicate",
    "art_rv_moveToKb": "Move to Project KB",
    "art_rv_loadFail": "Load failed: %@",
    "art_rb_title": "Recycle Bin",
    "art_rb_purge": "Purge expired",
    "art_rb_empty": "Recycle bin is empty",
    "art_rb_restore": "Restore",
    "art_cv_rename": "Rename",
    "art_cv_newName": "New name",
    "art_cv_confirm": "Confirm",
    "art_cv_cancel": "Cancel",
    "art_cv_deleteConfirm": "Confirm delete?",
    "art_cv_delete": "Delete",
    "art_cv_deleteMsg": "This moves to recycle bin and can be restored",
    "art_cv_unsaved": "Unsaved changes",
    "art_cv_discard": "Discard",
    "art_cv_save": "Save",
    "art_cv_noPreview": "No preview content",
    "art_cv_chars": "%d chars",
    "art_cv_discardChanges": "Discard changes",
    "art_cv_createSnapshot": "Create version snapshot",
    "art_cv_snapshotLabel": "Snapshot label (optional)",
    "art_cv_create": "Create",
    "art_cv_sections": "%d sections",
    "art_cv_toc": "Table of Contents",
    "desk_tab_templates": "Templates",
    "desk_tab_workflows": "Workflows",
    "desk_tab_agents": "Agents",
    "desk_tab_sessions": "Sessions",
    "desk_tab_permissions": "Permissions",
    "desk_tab_mlx": "MLX",
    "desk_tab_system": "System",
    "desk_tab_events": "Events",
    "desk_close": "Close",
    "desk_loading": "Loading...",
    "desk_name": "Name",
    "desk_category": "Category",
    "desk_description": "Description",
    "desk_create": "Create",
    "desk_cancel": "Cancel",
    "desk_save": "Save",
    "desk_edit": "Edit",
    "desk_delete": "Delete",
    "desk_status": "Status",
    "desk_refresh": "Refresh",
    "desk_svc_notConnected": "Fusion-CoWork service not connected",
    "desk_svc_notConnectedHint": "Please start the fusion-cowork service and retry (run ./start.sh start in terminal, or start in Settings → Upstream Services)",
    "desk_reconnect": "Reconnect",
    "desk_svc_notReady": "Service not ready",
    "desk_searchTemplates": "Search templates...",
    "desk_tpl_count": "%d templates",
    "desk_noTemplates": "No templates",
    "desk_tpl_detail": "Template detail",
    "desk_steps": "Steps",
    "desk_tpl_runResult": "Template %@: %@",
    "desk_tpl_runFail": "Template %@: failed",
    "desk_wf_promptPlaceholder": "Enter natural language to create a workflow...",
    "desk_wf_count": "%d workflows",
    "desk_wf_execStatus": "Execution status",
    "desk_noWorkflows": "No workflows, enter a prompt to create",
    "desk_wf_execStatusTitle": "Workflow execution status",
    "desk_wf_noRunning": "No running workflows",
    "desk_wf_currentNode": "Current node: %@",
    "desk_agent_taskPlaceholder": "Submit task to agent...",
    "desk_submit": "Submit",
    "desk_agent_count": "%d agents",
    "desk_noAgents": "No agents",
    "desk_agent_id": "ID: %@",
    "desk_agent_taskSubmitted": "Task %@ submitted",
    "desk_agent_viewStatus": "View status",
    "desk_agent_status": "Status: %@",
    "desk_agent_progress": "Progress: %@",
    "desk_session_new": "New session",
    "desk_session_count": "%d sessions",
    "desk_noSessions": "No sessions",
    "desk_session_steps": "Steps: %d",
    "desk_session_fork": "Fork",
    "desk_session_edit": "Edit session",
    "desk_session_namePlaceholder": "Session name",
    "desk_session_detail": "Session detail",
    "desk_session_stepCount": "Step count",
    "desk_perm_rules": "Permission rules",
    "desk_perm_checkTool": "Check tool",
    "desk_perm_check": "Check",
    "desk_perm_resetAll": "Reset all",
    "desk_perm_checkResult": "Tool %@: %@",
    "desk_perm_allowed": "Allowed",
    "desk_perm_denied": "Denied",
    "desk_perm_noRules": "No permission rules",
    "desk_perm_scope": "Scope: %@",
    "desk_perm_toggle": "Toggle",
    "desk_mlx_status": "Fusion-MLX status",
    "desk_mlx_running": "Running",
    "desk_mlx_stopped": "Stopped",
    "desk_mlx_noModels": "No models available",
    "desk_mlx_modelList": "Model list",
    "desk_mlx_modelCount": "%d models",
    "desk_mlx_runningTitle": "Fusion-MLX running",
    "desk_mlx_stoppedTitle": "Fusion-MLX not started",
    "desk_mlx_manageHint": "Manage MLX lifecycle via UpstreamServiceManager",
    "desk_sys_info": "System info",
    "desk_sys_platform": "Platform",
    "desk_sys_cpuCores": "CPU cores",
    "desk_sys_memoryTotal": "Memory total",
    "desk_sys_memoryUsed": "Memory used",
    "desk_sys_diskFree": "Disk free",
    "desk_sys_nodeCategories": "Node categories",
    "desk_sys_nodeList": "Node list",
    "desk_sys_loading": "Loading system info...",
    "desk_sys_nodeDetail": "Node detail",
    "desk_sys_inputs": "Input parameters",
    "desk_sys_outputs": "Output",
    "desk_evt_stream": "Event stream",
    "desk_evt_polling": "Polling",
    "desk_evt_subscribed": "Subscribed",
    "desk_evt_count": "%d events",
    "desk_evt_stopPoll": "Stop polling",
    "desk_evt_startPoll": "Start polling",
    "desk_noEvents": "No events",
    "desk_evt_source": "Source: %@",
    "dy_tab_inventory": "Inventory",
    "dy_tab_produce": "Produce",
    "dy_tab_publish": "Publish",
    "dy_tab_plan": "Schedule",
    "dy_tab_comment": "Comments",
    "dy_tab_evolve": "Evolve",
    "dy_tab_stats": "Stats",
    "dy_queue_pending": "Pending",
    "dy_queue_published": "Published",
    "dy_queue_failed": "Failed",
    "dy_queue_refresh": "Refresh",
    "dy_inv_pending_queue": "Pending Queue",
    "dy_inv_pending_empty": "No pending videos. Use \"Produce\" to add stock.",
    "dy_inv_published_recent": "Published (last 20)",
    "dy_inv_published_empty": "No published videos",
    "dy_inv_failed_queue": "Failed Queue",
    "dy_inv_variant_label": "variant %@",
    "dy_prod_title": "One-Click Produce",
    "dy_prod_desc": "Run Graph C via agent-studio (script→img→tts→compose→enqueue). Produces 1 video into the pending queue.",
    "dy_prod_topic_label": "Topic (blank = auto topic_gen)",
    "dy_prod_topic_ph": "e.g. What happens if you fall into a black hole",
    "dy_prod_variant_label": "Hook Variant",
    "dy_prod_hint_a": "%@: Number+Counterintuitive — open with an extreme number plus a counterintuitive claim",
    "dy_prod_hint_b": "%@: Question+Immersion — open with a second-person question to pull the viewer in",
    "dy_prod_hint_c": "%@: Suspense+Conflict — open with an unresolved suspense conflict",
    "dy_prod_start": "Start Produce",
    "dy_pub_title": "Stock Publish",
    "dy_pub_desc": "Run Graph D via agent-studio (dequeue→gate_stock→publish→archive). Publishes 1 item from the pending queue.",
    "dy_pub_dryrun_toggle": "Dry-run (no real publish, stops before upload)",
    "dy_pub_dryrun_btn": "Dry-run Publish",
    "dy_pub_real_btn": "Real Publish",
    "dy_pub_real_warn": "⚠️ Real publish uploads video to your Douyin account. Confirm stock and login state.",
    "dy_plan_title": "Peak-Hour Publish Schedule",
    "dy_plan_desc": "Register a cron plan to auto-run Graph D during peak windows (12-13 / 19-21) and publish from stock — no manual clicks. Backed by agent-studio cron runtime (PR #140).",
    "dy_plan_expr_label": "Cron expression (min hour day month weekday)",
    "dy_plan_expr_default": "Default `5 12,19 * * *` = triggers at 12:05 and 19:05 daily (5 min after each peak window opens).",
    "dy_plan_dryrun_toggle": "Dry-run (no real publish, verifies trigger)",
    "dy_plan_real_warn": "⚠️ A real plan auto-uploads video to Douyin during peak hours. Confirm stock and login state.",
    "dy_plan_register": "Register Plan",
    "dy_plan_refresh": "Refresh",
    "dy_plan_empty": "No publish plans. After registering, next trigger time and execution history show here.",
    "dy_plan_registered": "Registered Plans",
    "dy_plan_history": "Execution History",
    "dy_cron_next": "Next: %@",
    "dy_cron_last": "Last: %@",
    "dy_cron_params": "Params: %@",
    "dy_cron_cancel": "Cancel Plan",
    "dy_comment_title": "Comment Reply",
    "dy_comment_desc": "Run Graph B via agent-studio (fetch→gate→draft→reply). Fetches new comments and bulk-replies, idempotent.",
    "dy_comment_start": "Start Comment Reply",
    "dy_comment_replied_title": "Replied Comment IDs",
    "dy_evolve_title": "Evolve Analysis",
    "dy_evolve_desc": "Run Graph E via agent-studio (snapshot→rank→analyze→repair_scan). Updates winning patterns and scans weak videos.",
    "dy_evolve_run": "Run Evolve Loop",
    "dy_evolve_repair_title": "Weak Video Repair & Resend",
    "dy_evolve_repair_desc": "Run Graph F via agent-studio (scan→gate→retitle). Retitles weak videos and re-queues them.",
    "dy_evolve_repair_scan": "Scan & Repair",
    "dy_win_title": "Winning Patterns",
    "dy_win_summary": "Samples %d · Hot %d · Updated %@",
    "dy_win_title_formula": "Title Formula",
    "dy_win_hot_topic": "✅ Hot Topic",
    "dy_win_hot_hook": "✅ Hot Hook",
    "dy_win_lose": "❌ Losing Pattern",
    "dy_stats_title": "Stats Report · Overview",
    "dy_stats_desc": "Account performance overview: aggregate metrics + performance distribution + hook variant comparison.",
    "dy_stats_empty": "No stats snapshots. Run \"Evolve Analysis\" first to capture a snapshot.",
    "dy_stats_detail_title": "Per-Video Detail (by plays desc, best first)",
    "dy_stats_total_plays": "Total Plays",
    "dy_stats_total_likes": "Total Likes",
    "dy_stats_total_comments": "Total Comments",
    "dy_stats_total_shares": "Total Shares",
    "dy_stats_count": "Videos",
    "dy_stats_avg_plays": "Avg Plays",
    "dy_stats_avg_ir": "Avg IR",
    "dy_stats_hot_count": "Hot Count",
    "dy_stats_dist_hot": "Hot %d",
    "dy_stats_dist_mid": "Steady %d",
    "dy_stats_dist_cold": "Weak %d",
    "dy_stats_variant_dist": "Hook Variant Sample Distribution",
    "dy_stats_variant_count": "%@: %d items",
    "dy_stats_row_plays": "Plays %d",
    "dy_stats_row_likes": "Likes %d",
    "dy_stats_row_comments": "Comments %d",
    "dy_stats_row_shares": "Shares %d",
    "dy_stats_row_ir": "IR %.2f%%",
    "dy_action_running": "Running…",
    "dy_action_produce": "Producing",
    "dy_action_publish": "Publishing",
    "dy_action_comment_reply": "Comment Reply",
    "dy_action_evolve": "Evolve Analysis",
    "dy_action_repair": "Weak Video Repair",
    "dy_err_ops_not_found": "Not found: %@. Ensure fusion-operation has run and produced out/ data.",
    "dy_err_ipc_disconnected": "IPC not connected. Cannot call agent-studio.",
    "dy_err_ipc_register": "IPC not connected. Cannot register publish plan.",
    "dy_res_done": "Completed: %d events",
    "dy_res_status": "Status: %@",
    "dy_res_plan_registered": "Publish plan registered. Awaiting peak-hour auto-trigger.",
    "dy_res_register_failed": "Registration failed",
    "dy_err_rungraph": "runGraph %@ failed: %@",
    "dy_err_graph_missing": "Graph file missing: %@",
    "dy_err_graph_parse": "Graph JSON parse failed: %@",
    "dy_err_graph_no_id": "graph.create returned no graph_id",
    "dy_err_register": "Register publish plan failed: %@",
    "dy_err_unregister": "Cancel plan failed: %@",
    "dy_cron_name": "Douyin Peak-Hour Publish Plan",
    "fc_mode_ask": "Ask",
    "fc_mode_auto": "Auto",
    "fc_mode_plan": "Plan",
    "fc_layout_four_column": "Four Column",
    "fc_layout_three_column": "Three Column",
    "fc_layout_two_column": "Two Column",
    "fc_layout_chat_only": "Chat Only",
    "fc_pane_editor": "Editor",
    "fc_pane_diff": "Diff",
    "fc_pane_preview": "Preview",
    "fc_pane_terminal": "Terminal",
    "fc_pane_snapshot": "Snapshot",
    "fc_pane_workflow": "Workflow",
    "fc_pane_sandbox": "Sandbox",
    "fc_cmd_help": "Show available commands",
    "fc_cmd_clear": "Clear conversation",
    "fc_cmd_compact": "Compact conversation context",
    "fc_cmd_model": "Switch model",
    "fc_cmd_kb": "Query knowledge base",
    "fc_cmd_memory": "Manage project memory",
    "fc_cmd_template": "Apply workflow template",
    "fc_cmd_init": "Initialize project context",
    "fc_cmd_review": "Code review current changes",
    "fc_cmd_test": "Generate and run tests",
    "fc_cmd_deploy": "Deploy project",
    "fc_cmd_explain": "Explain code",
    "fc_cmd_refactor": "Refactor code",
    "fc_cmd_debug": "Debug issue",
    "fc_no_project_title": "Open a project folder",
    "fc_open_folder": "Open Folder",
    "fc_offline_mlx": "fusion-code offline — using MLX inference",
    "fc_thinking": "Thinking...",
    "fc_connected": "Connected",
    "fc_offline": "Offline",
    "fc_hide_session_bar": "Hide session bar",
    "fc_show_session_bar": "Show session bar",
    "fc_greeting_morning": "Good morning",
    "fc_greeting_afternoon": "Good afternoon",
    "fc_greeting_evening": "Good evening",
    "fc_greeting_night": "Good night",
    "fc_welcome_subtitle": "Fusion Code — Local AI Coding Assistant",
    "fc_card_open_title": "Open Project",
    "fc_card_open_sub": "Start with a local folder",
    "fc_card_code_title": "Code",
    "fc_card_code_sub": "Generate & edit code",
    "fc_card_debug_title": "Debug",
    "fc_card_debug_sub": "Find and fix issues",
    "fc_card_kb_title": "KB Query",
    "fc_card_kb_sub": "Ask your codebase",
    "fc_card_memory_title": "Memory",
    "fc_card_memory_sub": "Manage context",
    "fc_card_template_title": "Template",
    "fc_card_template_sub": "Workflow templates",
    "fc_card_review_title": "Review",
    "fc_card_review_sub": "Code review",
    "fc_card_test_title": "Test",
    "fc_card_test_sub": "Generate tests",
    "fc_prompt_write": "Write a ",
    "fc_prompt_debug": "Help me debug this",
    "fc_add_folder": "Add folder",
    "fc_add_file": "Add file",
    "fc_query_kb": "Query KB",
    "fc_templates": "Templates",
    "fc_web_search": "Web search",
    "fc_input_placeholder": "Ask anything — / for commands...",
    "fc_select_file_edit": "Select a file to edit",
    "fc_select_session_snapshot": "Select a session to view snapshots",
    "fc_undo": "Undo",
    "fc_save": "Save",
    "fc_project_context": "Project Context",
    "fc_ctx_project": "Project",
    "fc_ctx_branch": "Branch",
    "fc_ctx_files": "Files",
    "fc_ctx_model": "Model",
    "fc_ctx_mode": "Mode",
    "fc_ctx_kb": "KB",
    "fc_not_selected": "Not selected",
    "fc_no_project_open": "No project open",
    "fc_project_memory": "Project Memory",
    "fc_load_memory": "Load Memory Files",
    "fc_write_memory": "Write Memory",
    "fc_sessions": "Sessions",
    "fc_no_sessions": "No sessions",
    "fc_messages_count": "%d messages",
    "fc_workflow_templates": "Workflow Templates",
    "fc_tpl_review": "Code Review",
    "fc_tpl_test": "Generate Tests",
    "fc_tpl_debug": "Debug Issue",
    "fc_tpl_refactor": "Refactor",
    "fc_tpl_explain": "Explain Code",
    "fc_tpl_deploy": "Deploy",
    "fc_msg_model_switched": "Model switched to: %@",
    "fc_msg_current_model": "Current model: %@",
    "fc_msg_context_compacted": "Context compacted",
    "fc_msg_unknown_cmd": "Unknown command: %@. Type /help for available commands.",
    "fc_msg_kb_usage": "Usage: /kb <query>",
    "fc_msg_no_project_open": "No project open. Open a folder first.",
    "fc_msg_kb_no_results": "No results found for: %@",
    "fc_msg_kb_results": "KB Results:\n\n%@",
    "fc_msg_kb_failed": "KB query failed: %@",
    "fc_msg_no_project": "No project open.",
    "fc_msg_no_memory": "No memory files found.",
    "fc_msg_memory_files": "Memory files:\n%@",
    "fc_msg_memory_failed": "Memory load failed: %@",
    "fc_kb_building": "KB: building...",
    "fc_kb_build_failed": "KB: build failed",
    "fc_tool_edit": "Edit file: %@",
    "fc_tool_write": "Write file: %@",
    "fc_tool_run": "Run: %@",
    "fc_tool_multi_edit": "Edit multiple files",
    "fc_denied_by_user": "Denied by user",
    "fc_approve": "Approve",
    "fc_deny": "Deny",
    "fc_apply_code": "Apply Code",
    "fc_apply_code_n": "Apply Code #%d",
    "fc_status_pending": "Pending",
    "fc_status_running": "Running",
    "fc_status_approved": "Approved",
    "fc_status_denied": "Denied",
    "fc_status_completed": "Done",
    "fc_status_failed": "Failed",
    "fc_code": "code",
    "fc_copied": "Copied",
    "fc_copy": "Copy",
    "fc_no_matching_commands": "No matching commands",
    "fc_new_session": "New Session",
    "fc_title": "Title",
    "fc_session_title_ph": "Session title",
    "fc_cancel": "Cancel",
    "fc_create": "Create",
    "fc_permission_request": "Permission Request",
    "fc_tool_label": "Tool:",
    "fc_open_project_folder": "Open Project Folder",
    "fc_open_file": "Open File",
    "fc_scanning": "Scanning %@...",
    "fc_loaded_files": "Loaded %d files",
    "fc_loading": "Loading %@...",
    "fc_loaded_one_file": "Loaded 1 file",
    "fc_load_failed": "Failed to load: %@",
    "fc_scanning_n": "Scanning %d/%d...",
    "fc_ai_unavailable": "AI service temporarily unavailable, please retry later.",
    "fc_sidebar_chat": "Chat",
    "fc_sidebar_files": "Files",
    "fc_sidebar_git": "Git",
    "fc_sidebar_design": "Design",
    "fc_toggle_sidebar": "Toggle sidebar",
    "fc_input_ask_anything": "Ask anything — code, explain, debug, refactor...",
    "fc_attach_file": "Attach file",
    "fc_menu_add_folder": "Add Folder...",
    "fc_menu_add_file": "Add File...",
    "fc_menu_add_github": "Add GitHub Repo...",
    "fc_git_url_detected": "Git repository URL detected",
    "fc_send": "Send",
    "fc_open_project": "Open Project",
    "fc_local_folder": "Local Folder",
    "fc_local_folder_desc": "Select a local folder, auto-scan code files",
    "fc_choose": "Choose...",
    "fc_single_file": "Single File",
    "fc_single_file_desc": "Open a single file for editing and AI assistance",
    "fc_github_repo": "GitHub Repository",
    "fc_github_repo_desc": "Clone remote repo to local workspace",
    "fc_url": "URL",
    "fc_branch": "Branch",
    "fc_clone_open": "Clone & Open",
    "fc_or": "or",
    "fc_drop_here": "Drop files or folders here",
    "fc_search_conversations": "Search conversations...",
    "fc_no_conversations": "No conversations yet",
    "fc_files_count": "%d files",
    "fc_close_project": "Close Project",
    "fc_open_another": "Open Another Project",
    "fc_search_files": "Search files...",
    "fc_open_folder_browse": "Open a folder to browse files",
    "fc_show_in_finder": "Show in Finder",
    "fc_copy_path": "Copy Path",
    "fc_remove_context": "Remove from context",
    "fc_add_to_context": "Add to context",
    "fc_add_to_kb": "Add to knowledge base",
    "fc_index_to_rag": "Index to RAG",
    "fc_add_dir_to_kb": "Add directory to knowledge base",
    "fc_not_git_repo": "Not a git repo",
    "fc_open_for_git": "Open a project to see Git status",
    "fc_no_changes": "No changes",
    "fc_welcome_title": "Fusion Code — AI Coding Assistant",
    "fc_welcome_tagline": "Claude Code compatible · Powered by fusion-mlx",
    "fc_wc_open_title": "Open Project",
    "fc_wc_open_desc": "Load local/Git code",
    "fc_wc_explain_title": "Explain",
    "fc_wc_explain_desc": "Explain code functionality",
    "fc_wc_review_title": "Review",
    "fc_wc_review_desc": "Find code defects",
    "fc_wc_test_title": "Test",
    "fc_wc_test_desc": "Generate unit tests",
    "fc_recent": "Recent",
    "fc_min_ago": "%d min ago",
    "fc_hour_ago": "%d hours ago",
    "fc_day_ago": "%d days ago",
    "fc_term_banner": "Fusion Studio Terminal v1.0",
    "fc_term_help_hint": "Type 'help' for available commands",
    "fc_terminal": "Terminal",
    "fc_clear": "Clear",
    "fc_term_commands": "Commands: help, clear, status, mlx, python, swift",
    "fc_term_unknown": "Unknown: %@. Type 'help'",
    "fc_you": "You",
    "fc_clone": "Clone",
    "fc_group_mode": "Group By",
    "fc_search_sessions": "Search sessions...",
    "fc_no_project2": "No Project",
    "fc_rename": "Rename",
    "fc_pause": "Pause",
    "fc_resume": "Resume",
    "fc_delete": "Delete",
    "fc_layout_mode": "Layout",
    "fc_sessions_count": "%d sessions",
    "fc_new_session_full": "New Coding Session",
    "fc_working_dir": "Working Dir",
    "fc_model_label": "Model",
    "fc_security_mode": "Security Mode",
    "fc_sm_readonly": "Read-only",
    "fc_sm_manual": "Manual Approval",
    "fc_sm_auto": "Auto",
    "fc_gm_by_project": "By Project",
    "fc_gm_by_state": "By State",
    "fc_gm_flat": "Flat",
    "fc_state_idle": "Idle",
    "fc_state_running": "Running",
    "fc_state_waiting": "Waiting Approval",
    "fc_state_paused": "Paused",
    "fc_state_completed": "Completed",
    "fc_state_failed": "Failed",
    "fc_state_cluster": "Cluster Running",
    "fc_sm_auto_full": "Auto-approve",
    "fc_policy": "Policy",
    "fc_audit": "Audit",
    "fc_allow_dirs": "Allowed Dirs",
    "fc_add_dir_ph": "Add dir...",
    "fc_add": "Add",
    "fc_ignore_patterns": "Ignore Patterns (.fusionignore)",
    "fc_add_pattern_ph": "Add pattern...",
    "fc_no_audit": "No audit records",
    "fc_records_count": "%d records",
    "fc_export": "Export",
    "fc_wf_empty_desc": "Create workflows to automate complex tasks",
    "fc_wf_new": "New Workflow",
    "fc_wf_goal_ph": "Goal description",
    "fc_wf_select_template": "Select Template",
    "fc_wf_template_generic": "Generic task decomposition",
    "fc_wf_template_legacy": "Legacy migration",
    "fc_wf_template_security": "Security scan audit",
    "fc_wf_template_batch": "Batch API processing",
    "fc_wf_template_refactor": "Code refactor",
    "fc_wf_template_test": "Test generation",
    "fc_wf_status_failed": "%d failed",
    "fc_wf_status_running": "Running (%d/%d)",
    "fc_wf_status_completed": "Completed",
    "fc_wf_status_pending": "Pending (%d/%d)",
    "fc_preview": "Preview",
    "fc_live": "Live",
    "fc_html_preview_empty": "Preview appears here after HTML is generated",
    "fc_original": "Original",
    "fc_modified": "Modified",
    "fc_design_open_in_module": "Open in Design module",
    "fc_design_no_content": "No design content",
    "fc_design_create_hint": "After creating a design in the Design module,\nyou can preview it here",
    "fc_design_sync_on": "Two-way sync enabled",
    "fc_design_sync_off": "Sync not connected",
    "fc_design_export_file": "Export to file",
    "fc_tier_global": "Global",
    "fc_tier_project": "Project",
    "fc_tier_directory": "Directory",
    "fc_diff_split": "Split",
    "fc_diff_unified": "Unified",
    "fc_diff_line_numbers": "Line numbers",
    "fc_snapshots": "Snapshots",
    "fc_no_snapshots": "No snapshots",
    "fc_create_snapshot": "Create Snapshot",
    "fc_label_optional": "Label (optional)",
    "fc_restore": "Restore",
    "fc_rewind_here": "Rewind to here",
    "fc_snap_deltas_fmt": "%d deltas · %@",
    "fc_snap_not_found": "Snapshot not found: %@",
    "fc_pty_stopped": "stopped",
    "fc_pty_clear": "Clear",
    "fc_pty_stop": "Stop",
    "fc_pty_restart": "Restart",
    "fc_pty_shell_started": "Shell started: %@",
    "fc_pty_shell_exited": "Shell exited.",
    "fc_pty_start_fail": "Failed to start shell: %@",
    "fc_pty_alloc_fail": "Failed to allocate PTY: %@",
    "fc_copy_suffix": " (Copy)",
    "fc_untitled": "Untitled"
]

let jaJPTranslations: [String: String] = [
    "ok": "確認", "cancel": "キャンセル", "save": "保存", "delete": "削除", "edit": "編集",
    "close": "閉じる", "search": "検索", "refresh": "更新", "loading": "読み込み中...", "filter": "フィルター", "clear": "クリア", "retry": "再試行", "add": "追加",
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
    "secPlugin": "Plugin Ecosystem", "secTrainer": "Trainer",

    "newProject": "新規プロジェクト", "openLocalFolder": "ローカルフォルダを開く",
    "newWorkspace": "新規ワークスペース", "newWorkbench": "新規ワークベンチ",
    "noConversationsYet": "チャットなし", "noArtifactsYet": "Artifactsなし",
    "openArtifacts": "Artifactsを開く",
    "runDashboard": "運営ダッシュボード", "pendingPublish": "公開待ち", "published": "公開済み",
    "hitProduct": "ヒット", "douyinHint": "「運営ダッシュボード」で作成 / 公開 / コメント / 進化",

    "mod_dashboard": "ダッシュボード", "mod_design": "デザイン", "mod_code": "コード", "mod_simulation": "シミュレーション", "mod_modelHub": "モデル", "mod_multimodal": "マルチモーダル", "mod_training": "トレーニング", "mod_cli": "コマンドライン", "mod_doc": "ドキュメント", "mod_bench": "ベンチマーク", "mod_desk": "自動化", "mod_dataTools": "データツール", "mod_agent": "エージェント", "mod_plugin": "プラグイン", "mod_security": "セキュリティ", "mod_analytics": "分析", "mod_collab": "コラボレーション", "mod_tuning": "チューニング", "mod_external": "外部連携", "mod_docgen": "ドキュメント生成", "mod_clusterOverview": "クラスタ概要", "mod_clusterTopology": "トポロジー", "mod_clusterSync": "クラスタ同期", "mod_taskMonitor": "タスク監視", "mod_alertCenter": "アラートセンター", "mod_nodeActions": "ノード管理", "mod_submitTask": "タスク送信", "mod_taskProgress": "タスク詳細", "mod_routingStrategy": "ルーティング", "mod_kvCache": "KVキャッシュ", "mod_serviceWeb": "サービスパネル", "mod_rag": "RAG", "mod_memory": "メモリ", "mod_planner": "プランナー", "mod_deploy": "デプロイ", "mod_operations": "運用", "mod_eduK12": "K-12教育", "mod_verification": "検証", "mod_tokenBudget": "トークン予算", "mod_safety": "安全承認", "mod_tools": "ツール", "mod_agentDashboard": "エージェント監視", "mod_teamCollab": "チームコラボ", "mod_chat": "チャット", "mod_fusionProjects": "プロジェクト", "mod_cowork": "コラボスペース", "mod_artifactsRepo": "Artifacts", "mod_fsb": "FSB", "mod_aiAgentDashboard": "AI概要", "mod_aiAgentList": "エージェント一覧", "mod_aiAgentChat": "AIチャット", "mod_aiAgentObserver": "AIオブザーバー", "mod_aiAgentKnowledgeBase": "AIナレッジベース", "mod_science": "サイエンス", "mod_finance": "ファイナンス", "mod_health": "ヘルス", "mod_pluginConfig": "プラグイン設定", "mod_pluginStatus": "プラグイン状態", "mod_pluginToken": "Token", "mod_pluginVram": "VRAM", "mod_pluginLog": "プラグインログ", "mod_pluginMcp": "MCP", "mod_trainer": "トレーナー",

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
    "proj_panelTitle": "プロジェクト",
    "proj_panelSort": "並び替え:",
    "proj_panelNew": "新規",
    "proj_emptyTitle": "プロジェクトを始めますか？",
    "proj_emptyHint": "素材のアップロード、カスタム指示の設定、会話の整理を一か所で。",
    "proj_panelNewProject": "新規プロジェクト",
    "proj_tokensFmt": "%d トークン",
    "proj_panelKbEmpty": "ナレッジファイルはまだありません",
    "proj_panelAutoScan": "自動スキャン",
    "proj_panelCustomInst": "カスタム指示",
    "proj_panelChatHistory": "チャット履歴",
    "proj_panelNewChat": "新規チャット",
    "proj_sessionsFmt": "%d セッション",
    "proj_panelChatEmpty": "チャットセッションはまだありません",
    "proj_panelStartConv": "会話を始める",
    "proj_msgsFmt": "%d 件のメッセージ",
    "proj_panelSelect": "プロジェクトを選択",
    "proj_panelOpenFolder": "プロジェクトフォルダを開く",
    "proj_panelOpen": "開く",
    "proj_panelAddKbFiles": "ナレッジファイルを追加",
    "proj_panelDefaultModel": "デフォルトモデル",
    "proj_panelModelPh": "例: qwen3-9b",
    "proj_panelDefault": "デフォルト",
    "proj_panelTempFmt": "温度: %@",
    "proj_panelMaxTokensFmt": "最大トークン: %d",
    "proj_panelAutoLoadClaude": "CLAUDE.md を自動読み込み",
    "proj_panelAutoScanKb": "ナレッジファイルを自動スキャン",
    "proj_tabSessions": "セッション",
    "proj_tabSettings": "設定",
    "cw_snap_title": "セッションスナップショット",
    "cw_snap_create": "スナップショット作成",
    "cw_snap_empty": "スナップショットなし",
    "cw_list_subtitle": "コラボ空間 — チームチャット、共有エージェント、ワークフロー連携",
    "cw_list_searchPh": "空間を検索...",
    "cw_list_newHelp": "新規コラボ空間",
    "cw_list_marketHelp": "ワークフロー/テンプレート市場",
    "cw_filter_all": "すべて",
    "cw_filter_created": "自分が作成",
    "cw_filter_joined": "参加中",
    "cw_filter_archived": "アーカイブ済",
    "cw_list_onboardingTitle": "最初のコラボ空間を始める",
    "cw_list_onboardingBody": "CoWork はチームのリアルタイムチャット、エージェント共有、ワークフロー連携を実現。オフライン空間、深い研究、デスクトップ共有などをサポート。",
    "cw_list_createLabel": "コラボ空間を作成",
    "cw_list_archivedTag": "アーカイブ済",
    "cw_list_emptyTitle": "コラボ空間を選択",
    "cw_list_emptyHint": "または新規空間を作成して開始",
    "cw_list_loadFail": "読み込み失敗: %@",
    "cw_create_title": "新規コラボ空間",
    "cw_create_basic": "基本情報",
    "cw_create_namePh": "空間名",
    "cw_create_descPh": "説明（任意）",
    "cw_create_mode": "コラボモード",
    "cw_create_modeLocal": "ローカル",
    "cw_create_modeP2p": "LAN",
    "cw_create_modeGateway": "リモート",
    "cw_create_modeLocalDesc": "単体オフライン協業",
    "cw_create_modeP2pDesc": "Bonjour LAN 探索",
    "cw_create_modeGatewayDesc": "Fusion Gateway 経由",
    "cw_create_kb": "ナレッジベース連携",
    "cw_create_kbPh": "KB パス（任意、例: プロジェクトディレクトリ）",
    "cw_create_ability": "空間機能",
    "cw_create_webSearch": "ウェブ検索",
    "cw_create_deepResearch": "深い研究",
    "cw_create_computerUse": "デスクトップ操作",
    "cw_create_memberUpload": "メンバーのアップロード",
    "cw_create_memberAgent": "メンバーのエージェント作成",
    "cw_create_memberWorkflow": "メンバーのワークフロー実行",
    "cw_create_advanced": "詳細設定",
    "cw_create_maxMembers": "最大メンバー数",
    "cw_create_btn": "作成",
    "cw_main_loading": "読み込み中...",
    "cw_main_deepResearch": "深い研究",
    "cw_main_computerUse": "デスクトップ操作",
    "cw_main_createSnap": "スナップショット作成",
    "cw_main_archive": "空間をアーカイブ",
    "cw_main_archivedBanner": "この空間はアーカイブ済み — 読み取り専用",
    "cw_side_members": "メンバー",
    "cw_side_files": "ファイル",
    "cw_side_knowledge": "ナレッジベース",
    "cw_side_agents": "エージェント",
    "cw_side_artifacts": "アーティファクト",
    "cw_side_workflows": "ワークフロー",
    "cw_side_snapshots": "スナップショット",
    "cw_side_desktop": "デスクトップ",
    "cw_side_settings": "設定",
    "cw_chat_emptyTitle": "空間チャット",
    "cw_chat_emptyHint": "最初のメッセージを送信、または @Agent で協業開始",
    "cw_chat_thinking": "考え中...",
    "cw_chat_copy": "コピー",
    "cw_chat_retry": "再試行",
    "cw_chat_attach": "添付",
    "cw_chat_screenshot": "スクリーンショット",
    "cw_chat_noAgent": "なし（直接送信）",
    "cw_chat_inputPh": "メッセージを入力、@Agent で協業...",
    "cw_chat_relay": "エージェントリレー",
    "cw_chat_relayHint": "複数エージェントを選び順番にメッセージを処理",
    "cw_chat_relayClear": "クリア",
    "cw_chat_relayDone": "完了",
    "cw_chat_streamErr": "エラー: %@",
    "cw_chat_sendFail": "送信失敗: %@",
    "cw_chat_relayFail": "リレー失敗: %@",
    "cw_system_name": "システム",
    "cw_comment_title": "コメント",
    "cw_comment_addPh": "コメントを追加...",
    "cw_comment_send": "送信",
    "cw_member_title": "メンバー",
    "cw_member_lanDiscovery": "LAN 探索",
    "cw_member_scanning": "スキャン中...",
    "cw_member_scan": "スキャン",
    "cw_member_inviteTitle": "メンバー招待",
    "cw_member_inviteRole": "ロール",
    "cw_member_inviteMaxUses": "最大使用回数: %d",
    "cw_member_inviteExpires": "有効期限(時間): %d",
    "cw_member_inviteGen": "招待リンクを生成",
    "cw_member_inviteCode": "招待コード: %@",
    "cw_member_remove": "削除",
    "cw_role_owner": "オーナー",
    "cw_role_admin": "管理者",
    "cw_role_member": "メンバー",
    "cw_role_viewer": "閲覧者",
    "cw_files_title": "ファイル",
    "cw_files_empty": "ファイルなし",
    "cw_agent_title": "エージェント",
    "cw_agent_empty": "共有エージェントなし",
    "cw_agent_add": "エージェントを追加",
    "cw_agent_edit": "編集",
    "cw_agent_copyToProject": "プロジェクトにコピー",
    "cw_agent_remove": "削除",
    "cw_agent_addTitle": "エージェントを追加",
    "cw_agent_editTitle": "エージェントを編集",
    "cw_agent_name": "名前",
    "cw_agent_namePh": "エージェント名",
    "cw_agent_model": "モデル",
    "cw_agent_modelPh": "モデル（空欄でデフォルト）",
    "cw_agent_perm": "権限",
    "cw_agent_permAll": "全メンバー利用可能",
    "cw_agent_permAdmin": "管理者のみ",
    "cw_agent_permCustom": "指定メンバー",
    "cw_agent_permAllLabel": "全メンバー",
    "cw_agent_permCustomLabel": "カスタム",
    "cw_snap2_title": "スナップショット",
    "cw_snap2_empty": "スナップショットなし",
    "cw_snap2_createTitle": "スナップショット作成",
    "cw_snap2_namePh": "名前",
    "cw_snap2_forkTitle": "スナップショットをフォーク",
    "cw_snap2_forkSpacePh": "新規空間名",
    "cw_snap2_restore": "このスナップショットを復元",
    "cw_snap2_forkNew": "新規空間にフォーク",
    "cw_snap2_msgCount": "%d 件のメッセージ",
    "cw_snap2_dagName": "DAG: %@",
    "cw_art_title": "アーティファット",
    "cw_art_kindAll": "すべて",
    "cw_art_kindCode": "コード",
    "cw_art_kindDoc": "ドキュメント",
    "cw_art_kindViz": "可視化",
    "cw_art_kindData": "データ",
    "cw_art_createTitle": "アーティファット作成",
    "cw_art_kindPicker": "タイプ",
    "cw_wf_title": "ワークフロー",
    "cw_wf_empty": "ワークフローなし",
    "cw_wf_create": "ワークフロー作成",
    "cw_wf_createTitle": "ワークフロー作成",
    "cw_wf_namePh": "ワークフロー名",
    "cw_wf_descPh": "説明（任意）",
    "cw_wf_nodeCount": "%d ノード",
    "cw_wf_status_running": "実行中",
    "cw_wf_status_completed": "完了",
    "cw_wf_status_failed": "失敗",
    "cw_wf_status_idle": "アイドル",
    "cw_snap_emptyHint": "スナップショットを作成して現在のセッション状態を保存。いつでもロールバックまたはフォーク可能。",
    "cw_snap_labelPh": "ラベル（任意）",
    "cw_snap_createBtn": "作成",
    "cw_snap_forkAlert": "このスナップショットを新規セッションにフォークしますか？",
    "cw_snap_forkBtn": "フォーク",
    "cw_snap_msgFmt": "%d 件のメッセージ",
    "cw_snap_restoreHelp": "このスナップショットに復元",
    "cw_snap_forkHelp": "新規セッションにフォーク",
    "cw_snap_deleteHelp": "スナップショット削除",
    "cw_snap_forkAlertBtn": "フォーク",
    "cw_desk_title": "デスクトップ",
    "cw_desk_role": "ロール",
    "cw_desk_roleObserver": "観察者",
    "cw_desk_roleController": "操作者",
    "cw_desk_roleApprover": "承認者",
    "cw_desk_notSharing": "デスクトップ共有オフ",
    "cw_desk_controlReq": "操作リクエスト",
    "cw_desk_approve": "承認",
    "cw_desk_reject": "拒否",
    "cw_desk_auditLog": "操作ログ",
    "cw_desk_sharing": "共有中",
    "cw_set_title": "設定",
    "cw_set_streamResp": "ストリーム応答",
    "cw_research_running": "進行中...",
    "cw_research_queryPh": "研究質問を入力...",
    "cw_research_depth": "深さ",
    "cw_research_depthShallow": "浅",
    "cw_research_depthMedium": "中",
    "cw_research_depthDeep": "深",
    "cw_research_start": "研究開始",
    "cw_research_multiAgent": "マルチエージェント並列",
    "cw_research_autoSelect": "自動選択",
    "cw_research_agentCountFmt": "%d Agents",
    "cw_research_zeroToken": "トークンコストゼロ · ローカル推論",
    "cw_research_runningProgress": "深度研究進行中...",
    "cw_research_desc": "深度研究はマルチエージェント並列推論で複雑な調査を自動化",
    "cw_research_vsClaude": "Claude CoWork と比較: トークンコストゼロ · ローカルモデル推論 · マルチエージェント並列オプション",
    "cw_research_track": "研究パス",
    "cw_research_agentProgress": "エージェント研究進捗",
    "cw_research_noResult": "研究完了、結果テキストなし",
    "cw_research_failFmt": "研究失敗: %@",
    "cw_research_done": "完了",
    "cw_research_runningStatus": "研究中...",
    "cw_preview_empty": "プレビュー内容なし",
    "cw_notif_title": "通知",
    "cw_notif_markAll": "すべて既読",
    "cw_notif_empty": "通知なし",
    "cw_kb_title": "ナレッジベース",
    "cw_kb_unbound": "ナレッジベース未バインド",
    "cw_kb_bindHint": "バインド後、エージェント対話が関連ドキュメントを自動検索",
    "cw_kb_bind": "ナレッジベースをバインド",
    "cw_kb_statsFmt": "%d 文書, %d チャンク",
    "cw_kb_searchPh": "ナレッジベースを検索...",
    "cw_kb_results": "検索結果",
    "cw_kb_ragAnswer": "RAG 回答",
    "cw_kb_upload": "ドキュメントをアップロード",
    "cw_kb_uploadTitle": "ドキュメントをナレッジベースにアップロード",
    "cw_kb_pathPh": "ファイルパス",
    "cw_kb_uploadBtn": "アップロード",
    "cw_kb_docFmt": "文書 %d",
    "cw_mkt_title": "マーケットプレース",
    "cw_mkt_type": "タイプ",
    "cw_mkt_typeWorkflow": "ワークフロー",
    "cw_mkt_typeArtifact": "アーティファクトテンプレート",
    "cw_mkt_install": "インストール",
    "cw_home_mode_chat": "Chat",
    "cw_home_mode_cowork": "CoWork",
    "cw_home_pick_title": "認可フォルダを選択",
    "cw_home_pick_prompt": "CoWork は認可したフォルダのみアクセスします",
    "cw_home_pick_confirm": "認可",
    "cw_home_no_scoped": "認可フォルダを選択して開始",
    "cw_home_svc_down": "fusion-cowork 未起動（設定 → アップストリームサービス）",
    "cw_home_submit_fail": "送信失敗：",
    "cw_home_bubble_step": "ステップ",
    "cw_home_bubble_done": "完了",
    "cw_home_bubble_error": "エラー",
    "cw_home_bubble_artifact": "成果物",
    "ai_offline_badge": "オフライン",
    "ai_offline_helpOff": "オフラインモード — 詳細を見るにはクリック",
    "ai_offline_helpOn": "オンラインモード",
    "ai_offline_netStatus": "ネットワーク状態",
    "ai_offline_offMode": "オフラインモード",
    "ai_offline_onMode": "オンラインモード",
    "ai_offline_reasonFmt": "原因: %@",
    "ai_offline_disabledTitle": "オフラインモードで利用不可の機能:",
    "ai_offline_featInfer": "モデル推論",
    "ai_offline_featKb": "ナレッジベース照会",
    "ai_offline_featCode": "コード生成",
    "ai_offline_manual": "手動切替",
    "ai_audit_title": "監査ログ",
    "ai_audit_toolPh": "ツール名",
    "ai_audit_typePh": "操作タイプ",
    "ai_audit_sincePh": "開始時刻",
    "ai_audit_sinceHint": "例 2025-01-01",
    "ai_audit_apply": "適用",
    "ai_audit_freq": "ツール呼び出し頻度",
    "ai_audit_empty": "監査ログなし",
    "ai_monitor_title": "モデル負荷モニター",
    "ai_monitor_refreshFmt": "%ds ごとに更新",
    "ai_monitor_manualRefresh": "手動更新",
    "ai_monitor_connected": "MLX 接続済み",
    "ai_monitor_disconnected": "MLX 未接続",
    "ai_monitor_startMlx": "MLX 開始",
    "ai_monitor_availModels": "利用可能モデル",
    "ai_monitor_noModels": "モデルなし",
    "ai_monitor_loaded": "読込済み",
    "ai_monitor_load": "読込",
    "ai_monitor_loadingStatus": "モデル状態読込中...",
    "ai_monitor_errFmt": "モデル状態取得失敗: %@",
    "ai_perm_title": "権限タグ",
    "ai_perm_capsTitle": "機能権限",
    "ai_perm_empty": "権限データなし",
    "ai_perm_agentFmt": "Agent %@",
    "ai_perm_deniedTitle": "FUSION.rules 禁止ツール",
    "ai_perm_toolPh": "ツール名",
    "ai_perm_sensitiveTitle": "機密ファイルパターン",
    "ai_perm_sensitiveTag": "機密",
    "ai_perm_capRead": "ナレッジベース読取",
    "ai_perm_capWrite": "ナレッジベース書込",
    "ai_perm_capDelete": "ナレッジベース削除",
    "ai_perm_capCode": "コード実行",
    "ai_perm_capNet": "ネットワークアクセス",
    "ai_review_title": "Diff レビュー",
    "ai_review_export": "review.md をエクスポート",
    "ai_review_sevCritical": "重大",
    "ai_review_sevWarning": "警告",
    "ai_review_sevInfo": "情報",
    "ai_review_empty": "Diff データなし",
    "ai_review_exportTitle": "review.md をエクスポート",
    "ai_review_copy": "クリップボードにコピー",
    "ai_dash_title": "コンソール概要",
    "ai_dash_subtitle": "Agent 管理コンソール — グローバルダッシュボードとクイックアクセス",
    "ai_dash_statToday": "本日のリクエスト",
    "ai_dash_statToken": "Token 消費",
    "ai_dash_statActive": "アクティブ Agent",
    "ai_dash_statError": "エラーリクエスト",
    "ai_dash_quickTitle": "クイックアクセス",
    "ai_dash_qaCreate": "新規 Agent 作成",
    "ai_dash_qaKb": "新規ナレッジベース",
    "ai_dash_qaConnector": "コネクタ管理",
    "ai_dash_qaApiDoc": "API ドキュメント",
    "ai_dash_recentTitle": "最近の Agent",
    "ai_dash_recentViewAll": "すべて表示",
    "ai_dash_empty": "Agent なし、上部をクリックして作成",
    "ai_dash_alertTitle": "アラート通知",
    "ai_dash_alertEmpty": "すべて正常、アラートなし",
    "ai_dash_alertUnknown": "不明なアラート",
    "ai_list_create": "Agent 作成",
    "ai_list_searchPh": "Agent 名を検索...",
    "ai_list_delTitle": "削除確認",
    "ai_list_delMsgFmt": "Agent「%@」を削除しますか？この操作は取り消せません。",
    "ai_list_filterFmt": "フィルター: %@",
    "ai_list_hName": "Agent 名",
    "ai_list_hStatus": "ステータス",
    "ai_list_hModel": "モデル",
    "ai_list_hKb": "ナレッジベース",
    "ai_list_hUpdated": "最終更新",
    "ai_list_hAction": "操作",
    "ai_list_empty": "Agent なし",
    "ai_list_emptyHint": "「Agent 作成」をクリックして構築開始",
    "ai_list_actDebug": "デバッグ",
    "ai_list_actEdit": "編集",
    "ai_list_actClone": "複製",
    "ai_list_actArchive": "アーカイブ",
    "ai_list_actDelete": "削除",
    "ai_list_scopeAll": "すべて",
    "ai_list_scopeDraft": "下書き",
    "ai_list_scopePublished": "公開済み",
    "ai_list_sortUpdated": "最近の更新",
    "ai_list_sortCreated": "作成日時",
    "ai_list_sortName": "名前",
    "ai_kb_title": "ナレッジベース管理",
    "ai_kb_searchPh": "プロジェクトを検索...",
    "ai_kb_newBtn": "新規プロジェクト",
    "ai_kb_unnamed": "無題",
    "ai_kb_createdFmt": "%@ に作成",
    "ai_kb_detail": "詳細",
    "ai_kb_statusActive": "アクティブ",
    "ai_kb_empty": "ナレッジベースプロジェクトなし",
    "ai_kb_emptyHint": "プロジェクトを作成し、ドキュメントをアップロードして Agent に知識を提供",
    "ai_kb_sheetTitle": "新規ナレッジベースプロジェクト",
    "ai_kb_sheetName": "プロジェクト名",
    "ai_kb_sheetNamePh": "プロジェクト名を入力",
    "ai_kb_sheetDesc": "プロジェクト説明",
    "ai_kb_sheetCreate": "作成",
    "ai_kb_detTitle": "プロジェクト詳細",
    "ai_kb_detTabFiles": "ファイル",
    "ai_kb_detTabInstruction": "指示",
    "ai_kb_detTabAgents": "関連 Agent",
    "ai_kb_filesEmpty": "ファイルなし",
    "ai_kb_artRemove": "削除",
    "ai_kb_instrTitle": "プロジェクト指示",
    "ai_kb_instrSave": "指示を保存",
    "ai_kb_agentsTitle": "このナレッジベースに紐づく Agent",
    "ai_kb_agentsEmpty": "このナレッジベースに紐づく Agent なし",
    "ai_chat_welcomeTitle": "Agent との会話を開始",
    "ai_chat_welcomeHint": "Agent を選択し、メッセージを入力して開始",
    "ai_chat_noAgent": "利用可能な Agent なし、先に作成してください",
    "ai_chat_streaming": "生成中...",
    "ai_chat_qaSummarize": "ドキュメント要約",
    "ai_chat_qaCode": "コード生成",
    "ai_chat_qaData": "データ分析",
    "ai_chat_qaTranslate": "翻訳",
    "ai_chat_qaWrite": "クリエイティブライティング",
    "ai_chat_inputPh": "メッセージを入力...",
    "ai_chat_toolbox": "ツールボックス",
    "ai_chat_toolWebSearch": "ウェブ検索",
    "ai_chat_toolResearch": "深い調査",
    "ai_chat_toolCode": "コード実行",
    "ai_chat_toolKb": "ナレッジベースクエリ",
    "ai_chat_pickTitle": "Agent を選択",
    "ai_chat_pickEmpty": "利用可能な Agent なし",
    "ai_chat_noResponse": "（応答なし）",
    "ai_chat_rtTitle": "ランタイム設定",
    "ai_chat_rtMaxTokens": "最大 Token",
    "ai_chat_rtApply": "現在のセッションに適用",
    "ai_chat_reqFailedFmt": "リクエスト失敗：%@",
    "ai_debug_title": "デバッグパネル",
    "ai_debug_agentFmt": "Agent %@",
    "ai_debug_executing": "実行中",
    "ai_debug_ready": "準備完了",
    "ai_debug_chatEmpty": "メッセージを送信して Agent 応答をテスト",
    "ai_debug_chatEmptyHint": "デバッグモードでは実行ステップとツール呼び出しをリアルタイム表示",
    "ai_debug_inputPh": "テストメッセージを入力...",
    "ai_debug_logsTitle": "現在のセッションログ",
    "ai_debug_loadHistory": "履歴を読み込み",
    "ai_debug_logsEmpty": "実行ログが空です",
    "ai_debug_logsEmptyHint": "テストメッセージ送信後、実行ステップがここに表示されます",
    "ai_debug_tasksEmpty": "コードタスクなし",
    "ai_debug_tasksEmptyHint": "コードを提出して Agent に実行させ結果を確認",
    "ai_debug_lang": "言語",
    "ai_debug_submit": "提出",
    "ai_debug_logReceiveFmt": "ユーザーメッセージ受信：%@",
    "ai_debug_noResponse": "（応答内容なし）",
    "ai_debug_logExecDone": "Agent 実行完了",
    "ai_debug_logToolFmt": "ツール呼び出し：%@",
    "ai_debug_logExecFallback": "Agent 実行完了(fallback)",
    "ai_debug_logFailFmt": "実行失敗：%@",
    "ai_debug_tabChat": "チャットテスト",
    "ai_debug_tabLogs": "実行ログ",
    "ai_debug_tabTasks": "コードタスク",
    "ai_obs_tabUsage": "使用量",
    "ai_obs_tabLogs": "実行ログ",
    "ai_obs_tabApikeys": "APIキー",
    "ai_obs_tabConnectors": "コネクタ",
    "ai_obs_tabPermissions": "権限タグ",
    "ai_obs_tabAudit": "監査ログ",
    "ai_obs_title": "監視と管理",
    "ai_obs_subtitle": "使用量 · 実行ログ · APIキー · コネクタ",
    "ai_obs_statToday": "今日のリクエスト",
    "ai_obs_statToken": "合計トークン",
    "ai_obs_statActive": "アクティブ Agent",
    "ai_obs_statError": "エラー率",
    "ai_obs_alerts": "アラート",
    "ai_obs_logsEmpty": "実行ログなし",
    "ai_obs_apikeysTitle": "APIキー管理",
    "ai_obs_apikeyCreate": "キー作成",
    "ai_obs_apikeysEmpty": "APIキーなし",
    "ai_obs_createdFmt": "作成 %@",
    "ai_obs_rotate": "ローテーション",
    "ai_obs_revoke": "取り消し",
    "ai_obs_connTitle": "外部コネクタ",
    "ai_obs_connAdd": "コネクタ追加",
    "ai_obs_connEmpty": "設定済みコネクタなし",
    "ai_obs_connConnected": "接続済み",
    "ai_obs_connDisconnected": "未接続",
    "ai_obs_connect": "接続",
    "ai_obs_unnamedKey": "無名キー",
    "ai_obs_unnamedConn": "無名",
    "ai_cfg_tabBasic": "基本情報",
    "ai_cfg_tabInstructions": "システム指示",
    "ai_cfg_tabSoul": "人格 Soul",
    "ai_cfg_tabKnowledge": "ナレッジベース",
    "ai_cfg_tabTools": "ツール設定",
    "ai_cfg_tabAdvanced": "詳細パラメータ",
    "ai_cfg_tabPublish": "公開",
    "ai_cfg_skillAddTitle": "スキル追加",
    "ai_cfg_skillNamePh": "スキル名",
    "ai_cfg_skillDescPh": "スキルの説明（任意）",
    "ai_cfg_modeCreate": "新規 Agent 作成",
    "ai_cfg_modeEditFmt": "Agentを編集：%@",
    "ai_cfg_subCreate": "Agentの基本情報・指示・ツール・パラメータを設定",
    "ai_cfg_subEdit": "Agent設定を変更して保存または公開",
    "ai_cfg_nameLabel": "Agent名",
    "ai_cfg_namePh": "Agent名を入力",
    "ai_cfg_descLabel": "概要",
    "ai_cfg_descPh": "Agentの機能と用途を記述",
    "ai_cfg_modelLabel": "モデル選択",
    "ai_cfg_modelPicker": "モデル",
    "ai_cfg_modelChoose": "モデルを選択",
    "ai_cfg_visLabel": "公開範囲",
    "ai_cfg_visPrivate": "非公開",
    "ai_cfg_visOrg": "組織共有",
    "ai_cfg_instrHint": "Agentの基本ロール・行動制約・出力仕様を記述",
    "ai_cfg_charFmt": "%d 文字",
    "ai_cfg_instrSaveTpl": "テンプレート保存",
    "ai_cfg_instrRestore": "履歴を復元",
    "ai_cfg_soulHint": "Agentの人格・話し方・感情の好みを定義",
    "ai_cfg_soulSave": "Soulを保存",
    "ai_cfg_soulAfterCreate": "Agent作成後にSoulを編集可能",
    "ai_cfg_kbLabel": "ナレッジベースProjectを紐付け",
    "ai_cfg_kbAdd": "+ ナレッジベース追加",
    "ai_cfg_ragLabel": "検索戦略",
    "ai_cfg_ragVector": "ベクトル検索",
    "ai_cfg_ragFulltext": "全文検索",
    "ai_cfg_ragHybrid": "ハイブリッド検索",
    "ai_cfg_autoQueryLabel": "自動クエリ",
    "ai_cfg_autoQueryToggle": "Agentが自律的にナレッジベースを検索することを許可",
    "ai_cfg_toolsBuiltin": "組み込みツール",
    "ai_cfg_toolWebSearch": "ウェブ検索",
    "ai_cfg_toolDeepResearch": "ディープリサーチ",
    "ai_cfg_skillsLabel": "スキル Skills",
    "ai_cfg_skillCountFmt": "%d個のスキルを追加",
    "ai_cfg_skillsEmpty": "スキルなし。「スキル追加」をクリックして機能を追加",
    "ai_cfg_skillsAfterCreate": "Agent作成後にスキルを管理可能",
    "ai_cfg_connLabel": "外部コネクタ Connectors",
    "ai_cfg_connEmpty": "認可済みコネクタなし",
    "ai_cfg_connUnknown": "不明",
    "ai_cfg_tempHint": "低=正確 高=創造的",
    "ai_cfg_maxTokenLabel": "最大出力トークン",
    "ai_cfg_ctxLabel": "コンテキストウィンドウ",
    "ai_cfg_styleLabel": "出力スタイル Style",
    "ai_cfg_stylePicker": "スタイル",
    "ai_cfg_styleDefault": "デフォルト",
    "ai_cfg_qpsLabel": "QPS制限",
    "ai_cfg_qpsUnit": "リクエスト/秒",
    "ai_cfg_pubLabel": "公開操作",
    "ai_cfg_pubBtn": "Agentを公開",
    "ai_cfg_pubGetApi": "APIエンドポイントを取得",
    "ai_cfg_pubSaveFirst": "公開前に下書きを保存してください",
    "ai_cfg_summaryTitle": "設定サマリー",
    "ai_cfg_sumName": "名前",
    "ai_cfg_sumModel": "モデル",
    "ai_cfg_sumVis": "公開範囲",
    "ai_cfg_sumKb": "ナレッジベース",
    "ai_cfg_sumKbUnbound": "未紐付け",
    "ai_cfg_sumTools": "ツール",
    "ai_cfg_sumMaxToken": "最大トークン",
    "ai_cfg_sumConnFmt": "%dコネクタ",
    "ai_cfg_sumToolsNone": "無効",
    "ai_cfg_deleteBtn": "Agentを削除",
    "ai_cfg_saveDraft": "下書き保存",
    "fsb_ws_renameAlertTitle": "ワークスペース名変更",
    "fsb_ws_name": "名前",
    "fsb_ws_exportTitle": "ワークスペースをエクスポート",
    "fsb_ws_copyClipboard": "クリップボードにコピー",
    "fsb_ws_emptyWorkspaces": "ワークスペースがありません",
    "fsb_ws_noMatch": "一致するワークスペースがありません",
    "fsb_ws_createWs": "ワークスペース作成",
    "fsb_ws_headerTitle": "FSB ワークベンチ",
    "fsb_ws_newWs": "新規ワークスペース",
    "fsb_ws_listView": "リスト表示",
    "fsb_ws_gridView": "グリッド表示",
    "fsb_ws_searchPh": "ワークスペースを検索...",
    "fsb_unnamed": "無題",
    "fsb_ws_connWfFmt": "%d連·%dフロー",
    "fsb_ws_open": "開く",
    "fsb_ws_rename": "名前変更",
    "fsb_ws_duplicate": "複製",
    "fsb_ws_export": "エクスポート",
    "fsb_ws_subtitle": "クロスSaaSスマート業務ワークベンチ",
    "fsb_ws_serviceDown": "FSBサービス未起動",
    "fsb_ws_usageGuide": "使い方ガイド",
    "fsb_ws_namePh": "例：顧客管理システム",
    "fsb_ws_descOpt": "説明（任意）",
    "fsb_ws_descPh": "ワークスペースの用途を説明",
    "fsb_ws_bindProjectOpt": "プロジェクト連携（任意）",
    "fsb_ws_projectIdPh": "プロジェクトID",
    "fsb_ws_bindAgentOpt": "Agent連携（任意）",
    "fsb_ws_importTemplate": "テンプレートからインポート",
    "fsb_ws_createBtn": "作成",
    "fsb_ws_builtinTemplates": "組み込みテンプレート",
    "fsb_tpl_crm_name": "顧客関係管理",
    "fsb_tpl_crm_short": "CRM",
    "fsb_tpl_crm_desc": "顧客情報・フォローアップ・セールスパイプライン管理",
    "fsb_tpl_inventory_name": "在庫管理",
    "fsb_tpl_inventory_short": "在庫",
    "fsb_tpl_inventory_desc": "商品在庫追跡・補充提醒・出入庫記録",
    "fsb_tpl_finance_name": "財務記帳",
    "fsb_tpl_finance_short": "財務",
    "fsb_tpl_finance_desc": "収支記録・請求書管理・財務レポート生成",
    "fsb_tpl_email_name": "メールマーケティング",
    "fsb_tpl_email_short": "マーケティング",
    "fsb_tpl_email_desc": "メールテンプレート・受众分组・送信スケジュール・効果分析",
    "fsb_tpl_social_name": "ソーシャルメディア管理",
    "fsb_tpl_social_short": "ソーシャル",
    "fsb_tpl_social_desc": "マルチプラットフォーム公開・スケジュール・インタラクション監視・データ分析",
    "fsb_tpl_ticket_name": "チケットシステム",
    "fsb_tpl_ticket_short": "チケット",
    "fsb_tpl_ticket_desc": "顧客チケット・割当・SLA追跡・満足度調査",
    "fsb_ob_welcome_title": "FSBへようこそ",
    "fsb_ob_welcome_desc": "Fusion Small BusinessはクロスSaaSのスマート業務自動化ワークベンチです。\nプログラミング不要、ビジュアルワークフローで業務ツールを連携。",
    "fsb_ob_connectors_title": "コネクタ",
    "fsb_ob_connectors_desc": "既存のSaaSツールを連携：\nGoogle Workspace、Shopify、QuickBooks、Stripeなど。\n読み取りは自動実行、書き込みは承認が必要。",
    "fsb_ob_skills_title": "スキル",
    "fsb_ob_skills_desc": "15以上のスマートスキル内蔵：\nメール要約・データ抽出・レポート生成・翻訳など。\nプロンプトスキルとAPI呼び出しスキルをカスタマイズ可能。",
    "fsb_ob_workflow_title": "ワークフロー",
    "fsb_ob_workflow_desc": "ビジュアルでワークフローを編成：\nドラッグでノードを組みDAG構築、条件分岐、承認ゲート。\nスケジュール・イベント・外部APIトリガー対応。",
    "fsb_ob_start_title": "始める",
    "fsb_ob_start_desc": "ワークスペースを作成、テンプレート選択またはゼロから。\nすべてのデータはローカル実行、プライバシー保護。",
    "fsb_ob_prev": "前へ",
    "fsb_dlg_addConnector": "コネクタ追加",
    "fsb_dlg_connecting": "接続中...",
    "fsb_dlg_connect": "接続",
    "fsb_dlg_selectConnector": "コネクタを選択",
    "fsb_dlg_connector": "コネクタ",
    "fsb_dlg_selectPh": "選択してください...",
    "fsb_dlg_supportFmt": "対応: %@",
    "fsb_dlg_authMethod": "認証方式",
    "fsb_dlg_auth": "認証",
    "fsb_dlg_noAuth": "認証なし",
    "fsb_dlg_enterApiKey": "API Keyを入力",
    "fsb_dlg_scopesHint": "Scopes（カンマ区切り）",
    "fsb_dlg_createSkill": "スキル作成",
    "fsb_dlg_saving": "保存中...",
    "fsb_dlg_create": "作成",
    "fsb_dlg_skillName": "スキル名",
    "fsb_dlg_displayName": "表示名",
    "fsb_dlg_mySkill": "マイスキル",
    "fsb_dlg_type": "タイプ",
    "fsb_dlg_prompt": "プロンプト",
    "fsb_dlg_function": "関数",
    "fsb_dlg_chain": "チェーン",
    "fsb_dlg_definition": "定義",
    "fsb_dlg_inputSchema": "入力 Schema (JSON)",
    "fsb_dlg_outputFormat": "出力フォーマット",
    "fsb_dlg_plainText": "プレーンテキスト",
    "fsb_dlg_setSchedule": "スケジュール設定",
    "fsb_dlg_triggerMethod": "トリガー方式",
    "fsb_dlg_manual": "手動",
    "fsb_dlg_cron": "スケジュール (Cron)",
    "fsb_dlg_eventDriven": "イベント駆動",
    "fsb_dlg_manualOnly": "ワークスペースで手動実行のみ",
    "fsb_dlg_cronExpr": "Cron式",
    "fsb_dlg_commonPresets": "よく使うプリセット",
    "fsb_dlg_preset_weekday9": "平日9時",
    "fsb_dlg_preset_hourly": "毎時",
    "fsb_dlg_preset_daily8": "毎日8時",
    "fsb_dlg_preset_monday9": "毎週月曜9時",
    "fsb_dlg_preset_month1": "毎月1日",
    "fsb_dlg_eventTrigger": "イベントトリガー",
    "fsb_dlg_eventPh": "例: data.updated, order.created",
    "fsb_dlg_eventHint": "対応イベント: データ変更・新規レコード・ステータス更新など",
    "fsb_dlg_approvalRequest": "承認リクエスト",
    "fsb_dlg_requestContent": "リクエスト内容",
    "fsb_dlg_editContent": "編集内容（任意）",
    "fsb_dlg_reject": "拒否",
    "fsb_dlg_processing": "処理中...",
    "fsb_dlg_approve": "承認",
    "fsb_wb_sec_connectors": "コネクタ",
    "fsb_wb_sec_skills": "スキル",
    "fsb_wb_sec_workflows": "ワークフロー",
    "fsb_wb_sec_variables": "変数",
    "fsb_wb_sec_templates": "テンプレート",
    "fsb_wb_tab_approval": "承認待ち",
    "fsb_wb_tab_scheduled": "スケジュール",
    "fsb_wb_tab_history": "実行履歴",
    "fsb_wb_tab_sandbox": "コンテキストサンドボックス",
    "fsb_wb_workspace": "ワークベンチ",
    "fsb_wb_connected": "接続済み",
    "fsb_wb_noConnector": "コネクタなし",
    "fsb_wb_available": "利用可能なコネクタ",
    "fsb_wb_disconnect": "切断",
    "fsb_wb_connect": "接続",
    "fsb_wb_skillList": "スキル一覧",
    "fsb_wb_noSkill": "スキルなし",
    "fsb_wb_test": "テスト",
    "fsb_wb_wfList": "ワークフロー一覧",
    "fsb_wb_noWorkflow": "ワークフローなし",
    "fsb_wb_createWf": "ワークフロー作成",
    "fsb_wb_run": "実行",
    "fsb_wb_schedule": "スケジュール",
    "fsb_wb_variables": "変数",
    "fsb_wb_noVariable": "変数なし",
    "fsb_wb_templates": "テンプレート",
    "fsb_wb_newWf": "新規ワークフロー",
    "fsb_wb_createFirstWf": "最初のワークフローを作成",
    "fsb_wb_nodeCountFmt": "%d ノード",
    "fsb_wb_taskCenter": "タスクセンター",
    "fsb_wb_noApproval": "承認待ちタスクなし",
    "fsb_wb_approvalReq": "承認リクエスト",
    "fsb_wb_approve": "承認",
    "fsb_wb_deny": "拒否",
    "fsb_wb_noScheduled": "スケジュールタスクなし",
    "fsb_wb_noHistory": "実行履歴なし",
    "fsb_wb_inputData": "入力データ",
    "fsb_wb_sandboxVars": "サンドボックス変数",
    "fsb_wb_snapshots": "スナップショット",
    "fsb_wb_sandboxEmpty": "コンテキストサンドボックスが空です",
    "fsb_wb_sandboxHint": "ワークフロー実行後、サンドボックスは\n実行コンテキストとデータスナップショットを記録します",
    "rag_sec_dashboard": "ナレッジベース概要",
    "rag_sec_files": "ファイルディレクトリ管理",
    "rag_sec_chat": "RAG チャット",
    "rag_sec_embedConfig": "埋め込みモデル設定",
    "rag_sec_searchConfig": "検索戦略設定",
    "rag_sec_permissions": "権限管理",
    "rag_sec_vectorOps": "ベクトルDB運用",
    "rag_sec_callLog": "RAG呼び出しログ",
    "rag_sec_benchEval": "検索性能評価",
    "rag_currentKb": "現在のKB",
    "rag_all": "すべて",
    "rag_tab_bases": "ナレッジベース",
    "rag_tab_chat": "チャット",
    "rag_tab_search": "検索",
    "rag_tab_config": "設定",
    "rag_log_title": "RAG呼び出しログ",
    "rag_log_total": "総呼び出し",
    "rag_log_successRate": "成功率",
    "rag_log_avgLatency": "平均遅延",
    "rag_log_search": "検索",
    "rag_log_ask": "Q&A",
    "rag_log_searchPh": "ログを検索...",
    "rag_log_opPicker": "操作",
    "rag_log_export": "CSVエクスポート",
    "rag_log_empty": "呼び出しログなし",
    "rag_log_h_time": "時間",
    "rag_log_h_kb": "KB",
    "rag_log_h_op": "操作",
    "rag_log_h_query": "クエリ",
    "rag_log_h_result": "結果",
    "rag_log_h_latency": "遅延",
    "rag_log_h_status": "ステータス",
    "rag_log_exportTitle": "RAG呼び出しログをエクスポート",
    "rag_log_exportDescFmt": "絞り込んだ %d 件のログをCSVにエクスポート",
    "rag_log_exportBtn": "エクスポート",
    "rag_op_all": "すべて",
    "rag_op_search": "検索",
    "rag_op_ask": "Q&A",
    "rag_op_ingest": "取り込み",
    "rag_op_delete": "削除",
    "rag_op_watch": "監視",
    "rag_op_sync": "同期",
    "rag_perm_title": "権限管理",
    "rag_perm_authStatus": "認証ステータス",
    "rag_perm_apiKeyAuth": "API Key認証",
    "rag_perm_disabled": "無効",
    "rag_perm_enabled": "有効",
    "rag_perm_activeKeys": "有効なキー",
    "rag_perm_keyMgmt": "API Key管理",
    "rag_perm_createKey": "キー作成",
    "rag_perm_noKey": "API Keyなし",
    "rag_perm_noKeyHint": "API Key未設定時は認証無効",
    "rag_perm_h_name": "名前",
    "rag_perm_h_hash": "キーハッシュ",
    "rag_perm_h_createdAt": "作成日時",
    "rag_perm_memberRole": "メンバー役割",
    "rag_perm_role_admin": "管理者",
    "rag_perm_role_admin_desc": "全件読み書き・キー管理・KB削除",
    "rag_perm_role_edit": "編集者",
    "rag_perm_role_edit_desc": "ドキュメント追加・設定編集・再インデックス",
    "rag_perm_role_query": "閲覧者",
    "rag_perm_role_query_desc": "検索・RAG Q&A・読み取り専用",
    "rag_perm_role_api": "API呼び出し",
    "rag_perm_role_api_desc": "API Keyのみ検索/Q&A呼び出し",
    "rag_perm_audit": "監査ログ",
    "rag_perm_auditNote": "上流APIに監査ログAPI未対応、Issue要追跡",
    "rag_perm_createTitle": "API Key作成",
    "rag_perm_keyNamePh": "キー名",
    "rag_perm_keyCreated": "キー作成済み（一度のみ表示）",
    "rag_perm_createBtn": "作成",
    "rag_emb_title": "埋め込みモデル設定",
    "rag_emb_model": "埋め込みモデル",
    "rag_emb_modelName": "モデル名",
    "rag_emb_runMode": "実行方式",
    "rag_emb_localMlx": "ローカルMLX推論",
    "rag_emb_dim768": "768次元",
    "rag_emb_multilang": "多言語",
    "rag_emb_chunkStrategy": "チャンク戦略",
    "rag_emb_strategyPicker": "戦略",
    "rag_emb_chunkSize": "チャンクサイズ",
    "rag_emb_overlap": "オーバーラップ",
    "rag_emb_strategy_semantic": "セマンティック",
    "rag_emb_strategy_fixed": "固定",
    "rag_emb_strategy_code": "コード",
    "rag_emb_strategy_sentence": "文",
    "rag_emb_tip_semantic": "意味境界で分割、自然言語向け",
    "rag_emb_tip_fixed": "固定トークン数、均一コンテンツ向け",
    "rag_emb_tip_code": "AST関数/クラス境界、コード向け",
    "rag_emb_tip_sentence": "文境界で分割、短文向け",
    "rag_emb_context": "コンテキスト強化",
    "rag_emb_contextToggle": "Contextual Retrieval（コンテキスト検索強化）",
    "rag_emb_contextDesc": "チャンクごとにコンテキスト要約を生成し検索精度を向上。Fusion-RAG独自：ローカルMLXで生成、クラウドAPI不要。",
    "rag_emb_saved": "✓ 設定保存済み",
    "rag_emb_reset": "デフォルトに戻す",
    "rag_vec_title": "ベクトルストア運用",
    "rag_vec_syncAlertTitle": "増分同期を確認",
    "rag_vec_syncAlertBtn": "同期",
    "rag_vec_syncAlertMsg": "知識ベースディレクトリに対して増分同期を実行し、ファイル変更を検出して再インデックスします。続行しますか？",
    "rag_vec_createSnapTitle": "バージョンスナップショット作成",
    "rag_vec_snapDescPh": "スナップショットの説明（任意）",
    "rag_vec_create": "作成",
    "rag_vec_svcLabel": "サービス状態",
    "rag_vec_embEngine": "埋め込みエンジン",
    "rag_vec_avail": "利用可能",
    "rag_vec_unavail": "利用不可",
    "rag_vec_kbCount": "知識ベース数",
    "rag_vec_vecStatsLabel": "ベクトル統計",
    "rag_vec_docCount": "ドキュメント数",
    "rag_vec_chunkCount": "チャンク数",
    "rag_vec_vecCount": "ベクトル数",
    "rag_vec_fileCount": "ファイル数",
    "rag_vec_selectKbHint": "まず知識ベースを選択してください",
    "rag_vec_opsLabel": "運用操作",
    "rag_vec_opSync": "増分同期",
    "rag_vec_opSyncDesc": "ファイル変更を検出して再インデックス",
    "rag_vec_opSnap": "スナップショット作成",
    "rag_vec_opSnapDesc": "現在の知識ベース状態をバージョンスナップショットに保存",
    "rag_vec_opHealth": "ヘルスチェック",
    "rag_vec_opHealthDesc": "ベクトルストアと埋め込みサービスの状態を確認",
    "rag_vec_opRefresh": "統計を更新",
    "rag_vec_opRefreshDesc": "知識ベースの統計情報を再取得",
    "rag_vec_snapLabel": "バージョンスナップショット",
    "rag_vec_snapCountFmt": "%d 件のスナップショット",
    "rag_vec_snapEmpty": "スナップショットがありません。「スナップショット作成」をクリックして現在の知識ベース状態を保存してください",
    "rag_vec_snapNote": "バージョンスナップショットは Fusion-RAG が Claude RAG に対する主要な競争優位性です：時点ロールバック、増分比較、データ復元をサポート。",
    "rag_vec_snapFallback": "スナップショット",
    "rag_vec_rollback": "ロールバック",
    "rag_vec_syncing": "同期中...",
    "rag_vec_syncDoneFmt": "✓ 同期完了: %d ファイルを更新",
    "rag_vec_syncFail": "✗ 同期失敗",
    "rag_vec_creatingSnap": "スナップショット作成中...",
    "rag_vec_snapDoneFmt": "✓ スナップショット作成: %@",
    "rag_vec_snapFail": "✗ スナップショット作成失敗",
    "rag_vec_rollingBack": "ロールバック中...",
    "rag_vec_rollbackDoneFmt": "✓ スナップショット %@ にロールバック",
    "rag_vec_rollbackFail": "✗ ロールバック失敗",
    "rag_vec_svcHealthy": "✓ サービス正常",
    "rag_vec_svcUnhealthy": "✗ サービス異常",
    "rag_dash_kbTitle": "知識ベース",
    "rag_dash_newBtn": "新規",
    "rag_dash_svcHealthy": "Fusion-RAG サービス正常",
    "rag_dash_svcUnhealthy": "Fusion-RAG サービス利用不可",
    "rag_dash_kbCountFmt": "%d 件の知識ベース",
    "rag_dash_emptyTitle": "知識ベースがありません",
    "rag_dash_createKb": "知識ベース作成",
    "rag_dash_namePh": "名前",
    "rag_dash_descPh": "説明",
    "rag_dash_chunkStrategyPh": "チャンク戦略",
    "rag_dash_embedModelPh": "埋め込みモデル",
    "rag_dash_create": "作成",
    "rag_dash_scanTitle": "ディレクトリスキャン読み込み",
    "rag_dash_kbPrefix": "知識ベース: %@",
    "rag_dash_dirPathPh": "ディレクトリパス",
    "rag_dash_scanBtn": "スキャン開始",
    "rag_dash_statFile": "ファイル",
    "rag_dash_statChunk": "チャンク",
    "rag_dash_statVec": "ベクトル",
    "rag_dash_enterBtn": "開く",
    "rag_dash_importBtn": "読み込み",
    "rag_dash_chatMenu": "RAG チャット",
    "rag_dash_scanMenu": "ディレクトリスキャン",
    "rag_file_searchPh": "ファイルを検索...",
    "rag_file_watchBtn": "監視",
    "rag_file_addFileBtn": "ファイル追加",
    "rag_file_selectKbHint": "まず知識ベースを選択してください",
    "rag_file_emptyDoc": "ドキュメントがありません",
    "rag_file_h_name": "ファイル名",
    "rag_file_h_type": "種類",
    "rag_file_h_size": "サイズ",
    "rag_file_h_chunk": "チャンク",
    "rag_file_h_status": "状態",
    "rag_file_indexed": "インデックス済み",
    "rag_file_watchLabel": "ファイル監視",
    "rag_file_watchEmpty": "アクティブな監視なし",
    "rag_file_watchFileFmt": "%d 件のファイルを監視",
    "rag_file_changesFmt": "%d 件の変更",
    "rag_file_lastReindexFmt": "最終再構築: %@",
    "rag_file_stopBtn": "停止",
    "rag_file_addFileTitle": "ファイル追加",
    "rag_file_addFilePathPh": "ファイルパス（複数はカンマ区切り）",
    "rag_file_addBtn": "追加",
    "rag_file_watchTitle": "ファイル監視を設定",
    "rag_file_watchPathPh": "ファイルパス（カンマ区切り）",
    "rag_file_pollInterval": "ポーリング間隔(秒)",
    "rag_file_startWatchBtn": "監視開始",
    "rag_srch_title": "検索戦略設定",
    "rag_srch_presetLabel": "シナリオプリセット",
    "rag_srch_preset_general": "汎用",
    "rag_srch_preset_code": "コード",
    "rag_srch_preset_design": "デザイン",
    "rag_srch_presetDesc_general": "汎用：スパース+デンス検索のバランス、ドキュメントQ&Aに適",
    "rag_srch_presetDesc_code": "コード：スパース重みを向上（BM25 関数名の完全一致）、クエリ分解を有効化",
    "rag_srch_presetDesc_design": "デザイン：デンス重みを向上（設計記述の意味理解）、クエリ拡張を有効化",
    "rag_srch_weightLabel": "検索重み",
    "rag_srch_hybridToggle": "ハイブリッド検索（BM25 + ベクトル RRF）",
    "rag_srch_sparseLabel": "スパース検索（BM25）",
    "rag_srch_denseLabel": "デンス検索（ベクトル）",
    "rag_srch_alphaLabel": "ハイブリッド Alpha（RRF 重み）",
    "rag_srch_rerankToggle": "再ランキング（Rerank）",
    "rag_srch_rerankTip": "再ランキングは BGE-Reranker で初期結果を再スコアリングし、Top-5 精度を大幅に向上",
    "rag_srch_paramsLabel": "検索パラメータ",
    "rag_srch_topKLabel": "Top-K 返却数",
    "rag_srch_thresholdLabel": "類似度しきい値",
    "rag_srch_rewriteCard": "クエリ書き換え",
    "rag_srch_rewriteModePicker": "書き換えモード",
    "rag_srch_rewriteDesc_none": "クエリ書き換えなし、元のクエリをそのまま使用",
    "rag_srch_rewriteDesc_expand": "クエリ拡張：同義表現を生成して再現率を向上",
    "rag_srch_rewriteDesc_decompose": "クエリ分解：複雑なクエリをサブ質問に分割して個別検索",
    "rag_srch_rewriteDesc_hyde": "HyDE：まず LLM で仮想的な回答を生成し、その回答で検索",
    "rag_srch_testLabel": "検索テスト",
    "rag_srch_testQueryPh": "テストクエリを入力...",
    "rag_srch_testBtn": "テスト",
    "rag_srch_rw_none": "なし",
    "rag_srch_rw_expand": "拡張",
    "rag_srch_rw_decompose": "分解",
    "rag_srch_rw_hyde": "HyDE",
    "rag_bench_title": "検索性能評価",
    "rag_bench_adv_local": "ローカルオフラインベクトル",
    "rag_bench_adv_ast": "コード AST 解析",
    "rag_bench_adv_rrf": "ハイブリッド検索 RRF",
    "rag_bench_adv_context": "Contextual Retrieval",
    "rag_bench_adv_sync": "増分同期",
    "rag_bench_adv_snap": "バージョンスナップショット",
    "rag_bench_presetLabel": "評価プリセット",
    "rag_bench_preset_standard": "標準評価",
    "rag_bench_preset_code": "コード検索",
    "rag_bench_preset_design": "デザイン検索",
    "rag_bench_customQueryLabel": "カスタム評価セット",
    "rag_bench_customEmpty": "+ をクリックして評価クエリと期待ドキュメントを追加",
    "rag_bench_addQueryTitle": "評価クエリ追加",
    "rag_bench_queryPh": "クエリテキスト",
    "rag_bench_expectedPh": "期待されるドキュメント名",
    "rag_bench_addBtn": "追加",
    "rag_bench_runBtn": "評価実行",
    "rag_bench_hitRateFmt": "Top-5 命中率: %@",
    "rag_bench_clearResultsBtn": "結果を消去",
    "rag_bench_resultsLabel": "評価結果",
    "rag_bench_resultsEmpty": "「評価実行」をクリックして開始",
    "rag_bench_miniHit": "命中",
    "rag_bench_miniLatency": "平均レイテンシ",
    "rag_bench_miniTopScore": "最高スコア",
    "rag_bench_historyLabel": "評価履歴",
    "rag_bench_historyEmpty": "評価履歴がありません",
    "fsb_cv_node_start": "開始",
    "fsb_cv_node_connector": "コネクタ",
    "fsb_cv_node_skill": "スキル",
    "fsb_cv_node_condition": "条件",
    "fsb_cv_node_approval": "承認",
    "fsb_cv_node_output": "出力",
    "fsb_cv_node_end": "終了",
    "fsb_cv_wfName": "ワークフロー名",
    "fsb_cv_autoLayout": "自動レイアウト",
    "fsb_cv_running": "実行中...",
    "fsb_cv_testRun": "テスト実行",
    "fsb_cv_saving": "保存中...",
    "fsb_cv_nodeTypes": "ノードタイプ",
    "fsb_cv_hintDrag": "ヒント：ノードをキャンバスへドラッグ",
    "fsb_cv_hintRightClick": "右クリックでノードを追加",
    "fsb_cv_hintConnect": "ポートをドラッグして接続",
    "fsb_cv_nodeName": "ノード名",
    "fsb_cv_deleteNode": "ノード削除",
    "fsb_cv_connector": "コネクタ",
    "fsb_cv_selectConnector": "コネクタを選択",
    "fsb_cv_notSelected": "未選択",
    "fsb_cv_action": "アクション",
    "fsb_cv_skill": "スキル",
    "fsb_cv_selectSkill": "スキルを選択",
    "fsb_cv_promptTpl": "プロンプトテンプレート",
    "fsb_cv_conditionExpr": "条件式",
    "fsb_cv_conditionHint": "True 分岐は下へ、False 分岐は右へ",
    "fsb_cv_approvalConfig": "承認設定",
    "fsb_cv_approvalMode": "承認モード",
    "fsb_cv_writeOnly": "書き込みのみ (推奨)",
    "fsb_cv_allOps": "すべての操作",
    "fsb_cv_approvalNote": "承認メモ",
    "fsb_cv_timeoutFmt": "タイムアウト: %ds",
    "fsb_cv_outputFormat": "出力形式",
    "fsb_cv_format": "形式",
    "fsb_cv_plainText": "プレーンテキスト",
    "fsb_cv_addNode": "ノード追加",
    "fsb_cv_newWorkflow": "新規ワークフロー",
    "mn_kv_title": "KV キャッシュ",
    "mn_kv_subtitle": "クラスタ KV キャッシュを管理、ヒット率とノード分布を表示",
    "mn_kv_totalEntries": "総エントリ",
    "mn_kv_cacheEntries": "キャッシュエントリ数",
    "mn_kv_totalSize": "総サイズ",
    "mn_kv_cacheSpace": "キャッシュ使用量",
    "mn_kv_hitRate": "ヒット率",
    "mn_kv_hitRateSub": "KV キャッシュヒット",
    "mn_kv_findCache": "キャッシュ検索",
    "mn_kv_searchPh": "モデル名で KV キャッシュを検索...",
    "mn_kv_findBtn": "検索",
    "mn_kv_notFoundFmt": "このモデルの KV キャッシュが見つかりません: %@",
    "mn_kv_hwTitle": "Agent ハードウェア",
    "mn_kv_node": "ノード",
    "mn_kv_memory": "メモリ",
    "mn_kv_device": "デバイス",
    "mn_kv_agentOnline": "Agent オンライン",
    "mn_kv_agentOffline": "Agent オフライン",
    "mn_kv_checking": "確認中...",
    "mn_kv_warmTitle": "KV ウォームアップ",
    "mn_kv_modelName": "モデル名",
    "mn_kv_warmPrompt": "ウォームアッププロンプト",
    "mn_kv_warmBtn": "ウォーム",
    "mn_kv_warmedFmt": "%d 件のキャッシュをウォームアップしました",
    "mn_kv_transferTitle": "KV 転送",
    "mn_kv_targetNode": "宛先ノード ID",
    "mn_kv_transferBtn": "転送",
    "mn_kv_byModelTitle": "モデル別分布",
    "mn_kv_countFmt": "%d 件",
    "mn_task_title": "タスクモニタ",
    "mn_task_subtitle": "タスク実行状態と進捗をリアルタイム追跡",
    "mn_task_tab_all": "すべて",
    "mn_task_tab_running": "実行中",
    "mn_task_tab_completed": "完了",
    "mn_task_tab_failed": "失敗",
    "mn_task_migrateTitle": "タスク移行",
    "mn_task_taskId": "タスク ID",
    "mn_task_targetNode": "宛先ノード",
    "mn_task_selectNode": "選択してください",
    "mn_task_confirmMigrate": "移行を確認",
    "mn_task_total": "総タスク",
    "mn_task_allTasks": "全タスク",
    "mn_task_running": "実行中",
    "mn_task_executing": "実行中",
    "mn_task_failed": "失敗",
    "mn_task_needsAttention": "要対応",
    "mn_task_listTitleFmt": "タスクリスト (%d)",
    "mn_task_searchPh": "タスクを検索...",
    "mn_task_cancelTask": "タスクをキャンセル",
    "mn_task_degradeTask": "タスクを降格",
    "mn_task_migrateTask": "タスクを移行",
    "mn_task_emptyFmt": "%@タスクはありません",
    "mn_sync_title": "クラスタ同期",
    "mn_sync_subtitle": "モデル増分同期とクラスタ分区状態",
    "mn_sync_partitionState": "分区状態",
    "mn_sync_partitionNodes": "分区ノード",
    "mn_sync_isDegraded": "降格状態",
    "mn_sync_degraded": "降格中",
    "mn_sync_normal": "正常",
    "mn_sync_syncAvailable": "同期可否",
    "mn_sync_available": "利用可能",
    "mn_sync_unavailable": "利用不可",
    "mn_sync_incrementalTitle": "増分同期",
    "mn_sync_modelName": "モデル名",
    "mn_sync_modelPh": "例: Qwen2.5-7B-Instruct",
    "mn_sync_sourceHost": "送信元ノード Host",
    "mn_sync_sourcePort": "送信元ポート",
    "mn_sync_syncing": "同期中...",
    "mn_sync_triggerBtn": "同期を開始",
    "mn_sync_manifestTitle": "モデル Manifest",
    "mn_sync_manifestPh": "モデル名で Manifest を表示",
    "mn_sync_viewBtn": "表示",
    "mn_sync_upToDateFmt": "モデル %@ は最新です",
    "mn_sync_syncDoneFmt": "同期完了: %d ファイル更新済み",
    "mn_sync_syncFailFmt": "同期失敗: %@",
    "mn_route_title": "ルーティング戦略",
    "mn_route_subtitle": "クラスタタスクルーティング戦略と負荷分散を設定",
    "mn_route_currentTitle": "現在の戦略",
    "mn_route_strategy": "ルーティング戦略",
    "mn_route_applyBtn": "戦略を適用",
    "mn_route_loadTitle": "ノード負荷分布",
    "mn_route_avgLoad": "平均負荷",
    "mn_route_updatedFmt": "戦略を %@ に更新しました",
    "mn_route_desc_least_loaded": "負荷が最も低いノードを優先",
    "mn_route_desc_round_robin": "各ノードにラウンドロビン割当",
    "mn_route_desc_random": "ノードをランダム選択",
    "mn_route_desc_capability_aware": "ノード能力とタスク要件でマッチング",
    "mn_alert_title": "アラートセンター",
    "mn_alert_subtitle": "クラスタ異常検出とスマート提案",
    "mn_alert_tab_active": "アクティブアラート",
    "mn_alert_tab_suggestions": "スマート提案",
    "mn_alert_tab_history": "アラート履歴",
    "mn_alert_exportBtn": "ログをエクスポート",
    "mn_alert_activeTitleFmt": "アクティブアラート (%d)",
    "mn_alert_activeEmpty": "アクティブアラートなし、クラスタ正常稼働中",
    "mn_alert_suggestTitleFmt": "スマート提案 (%d)",
    "mn_alert_suggestEmpty": "最適化提案なし",
    "mn_alert_historyTitle": "アラート履歴",
    "mn_alert_historyEmpty": "アラート履歴なし",
    "mn_alert_ackBtn": "確認",
    "mn_err_invalidURL": "無効な URL",
    "mn_err_noData": "データが返されませんでした",
    "mn_overview_title": "クラスター概要",
    "mn_overview_subtitle": "クラスターノードの状態とリソースをリアルタイム監視",
    "mn_overview_disconnectedFmt": "Multi-Node サービス未接続 — サービス起動を確認 (port %d)",
    "mn_overview_metricNodes": "ノード",
    "mn_overview_metricTotal": "合計",
    "mn_overview_metricOnline": "オンライン",
    "mn_overview_metricOnlineRun": "オンライン実行",
    "mn_overview_metricActiveTasks": "アクティブタスク",
    "mn_overview_metricExecuting": "実行中",
    "mn_overview_metricClusterMem": "クラスターメモリ",
    "mn_overview_metricTotalMemFmt": "合計 %@GB",
    "mn_overview_submitTaskBtn": "タスク送信",
    "mn_overview_searchPh": "ノードを検索...",
    "mn_overview_nodeListFmt": "ノードリスト (%d)",
    "mn_overview_viewMetrics": "メトリクス表示",
    "mn_overview_removeNode": "ノード削除",
    "mn_overview_degradedFmt": "クラスターは劣化状態 — パーティション: %@",
    "mn_overview_normalFmt": "クラスター同期正常 — パーティション: %@",
    "mn_overview_detailLink": "詳細",
    "mn_submit_title": "タスク送信",
    "mn_submit_subtitle": "クラスタに新しい推論または計算タスクを送信",
    "mn_submit_configTitle": "タスク設定",
    "mn_submit_taskNameLabel": "タスク名",
    "mn_submit_taskNameSub": "タスクを識別するための説明的な名前",
    "mn_submit_taskNamePh": "例: llama-inference-batch",
    "mn_submit_execModeLabel": "実行モード",
    "mn_submit_execModeSub": "pipeline=パイプライン, data_parallel=データ並列, inference=単一ノード推論",
    "mn_submit_modelLabel": "モデル名",
    "mn_submit_modelSub": "対象推論モデル",
    "mn_submit_modelPh": "例: mlx-community/Llama-3.2-1B",
    "mn_submit_priorityLabel": "優先度",
    "mn_submit_prioritySub": "1=最低, 10=最高",
    "mn_submit_capabilityLabel": "必要な能力",
    "mn_submit_capabilitySub": "任意: 例 gpu, high_memory など",
    "mn_submit_capabilityPh": "任意",
    "mn_submit_submitBtn": "送信",
    "mn_submit_successFmt": "タスク送信済み (ID: %@)",
    "mn_node_title": "ノード操作",
    "mn_node_subtitle": "弾力性スケーリング設定とノード管理",
    "mn_node_autoscalerTitle": "Autoscaler 弾力性設定",
    "mn_node_mgmtTitle": "ノード管理",
    "mn_node_removeBtn": "削除",
    "mn_node_emptyNodes": "ノードなし",
    "mn_node_minNodes": "最小ノード",
    "mn_node_maxNodes": "最大ノード",
    "mn_node_scaleUpThreshold": "スケールアップしきい値",
    "mn_node_scaleDownThreshold": "スケールダウンしきい値",
    "mn_node_cooldownLabel": "クールダウン (s)",
    "mn_node_strategyLabel": "戦略",
    "mn_node_applying": "適用中...",
    "mn_node_applyBtn": "設定を適用",
    "mn_node_pendingTitle": "承認待ちノード",
    "mn_node_pendingEmpty": "承認待ちノードなし",
    "mn_node_approveBtn": "承認",
    "mn_node_rejectBtn": "拒否",
    "mn_progress_title": "タスク詳細",
    "mn_progress_subtitle": "タスクの進捗、タイムライン、サブタスク状態を表示",
    "mn_progress_selectTaskTitle": "タスク選択",
    "mn_progress_taskPicker": "タスク",
    "mn_progress_inspectorSelect": "Inspector から選択",
    "mn_progress_loadDetailsBtn": "詳細を読み込み",
    "mn_progress_execProgressTitle": "実行進捗",
    "mn_progress_remainingFmt": "残り %@",
    "mn_progress_timelineTitle": "タイムライン",
    "mn_progress_subTasksFmt": "サブタスク (%d)",
    "mn_progress_emptyHint": "タスクモニターパネルからタスクを選択、または上のドロップダウンから選択",
    "mn_progress_loadFailFmt": "進捗の読み込み失敗: %@",
    "mn_web_title": "サービスパネル",
    "mn_web_subtitle": "WebView で外部サービス画面を埋め込み",
    "mn_web_tab_docs": "Master API",
    "mn_web_tab_bench": "ベンチマーク",
    "mn_web_tab_security": "セキュリティ",
    "mn_web_docsDescFmt": "FastAPI 自動ドキュメント — fusion-multi-node Master サービス起動が必要 (ポート %d)",
    "mn_web_benchDesc": "ベンチマークパネル — fusion-bench bench-site 起動が必要 (ポート 3000, npm run dev)",
    "mn_web_securityDesc": "セキュリティ監査パネル — fusion-security フロントエンド起動が必要 (ポート 3000)",
    "mn_web_connectingFmt": "%@ に接続中...",
    "mn_web_loadFailFmt": "%@ を読み込めません",
    "mn_web_retryBtn": "再試行",
    "mn_topo_title": "トポロジー",
    "mn_topo_subtitle": "Master-Worker 接続関係を可視化",
    "mn_topo_legendOnline": "オンライン",
    "mn_topo_legendBusy": "ビジー",
    "mn_topo_legendOffline": "オフライン",
    "mn_topo_legendFault": "障害",
    "mn_topo_statsFmt": "%d ノード · オンライン率 %d%%",
    "mn_node_statusA11yFmt": "ノード%@",
    "mn_task_degradedFmt": "ダウングレード: %@→%@",
    "design_swiftUITitle": "SwiftUI エクスポート",
    "design_codegenTitle": "コードエクスポート",
    "design_copy": "コピー",
    "design_close": "閉じる",
    "design_helpPageMgmt": "ページ管理",
    "design_helpCopyCode": "コードをコピー (⇧⌘C)",
    "design_helpExportCode": "コードをエクスポート (⇧⌘E)",
    "design_helpClear": "会話をクリア",
    "design_welcomeDesc": "デザインしたい画面を記述すると、AIがインタラクティブなコードを生成します",
    "design_inputPh": "デザインしたい画面を記述...",
    "design_emptyTitle": "デザインしたい画面を記述",
    "design_emptyDesc": "AIがインタラクティブなHTMLコードを生成し、右側にリアルタイムプレビュー",
    "design_clearInput": "入力をクリア",
    "design_clearConv": "会話をクリア",
    "design_copyCurrentCode": "現在のコードをコピー",
    "design_helpSave": "保存",
    "design_helpCopy": "コードをコピー",
    "design_helpHistory": "履歴",
    "design_helpSwiftUI": "SwiftUIをエクスポート",
    "design_helpStop": "停止",
    "design_helpSend": "送信",
    "design_roleUser": "あなた",
    "design_roleDesigner": "デザイナー",
    "design_parsedFmt": "解析済み: %@",
    "design_noVersions": "バージョン履歴なし",
    "design_rollback": "ロールバック",
    "design_errMLXNotRunning": "MLXサービスが実行されていません。MLXパネルでサービスを開始してから送信してください",
    "design_errNoModel": "対話モデルが選択されていません。上部のモデルセレクターでモデルを選択してから送信してください",
    "design_marqueeFmt": "%d 個のノードを選択",
    "design_previewFmt": "プレビュー: %@",
    "design_previewHint": "AI提案の変更、確認後にキャンバスに書き込み",
    "design_reject": "拒否",
    "design_accept": "確認",
    "design_pages": "ページ",
    "design_newPage": "新規ページ",
    "design_noPages": "ページなし、デザイン生成後に自動作成",
    "design_deletePage": "ページを削除",
    "design_batchExport": "一括エクスポート",
    "design_exporting": "エクスポート中...",
    "design_selectFormat": "エクスポート形式を選択",
    "design_skillUseFmt": "%@スキルを使用: %@",
    "design_stepConnecting": "接続中...",
    "design_stepGenerating": "推論中...",
    "design_stepStreaming": "生成中...",
    "design_stepRendering": "キャンバスをレンダリング...",
    "design_stepConnShort": "接続",
    "design_stepGenShort": "推論",
    "design_stepStreamShort": "生成",
    "design_stepRenderShort": "レンダリング",
    "design_grp_pages": "ページ",
    "design_grp_components": "コンポーネント",
    "design_grp_skills": "AIスキル",
    "design_tpl_login": "ログインページ",
    "design_tpl_dashboard": "ダッシュボード",
    "design_tpl_landing": "ランディングページ",
    "design_tpl_settings": "設定ページ",
    "design_tpl_chat": "チャット画面",
    "design_tpl_profile": "プロフィールページ",
    "design_tpl_card": "カードコンポーネント",
    "design_tpl_form": "フォーム",
    "design_tpl_table": "データテーブル",
    "design_tpl_nav": "ナビゲーション",
    "design_tpl_modal": "モーダル/ダイアログ",
    "design_tpl_buttons": "ボタングループ",
    "design_tpl_textToUI": "テキストからUI",
    "design_tpl_imageToUI": "画像からUI",
    "design_tpl_partialEdit": "部分編集",
    "design_tpl_localEdit": "精密編集",
    "design_tpl_simPanel": "類似パネル",
    "design_tpl_multiVariants": "複数バリエーション",
    "design_tpl_specDoc": "仕様書",
    "design_tpl_pageFlow": "ページフロー",
    "design_ds_compLibrary": "コンポーネントライブラリ",
    "design_ds_searchCompPh": "コンポーネントを検索...",
    "design_ds_catAll": "すべて",
    "design_ds_template": "テンプレート",
    "design_ds_sizeSM": "小",
    "design_ds_sizeMD": "中",
    "design_ds_sizeLG": "大",
    "design_ds_cat_button": "ボタン",
    "design_ds_cat_card": "カード",
    "design_ds_cat_input": "入力",
    "design_ds_cat_select": "選択",
    "design_ds_cat_modal": "モーダル",
    "design_ds_cat_nav": "ナビゲーション",
    "design_ds_cat_table": "テーブル",
    "design_ds_cat_chart": "チャート",
    "design_ds_cat_form": "フォーム",
    "design_ds_desc_button": "複数のスタイルバリアントとサイズをサポートするアクションボタンコンポーネント",
    "design_ds_desc_card": "標準/アウトライン/フィーチャースタイルをサポートするコンテンツカードコンポーネント",
    "design_ds_desc_input": "複数の入力タイプをサポートするテキスト入力コンポーネント",
    "design_ds_desc_select": "単一/複数選択をサポートするドロップダウン選択コンポーネント",
    "design_ds_desc_modal": "情報/確認/フォームモードをサポートするモーダルコンポーネント",
    "design_ds_desc_nav": "トップバー/サイドバー/タブをサポートするナビゲーションコンポーネント",
    "design_ds_desc_table": "基本/ソート可能/ページネーションをサポートするデータテーブルコンポーネント",
    "design_ds_desc_chart": "折れ線/棒/円グラフをサポートするチャートコンポーネント",
    "design_ds_desc_form": "ログイン/登録/問い合わせフォームをサポートするフォームコンポーネント",
    "design_lint_title": "リントチェック",
    "design_lint_ruleLock": "ルールロック",
    "design_lint_run": "リント実行",
    "design_lint_genDocFirst": "先に設計ドキュメントを生成してください",
    "design_lint_noResult": "リントが結果を返しませんでした",
    "design_lint_noViolation": "違反なし",
    "design_lint_errCountFmt": "%d エラー",
    "design_lint_warnCountFmt": "%d 警告",
    "design_lint_infoCountFmt": "%d 情報",
    "design_lint_violationCountFmt": "%d 件の違反",
    "design_lint_nodeFmt": "ノード: %@",
    "design_lint_rule_contrastCheck": "コントラストチェック",
    "design_lint_rule_unlabeledInput": "ラベルなし入力",
    "design_lint_rule_textEffects": "テキスト効果",
    "design_lint_rule_abnormalRotation": "異常な回転",
    "design_lint_rule_emptyEffects": "空の効果",
    "design_lint_rule_tokenInconsistency": "Tokenの不一致",
    "design_lint_rule_unnamedNode": "名前なしノード",
    "design_lint_rule_textOverflow": "テキストオーバーフロー",
    "design_lint_rule_overlappingNodes": "ノードの重なり",
    "design_lint_rule_hardcodedSpacing": "ハードコードされたスペーシング",
    "design_lint_rule_hardcodedFontSize": "ハードコードされたフォントサイズ",
    "design_lint_rule_missingInteractionState": "インタラクション状態の欠如",
    "design_lint_rule_layoutInconsistency": "レイアウトの不一致",
    "design_lint_lockTitle": "設計ルールロック",
    "design_lint_done": "完了",
    "design_lint_lockHint": "ロックされたルールはリント時に無視され、違反は表示されません",
    "design_lint_lockedCountFmt": "%d 件のルールがロック済み",
    "design_lint_unlockAll": "すべてロック解除",
    "design_eco_tabSync": "コード同期",
    "design_eco_tabTpl": "テンプレートライブラリ",
    "design_eco_syncToCode": "フォワード同期 → Fusion Code",
    "design_eco_compName": "コンポーネント名",
    "design_eco_syncing": "同期中...",
    "design_eco_syncCode": "コードを同期",
    "design_eco_watchCode": "リバース監視 ← Fusion Code",
    "design_eco_checking": "確認中...",
    "design_eco_checkChange": "変更を確認",
    "design_eco_noMutation": "保留中のスタイル変更なし",
    "design_eco_applyCanvas": "キャンバスに適用",
    "design_eco_saveAsTpl": "現在の設計をテンプレートとして保存",
    "design_eco_tplNamePh": "テンプレート名",
    "design_eco_tplTagsPh": "タグ(カンマ区切り)",
    "design_eco_tplCatPh": "カテゴリ",
    "design_eco_save": "保存",
    "design_eco_searchTpl": "テンプレート検索",
    "design_eco_searchPh": "名前/タグ/カテゴリを検索",
    "design_eco_search": "検索",
    "design_eco_noMatchTpl": "一致するテンプレートなし",
    "design_eco_load": "読み込み",
    "design_eco_syncDone": "コード同期が完了しました",
    "design_eco_syncFailFmt": "同期失敗: %@",
    "design_eco_appliedFmt": "%d 件のスタイル変更を適用",
    "design_eco_tplSavedFmt": "テンプレート '%@' を保存しました",
    "design_eco_tplSaveFailFmt": "テンプレートの保存に失敗: %@",
    "design_eco_tplLoadedFmt": "テンプレート '%@' を読み込みました",
    "design_theme_modeSystem": "システムに従う",
    "design_theme_modeLight": "ライト",
    "design_theme_modeDark": "ダーク",
    "design_theme_modeCustom": "カスタム",
    "design_theme_title": "テーマ切替",
    "design_theme_modeLabel": "外観モード",
    "design_theme_customAccent": "カスタムアクセント",
    "design_theme_accentBlue": "青",
    "design_theme_accentRed": "赤",
    "design_theme_accentGreen": "緑",
    "design_theme_accentOrange": "オレンジ",
    "design_theme_accentPurple": "紫",
    "design_theme_accentPink": "ピンク",
    "design_theme_preview": "プレビュー",
    "design_theme_previewLight": "ライト",
    "design_theme_previewDark": "ダーク",
    "design_theme_reset": "デフォルトにリセット",
    "design_wf_recipe_designToCode": "Design → Code",
    "design_wf_recipe_codeToDesign": "Code → Design",
    "design_wf_recipe_screenshot": "Screenshot → Design → Code",
    "design_wf_recipe_designToCodeDesc": "Design モジュールでデザインを作成しコードファイルへエクスポート",
    "design_wf_recipe_codeToDesignDesc": "既存コードを Design モジュールへ取り込みビジュアル編集",
    "design_wf_recipe_screenshotDesc": "スクリーンショットを撮影し AI でデザイン生成しコードへエクスポート",
    "design_wf_step_createDesign": "デザイン作成",
    "design_wf_step_previewDesign": "デザインプレビュー",
    "design_wf_step_exportToCode": "コードへエクスポート",
    "design_wf_step_openInEditor": "エディタで開く",
    "design_wf_step_selectCodeFile": "コードファイルを選択",
    "design_wf_step_importToDesign": "デザインへ取り込み",
    "design_wf_step_editDesign": "デザイン編集",
    "design_wf_step_syncBack": "ファイルへ同期",
    "design_wf_step_captureScreenshot": "スクリーンショット撮影",
    "design_wf_step_analyzeScreenshot": "スクリーンショット分析",
    "design_wf_step_generateDesign": "デザイン生成",
    "design_wf_startFmt": "ワークフローを開始: %@",
    "design_wf_cancelled": "ワークフローはキャンセルされました",
    "design_wf_doneFmt": "✅ ワークフロー完了: %@",
    "design_wf_execFmt": "実行中: %@",
    "design_wf_ssSaved": "スクリーンショットをクリップボードに保存しました。Design チャットに貼り付けしてください",
    "design_wf_canvasCleared": "キャンバスをクリアしました。チャットでデザインを説明してください",
    "design_wf_previewing": "デザインをプレビュー中...",
    "design_wf_editHint": "チャットで編集内容を説明してください",
    "design_wf_generating": "AI がデザインを生成中...",
    "design_wf_analyzing": "スクリーンショットを分析しデザインを生成中...",
    "design_wf_noScreenshot": "クリップボードにスクリーンショットがありません。先に撮影してください (⌘⇧4)",
    "design_wf_selectCodeFile": "コードファイルを選択",
    "design_wf_selectedFmt": "選択済み: %@",
    "design_wf_notSelected": "ファイルが選択されていません",
    "design_wf_importedFmt": "取り込み済み: %@",
    "design_wf_importedDoc": "ドキュメントを取り込みました",
    "design_wf_noFileSelected": "ファイルが選択されていません。先にコードファイルを選択してください",
    "design_wf_panelTitle": "デザインワークフロー",
    "design_wf_cancelBtn": "ワークフローをキャンセル",
    "design_ins_sec_layout": "レイアウト",
    "design_ins_sec_spacing": "間隔",
    "design_ins_sec_typography": "タイポグラフィ",
    "design_ins_sec_colors": "カラー",
    "design_ins_sec_borders": "ボーダー",
    "design_ins_sec_effects": "エフェクト",
    "design_ins_alignStart": "開始",
    "design_ins_alignCenter": "中央",
    "design_ins_alignEnd": "末尾",
    "design_ins_justifyBetween": "両端揃え",
    "design_ins_justifyAround": "均等配置",
    "design_ins_alignStretch": "伸縮",
    "design_ins_preset_card": "カード",
    "design_ins_preset_button": "ボタン",
    "design_ins_preset_inputField": "入力フィールド",
    "design_ins_preset_navBar": "ナビバー",
    "design_ins_preset_heroSection": "ヒーローセクション",
    "design_ins_title": "スタイルインスペクタ",
    "design_ins_presetLabel": "スタイルプリセット",
    "design_ins_layoutMode": "レイアウトモード",
    "design_ins_direction": "方向",
    "design_ins_mainAxis": "主軸",
    "design_ins_crossAxis": "交差軸",
    "design_ins_width": "幅",
    "design_ins_height": "高さ",
    "design_ins_padding": "パディング",
    "design_ins_margin": "マージン",
    "design_ins_gap": "ギャップ",
    "design_ins_fontFamily": "フォント",
    "design_ins_fontSize": "フォントサイズ",
    "design_ins_fontWeight": "フォントの太さ",
    "design_ins_lineHeight": "行の高さ",
    "design_ins_textAlign": "整列",
    "design_ins_textColor": "文字色",
    "design_ins_bgColor": "背景色",
    "design_ins_borderColor": "ボーダー色",
    "design_ins_borderWidth": "ボーダー幅",
    "design_ins_borderRadius": "角丸",
    "design_ins_opacity": "不透明度",
    "design_ins_shadow": "シャドウ",
    "design_ins_overflow": "オーバーフロー",
    "design_ins_cssOutput": "CSS出力",
    "design_tok_preset_appleHIG": "Apple HIG",
    "design_tok_preset_adminMinimal": "ミニマル管理",
    "design_tok_preset_robotSim": "ロボットシミュレーション",
    "design_tok_cat_colors": "カラー",
    "design_tok_cat_spacing": "間隔",
    "design_tok_cat_typography": "タイポグラフィ",
    "design_tok_cat_radius": "角丸",
    "design_tok_cat_shadows": "シャドウ",
    "design_tok_cat_animation": "アニメーション",
    "design_tok_designSpec": "デザイン仕様",
    "design_cv_menu_duplicate": "ノードを複製",
    "design_cv_menu_delete": "ノードを削除",
    "design_cv_menu_toggleLock": "ロック/ロック解除",
    "design_cv_menu_toggleVisibility": "非表示/表示",
    "design_cv_menu_partialRepaint": "部分再描画",
    "design_cv_menu_bringToFront": "最前面へ",
    "design_cv_menu_sendToBack": "最背面へ",
    "design_cv_menu_selectAll": "すべて選択",
    "design_cv_menu_fitZoom": "ズームをフィット",
    "design_cv_menu_paste": "貼り付け",
    "design_cg_targetLabel": "エクスポート対象",
    "design_cg_componentName": "コンポーネント名",
    "design_cg_generating": "生成中...",
    "design_cg_generate": "コード生成",
    "design_cg_copied": "コピー済み",
    "design_cg_copy": "コピー",
    "design_cg_emptyHint": "エクスポート対象を選択\nクリックしてコード生成",
    "design_cg_charCount": "文字",
    "design_cg_genFailFmt": "コード生成失敗: %@",
    "design_cg_desc_html": "純 HTML + CSS エクスポート",
    "design_cg_desc_react": "React コンポーネント + Tailwind CSS",
    "design_cg_desc_tailwind": "純 Tailwind CSS クラス名",
    "design_cg_desc_swiftui": "SwiftUI View コード",
    "design_ds_title": "デザインシステム",
    "design_ds_refresh": "更新",
    "design_ds_activeFmt": "現在アクティブ: %@",
    "design_ds_applyToCanvas": "キャンバスに適用",
    "design_ds_activateFailFmt": "アクティベート失敗: %@",
    "design_ds_listFailFmt": "デザインシステム一覧の取得に失敗: %@",
    "design_ds_name_appleHIG": "Apple HIG",
    "design_ds_name_adminMinimal": "ミニマル管理",
    "design_ds_name_robotSim": "ロボットシミュレーション",
    "design_ds_desc_appleHIG": "Apple Human Interface Guidelines",
    "design_ds_desc_adminMinimal": "ミニマル風管理",
    "design_ds_desc_robotSim": "産業シミュレーション制御パネル",
    "design_ds_customDesc": "カスタムデザインシステム",
    "design_ly_title": "レイヤー",
    "design_ly_countFmt": "%d 個の要素",
    "design_ly_empty": "レイヤーなし",
    "design_ly_emptyHint": "AIチャットでデザインを生成すると\nここにレイヤーが表示されます",
    "design_avd_exportReview": "レビューをエクスポート",
    "design_ae_multiFormat": "マルチフォーマットエクスポート",
    "design_ae_cancel": "キャンセル",
    "design_ae_exportFmt": "%d 形式をエクスポート",
    "design_cl_conflictFmt": "ファイルとデザインが同時に変更されたため、ファイル版を採用: %@",
    "design_si_selectScreenshot": "スクリーンショットファイルを選択",
    "art_pc_open": "開く",
    "art_pc_copy": "コピー",
    "art_pc_versionHistory": "バージョン履歴",
    "art_pc_share": "共有",
    "art_pc_unpin": "ピン留め解除",
    "art_pc_pin": "ピン留め",
    "art_pc_duplicate": "複製",
    "art_pc_moveToKb": "プロジェクトKBへ移動",
    "art_pc_delete": "削除",
    "art_pc_copySuffix": " (コピー)",
    "art_sd_title": "アーティファクトを共有",
    "art_sd_permission": "権限",
    "art_sd_permView": "閲覧のみ",
    "art_sd_permComment": "コメント可",
    "art_sd_permEdit": "編集可",
    "art_sd_expiry": "有効期限",
    "art_sd_exp1h": "1 時間",
    "art_sd_exp1d": "1 日",
    "art_sd_exp7d": "7 日",
    "art_sd_exp30d": "30 日",
    "art_sd_expNever": "期限なし",
    "art_sd_generate": "共有リンク生成",
    "art_sd_done": "完了",
    "art_sd_shareLink": "共有リンク",
    "art_sd_existingShares": "既存の共有 (%d)",
    "art_sd_expires": "期限: %@",
    "art_sd_revoke": "取り消し",
    "art_tf_tags": "タグ",
    "art_tf_addTag": "タグ追加",
    "art_tf_folders": "フォルダ",
    "art_tf_noFolders": "フォルダがありません",
    "art_vh_rollbackConfirm": "ロールバックを確認？",
    "art_vh_rollback": "ロールバック",
    "art_vh_cancel": "キャンセル",
    "art_vh_rollbackMsg": "バージョン v%d にロールバック、現在のバージョンは名前付きスナップショットとして保存",
    "art_vh_createSnapshot": "スナップショット作成",
    "art_vh_snapshotName": "スナップショット名",
    "art_vh_create": "作成",
    "art_vh_title": "バージョン履歴",
    "art_vh_empty": "バージョン履歴なし",
    "art_vh_current": "現在",
    "art_vh_chars": "%d 文字",
    "art_vh_diffCurrent": "現在のバージョンと比較",
    "art_vh_incremental": "差分変更",
    "art_vh_noDiff": "差分なし",
    "art_vh_diffFail": "差分読込失敗: %@",
    "art_rv_sortUpdated": "最近更新",
    "art_rv_sortCreated": "作成時間",
    "art_rv_sortName": "名称",
    "art_rv_scopeAll": "すべて",
    "art_rv_scopeMine": "自分の",
    "art_rv_scopeStarred": "スター付き",
    "art_rv_scopePinned": "ピン留め",
    "art_rv_subtitle": "グローバルアーティファクトリポジトリ — セッションをまたぐアーティファクト管理",
    "art_rv_newFolder": "新規フォルダ",
    "art_rv_folderName": "フォルダ名",
    "art_rv_create": "作成",
    "art_rv_search": "アーティファクトを検索…",
    "art_rv_typeAll": "すべて",
    "art_rv_recycle": "ごみ箱",
    "art_rv_folders": "フォルダ",
    "art_rv_allArtifacts": "すべてのアーティファクト",
    "art_rv_rename": "名前変更",
    "art_rv_delete": "削除",
    "art_rv_retry": "再試行",
    "art_rv_empty": "アーティファクトなし",
    "art_rv_open": "開く",
    "art_rv_unstar": "スター解除",
    "art_rv_star": "スター",
    "art_rv_copyContent": "内容コピー",
    "art_rv_download": "ダウンロード",
    "art_rv_copy": "複製",
    "art_rv_moveToKb": "プロジェクトKBへ移動",
    "art_rv_loadFail": "読込失敗: %@",
    "art_rb_title": "ごみ箱",
    "art_rb_purge": "期限切れ削除",
    "art_rb_empty": "ごみ箱は空です",
    "art_rb_restore": "復元",
    "art_cv_rename": "名前変更",
    "art_cv_newName": "新しい名前",
    "art_cv_confirm": "確認",
    "art_cv_cancel": "キャンセル",
    "art_cv_deleteConfirm": "削除を確認？",
    "art_cv_delete": "削除",
    "art_cv_deleteMsg": "ごみ箱へ移動、復元可能",
    "art_cv_unsaved": "未保存の変更あり",
    "art_cv_discard": "破棄",
    "art_cv_save": "保存",
    "art_cv_noPreview": "プレビューなし",
    "art_cv_chars": "%d 文字",
    "art_cv_discardChanges": "変更を破棄",
    "art_cv_createSnapshot": "バージョンスナップショット作成",
    "art_cv_snapshotLabel": "スナップショットラベル（任意）",
    "art_cv_create": "作成",
    "art_cv_sections": "%d セクション",
    "art_cv_toc": "目次",
    "desk_tab_templates": "テンプレート",
    "desk_tab_workflows": "ワークフロー",
    "desk_tab_agents": "エージェント",
    "desk_tab_sessions": "セッション",
    "desk_tab_permissions": "権限",
    "desk_tab_mlx": "MLX",
    "desk_tab_system": "システム",
    "desk_tab_events": "イベント",
    "desk_close": "閉じる",
    "desk_loading": "読み込み中...",
    "desk_name": "名称",
    "desk_category": "分類",
    "desk_description": "説明",
    "desk_create": "作成",
    "desk_cancel": "キャンセル",
    "desk_save": "保存",
    "desk_edit": "編集",
    "desk_delete": "削除",
    "desk_status": "ステータス",
    "desk_refresh": "更新",
    "desk_svc_notConnected": "Fusion-CoWork サービス未接続",
    "desk_svc_notConnectedHint": "fusion-cowork サービスを起動して再試行してください（ターミナルで ./start.sh start を実行、または 設定→アップストリームサービス で起動）",
    "desk_reconnect": "再接続",
    "desk_svc_notReady": "サービス未準備",
    "desk_searchTemplates": "テンプレートを検索...",
    "desk_tpl_count": "%d テンプレート",
    "desk_noTemplates": "テンプレートなし",
    "desk_tpl_detail": "テンプレート詳細",
    "desk_steps": "手順",
    "desk_tpl_runResult": "テンプレート %@: %@",
    "desk_tpl_runFail": "テンプレート %@: 実行失敗",
    "desk_wf_promptPlaceholder": "自然言語でワークフローを作成...",
    "desk_wf_count": "%d ワークフロー",
    "desk_wf_execStatus": "実行状態",
    "desk_noWorkflows": "ワークフローなし、プロンプトを入力して作成",
    "desk_wf_execStatusTitle": "ワークフロー実行状態",
    "desk_wf_noRunning": "実行中のワークフローなし",
    "desk_wf_currentNode": "現在のノード: %@",
    "desk_agent_taskPlaceholder": "エージェントにタスクを送信...",
    "desk_submit": "送信",
    "desk_agent_count": "%d エージェント",
    "desk_noAgents": "エージェントなし",
    "desk_agent_id": "ID: %@",
    "desk_agent_taskSubmitted": "タスク %@ 送信済み",
    "desk_agent_viewStatus": "ステータスを表示",
    "desk_agent_status": "ステータス: %@",
    "desk_agent_progress": "進捗: %@",
    "desk_session_new": "新規セッション",
    "desk_session_count": "%d セッション",
    "desk_noSessions": "セッションなし",
    "desk_session_steps": "手順: %d",
    "desk_session_fork": "分岐",
    "desk_session_edit": "セッションを編集",
    "desk_session_namePlaceholder": "セッション名",
    "desk_session_detail": "セッション詳細",
    "desk_session_stepCount": "手順数",
    "desk_perm_rules": "権限ルール",
    "desk_perm_checkTool": "ツールを確認",
    "desk_perm_check": "確認",
    "desk_perm_resetAll": "すべてリセット",
    "desk_perm_checkResult": "ツール %@: %@",
    "desk_perm_allowed": "許可",
    "desk_perm_denied": "拒否",
    "desk_perm_noRules": "権限ルールなし",
    "desk_perm_scope": "範囲: %@",
    "desk_perm_toggle": "切り替え",
    "desk_mlx_status": "Fusion-MLX ステータス",
    "desk_mlx_running": "実行中",
    "desk_mlx_stopped": "停止",
    "desk_mlx_noModels": "モデルなし",
    "desk_mlx_modelList": "モデルリスト",
    "desk_mlx_modelCount": "%d モ델",
    "desk_mlx_runningTitle": "Fusion-MLX 実行中",
    "desk_mlx_stoppedTitle": "Fusion-MLX 未起動",
    "desk_mlx_manageHint": "UpstreamServiceManager で MLX ライフサイクルを管理",
    "desk_sys_info": "システム情報",
    "desk_sys_platform": "プラットフォーム",
    "desk_sys_cpuCores": "CPU コア数",
    "desk_sys_memoryTotal": "メモリ合計",
    "desk_sys_memoryUsed": "メモリ使用量",
    "desk_sys_diskFree": "ディスク空き",
    "desk_sys_nodeCategories": "ノード分類",
    "desk_sys_nodeList": "ノードリスト",
    "desk_sys_loading": "システム情報読み込み中...",
    "desk_sys_nodeDetail": "ノード詳細",
    "desk_sys_inputs": "入力パラメータ",
    "desk_sys_outputs": "出力",
    "desk_evt_stream": "イベントストリーム",
    "desk_evt_polling": "ポーリング中",
    "desk_evt_subscribed": "購読済み",
    "desk_evt_count": "%d イベント",
    "desk_evt_stopPoll": "ポーリング停止",
    "desk_evt_startPoll": "ポーリング開始",
    "desk_noEvents": "イベントなし",
    "desk_evt_source": "送信元: %@",
    "dy_tab_inventory": "在庫",
    "dy_tab_produce": "製作",
    "dy_tab_publish": "公開",
    "dy_tab_plan": "スケジュール",
    "dy_tab_comment": "コメント",
    "dy_tab_evolve": "進化",
    "dy_tab_stats": "統計",
    "dy_queue_pending": "公開待ち",
    "dy_queue_published": "公開済み",
    "dy_queue_failed": "失敗",
    "dy_queue_refresh": "更新",
    "dy_inv_pending_queue": "公開待ちキュー",
    "dy_inv_pending_empty": "公開待ち動画なし。「製作」で在庫補充。",
    "dy_inv_published_recent": "公開済み（直近20件）",
    "dy_inv_published_empty": "公開済み動画なし",
    "dy_inv_failed_queue": "失敗キュー",
    "dy_inv_variant_label": "variant %@",
    "dy_prod_title": "ワンクリック製作",
    "dy_prod_desc": "agent-studio で Graph C（script→img→tts→compose→enqueue）を実行し、1本を公開待ちキューへ。",
    "dy_prod_topic_label": "お題（空欄で topic_gen 自動生成）",
    "dy_prod_topic_ph": "例：ブラックホールに落ちたらどうなる？",
    "dy_prod_variant_label": "フックバリアント",
    "dy_prod_hint_a": "%@：数字+逆説 — 冒頭に極端な数字と逆説的結論",
    "dy_prod_hint_b": "%@：質問+没入 — 冒頭に二人称の質問で視聴者を引き込む",
    "dy_prod_hint_c": "%@：サスペンス+葛藤 — 冒頭に未解決のサスペンス葛藤",
    "dy_prod_start": "製作開始",
    "dy_pub_title": "在庫公開",
    "dy_pub_desc": "agent-studio で Graph D（dequeue→gate_stock→publish→archive）を実行し、公開待ちキューから1件を公開。",
    "dy_pub_dryrun_toggle": "Dry-run（実際に公開せず、公開直前で停止）",
    "dy_pub_dryrun_btn": "Dry-run 公開",
    "dy_pub_real_btn": "本番公開",
    "dy_pub_real_warn": "⚠️ 本番公開は動画を抖音アカウントへアップロードします。在庫とログイン状態を確認。",
    "dy_plan_title": "ピーク時間公開スケジュール",
    "dy_plan_desc": "cron 計画を登録し、毎日ピーク帯（12-13 / 19-21）に Graph D を自動実行して在庫から公開。手動不要。基盤は agent-studio cron ランタイム（PR #140）。",
    "dy_plan_expr_label": "Cron 式（分 時 日 月 曜）",
    "dy_plan_expr_default": "デフォルト `5 12,19 * * *` = 毎日 12:05 と 19:05 に各1回トリガー（ピーク帯開始5分後）。",
    "dy_plan_dryrun_toggle": "Dry-run（実際に公開せず、トリガー検証）",
    "dy_plan_real_warn": "⚠️ 本番計画はピーク帯に自動で動画を抖音へアップロードします。在庫とログイン状態を確認。",
    "dy_plan_register": "計画登録",
    "dy_plan_refresh": "更新",
    "dy_plan_empty": "公開計画なし。登録後、次回トリガー時刻と実行履歴がここに表示。",
    "dy_plan_registered": "登録済み計画",
    "dy_plan_history": "実行履歴",
    "dy_cron_next": "次回: %@",
    "dy_cron_last": "前回: %@",
    "dy_cron_params": "パラメータ: %@",
    "dy_cron_cancel": "計画キャンセル",
    "dy_comment_title": "コメント返信",
    "dy_comment_desc": "agent-studio で Graph B（fetch→gate→draft→reply）を実行し、新着コメントを取得して一括返信。冪等。",
    "dy_comment_start": "コメント返信開始",
    "dy_comment_replied_title": "返信済みコメント ID",
    "dy_evolve_title": "進化分析",
    "dy_evolve_desc": "agent-studio で Graph E（snapshot→rank→analyze→repair_scan）を実行し、バズりパターン更新と失敗動画スキャン。",
    "dy_evolve_run": "進化ループ実行",
    "dy_evolve_repair_title": "失敗動画修復・再送",
    "dy_evolve_repair_desc": "agent-studio で Graph F（scan→gate→retitle）を実行し、失敗動画のタイトル変更・再キュー投入。",
    "dy_evolve_repair_scan": "スキャン＆修復",
    "dy_win_title": "バズりパターン（winning_patterns）",
    "dy_win_summary": "サンプル %d · バズり %d · 更新 %@",
    "dy_win_title_formula": "タイトル公式",
    "dy_win_hot_topic": "✅ バズりお題",
    "dy_win_hot_hook": "✅ バズりフック",
    "dy_win_lose": "❌ 失敗パターン",
    "dy_stats_title": "統計レポート · 全貌",
    "dy_stats_desc": "アカウント全体パフォーマンス概要：集計指標 + パフォーマンス分布 + フックバリアント比較。",
    "dy_stats_empty": "統計スナップショットなし。先に「進化分析」を実行してスナップショット取得。",
    "dy_stats_detail_title": "動画別詳細（再生降順、優秀優先）",
    "dy_stats_total_plays": "総再生",
    "dy_stats_total_likes": "総いいね",
    "dy_stats_total_comments": "総コメント",
    "dy_stats_total_shares": "総シェア",
    "dy_stats_count": "作品数",
    "dy_stats_avg_plays": "平均再生",
    "dy_stats_avg_ir": "平均互動率",
    "dy_stats_hot_count": "バズり数",
    "dy_stats_dist_hot": "バズり %d",
    "dy_stats_dist_mid": "安定 %d",
    "dy_stats_dist_cold": "失敗 %d",
    "dy_stats_variant_dist": "フックバリアント サンプル分布",
    "dy_stats_variant_count": "%@：%d件",
    "dy_stats_row_plays": "再生 %d",
    "dy_stats_row_likes": "いいね %d",
    "dy_stats_row_comments": "コメント %d",
    "dy_stats_row_shares": "シェア %d",
    "dy_stats_row_ir": "互動率 %.2f%%",
    "dy_action_running": "実行中…",
    "dy_action_produce": "製作中",
    "dy_action_publish": "公開中",
    "dy_action_comment_reply": "コメント返信",
    "dy_action_evolve": "進化分析",
    "dy_action_repair": "失敗動画修復",
    "dy_err_ops_not_found": "見つかりません: %@。fusion-operation が実行済みで out/ データがあるか確認。",
    "dy_err_ipc_disconnected": "IPC 未接続。agent-studio を呼び出せません。",
    "dy_err_ipc_register": "IPC 未接続。公開計画を登録できません。",
    "dy_res_done": "実行完了、%d イベント",
    "dy_res_status": "実行ステータス: %@",
    "dy_res_plan_registered": "公開計画を登録しました。ピーク帯の自動トリガーを待機。",
    "dy_res_register_failed": "登録失敗",
    "dy_err_rungraph": "runGraph %@ 失敗: %@",
    "dy_err_graph_missing": "Graph ファイルなし: %@",
    "dy_err_graph_parse": "Graph JSON 解析失敗: %@",
    "dy_err_graph_no_id": "graph.create が graph_id を返しませんでした",
    "dy_err_register": "公開計画登録失敗: %@",
    "dy_err_unregister": "計画キャンセル失敗: %@",
    "dy_cron_name": "抖音ピーク時間公開計画",
    "fc_mode_ask": "Ask",
    "fc_mode_auto": "Auto",
    "fc_mode_plan": "Plan",
    "fc_layout_four_column": "4列",
    "fc_layout_three_column": "3列",
    "fc_layout_two_column": "2列",
    "fc_layout_chat_only": "チャットのみ",
    "fc_pane_editor": "エディタ",
    "fc_pane_diff": "差分",
    "fc_pane_preview": "プレビュー",
    "fc_pane_terminal": "ターミナル",
    "fc_pane_snapshot": "スナップショット",
    "fc_pane_workflow": "ワークフロー",
    "fc_pane_sandbox": "サンドボックス",
    "fc_cmd_help": "利用可能なコマンドを表示",
    "fc_cmd_clear": "会話をクリア",
    "fc_cmd_compact": "会話コンテキストを圧縮",
    "fc_cmd_model": "モデル切替",
    "fc_cmd_kb": "ナレッジベース照会",
    "fc_cmd_memory": "プロジェクトメモリ管理",
    "fc_cmd_template": "ワークフローテンプレート適用",
    "fc_cmd_init": "プロジェクトコンテキスト初期化",
    "fc_cmd_review": "現在の変更をレビュー",
    "fc_cmd_test": "テスト生成・実行",
    "fc_cmd_deploy": "プロジェクトデプロイ",
    "fc_cmd_explain": "コード解説",
    "fc_cmd_refactor": "コードリファクタ",
    "fc_cmd_debug": "問題デバッグ",
    "fc_no_project_title": "プロジェクトフォルダを開く",
    "fc_open_folder": "フォルダを開く",
    "fc_offline_mlx": "fusion-code オフライン — MLX 推論を使用",
    "fc_thinking": "思考中...",
    "fc_connected": "接続済み",
    "fc_offline": "オフライン",
    "fc_hide_session_bar": "セッションバーを非表示",
    "fc_show_session_bar": "セッションバーを表示",
    "fc_greeting_morning": "おはようございます",
    "fc_greeting_afternoon": "こんにちは",
    "fc_greeting_evening": "こんばんは",
    "fc_greeting_night": "おやすみなさい",
    "fc_welcome_subtitle": "Fusion Code — ローカル AI コーディングアシスタント",
    "fc_card_open_title": "プロジェクトを開く",
    "fc_card_open_sub": "ローカルフォルダから開始",
    "fc_card_code_title": "コード",
    "fc_card_code_sub": "コード生成・編集",
    "fc_card_debug_title": "デバッグ",
    "fc_card_debug_sub": "問題を発見・修正",
    "fc_card_kb_title": "KB 照会",
    "fc_card_kb_sub": "コードベースに質問",
    "fc_card_memory_title": "メモリ",
    "fc_card_memory_sub": "コンテキスト管理",
    "fc_card_template_title": "テンプレート",
    "fc_card_template_sub": "ワークフローテンプレート",
    "fc_card_review_title": "レビュー",
    "fc_card_review_sub": "コードレビュー",
    "fc_card_test_title": "テスト",
    "fc_card_test_sub": "テスト生成",
    "fc_prompt_write": "書いて: ",
    "fc_prompt_debug": "この問題をデバッグして",
    "fc_add_folder": "フォルダを追加",
    "fc_add_file": "ファイルを追加",
    "fc_query_kb": "KB 照会",
    "fc_templates": "テンプレート",
    "fc_web_search": "ウェブ検索",
    "fc_input_placeholder": "何でも聞いて — / でコマンド...",
    "fc_select_file_edit": "編集するファイルを選択",
    "fc_select_session_snapshot": "スナップショット表示するセッションを選択",
    "fc_undo": "元に戻す",
    "fc_save": "保存",
    "fc_project_context": "プロジェクトコンテキスト",
    "fc_ctx_project": "プロジェクト",
    "fc_ctx_branch": "ブランチ",
    "fc_ctx_files": "ファイル",
    "fc_ctx_model": "モデル",
    "fc_ctx_mode": "モード",
    "fc_ctx_kb": "KB",
    "fc_not_selected": "未選択",
    "fc_no_project_open": "プロジェクト未開",
    "fc_project_memory": "プロジェクトメモリ",
    "fc_load_memory": "メモリファイル読込",
    "fc_write_memory": "メモリ書込",
    "fc_sessions": "セッション",
    "fc_no_sessions": "セッションなし",
    "fc_messages_count": "%d 件のメッセージ",
    "fc_workflow_templates": "ワークフローテンプレート",
    "fc_tpl_review": "コードレビュー",
    "fc_tpl_test": "テスト生成",
    "fc_tpl_debug": "問題デバッグ",
    "fc_tpl_refactor": "リファクタ",
    "fc_tpl_explain": "コード解説",
    "fc_tpl_deploy": "デプロイ",
    "fc_msg_model_switched": "モデル切替: %@",
    "fc_msg_current_model": "現在のモデル: %@",
    "fc_msg_context_compacted": "コンテキスト圧縮済み",
    "fc_msg_unknown_cmd": "不明なコマンド: %@。/help で利用可能なコマンドを確認。",
    "fc_msg_kb_usage": "使い方: /kb <クエリ>",
    "fc_msg_no_project_open": "プロジェクト未開。先にフォルダを開いてください。",
    "fc_msg_kb_no_results": "結果なし: %@",
    "fc_msg_kb_results": "KB 結果:\n\n%@",
    "fc_msg_kb_failed": "KB 照会失敗: %@",
    "fc_msg_no_project": "プロジェクト未開。",
    "fc_msg_no_memory": "メモリファイルなし。",
    "fc_msg_memory_files": "メモリファイル:\n%@",
    "fc_msg_memory_failed": "メモリ読込失敗: %@",
    "fc_kb_building": "KB: 構築中...",
    "fc_kb_build_failed": "KB: 構築失敗",
    "fc_tool_edit": "ファイル編集: %@",
    "fc_tool_write": "ファイル書込: %@",
    "fc_tool_run": "実行: %@",
    "fc_tool_multi_edit": "複数ファイル編集",
    "fc_denied_by_user": "ユーザーにより拒否",
    "fc_approve": "承認",
    "fc_deny": "拒否",
    "fc_apply_code": "コード適用",
    "fc_apply_code_n": "コード適用 #%d",
    "fc_status_pending": "保留中",
    "fc_status_running": "実行中",
    "fc_status_approved": "承認済み",
    "fc_status_denied": "拒否済み",
    "fc_status_completed": "完了",
    "fc_status_failed": "失敗",
    "fc_code": "コード",
    "fc_copied": "コピー済み",
    "fc_copy": "コピー",
    "fc_no_matching_commands": "一致するコマンドなし",
    "fc_new_session": "新規セッション",
    "fc_title": "タイトル",
    "fc_session_title_ph": "セッションタイトル",
    "fc_cancel": "キャンセル",
    "fc_create": "作成",
    "fc_permission_request": "権限リクエスト",
    "fc_tool_label": "ツール:",
    "fc_open_project_folder": "プロジェクトフォルダを開く",
    "fc_open_file": "ファイルを開く",
    "fc_scanning": "スキャン中 %@...",
    "fc_loaded_files": "%d ファイル読込済み",
    "fc_loading": "読込中 %@...",
    "fc_loaded_one_file": "1 ファイル読込済み",
    "fc_load_failed": "読込失敗: %@",
    "fc_scanning_n": "スキャン %d/%d...",
    "fc_ai_unavailable": "AI サービスは一時的に利用できません。後で再試行してください。",
    "fc_sidebar_chat": "チャット",
    "fc_sidebar_files": "ファイル",
    "fc_sidebar_git": "Git",
    "fc_sidebar_design": "デザイン",
    "fc_toggle_sidebar": "サイドバー切替",
    "fc_input_ask_anything": "何でも聞いて — code, explain, debug, refactor...",
    "fc_attach_file": "ファイル添付",
    "fc_menu_add_folder": "フォルダを追加...",
    "fc_menu_add_file": "ファイルを追加...",
    "fc_menu_add_github": "GitHub リポジトリを追加...",
    "fc_git_url_detected": "Git リポジトリ URL を検出",
    "fc_send": "送信",
    "fc_open_project": "プロジェクトを開く",
    "fc_local_folder": "ローカルフォルダ",
    "fc_local_folder_desc": "ローカルフォルダを選択、コードファイルを自動スキャン",
    "fc_choose": "選択...",
    "fc_single_file": "単一ファイル",
    "fc_single_file_desc": "単一ファイルを開いて編集・AI 支援",
    "fc_github_repo": "GitHub リポジトリ",
    "fc_github_repo_desc": "リモートリポジトリをローカルへクローン",
    "fc_url": "URL",
    "fc_branch": "ブランチ",
    "fc_clone_open": "クローンして開く",
    "fc_or": "または",
    "fc_drop_here": "ファイルやフォルダをここにドロップ",
    "fc_search_conversations": "会話を検索...",
    "fc_no_conversations": "会話なし",
    "fc_files_count": "%d ファイル",
    "fc_close_project": "プロジェクトを閉じる",
    "fc_open_another": "別のプロジェクトを開く",
    "fc_search_files": "ファイルを検索...",
    "fc_open_folder_browse": "フォルダを開いてファイル閲覧",
    "fc_show_in_finder": "Finder で表示",
    "fc_copy_path": "パスをコピー",
    "fc_remove_context": "コンテキストから削除",
    "fc_add_to_context": "コンテキストに追加",
    "fc_add_to_kb": "ナレッジベースに追加",
    "fc_index_to_rag": "RAG にインデックス",
    "fc_add_dir_to_kb": "ディレクトリをナレッジベースに追加",
    "fc_not_git_repo": "git リポジトリではありません",
    "fc_open_for_git": "プロジェクトを開いて Git ステータス表示",
    "fc_no_changes": "変更なし",
    "fc_welcome_title": "Fusion Code — AI コーディングアシスタント",
    "fc_welcome_tagline": "Claude Code 互換 · fusion-mlx 駆動",
    "fc_wc_open_title": "プロジェクトを開く",
    "fc_wc_open_desc": "ローカル/Git コード読込",
    "fc_wc_explain_title": "解説",
    "fc_wc_explain_desc": "コード機能を解説",
    "fc_wc_review_title": "レビュー",
    "fc_wc_review_desc": "コードの欠陥を検出",
    "fc_wc_test_title": "テスト",
    "fc_wc_test_desc": "ユニットテスト生成",
    "fc_recent": "最近開いた",
    "fc_min_ago": "%d 分前",
    "fc_hour_ago": "%d 時間前",
    "fc_day_ago": "%d 日前",
    "fc_term_banner": "Fusion Studio ターミナル v1.0",
    "fc_term_help_hint": "'help' で利用可能なコマンドを表示",
    "fc_terminal": "ターミナル",
    "fc_clear": "クリア",
    "fc_term_commands": "コマンド: help, clear, status, mlx, python, swift",
    "fc_term_unknown": "不明: %@。'help' と入力",
    "fc_you": "あなた",
    "fc_clone": "クローン",
    "fc_group_mode": "グループ",
    "fc_search_sessions": "セッション検索...",
    "fc_no_project2": "プロジェクト無",
    "fc_rename": "名前変更",
    "fc_pause": "一時停止",
    "fc_resume": "再開",
    "fc_delete": "削除",
    "fc_layout_mode": "レイアウト",
    "fc_sessions_count": "%d セッション",
    "fc_new_session_full": "新規コーディングセッション",
    "fc_working_dir": "作業ディレクトリ",
    "fc_model_label": "モデル",
    "fc_security_mode": "セキュリティモード",
    "fc_sm_readonly": "読み取り専用",
    "fc_sm_manual": "手動承認",
    "fc_sm_auto": "自動",
    "fc_gm_by_project": "プロジェクト別",
    "fc_gm_by_state": "状態別",
    "fc_gm_flat": "フラット",
    "fc_state_idle": "アイドル",
    "fc_state_running": "実行中",
    "fc_state_waiting": "承認待ち",
    "fc_state_paused": "一時停止中",
    "fc_state_completed": "完了",
    "fc_state_failed": "異常",
    "fc_state_cluster": "クラスター実行中",
    "fc_sm_auto_full": "自動承認",
    "fc_policy": "ポリシー",
    "fc_audit": "監査",
    "fc_allow_dirs": "許可ディレクトリ",
    "fc_add_dir_ph": "ディレクトリ追加...",
    "fc_add": "追加",
    "fc_ignore_patterns": "無視パターン (.fusionignore)",
    "fc_add_pattern_ph": "パターン追加...",
    "fc_no_audit": "監査記録なし",
    "fc_records_count": "%d 件",
    "fc_export": "エクスポート",
    "fc_wf_empty_desc": "複雑なタスクを自動化するワークフローを作成",
    "fc_wf_new": "新規ワークフロー",
    "fc_wf_goal_ph": "目標説明",
    "fc_wf_select_template": "テンプレート選択",
    "fc_wf_template_generic": "汎用タスク分解",
    "fc_wf_template_legacy": "レガシー移行",
    "fc_wf_template_security": "セキュリティスキャン監査",
    "fc_wf_template_batch": "バッチAPI処理",
    "fc_wf_template_refactor": "リファクタリング",
    "fc_wf_template_test": "テスト生成",
    "fc_wf_status_failed": "%d 失敗",
    "fc_wf_status_running": "実行中 (%d/%d)",
    "fc_wf_status_completed": "完了",
    "fc_wf_status_pending": "保留中 (%d/%d)",
    "fc_preview": "プレビュー",
    "fc_live": "ライブ",
    "fc_html_preview_empty": "HTML生成後にここにプレビューが表示されます",
    "fc_original": "オリジナル",
    "fc_modified": "変更後",
    "fc_design_open_in_module": "Design モジュールで開く",
    "fc_design_no_content": "デザインコンテンツがありません",
    "fc_design_create_hint": "Design モジュールでデザインを作成後\nここでプレビューできます",
    "fc_design_sync_on": "双方向同期が有効",
    "fc_design_sync_off": "同期未接続",
    "fc_design_export_file": "ファイルへエクスポート",
    "fc_tier_global": "グローバル",
    "fc_tier_project": "プロジェクト",
    "fc_tier_directory": "ディレクトリ",
    "fc_diff_split": "分割",
    "fc_diff_unified": "統合",
    "fc_diff_line_numbers": "行番号",
    "fc_snapshots": "スナップショット",
    "fc_no_snapshots": "スナップショットなし",
    "fc_create_snapshot": "スナップショットを作成",
    "fc_label_optional": "ラベル（任意）",
    "fc_restore": "復元",
    "fc_rewind_here": "ここまで巻き戻し",
    "fc_snap_deltas_fmt": "%d 個のデルタ · %@",
    "fc_snap_not_found": "スナップショットが見つかりません：%@",
    "fc_pty_stopped": "停止",
    "fc_pty_clear": "クリア",
    "fc_pty_stop": "停止",
    "fc_pty_restart": "再起動",
    "fc_pty_shell_started": "Shellを開始しました：%@",
    "fc_pty_shell_exited": "Shellが終了しました。",
    "fc_pty_start_fail": "Shellの起動に失敗しました：%@",
    "fc_pty_alloc_fail": "PTYの割り当てに失敗しました：%@",
    "fc_copy_suffix": " (コピー)",
    "fc_untitled": "無題"
]

let koKRTranslations: [String: String] = [
    "ok": "확인", "cancel": "취소", "save": "저장", "delete": "삭제", "edit": "편집",
    "close": "닫기", "search": "검색", "refresh": "새로고침", "loading": "로딩 중...", "filter": "필터", "clear": "지우기", "retry": "재시도", "add": "추가",
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
    "secPlugin": "Plugin Ecosystem", "secTrainer": "Trainer",

    "newProject": "새 프로젝트", "openLocalFolder": "로컬 폴더 열기",
    "newWorkspace": "새 워크스페이스", "newWorkbench": "새 워크벤치",
    "noConversationsYet": "대화 없음", "noArtifactsYet": "Artifacts 없음",
    "openArtifacts": "Artifacts 열기",
    "runDashboard": "운영 대시보드", "pendingPublish": "발행 대기", "published": "발행됨",
    "hitProduct": "히트", "douyinHint": "「운영 대시보드」에서 제작 / 발행 / 댓글 / 진화",

    "mod_dashboard": "대시보드", "mod_design": "디자인", "mod_code": "코드", "mod_simulation": "시뮬레이션", "mod_modelHub": "모델", "mod_multimodal": "멀티모달", "mod_training": "트레이닝", "mod_cli": "명령줄", "mod_doc": "문서", "mod_bench": "벤치마크", "mod_desk": "자동화", "mod_dataTools": "데이터 도구", "mod_agent": "에이전트", "mod_plugin": "플러그인", "mod_security": "보안", "mod_analytics": "분석", "mod_collab": "협업", "mod_tuning": "튜닝", "mod_external": "외부 연동", "mod_docgen": "문서 생성", "mod_clusterOverview": "클러스터 개요", "mod_clusterTopology": "토폴로지", "mod_clusterSync": "클러스터 동기화", "mod_taskMonitor": "태스크 모니터", "mod_alertCenter": "알림 센터", "mod_nodeActions": "노드 관리", "mod_submitTask": "태스크 제출", "mod_taskProgress": "태스크 상세", "mod_routingStrategy": "라우팅", "mod_kvCache": "KV 캐시", "mod_serviceWeb": "서비스 패널", "mod_rag": "RAG", "mod_memory": "메모리", "mod_planner": "플래너", "mod_deploy": "배포", "mod_operations": "운영", "mod_eduK12": "K-12 교육", "mod_verification": "검증", "mod_tokenBudget": "토큰 예산", "mod_safety": "안전 승인", "mod_tools": "도구", "mod_agentDashboard": "에이전트 모니터", "mod_teamCollab": "팀 협업", "mod_chat": "채팅", "mod_fusionProjects": "프로젝트", "mod_cowork": "협업 공간", "mod_artifactsRepo": "Artifacts", "mod_fsb": "FSB", "mod_aiAgentDashboard": "AI 개요", "mod_aiAgentList": "에이전트 목록", "mod_aiAgentChat": "AI 채팅", "mod_aiAgentObserver": "AI 옵저버", "mod_aiAgentKnowledgeBase": "AI 지식베이스", "mod_science": "사이언스", "mod_finance": "파이낸스", "mod_health": "헬스", "mod_pluginConfig": "플러그인 설정", "mod_pluginStatus": "플러그인 상태", "mod_pluginToken": "Token", "mod_pluginVram": "VRAM", "mod_pluginLog": "플러그인 로그", "mod_pluginMcp": "MCP", "mod_trainer": "트레이너",

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
    "proj_panelTitle": "프로젝트",
    "proj_panelSort": "정렬:",
    "proj_panelNew": "새로 만들기",
    "proj_emptyTitle": "프로젝트를 시작하시겠습니까?",
    "proj_emptyHint": "한 공간에서 자료 업로드, 사용자 지정 지시 설정, 대화 정리.",
    "proj_panelNewProject": "새 프로젝트",
    "proj_tokensFmt": "%d 토큰",
    "proj_panelKbEmpty": "지식 파일이 아직 없습니다",
    "proj_panelAutoScan": "자동 스캔",
    "proj_panelCustomInst": "사용자 지정 지시",
    "proj_panelChatHistory": "채팅 기록",
    "proj_panelNewChat": "새 채팅",
    "proj_sessionsFmt": "%d 세션",
    "proj_panelChatEmpty": "채팅 세션이 아직 없습니다",
    "proj_panelStartConv": "대화 시작",
    "proj_msgsFmt": "%d개 메시지",
    "proj_panelSelect": "프로젝트 선택",
    "proj_panelOpenFolder": "프로젝트 폴더 열기",
    "proj_panelOpen": "열기",
    "proj_panelAddKbFiles": "지식 파일 추가",
    "proj_panelDefaultModel": "기본 모델",
    "proj_panelModelPh": "예: qwen3-9b",
    "proj_panelDefault": "기본값",
    "proj_panelTempFmt": "온도: %@",
    "proj_panelMaxTokensFmt": "최대 토큰: %d",
    "proj_panelAutoLoadClaude": "CLAUDE.md 자동 로드",
    "proj_panelAutoScanKb": "지식 파일 자동 스캔",
    "proj_tabSessions": "세션",
    "proj_tabSettings": "설정",
    "cw_snap_title": "세션 스냅샷",
    "cw_snap_create": "스냅샷 생성",
    "cw_snap_empty": "스냅샷 없음",
    "cw_list_subtitle": "협업 공간 — 팀 채팅, 공유 에이전트, 워크플로 조정",
    "cw_list_searchPh": "공간 검색...",
    "cw_list_newHelp": "새 협업 공간",
    "cw_list_marketHelp": "워크플로/템플릿 마켓",
    "cw_filter_all": "전체",
    "cw_filter_created": "내가 생성",
    "cw_filter_joined": "참여 중",
    "cw_filter_archived": "보관됨",
    "cw_list_onboardingTitle": "첫 협업 공간 시작",
    "cw_list_onboardingBody": "CoWork는 팀의 실시간 채팅, 에이전트 공유, 워크플로 조정을 지원. 오프라인 공간, 심층 연구, 데스크톱 공유 등 차별화 기능.",
    "cw_list_createLabel": "협업 공간 만들기",
    "cw_list_archivedTag": "보관됨",
    "cw_list_emptyTitle": "협업 공간 선택",
    "cw_list_emptyHint": "또는 새 공간을 만들어 시작",
    "cw_list_loadFail": "로드 실패: %@",
    "cw_create_title": "새 협업 공간",
    "cw_create_basic": "기본 정보",
    "cw_create_namePh": "공간 이름",
    "cw_create_descPh": "설명（선택）",
    "cw_create_mode": "협업 모드",
    "cw_create_modeLocal": "로컬",
    "cw_create_modeP2p": "LAN",
    "cw_create_modeGateway": "원격",
    "cw_create_modeLocalDesc": "단일 오프라인 협업",
    "cw_create_modeP2pDesc": "Bonjour LAN 탐색",
    "cw_create_modeGatewayDesc": "Fusion Gateway 경유",
    "cw_create_kb": "지식베이스 연동",
    "cw_create_kbPh": "KB 경로（선택, 예: 프로젝트 디렉터리）",
    "cw_create_ability": "공간 기능",
    "cw_create_webSearch": "웹 검색",
    "cw_create_deepResearch": "심층 연구",
    "cw_create_computerUse": "데스크톱 제어",
    "cw_create_memberUpload": "멤버 업로드",
    "cw_create_memberAgent": "멤버 에이전트 생성",
    "cw_create_memberWorkflow": "멤버 워크플로 실행",
    "cw_create_advanced": "고급 설정",
    "cw_create_maxMembers": "최대 멤버 수",
    "cw_create_btn": "만들기",
    "cw_main_loading": "로드 중...",
    "cw_main_deepResearch": "심층 연구",
    "cw_main_computerUse": "데스크톱 제어",
    "cw_main_createSnap": "스냅샷 만들기",
    "cw_main_archive": "공간 보관",
    "cw_main_archivedBanner": "이 공간은 보관됨 — 읽기 전용",
    "cw_side_members": "멤버",
    "cw_side_files": "파일",
    "cw_side_knowledge": "지식베이스",
    "cw_side_agents": "에이전트",
    "cw_side_artifacts": "아티팩트",
    "cw_side_workflows": "워크플로",
    "cw_side_snapshots": "스냅샷",
    "cw_side_desktop": "데스크톱",
    "cw_side_settings": "설정",
    "cw_chat_emptyTitle": "공간 채팅",
    "cw_chat_emptyHint": "첫 메시지를 보내거나 @Agent 로 협업 시작",
    "cw_chat_thinking": "생각 중...",
    "cw_chat_copy": "복사",
    "cw_chat_retry": "재시도",
    "cw_chat_attach": "첨부",
    "cw_chat_screenshot": "스크린샷",
    "cw_chat_noAgent": "없음（직접 전송）",
    "cw_chat_inputPh": "메시지 입력, @Agent 로 협업...",
    "cw_chat_relay": "에이전트 릴레이",
    "cw_chat_relayHint": "여러 에이전트를 선택해 순차적으로 메시지 처리",
    "cw_chat_relayClear": "초기화",
    "cw_chat_relayDone": "완료",
    "cw_chat_streamErr": "오류: %@",
    "cw_chat_sendFail": "전송 실패: %@",
    "cw_chat_relayFail": "릴레이 실패: %@",
    "cw_system_name": "시스템",
    "cw_comment_title": "댓글",
    "cw_comment_addPh": "댓글 추가...",
    "cw_comment_send": "전송",
    "cw_member_title": "멤버",
    "cw_member_lanDiscovery": "LAN 탐색",
    "cw_member_scanning": "스캔 중...",
    "cw_member_scan": "스캔",
    "cw_member_inviteTitle": "멤버 초대",
    "cw_member_inviteRole": "역할",
    "cw_member_inviteMaxUses": "최대 사용 횟수: %d",
    "cw_member_inviteExpires": "만료(시간): %d",
    "cw_member_inviteGen": "초대 링크 생성",
    "cw_member_inviteCode": "초대 코드: %@",
    "cw_member_remove": "제거",
    "cw_role_owner": "소유자",
    "cw_role_admin": "관리자",
    "cw_role_member": "멤버",
    "cw_role_viewer": "관찰자",
    "cw_files_title": "파일",
    "cw_files_empty": "파일 없음",
    "cw_agent_title": "에이전트",
    "cw_agent_empty": "공유 에이전트 없음",
    "cw_agent_add": "에이전트 추가",
    "cw_agent_edit": "편집",
    "cw_agent_copyToProject": "프로젝트로 복사",
    "cw_agent_remove": "제거",
    "cw_agent_addTitle": "에이전트 추가",
    "cw_agent_editTitle": "에이전트 편집",
    "cw_agent_name": "이름",
    "cw_agent_namePh": "에이전트 이름",
    "cw_agent_model": "모델",
    "cw_agent_modelPh": "모델（빈칸 시 기본값）",
    "cw_agent_perm": "권한",
    "cw_agent_permAll": "모든 멤버 사용 가능",
    "cw_agent_permAdmin": "관리자만",
    "cw_agent_permCustom": "지정 멤버",
    "cw_agent_permAllLabel": "전체 멤버",
    "cw_agent_permCustomLabel": "사용자 지정",
    "cw_snap2_title": "스냅샷",
    "cw_snap2_empty": "스냅샷 없음",
    "cw_snap2_createTitle": "스냅샷 만들기",
    "cw_snap2_namePh": "이름",
    "cw_snap2_forkTitle": "스냅샷 포크",
    "cw_snap2_forkSpacePh": "새 공간 이름",
    "cw_snap2_restore": "이 스냅샷 복원",
    "cw_snap2_forkNew": "새 공간으로 포크",
    "cw_snap2_msgCount": "%d개 메시지",
    "cw_snap2_dagName": "DAG: %@",
    "cw_art_title": "아티팩트",
    "cw_art_kindAll": "전체",
    "cw_art_kindCode": "코드",
    "cw_art_kindDoc": "문서",
    "cw_art_kindViz": "시각화",
    "cw_art_kindData": "데이터",
    "cw_art_createTitle": "아티팩트 만들기",
    "cw_art_kindPicker": "유형",
    "cw_wf_title": "워크플로",
    "cw_wf_empty": "워크플로 없음",
    "cw_wf_create": "워크플로 만들기",
    "cw_wf_createTitle": "워크플로 만들기",
    "cw_wf_namePh": "워크플로 이름",
    "cw_wf_descPh": "설명（선택）",
    "cw_wf_nodeCount": "%d개 노드",
    "cw_wf_status_running": "실행 중",
    "cw_wf_status_completed": "완료",
    "cw_wf_status_failed": "실패",
    "cw_wf_status_idle": "유휴",
    "cw_snap_emptyHint": "스냅샷을 생성해 현재 세션 상태를 저장하세요. 언제든 롤백 또는 포크 가능.",
    "cw_snap_labelPh": "라벨(선택)",
    "cw_snap_createBtn": "생성",
    "cw_snap_forkAlert": "이 스냅샷을 새 세션으로 포크하시겠습니까?",
    "cw_snap_forkBtn": "포크",
    "cw_snap_msgFmt": "%d개 메시지",
    "cw_snap_restoreHelp": "이 스냅샷으로 복원",
    "cw_snap_forkHelp": "새 세션으로 포크",
    "cw_snap_deleteHelp": "스냅샷 삭제",
    "cw_snap_forkAlertBtn": "포크",
    "cw_desk_title": "데스크톱",
    "cw_desk_role": "역할",
    "cw_desk_roleObserver": "관찰자",
    "cw_desk_roleController": "제어자",
    "cw_desk_roleApprover": "승인자",
    "cw_desk_notSharing": "데스크톱 공유 꺼짐",
    "cw_desk_controlReq": "제어 요청",
    "cw_desk_approve": "승인",
    "cw_desk_reject": "거절",
    "cw_desk_auditLog": "작업 기록",
    "cw_desk_sharing": "공유 중",
    "cw_set_title": "설정",
    "cw_set_streamResp": "스트리밍 응답",
    "cw_research_running": "진행 중...",
    "cw_research_queryPh": "연구 질문 입력...",
    "cw_research_depth": "깊이",
    "cw_research_depthShallow": "얕게",
    "cw_research_depthMedium": "중간",
    "cw_research_depthDeep": "깊게",
    "cw_research_start": "연구 시작",
    "cw_research_multiAgent": "다중 에이전트 병렬",
    "cw_research_autoSelect": "자동 선택",
    "cw_research_agentCountFmt": "%d Agents",
    "cw_research_zeroToken": "토큰 비용 제로 · 로컬 추론",
    "cw_research_runningProgress": "심층 연구 진행 중...",
    "cw_research_desc": "심층 연구는 다중 에이전트 병렬 추론으로 복잡한 조사를 자동화",
    "cw_research_vsClaude": "Claude CoWork 대비: 토큰 비용 제로 · 로컬 모델 추론 · 다중 에이전트 병렬 선택",
    "cw_research_track": "연구 경로",
    "cw_research_agentProgress": "에이전트 연구 진행",
    "cw_research_noResult": "연구 완료, 결과 텍스트 없음",
    "cw_research_failFmt": "연구 실패: %@",
    "cw_research_done": "완료",
    "cw_research_runningStatus": "연구 중...",
    "cw_preview_empty": "미리보기 내용 없음",
    "cw_notif_title": "알림",
    "cw_notif_markAll": "모두 읽음",
    "cw_notif_empty": "알림 없음",
    "cw_kb_title": "지식 베이스",
    "cw_kb_unbound": "지식 베이스 미연결",
    "cw_kb_bindHint": "연결 후 에이전트 대화가 관련 문서를 자동 검색",
    "cw_kb_bind": "지식 베이스 연결",
    "cw_kb_statsFmt": "%d 문서, %d 청크",
    "cw_kb_searchPh": "지식 베이스 검색...",
    "cw_kb_results": "검색 결과",
    "cw_kb_ragAnswer": "RAG 답변",
    "cw_kb_upload": "문서 업로드",
    "cw_kb_uploadTitle": "지식 베이스에 문서 업로드",
    "cw_kb_pathPh": "파일 경로",
    "cw_kb_uploadBtn": "업로드",
    "cw_kb_docFmt": "문서 %d",
    "cw_mkt_title": "마켓플레이스",
    "cw_mkt_type": "유형",
    "cw_mkt_typeWorkflow": "워크플로우",
    "cw_mkt_typeArtifact": "아티팩트 템플릿",
    "cw_mkt_install": "설치",
    "cw_home_mode_chat": "Chat",
    "cw_home_mode_cowork": "CoWork",
    "cw_home_pick_title": "인가 폴더 선택",
    "cw_home_pick_prompt": "CoWork 는 인가한 폴더만 접근합니다",
    "cw_home_pick_confirm": "인가",
    "cw_home_no_scoped": "인가 폴더를 선택하고 시작",
    "cw_home_svc_down": "fusion-cowork 미실행 (설정 → 업스트림 서비스)",
    "cw_home_submit_fail": "제출 실패: ",
    "cw_home_bubble_step": "단계",
    "cw_home_bubble_done": "완료",
    "cw_home_bubble_error": "오류",
    "cw_home_bubble_artifact": "산출물",
    "ai_offline_badge": "오프라인",
    "ai_offline_helpOff": "오프라인 모드 — 클릭하여 상세 보기",
    "ai_offline_helpOn": "온라인 모드",
    "ai_offline_netStatus": "네트워크 상태",
    "ai_offline_offMode": "오프라인 모드",
    "ai_offline_onMode": "온라인 모드",
    "ai_offline_reasonFmt": "원인: %@",
    "ai_offline_disabledTitle": "오프라인 모드에서 사용 불가 기능:",
    "ai_offline_featInfer": "모델 추론",
    "ai_offline_featKb": "지식 베이스 조회",
    "ai_offline_featCode": "코드 생성",
    "ai_offline_manual": "수동 전환",
    "ai_audit_title": "감사 로그",
    "ai_audit_toolPh": "도구 이름",
    "ai_audit_typePh": "작업 유형",
    "ai_audit_sincePh": "시작 시간",
    "ai_audit_sinceHint": "예: 2025-01-01",
    "ai_audit_apply": "적용",
    "ai_audit_freq": "도구 호출 빈도",
    "ai_audit_empty": "감사 로그 없음",
    "ai_monitor_title": "모델 로드 모니터",
    "ai_monitor_refreshFmt": "%ds마다 새로고침",
    "ai_monitor_manualRefresh": "수동 새로고침",
    "ai_monitor_connected": "MLX 연결됨",
    "ai_monitor_disconnected": "MLX 미연결",
    "ai_monitor_startMlx": "MLX 시작",
    "ai_monitor_availModels": "사용 가능 모델",
    "ai_monitor_noModels": "모델 없음",
    "ai_monitor_loaded": "로드됨",
    "ai_monitor_load": "로드",
    "ai_monitor_loadingStatus": "모델 상태 로드 중...",
    "ai_monitor_errFmt": "모델 상태 가져오기 실패: %@",
    "ai_perm_title": "권한 태그",
    "ai_perm_capsTitle": "기능 권한",
    "ai_perm_empty": "권한 데이터 없음",
    "ai_perm_agentFmt": "Agent %@",
    "ai_perm_deniedTitle": "FUSION.rules 금지 도구",
    "ai_perm_toolPh": "도구 이름",
    "ai_perm_sensitiveTitle": "민감 파일 패턴",
    "ai_perm_sensitiveTag": "민감",
    "ai_perm_capRead": "지식 베이스 읽기",
    "ai_perm_capWrite": "지식 베이스 쓰기",
    "ai_perm_capDelete": "지식 베이스 삭제",
    "ai_perm_capCode": "코드 실행",
    "ai_perm_capNet": "네트워크 접근",
    "ai_review_title": "Diff 리뷰",
    "ai_review_export": "review.md 내보내기",
    "ai_review_sevCritical": "심각",
    "ai_review_sevWarning": "경고",
    "ai_review_sevInfo": "정보",
    "ai_review_empty": "Diff 데이터 없음",
    "ai_review_exportTitle": "review.md 내보내기",
    "ai_review_copy": "클립보드에 복사",
    "ai_dash_title": "콘솔 개요",
    "ai_dash_subtitle": "Agent 관리 콘솔 — 글로벌 대시보드 및 빠른 접근",
    "ai_dash_statToday": "오늘 요청",
    "ai_dash_statToken": "Token 사용량",
    "ai_dash_statActive": "활성 Agent",
    "ai_dash_statError": "오류 요청",
    "ai_dash_quickTitle": "빠른 접근",
    "ai_dash_qaCreate": "새 Agent 만들기",
    "ai_dash_qaKb": "새 지식 베이스",
    "ai_dash_qaConnector": "커넥터 관리",
    "ai_dash_qaApiDoc": "API 문서",
    "ai_dash_recentTitle": "최근 Agent",
    "ai_dash_recentViewAll": "전체 보기",
    "ai_dash_empty": "Agent 없음, 위를 클릭하여 생성",
    "ai_dash_alertTitle": "알림",
    "ai_dash_alertEmpty": "모두 정상, 알림 없음",
    "ai_dash_alertUnknown": "알 수 없는 알림",
    "ai_list_create": "Agent 생성",
    "ai_list_searchPh": "Agent 이름 검색...",
    "ai_list_delTitle": "삭제 확인",
    "ai_list_delMsgFmt": "Agent \"%@\"를 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.",
    "ai_list_filterFmt": "필터: %@",
    "ai_list_hName": "Agent 이름",
    "ai_list_hStatus": "상태",
    "ai_list_hModel": "모델",
    "ai_list_hKb": "지식 베이스",
    "ai_list_hUpdated": "최종 업데이트",
    "ai_list_hAction": "작업",
    "ai_list_empty": "Agent 없음",
    "ai_list_emptyHint": "\"Agent 생성\"을 클릭하여 구축 시작",
    "ai_list_actDebug": "디버그",
    "ai_list_actEdit": "편집",
    "ai_list_actClone": "복제",
    "ai_list_actArchive": "보관",
    "ai_list_actDelete": "삭제",
    "ai_list_scopeAll": "전체",
    "ai_list_scopeDraft": "초안",
    "ai_list_scopePublished": "게시됨",
    "ai_list_sortUpdated": "최근 업데이트",
    "ai_list_sortCreated": "생성 시간",
    "ai_list_sortName": "이름",
    "ai_kb_title": "지식 베이스 관리",
    "ai_kb_searchPh": "프로젝트 검색...",
    "ai_kb_newBtn": "새 프로젝트",
    "ai_kb_unnamed": "제목 없음",
    "ai_kb_createdFmt": "%@에 생성",
    "ai_kb_detail": "세부 정보",
    "ai_kb_statusActive": "활성",
    "ai_kb_empty": "지식 베이스 프로젝트 없음",
    "ai_kb_emptyHint": "프로젝트를 만들고 문서를 업로드하여 Agent에 지식 제공",
    "ai_kb_sheetTitle": "새 지식 베이스 프로젝트",
    "ai_kb_sheetName": "프로젝트 이름",
    "ai_kb_sheetNamePh": "프로젝트 이름 입력",
    "ai_kb_sheetDesc": "프로젝트 설명",
    "ai_kb_sheetCreate": "만들기",
    "ai_kb_detTitle": "프로젝트 세부 정보",
    "ai_kb_detTabFiles": "파일",
    "ai_kb_detTabInstruction": "지침",
    "ai_kb_detTabAgents": "연결된 Agent",
    "ai_kb_filesEmpty": "파일 없음",
    "ai_kb_artRemove": "제거",
    "ai_kb_instrTitle": "프로젝트 지침",
    "ai_kb_instrSave": "지침 저장",
    "ai_kb_agentsTitle": "이 지식 베이스에 연결된 Agent",
    "ai_kb_agentsEmpty": "이 지식 베이스에 연결된 Agent 없음",
    "ai_chat_welcomeTitle": "Agent 와 대화 시작",
    "ai_chat_welcomeHint": "Agent 를 선택하고 메시지를 입력하여 시작",
    "ai_chat_noAgent": "사용 가능한 Agent 없음, 먼저 생성하세요",
    "ai_chat_streaming": "생성 중...",
    "ai_chat_qaSummarize": "문서 요약",
    "ai_chat_qaCode": "코드 생성",
    "ai_chat_qaData": "데이터 분석",
    "ai_chat_qaTranslate": "번역",
    "ai_chat_qaWrite": "창의적 글쓰기",
    "ai_chat_inputPh": "메시지 입력...",
    "ai_chat_toolbox": "도구 상자",
    "ai_chat_toolWebSearch": "웹 검색",
    "ai_chat_toolResearch": "심층 조사",
    "ai_chat_toolCode": "코드 실행",
    "ai_chat_toolKb": "지식 베이스 쿼리",
    "ai_chat_pickTitle": "Agent 선택",
    "ai_chat_pickEmpty": "사용 가능한 Agent 없음",
    "ai_chat_noResponse": "(응답 없음)",
    "ai_chat_rtTitle": "런타임 설정",
    "ai_chat_rtMaxTokens": "최대 Token",
    "ai_chat_rtApply": "현재 세션에 적용",
    "ai_chat_reqFailedFmt": "요청 실패: %@",
    "ai_debug_title": "디버그 패널",
    "ai_debug_agentFmt": "Agent %@",
    "ai_debug_executing": "실행 중",
    "ai_debug_ready": "준비 완료",
    "ai_debug_chatEmpty": "메시지를 보내 Agent 응답 테스트",
    "ai_debug_chatEmptyHint": "디버그 모드는 실행 단계와 도구 호출을 실시간으로 표시",
    "ai_debug_inputPh": "테스트 메시지 입력...",
    "ai_debug_logsTitle": "현재 세션 로그",
    "ai_debug_loadHistory": "기록 불러오기",
    "ai_debug_logsEmpty": "실행 로그 비어 있음",
    "ai_debug_logsEmptyHint": "테스트 메시지 전송 후 실행 단계가 여기에 표시됩니다",
    "ai_debug_tasksEmpty": "코드 작업 없음",
    "ai_debug_tasksEmptyHint": "코드를 제출해 Agent 가 실행하고 결과 확인",
    "ai_debug_lang": "언어",
    "ai_debug_submit": "제출",
    "ai_debug_logReceiveFmt": "사용자 메시지 수신: %@",
    "ai_debug_noResponse": "(응답 내용 없음)",
    "ai_debug_logExecDone": "Agent 실행 완료",
    "ai_debug_logToolFmt": "도구 호출: %@",
    "ai_debug_logExecFallback": "Agent 실행 완료(fallback)",
    "ai_debug_logFailFmt": "실행 실패: %@",
    "ai_debug_tabChat": "채팅 테스트",
    "ai_debug_tabLogs": "실행 로그",
    "ai_debug_tabTasks": "코드 작업",
    "ai_obs_tabUsage": "사용량",
    "ai_obs_tabLogs": "실행 로그",
    "ai_obs_tabApikeys": "API 키",
    "ai_obs_tabConnectors": "커넥터",
    "ai_obs_tabPermissions": "권한 태그",
    "ai_obs_tabAudit": "감사 로그",
    "ai_obs_title": "모니터링 및 관리",
    "ai_obs_subtitle": "사용량 · 로그 · API 키 · 커넥터",
    "ai_obs_statToday": "오늘 요청",
    "ai_obs_statToken": "총 토큰",
    "ai_obs_statActive": "활성 Agent",
    "ai_obs_statError": "오류율",
    "ai_obs_alerts": "알림",
    "ai_obs_logsEmpty": "실행 로그 없음",
    "ai_obs_apikeysTitle": "API 키 관리",
    "ai_obs_apikeyCreate": "키 생성",
    "ai_obs_apikeysEmpty": "API 키 없음",
    "ai_obs_createdFmt": "생성 %@",
    "ai_obs_rotate": "교체",
    "ai_obs_revoke": "폐기",
    "ai_obs_connTitle": "외부 커넥터",
    "ai_obs_connAdd": "커넥터 추가",
    "ai_obs_connEmpty": "구성된 커넥터 없음",
    "ai_obs_connConnected": "연결됨",
    "ai_obs_connDisconnected": "연결 안 됨",
    "ai_obs_connect": "연결",
    "ai_obs_unnamedKey": "이름 없는 키",
    "ai_obs_unnamedConn": "이름 없음",
    "ai_cfg_tabBasic": "기본 정보",
    "ai_cfg_tabInstructions": "시스템 명령",
    "ai_cfg_tabSoul": "인격 Soul",
    "ai_cfg_tabKnowledge": "지식 베이스",
    "ai_cfg_tabTools": "도구 설정",
    "ai_cfg_tabAdvanced": "고급 매개변수",
    "ai_cfg_tabPublish": "게시",
    "ai_cfg_skillAddTitle": "스킬 추가",
    "ai_cfg_skillNamePh": "스킬 이름",
    "ai_cfg_skillDescPh": "스킬 설명（선택）",
    "ai_cfg_modeCreate": "새 Agent 만들기",
    "ai_cfg_modeEditFmt": "Agent 편집: %@",
    "ai_cfg_subCreate": "에이전트의 기본 정보, 명령, 도구, 매개변수 설정",
    "ai_cfg_subEdit": "Agent 설정 수정 후 저장 또는 게시",
    "ai_cfg_nameLabel": "Agent 이름",
    "ai_cfg_namePh": "Agent 이름 입력",
    "ai_cfg_descLabel": "소개",
    "ai_cfg_descPh": "Agent의 기능과 용도 설명",
    "ai_cfg_modelLabel": "모델 선택",
    "ai_cfg_modelPicker": "모델",
    "ai_cfg_modelChoose": "모델 선택",
    "ai_cfg_visLabel": "공개 범위",
    "ai_cfg_visPrivate": "비공개",
    "ai_cfg_visOrg": "조직 공유",
    "ai_cfg_instrHint": "Agent의 기본 역할, 행동 제약, 출력 사양 작성",
    "ai_cfg_charFmt": "%d자",
    "ai_cfg_instrSaveTpl": "템플릿 저장",
    "ai_cfg_instrRestore": "이전 버전 복원",
    "ai_cfg_soulHint": "Agent의 인격, 말투, 감정 선호도 정의",
    "ai_cfg_soulSave": "Soul 저장",
    "ai_cfg_soulAfterCreate": "Agent 생성 후 Soul 편집 가능",
    "ai_cfg_kbLabel": "지식 베이스 Project 연결",
    "ai_cfg_kbAdd": "+ 지식 베이스 추가",
    "ai_cfg_ragLabel": "검색 전략",
    "ai_cfg_ragVector": "벡터 검색",
    "ai_cfg_ragFulltext": "전문 검색",
    "ai_cfg_ragHybrid": "하이브리드 검색",
    "ai_cfg_autoQueryLabel": "자동 쿼리",
    "ai_cfg_autoQueryToggle": "Agent가 자율적으로 지식 베이스를 쿼리하도록 허용",
    "ai_cfg_toolsBuiltin": "내장 도구",
    "ai_cfg_toolWebSearch": "웹 검색",
    "ai_cfg_toolDeepResearch": "딥 리서치",
    "ai_cfg_skillsLabel": "스킬 Skills",
    "ai_cfg_skillCountFmt": "스킬 %d개 추가",
    "ai_cfg_skillsEmpty": "스킬 없음. 스킬 추가를 클릭해 기능 추가",
    "ai_cfg_skillsAfterCreate": "Agent 생성 후 스킬 관리 가능",
    "ai_cfg_connLabel": "외부 커넥터 Connectors",
    "ai_cfg_connEmpty": "인증된 커넥터 없음",
    "ai_cfg_connUnknown": "알 수 없음",
    "ai_cfg_tempHint": "낮음=정확, 높음=창의적",
    "ai_cfg_maxTokenLabel": "최대 출력 토큰",
    "ai_cfg_ctxLabel": "컨텍스트 윈도우",
    "ai_cfg_styleLabel": "출력 스타일 Style",
    "ai_cfg_stylePicker": "스타일",
    "ai_cfg_styleDefault": "기본",
    "ai_cfg_qpsLabel": "QPS 제한",
    "ai_cfg_qpsUnit": "요청/초",
    "ai_cfg_pubLabel": "게시 작업",
    "ai_cfg_pubBtn": "Agent 게시",
    "ai_cfg_pubGetApi": "API 엔드포인트 가져오기",
    "ai_cfg_pubSaveFirst": "게시 전 초안을 먼저 저장하세요",
    "ai_cfg_summaryTitle": "설정 요약",
    "ai_cfg_sumName": "이름",
    "ai_cfg_sumModel": "모델",
    "ai_cfg_sumVis": "공개 범위",
    "ai_cfg_sumKb": "지식 베이스",
    "ai_cfg_sumKbUnbound": "연결 안 됨",
    "ai_cfg_sumTools": "도구",
    "ai_cfg_sumMaxToken": "최대 토큰",
    "ai_cfg_sumConnFmt": "커넥터 %d개",
    "ai_cfg_sumToolsNone": "비활성화",
    "ai_cfg_deleteBtn": "Agent 삭제",
    "ai_cfg_saveDraft": "초안 저장",
    "fsb_ws_renameAlertTitle": "워크스페이스 이름 변경",
    "fsb_ws_name": "이름",
    "fsb_ws_exportTitle": "워크스페이스 내보내기",
    "fsb_ws_copyClipboard": "클립보드에 복사",
    "fsb_ws_emptyWorkspaces": "워크스페이스 없음",
    "fsb_ws_noMatch": "일치하는 워크스페이스 없음",
    "fsb_ws_createWs": "워크스페이스 생성",
    "fsb_ws_headerTitle": "FSB 워크벤치",
    "fsb_ws_newWs": "새 워크스페이스",
    "fsb_ws_listView": "목록 보기",
    "fsb_ws_gridView": "그리드 보기",
    "fsb_ws_searchPh": "워크스페이스 검색...",
    "fsb_unnamed": "이름 없음",
    "fsb_ws_connWfFmt": "%d연결·%d흐름",
    "fsb_ws_open": "열기",
    "fsb_ws_rename": "이름 변경",
    "fsb_ws_duplicate": "복제",
    "fsb_ws_export": "내보내기",
    "fsb_ws_subtitle": "크로스 SaaS 스마트 비즈니스 워크벤치",
    "fsb_ws_serviceDown": "FSB 서비스 미실행",
    "fsb_ws_usageGuide": "사용 가이드",
    "fsb_ws_namePh": "예: 고객 관리 시스템",
    "fsb_ws_descOpt": "설명 (선택)",
    "fsb_ws_descPh": "워크스페이스 용도 설명",
    "fsb_ws_bindProjectOpt": "프로젝트 연결 (선택)",
    "fsb_ws_projectIdPh": "프로젝트 ID",
    "fsb_ws_bindAgentOpt": "Agent 연결 (선택)",
    "fsb_ws_importTemplate": "템플릿에서 가져오기",
    "fsb_ws_createBtn": "생성",
    "fsb_ws_builtinTemplates": "내장 템플릿",
    "fsb_tpl_crm_name": "고객 관계 관리",
    "fsb_tpl_crm_short": "CRM",
    "fsb_tpl_crm_desc": "고객 정보, 후속 기록, 영업 파이프라인 관리",
    "fsb_tpl_inventory_name": "재고 관리",
    "fsb_tpl_inventory_short": "재고",
    "fsb_tpl_inventory_desc": "재고 추적, 보충 알림, 입출고 기록",
    "fsb_tpl_finance_name": "재무 기장",
    "fsb_tpl_finance_short": "재무",
    "fsb_tpl_finance_desc": "수입/지출, 청구서, 재무 보고서",
    "fsb_tpl_email_name": "이메일 마케팅",
    "fsb_tpl_email_short": "마케팅",
    "fsb_tpl_email_desc": "이메일 템플릿, 대상 그룹, 발송 예약, 효과 분석",
    "fsb_tpl_social_name": "소셜 미디어 관리",
    "fsb_tpl_social_short": "소셜",
    "fsb_tpl_social_desc": "멀티 플랫폼 게시, 예약, 상호작용 모니터링, 데이터 분석",
    "fsb_tpl_ticket_name": "티켓 시스템",
    "fsb_tpl_ticket_short": "티켓",
    "fsb_tpl_ticket_desc": "고객 티켓, 할당, SLA 추적, 만족도 조사",
    "fsb_ob_welcome_title": "FSB에 오신 것을 환영합니다",
    "fsb_ob_welcome_desc": "Fusion Small Business는 크로스 SaaS 스마트 비즈니스 자동화 워크벤치입니다.\n코딩 없이 시각적 워크플로로 비즈니스 도구를 연결하세요.",
    "fsb_ob_connectors_title": "커넥터",
    "fsb_ob_connectors_desc": "기존 SaaS 도구를 연결하세요:\nGoogle Workspace, Shopify, QuickBooks, Stripe 등.\n읽기는 자동 실행, 쓰기는 승인 필요.",
    "fsb_ob_skills_title": "스킬",
    "fsb_ob_skills_desc": "15개 이상의 스마트 스킬 내장:\n이메일 요약, 데이터 추출, 보고서 생성, 번역 등.\n프롬프트 스킬과 API 호출 스킬을 사용자 정의.",
    "fsb_ob_workflow_title": "워크플로",
    "fsb_ob_workflow_desc": "시각적으로 워크플로를 구성하세요:\n드래그로 노드를 연결해 DAG 구성, 조건 분기, 승인 게이트.\n예약, 이벤트, 외부 API 트리거 지원.",
    "fsb_ob_start_title": "시작하기",
    "fsb_ob_start_desc": "워크스페이스를 생성하세요. 템플릿 선택 또는 처음부터.\n모든 데이터는 로컬 실행, 프라이버시 보장.",
    "fsb_ob_prev": "이전",
    "fsb_dlg_addConnector": "커넥터 추가",
    "fsb_dlg_connecting": "연결 중...",
    "fsb_dlg_connect": "연결",
    "fsb_dlg_selectConnector": "커넥터 선택",
    "fsb_dlg_connector": "커넥터",
    "fsb_dlg_selectPh": "선택...",
    "fsb_dlg_supportFmt": "지원: %@",
    "fsb_dlg_authMethod": "인증 방식",
    "fsb_dlg_auth": "인증",
    "fsb_dlg_noAuth": "인증 없음",
    "fsb_dlg_enterApiKey": "API Key 입력",
    "fsb_dlg_scopesHint": "Scopes (쉼표 구분)",
    "fsb_dlg_createSkill": "스킬 생성",
    "fsb_dlg_saving": "저장 중...",
    "fsb_dlg_create": "생성",
    "fsb_dlg_skillName": "스킬 이름",
    "fsb_dlg_displayName": "표시 이름",
    "fsb_dlg_mySkill": "내 스킬",
    "fsb_dlg_type": "유형",
    "fsb_dlg_prompt": "프롬프트",
    "fsb_dlg_function": "함수",
    "fsb_dlg_chain": "체인",
    "fsb_dlg_definition": "정의",
    "fsb_dlg_inputSchema": "입력 Schema (JSON)",
    "fsb_dlg_outputFormat": "출력 형식",
    "fsb_dlg_plainText": "일반 텍스트",
    "fsb_dlg_setSchedule": "스케줄 설정",
    "fsb_dlg_triggerMethod": "트리거 방식",
    "fsb_dlg_manual": "수동",
    "fsb_dlg_cron": "예약 (Cron)",
    "fsb_dlg_eventDriven": "이벤트 구동",
    "fsb_dlg_manualOnly": "워크스페이스에서 수동 실행만",
    "fsb_dlg_cronExpr": "Cron 식",
    "fsb_dlg_commonPresets": "자주 쓰는 프리셋",
    "fsb_dlg_preset_weekday9": "평일 9시",
    "fsb_dlg_preset_hourly": "매시",
    "fsb_dlg_preset_daily8": "매일 8시",
    "fsb_dlg_preset_monday9": "매주 월 9시",
    "fsb_dlg_preset_month1": "매월 1일",
    "fsb_dlg_eventTrigger": "이벤트 트리거",
    "fsb_dlg_eventPh": "예: data.updated, order.created",
    "fsb_dlg_eventHint": "지원 이벤트: 데이터 변경, 신규 레코드, 상태 업데이트 등",
    "fsb_dlg_approvalRequest": "승인 요청",
    "fsb_dlg_requestContent": "요청 내용",
    "fsb_dlg_editContent": "편집 내용 (선택)",
    "fsb_dlg_reject": "거절",
    "fsb_dlg_processing": "처리 중...",
    "fsb_dlg_approve": "승인",
    "fsb_wb_sec_connectors": "커넥터",
    "fsb_wb_sec_skills": "스킬",
    "fsb_wb_sec_workflows": "워크플로",
    "fsb_wb_sec_variables": "변수",
    "fsb_wb_sec_templates": "템플릿",
    "fsb_wb_tab_approval": "승인 대기",
    "fsb_wb_tab_scheduled": "예약 작업",
    "fsb_wb_tab_history": "실행 기록",
    "fsb_wb_tab_sandbox": "컨텍스트 샌드박스",
    "fsb_wb_workspace": "워크벤치",
    "fsb_wb_connected": "연결됨",
    "fsb_wb_noConnector": "커넥터 없음",
    "fsb_wb_available": "사용 가능한 커넥터",
    "fsb_wb_disconnect": "연결 해제",
    "fsb_wb_connect": "연결",
    "fsb_wb_skillList": "스킬 목록",
    "fsb_wb_noSkill": "스킬 없음",
    "fsb_wb_test": "테스트",
    "fsb_wb_wfList": "워크플로 목록",
    "fsb_wb_noWorkflow": "워크플로 없음",
    "fsb_wb_createWf": "워크플로 생성",
    "fsb_wb_run": "실행",
    "fsb_wb_schedule": "예약",
    "fsb_wb_variables": "변수",
    "fsb_wb_noVariable": "변수 없음",
    "fsb_wb_templates": "템플릿",
    "fsb_wb_newWf": "새 워크플로",
    "fsb_wb_createFirstWf": "첫 워크플로를 생성하세요",
    "fsb_wb_nodeCountFmt": "%d 노드",
    "fsb_wb_taskCenter": "작업 센터",
    "fsb_wb_noApproval": "승인 대기 작업 없음",
    "fsb_wb_approvalReq": "승인 요청",
    "fsb_wb_approve": "승인",
    "fsb_wb_deny": "거절",
    "fsb_wb_noScheduled": "예약 작업 없음",
    "fsb_wb_noHistory": "실행 기록 없음",
    "fsb_wb_inputData": "입력 데이터",
    "fsb_wb_sandboxVars": "샌드박스 변수",
    "fsb_wb_snapshots": "스냅샷",
    "fsb_wb_sandboxEmpty": "컨텍스트 샌드박스가 비어 있음",
    "fsb_wb_sandboxHint": "워크플로 실행 후 샌드박스가\n실행 컨텍스트와 데이터 스냅샷을 기록합니다",
    "rag_sec_dashboard": "지식베이스 개요",
    "rag_sec_files": "파일 디렉터리 관리",
    "rag_sec_chat": "RAG 채팅",
    "rag_sec_embedConfig": "임베딩 모델 설정",
    "rag_sec_searchConfig": "검색 전략 설정",
    "rag_sec_permissions": "권한 관리",
    "rag_sec_vectorOps": "벡터 DB 운영",
    "rag_sec_callLog": "RAG 호출 로그",
    "rag_sec_benchEval": "검색 성능 평가",
    "rag_currentKb": "현재 KB",
    "rag_all": "전체",
    "rag_tab_bases": "지식베이스",
    "rag_tab_chat": "채팅",
    "rag_tab_search": "검색",
    "rag_tab_config": "설정",
    "rag_log_title": "RAG 호출 로그",
    "rag_log_total": "총 호출",
    "rag_log_successRate": "성공률",
    "rag_log_avgLatency": "평균 지연",
    "rag_log_search": "검색",
    "rag_log_ask": "Q&A",
    "rag_log_searchPh": "로그 검색...",
    "rag_log_opPicker": "작업",
    "rag_log_export": "CSV 내보내기",
    "rag_log_empty": "호출 로그 없음",
    "rag_log_h_time": "시간",
    "rag_log_h_kb": "KB",
    "rag_log_h_op": "작업",
    "rag_log_h_query": "쿼리",
    "rag_log_h_result": "결과",
    "rag_log_h_latency": "지연",
    "rag_log_h_status": "상태",
    "rag_log_exportTitle": "RAG 호출 로그 내보내기",
    "rag_log_exportDescFmt": "필터링된 %d건의 로그를 CSV로 내보내기",
    "rag_log_exportBtn": "내보내기",
    "rag_op_all": "전체",
    "rag_op_search": "검색",
    "rag_op_ask": "Q&A",
    "rag_op_ingest": "수집",
    "rag_op_delete": "삭제",
    "rag_op_watch": "모니터링",
    "rag_op_sync": "동기화",
    "rag_perm_title": "권한 관리",
    "rag_perm_authStatus": "인증 상태",
    "rag_perm_apiKeyAuth": "API Key 인증",
    "rag_perm_disabled": "비활성",
    "rag_perm_enabled": "활성",
    "rag_perm_activeKeys": "활성 키",
    "rag_perm_keyMgmt": "API Key 관리",
    "rag_perm_createKey": "키 생성",
    "rag_perm_noKey": "API Key 없음",
    "rag_perm_noKeyHint": "API Key 미설정 시 인증 비활성",
    "rag_perm_h_name": "이름",
    "rag_perm_h_hash": "키 해시",
    "rag_perm_h_createdAt": "생성 시간",
    "rag_perm_memberRole": "멤버 역할",
    "rag_perm_role_admin": "관리자",
    "rag_perm_role_admin_desc": "전체 읽기/쓰기, 키 관리, KB 삭제",
    "rag_perm_role_edit": "편집자",
    "rag_perm_role_edit_desc": "문서 업로드, 설정 수정, 재인덱스",
    "rag_perm_role_query": "조회자",
    "rag_perm_role_query_desc": "검색, RAG Q&A, 읽기 전용",
    "rag_perm_role_api": "API 호출",
    "rag_perm_role_api_desc": "API Key로만 검색/Q&A 호출",
    "rag_perm_audit": "감사 로그",
    "rag_perm_auditNote": "업스트림 API에 감사 로그 엔드포인트 없음, Issue 필요",
    "rag_perm_createTitle": "API Key 생성",
    "rag_perm_keyNamePh": "키 이름",
    "rag_perm_keyCreated": "키 생성됨 (한 번만 표시)",
    "rag_perm_createBtn": "생성",
    "rag_emb_title": "임베딩 모델 설정",
    "rag_emb_model": "임베딩 모델",
    "rag_emb_modelName": "모델 이름",
    "rag_emb_runMode": "실행 방식",
    "rag_emb_localMlx": "로컬 MLX 추론",
    "rag_emb_dim768": "768차원",
    "rag_emb_multilang": "다국어",
    "rag_emb_chunkStrategy": "청킹 전략",
    "rag_emb_strategyPicker": "전략",
    "rag_emb_chunkSize": "청크 크기",
    "rag_emb_overlap": "오버랩",
    "rag_emb_strategy_semantic": "의미론적",
    "rag_emb_strategy_fixed": "고정",
    "rag_emb_strategy_code": "코드",
    "rag_emb_strategy_sentence": "문장",
    "rag_emb_tip_semantic": "의미 경계로 분할, 자연어 문서용",
    "rag_emb_tip_fixed": "고정 토큰 수, 균일 콘텐츠용",
    "rag_emb_tip_code": "AST 함수/클래스 경계, 코드용",
    "rag_emb_tip_sentence": "문장 경계로 분할, 짧은 텍스트용",
    "rag_emb_context": "컨텍스트 강화",
    "rag_emb_contextToggle": "Contextual Retrieval (컨텍스트 검색 강화)",
    "rag_emb_contextDesc": "각 청크별 컨텍스트 요약 생성으로 검색 정확도 향상. Fusion-RAG 독점: 로컬 MLX 생성, 클라우드 API 불필요.",
    "rag_emb_saved": "✓ 설정 저장됨",
    "rag_emb_reset": "기본값 복원",
    "rag_vec_title": "벡터 스토어 운영",
    "rag_vec_syncAlertTitle": "증분 동기화 확인",
    "rag_vec_syncAlertBtn": "동기화",
    "rag_vec_syncAlertMsg": "지식 베이스 디렉토리에 증분 동기화를 실행하여 파일 변경을 감지하고 다시 인덱싱합니다. 계속하시겠습니까?",
    "rag_vec_createSnapTitle": "버전 스냅샷 생성",
    "rag_vec_snapDescPh": "스냅샷 설명（선택）",
    "rag_vec_create": "생성",
    "rag_vec_svcLabel": "서비스 상태",
    "rag_vec_embEngine": "임베딩 엔진",
    "rag_vec_avail": "사용 가능",
    "rag_vec_unavail": "사용 불가",
    "rag_vec_kbCount": "지식 베이스 수",
    "rag_vec_vecStatsLabel": "벡터 통계",
    "rag_vec_docCount": "문서 수",
    "rag_vec_chunkCount": "청크 수",
    "rag_vec_vecCount": "벡터 수",
    "rag_vec_fileCount": "파일 수",
    "rag_vec_selectKbHint": "먼저 지식 베이스를 선택하세요",
    "rag_vec_opsLabel": "운영 작업",
    "rag_vec_opSync": "증분 동기화",
    "rag_vec_opSyncDesc": "파일 변경 감지 후 재인덱싱",
    "rag_vec_opSnap": "스냅샷 생성",
    "rag_vec_opSnapDesc": "현재 지식 베이스 상태를 버전 스냅샷에 저장",
    "rag_vec_opHealth": "헬스 체크",
    "rag_vec_opHealthDesc": "벡터 스토어 및 임베딩 서비스 상태 확인",
    "rag_vec_opRefresh": "통계 새로고침",
    "rag_vec_opRefreshDesc": "지식 베이스 통계 정보 재조회",
    "rag_vec_snapLabel": "버전 스냅샷",
    "rag_vec_snapCountFmt": "%d개 스냅샷",
    "rag_vec_snapEmpty": "스냅샷이 없습니다.「스냅샷 생성」을 클릭하여 현재 지식 베이스 상태를 저장하세요",
    "rag_vec_snapNote": "버전 스냅샷은 Fusion-RAG가 Claude RAG 대비 핵심 경쟁력입니다: 시점 롤백, 증분 비교, 데이터 복구 지원.",
    "rag_vec_snapFallback": "스냅샷",
    "rag_vec_rollback": "롤백",
    "rag_vec_syncing": "동기화 중...",
    "rag_vec_syncDoneFmt": "✓ 동기화 완료: %d 파일 업데이트",
    "rag_vec_syncFail": "✗ 동기화 실패",
    "rag_vec_creatingSnap": "스냅샷 생성 중...",
    "rag_vec_snapDoneFmt": "✓ 스냅샷 생성됨: %@",
    "rag_vec_snapFail": "✗ 스냅샷 생성 실패",
    "rag_vec_rollingBack": "롤백 중...",
    "rag_vec_rollbackDoneFmt": "✓ 스냅샷 %@(으)로 롤백",
    "rag_vec_rollbackFail": "✗ 롤백 실패",
    "rag_vec_svcHealthy": "✓ 서비스 정상",
    "rag_vec_svcUnhealthy": "✗ 서비스 이상",
    "rag_dash_kbTitle": "지식 베이스",
    "rag_dash_newBtn": "새로 만들기",
    "rag_dash_svcHealthy": "Fusion-RAG 서비스 정상",
    "rag_dash_svcUnhealthy": "Fusion-RAG 서비스 사용 불가",
    "rag_dash_kbCountFmt": "%d개 지식 베이스",
    "rag_dash_emptyTitle": "지식 베이스 없음",
    "rag_dash_createKb": "지식 베이스 생성",
    "rag_dash_namePh": "이름",
    "rag_dash_descPh": "설명",
    "rag_dash_chunkStrategyPh": "청크 전략",
    "rag_dash_embedModelPh": "임베딩 모델",
    "rag_dash_create": "생성",
    "rag_dash_scanTitle": "디렉토리 스캔 가져오기",
    "rag_dash_kbPrefix": "지식 베이스: %@",
    "rag_dash_dirPathPh": "디렉토리 경로",
    "rag_dash_scanBtn": "스캔 시작",
    "rag_dash_statFile": "파일",
    "rag_dash_statChunk": "청크",
    "rag_dash_statVec": "벡터",
    "rag_dash_enterBtn": "열기",
    "rag_dash_importBtn": "가져오기",
    "rag_dash_chatMenu": "RAG 채팅",
    "rag_dash_scanMenu": "디렉토리 스캔",
    "rag_file_searchPh": "파일 검색...",
    "rag_file_watchBtn": "모니터링",
    "rag_file_addFileBtn": "파일 추가",
    "rag_file_selectKbHint": "먼저 지식 베이스를 선택하세요",
    "rag_file_emptyDoc": "문서 없음",
    "rag_file_h_name": "파일명",
    "rag_file_h_type": "유형",
    "rag_file_h_size": "크기",
    "rag_file_h_chunk": "청크",
    "rag_file_h_status": "상태",
    "rag_file_indexed": "인덱싱됨",
    "rag_file_watchLabel": "파일 모니터링",
    "rag_file_watchEmpty": "활성 모니터링 없음",
    "rag_file_watchFileFmt": "%d개 파일 모니터링",
    "rag_file_changesFmt": "%d회 변경",
    "rag_file_lastReindexFmt": "마지막 재구축: %@",
    "rag_file_stopBtn": "중지",
    "rag_file_addFileTitle": "파일 추가",
    "rag_file_addFilePathPh": "파일 경로（쉼표로 여러 개 구분）",
    "rag_file_addBtn": "추가",
    "rag_file_watchTitle": "파일 모니터링 설정",
    "rag_file_watchPathPh": "파일 경로（쉼표 구분）",
    "rag_file_pollInterval": "폴링 간격(초)",
    "rag_file_startWatchBtn": "모니터링 시작",
    "rag_srch_title": "검색 전략 설정",
    "rag_srch_presetLabel": "시나리오 프리셋",
    "rag_srch_preset_general": "일반",
    "rag_srch_preset_code": "코드",
    "rag_srch_preset_design": "디자인",
    "rag_srch_presetDesc_general": "일반: 희소+밀집 검색 균형, 문서 Q&A에 적합",
    "rag_srch_presetDesc_code": "코드: 희소 가중치 향상（BM25 정확한 함수명 매치）, 쿼리 분해 활성화",
    "rag_srch_presetDesc_design": "디자인: 밀집 가중치 향상（설명 의미 이해）, 쿼리 확장 활성화",
    "rag_srch_weightLabel": "검색 가중치",
    "rag_srch_hybridToggle": "하이브리드 검색（BM25 + 벡터 RRF）",
    "rag_srch_sparseLabel": "희소 검색（BM25）",
    "rag_srch_denseLabel": "밀집 검索（벡터）",
    "rag_srch_alphaLabel": "하이브리드 Alpha（RRF 가중치）",
    "rag_srch_rerankToggle": "재랭킹（Rerank）",
    "rag_srch_rerankTip": "재랭킹은 BGE-Reranker로 초기 결과를 재점수화하여 Top-5 정확도를 크게 향상",
    "rag_srch_paramsLabel": "검색 매개변수",
    "rag_srch_topKLabel": "Top-K 반환 수",
    "rag_srch_thresholdLabel": "유사도 임계값",
    "rag_srch_rewriteCard": "쿼리 재작성",
    "rag_srch_rewriteModePicker": "재작성 모드",
    "rag_srch_rewriteDesc_none": "쿼리 재작성 없음, 원본 쿼리 그대로 사용",
    "rag_srch_rewriteDesc_expand": "쿼리 확장: 동의 표현 생성으로 재현율 향상",
    "rag_srch_rewriteDesc_decompose": "쿼리 분해: 복잡한 쿼리를 하위 질문으로 분할해 개별 검색",
    "rag_srch_rewriteDesc_hyde": "HyDE: 먼저 LLM으로 가정 답변을 생성한 뒤 그 답변으로 검색",
    "rag_srch_testLabel": "검색 테스트",
    "rag_srch_testQueryPh": "테스트 쿼리 입력...",
    "rag_srch_testBtn": "테스트",
    "rag_srch_rw_none": "없음",
    "rag_srch_rw_expand": "확장",
    "rag_srch_rw_decompose": "분해",
    "rag_srch_rw_hyde": "HyDE",
    "rag_bench_title": "검색 성능 평가",
    "rag_bench_adv_local": "로컬 오프라인 벡터",
    "rag_bench_adv_ast": "코드 AST 파싱",
    "rag_bench_adv_rrf": "하이브리드 검색 RRF",
    "rag_bench_adv_context": "Contextual Retrieval",
    "rag_bench_adv_sync": "증분 동기화",
    "rag_bench_adv_snap": "버전 스냅샷",
    "rag_bench_presetLabel": "평가 프리셋",
    "rag_bench_preset_standard": "표준 평가",
    "rag_bench_preset_code": "코드 검색",
    "rag_bench_preset_design": "디자인 검색",
    "rag_bench_customQueryLabel": "커스텀 평가 세트",
    "rag_bench_customEmpty": "+를 클릭해 평가 쿼리와 기대 문서를 추가",
    "rag_bench_addQueryTitle": "평가 쿼리 추가",
    "rag_bench_queryPh": "쿼리 텍스트",
    "rag_bench_expectedPh": "기대 문서명",
    "rag_bench_addBtn": "추가",
    "rag_bench_runBtn": "평가 실행",
    "rag_bench_hitRateFmt": "Top-5 적중률: %@",
    "rag_bench_clearResultsBtn": "결과 지우기",
    "rag_bench_resultsLabel": "평가 결과",
    "rag_bench_resultsEmpty": "「평가 실행」을 클릭해 시작",
    "rag_bench_miniHit": "적중",
    "rag_bench_miniLatency": "평균 레이턴시",
    "rag_bench_miniTopScore": "최고 점수",
    "rag_bench_historyLabel": "평가 기록",
    "rag_bench_historyEmpty": "평가 기록 없음",
    "fsb_cv_node_start": "시작",
    "fsb_cv_node_connector": "커넥터",
    "fsb_cv_node_skill": "스킬",
    "fsb_cv_node_condition": "조건",
    "fsb_cv_node_approval": "승인",
    "fsb_cv_node_output": "출력",
    "fsb_cv_node_end": "종료",
    "fsb_cv_wfName": "워크플로 이름",
    "fsb_cv_autoLayout": "자동 레이아웃",
    "fsb_cv_running": "실행 중...",
    "fsb_cv_testRun": "테스트 실행",
    "fsb_cv_saving": "저장 중...",
    "fsb_cv_nodeTypes": "노드 유형",
    "fsb_cv_hintDrag": "팁: 노드를 캔버스로 드래그",
    "fsb_cv_hintRightClick": "우클릭으로 노드 추가",
    "fsb_cv_hintConnect": "포트를 드래그해 연결",
    "fsb_cv_nodeName": "노드 이름",
    "fsb_cv_deleteNode": "노드 삭제",
    "fsb_cv_connector": "커넥터",
    "fsb_cv_selectConnector": "커넥터 선택",
    "fsb_cv_notSelected": "미선택",
    "fsb_cv_action": "액션",
    "fsb_cv_skill": "스킬",
    "fsb_cv_selectSkill": "스킬 선택",
    "fsb_cv_promptTpl": "프롬프트 템플릿",
    "fsb_cv_conditionExpr": "조건식",
    "fsb_cv_conditionHint": "True 분기는 아래로, False 분기는 오른쪽으로",
    "fsb_cv_approvalConfig": "승인 설정",
    "fsb_cv_approvalMode": "승인 모드",
    "fsb_cv_writeOnly": "쓰기 전용 (권장)",
    "fsb_cv_allOps": "모든 작업",
    "fsb_cv_approvalNote": "승인 메모",
    "fsb_cv_timeoutFmt": "시간 초과: %ds",
    "fsb_cv_outputFormat": "출력 형식",
    "fsb_cv_format": "형식",
    "fsb_cv_plainText": "일반 텍스트",
    "fsb_cv_addNode": "노드 추가",
    "fsb_cv_newWorkflow": "새 워크플로",
    "mn_kv_title": "KV 캐시",
    "mn_kv_subtitle": "클러스터 KV 캐시 관리, 적중률 및 노드 분포 확인",
    "mn_kv_totalEntries": "총 항목",
    "mn_kv_cacheEntries": "캐시 항목 수",
    "mn_kv_totalSize": "총 크기",
    "mn_kv_cacheSpace": "캐시 점유 공간",
    "mn_kv_hitRate": "적중률",
    "mn_kv_hitRateSub": "KV 캐시 적중",
    "mn_kv_findCache": "캐시 찾기",
    "mn_kv_searchPh": "모델 이름으로 KV 캐시 찾기...",
    "mn_kv_findBtn": "찾기",
    "mn_kv_notFoundFmt": "이 모델의 KV 캐시를 찾을 수 없습니다: %@",
    "mn_kv_hwTitle": "Agent 하드웨어",
    "mn_kv_node": "노드",
    "mn_kv_memory": "메모리",
    "mn_kv_device": "장치",
    "mn_kv_agentOnline": "Agent 온라인",
    "mn_kv_agentOffline": "Agent 오프라인",
    "mn_kv_checking": "확인 중...",
    "mn_kv_warmTitle": "KV 워밍업",
    "mn_kv_modelName": "모델 이름",
    "mn_kv_warmPrompt": "워밍업 프롬프트",
    "mn_kv_warmBtn": "워밍업",
    "mn_kv_warmedFmt": "%d개 캐시 항목 워밍업 완료",
    "mn_kv_transferTitle": "KV 이전",
    "mn_kv_targetNode": "대상 노드 ID",
    "mn_kv_transferBtn": "이전",
    "mn_kv_byModelTitle": "모델별 분포",
    "mn_kv_countFmt": "%d개",
    "mn_task_title": "작업 모니터",
    "mn_task_subtitle": "작업 실행 상태 및 진행 상황 실시간 추적",
    "mn_task_tab_all": "전체",
    "mn_task_tab_running": "실행 중",
    "mn_task_tab_completed": "완료",
    "mn_task_tab_failed": "실패",
    "mn_task_migrateTitle": "작업 이전",
    "mn_task_taskId": "작업 ID",
    "mn_task_targetNode": "대상 노드",
    "mn_task_selectNode": "선택하세요",
    "mn_task_confirmMigrate": "이전 확인",
    "mn_task_total": "총 작업",
    "mn_task_allTasks": "전체 작업",
    "mn_task_running": "실행 중",
    "mn_task_executing": "실행 중",
    "mn_task_failed": "실패",
    "mn_task_needsAttention": "주의 필요",
    "mn_task_listTitleFmt": "작업 목록 (%d)",
    "mn_task_searchPh": "작업 검색...",
    "mn_task_cancelTask": "작업 취소",
    "mn_task_degradeTask": "작업 강등",
    "mn_task_migrateTask": "작업 이전",
    "mn_task_emptyFmt": "%@ 작업 없음",
    "mn_sync_title": "클러스터 동기화",
    "mn_sync_subtitle": "모델 증분 동기화 및 클러스터 파티션 상태",
    "mn_sync_partitionState": "파티션 상태",
    "mn_sync_partitionNodes": "파티션 노드",
    "mn_sync_isDegraded": "강등 여부",
    "mn_sync_degraded": "강등 중",
    "mn_sync_normal": "정상",
    "mn_sync_syncAvailable": "동기화 가능",
    "mn_sync_available": "가능",
    "mn_sync_unavailable": "불가능",
    "mn_sync_incrementalTitle": "증분 동기화",
    "mn_sync_modelName": "모델 이름",
    "mn_sync_modelPh": "예: Qwen2.5-7B-Instruct",
    "mn_sync_sourceHost": "소스 노드 Host",
    "mn_sync_sourcePort": "소스 포트",
    "mn_sync_syncing": "동기화 중...",
    "mn_sync_triggerBtn": "동기화 트리거",
    "mn_sync_manifestTitle": "모델 Manifest",
    "mn_sync_manifestPh": "모델 이름으로 Manifest 확인",
    "mn_sync_viewBtn": "보기",
    "mn_sync_upToDateFmt": "모델 %@ 최신 상태",
    "mn_sync_syncDoneFmt": "동기화 완료: %d개 파일 업데이트",
    "mn_sync_syncFailFmt": "동기화 실패: %@",
    "mn_route_title": "라우팅 전략",
    "mn_route_subtitle": "클러스터 작업 라우팅 전략 및 로드 밸런싱 설정",
    "mn_route_currentTitle": "현재 전략",
    "mn_route_strategy": "라우팅 전략",
    "mn_route_applyBtn": "전략 적용",
    "mn_route_loadTitle": "노드 부하 분포",
    "mn_route_avgLoad": "평균 부하",
    "mn_route_updatedFmt": "전략이 %@로 업데이트되었습니다",
    "mn_route_desc_least_loaded": "부하가 가장 낮은 노드 우선 할당",
    "mn_route_desc_round_robin": "각 노드에 라운드로빈 할당",
    "mn_route_desc_random": "노드 무작위 선택",
    "mn_route_desc_capability_aware": "노드 능력과 작업 요건 매칭",
    "mn_alert_title": "알림 센터",
    "mn_alert_subtitle": "클러스터 이상 감지 및 스마트 제안",
    "mn_alert_tab_active": "활성 알림",
    "mn_alert_tab_suggestions": "스마트 제안",
    "mn_alert_tab_history": "알림 기록",
    "mn_alert_exportBtn": "로그 내보내기",
    "mn_alert_activeTitleFmt": "활성 알림 (%d)",
    "mn_alert_activeEmpty": "활성 알림 없음, 클러스터 정상 작동 중",
    "mn_alert_suggestTitleFmt": "스마트 제안 (%d)",
    "mn_alert_suggestEmpty": "최적화 제안 없음",
    "mn_alert_historyTitle": "알림 기록",
    "mn_alert_historyEmpty": "알림 기록 없음",
    "mn_alert_ackBtn": "확인",
    "mn_err_invalidURL": "잘못된 URL",
    "mn_err_noData": "반환된 데이터 없음",
    "mn_overview_title": "클러스터 개요",
    "mn_overview_subtitle": "클러스터 노드 상태와 리소스 실시간 모니터링",
    "mn_overview_disconnectedFmt": "Multi-Node 서비스 미연결 — 서비스 실행 확인 (port %d)",
    "mn_overview_metricNodes": "노드",
    "mn_overview_metricTotal": "합계",
    "mn_overview_metricOnline": "온라인",
    "mn_overview_metricOnlineRun": "온라인 실행",
    "mn_overview_metricActiveTasks": "활성 작업",
    "mn_overview_metricExecuting": "실행 중",
    "mn_overview_metricClusterMem": "클러스터 메모리",
    "mn_overview_metricTotalMemFmt": "합계 %@GB",
    "mn_overview_submitTaskBtn": "작업 제출",
    "mn_overview_searchPh": "노드 검색...",
    "mn_overview_nodeListFmt": "노드 목록 (%d)",
    "mn_overview_viewMetrics": "메트릭스 보기",
    "mn_overview_removeNode": "노드 제거",
    "mn_overview_degradedFmt": "클러스터 성능 저하 상태 — 파티션: %@",
    "mn_overview_normalFmt": "클러스터 동기 정상 — 파티션: %@",
    "mn_overview_detailLink": "상세",
    "mn_submit_title": "작업 제출",
    "mn_submit_subtitle": "클러스터에 새 추론 또는 계산 작업 제출",
    "mn_submit_configTitle": "작업 설정",
    "mn_submit_taskNameLabel": "작업 이름",
    "mn_submit_taskNameSub": "작업을 식별하는 설명 이름",
    "mn_submit_taskNamePh": "예: llama-inference-batch",
    "mn_submit_execModeLabel": "실행 모드",
    "mn_submit_execModeSub": "pipeline=파이프라인, data_parallel=데이터 병렬, inference=단일 노드 추론",
    "mn_submit_modelLabel": "모델 이름",
    "mn_submit_modelSub": "대상 추론 모델",
    "mn_submit_modelPh": "예: mlx-community/Llama-3.2-1B",
    "mn_submit_priorityLabel": "우선순위",
    "mn_submit_prioritySub": "1=최저, 10=최고",
    "mn_submit_capabilityLabel": "필요 역량",
    "mn_submit_capabilitySub": "선택: 예 gpu, high_memory 등",
    "mn_submit_capabilityPh": "선택",
    "mn_submit_submitBtn": "제출",
    "mn_submit_successFmt": "작업 제출됨 (ID: %@)",
    "mn_node_title": "노드 작업",
    "mn_node_subtitle": "탄성 스케일링 설정과 노드 관리",
    "mn_node_autoscalerTitle": "Autoscaler 탄성 설정",
    "mn_node_mgmtTitle": "노드 관리",
    "mn_node_removeBtn": "제거",
    "mn_node_emptyNodes": "노드 없음",
    "mn_node_minNodes": "최소 노드",
    "mn_node_maxNodes": "최대 노드",
    "mn_node_scaleUpThreshold": "스케일업 임계값",
    "mn_node_scaleDownThreshold": "스케일다운 임계값",
    "mn_node_cooldownLabel": "쿨다운 (s)",
    "mn_node_strategyLabel": "전략",
    "mn_node_applying": "적용 중...",
    "mn_node_applyBtn": "설정 적용",
    "mn_node_pendingTitle": "승인 대기 노드",
    "mn_node_pendingEmpty": "대기 중인 노드 없음",
    "mn_node_approveBtn": "승인",
    "mn_node_rejectBtn": "거부",
    "mn_progress_title": "작업 상세",
    "mn_progress_subtitle": "작업 진행률, 타임라인, 하위 작업 상태 보기",
    "mn_progress_selectTaskTitle": "작업 선택",
    "mn_progress_taskPicker": "작업",
    "mn_progress_inspectorSelect": "Inspector에서 선택",
    "mn_progress_loadDetailsBtn": "상세 불러오기",
    "mn_progress_execProgressTitle": "실행 진행률",
    "mn_progress_remainingFmt": "남은 시간 %@",
    "mn_progress_timelineTitle": "타임라인",
    "mn_progress_subTasksFmt": "하위 작업 (%d)",
    "mn_progress_emptyHint": "작업 모니터 패널에서 작업을 선택하거나 위 드롭다운에서 선택",
    "mn_progress_loadFailFmt": "진행률 로드 실패: %@",
    "mn_web_title": "서비스 패널",
    "mn_web_subtitle": "WebView로 외부 서비스 UI 임베드",
    "mn_web_tab_docs": "Master API",
    "mn_web_tab_bench": "벤치마크",
    "mn_web_tab_security": "보안",
    "mn_web_docsDescFmt": "FastAPI 자동 문서 — fusion-multi-node Master 서비스 실행 필요 (포트 %d)",
    "mn_web_benchDesc": "벤치마크 패널 — fusion-bench bench-site 실행 필요 (포트 3000, npm run dev)",
    "mn_web_securityDesc": "보안 감사 패널 — fusion-security 프론트엔드 실행 필요 (포트 3000)",
    "mn_web_connectingFmt": "%@ 에 연결 중...",
    "mn_web_loadFailFmt": "%@ 로드 실패",
    "mn_web_retryBtn": "재시도",
    "mn_topo_title": "토폴로지",
    "mn_topo_subtitle": "Master-Worker 연결 관계 시각화",
    "mn_topo_legendOnline": "온라인",
    "mn_topo_legendBusy": "사용 중",
    "mn_topo_legendOffline": "오프라인",
    "mn_topo_legendFault": "장애",
    "mn_topo_statsFmt": "%d 노드 · 온라인율 %d%%",
    "mn_node_statusA11yFmt": "노드 %@",
    "mn_task_degradedFmt": "다운그레이드: %@→%@",
    "design_swiftUITitle": "SwiftUI 내보내기",
    "design_codegenTitle": "코드 내보내기",
    "design_copy": "복사",
    "design_close": "닫기",
    "design_helpPageMgmt": "페이지 관리",
    "design_helpCopyCode": "코드 복사 (⇧⌘C)",
    "design_helpExportCode": "코드 내보내기 (⇧⌘E)",
    "design_helpClear": "대화 비우기",
    "design_welcomeDesc": "디자인할 화면을 설명하면 AI가 인터랙티브 코드를 생성합니다",
    "design_inputPh": "디자인할 화면을 설명...",
    "design_emptyTitle": "디자인할 화면을 설명",
    "design_emptyDesc": "AI가 인터랙티브 HTML 코드를 생성하고 우측에 실시간 미리보기",
    "design_clearInput": "입력 비우기",
    "design_clearConv": "대화 비우기",
    "design_copyCurrentCode": "현재 코드 복사",
    "design_helpSave": "저장",
    "design_helpCopy": "코드 복사",
    "design_helpHistory": "기록",
    "design_helpSwiftUI": "SwiftUI 내보내기",
    "design_helpStop": "정지",
    "design_helpSend": "전송",
    "design_roleUser": "나",
    "design_roleDesigner": "디자이너",
    "design_parsedFmt": "파싱됨: %@",
    "design_noVersions": "버전 기록 없음",
    "design_rollback": "롤백",
    "design_errMLXNotRunning": "MLX 서비스가 실행 중이 아닙니다. MLX 패널에서 서비스를 시작한 후 전송하세요",
    "design_errNoModel": "대화 모델이 선택되지 않았습니다. 상단 모델 선택기에서 모델을 선택한 후 전송하세요",
    "design_marqueeFmt": "%d개 노드 선택됨",
    "design_previewFmt": "미리보기: %@",
    "design_previewHint": "AI 제안 변경, 확인 후 캔버스에 적용",
    "design_reject": "거부",
    "design_accept": "확인",
    "design_pages": "페이지",
    "design_newPage": "새 페이지",
    "design_noPages": "페이지 없음, 디자인 생성 후 자동 생성",
    "design_deletePage": "페이지 삭제",
    "design_batchExport": "일괄 내보내기",
    "design_exporting": "내보내는 중...",
    "design_selectFormat": "내보내기 형식 선택",
    "design_skillUseFmt": "%@ 스킬 사용: %@",
    "design_stepConnecting": "연결 중...",
    "design_stepGenerating": "추론 중...",
    "design_stepStreaming": "생성 중...",
    "design_stepRendering": "캔버스 렌더링...",
    "design_stepConnShort": "연결",
    "design_stepGenShort": "추론",
    "design_stepStreamShort": "생성",
    "design_stepRenderShort": "렌더링",
    "design_grp_pages": "페이지",
    "design_grp_components": "컴포넌트",
    "design_grp_skills": "AI 스킬",
    "design_tpl_login": "로그인 페이지",
    "design_tpl_dashboard": "대시보드",
    "design_tpl_landing": "랜딩 페이지",
    "design_tpl_settings": "설정 페이지",
    "design_tpl_chat": "채팅 화면",
    "design_tpl_profile": "프로필 페이지",
    "design_tpl_card": "카드 컴포넌트",
    "design_tpl_form": "폼",
    "design_tpl_table": "데이터 테이블",
    "design_tpl_nav": "내비게이션",
    "design_tpl_modal": "모달/다이얼로그",
    "design_tpl_buttons": "버튼 그룹",
    "design_tpl_textToUI": "텍스트를 UI로",
    "design_tpl_imageToUI": "이미지를 UI로",
    "design_tpl_partialEdit": "부분 편집",
    "design_tpl_localEdit": "정밀 수정",
    "design_tpl_simPanel": "유사 패널",
    "design_tpl_multiVariants": "다중 변형",
    "design_tpl_specDoc": "사양 문서",
    "design_tpl_pageFlow": "페이지 흐름",
    "design_ds_compLibrary": "컴포넌트 라이브러리",
    "design_ds_searchCompPh": "컴포넌트 검색...",
    "design_ds_catAll": "전체",
    "design_ds_template": "템플릿",
    "design_ds_sizeSM": "소",
    "design_ds_sizeMD": "중",
    "design_ds_sizeLG": "대",
    "design_ds_cat_button": "버튼",
    "design_ds_cat_card": "카드",
    "design_ds_cat_input": "입력",
    "design_ds_cat_select": "선택",
    "design_ds_cat_modal": "모달",
    "design_ds_cat_nav": "내비게이션",
    "design_ds_cat_table": "테이블",
    "design_ds_cat_chart": "차트",
    "design_ds_cat_form": "폼",
    "design_ds_desc_button": "다양한 스타일 변형과 크기를 지원하는 액션 버튼 컴포넌트",
    "design_ds_desc_card": "표준/아웃라인/피처드 스타일을 지원하는 콘텐츠 카드 컴포넌트",
    "design_ds_desc_input": "다양한 입력 타입을 지원하는 텍스트 입력 컴포넌트",
    "design_ds_desc_select": "단일/다중 선택을 지원하는 드롭다운 선택 컴포넌트",
    "design_ds_desc_modal": "정보/확인/폼 모드를 지원하는 모달 컴포넌트",
    "design_ds_desc_nav": "상단 바/사이드바/탭을 지원하는 내비게이션 컴포넌트",
    "design_ds_desc_table": "기본/정렬/페이지네이션을 지원하는 데이터 테이블 컴포넌트",
    "design_ds_desc_chart": "선형/막대/파이 차트를 지원하는 차트 컴포넌트",
    "design_ds_desc_form": "로그イン/가입/문의 폼을 지원하는 폼 컴포넌트",
    "design_lint_title": "린트 검사",
    "design_lint_ruleLock": "규칙 잠금",
    "design_lint_run": "린트 실행",
    "design_lint_genDocFirst": "먼저 설계 문서를 생성하세요",
    "design_lint_noResult": "린트가 결과를 반환하지 않았습니다",
    "design_lint_noViolation": "위반 없음",
    "design_lint_errCountFmt": "%d 오류",
    "design_lint_warnCountFmt": "%d 경고",
    "design_lint_infoCountFmt": "%d 정보",
    "design_lint_violationCountFmt": "%d건 위반",
    "design_lint_nodeFmt": "노드: %@",
    "design_lint_rule_contrastCheck": "대비 검사",
    "design_lint_rule_unlabeledInput": "라벨 없는 입력",
    "design_lint_rule_textEffects": "텍스트 효과",
    "design_lint_rule_abnormalRotation": "비정상 회전",
    "design_lint_rule_emptyEffects": "빈 효과",
    "design_lint_rule_tokenInconsistency": "Token 불일치",
    "design_lint_rule_unnamedNode": "이름 없는 노드",
    "design_lint_rule_textOverflow": "텍스트 오버플로우",
    "design_lint_rule_overlappingNodes": "노드 겹침",
    "design_lint_rule_hardcodedSpacing": "하드코딩된 간격",
    "design_lint_rule_hardcodedFontSize": "하드코딩된 글꼴 크기",
    "design_lint_rule_missingInteractionState": "상호작용 상태 누락",
    "design_lint_rule_layoutInconsistency": "레이아웃 불일치",
    "design_lint_lockTitle": "설계 규칙 잠금",
    "design_lint_done": "완료",
    "design_lint_lockHint": "잠긴 규칙은 린트 시 무視되며 위반은 표시되지 않습니다",
    "design_lint_lockedCountFmt": "%d건 규칙 잠김",
    "design_lint_unlockAll": "모두 잠금 해제",
    "design_eco_tabSync": "코드 동기화",
    "design_eco_tabTpl": "템플릿 라이브러리",
    "design_eco_syncToCode": "정방향 동기화 → Fusion Code",
    "design_eco_compName": "컴포넌트 이름",
    "design_eco_syncing": "동기화 중...",
    "design_eco_syncCode": "코드 동기화",
    "design_eco_watchCode": "역방향 감시 ← Fusion Code",
    "design_eco_checking": "확인 중...",
    "design_eco_checkChange": "변경 확인",
    "design_eco_noMutation": "대기 중인 스타일 변경 없음",
    "design_eco_applyCanvas": "캔버스에 적용",
    "design_eco_saveAsTpl": "현재 설계를 템플릿으로 저장",
    "design_eco_tplNamePh": "템플릿 이름",
    "design_eco_tplTagsPh": "태그(쉼표 구분)",
    "design_eco_tplCatPh": "카테고리",
    "design_eco_save": "저장",
    "design_eco_searchTpl": "템플릿 검색",
    "design_eco_searchPh": "이름/태그/카테고리 검색",
    "design_eco_search": "검색",
    "design_eco_noMatchTpl": "일치하는 템플릿 없음",
    "design_eco_load": "불러오기",
    "design_eco_syncDone": "코드 동기화 완료",
    "design_eco_syncFailFmt": "동기화 실패: %@",
    "design_eco_appliedFmt": "%d건 스타일 변경 적용",
    "design_eco_tplSavedFmt": "템플릿 '%@' 저장됨",
    "design_eco_tplSaveFailFmt": "템플릿 저장 실패: %@",
    "design_eco_tplLoadedFmt": "템플릿 '%@' 불러옴",
    "design_theme_modeSystem": "시스템 따름",
    "design_theme_modeLight": "라이트",
    "design_theme_modeDark": "다ーク",
    "design_theme_modeCustom": "사용자 지정",
    "design_theme_title": "테마 전환",
    "design_theme_modeLabel": "외관 모드",
    "design_theme_customAccent": "사용자 지정 강조색",
    "design_theme_accentBlue": "파랑",
    "design_theme_accentRed": "빨강",
    "design_theme_accentGreen": "초록",
    "design_theme_accentOrange": "주황",
    "design_theme_accentPurple": "보라",
    "design_theme_accentPink": "분홍",
    "design_theme_preview": "미리보기",
    "design_theme_previewLight": "라이트",
    "design_theme_previewDark": "다ーク",
    "design_theme_reset": "기본값으로 재설정",
    "design_wf_recipe_designToCode": "Design → Code",
    "design_wf_recipe_codeToDesign": "Code → Design",
    "design_wf_recipe_screenshot": "Screenshot → Design → Code",
    "design_wf_recipe_designToCodeDesc": "Design 모듈에서 디자인을 생성하여 코드 파일로 내보내기",
    "design_wf_recipe_codeToDesignDesc": "기존 코드를 Design 모듈로 가져와 시각적 편집",
    "design_wf_recipe_screenshotDesc": "스크린샷을 캡처하고 AI로 디자인을 생성하여 코드로 내보내기",
    "design_wf_step_createDesign": "디자인 생성",
    "design_wf_step_previewDesign": "디자인 미리보기",
    "design_wf_step_exportToCode": "코드로 내보내기",
    "design_wf_step_openInEditor": "에디터에서 열기",
    "design_wf_step_selectCodeFile": "코드 파일 선택",
    "design_wf_step_importToDesign": "디자인으로 가져오기",
    "design_wf_step_editDesign": "디자인 편집",
    "design_wf_step_syncBack": "파일로 동기화",
    "design_wf_step_captureScreenshot": "스크린샷 캡처",
    "design_wf_step_analyzeScreenshot": "스크린샷 분석",
    "design_wf_step_generateDesign": "디자인 생성",
    "design_wf_startFmt": "워크플로 시작: %@",
    "design_wf_cancelled": "워크플로가 취소되었습니다",
    "design_wf_doneFmt": "✅ 워크플로 완료: %@",
    "design_wf_execFmt": "실행 중: %@",
    "design_wf_ssSaved": "스크린샷이 클립보드에 저장되었습니다. Design 채팅에 붙여넣으세요",
    "design_wf_canvasCleared": "캔버스가 비워졌습니다. 채팅에서 디자인을 설명하세요",
    "design_wf_previewing": "디자인 미리보는 중...",
    "design_wf_editHint": "채팅에서 수정 요청을 설명하세요",
    "design_wf_generating": "AI가 디자인 생성 중...",
    "design_wf_analyzing": "스크린샷을 분석하고 디자인을 생성하는 중...",
    "design_wf_noScreenshot": "클립보드에 스크린샷이 없습니다. 먼저 캡처하세요 (⌘⇧4)",
    "design_wf_selectCodeFile": "코드 파일 선택",
    "design_wf_selectedFmt": "선택됨: %@",
    "design_wf_notSelected": "파일이 선택되지 않았습니다",
    "design_wf_importedFmt": "가져옴: %@",
    "design_wf_importedDoc": "문서를 가져왔습니다",
    "design_wf_noFileSelected": "선택된 파일이 없습니다. 먼저 코드 파일을 선택하세요",
    "design_wf_panelTitle": "디자인 워크플로",
    "design_wf_cancelBtn": "워크플로 취소",
    "design_ins_sec_layout": "레이아웃",
    "design_ins_sec_spacing": "간격",
    "design_ins_sec_typography": "타이포그래피",
    "design_ins_sec_colors": "색상",
    "design_ins_sec_borders": "테두리",
    "design_ins_sec_effects": "효과",
    "design_ins_alignStart": "시작",
    "design_ins_alignCenter": "중앙",
    "design_ins_alignEnd": "끝",
    "design_ins_justifyBetween": "양끝 정렬",
    "design_ins_justifyAround": "균등 배치",
    "design_ins_alignStretch": "늘림",
    "design_ins_preset_card": "카드",
    "design_ins_preset_button": "버튼",
    "design_ins_preset_inputField": "입력 필드",
    "design_ins_preset_navBar": "내비게이션 바",
    "design_ins_preset_heroSection": "히어로 섹션",
    "design_ins_title": "스타일 검사기",
    "design_ins_presetLabel": "스타일 프리셋",
    "design_ins_layoutMode": "레이아웃 모드",
    "design_ins_direction": "방향",
    "design_ins_mainAxis": "주축",
    "design_ins_crossAxis": "교차축",
    "design_ins_width": "너비",
    "design_ins_height": "높이",
    "design_ins_padding": "패딩",
    "design_ins_margin": "마진",
    "design_ins_gap": "갭",
    "design_ins_fontFamily": "글꼴",
    "design_ins_fontSize": "글자 크기",
    "design_ins_fontWeight": "글자 굵기",
    "design_ins_lineHeight": "줄 높이",
    "design_ins_textAlign": "정렬",
    "design_ins_textColor": "문자 색상",
    "design_ins_bgColor": "배경색",
    "design_ins_borderColor": "테두리 색상",
    "design_ins_borderWidth": "테두리 두께",
    "design_ins_borderRadius": "모서리 둥글기",
    "design_ins_opacity": "불투명도",
    "design_ins_shadow": "그림자",
    "design_ins_overflow": "오버플로",
    "design_ins_cssOutput": "CSS 출력",
    "design_tok_preset_appleHIG": "Apple HIG",
    "design_tok_preset_adminMinimal": "미니멀 관리",
    "design_tok_preset_robotSim": "로봇 시뮬레이션",
    "design_tok_cat_colors": "색상",
    "design_tok_cat_spacing": "간격",
    "design_tok_cat_typography": "타이포그래피",
    "design_tok_cat_radius": "모서리 둥글기",
    "design_tok_cat_shadows": "그림자",
    "design_tok_cat_animation": "애니메이션",
    "design_tok_designSpec": "디자인 사양",
    "design_cv_menu_duplicate": "노드 복제",
    "design_cv_menu_delete": "노드 삭제",
    "design_cv_menu_toggleLock": "잠금/해제",
    "design_cv_menu_toggleVisibility": "숨기기/표시",
    "design_cv_menu_partialRepaint": "부분 다시 그리기",
    "design_cv_menu_bringToFront": "맨 앞으로",
    "design_cv_menu_sendToBack": "맨 뒤로",
    "design_cv_menu_selectAll": "모두 선택",
    "design_cv_menu_fitZoom": "줌 맞춤",
    "design_cv_menu_paste": "붙여넣기",
    "design_cg_targetLabel": "내보내기 대상",
    "design_cg_componentName": "컴포넌트 이름",
    "design_cg_generating": "생성 중...",
    "design_cg_generate": "코드 생성",
    "design_cg_copied": "복사됨",
    "design_cg_copy": "복사",
    "design_cg_emptyHint": "내보내기 대상 선택\n클릭하여 코드 생성",
    "design_cg_charCount": "문자",
    "design_cg_genFailFmt": "코드 생성 실패: %@",
    "design_cg_desc_html": "순 HTML + CSS 내보내기",
    "design_cg_desc_react": "React 컴포넌트 + Tailwind CSS",
    "design_cg_desc_tailwind": "순 Tailwind CSS 클래스명",
    "design_cg_desc_swiftui": "SwiftUI View 코드",
    "design_ds_title": "디자인 시스템",
    "design_ds_refresh": "새로고침",
    "design_ds_activeFmt": "현재 활성: %@",
    "design_ds_applyToCanvas": "캔버스에 적용",
    "design_ds_activateFailFmt": "활성화 실패: %@",
    "design_ds_listFailFmt": "디자인 시스템 목록 로드 실패: %@",
    "design_ds_name_appleHIG": "Apple HIG",
    "design_ds_name_adminMinimal": "미니멀 관리",
    "design_ds_name_robotSim": "로봇 시뮬레이션",
    "design_ds_desc_appleHIG": "Apple Human Interface Guidelines",
    "design_ds_desc_adminMinimal": "미니멀 스타일 관리",
    "design_ds_desc_robotSim": "산업 시뮬레이션 제어 패널",
    "design_ds_customDesc": "커스텀 디자인 시스템",
    "design_ly_title": "레이어",
    "design_ly_countFmt": "요소 %d개",
    "design_ly_empty": "레이어 없음",
    "design_ly_emptyHint": "AI 채팅으로 디자인 생성 후\n여기에 레이어가 표시됩니다",
    "design_avd_exportReview": "리뷰 내보내기",
    "design_ae_multiFormat": "다중 형식 내보내기",
    "design_ae_cancel": "취소",
    "design_ae_exportFmt": "%d 형식 내보내기",
    "design_cl_conflictFmt": "파일과 디자인이 최근 변경되어 파일 버전 채택: %@",
    "design_si_selectScreenshot": "스크린샷 파일 선택",
    "art_pc_open": "열기",
    "art_pc_copy": "복사",
    "art_pc_versionHistory": "버전 이력",
    "art_pc_share": "공유",
    "art_pc_unpin": "고정 해제",
    "art_pc_pin": "고정",
    "art_pc_duplicate": "복제",
    "art_pc_moveToKb": "프로젝트 KB로 이동",
    "art_pc_delete": "삭제",
    "art_pc_copySuffix": " (사본)",
    "art_sd_title": "아티팩트 공유",
    "art_sd_permission": "권한",
    "art_sd_permView": "보기 전용",
    "art_sd_permComment": "댓글 가능",
    "art_sd_permEdit": "편집 가능",
    "art_sd_expiry": "유효기간",
    "art_sd_exp1h": "1시간",
    "art_sd_exp1d": "1일",
    "art_sd_exp7d": "7일",
    "art_sd_exp30d": "30일",
    "art_sd_expNever": "만료 없음",
    "art_sd_generate": "공유 링크 생성",
    "art_sd_done": "완료",
    "art_sd_shareLink": "공유 링크",
    "art_sd_existingShares": "기존 공유 (%d)",
    "art_sd_expires": "만료: %@",
    "art_sd_revoke": "철회",
    "art_tf_tags": "태그",
    "art_tf_addTag": "태그 추가",
    "art_tf_folders": "폴더",
    "art_tf_noFolders": "사용 가능한 폴더 없음",
    "art_vh_rollbackConfirm": "롤백 확인?",
    "art_vh_rollback": "롤백",
    "art_vh_cancel": "취소",
    "art_vh_rollbackMsg": "v%d로 롤백, 현재 버전은 명명된 스냅샷으로 저장",
    "art_vh_createSnapshot": "스냅샷 생성",
    "art_vh_snapshotName": "스냅샷 이름",
    "art_vh_create": "생성",
    "art_vh_title": "버전 이력",
    "art_vh_empty": "버전 이력 없음",
    "art_vh_current": "현재",
    "art_vh_chars": "%d자",
    "art_vh_diffCurrent": "현재 버전과 비교",
    "art_vh_incremental": "증분 변경",
    "art_vh_noDiff": "차이 없음",
    "art_vh_diffFail": "diff 로드 실패: %@",
    "art_rv_sortUpdated": "최근 업데이트",
    "art_rv_sortCreated": "생성 시간",
    "art_rv_sortName": "이름",
    "art_rv_scopeAll": "전체",
    "art_rv_scopeMine": "내 것",
    "art_rv_scopeStarred": "별표",
    "art_rv_scopePinned": "고정됨",
    "art_rv_subtitle": "전역 아티팩트 저장소 — 세션 간 모든 아티팩트 관리",
    "art_rv_newFolder": "새 폴더",
    "art_rv_folderName": "폴더 이름",
    "art_rv_create": "생성",
    "art_rv_search": "아티팩트 검색…",
    "art_rv_typeAll": "전체",
    "art_rv_recycle": "휴지통",
    "art_rv_folders": "폴더",
    "art_rv_allArtifacts": "모든 아티팩트",
    "art_rv_rename": "이름 변경",
    "art_rv_delete": "삭제",
    "art_rv_retry": "재시도",
    "art_rv_empty": "아티팩트 없음",
    "art_rv_open": "열기",
    "art_rv_unstar": "별표 해제",
    "art_rv_star": "별표",
    "art_rv_copyContent": "내용 복사",
    "art_rv_download": "다운로드",
    "art_rv_copy": "복제",
    "art_rv_moveToKb": "프로젝트 KB로 이동",
    "art_rv_loadFail": "로드 실패: %@",
    "art_rb_title": "휴지통",
    "art_rb_purge": "만료 항목 비우기",
    "art_rb_empty": "휴지통이 비어 있음",
    "art_rb_restore": "복원",
    "art_cv_rename": "이름 변경",
    "art_cv_newName": "새 이름",
    "art_cv_confirm": "확인",
    "art_cv_cancel": "취소",
    "art_cv_deleteConfirm": "삭제 확인?",
    "art_cv_delete": "삭제",
    "art_cv_deleteMsg": "휴지통으로 이동, 복원 가능",
    "art_cv_unsaved": "저장되지 않은 변경사항",
    "art_cv_discard": "버리기",
    "art_cv_save": "저장",
    "art_cv_noPreview": "미리보기 없음",
    "art_cv_chars": "%d자",
    "art_cv_discardChanges": "변경사항 버리기",
    "art_cv_createSnapshot": "버전 스냅샷 생성",
    "art_cv_snapshotLabel": "스냅샷 라벨(선택)",
    "art_cv_create": "생성",
    "art_cv_sections": "%d 섹션",
    "art_cv_toc": "목차",
    "desk_tab_templates": "템플릿",
    "desk_tab_workflows": "워크플로",
    "desk_tab_agents": "에이전트",
    "desk_tab_sessions": "세션",
    "desk_tab_permissions": "권한",
    "desk_tab_mlx": "MLX",
    "desk_tab_system": "시스템",
    "desk_tab_events": "이벤트",
    "desk_close": "닫기",
    "desk_loading": "로딩 중...",
    "desk_name": "이름",
    "desk_category": "분류",
    "desk_description": "설명",
    "desk_create": "만들기",
    "desk_cancel": "취소",
    "desk_save": "저장",
    "desk_edit": "편집",
    "desk_delete": "삭제",
    "desk_status": "상태",
    "desk_refresh": "새로고침",
    "desk_svc_notConnected": "Fusion-CoWork 서비스 미연결",
    "desk_svc_notConnectedHint": "fusion-cowork 서비스를 시작한 후 재시도하세요 (터미널에서 ./start.sh start 실행, 또는 설정→업스트림 서비스에서 시작)",
    "desk_reconnect": "다시 연결",
    "desk_svc_notReady": "서비스 미준비",
    "desk_searchTemplates": "템플릿 검색...",
    "desk_tpl_count": "%d 템플릿",
    "desk_noTemplates": "템플릿 없음",
    "desk_tpl_detail": "템플릿 상세",
    "desk_steps": "단계",
    "desk_tpl_runResult": "템플릿 %@: %@",
    "desk_tpl_runFail": "템플릿 %@: 실행 실패",
    "desk_wf_promptPlaceholder": "자연어로 워크플로 생성...",
    "desk_wf_count": "%d 워크플로",
    "desk_wf_execStatus": "실행 상태",
    "desk_noWorkflows": "워크플로 없음, 프롬프트 입력하여 생성",
    "desk_wf_execStatusTitle": "워크플로 실행 상태",
    "desk_wf_noRunning": "실행 중인 워크플로 없음",
    "desk_wf_currentNode": "현재 노드: %@",
    "desk_agent_taskPlaceholder": "에이전트에 작업 제출...",
    "desk_submit": "제출",
    "desk_agent_count": "%d 에이전트",
    "desk_noAgents": "에이전트 없음",
    "desk_agent_id": "ID: %@",
    "desk_agent_taskSubmitted": "작업 %@ 제출됨",
    "desk_agent_viewStatus": "상태 보기",
    "desk_agent_status": "상태: %@",
    "desk_agent_progress": "진행률: %@",
    "desk_session_new": "새 세션",
    "desk_session_count": "%d 세션",
    "desk_noSessions": "세션 없음",
    "desk_session_steps": "단계: %d",
    "desk_session_fork": "분기",
    "desk_session_edit": "세션 편집",
    "desk_session_namePlaceholder": "세션 이름",
    "desk_session_detail": "세션 상세",
    "desk_session_stepCount": "단계 수",
    "desk_perm_rules": "권한 규칙",
    "desk_perm_checkTool": "도구 확인",
    "desk_perm_check": "확인",
    "desk_perm_resetAll": "모두 재설정",
    "desk_perm_checkResult": "도구 %@: %@",
    "desk_perm_allowed": "허용",
    "desk_perm_denied": "거부",
    "desk_perm_noRules": "권한 규칙 없음",
    "desk_perm_scope": "범위: %@",
    "desk_perm_toggle": "전환",
    "desk_mlx_status": "Fusion-MLX 상태",
    "desk_mlx_running": "실행 중",
    "desk_mlx_stopped": "중지됨",
    "desk_mlx_noModels": "사용 가능한 모델 없음",
    "desk_mlx_modelList": "모델 목록",
    "desk_mlx_modelCount": "%d 모델",
    "desk_mlx_runningTitle": "Fusion-MLX 실행 중",
    "desk_mlx_stoppedTitle": "Fusion-MLX 미시작",
    "desk_mlx_manageHint": "UpstreamServiceManager로 MLX 라이프사이클 관리",
    "desk_sys_info": "시스템 정보",
    "desk_sys_platform": "플랫폼",
    "desk_sys_cpuCores": "CPU 코어 수",
    "desk_sys_memoryTotal": "메모리 총량",
    "desk_sys_memoryUsed": "메모리 사용량",
    "desk_sys_diskFree": "디스크 여유",
    "desk_sys_nodeCategories": "노드 분류",
    "desk_sys_nodeList": "노드 목록",
    "desk_sys_loading": "시스템 정보 로딩 중...",
    "desk_sys_nodeDetail": "노드 상세",
    "desk_sys_inputs": "입력 매개변수",
    "desk_sys_outputs": "출력",
    "desk_evt_stream": "이벤트 스트림",
    "desk_evt_polling": "폴링 중",
    "desk_evt_subscribed": "구독됨",
    "desk_evt_count": "%d 이벤트",
    "desk_evt_stopPoll": "폴링 중지",
    "desk_evt_startPoll": "폴링 시작",
    "desk_noEvents": "이벤트 없음",
    "desk_evt_source": "출처: %@",
    "dy_tab_inventory": "재고",
    "dy_tab_produce": "제작",
    "dy_tab_publish": "게시",
    "dy_tab_plan": "스케줄",
    "dy_tab_comment": "댓글",
    "dy_tab_evolve": "진화",
    "dy_tab_stats": "통계",
    "dy_queue_pending": "게시 대기",
    "dy_queue_published": "게시 완료",
    "dy_queue_failed": "실패",
    "dy_queue_refresh": "새로고침",
    "dy_inv_pending_queue": "게시 대기 큐",
    "dy_inv_pending_empty": "대기 중인 영상 없음. 「제작」에서 재고 보충.",
    "dy_inv_published_recent": "게시 완료 (최근 20개)",
    "dy_inv_published_empty": "게시된 영상 없음",
    "dy_inv_failed_queue": "실패 큐",
    "dy_inv_variant_label": "variant %@",
    "dy_prod_title": "원클릭 제작",
    "dy_prod_desc": "agent-studio로 Graph C(script→img→tts→compose→enqueue) 실행, 1편을 게시 대기 큐에 추가.",
    "dy_prod_topic_label": "주제 (빈칸 = 자동 topic_gen)",
    "dy_prod_topic_ph": "예: 블랙홀에 빠지면 어떻게 될까",
    "dy_prod_variant_label": "훅 변형",
    "dy_prod_hint_a": "%@: 숫자+역설 — 첫 문장에 극단적 숫자와 상식 반대 결론",
    "dy_prod_hint_b": "%@: 질문+몰입 — 첫 문장에 이인칭 질문으로 시청자 몰입",
    "dy_prod_hint_c": "%@: 서스펜스+갈등 — 첫 문장에 미해결 서스펜스 갈등",
    "dy_prod_start": "제작 시작",
    "dy_pub_title": "재고 게시",
    "dy_pub_desc": "agent-studio로 Graph D(dequeue→gate_stock→publish→archive) 실행, 게시 대기 큐에서 1건 게시.",
    "dy_pub_dryrun_toggle": "Dry-run (실제 게시 안 함, 게시 직전 정지)",
    "dy_pub_dryrun_btn": "Dry-run 게시",
    "dy_pub_real_btn": "실제 게시",
    "dy_pub_real_warn": "⚠️ 실제 게시는 영상을抖音 계정에 업로드합니다. 재고와 로그인 상태 확인.",
    "dy_plan_title": "피크 시간대 게시 스케줄",
    "dy_plan_desc": "cron 계획을 등록해 매일 피크 시간대(12-13 / 19-21)에 Graph D 자동 실행, 재고에서 게시. 수동 클릭 불필요. 기반은 agent-studio cron 런타임(PR #140).",
    "dy_plan_expr_label": "Cron 표현식 (분 시 일 월 요일)",
    "dy_plan_expr_default": "기본 `5 12,19 * * *` = 매일 12:05와 19:05 각 1회 트리거 (피크 시간대 시작 5분 후).",
    "dy_plan_dryrun_toggle": "Dry-run (실제 게시 안 함, 트리거 검증)",
    "dy_plan_real_warn": "⚠️ 실제 계획은 피크 시간대에 자동으로 영상을抖音에 업로드합니다. 재고와 로그인 상태 확인.",
    "dy_plan_register": "계획 등록",
    "dy_plan_refresh": "새로고침",
    "dy_plan_empty": "게시 계획 없음. 등록 후 다음 트리거 시간과 실행 이력 표시.",
    "dy_plan_registered": "등록된 계획",
    "dy_plan_history": "실행 이력",
    "dy_cron_next": "다음: %@",
    "dy_cron_last": "이전: %@",
    "dy_cron_params": "매개변수: %@",
    "dy_cron_cancel": "계획 취소",
    "dy_comment_title": "댓글 답장",
    "dy_comment_desc": "agent-studio로 Graph B(fetch→gate→draft→reply) 실행, 새 댓글을 가져와 일괄 답장. 멱등.",
    "dy_comment_start": "댓글 답장 시작",
    "dy_comment_replied_title": "답장한 댓글 ID",
    "dy_evolve_title": "진화 분석",
    "dy_evolve_desc": "agent-studio로 Graph E(snapshot→rank→analyze→repair_scan) 실행, 히트 패턴 갱신과 저조 영상 스캔.",
    "dy_evolve_run": "진화 루프 실행",
    "dy_evolve_repair_title": "저조 영상 수리 재전송",
    "dy_evolve_repair_desc": "agent-studio로 Graph F(scan→gate→retitle) 실행, 저조 영상 제목 변경 후 큐 재투입.",
    "dy_evolve_repair_scan": "스캔 및 수리",
    "dy_win_title": "히트 패턴 (winning_patterns)",
    "dy_win_summary": "샘플 %d · 히트 %d · 갱신 %@",
    "dy_win_title_formula": "제목 공식",
    "dy_win_hot_topic": "✅ 히트 주제",
    "dy_win_hot_hook": "✅ 히트 훅",
    "dy_win_lose": "❌ 실패 패턴",
    "dy_stats_title": "통계 리포트 · 전체",
    "dy_stats_desc": "계정 전체 성과 개요: 집계 지표 + 성과 분포 + 훅 변형 비교.",
    "dy_stats_empty": "통계 스냅샷 없음. 먼저「진화 분석」실행해 스냅샷 확보.",
    "dy_stats_detail_title": "영상별 상세 (재생 내림차순, 우수 먼저)",
    "dy_stats_total_plays": "총 재생",
    "dy_stats_total_likes": "총 좋아요",
    "dy_stats_total_comments": "총 댓글",
    "dy_stats_total_shares": "총 공유",
    "dy_stats_count": "영상 수",
    "dy_stats_avg_plays": "평균 재생",
    "dy_stats_avg_ir": "평균 상호작용률",
    "dy_stats_hot_count": "히트 수",
    "dy_stats_dist_hot": "히트 %d",
    "dy_stats_dist_mid": "안정 %d",
    "dy_stats_dist_cold": "저조 %d",
    "dy_stats_variant_dist": "훅 변형 샘플 분포",
    "dy_stats_variant_count": "%@: %d개",
    "dy_stats_row_plays": "재생 %d",
    "dy_stats_row_likes": "좋아요 %d",
    "dy_stats_row_comments": "댓글 %d",
    "dy_stats_row_shares": "공유 %d",
    "dy_stats_row_ir": "상호작용률 %.2f%%",
    "dy_action_running": "실행 중…",
    "dy_action_produce": "제작 중",
    "dy_action_publish": "게시 중",
    "dy_action_comment_reply": "댓글 답장",
    "dy_action_evolve": "진화 분석",
    "dy_action_repair": "저조 영상 수리",
    "dy_err_ops_not_found": "찾을 수 없음: %@. fusion-operation이 실행되어 out/ 데이터가 있는지 확인.",
    "dy_err_ipc_disconnected": "IPC 미연결. agent-studio 호출 불가.",
    "dy_err_ipc_register": "IPC 미연결. 게시 계획 등록 불가.",
    "dy_res_done": "실행 완료, %d 이벤트",
    "dy_res_status": "실행 상태: %@",
    "dy_res_plan_registered": "게시 계획 등록 완료. 피크 시간대 자동 트리거 대기.",
    "dy_res_register_failed": "등록 실패",
    "dy_err_rungraph": "runGraph %@ 실패: %@",
    "dy_err_graph_missing": "Graph 파일 없음: %@",
    "dy_err_graph_parse": "Graph JSON 파싱 실패: %@",
    "dy_err_graph_no_id": "graph.create가 graph_id를 반환하지 않음",
    "dy_err_register": "게시 계획 등록 실패: %@",
    "dy_err_unregister": "계획 취소 실패: %@",
    "dy_cron_name": "抖音 피크 시간대 게시 계획",
    "fc_mode_ask": "Ask",
    "fc_mode_auto": "Auto",
    "fc_mode_plan": "Plan",
    "fc_layout_four_column": "4열",
    "fc_layout_three_column": "3열",
    "fc_layout_two_column": "2열",
    "fc_layout_chat_only": "채팅만",
    "fc_pane_editor": "편집기",
    "fc_pane_diff": "차분",
    "fc_pane_preview": "미리보기",
    "fc_pane_terminal": "터미널",
    "fc_pane_snapshot": "스냅샷",
    "fc_pane_workflow": "워크플로",
    "fc_pane_sandbox": "샌드박스",
    "fc_cmd_help": "사용 가능한 명령 표시",
    "fc_cmd_clear": "대화 비우기",
    "fc_cmd_compact": "대화 컨텍스트 압축",
    "fc_cmd_model": "모델 전환",
    "fc_cmd_kb": "지식 베이스 조회",
    "fc_cmd_memory": "프로젝트 메모리 관리",
    "fc_cmd_template": "워크플로 템플릿 적용",
    "fc_cmd_init": "프로젝트 컨텍스트 초기화",
    "fc_cmd_review": "현재 변경사항 검토",
    "fc_cmd_test": "테스트 생성 및 실행",
    "fc_cmd_deploy": "프로젝트 배포",
    "fc_cmd_explain": "코드 설명",
    "fc_cmd_refactor": "코드 리팩터",
    "fc_cmd_debug": "문제 디버그",
    "fc_no_project_title": "프로젝트 폴더 열기",
    "fc_open_folder": "폴더 열기",
    "fc_offline_mlx": "fusion-code 오프라인 — MLX 추론 사용",
    "fc_thinking": "생각 중...",
    "fc_connected": "연결됨",
    "fc_offline": "오프라인",
    "fc_hide_session_bar": "세션 바 숨기기",
    "fc_show_session_bar": "세션 바 표시",
    "fc_greeting_morning": "좋은 아침",
    "fc_greeting_afternoon": "좋은 오후",
    "fc_greeting_evening": "좋은 저녁",
    "fc_greeting_night": "안녕히 주무세요",
    "fc_welcome_subtitle": "Fusion Code — 로컬 AI 코딩 어시스턴트",
    "fc_card_open_title": "프로젝트 열기",
    "fc_card_open_sub": "로컬 폴더로 시작",
    "fc_card_code_title": "코드",
    "fc_card_code_sub": "코드 생성 및 편집",
    "fc_card_debug_title": "디버그",
    "fc_card_debug_sub": "문제 찾기 및 수정",
    "fc_card_kb_title": "KB 조회",
    "fc_card_kb_sub": "코드베이스에 질문",
    "fc_card_memory_title": "메모리",
    "fc_card_memory_sub": "컨텍스트 관리",
    "fc_card_template_title": "템플릿",
    "fc_card_template_sub": "워크플로 템플릿",
    "fc_card_review_title": "검토",
    "fc_card_review_sub": "코드 검토",
    "fc_card_test_title": "테스트",
    "fc_card_test_sub": "테스트 생성",
    "fc_prompt_write": "작성해: ",
    "fc_prompt_debug": "이 문제를 디버그해줘",
    "fc_add_folder": "폴더 추가",
    "fc_add_file": "파일 추가",
    "fc_query_kb": "KB 조회",
    "fc_templates": "템플릿",
    "fc_web_search": "웹 검색",
    "fc_input_placeholder": "무엇이든 물어보세요 — / 로 명령...",
    "fc_select_file_edit": "편집할 파일 선택",
    "fc_select_session_snapshot": "스냅샷을 볼 세션 선택",
    "fc_undo": "실행 취소",
    "fc_save": "저장",
    "fc_project_context": "프로젝트 컨텍스트",
    "fc_ctx_project": "프로젝트",
    "fc_ctx_branch": "브랜치",
    "fc_ctx_files": "파일",
    "fc_ctx_model": "모델",
    "fc_ctx_mode": "모드",
    "fc_ctx_kb": "KB",
    "fc_not_selected": "선택 안 됨",
    "fc_no_project_open": "프로젝트 미열림",
    "fc_project_memory": "프로젝트 메모리",
    "fc_load_memory": "메모리 파일 로드",
    "fc_write_memory": "메모리 작성",
    "fc_sessions": "세션",
    "fc_no_sessions": "세션 없음",
    "fc_messages_count": "%d개 메시지",
    "fc_workflow_templates": "워크플로 템플릿",
    "fc_tpl_review": "코드 검토",
    "fc_tpl_test": "테스트 생성",
    "fc_tpl_debug": "문제 디버그",
    "fc_tpl_refactor": "리팩터",
    "fc_tpl_explain": "코드 설명",
    "fc_tpl_deploy": "배포",
    "fc_msg_model_switched": "모델 전환: %@",
    "fc_msg_current_model": "현재 모델: %@",
    "fc_msg_context_compacted": "컨텍스트 압축됨",
    "fc_msg_unknown_cmd": "알 수 없는 명령: %@. /help로 사용 가능한 명령 확인.",
    "fc_msg_kb_usage": "사용법: /kb <쿼리>",
    "fc_msg_no_project_open": "프로젝트가 열려 있지 않습니다. 먼저 폴더를 여세요.",
    "fc_msg_kb_no_results": "결과 없음: %@",
    "fc_msg_kb_results": "KB 결과:\n\n%@",
    "fc_msg_kb_failed": "KB 조회 실패: %@",
    "fc_msg_no_project": "프로젝트 미열림.",
    "fc_msg_no_memory": "메모리 파일 없음.",
    "fc_msg_memory_files": "메모리 파일:\n%@",
    "fc_msg_memory_failed": "메모리 로드 실패: %@",
    "fc_kb_building": "KB: 빌드 중...",
    "fc_kb_build_failed": "KB: 빌드 실패",
    "fc_tool_edit": "파일 편집: %@",
    "fc_tool_write": "파일 작성: %@",
    "fc_tool_run": "실행: %@",
    "fc_tool_multi_edit": "여러 파일 편집",
    "fc_denied_by_user": "사용자가 거부함",
    "fc_approve": "승인",
    "fc_deny": "거부",
    "fc_apply_code": "코드 적용",
    "fc_apply_code_n": "코드 적용 #%d",
    "fc_status_pending": "대기 중",
    "fc_status_running": "실행 중",
    "fc_status_approved": "승인됨",
    "fc_status_denied": "거부됨",
    "fc_status_completed": "완료",
    "fc_status_failed": "실패",
    "fc_code": "코드",
    "fc_copied": "복사됨",
    "fc_copy": "복사",
    "fc_no_matching_commands": "일치하는 명령 없음",
    "fc_new_session": "새 세션",
    "fc_title": "제목",
    "fc_session_title_ph": "세션 제목",
    "fc_cancel": "취소",
    "fc_create": "생성",
    "fc_permission_request": "권한 요청",
    "fc_tool_label": "도구:",
    "fc_open_project_folder": "프로젝트 폴더 열기",
    "fc_open_file": "파일 열기",
    "fc_scanning": "스캔 중 %@...",
    "fc_loaded_files": "%d개 파일 로드됨",
    "fc_loading": "로드 중 %@...",
    "fc_loaded_one_file": "1개 파일 로드됨",
    "fc_load_failed": "로드 실패: %@",
    "fc_scanning_n": "스캔 %d/%d...",
    "fc_ai_unavailable": "AI 서비스를 일시적으로 사용할 수 없습니다. 나중에 다시 시도하세요.",
    "fc_sidebar_chat": "채팅",
    "fc_sidebar_files": "파일",
    "fc_sidebar_git": "Git",
    "fc_sidebar_design": "디자인",
    "fc_toggle_sidebar": "사이드바 전환",
    "fc_input_ask_anything": "무엇이든 물어보세요 — code, explain, debug, refactor...",
    "fc_attach_file": "파일 첨부",
    "fc_menu_add_folder": "폴더 추가...",
    "fc_menu_add_file": "파일 추가...",
    "fc_menu_add_github": "GitHub 리포 추가...",
    "fc_git_url_detected": "Git 리포지토리 URL 감지",
    "fc_send": "전송",
    "fc_open_project": "프로젝트 열기",
    "fc_local_folder": "로컬 폴더",
    "fc_local_folder_desc": "로컬 폴더 선택, 코드 파일 자동 스캔",
    "fc_choose": "선택...",
    "fc_single_file": "단일 파일",
    "fc_single_file_desc": "단일 파일 열어 편집 및 AI 지원",
    "fc_github_repo": "GitHub リポジ토리",
    "fc_github_repo_desc": "원격 리포를 로컬로 클론",
    "fc_url": "URL",
    "fc_branch": "브랜치",
    "fc_clone_open": "클론 후 열기",
    "fc_or": "또는",
    "fc_drop_here": "파일이나 폴더를 여기에 드롭",
    "fc_search_conversations": "대화 검색...",
    "fc_no_conversations": "대화 없음",
    "fc_files_count": "%d개 파일",
    "fc_close_project": "프로젝트 닫기",
    "fc_open_another": "다른 프로젝트 열기",
    "fc_search_files": "파일 검색...",
    "fc_open_folder_browse": "폴더를 열어 파일 탐색",
    "fc_show_in_finder": "Finder에서 보기",
    "fc_copy_path": "경로 복사",
    "fc_remove_context": "컨텍스트에서 제거",
    "fc_add_to_context": "컨텍스트에 추가",
    "fc_add_to_kb": "지식 베이스에 추가",
    "fc_index_to_rag": "RAG에 인덱스",
    "fc_add_dir_to_kb": "디렉터리를 지식 베이스에 추가",
    "fc_not_git_repo": "git 리포가 아님",
    "fc_open_for_git": "프로젝트를 열어 Git 상태 보기",
    "fc_no_changes": "변경 없음",
    "fc_welcome_title": "Fusion Code — AI 코딩 어시스턴트",
    "fc_welcome_tagline": "Claude Code 호환 · fusion-mlx 구동",
    "fc_wc_open_title": "프로젝트 열기",
    "fc_wc_open_desc": "로컬/Git 코드 로드",
    "fc_wc_explain_title": "설명",
    "fc_wc_explain_desc": "코드 기능 설명",
    "fc_wc_review_title": "검토",
    "fc_wc_review_desc": "코드 결함 찾기",
    "fc_wc_test_title": "테스트",
    "fc_wc_test_desc": "단위 테스트 생성",
    "fc_recent": "최근 열기",
    "fc_min_ago": "%d분 전",
    "fc_hour_ago": "%d시간 전",
    "fc_day_ago": "%d일 전",
    "fc_term_banner": "Fusion Studio 터미널 v1.0",
    "fc_term_help_hint": "'help'로 사용 가능한 명령 표시",
    "fc_terminal": "터미널",
    "fc_clear": "지우기",
    "fc_term_commands": "명령: help, clear, status, mlx, python, swift",
    "fc_term_unknown": "알 수 없음: %@. 'help' 입력",
    "fc_you": "나",
    "fc_clone": "클론",
    "fc_group_mode": "그룹",
    "fc_search_sessions": "세션 검색...",
    "fc_no_project2": "프로젝트 없음",
    "fc_rename": "이름 변경",
    "fc_pause": "일시정지",
    "fc_resume": "재개",
    "fc_delete": "삭제",
    "fc_layout_mode": "레이아웃",
    "fc_sessions_count": "%d 세션",
    "fc_new_session_full": "새 코딩 세션",
    "fc_working_dir": "작업 디렉토리",
    "fc_model_label": "모델",
    "fc_security_mode": "보안 모드",
    "fc_sm_readonly": "읽기 전용",
    "fc_sm_manual": "수동 승인",
    "fc_sm_auto": "자동",
    "fc_gm_by_project": "프로젝트별",
    "fc_gm_by_state": "상태별",
    "fc_gm_flat": "플랫",
    "fc_state_idle": "유휴",
    "fc_state_running": "실행 중",
    "fc_state_waiting": "승인 대기",
    "fc_state_paused": "일시정지됨",
    "fc_state_completed": "완료",
    "fc_state_failed": "실패",
    "fc_state_cluster": "클러스터 실행 중",
    "fc_sm_auto_full": "자동 승인",
    "fc_policy": "정책",
    "fc_audit": "감사",
    "fc_allow_dirs": "허용 디렉토리",
    "fc_add_dir_ph": "디렉토리 추가...",
    "fc_add": "추가",
    "fc_ignore_patterns": "무시 패턴 (.fusionignore)",
    "fc_add_pattern_ph": "패턴 추가...",
    "fc_no_audit": "감사 기록 없음",
    "fc_records_count": "%d건",
    "fc_export": "내보내기",
    "fc_wf_empty_desc": "복잡한 작업을 자동화하는 워크플로 생성",
    "fc_wf_new": "새 워크플로",
    "fc_wf_goal_ph": "목표 설명",
    "fc_wf_select_template": "템플릿 선택",
    "fc_wf_template_generic": "범용 작업 분해",
    "fc_wf_template_legacy": "레거시 마이그레이션",
    "fc_wf_template_security": "보안 스캔 감사",
    "fc_wf_template_batch": "배치 API 처리",
    "fc_wf_template_refactor": "코드 리팩터링",
    "fc_wf_template_test": "테스트 생성",
    "fc_wf_status_failed": "%d 실패",
    "fc_wf_status_running": "실행 중 (%d/%d)",
    "fc_wf_status_completed": "완료",
    "fc_wf_status_pending": "대기 중 (%d/%d)",
    "fc_preview": "미리보기",
    "fc_live": "실시간",
    "fc_html_preview_empty": "HTML 생성 후 여기에 미리보기가 표시됩니다",
    "fc_original": "원본",
    "fc_modified": "수정됨",
    "fc_design_open_in_module": "Design 모듈에서 열기",
    "fc_design_no_content": "디자인 콘텐츠 없음",
    "fc_design_create_hint": "Design 모듈에서 디자인 생성 후\n여기서 미리보기할 수 있습니다",
    "fc_design_sync_on": "양방향 동기화 활성화됨",
    "fc_design_sync_off": "동기화 미연결",
    "fc_design_export_file": "파일로 내보내기",
    "fc_tier_global": "전역",
    "fc_tier_project": "프로젝트",
    "fc_tier_directory": "디렉터리",
    "fc_diff_split": "분할",
    "fc_diff_unified": "통합",
    "fc_diff_line_numbers": "줄 번호",
    "fc_snapshots": "스냅샷",
    "fc_no_snapshots": "스냅샷 없음",
    "fc_create_snapshot": "스냅샷 생성",
    "fc_label_optional": "라벨（선택）",
    "fc_restore": "복원",
    "fc_rewind_here": "여기로 되감기",
    "fc_snap_deltas_fmt": "%d개 델타 · %@",
    "fc_snap_not_found": "스냅샷을 찾을 수 없음: %@",
    "fc_pty_stopped": "중지됨",
    "fc_pty_clear": "지우기",
    "fc_pty_stop": "중지",
    "fc_pty_restart": "재시작",
    "fc_pty_shell_started": "Shell 시작됨: %@",
    "fc_pty_shell_exited": "Shell 종료됨.",
    "fc_pty_start_fail": "Shell 시작 실패: %@",
    "fc_pty_alloc_fail": "PTY 할당 실패: %@",
    "fc_copy_suffix": " (사본)",
    "fc_untitled": "제목 없음"
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
