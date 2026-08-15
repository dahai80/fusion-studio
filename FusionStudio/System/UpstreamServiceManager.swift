import Foundation
import Combine
import os.log
import SwiftUI
// Callers: ContentView service health UI, SettingsView
// Affected API: multi-node health endpoint (9753→cfg.multiNodePort=11452)
// Data: UpstreamService healthEndpoint string
// User instruction: "修复issue #111" — eliminate hardcoded 9753

// 上游服务状态横幅：在依赖上游服务的模块视图顶部展示服务状态 + 启动入口
struct UpstreamServiceStatusBanner: View {
    @EnvironmentObject var upstream: UpstreamServiceManager
    @Environment(\.studioTheme) private var theme
    let serviceId: String

    var body: some View {
        let svc = upstream.services.first { $0.id == serviceId }
        HStack(spacing: 10) {
            Image(systemName: svc?.icon ?? "bolt.horizontal")
                .foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(svc?.displayName ?? serviceId)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.text)
                Text(message(for: svc))
                    .font(.system(size: 11))
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(2)
            }
            Spacer()
            Circle()
                .fill(statusColor(svc))
                .frame(width: 8, height: 8)
            Text(svc?.status.text ?? "未知")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(theme.textSecondary)
            Button {
                Task { await upstream.refreshAll() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("刷新状态")
            Button("启动") {
                Task { await upstream.startService(id: serviceId) }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("调用 start.sh 启动服务")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.surfaceSecondary)
    }

    private func message(for svc: UpstreamService?) -> String {
        guard let svc = svc else { return "未注册" }
        return svc.message.isEmpty ? svc.status.text : svc.message
    }

    private func statusColor(_ svc: UpstreamService?) -> Color {
        switch svc?.status {
        case .running:      return theme.greenDot
        case .failed:       return theme.redDot
        case .notInstalled: return theme.redDot
        case .stopped:      return theme.amberDot
        case .starting:     return theme.amberDot
        default:            return theme.textTertiary
        }
    }
}

// 上游服务生命周期管理器
// Callers: FusionStudioApp.onAppear (ensureCriticalRunning on launch), UpstreamServiceStatusView (manual start/stop/refresh).
// Affected API: @Published services/startupCompleted/isRefreshing; hasCriticalFailure; ensureCriticalRunning/startService/stopService/refreshAll.
// Data schemas: [UpstreamService] (id/displayName/icon/isCritical/startOrder/repoPathRaw/healthKind/healthEndpoint/status/message).
// User instruction: "在所有依赖的上游模块根目录创建start.sh，在fusion-studio启动时需要检测上游服务是否启动，如果没有启动，尝试调用start.sh启动上游服务，如果启动不成功，fusion-studio要展示服务不存在，或者服务启动失败等等"

/// 上游服务状态
enum UpstreamServiceStatus: Equatable {
    case unknown
    case notApplicable   // CLI 工具，无服务进程（fusion-design）
    case notInstalled    // start.sh 不存在
    case stopped         // 已安装，未运行
    case starting        // 启动中
    case running
    case failed          // 启动失败

    var text: String {
        switch self {
        case .unknown:       return "未知"
        case .notApplicable: return "CLI 工具-无需启动"
        case .notInstalled:  return "服务不存在"
        case .stopped:       return "未启动"
        case .starting:      return "启动中..."
        case .running:       return "运行中"
        case .failed:        return "启动失败"
        }
    }
}

/// 健康探测方式
enum UpstreamHealthKind {
    case socket        // agent-studio: UDS 连接探测
    case httpGet       // mlx/multi-node/rag: HTTP GET 任意响应即存活
    case jsonRpcPing   // artifacts-engine: JSON-RPC POST 任意响应即存活
}

/// 上游服务定义
struct UpstreamService: Identifiable {
    let id: String
    let displayName: String
    let icon: String
    let isCritical: Bool
    let startOrder: Int          // 自动启动顺序（小先启动）
    let repoPathRaw: String      // 来自 FusionConfig（含 ~）
    let healthKind: UpstreamHealthKind
    let healthEndpoint: String   // URL 或 socket 路径
    var status: UpstreamServiceStatus = .unknown
    var message: String = ""
}

/// 上游服务管理器：启动时检测上游服务，必要时调用 start.sh 自动启动关键服务。
final class UpstreamServiceManager: ObservableObject {

    @Published var services: [UpstreamService] = []
    @Published var startupCompleted: Bool = false
    @Published var isRefreshing: Bool = false

    private let logger = Logger(subsystem: "com.fusion.studio", category: "UpstreamService")

    init() {
        rebuildRegistry()
    }

    /// 根据 FusionConfig 重建服务注册表
    private func rebuildRegistry() {
        let cfg = FusionConfig.shared
        services = [
            UpstreamService(id: "agent-studio",
                            displayName: "Agent Studio (Daemon)",
                            icon: "brain.head.profile",
                            isCritical: true, startOrder: 1,
                            repoPathRaw: cfg.upstreamAgentStudioPath,
                            healthKind: .socket, healthEndpoint: cfg.ipcSocketPath),
            UpstreamService(id: "mlx",
                            displayName: "MLX 推理服务",
                            icon: "cpu",
                            isCritical: true, startOrder: 0,
                            repoPathRaw: cfg.upstreamMlxPath,
                            healthKind: .httpGet, healthEndpoint: "\(cfg.mlxBaseURL)/health"),
            // Callers: DouyinOperationBridge 造片链 (Graph C 配图+TTS 经 agent-studio RPC 调 comfyui_image/comfyui_tts).
            // Affected API: UpstreamService entry, ensureCriticalRunning 按 startOrder=1 自动 start.sh start.
            // Data: UpstreamService struct. fix: comfyui 此前未注册，fusion-studio 不会自动拉起造片服务。
            // 健康路由 /system_stats (ComfyUI 标准，非 /health)。依赖 mlx (TTS http backend)，故 startOrder=1 与 agent-studio 同级、晚于 mlx=0。
            UpstreamService(id: "comfyui",
                            displayName: "ComfyUI 造片服务",
                            icon: "wand.and.stars",
                            isCritical: true, startOrder: 1,
                            repoPathRaw: cfg.upstreamComfyuiPath,
                            healthKind: .httpGet, healthEndpoint: "http://127.0.0.1:\(cfg.comfyuiPort)/system_stats"),
            UpstreamService(id: "artifacts-engine",
                            displayName: "Artifacts Engine",
                            icon: "shippingbox",
                            isCritical: true, startOrder: 2,
                            repoPathRaw: cfg.upstreamArtifactsPath,
                            healthKind: .jsonRpcPing, healthEndpoint: cfg.artifactsEngineURL),
            UpstreamService(id: "fusion-rag",
                            displayName: "Fusion-RAG (KB)",
                            icon: "books.vertical",
                            isCritical: false, startOrder: 3,
                            repoPathRaw: cfg.upstreamRagPath,
                            healthKind: .httpGet, healthEndpoint: "\(cfg.fusionRagURL)/health"),
            UpstreamService(id: "multi-node",
                            displayName: "Multi-Node Master",
                            icon: "network",
                            isCritical: false, startOrder: 4,
                            repoPathRaw: cfg.upstreamMultiNodePath,
                            healthKind: .httpGet, healthEndpoint: "http://localhost:\(cfg.multiNodePort)/api/health"),
            UpstreamService(id: "fusion-design",
                            displayName: "Fusion Design (fd-cli)",
                            icon: "paintbrush",
                            isCritical: false, startOrder: 99,
                            repoPathRaw: "~/fusion/fusion-design",
                            healthKind: .httpGet, healthEndpoint: "",
                            status: .notApplicable, message: "CLI 工具-无需启动"),
            UpstreamService(id: "fusion-cowork",
                            displayName: "Fusion-Cowork 协作",
                            icon: "desktopcomputer",
                            isCritical: false, startOrder: 5,
                            repoPathRaw: "~/fusion/fusion-cowork",
                            healthKind: .socket, healthEndpoint: "/tmp/fusion-cowork.sock"),
            UpstreamService(id: "fusion-model-hub",
                            displayName: "Fusion Model Hub",
                            icon: "shippingbox",
                            isCritical: false, startOrder: 6,
                            repoPathRaw: "~/fusion/fusion-model-hub",
                            healthKind: .httpGet, healthEndpoint: "http://localhost:\(cfg.modelHubPort)/api/v1/system/health"),
            UpstreamService(id: "fusion-security",
                            displayName: "Fusion-Security 审计",
                            icon: "shield.checkered",
                            isCritical: false, startOrder: 7,
                            repoPathRaw: "~/fusion/fusion-security",
                            healthKind: .httpGet, healthEndpoint: "http://localhost:\(cfg.securityPort)/api/v1/system/health"),
            UpstreamService(id: "fusion-code",
                            displayName: "Fusion Code API",
                            icon: "terminal",
                            isCritical: false, startOrder: 8,
                            repoPathRaw: cfg.upstreamFusionCodePath,
                            healthKind: .httpGet, healthEndpoint: "\(cfg.fusionCodeURL)/api/project/context"),
            UpstreamService(id: "project-svc",
                            displayName: "Fusion Projects 服务",
                            icon: "folder.badge.gearshape",
                            isCritical: false, startOrder: 9,
                            repoPathRaw: "~/fusion/fusion-projects",
                            healthKind: .socket, healthEndpoint: "/tmp/fusion-project-svc.sock"),
            UpstreamService(id: "cowork-desk",
                            displayName: "CoWork Desk RPC",
                            icon: "person.2.square.stack",
                            isCritical: false, startOrder: 10,
                            repoPathRaw: "~/fusion/fusion-cowork",
                            healthKind: .socket, healthEndpoint: "/tmp/fusion-cowork.sock"),
            UpstreamService(id: "fusion-science",
                            displayName: "Fusion-Science 科研",
                            icon: "atom",
                            isCritical: false, startOrder: 11,
                            repoPathRaw: cfg.upstreamSciencePath,
                            healthKind: .httpGet, healthEndpoint: "\(cfg.scienceBaseURL)/api/v1/health"),
            UpstreamService(id: "fusion-health",
                            displayName: "Fusion-Health 健康",
                            icon: "heart.text.square",
                            isCritical: false, startOrder: 13,
                            repoPathRaw: cfg.upstreamHealthPath,
                            healthKind: .httpGet, healthEndpoint: "\(cfg.healthBaseURL)/api/v1/health"),
            // Callers: DocBridge (baseURL 11449), EnvironmentHealthSheet case "doc". Affected API: httpGet health.
            // Data: UpstreamService entry. fix: fusion-doc 此前未纳入管理器，无自动启动/健康探测。
            // 端口 11449（与 multi-node 冲突已由 multi-node 迁至 11452 解决）。健康路由 /api/health。
            UpstreamService(id: "fusion-doc",
                            displayName: "Fusion-Doc 文档",
                            icon: "doc.text",
                            isCritical: false, startOrder: 14,
                            repoPathRaw: "~/fusion/fusion-doc",
                            healthKind: .httpGet, healthEndpoint: "http://127.0.0.1:\(cfg.fusionDocPort)/api/health"),
            // Callers: SimulationWorkbenchView UpstreamServiceStatusBanner(serviceId:"fusion-simulation"), refreshAll.
            // Affected API: UpstreamService entry (httpGet health at simulationBaseURL/api/health, port 11455).
            // Data: UpstreamService struct. User instruction: "和~/fusion/fuison-simulation项目集成起来"
            UpstreamService(id: "fusion-simulation",
                            displayName: "Fusion-Simulation 仿真",
                            icon: "cube.transparent",
                            isCritical: false, startOrder: 12,
                            repoPathRaw: cfg.upstreamSimulationPath,
                            healthKind: .httpGet, healthEndpoint: "\(cfg.simulationBaseURL)/api/health"),
        ]
    }

    /// 关键服务是否存在启动失败/服务不存在
    var hasCriticalFailure: Bool {
        services.contains { $0.isCritical && ($0.status == .failed || $0.status == .notInstalled) }
    }

    // MARK: - 启动流程

    /// 启动时调用：先全量探测，再按顺序自动启动未运行的服务。
    func ensureCriticalRunning() async {
        logger.info("ensureCriticalRunning: begin")
        await refreshAll()
        guard FusionConfig.shared.upstreamAutoStartCritical else {
            logger.info("auto-start disabled by config, skipping launch")
            await MainActor.run { self.startupCompleted = true }
            return
        }
        // 按依赖顺序启动所有未运行的服务（非关键服务失败不阻塞）
        let ordered = services
            .sorted { $0.startOrder < $1.startOrder }
        for svc in ordered {
            let cur = services.first { $0.id == svc.id }?.status ?? .unknown
            if cur == .stopped {
                logger.info("auto-starting service: \(svc.id)")
                await startService(id: svc.id)
            } else {
                logger.info("service \(svc.id) status=\(svc.status.text), skip auto-start")
            }
        }
        await MainActor.run { self.startupCompleted = true }
        logger.info("ensureCriticalRunning: done, hasCriticalFailure=\(self.hasCriticalFailure)")
    }

    /// 手动启动单个服务
    func startService(id: String) async {
        guard let idx = services.firstIndex(where: { $0.id == id }) else { return }
        let svc = services[idx]
        if svc.status == .notApplicable { return }

        let startSh = startShPath(for: svc)
        guard FileManager.default.isExecutableFile(atPath: startSh) else {
            logger.error("start.sh not found for \(svc.id): \(startSh)")
            await MainActor.run {
                services[idx].status = .notInstalled
                services[idx].message = "服务不存在：未找到 start.sh"
            }
            return
        }

        await MainActor.run {
            services[idx].status = .starting
            services[idx].message = "正在启动..."
        }

        let result = await Self.runStartSh(path: startSh, action: "start")
        logger.info("start.sh start for \(svc.id) exit=\(result.exitCode)")

        let healthy = await probeHealth(services[idx])
        await MainActor.run {
            if result.exitCode == 0 || healthy {
                services[idx].status = .running
                services[idx].message = healthy ? "运行中" : "已启动（健康探测待确认）"
            } else {
                services[idx].status = .failed
                let tail = result.output.split(separator: "\n").suffix(8).joined(separator: "\n")
                services[idx].message = "启动失败：\(tail)"
            }
        }
    }

    /// 手动停止单个服务
    func stopService(id: String) async {
        guard let idx = services.firstIndex(where: { $0.id == id }) else { return }
        let svc = services[idx]
        if svc.status == .notApplicable { return }
        let startSh = startShPath(for: svc)
        guard FileManager.default.isExecutableFile(atPath: startSh) else {
            await MainActor.run { services[idx].status = .notInstalled; services[idx].message = "服务不存在" }
            return
        }
        await MainActor.run { services[idx].message = "正在停止..." }
        let result = await Self.runStartSh(path: startSh, action: "stop")
        logger.info("start.sh stop for \(svc.id) exit=\(result.exitCode)")
        let healthy = await probeHealth(services[idx])
        await MainActor.run {
            services[idx].status = healthy ? .running : .stopped
            services[idx].message = healthy ? "运行中" : "已停止"
        }
    }

    /// 全量健康探测（不启动）
    func refreshAll() async {
        await MainActor.run { self.isRefreshing = true }
        let snapshot = services
        var updated: [UpstreamService] = []
        for var svc in snapshot {
            if svc.status == .notApplicable {
                updated.append(svc)
                continue
            }
            // .socket 健康探测自足：UDS connect 成功即存活，不依赖 start.sh
            // （fusion-cowork 无 start.sh，但 desk_rpc 由 fusion-studio start.sh 拉起）
            if svc.healthKind == .socket {
                let healthy = await probeHealth(svc)
                if healthy {
                    svc.status = .running
                    svc.message = "运行中"
                } else if FileManager.default.isExecutableFile(atPath: startShPath(for: svc)) {
                    svc.status = .stopped
                    svc.message = "未启动"
                } else {
                    svc.status = .notInstalled
                    svc.message = "服务不存在：未找到 start.sh"
                }
                updated.append(svc)
                continue
            }
            let startSh = startShPath(for: svc)
            if !FileManager.default.isExecutableFile(atPath: startSh) {
                svc.status = .notInstalled
                svc.message = "服务不存在：未找到 start.sh"
                updated.append(svc)
                continue
            }
            let healthy = await probeHealth(svc)
            svc.status = healthy ? .running : .stopped
            svc.message = healthy ? "运行中" : "未启动"
            updated.append(svc)
        }
        let refreshed = updated
        await MainActor.run {
            self.services = refreshed
            self.isRefreshing = false
        }
        logger.info("refreshAll done")
    }

    // MARK: - 探测与执行

    private func startShPath(for svc: UpstreamService) -> String {
        FusionConfig.shared.expandedUpstreamPath(svc.repoPathRaw) + "/start.sh"
    }

    private func probeHealth(_ svc: UpstreamService) async -> Bool {
        switch svc.healthKind {
        case .socket:
            return await Task.detached(priority: .userInitiated) { Self.probeSocket(path: svc.healthEndpoint) }.value
        case .httpGet:
            return await Self.probeHTTP(url: svc.healthEndpoint)
        case .jsonRpcPing:
            return await Self.probeJSONRpc(url: svc.healthEndpoint)
        }
    }

    /// UDS 连接探测：connect 成功即存活（stale socket 会连接失败）
    private static func probeSocket(path: String) -> Bool {
        guard FileManager.default.fileExists(atPath: path) else { return false }
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathCString = path.utf8CString
        let pathLen = min(pathCString.count, MemoryLayout.size(ofValue: addr.sun_path))
        // Callers: UpstreamServiceManager.probeSocket. Affected API: none. Data: fix _ = on Void-returning closure causing release build fatalError. User: "修复 Release workflow"
        pathCString.withUnsafeBufferPointer { src in
            withUnsafeMutableBytes(of: &addr.sun_path) { dst in
                dst.copyMemory(from: UnsafeRawBufferPointer(
                    start: UnsafeRawPointer(src.baseAddress!),
                    count: pathLen
                ))
            }
        }
        var tv = timeval(tv_sec: 2, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        let rc = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        return rc == 0
    }

    /// HTTP GET 探测：任意 HTTP 响应即视为服务在监听
    private static func probeHTTP(url: String) async -> Bool {
        guard let url = URL(string: url), !url.absoluteString.isEmpty else { return false }
        var req = URLRequest(url: url)
        req.timeoutInterval = 2.0
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            return (resp as? HTTPURLResponse) != nil
        } catch {
            return false
        }
    }

    /// JSON-RPC POST 探测：任意 HTTP 响应即视为服务在监听
    private static func probeJSONRpc(url: String) async -> Bool {
        guard let url = URL(string: url) else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 2.0
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = #"{"jsonrpc":"2.0","method":"ping","id":1}"#.data(using: .utf8)
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            return (resp as? HTTPURLResponse) != nil
        } catch {
            return false
        }
    }

    /// 同步执行 start.sh，返回退出码与合并输出。30s 强制终止，避免 waitUntilExit 永挂 (bug8)。
    private static func runStartSh(path: String, action: String) async -> (exitCode: Int32, output: String) {
        await withCheckedContinuation { (cont: CheckedContinuation<(Int32, String), Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/bash")
                process.arguments = [path, action]
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe
                do {
                    try process.run()
                } catch {
                    cont.resume(returning: (-1, error.localizedDescription))
                    return
                }
                let timeoutLock = NSLock()
                var didTimeout = false
                let timer = DispatchSource.makeTimerSource(queue: .global(qos: .userInitiated))
                timer.schedule(deadline: .now() + 30)
                timer.setEventHandler {
                    timeoutLock.lock()
                    if process.isRunning {
                        didTimeout = true
                        process.terminate()
                    }
                    timeoutLock.unlock()
                }
                timer.resume()
                process.waitUntilExit()
                timer.cancel()
                timeoutLock.lock()
                let timeout = didTimeout
                timeoutLock.unlock()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                var output = String(data: data, encoding: .utf8) ?? ""
                if timeout { output = "启动超时(30s)\n" + output }
                cont.resume(returning: (timeout ? -1 : process.terminationStatus, output))
            }
        }
    }
}
