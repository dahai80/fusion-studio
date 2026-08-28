import Foundation

// F-I3: IPC RPC 方法名集中常量。全仓 call(method:) 引用此 enum, 编译期防拼写错误。
// 审计 0825 F-I3: 旧全裸字符串字面量, 拼错零编译期检查, 运行时 method-not-found 静默失败。
// 集中后上游重命名 method 客户端单点改, grep 不到的调用点不残留旧名。
// 与 F-A16 rpc.discover 运行时校验互补: 此处编译期防拼写, discover 防上游 schema 漂移。
enum RPCMethod {
    // MARK: - agent
    static let agentAddSkill = "agent.add_skill"
    static let agentArchive = "agent.archive"
    static let agentCancelTask = "agent.cancel_task"
    static let agentClone = "agent.clone"
    static let agentCodeLanguages = "agent.code_languages"
    static let agentConfigure = "agent.configure"
    static let agentCoworkAdd = "agent.cowork.add"
    static let agentCoworkCall = "agent.cowork.call"
    static let agentCoworkList = "agent.cowork.list"
    static let agentCoworkRemove = "agent.cowork.remove"
    static let agentCoworkStatus = "agent.cowork.status"
    static let agentCreate = "agent.create"
    static let agentDelete = "agent.delete"
    static let agentDeleteSkill = "agent.delete_skill"
    static let agentDiffReview = "agent.diff_review"
    static let agentExecute = "agent.execute"
    static let agentExecuteStream = "agent.execute_stream"
    static let agentGet = "agent.get"
    static let agentGetApiEndpoint = "agent.get_api_endpoint"
    static let agentGetSoul = "agent.get_soul"
    static let agentHistory = "agent.history"
    static let agentList = "agent.list"
    static let agentListSkills = "agent.list_skills"
    static let agentPublish = "agent.publish"
    static let agentSubmitCodeTask = "agent.submit_code_task"
    static let agentTaskStatus = "agent.task_status"
    static let agentTasks = "agent.tasks"
    static let agentUnpublish = "agent.unpublish"
    static let agentUpdate = "agent.update"
    static let agentUpdateSoul = "agent.update_soul"

    // MARK: - team
    static let teamFmpRegister = "team.fmp_register"
    static let teamFmpSend = "team.fmp_send"
    static let teamFmpStats = "team.fmp_stats"
    static let teamOrchestrate = "team.orchestrate"
    static let teamPlazaBreakIn = "team.plaza_break_in"
    static let teamPlazaBroadcast = "team.plaza_broadcast"
    static let teamPlazaChannels = "team.plaza_channels"
    static let teamPlazaCircuit = "team.plaza_circuit"
    static let teamPlazaCreate = "team.plaza_create"
    static let teamPlazaMessages = "team.plaza_messages"
    static let teamSwarmAgents = "team.swarm_agents"
    static let teamSwarmDelegate = "team.swarm_delegate"
    static let teamSwarmEscalate = "team.swarm_escalate"
    static let teamSwarmEvaluate = "team.swarm_evaluate"
    static let teamSwarmHandoff = "team.swarm_handoff"
    static let teamSwarmRegister = "team.swarm_register"
    static let teamSwarmStats = "team.swarm_stats"

    // MARK: - trainer
    static let trainerAdaptersDelete = "trainer.adapters.delete"
    static let trainerAdaptersList = "trainer.adapters.list"
    static let trainerDatasetsList = "trainer.datasets.list"
    static let trainerDatasetsPreview = "trainer.datasets.preview"
    static let trainerInfoFull = "trainer.info_full"
    static let trainerPresetsList = "trainer.presets.list"
    static let trainerRunsList = "trainer.runs.list"
    static let trainerRunsProgress = "trainer.runs.progress"
    static let trainerRunsStatusFull = "trainer.runs.status_full"
    static let trainerRunsStop = "trainer.runs.stop"
    static let trainerStartRlsl = "trainer.start_rlsl"
    static let trainerStartSft = "trainer.start_sft"

    // MARK: - chat
    static let chatBranch = "chat.branch"
    static let chatBranches = "chat.branches"
    static let chatCreate = "chat.create"
    static let chatDelete = "chat.delete"
    static let chatEdit = "chat.edit"
    static let chatGet = "chat.get"
    static let chatList = "chat.list"
    static let chatMessageTree = "chat.message_tree"
    static let chatSend = "chat.send"
    static let chatStream = "chat.stream"
    static let chatSwitchBranch = "chat.switch_branch"

    // MARK: - memory
    static let memoryAutoForget = "memory.auto_forget"
    static let memoryCount = "memory.count"
    static let memoryDelete = "memory.delete"
    static let memoryDeleteScope = "memory.delete_scope"
    static let memoryGet = "memory.get"
    static let memoryListRecent = "memory.list_recent"
    static let memoryRecall = "memory.recall"
    static let memoryRecallRelevant = "memory.recall_relevant"
    static let memoryStore = "memory.store"

    // MARK: - connector
    static let connectorConnect = "connector.connect"
    static let connectorCreate = "connector.create"
    static let connectorDelete = "connector.delete"
    static let connectorDisconnect = "connector.disconnect"
    static let connectorGet = "connector.get"
    static let connectorList = "connector.list"
    static let connectorTest = "connector.test"
    static let connectorUpdate = "connector.update"

    // MARK: - planner
    static let plannerApprovePlan = "planner.approve_plan"
    static let plannerCancelPlan = "planner.cancel_plan"
    static let plannerCreatePlan = "planner.create_plan"
    static let plannerExecutePlan = "planner.execute_plan"
    static let plannerExecuteStep = "planner.execute_step"
    static let plannerGetPlan = "planner.get_plan"
    static let plannerListPlans = "planner.list_plans"
    static let plannerRejectPlan = "planner.reject_plan"

    // MARK: - safety
    static let safetyAddPolicy = "safety.add_policy"
    static let safetyApprove = "safety.approve"
    static let safetyApproveAction = "safety.approve_action"
    static let safetyCheck = "safety.check"
    static let safetyEvaluateAction = "safety.evaluate_action"
    static let safetyGetPendingActions = "safety.get_pending_actions"
    static let safetyReject = "safety.reject"
    static let safetyRejectAction = "safety.reject_action"

    // MARK: - task
    static let taskAddArtifacts = "task.add_artifacts"
    static let taskCancel = "task.cancel"
    static let taskDelete = "task.delete"
    static let taskGet = "task.get"
    static let taskList = "task.list"
    static let taskRerun = "task.rerun"
    static let taskStatus = "task.status"
    static let taskSubmit = "task.submit"

    // MARK: - agent_studio
    static let agentStudioAgentChat = "agent_studio.agent.chat"
    static let agentStudioAgentRestoreVersion = "agent_studio.agent.restore_version"
    static let agentStudioAgentSnapshot = "agent_studio.agent.snapshot"
    static let agentStudioAgentVersions = "agent_studio.agent.versions"
    static let agentStudioApikeyRotate = "agent_studio.apikey.rotate"
    static let agentStudioAuditTrail = "agent_studio.audit.trail"
    static let agentStudioSessionLogs = "agent_studio.session.logs"

    // MARK: - marketplace
    static let marketplaceGet = "marketplace.get"
    static let marketplaceInstall = "marketplace.install"
    static let marketplaceListCategories = "marketplace.list_categories"
    static let marketplacePublish = "marketplace.publish"
    static let marketplaceSearch = "marketplace.search"
    static let marketplaceUninstall = "marketplace.uninstall"
    static let marketplaceUnpublish = "marketplace.unpublish"

    // MARK: - graph
    static let graphCreate = "graph.create"
    static let graphDelete = "graph.delete"
    static let graphExecute = "graph.execute"
    static let graphGet = "graph.get"
    static let graphList = "graph.list"
    static let graphUpdate = "graph.update"

    // MARK: - mlx
    static let mlxHealth = "mlx.health"
    static let mlxRestart = "mlx.restart"
    static let mlxSetModel = "mlx.set_model"
    static let mlxStart = "mlx.start"
    static let mlxStatus = "mlx.status"
    static let mlxStop = "mlx.stop"

    // MARK: - apikey
    static let apikeyCreate = "apikey.create"
    static let apikeyList = "apikey.list"
    static let apikeyRevoke = "apikey.revoke"
    static let apikeyRotate = "apikey.rotate"
    static let apikeyUpdate = "apikey.update"

    // MARK: - knowledge
    static let knowledgeCount = "knowledge.count"
    static let knowledgeDelete = "knowledge.delete"
    static let knowledgeIngest = "knowledge.ingest"
    static let knowledgeList = "knowledge.list"
    static let knowledgeSearch = "knowledge.search"

    // MARK: - style
    static let styleApply = "style.apply"
    static let styleCreate = "style.create"
    static let styleDelete = "style.delete"
    static let styleGet = "style.get"
    static let styleList = "style.list"

    // MARK: - cron
    static let cronList = "cron.list"
    static let cronListExecutions = "cron.list_executions"
    static let cronRegister = "cron.register"
    static let cronUnregister = "cron.unregister"

    // MARK: - tool
    static let toolDynamicRegister = "tool.dynamic_register"
    static let toolDynamicUnregister = "tool.dynamic_unregister"
    static let toolGet = "tool.get"
    static let toolList = "tool.list"

    // MARK: - deploy
    static let deployExport = "deploy.export"
    static let deployImport = "deploy.import"
    static let deployListFormats = "deploy.list_formats"

    // MARK: - env
    static let envHealthCheck = "env.health_check"
    static let envRepair = "env.repair"
    static let envRepairAll = "env.repair_all"

    // MARK: - hooks
    static let hooksList = "hooks.list"
    static let hooksRegister = "hooks.register"
    static let hooksTest = "hooks.test"

    // MARK: - kb
    static let kbBuild = "kb.build"
    static let kbQuery = "kb.query"
    static let kbStatus = "kb.status"

    // MARK: - rag
    static let ragQuery = "rag.query"
    static let ragRetrieve = "rag.retrieve"
    static let ragVectorSearch = "rag.vector_search"

    // MARK: - template
    static let templateGet = "template.get"
    static let templateInstantiate = "template.instantiate"
    static let templateList = "template.list"

    // MARK: - alert
    static let alertAcknowledge = "alert.acknowledge"
    static let alertList = "alert.list"

    // MARK: - budget
    static let budgetSet = "budget.set"
    static let budgetStatus = "budget.status"

    // MARK: - context
    static let contextCompact = "context.compact"
    static let contextUsage = "context.usage"

    // MARK: - design
    static let designGenerate = "design.generate"
    static let designHealthCheck = "design.health_check"

    // MARK: - permission
    static let permissionList = "permission.list"
    static let permissionUpdate = "permission.update"

    // MARK: - project
    static let projectList = "project.list"
    static let projectTasks = "project.tasks"

    // MARK: - system
    static let systemOfflineStatus = "system.offline_status"
    static let systemSetOffline = "system.set_offline"

    // MARK: - analytics
    static let analyticsAgentUsage = "analytics.agent_usage"

    // MARK: - audit
    static let auditList = "audit.list"

    // MARK: - dashboard
    static let dashboardOverview = "dashboard.overview"

    // MARK: - hardware
    static let hardwareMetrics = "hardware.metrics"

    // MARK: - model
    static let modelStatus = "model.status"

    // MARK: - ping
    static let ping = "ping"

    // MARK: - plugin
    static let pluginList = "plugin.list"

    // MARK: - research
    static let researchAdaptive = "research.adaptive"

    // MARK: - rpc
    static let rpcDiscover = "rpc.discover"

    // MARK: - session
    static let sessionList = "session.list"

    // MARK: - skill
    static let skillExecute = "skill.execute"

    // MARK: - verify
    static let verifyVerify = "verify.verify"

    // MARK: - guard (#344: fusion-guard UDS JSON-RPC, /tmp/fusion-guard.sock)
    static let guardPing = "guard.ping"
    static let guardEvaluate = "guard.evaluate"
    static let guardConfirm = "guard.confirm"
    static let guardTccReport = "guard.tcc.report"
    static let guardTccStatus = "guard.tcc.status"
}
