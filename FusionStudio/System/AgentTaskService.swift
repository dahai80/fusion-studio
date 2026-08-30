// ARCH-1 PR6 (#359 facade-delegate): Task fetch 叶 silo 从 AgentBridge God-object 迁入 TaskState 域。
//   本文件含 2 extension:
//     1) extension TaskState — 2 真实方法体 (fetchTasks/fetchProjects, 自持 ipcClient + 2 TTL)。
//     2) extension AgentBridge — 2 个 1 行 facade stub 委托到 taskState.X(), 保外部 call site 签名零变。
//   仅迁 fetch 叶 (0 跨域依赖, 0 private static 依赖, 仅读 self.ipcClient + 写 self.tasks/projects + TTL)。
//   执行集群 (taskExecuteImmediate/taskSubmit/taskDelete/taskCancel/taskRerun/taskScheduleCron/
//     taskScheduleRunAt + taskRunHandles/backendCircuit/lockedTaskHandle/retryBackoffSeconds/taskIndex/
//     updateTask/reportTaskStatus/encodeCronInput/summarizeEvents) 留 AgentBridge — 跨域协调器
//     (依赖 executeGraph/parseEventModel/cronRegister + 共享 taskRunHandles/backendCircuit)。
//   @Published tasks/projects 在 TaskState 域 (外部 SwiftUI 读 TaskQueueView/ProjectsPanel), 经 bridge.taskState.X 不变。
//   Logger: 本文件自有 agentTaskLog 替代主类 private logger (跨文件不可达)。
//   ipcClient/TTL 为 internal (非 private): 跨文件 extension 访问, Swift private=文件作用域 (同 PR1-PR5 坑)。

import Foundation
import os.log

private let agentTaskLog = Logger(subsystem: "com.fusion.studio", category: "AgentTaskService")

// MARK: - Task Fetch Operations (行为落地 TaskState 域)
extension TaskState {

    // MARK: - Task Fetch Operations

    // 从后端 task.list 拉取持久化任务. 后端 5 态 → 前端 7 态.
    func fetchTasks() async {
        if let t = tasksFetchedAt, Date().timeIntervalSince(t) < 30 { return }
        tasksFetchedAt = Date()
        guard let client = self.ipcClient else { return }
        do {
            let result = try await client.taskList(limit: 200)
            let raw = result["tasks"] as? [[String: Any]] ?? []
            var parsed: [TaskModel] = []
            for d in raw {
                if let t = TaskModel(backendDict: d) { parsed.append(t) }
            }
            self.tasks = parsed
            agentTaskLog.info("fetchTasks: \(parsed.count) backend tasks")
        } catch {
            agentTaskLog.warning("fetchTasks failed: \(error.localizedDescription)")
        }
    }

    // 拉取 Project 聚合看板桶 (#141 priority-2). 后端 project.list 按 project_id 分组统计.
    func fetchProjects() async {
        if let t = projectsFetchedAt, Date().timeIntervalSince(t) < 30 { return }
        projectsFetchedAt = Date()
        guard let client = self.ipcClient else { return }
        do {
            let result = try await client.projectList()
            let raw = result["projects"] as? [[String: Any]] ?? []
            var parsed: [ProjectBucket] = []
            for d in raw {
                if let b = ProjectBucket(backendDict: d) { parsed.append(b) }
            }
            self.projects = parsed
            agentTaskLog.info("fetchProjects: \(parsed.count) projects")
        } catch {
            agentTaskLog.warning("fetchProjects failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Task Fetch Operations (facade-delegate stubs — 行为已迁 TaskState 域)
// ARCH-1 PR6: 本 extension 仅 1 行委托, 保外部 call site (bridge.X) 签名零变。
extension AgentBridge {

    func fetchTasks() async {
        await taskState.fetchTasks()
    }

    func fetchProjects() async {
        await taskState.fetchProjects()
    }
}
