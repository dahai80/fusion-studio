// Callers: EnvironmentHealthCard embeds, AIAgentDashboardView.
// Affected API: IPCClient.modelLoadStatus(), mlxSetModel(), startMLX().
// Data schemas: {connected: Bool, models: [{id, size, quant}], loaded: [String], url: String}.
// User instruction: #46 模型负载监控仪表盘 — MLX connection status, model list with size/quant, loaded status, 10s auto-refresh

import SwiftUI
import os.log

private let monitorLog = Logger(subsystem: "com.fusion.studio", category: "ModelLoadMonitor")

struct ModelLoadMonitorView: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme

    @State private var isConnected = false
    @State private var models: [[String: Any]] = []
    @State private var loadedIds: [String] = []
    @State private var serverUrl = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var refreshTimer: Timer?

    private let refreshInterval: TimeInterval = 10.0

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            headerBar
            if isLoading && models.isEmpty {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else {
                connectionStatus
                modelList
            }
        }
        .padding(theme.spacingL)
        .background(theme.contentBg)
        .cornerRadius(theme.cornerRadius)
        .onAppear { startRefresh() }
        .onDisappear { stopRefresh() }
    }

    private var headerBar: some View {
        HStack {
            Label("模型负载监控", systemImage: "gauge.with.dots.needle.bottom.50percent")
                .font(.system(size: theme.textSize, weight: .semibold))
                .foregroundStyle(theme.text)
            Spacer()
            Text("每 \(Int(refreshInterval))s 刷新")
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.textTertiary)
            Button(action: loadStatus) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)
            .help("手动刷新")
        }
    }

    private var connectionStatus: some View {
        HStack(spacing: theme.spacingS) {
            Circle()
                .fill(isConnected ? theme.greenDot : theme.redDot)
                .frame(width: 10, height: 10)
            Text(isConnected ? "MLX 已连接" : "MLX 未连接")
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.text)
            if !serverUrl.isEmpty {
                Text(serverUrl)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
            }
            Spacer()
            if !isConnected {
                Button("启动 MLX") { startMLX() }
                    .buttonStyle(.plain)
                    .font(.system(size: theme.smallTextSize, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(theme.accent)
                    .cornerRadius(6)
            }
        }
        .padding(theme.spacingS)
        .background(isConnected ? theme.accentSoft.opacity(0.15) : theme.accentDestructive.opacity(0.1))
        .cornerRadius(theme.cornerRadiusSmall)
    }

    private var modelList: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text("可用模型")
                .font(.system(size: theme.smallTextSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)
            if models.isEmpty {
                Text("暂无模型")
                    .font(.system(size: theme.smallTextSize))
                    .foregroundStyle(theme.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ForEach(Array(models.enumerated()), id: \.offset) { idx, model in
                    modelRow(model)
                }
            }
        }
    }

    private func modelRow(_ model: [String: Any]) -> some View {
        let id = model["id"] as? String ?? model["name"] as? String ?? "unknown"
        let size = model["size"] as? String ?? ""
        let quant = model["quant"] as? String ?? model["quantization"] as? String ?? ""
        let isLoaded = loadedIds.contains(id)
        return HStack(spacing: theme.spacingS) {
            Image(systemName: isLoaded ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isLoaded ? theme.greenDot : theme.textTertiary)
                .font(.system(size: theme.iconS))
            Text(id)
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.text)
                .lineLimit(1)
            if !quant.isEmpty {
                Text(quant)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.accentText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.accentSoft.opacity(0.2))
                    .cornerRadius(4)
            }
            if !size.isEmpty {
                Text(size)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
            }
            Spacer()
            if isLoaded {
                Text("已加载")
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(theme.greenDot)
            } else {
                Button("加载") { loadModel(id) }
                    .buttonStyle(.plain)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.accent)
            }
        }
        .padding(.horizontal, theme.spacingS)
        .padding(.vertical, theme.spacingXS)
        .background(theme.surfaceElevated)
        .cornerRadius(theme.cornerRadiusSmall)
    }

    private var loadingView: some View {
        HStack {
            Spacer()
            ProgressView()
                .scaleEffect(0.8)
            Text("加载模型状态...")
                .font(.system(size: theme.smallTextSize))
                .foregroundStyle(theme.textSecondary)
            Spacer()
        }
        .padding(.vertical, 20)
    }

    private func errorView(_ msg: String) -> some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(theme.amberDot)
                Text(msg)
                    .font(.system(size: theme.smallTextSize))
                    .foregroundStyle(theme.textSecondary)
                Button("重试") { loadStatus() }
                    .buttonStyle(.plain)
                    .font(.system(size: theme.smallTextSize))
                    .foregroundStyle(theme.accent)
            }
            Spacer()
        }
        .padding(.vertical, 20)
    }

    private func startRefresh() {
        loadStatus()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { _ in
            loadStatus()
        }
    }

    private func stopRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func loadStatus() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let result = try await ipc.modelLoadStatus()
                await MainActor.run {
                    isConnected = result["connected"] as? Bool ?? false
                    models = result["models"] as? [[String: Any]] ?? []
                    loadedIds = result["loaded"] as? [String] ?? []
                    serverUrl = result["url"] as? String ?? ""
                    isLoading = false
                    monitorLog.info("Model status: connected=\(self.isConnected), models=\(self.models.count), loaded=\(self.loadedIds.count)")
                }
            } catch {
                await MainActor.run {
                    errorMessage = "无法获取模型状态: \(error.localizedDescription)"
                    isLoading = false
                    monitorLog.error("Model status failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func loadModel(_ modelId: String) {
        Task {
            do {
                _ = try await ipc.mlxSetModel(model: modelId)
                monitorLog.info("Requested load model: \(modelId)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { loadStatus() }
            } catch {
                monitorLog.error("Load model failed: \(error.localizedDescription)")
            }
        }
    }

    private func startMLX() {
        Task {
            do {
                _ = try await ipc.startMLX()
                monitorLog.info("MLX start requested")
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) { loadStatus() }
            } catch {
                monitorLog.error("MLX start failed: \(error.localizedDescription)")
            }
        }
    }
}
