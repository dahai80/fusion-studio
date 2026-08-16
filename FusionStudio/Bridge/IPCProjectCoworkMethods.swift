import Foundation
import os.log

extension IPCClient {
    // MARK: - Agent Task Operations

    func agentSubmitCodeTask(agentId: String, code: String, language: String = "swift") async throws -> [String: Any] {
        return try await call(method: "agent.submit_code_task", params: ["agent_id": agentId, "code": code, "language": language])
    }

    func agentTaskStatus(taskId: String) async throws -> [String: Any] {
        return try await call(method: "agent.task_status", params: ["task_id": taskId])
    }

    func agentTasks(agentId: String? = nil) async throws -> [String: Any] {
        var params: [String: Any] = [:]
        if let aid = agentId { params["agent_id"] = aid }
        return try await call(method: "agent.tasks", params: params)
    }

    func agentCancelTask(taskId: String) async throws -> [String: Any] {
        return try await call(method: "agent.cancel_task", params: ["task_id": taskId])
    }

    // MARK: - Chat Core

    func chatCreate(agentId: String, title: String = "") async throws -> [String: Any] {
        return try await call(method: "chat.create", params: ["agent_id": agentId, "title": title])
    }

    func chatList(agentId: String? = nil) async throws -> [String: Any] {
        var params: [String: Any] = [:]
        if let aid = agentId { params["agent_id"] = aid }
        return try await call(method: "chat.list", params: params)
    }

    func chatDelete(chatId: String) async throws -> [String: Any] {
        return try await call(method: "chat.delete", params: ["chat_id": chatId])
    }

    func chatSend(chatId: String, message: String) async throws -> [String: Any] {
        return try await call(method: "chat.send", params: ["chat_id": chatId, "message": message])
    }

    func chatStream(chatId: String, message: String) async throws -> [String: Any] {
        return try await call(method: "chat.stream", params: ["chat_id": chatId, "message": message])
    }

    func chatEdit(messageId: String, content: String) async throws -> [String: Any] {
        return try await call(method: "chat.edit", params: ["message_id": messageId, "content": content])
    }

    func chatBranch(messageId: String) async throws -> [String: Any] {
        return try await call(method: "chat.branch", params: ["message_id": messageId])
    }

    // MARK: - Team (Multi-Agent Collaboration)

    func teamOrchestrate(task: String, agentIds: [String], mode: String = "sequential") async throws -> [String: Any] {
        return try await call(method: "team.orchestrate", params: ["task": task, "agent_ids": agentIds, "mode": mode])
    }

    func teamSwarmRegister(agentId: String, role: String = "worker") async throws -> [String: Any] {
        return try await call(method: "team.swarm_register", params: ["agent_id": agentId, "role": role])
    }

    func teamSwarmAgents() async throws -> [String: Any] {
        return try await call(method: "team.swarm_agents")
    }

    func teamSwarmHandoff(fromAgent: String, toAgent: String, context: [String: Any] = [:]) async throws -> [String: Any] {
        return try await call(method: "team.swarm_handoff", params: ["from": fromAgent, "to": toAgent, "context": context])
    }

    func teamSwarmDelegate(agentId: String, task: String) async throws -> [String: Any] {
        return try await call(method: "team.swarm_delegate", params: ["agent_id": agentId, "task": task])
    }

    func teamSwarmEscalate(agentId: String, reason: String) async throws -> [String: Any] {
        return try await call(method: "team.swarm_escalate", params: ["agent_id": agentId, "reason": reason])
    }

    func teamSwarmEvaluate(agentId: String) async throws -> [String: Any] {
        return try await call(method: "team.swarm_evaluate", params: ["agent_id": agentId])
    }

    func teamSwarmStats() async throws -> [String: Any] {
        return try await call(method: "team.swarm_stats")
    }

    func teamFmpRegister(channel: String, agentId: String) async throws -> [String: Any] {
        return try await call(method: "team.fmp_register", params: ["channel": channel, "agent_id": agentId])
    }

    func teamFmpSend(channel: String, message: String) async throws -> [String: Any] {
        return try await call(method: "team.fmp_send", params: ["channel": channel, "message": message])
    }

    func teamFmpStats() async throws -> [String: Any] {
        return try await call(method: "team.fmp_stats")
    }

    func teamPlazaCreate(name: String, description: String = "") async throws -> [String: Any] {
        return try await call(method: "team.plaza_create", params: ["name": name, "description": description])
    }

    func teamPlazaChannels() async throws -> [String: Any] {
        return try await call(method: "team.plaza_channels")
    }

    func teamPlazaBroadcast(channelId: String, message: String) async throws -> [String: Any] {
        return try await call(method: "team.plaza_broadcast", params: ["channel_id": channelId, "message": message])
    }

    func teamPlazaMessages(channelId: String) async throws -> [String: Any] {
        return try await call(method: "team.plaza_messages", params: ["channel_id": channelId])
    }

    func teamPlazaBreakIn(channelId: String, message: String) async throws -> [String: Any] {
        return try await call(method: "team.plaza_break_in", params: ["channel_id": channelId, "message": message])
    }

    func teamPlazaCircuit(channelId: String) async throws -> [String: Any] {
        return try await call(method: "team.plaza_circuit", params: ["channel_id": channelId])
    }

    // MARK: - Cron

    func cronRegister(name: String, schedule: String, agentId: String, input: String = "") async throws -> [String: Any] {
        return try await call(method: "cron.register", params: ["name": name, "schedule": schedule, "agent_id": agentId, "input": input])
    }

    func cronUnregister(cronId: String) async throws -> [String: Any] {
        return try await call(method: "cron.unregister", params: ["cron_id": cronId])
    }

    func cronList() async throws -> [String: Any] {
        return try await call(method: "cron.list")
    }

    func cronListExecutions(cronId: String? = nil) async throws -> [String: Any] {
        var params: [String: Any] = [:]
        if let cid = cronId { params["cron_id"] = cid }
        return try await call(method: "cron.list_executions", params: params)
    }

    // MARK: - Task (通用 Task 持久化, #141 PR#143)

    func taskSubmit(
        taskId: String = "",
        title: String,
        description: String = "",
        agentId: String = "",
        graphId: String = "",
        trigger: String = "immediate",
        cronExpression: String = "",
        runAt: Double = 0,
        input: String = "",
        status: String = "pending",
        priority: Int = 1,
        sessionId: String = "",
        projectId: String = "",
        maxRetries: Int = 3
    ) async throws -> [String: Any] {
        var params: [String: Any] = [
            "task_id": taskId,
            "title": title,
            "description": description,
            "agent_id": agentId,
            "graph_id": graphId,
            "trigger": trigger,
            "cron_expression": cronExpression,
            "run_at": runAt,
            "input": input,
            "status": status,
            "priority": priority,
            "session_id": sessionId,
            "max_retries": maxRetries,
        ]
        if !projectId.isEmpty { params["project_id"] = projectId }
        return try await call(method: "task.submit", params: params)
    }

    func taskList(status: String = "", agentId: String = "", projectId: String = "", limit: Int = 100) async throws -> [String: Any] {
        var params: [String: Any] = ["limit": limit]
        if !status.isEmpty { params["status"] = status }
        if !agentId.isEmpty { params["agent_id"] = agentId }
        if !projectId.isEmpty { params["project_id"] = projectId }
        return try await call(method: "task.list", params: params)
    }

    // MARK: - Project (#141 priority-2: 多 Task 聚合容器/看板)

    func projectList() async throws -> [String: Any] {
        return try await call(method: "project.list")
    }

    func projectTasks(projectId: String, status: String = "", limit: Int = 500) async throws -> [String: Any] {
        var params: [String: Any] = ["project_id": projectId, "limit": limit]
        if !status.isEmpty { params["status"] = status }
        return try await call(method: "project.tasks", params: params)
    }

    func taskGet(taskId: String) async throws -> [String: Any] {
        return try await call(method: "task.get", params: ["task_id": taskId])
    }

    func taskStatus(taskId: String, status: String, lastResult: [String: Any]? = nil, lastError: String = "") async throws -> [String: Any] {
        var params: [String: Any] = ["task_id": taskId, "status": status, "last_error": lastError]
        if let r = lastResult { params["last_result"] = r }
        return try await call(method: "task.status", params: params)
    }

    func taskCancel(taskId: String) async throws -> [String: Any] {
        return try await call(method: "task.cancel", params: ["task_id": taskId])
    }

    func taskRerun(taskId: String) async throws -> [String: Any] {
        return try await call(method: "task.rerun", params: ["task_id": taskId])
    }

    // MARK: - Hooks

    func hooksList() async throws -> [String: Any] {
        return try await call(method: "hooks.list")
    }

    func hooksRegister(event: String, agentId: String, action: String) async throws -> [String: Any] {
        return try await call(method: "hooks.register", params: ["event": event, "agent_id": agentId, "action": action])
    }

    func hooksTest(hookId: String) async throws -> [String: Any] {
        return try await call(method: "hooks.test", params: ["hook_id": hookId])
    }

    // MARK: - Context

    func contextCompact(sessionId: String) async throws -> [String: Any] {
        return try await call(method: "context.compact", params: ["session_id": sessionId])
    }

    func contextUsage(sessionId: String) async throws -> [String: Any] {
        return try await call(method: "context.usage", params: ["session_id": sessionId])
    }

    // MARK: - Marketplace Extended

    func marketplaceUninstall(agentId: String) async throws -> [String: Any] {
        return try await call(method: "marketplace.uninstall", params: ["agent_id": agentId])
    }

    // MARK: - Project Service (UDS /tmp/fusion-project-svc.sock, Issue #40)

    // Callers: ProjectModuleView / ProjectsPanel (fusion-project-svc backed). Affected API: projectCall + 15 project.* methods.
    private static let projectSvcSock = "/tmp/fusion-project-svc.sock"

    @discardableResult
    func projectCall(method: String, params: [String: Any] = [:]) async throws -> [String: Any] {
        return try await udsCall(socketPath: Self.projectSvcSock, method: method, params: params)
    }

    func projectList(includeArchived: Bool = false, onlyStarred: Bool = false) async throws -> [String: Any] {
        var p: [String: Any] = [:]
        if includeArchived { p["include_archived"] = true }
        if onlyStarred { p["only_starred"] = true }
        return try await projectCall(method: "project.list", params: p)
    }

    func projectCreate(name: String, description: String = "", defaultAgentId: String? = nil, ragMode: String? = nil, ragTopK: Int? = nil, ragThreshold: Double? = nil, kbId: String? = nil, promptMergeMode: String? = nil) async throws -> [String: Any] {
        var p: [String: Any] = ["name": name]
        if !description.isEmpty { p["description"] = description }
        if let v = defaultAgentId { p["default_agent_id"] = v }
        if let v = ragMode { p["rag_mode"] = v }
        if let v = ragTopK { p["rag_top_k"] = v }
        if let v = ragThreshold { p["rag_threshold"] = v }
        if let v = kbId { p["kb_id"] = v }
        if let v = promptMergeMode { p["prompt_merge_mode"] = v }
        return try await projectCall(method: "project.create", params: p)
    }

    func projectGet(projectId: String) async throws -> [String: Any] {
        return try await projectCall(method: "project.get", params: ["project_id": projectId])
    }

    func projectUpdate(projectId: String, fields: [String: Any]) async throws -> [String: Any] {
        return try await projectCall(method: "project.update", params: ["project_id": projectId, "fields": fields])
    }

    func projectArchive(projectId: String) async throws -> [String: Any] {
        return try await projectCall(method: "project.archive", params: ["project_id": projectId])
    }

    func projectUnarchive(projectId: String) async throws -> [String: Any] {
        return try await projectCall(method: "project.unarchive", params: ["project_id": projectId])
    }

    func projectStar(projectId: String, starred: Bool = true) async throws -> [String: Any] {
        return try await projectCall(method: "project.star", params: ["project_id": projectId, "starred": starred])
    }

    func projectDelete(projectId: String) async throws -> [String: Any] {
        return try await projectCall(method: "project.delete", params: ["project_id": projectId])
    }

    func projectInstructionGet(projectId: String) async throws -> [String: Any] {
        return try await projectCall(method: "project.instruction.get", params: ["project_id": projectId])
    }

    func projectInstructionSave(projectId: String, content: String) async throws -> [String: Any] {
        return try await projectCall(method: "project.instruction.save", params: ["project_id": projectId, "content": content])
    }

    func projectInstructionClear(projectId: String) async throws -> [String: Any] {
        return try await projectCall(method: "project.instruction.clear", params: ["project_id": projectId])
    }

    func projectInstructionSnapshots(projectId: String) async throws -> [String: Any] {
        return try await projectCall(method: "project.instruction.snapshots", params: ["project_id": projectId])
    }

    func projectInstructionSnapshotRestore(snapshotId: String) async throws -> [String: Any] {
        return try await projectCall(method: "project.instruction.snapshot.restore", params: ["snapshot_id": snapshotId])
    }

    func projectInstructionSnapshotDelete(snapshotId: String) async throws -> [String: Any] {
        return try await projectCall(method: "project.instruction.snapshot.delete", params: ["snapshot_id": snapshotId])
    }

    func projectArtifactMigrate(projectId: String, artifactId: String) async throws -> [String: Any] {
        return try await projectCall(method: "project.artifact.migrate", params: ["project_id": projectId, "artifact_id": artifactId])
    }

    func projectArtifactList(projectId: String) async throws -> [String: Any] {
        return try await projectCall(method: "project.artifact.list", params: ["project_id": projectId])
    }

    func projectArtifactRemove(artifactId: String) async throws -> [String: Any] {
        return try await projectCall(method: "project.artifact.remove", params: ["artifact_id": artifactId])
    }

    func projectArtifactExport(projectId: String, artifactIds: [String]? = nil) async throws -> [String: Any] {
        var p: [String: Any] = ["project_id": projectId]
        if let ids = artifactIds { p["artifact_ids"] = ids }
        return try await projectCall(method: "project.artifact.export", params: p)
    }

    func projectDuplicate(projectId: String, name: String? = nil) async throws -> [String: Any] {
        var p: [String: Any] = ["project_id": projectId]
        if let n = name { p["name"] = n }
        return try await projectCall(method: "project.duplicate", params: p)
    }

    func projectExport(projectId: String) async throws -> [String: Any] {
        return try await projectCall(method: "project.export", params: ["project_id": projectId])
    }

    // MARK: - Project Chat

    func projectChatList(projectId: String, onlyStarred: Bool = false) async throws -> [String: Any] {
        var p: [String: Any] = ["project_id": projectId]
        if onlyStarred { p["only_starred"] = true }
        return try await projectCall(method: "project.chat.list", params: p)
    }

    func projectChatCreate(projectId: String, title: String = "New Chat", model: String? = nil, agentId: String? = nil) async throws -> [String: Any] {
        var p: [String: Any] = ["project_id": projectId, "title": title]
        if let m = model { p["model"] = m }
        if let a = agentId { p["agent_id"] = a }
        return try await projectCall(method: "project.chat.create", params: p)
    }

    func projectChatGet(chatId: String) async throws -> [String: Any] {
        return try await projectCall(method: "project.chat.get", params: ["chat_id": chatId])
    }

    func projectChatUpdate(chatId: String, fields: [String: Any]) async throws -> [String: Any] {
        return try await projectCall(method: "project.chat.update", params: ["chat_id": chatId, "fields": fields])
    }

    func projectChatStar(chatId: String, starred: Bool = true) async throws -> [String: Any] {
        return try await projectCall(method: "project.chat.star", params: ["chat_id": chatId, "starred": starred])
    }

    func projectChatDelete(chatId: String) async throws -> [String: Any] {
        return try await projectCall(method: "project.chat.delete", params: ["chat_id": chatId])
    }

    func projectChatFork(chatId: String, label: String? = nil) async throws -> [String: Any] {
        var p: [String: Any] = ["chat_id": chatId]
        if let l = label { p["label"] = l }
        return try await projectCall(method: "project.chat.fork", params: p)
    }

    func projectChatMove(chatId: String, targetProjectId: String) async throws -> [String: Any] {
        return try await projectCall(method: "project.chat.move", params: ["chat_id": chatId, "target_project_id": targetProjectId])
    }

    func projectChatDetach(chatId: String) async throws -> [String: Any] {
        return try await projectCall(method: "project.chat.detach", params: ["chat_id": chatId])
    }

    // MARK: - Project Chat Snapshot

    func projectChatSnapshotCreate(chatId: String, label: String? = nil) async throws -> [String: Any] {
        var p: [String: Any] = ["chat_id": chatId]
        if let l = label { p["label"] = l }
        return try await projectCall(method: "project.chat.snapshot.create", params: p)
    }

    func projectChatSnapshotList(chatId: String) async throws -> [String: Any] {
        return try await projectCall(method: "project.chat.snapshot.list", params: ["chat_id": chatId])
    }

    func projectChatSnapshotRestore(snapshotId: String) async throws -> [String: Any] {
        return try await projectCall(method: "project.chat.snapshot.restore", params: ["snapshot_id": snapshotId])
    }

    func projectChatSnapshotDelete(snapshotId: String) async throws -> [String: Any] {
        return try await projectCall(method: "project.chat.snapshot.delete", params: ["snapshot_id": snapshotId])
    }

    // MARK: - Project Chat Messages

    func projectMessageList(chatId: String, limit: Int = 100, offset: Int = 0) async throws -> [String: Any] {
        return try await projectCall(method: "project.chat.message.list", params: ["chat_id": chatId, "limit": limit, "offset": offset])
    }

    func projectMessageAdd(chatId: String, content: String, ragMode: String? = nil, ragScope: [String]? = nil, tempFileIds: [String]? = nil) async throws -> [String: Any] {
        var p: [String: Any] = ["chat_id": chatId, "content": content]
        if let r = ragMode { p["rag_mode"] = r }
        if let s = ragScope { p["rag_scope"] = s }
        if let t = tempFileIds { p["temp_file_ids"] = t }
        return try await projectCall(method: "project.chat.message.add", params: p)
    }

    func projectMessageDelete(messageId: String) async throws -> [String: Any] {
        return try await projectCall(method: "project.chat.message.delete", params: ["message_id": messageId])
    }

    // MARK: - Project Temp Attachments

    func projectTempAttachmentAdd(chatId: String, filePath: String, originalName: String, fileSize: Int = 0, mimeType: String? = nil) async throws -> [String: Any] {
        var p: [String: Any] = ["chat_id": chatId, "file_path": filePath, "original_name": originalName, "file_size": fileSize]
        if let m = mimeType { p["mime_type"] = m }
        return try await projectCall(method: "project.chat.temp_attachment.add", params: p)
    }

    func projectTempAttachmentList(chatId: String) async throws -> [String: Any] {
        return try await projectCall(method: "project.chat.temp_attachment.list", params: ["chat_id": chatId])
    }

    func projectTempAttachmentDelete(attachmentId: String) async throws -> [String: Any] {
        return try await projectCall(method: "project.chat.temp_attachment.delete", params: ["attachment_id": attachmentId])
    }

    // MARK: - Project Knowledge Folders

    func projectFolderList(projectId: String, parentId: String? = nil) async throws -> [String: Any] {
        var p: [String: Any] = ["project_id": projectId]
        if let pid = parentId { p["parent_id"] = pid }
        return try await projectCall(method: "project.knowledge.folder.list", params: p)
    }

    func projectFolderCreate(projectId: String, name: String, parentId: String? = nil) async throws -> [String: Any] {
        var p: [String: Any] = ["project_id": projectId, "name": name]
        if let pid = parentId { p["parent_id"] = pid }
        return try await projectCall(method: "project.knowledge.folder.create", params: p)
    }

    func projectFolderUpdate(folderId: String, name: String? = nil, parentId: String? = nil) async throws -> [String: Any] {
        var p: [String: Any] = ["folder_id": folderId]
        if let n = name { p["name"] = n }
        if let pid = parentId { p["parent_id"] = pid }
        return try await projectCall(method: "project.knowledge.folder.update", params: p)
    }

    func projectFolderDelete(folderId: String) async throws -> [String: Any] {
        return try await projectCall(method: "project.knowledge.folder.delete", params: ["folder_id": folderId])
    }

    // MARK: - Project Knowledge Files

    func projectKnowledgeFileList(projectId: String, folderId: String? = nil) async throws -> [String: Any] {
        var p: [String: Any] = ["project_id": projectId]
        if let fid = folderId { p["folder_id"] = fid }
        return try await projectCall(method: "project.knowledge.file.list", params: p)
    }

    func projectKnowledgeFileGet(fileId: String) async throws -> [String: Any] {
        return try await projectCall(method: "project.knowledge.file.get", params: ["file_id": fileId])
    }

    func projectKnowledgeFileDelete(fileId: String) async throws -> [String: Any] {
        return try await projectCall(method: "project.knowledge.file.delete", params: ["file_id": fileId])
    }

    func projectKnowledgeFileUpload(projectId: String, sourcePath: String, originalName: String, folderId: String? = nil, mimeType: String? = nil) async throws -> [String: Any] {
        var p: [String: Any] = ["project_id": projectId, "source_path": sourcePath, "original_name": originalName]
        if let fid = folderId { p["folder_id"] = fid }
        if let m = mimeType { p["mime_type"] = m }
        return try await projectCall(method: "project.knowledge.file.upload", params: p)
    }

    func projectKnowledgeFileReplace(fileId: String, sourcePath: String) async throws -> [String: Any] {
        return try await projectCall(method: "project.knowledge.file.replace", params: ["file_id": fileId, "source_path": sourcePath])
    }

    func projectKnowledgeFileRename(fileId: String, name: String) async throws -> [String: Any] {
        return try await projectCall(method: "project.knowledge.file.rename", params: ["file_id": fileId, "name": name])
    }

    func projectKnowledgeFileMove(fileId: String, folderId: String?) async throws -> [String: Any] {
        var p: [String: Any] = ["file_id": fileId]
        if let fid = folderId { p["folder_id"] = fid }
        return try await projectCall(method: "project.knowledge.file.move", params: p)
    }

    func projectKnowledgeFileStatuses(projectId: String) async throws -> [String: Any] {
        return try await projectCall(method: "project.knowledge.file.statuses", params: ["project_id": projectId])
    }

    // MARK: - Project Agent Binding

    func projectAgentGet(projectId: String, chatId: String? = nil) async throws -> [String: Any] {
        var p: [String: Any] = ["project_id": projectId]
        if let cid = chatId { p["chat_id"] = cid }
        return try await projectCall(method: "project.agent.get", params: p)
    }

    func projectAgentSet(projectId: String, agentId: String? = nil, mergeMode: String? = nil, chatId: String? = nil) async throws -> [String: Any] {
        var p: [String: Any] = ["project_id": projectId]
        if let a = agentId { p["agent_id"] = a }
        if let m = mergeMode { p["merge_mode"] = m }
        if let c = chatId { p["chat_id"] = c }
        return try await projectCall(method: "project.agent.set", params: p)
    }

    func projectAgentRemove(projectId: String, chatId: String? = nil) async throws -> [String: Any] {
        var p: [String: Any] = ["project_id": projectId]
        if let c = chatId { p["chat_id"] = c }
        return try await projectCall(method: "project.agent.remove", params: p)
    }

    func projectAgentList() async throws -> [String: Any] {
        return try await projectCall(method: "project.agent.list", params: [:])
    }

    func projectAgentPreview(agentId: String) async throws -> [String: Any] {
        return try await projectCall(method: "project.agent.preview", params: ["agent_id": agentId])
    }

    func projectAgentSystemPrompt(projectId: String, agentPrompt: String? = nil, chatId: String? = nil) async throws -> [String: Any] {
        var p: [String: Any] = ["project_id": projectId]
        if let ap = agentPrompt { p["agent_prompt"] = ap }
        if let c = chatId { p["chat_id"] = c }
        return try await projectCall(method: "project.agent.system_prompt", params: p)
    }

    // MARK: - Project RAG

    func projectRagIndexFile(projectId: String, fileId: String) async throws -> [String: Any] {
        return try await projectCall(method: "project.rag.index_file", params: ["project_id": projectId, "file_id": fileId])
    }

    func projectRagIndexFolder(projectId: String, folderId: String) async throws -> [String: Any] {
        return try await projectCall(method: "project.rag.index_folder", params: ["project_id": projectId, "folder_id": folderId])
    }

    func projectRagQuery(projectId: String, query: String, mode: String? = nil, folderIds: [String]? = nil, topK: Int? = nil, threshold: Double? = nil, chatId: String? = nil) async throws -> [String: Any] {
        var p: [String: Any] = ["project_id": projectId, "query": query]
        if let m = mode { p["mode"] = m }
        if let f = folderIds { p["folder_ids"] = f }
        if let k = topK { p["top_k"] = k }
        if let t = threshold { p["threshold"] = t }
        if let c = chatId { p["chat_id"] = c }
        return try await projectCall(method: "project.rag.query", params: p)
    }

    func projectRagRemoveIndex(projectId: String, fileId: String) async throws -> [String: Any] {
        return try await projectCall(method: "project.rag.remove_index", params: ["project_id": projectId, "file_id": fileId])
    }

    func projectRagStatus(projectId: String) async throws -> [String: Any] {
        return try await projectCall(method: "project.rag.status", params: ["project_id": projectId])
    }

    func projectRagConfigGet(projectId: String) async throws -> [String: Any] {
        return try await projectCall(method: "project.rag.config.get", params: ["project_id": projectId])
    }

    func projectRagConfigSet(projectId: String, ragMode: String? = nil, ragTopK: Int? = nil, ragThreshold: Double? = nil) async throws -> [String: Any] {
        var p: [String: Any] = ["project_id": projectId]
        if let m = ragMode { p["rag_mode"] = m }
        if let k = ragTopK { p["rag_top_k"] = k }
        if let t = ragThreshold { p["rag_threshold"] = t }
        return try await projectCall(method: "project.rag.config.set", params: p)
    }

    // MARK: - Project Upstream

    func projectUpstreamHealth() async throws -> [String: Any] {
        return try await projectCall(method: "project.upstream.health", params: [:])
    }

    func projectUpstreamCircuits() async throws -> [String: Any] {
        return try await projectCall(method: "project.upstream.circuits", params: [:])
    }

    // MARK: - Project Audit

    func projectAuditList(projectId: String, limit: Int = 100, offset: Int = 0) async throws -> [String: Any] {
        return try await projectCall(method: "project.audit.list", params: ["project_id": projectId, "limit": limit, "offset": offset])
    }

    func projectAuditLog(projectId: String, action: String, chatId: String? = nil, agentId: String? = nil, details: String? = nil) async throws -> [String: Any] {
        var p: [String: Any] = ["project_id": projectId, "action": action]
        if let c = chatId { p["chat_id"] = c }
        if let a = agentId { p["agent_id"] = a }
        if let d = details { p["details"] = d }
        return try await projectCall(method: "project.audit.log", params: p)
    }

    // MARK: - Project Cowork

    func projectCoworkTrigger(projectId: String, action: String, payload: [String: Any]? = nil) async throws -> [String: Any] {
        var p: [String: Any] = ["project_id": projectId, "action": action]
        if let pl = payload { p.merge(pl) { _, new in new } }
        return try await projectCall(method: "cowork.trigger", params: p)
    }

    func projectCoworkStatus(taskId: String) async throws -> [String: Any] {
        return try await projectCall(method: "cowork.status", params: ["task_id": taskId])
    }

    // MARK: - CoWork Space (UDS /tmp/fusion-cowork.sock desk.space.*, Issue #38)

    // Callers: SpaceListView / SpaceMainView 等 CoWork GUI. Affected API: spaceCall + 11 desk.space.* methods.
    // 注意: desk_rpc 监听 /tmp/fusion-cowork.sock, 非 /tmp/fusion-studio.sock (env-daemon 不转发 desk.*)
    private static let coworkDeskSock = "/tmp/fusion-cowork.sock"

    @discardableResult
    func spaceCall(method: String, params: [String: Any] = [:]) async throws -> [String: Any] {
        return try await udsCall(socketPath: Self.coworkDeskSock, method: method, params: params)
    }

    func spaceCreate(name: String, ownerId: String = "local_user", description: String = "", collabMode: String = "local") async throws -> [String: Any] {
        return try await spaceCall(method: "desk.space.create", params: [
            "name": name, "owner_id": ownerId, "description": description, "collab_mode": collabMode,
        ])
    }

    func spaceList(status: String? = nil, ownerId: String? = nil, limit: Int = 20) async throws -> [String: Any] {
        var p: [String: Any] = ["limit": limit]
        if let s = status { p["status"] = s }
        if let o = ownerId { p["owner_id"] = o }
        return try await spaceCall(method: "desk.space.list", params: p)
    }

    func spaceGet(spaceId: String) async throws -> [String: Any] {
        return try await spaceCall(method: "desk.space.get", params: ["space_id": spaceId])
    }

    func spaceUpdate(spaceId: String, updates: [String: Any]) async throws -> [String: Any] {
        return try await spaceCall(method: "desk.space.update", params: ["space_id": spaceId, "updates": updates])
    }

    func spaceArchive(spaceId: String) async throws -> [String: Any] {
        return try await spaceCall(method: "desk.space.archive", params: ["space_id": spaceId])
    }

    func spaceDelete(spaceId: String) async throws -> [String: Any] {
        return try await spaceCall(method: "desk.space.delete", params: ["space_id": spaceId])
    }

    func spaceMemberInvite(spaceId: String, inviterId: String = "local_user", role: String = "member", maxUses: Int = 0, expiresHours: Int = 0) async throws -> [String: Any] {
        return try await spaceCall(method: "desk.space.member.invite", params: [
            "space_id": spaceId, "inviter_id": inviterId, "role": role, "max_uses": maxUses, "expires_hours": expiresHours,
        ])
    }

    func spaceMemberJoin(inviteCode: String, userId: String, displayName: String = "") async throws -> [String: Any] {
        var p: [String: Any] = ["invite_code": inviteCode, "user_id": userId]
        if !displayName.isEmpty { p["display_name"] = displayName }
        return try await spaceCall(method: "desk.space.member.join", params: p)
    }

    func spaceMemberList(spaceId: String) async throws -> [String: Any] {
        return try await spaceCall(method: "desk.space.member.list", params: ["space_id": spaceId])
    }

    func spaceMemberRemove(spaceId: String, userId: String, operatorId: String = "local_user") async throws -> [String: Any] {
        return try await spaceCall(method: "desk.space.member.remove", params: [
            "space_id": spaceId, "user_id": userId, "operator_id": operatorId,
        ])
    }

    func spaceMemberUpdateRole(spaceId: String, userId: String, newRole: String, operatorId: String = "local_user") async throws -> [String: Any] {
        return try await spaceCall(method: "desk.space.member.update_role", params: [
            "space_id": spaceId, "user_id": userId, "new_role": newRole, "operator_id": operatorId,
        ])
    }

    // MARK: - CoWork Chat (desk.space.chat.*)

    func spaceChatSend(spaceId: String, content: String, senderId: String = "local_user",
                        senderName: String = "", mentionedAgents: [String] = []) async throws -> [String: Any] {
        var p: [String: Any] = [
            "space_id": spaceId, "content": content,
            "sender_id": senderId, "sender_name": senderName,
        ]
        if !mentionedAgents.isEmpty { p["mentioned_agents"] = mentionedAgents }
        return try await spaceCall(method: "desk.space.chat.send", params: p)
    }

    func spaceChatHistory(spaceId: String, limit: Int = 50, before: String? = nil) async throws -> [String: Any] {
        var p: [String: Any] = ["space_id": spaceId, "limit": limit]
        if let b = before { p["before"] = b }
        return try await spaceCall(method: "desk.space.chat.history", params: p)
    }

    func spaceChatStream(spaceId: String, content: String, senderId: String = "local_user") async throws -> [String: Any] {
        return try await spaceCall(method: "desk.space.chat.stream", params: [
            "space_id": spaceId, "content": content, "sender_id": senderId,
        ])
    }

    func spaceChatStreamEvents(spaceId: String, content: String, senderId: String = "local_user",
                                mentionedAgents: [String] = []) -> AsyncThrowingStream<StreamChatEvent, Error> {
        var p: [String: Any] = [
            "space_id": spaceId, "content": content,
            "sender_id": senderId, "stream": true,
        ]
        if !mentionedAgents.isEmpty { p["mentioned_agents"] = mentionedAgents }

        return AsyncThrowingStream { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let sock = socket(AF_UNIX, SOCK_STREAM, 0)
                guard sock >= 0 else {
                    continuation.finish(throwing: IPCError.invalidRequest)
                    return
                }
                var tv = timeval(tv_sec: 120, tv_usec: 0)
                _ = setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
                var addr = sockaddr_un()
                addr.sun_family = sa_family_t(AF_UNIX)
                let pathC = Self.coworkDeskSock.utf8CString
                let pathLen = min(pathC.count, MemoryLayout.size(ofValue: addr.sun_path))
                _ = pathC.withUnsafeBufferPointer { src in
                    withUnsafeMutableBytes(of: &addr.sun_path) { dst in
                        dst.copyMemory(from: UnsafeRawBufferPointer(
                            start: UnsafeRawPointer(src.baseAddress!),
                            count: pathLen
                        ))
                    }
                }
                let conn = Darwin.connect(sock, withUnsafePointer(to: &addr) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { $0 }
                }, socklen_t(MemoryLayout<sockaddr_un>.size))
                guard conn >= 0 else {
                    close(sock)
                    ipcLog.warning("spaceChatStreamEvents connect failed")
                    continuation.finish(throwing: IPCError.disconnected)
                    return
                }
                var request: [String: Any] = [
                    "jsonrpc": "2.0",
                    "id": Int(Date().timeIntervalSince1970 * 1000),
                    "method": "desk.space.chat.stream",
                    "params": p,
                ]
                guard let data = try? JSONSerialization.data(withJSONObject: request) else {
                    close(sock)
                    continuation.finish(throwing: IPCError.invalidRequest)
                    return
                }
                var writeBuf = data
                writeBuf.append(0x0A)
                writeBuf.withUnsafeBytes { ptr in
                    _ = Darwin.write(sock, ptr.baseAddress, writeBuf.count)
                }
                ipcLog.info("spaceChatStreamEvents request sent space=\(spaceId)")
                var lineBuf = Data()
                var readBuf = [UInt8](repeating: 0, count: 16384)
                var done = false
                while !done {
                    let n = readBuf.withUnsafeMutableBufferPointer { Darwin.read(sock, $0.baseAddress!, $0.count) }
                    if n > 0 {
                        lineBuf.append(contentsOf: readBuf[0..<n])
                        while let nlIdx = lineBuf.firstIndex(of: 0x0A) {
                            let lineData = lineBuf.subdata(in: 0..<nlIdx)
                            lineBuf.removeSubrange(0...nlIdx)
                            guard !lineData.isEmpty,
                                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else { continue }
                            if let error = json["error"] as? [String: Any] {
                                let msg = error["message"] as? String ?? "stream error"
                                let ev = StreamChatEvent(sessionId: spaceId, eventType: "error", content: msg, timestamp: Date().timeIntervalSince1970)
                                continuation.yield(ev)
                                done = true
                                break
                            }
                            let type = json["type"] as? String ?? ""
                            if type == "chat_event", let eventDict = json["event"] as? [String: Any] {
                                let ev = StreamChatEvent(
                                    sessionId: json["session_id"] as? String ?? spaceId,
                                    eventType: eventDict["type"] as? String ?? "",
                                    content: eventDict["content"] as? String ?? "",
                                    name: eventDict["name"] as? String ?? "",
                                    args: eventDict["args"] as? [String: Any] ?? [:],
                                    timestamp: eventDict["timestamp"] as? Double ?? 0
                                )
                                continuation.yield(ev)
                                if ev.isDone { done = true; break }
                            } else if type == "chat_done" || type == "done" {
                                done = true; break
                            } else if type == "result" {
                                if let resultDict = json["result"] as? [String: Any] {
                                    let content = resultDict["content"] as? String ?? ""
                                    if !content.isEmpty {
                                        let ev = StreamChatEvent(sessionId: spaceId, eventType: "token", content: content, timestamp: Date().timeIntervalSince1970)
                                        continuation.yield(ev)
                                    }
                                    let status = resultDict["status"] as? String ?? ""
                                    if status == "done" || status == "complete" { done = true; break }
                                }
                            }
                        }
                    } else {
                        break
                    }
                }
                close(sock)
                ipcLog.info("spaceChatStreamEvents finished space=\(spaceId)")
                continuation.finish()
            }
        }
    }

    // MARK: - CoWork Comments (desk.space.comment.*)

    func spaceCommentCreate(spaceId: String, messageId: String, authorId: String = "local_user",
                             authorName: String = "", content: String) async throws -> [String: Any] {
        return try await spaceCall(method: "desk.space.comment.create", params: [
            "space_id": spaceId, "message_id": messageId,
            "author_id": authorId, "author_name": authorName, "content": content,
        ])
    }

    func spaceCommentList(spaceId: String, messageId: String) async throws -> [String: Any] {
        return try await spaceCall(method: "desk.space.comment.list", params: [
            "space_id": spaceId, "message_id": messageId,
        ])
    }

    // MARK: - CoWork Snapshots (desk.space.snapshot.*)

    func spaceSnapshotCreate(spaceId: String, name: String) async throws -> [String: Any] {
        return try await spaceCall(method: "desk.space.snapshot.create", params: [
            "space_id": spaceId, "name": name,
        ])
    }

    func spaceSnapshotList(spaceId: String) async throws -> [String: Any] {
        return try await spaceCall(method: "desk.space.snapshot.list", params: ["space_id": spaceId])
    }

    func spaceSnapshotClone(spaceId: String, snapshotId: String, newName: String) async throws -> [String: Any] {
        return try await spaceCall(method: "desk.space.snapshot.fork", params: [
            "space_id": spaceId, "snapshot_id": snapshotId, "new_name": newName,
        ])
    }

    // MARK: - CoWork Agents (desk.space.agent.*)

    func spaceAgentList(spaceId: String) async throws -> [String: Any] {
        return try await spaceCall(method: "desk.space.agent.list", params: ["space_id": spaceId])
    }

    func spaceAgentAdd(spaceId: String, agentName: String, systemPrompt: String = "",
                        permission: String = "all_member", model: String = "") async throws -> [String: Any] {
        var p: [String: Any] = [
            "space_id": spaceId, "agent_name": agentName,
            "system_prompt": systemPrompt, "permission": permission,
        ]
        if !model.isEmpty { p["model"] = model }
        return try await spaceCall(method: "desk.space.agent.add", params: p)
    }

    func spaceAgentRemove(spaceId: String, agentId: String) async throws -> [String: Any] {
        return try await spaceCall(method: "desk.space.agent.remove", params: [
            "space_id": spaceId, "agent_id": agentId,
        ])
    }

    func spaceAgentUpdate(spaceId: String, agentId: String, agentName: String? = nil,
                           systemPrompt: String? = nil, permission: String? = nil,
                           model: String? = nil) async throws -> [String: Any] {
        var p: [String: Any] = ["space_id": spaceId, "agent_id": agentId]
        if let n = agentName { p["agent_name"] = n }
        if let s = systemPrompt { p["system_prompt"] = s }
        if let pr = permission { p["permission"] = pr }
        if let m = model { p["model"] = m }
        return try await spaceCall(method: "desk.space.agent.update", params: p)
    }

    func spaceAgentCall(spaceId: String, agentId: String, userId: String = "local_user",
                         message: String, model: String? = nil) async throws -> [String: Any] {
        var p: [String: Any] = [
            "space_id": spaceId, "agent_id": agentId,
            "user_id": userId, "message": message,
        ]
        if let m = model { p["model"] = m }
        return try await spaceCall(method: "desk.space.agent.call", params: p)
    }

    func spaceAgentRelay(spaceId: String, agentIds: [String], userId: String = "local_user",
                          message: String, model: String? = nil) async throws -> [String: Any] {
        var p: [String: Any] = [
            "space_id": spaceId, "agent_ids": agentIds,
            "user_id": userId, "message": message,
        ]
        if let m = model { p["model"] = m }
        return try await spaceCall(method: "desk.space.agent.relay", params: p)
    }

    // MARK: - CoWork Discovery (desk.space.discovery.*)

    func spaceDiscoveryScan() async throws -> [String: Any] {
        return try await spaceCall(method: "desk.space.discovery.scan", params: [:])
    }

    // MARK: - CoWork Workflows (desk.space.workflow.*)

    func spaceWorkflowList(spaceId: String) async throws -> [String: Any] {
        return try await spaceCall(method: "desk.space.workflow.list", params: ["space_id": spaceId])
    }

    func spaceWorkflowRun(spaceId: String, workflowId: String) async throws -> [String: Any] {
        return try await spaceCall(method: "desk.space.workflow.run", params: [
            "space_id": spaceId, "workflow_id": workflowId,
        ])
    }

    func spaceWorkflowCreate(spaceId: String, name: String, description: String = "") async throws -> [String: Any] {
        return try await spaceCall(method: "desk.space.workflow.create", params: [
            "space_id": spaceId, "name": name, "description": description,
        ])
    }

    // MARK: - CoWork Artifacts (desk.space.artifact.*)

    func spaceArtifactList(spaceId: String, kind: String? = nil) async throws -> [String: Any] {
        var p: [String: Any] = ["space_id": spaceId]
        if let k = kind { p["kind"] = k }
        return try await spaceCall(method: "desk.space.artifact.list", params: p)
    }

    func spaceArtifactCreate(spaceId: String, name: String, kind: String,
                              description: String = "", filePath: String = "") async throws -> [String: Any] {
        var p: [String: Any] = [
            "space_id": spaceId, "name": name, "kind": kind,
        ]
        if !description.isEmpty { p["description"] = description }
        if !filePath.isEmpty { p["file_path"] = filePath }
        return try await spaceCall(method: "desk.space.artifact.create", params: p)
    }

    func spaceArtifactGet(spaceId: String, artifactId: String) async throws -> [String: Any] {
        return try await spaceCall(method: "desk.space.artifact.get", params: [
            "space_id": spaceId, "artifact_id": artifactId,
        ])
    }

    func spaceArtifactDelete(spaceId: String, artifactId: String) async throws -> [String: Any] {
        return try await spaceCall(method: "desk.space.artifact.delete", params: [
            "space_id": spaceId, "artifact_id": artifactId,
        ])
    }

    func spaceArtifactUpdate(spaceId: String, artifactId: String, name: String? = nil,
                              content: String? = nil, metadata: [String: Any]? = nil) async throws -> [String: Any] {
        var p: [String: Any] = ["space_id": spaceId, "artifact_id": artifactId]
        if let n = name { p["name"] = n }
        if let c = content { p["content"] = c }
        if let md = metadata { p["metadata"] = md }
        return try await spaceCall(method: "desk.space.artifact.update", params: p)
    }

    func spaceArtifactShare(spaceId: String, artifactId: String) async throws -> [String: Any] {
        return try await spaceCall(method: "desk.space.artifact.share", params: [
            "space_id": spaceId, "artifact_id": artifactId,
        ])
    }

    func spaceArtifactTransfer(spaceId: String, artifactId: String,
                                fromUserId: String, toUserId: String) async throws -> [String: Any] {
        return try await spaceCall(method: "desk.space.artifact.transfer", params: [
            "space_id": spaceId, "artifact_id": artifactId,
            "from_user_id": fromUserId, "to_user_id": toUserId,
        ])
    }

    // MARK: - CoWork Snapshots (desk.space.snapshot.* - extended)

    func spaceSnapshotRestore(spaceId: String, snapshotId: String) async throws -> [String: Any] {
        return try await spaceCall(method: "desk.space.snapshot.restore", params: [
            "space_id": spaceId, "snapshot_id": snapshotId,
        ])
    }

    func spaceSnapshotDelete(spaceId: String, snapshotId: String) async throws -> [String: Any] {
        return try await spaceCall(method: "desk.space.snapshot.delete", params: [
            "space_id": spaceId, "snapshot_id": snapshotId,
        ])
    }

    // MARK: - CoWork Desktop (desk.space.desktop.*)

    func spaceDesktopShare(spaceId: String, action: String) async throws -> [String: Any] {
        return try await spaceCall(method: "desk.space.desktop.share", params: [
            "space_id": spaceId, "action": action,
        ])
    }

    func spaceDesktopControl(spaceId: String, action: String) async throws -> [String: Any] {
        return try await spaceCall(method: "desk.space.desktop.control", params: [
            "space_id": spaceId, "action": action,
        ])
    }

    // MARK: - CoWork Knowledge (desk.space.knowledge.*)

    func spaceKnowledgeBind(spaceId: String, kbId: String? = nil) async throws -> [String: Any] {
        var p: [String: Any] = ["space_id": spaceId]
        if let k = kbId { p["kb_id"] = k }
        return try await spaceCall(method: "desk.space.knowledge.bind", params: p)
    }

    func spaceKnowledgeStatus(spaceId: String) async throws -> [String: Any] {
        return try await spaceCall(method: "desk.space.knowledge.status", params: [
            "space_id": spaceId,
        ])
    }

    func spaceKnowledgeUpload(spaceId: String, filePath: String) async throws -> [String: Any] {
        return try await spaceCall(method: "desk.space.knowledge.upload", params: [
            "space_id": spaceId, "file_path": filePath,
        ])
    }

    func spaceKnowledgeSearch(spaceId: String, query: String, topK: Int = 5) async throws -> [String: Any] {
        return try await spaceCall(method: "desk.space.knowledge.search", params: [
            "space_id": spaceId, "query": query, "top_k": topK,
        ])
    }

    func spaceKnowledgeQuery(spaceId: String, question: String, topK: Int = 5) async throws -> [String: Any] {
        return try await spaceCall(method: "desk.space.knowledge.query", params: [
            "space_id": spaceId, "question": question, "top_k": topK,
        ])
    }

    func spaceKnowledgeUnbind(spaceId: String) async throws -> [String: Any] {
        return try await spaceCall(method: "desk.space.knowledge.unbind", params: [
            "space_id": spaceId,
        ])
    }

    // MARK: - CoWork Chat Context (desk.space.chat.context)

    func spaceChatContext(spaceId: String, limit: Int? = nil) async throws -> [String: Any] {
        var p: [String: Any] = ["space_id": spaceId]
        if let l = limit { p["limit"] = l }
        return try await spaceCall(method: "desk.space.chat.context", params: p)
    }

    // MARK: - CoWork Notifications (desk.notification.*)

    func spaceNotificationPush(spaceId: String, userId: String, title: String,
                                type: String = "info", content: String = "") async throws -> [String: Any] {
        var p: [String: Any] = [
            "space_id": spaceId, "user_id": userId,
            "title": title, "type": type,
        ]
        if !content.isEmpty { p["content"] = content }
        return try await spaceCall(method: "desk.notification.push", params: p)
    }

    func spaceNotificationList(userId: String, unreadOnly: Bool = false) async throws -> [String: Any] {
        return try await spaceCall(method: "desk.notification.list", params: [
            "user_id": userId, "unread_only": unreadOnly,
        ])
    }

    func spaceNotificationMarkRead(notificationId: String) async throws -> [String: Any] {
        return try await spaceCall(method: "desk.notification.markRead", params: [
            "id": notificationId,
        ])
    }

    // MARK: - CoWork Deep Research (desk.space.research.*)

    func spaceDeepResearch(spaceId: String, query: String, depth: Int = 2) async throws -> [String: Any] {
        return try await spaceCall(method: "desk.space.research.start", params: [
            "space_id": spaceId, "query": query, "depth": depth,
        ])
    }

    // MARK: - Multi-Node Cluster Sync (#74)

    func multiNodeCall(method: String, params: [String: Any] = [:]) async throws -> [String: Any] {
        let host = FusionConfig.shared.modelHubHost
        let port = 11452
        let urlStr = "http://\(host):\(port)/rpc"
        guard let url = URL(string: urlStr) else {
            throw IPCError.invalidRequest
        }
        var request: [String: Any] = [
            "jsonrpc": "2.0",
            "id": Int(Date().timeIntervalSince1970 * 1000),
            "method": method,
        ]
        if !params.isEmpty { request["params"] = params }
        guard let requestData = try? JSONSerialization.data(withJSONObject: request) else {
            throw IPCError.invalidRequest
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = requestData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw IPCError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw IPCError.rpcError(code: httpResponse.statusCode, message: "HTTP \(httpResponse.statusCode)")
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw IPCError.invalidResponse
        }
        if let error = json["error"] as? [String: Any] {
            let code = error["code"] as? Int ?? -1
            let msg = error["message"] as? String ?? "Unknown error"
            throw IPCError.rpcError(code: code, message: msg)
        }
        return json["result"] as? [String: Any] ?? [:]
    }

    func getModelManifest(modelName: String) async throws -> [String: Any] {
        return try await multiNodeCall(method: "cluster.get_model_manifest", params: ["model_name": modelName])
    }

    func triggerIncrementalSync(modelName: String, sourceHost: String, sourcePort: Int = 11452) async throws -> [String: Any] {
        return try await multiNodeCall(method: "cluster.incremental_sync", params: [
            "model_name": modelName,
            "source_host": sourceHost,
            "source_port": sourcePort,
        ])
    }

    func getClusterSyncStatus() async throws -> [String: Any] {
        return try await multiNodeCall(method: "cluster.sync_status")
    }

    func getNodeLoad(nodeId: String) async throws -> [String: Any] {
        return try await multiNodeCall(method: "cluster.get_node_load", params: ["node_id": nodeId])
    }

}
