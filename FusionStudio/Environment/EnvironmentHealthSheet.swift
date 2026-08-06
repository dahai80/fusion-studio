import SwiftUI
import os.log

private let envSheetLog = Logger(subsystem: "com.fusion.studio", category: "EnvHealthSheet")

// 环境健康检查弹窗：纯 HTTP/UDS 探活，覆盖所有 Fusion 子系统，不依赖 env-daemon。
// 由右上角 HealthStatusBadge 点击弹出。
struct EnvironmentHealthSheet: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var upstream: UpstreamServiceManager
    @Environment(\.studioTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var results: [HealthCheckItem] = []
    @State private var isChecking = false
    @State private var startingIds: Set<String> = []

    // 健康面板子系统 id -> UpstreamServiceManager 服务 id 映射
    // 仅可拉起有 start.sh 的服务；nil 表示该服务无 start.sh（如 gateway/doc 由其他服务托管）
    private let upstreamServiceIdMap: [String: String] = [
        "mlx": "mlx",
        "rag": "fusion-rag",
        "modelhub": "fusion-model-hub",
        "artifacts": "artifacts-engine",
        "cowork": "cowork-desk",
        "projects": "project-svc",
        "code": "fusion-code",
    ]

    // 全量子系统清单：id -> (label, icon, 探活方式)
    private let subsystems: [HealthCheckItem.Def] = [
        .init(id: "mlx", label: "Fusion-MLX 推理引擎", icon: "cpu"),
        .init(id: "gateway", label: "Fusion Gateway 鉴权网关", icon: "shield.lefthalf.filled"),
        .init(id: "rag", label: "Fusion RAG 检索增强", icon: "books.vertical"),
        .init(id: "modelhub", label: "Fusion Model Hub 模型仓库", icon: "square.stack.3d.up.fill"),
        .init(id: "artifacts", label: "Fusion Artifacts 产物引擎", icon: "cube.box"),
        .init(id: "cowork", label: "Fusion CoWork 协作", icon: "person.2.square.stack"),
        .init(id: "projects", label: "Fusion Projects 项目服务", icon: "folder.badge.gearshape"),
        .init(id: "doc", label: "Fusion Doc 文档服务", icon: "doc.text"),
        .init(id: "code", label: "Fusion Code 代码服务", icon: "chevron.left.forwardslash.chevron.right"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("环境健康检查", systemImage: "stethoscope")
                    .font(.system(size: theme.textSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                Spacer()
                Button(action: runCheck) {
                    Label(isChecking ? "检测中..." : "重新检测", systemImage: "arrow.clockwise")
                        .font(.system(size: theme.smallTextSize))
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.accent)
                .disabled(isChecking)
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: theme.iconM))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
                .help("关闭")
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.vertical, theme.spacingM)

            Rectangle().fill(theme.separator).frame(height: 1)

            if results.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: theme.spacingS) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 28))
                            .foregroundStyle(theme.textTertiary)
                        Text("点击「重新检测」扫描所有子系统")
                            .font(.system(size: theme.smallTextSize))
                            .foregroundStyle(theme.textSecondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 40)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(results) { item in
                            subsystemRow(item)
                        }
                    }
                    .padding(theme.spacingM)
                }
            }
        }
        .frame(width: 560, height: 480)
        .background(theme.contentBg)
        .onAppear { runCheck() }
    }

    private func subsystemRow(_ item: HealthCheckItem) -> some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: item.icon)
                .font(.system(size: theme.iconS))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 22)

            Text(item.label)
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.text)
                .frame(width: 220, alignment: .leading)

            Spacer()

            Circle()
                .fill(item.status.color)
                .frame(width: 7, height: 7)
            Text(item.status.text)
                .font(.system(size: theme.smallTextSize))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 70, alignment: .leading)

            if let detail = item.detail {
                Text(detail)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            // 探活失败且有 start.sh 的服务显示「启动」按钮，拉起后端服务
            if item.status == .failed, let svcId = upstreamServiceIdMap[item.id] {
                Button(action: { startService(item.id, svcId: svcId) }) {
                    Label(startingIds.contains(item.id) ? "启动中" : "启动", systemImage: "play.circle.fill")
                        .font(.system(size: theme.smallTextSize))
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.accent)
                .disabled(startingIds.contains(item.id))
            }
        }
        .padding(.horizontal, theme.spacingS)
        .padding(.vertical, 7)
        .background(item.status == .failed ? theme.warningBg.opacity(0.3) : Color.clear)
        .cornerRadius(theme.rowRadius)
    }

    // MARK: - 拉起服务

    // 调用 UpstreamServiceManager.startService 拉起失败的后端服务，成功后重新探活
    private func startService(_ itemId: String, svcId: String) {
        startingIds.insert(itemId)
        envSheetLog.info("startService: 拉起 \(itemId, privacy: .public) -> upstream \(svcId, privacy: .public)")
        Task {
            await upstream.startService(id: svcId)
            // start.sh 通常后台启动，给服务 3s 就绪后再探活
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run { startingIds.remove(itemId) }
            await runCheckAsync()
        }
    }

    // MARK: - 探活

    private func runCheck() {
        guard !isChecking else { return }
        Task { await runCheckAsync() }
    }

    // 探活核心逻辑（async），供 runCheck 与 startService 复用
    private func runCheckAsync() async {
        await MainActor.run {
            isChecking = true
            appState.healthStatus = .checking
            results = subsystems.map { def in
                HealthCheckItem(id: def.id, label: def.label, icon: def.icon, status: .checking, detail: nil)
            }
        }
        envSheetLog.info("runCheck: start \(self.subsystems.count) subsystems")
        let cfg = FusionConfig.shared
        let key = cfg.mlxResolvedApiKey
        var checked: [HealthCheckItem] = []
        for def in subsystems {
            let res = await probeSubsystem(def.id, cfg: cfg, apiKey: key)
            checked.append(res)
        }
        await MainActor.run {
            self.results = checked
            self.isChecking = false
            let hasIssues = checked.contains { $0.status == .failed }
            appState.healthStatus = hasIssues ? .issuesFound : .healthy
            appState.isHealthCheckPassed = !hasIssues
            envSheetLog.info("runCheck: done, issues=\(hasIssues)")
        }
    }

    // 各子系统探活：mlx/gateway/rag/artifacts/doc/code 走 HTTP 真实业务端点；
    // cowork/projects 走 UDS JSON-RPC 真实业务方法。
    // 判定标准：HTTP 仅 200-299 通过；UDS 仅返回 result 通过。401/403/404/业务error 一律判异常。
    private func probeSubsystem(_ id: String, cfg: FusionConfig, apiKey: String) async -> HealthCheckItem {
        guard let def = subsystems.first(where: { $0.id == id }) else {
            return HealthCheckItem(id: id, label: id, icon: "questionmark", status: .failed, detail: "未知子系统")
        }
        do {
            let detail: String
            switch id {
            // /health 端点真实存在且无需鉴权
            case "mlx":
                detail = try await probeHTTP("http://127.0.0.1:\(cfg.mlxPort)/health", headers: [:])
            case "gateway":
                detail = try await probeHTTP("http://127.0.0.1:11432/health", headers: [:])
            case "rag":
                // fusion-rag /health 需要 X-API-Key，沿用 MLX 解析出的 api key
                detail = try await probeHTTP("http://127.0.0.1:\(cfg.fusionRagPort)/health", headers: ["X-API-Key": apiKey])
            case "modelhub":
                // fusion-model-hub /api/v1/system/health 为公开端点（/api/v1/system/info 需鉴权 401）
                detail = try await probeHTTP("http://127.0.0.1:\(cfg.modelHubPort)/api/v1/system/health", headers: [:])
            case "artifacts":
                // artifacts 无 /health 端点(404)，用真实业务接口 /api/v1/artifacts 探活
                detail = try await probeHTTP("\(cfg.artifactsEngineURL)/api/v1/artifacts", headers: [:])
            case "doc":
                detail = try await probeHTTP("http://127.0.0.1:\(cfg.fusionDocPort)/health", headers: [:])
            case "cowork":
                // cowork UDS 用 desk.space.list 真实业务方法探活
                detail = try await probeUDS("/tmp/fusion-cowork.sock", method: "desk.space.list")
            case "projects":
                detail = try await probeUDS("/tmp/fusion-project-svc.sock", method: "project.list")
            case "code":
                // fusion-code 无 /health 端点(404)，用真实业务接口 /api/projects + Bearer 鉴权探活
                detail = try await probeHTTP("http://127.0.0.1:\(cfg.fusionCodePort)/api/projects", headers: ["Authorization": "Bearer fg-admin-key"])
            default:
                detail = "未配置探活"
            }
            return HealthCheckItem(id: id, label: def.label, icon: def.icon, status: .passed, detail: detail)
        } catch {
            envSheetLog.error("probeSubsystem \(id, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            return HealthCheckItem(id: id, label: def.label, icon: def.icon, status: .failed, detail: error.localizedDescription)
        }
    }

    // HTTP 探活：只有 200-299 业务正常响应才算健康。
    // 401/403/404 一律判异常——服务在线但未正确处理请求不算"正常"。
    private func probeHTTP(_ urlStr: String, headers: [String: String]) async throws -> String {
        guard let url = URL(string: urlStr) else {
            throw NSError(domain: "EnvHealth", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效 URL"])
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = 4
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw NSError(domain: "EnvHealth", code: -1, userInfo: [NSLocalizedDescriptionKey: "非 HTTP 响应"])
        }
        if (200..<300).contains(http.statusCode) {
            return "HTTP \(http.statusCode)"
        }
        throw NSError(domain: "EnvHealth", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])
    }

    // UDS JSON-RPC ping 探活
    private func probeUDS(_ sockPath: String, method: String) async throws -> String {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let s = socket(AF_UNIX, SOCK_STREAM, 0)
                guard s >= 0 else {
                    cont.resume(throwing: NSError(domain: "EnvHealth", code: -1, userInfo: [NSLocalizedDescriptionKey: "socket 创建失败"]))
                    return
                }
                defer { close(s) }
                var tv = timeval(tv_sec: 4, tv_usec: 0)
                _ = setsockopt(s, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
                var addr = sockaddr_un()
                addr.sun_family = sa_family_t(AF_UNIX)
                let pathC = sockPath.utf8CString
                let pathLen = min(pathC.count, MemoryLayout.size(ofValue: addr.sun_path))
                _ = pathC.withUnsafeBufferPointer { src in
                    withUnsafeMutableBytes(of: &addr.sun_path) { dst in
                        dst.copyMemory(from: UnsafeRawBufferPointer(start: src.baseAddress!, count: pathLen))
                    }
                }
                let conn = Darwin.connect(s, withUnsafePointer(to: &addr) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { $0 }
                }, socklen_t(MemoryLayout<sockaddr_un>.size))
                guard conn >= 0 else {
                    cont.resume(throwing: NSError(domain: "EnvHealth", code: -1, userInfo: [NSLocalizedDescriptionKey: "UDS 连接失败: \(sockPath)"]))
                    return
                }
                let req: [String: Any] = ["jsonrpc": "2.0", "id": 1, "method": method]
                guard let data = try? JSONSerialization.data(withJSONObject: req) else {
                    cont.resume(throwing: NSError(domain: "EnvHealth", code: -1, userInfo: [NSLocalizedDescriptionKey: "请求序列化失败"]))
                    return
                }
                var buf = data
                buf.append(0x0A)
                buf.withUnsafeBytes { _ = Darwin.write(s, $0.baseAddress, buf.count) }
                // 循环读取直到出现换行符或连接关闭，避免大响应(>4096)被截断导致解析失败
                var resp = Data()
                var tmp = [UInt8](repeating: 0, count: 4096)
                while true {
                    let n = tmp.withUnsafeMutableBufferPointer { Darwin.read(s, $0.baseAddress!, $0.count) }
                    if n <= 0 { break }
                    resp.append(contentsOf: tmp[0..<n])
                    if resp.contains(0x0A) { break }
                }
                guard let nl = resp.firstIndex(of: 0x0A),
                      let json = try? JSONSerialization.jsonObject(with: resp.subdata(in: 0..<nl)) as? [String: Any] else {
                    cont.resume(throwing: NSError(domain: "EnvHealth", code: -1, userInfo: [NSLocalizedDescriptionKey: "响应解析失败"]))
                    return
                }
                // 只有返回 result 字段才算业务正常。
                // 任何 error（含 -32601 方法不存在、业务错误）一律判异常。
                if json["error"] != nil {
                    let msg = (json["error"] as? [String: Any])?["message"] as? String ?? "未知错误"
                    cont.resume(throwing: NSError(domain: "EnvHealth", code: -1, userInfo: [NSLocalizedDescriptionKey: "RPC error: \(msg)"]))
                    return
                }
                guard json["result"] != nil else {
                    cont.resume(throwing: NSError(domain: "EnvHealth", code: -1, userInfo: [NSLocalizedDescriptionKey: "无 result 字段"]))
                    return
                }
                cont.resume(returning: "UDS OK")
            }
        }
    }
}
