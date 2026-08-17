// Callers: ModuleDetailView routing.
// Affected API: BenchView (replacing NSColor with StudioTheme tokens).
// Data schemas: None changed.
// User instruction: "落地2，1先等一等" — embed fusion-bench WebView into fusion-studio

import SwiftUI
import os.log

private let benchLog = Logger(subsystem: "com.fusion.studio", category: "BenchView")

struct BenchResult: Identifiable {
    let id: String
    let modelName: String
    let testType: BenchType
    let score: Double
    let unit: String
    let timestamp: Date
    let details: [String: String]

    enum BenchType: String, CaseIterable {
        case speed     = "速度测试"
        case memory    = "内存测试"
        case context   = "上下文测试"
        case quality   = "质量评估"

        var icon: String {
            switch self {
            case .speed:   return "speedometer"
            case .memory:  return "memorychip"
            case .context: return "doc.text.magnifyingglass"
            case .quality: return "star"
            }
        }

        var color: Color {
            switch self {
            case .speed:   return .orange
            case .memory:  return .blue
            case .context: return .purple
            case .quality: return .green
            }
        }
    }
}

struct BenchView: View {
    @Environment(\.studioTheme) private var theme
    // 假基准结果已清理：初始为空，运行真实 POST /v1/benchmarks/run 后填充
    @State private var results: [BenchResult] = []
    @State private var selectedType: BenchResult.BenchType?
    @State private var isRunning = false
    @State private var selectedTab: BenchTab = .results

    enum BenchTab: String, CaseIterable {
        case results  = "测试结果"
        case webPanel = "完整面板"
    }

    var filteredResults: [BenchResult] {
        if let type = selectedType {
            return results.filter { $0.testType == type }
        }
        return results
    }

    var body: some View {
        VStack(spacing: 0) {
            tabPicker

            switch selectedTab {
            case .results:
                benchResultsContent
            case .webPanel:
                BenchWebPanelView()
            }
        }
    }

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(BenchTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(theme.springDefault) { selectedTab = tab }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab == .results ? "chart.bar" : "globe")
                            .font(.system(size: 12))
                        Text(tab.rawValue)
                            .font(.system(size: theme.smallTextSize, weight: tab == selectedTab ? .semibold : .regular))
                    }
                    .foregroundStyle(tab == selectedTab ? theme.accent : theme.textSecondary)
                    .padding(.horizontal, theme.spacingL)
                    .padding(.vertical, theme.spacingS)
                    .background(
                        tab == selectedTab ? theme.accentSoft : Color.clear,
                        in: RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.bottom, theme.spacingM)
    }

    private var benchResultsContent: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(BenchResult.BenchType.allCases, id: \.self) { type in
                        Button(action: {
                            withAnimation { selectedType = selectedType == type ? nil : type }
                        }) {
                            Label(type.rawValue, systemImage: type.icon)
                                .foregroundColor(selectedType == type ? .white : type.color)
                        }
                        .buttonStyle(.bordered)
                        .tint(selectedType == type ? type.color : nil)
                        .controlSize(.small)
                    }
                }
                .padding(8)
            }
            .background(theme.surfaceSecondary)

            Divider()

            HStack {
                Spacer()
                Button(action: runBenchmark) {
                    Label(isRunning ? "运行中..." : "运行基准测试",
                          systemImage: isRunning ? "arrow.triangle.2.circlepath" : "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRunning)
                .padding(8)
            }

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300))], spacing: 12) {
                    ForEach(filteredResults) { result in
                        BenchResultCard(result: result)
                    }
                }
                .padding()
            }
        }
    }

    private func runBenchmark() {
        isRunning = true
        Task {
            do {
                let url = URL(string: "\(FusionConfig.shared.mlxBaseURL)/v1/benchmarks/run")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let body: [String: Any] = ["type": selectedType?.rawValue ?? "all"]
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                request.timeoutInterval = 300
                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResp = response as? HTTPURLResponse,
                   httpResp.statusCode == 200,
                   let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let result = json["result"] as? [String: Any] {
                    let newResult = BenchResult(
                        id: "b-\(UUID().uuidString.prefix(6))",
                        modelName: result["model"] as? String ?? "unknown",
                        testType: selectedType ?? .speed,
                        score: result["score"] as? Double ?? 0,
                        unit: result["unit"] as? String ?? "",
                        timestamp: Date(),
                        details: result["details"] as? [String: String] ?? [:]
                    )
                    await MainActor.run { self.results.append(newResult) }
                }
            } catch {
                benchLog.error("Benchmark run failed: \(error.localizedDescription)")
            }
            await MainActor.run { self.isRunning = false }
        }
    }
}

// MARK: - Bench WebView 面板

struct BenchWebPanelView: View {
    @Environment(\.studioTheme) var theme
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var serviceStatus: BenchServiceReachability = .unknown

    private let benchSiteURL = "http://localhost:3000"

    enum BenchServiceReachability {
        case online, offline, unknown
    }

    var body: some View {
        VStack(spacing: 0) {
            serviceStatusBar

            ZStack {
                WebViewContainer(url: benchSiteURL, isLoading: $isLoading, error: $loadError)

                if isLoading && loadError == nil {
                    VStack(spacing: 12) {
                        ProgressView().controlSize(.large)
                        Text("正在连接 Fusion-Bench bench-site...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                if let error = loadError {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 36))
                            .foregroundColor(.orange)
                        Text("无法加载基准测试面板")
                            .font(.title2)
                            .bold()
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("启动方式:").font(.subheadline).fontWeight(.semibold)
                            Text("1. 启动后端: cd fusion-bench && ./start.sh start").font(.caption).foregroundColor(.secondary)
                            Text("2. 启动前端: cd fusion-bench/bench-site && npm run dev").font(.caption).foregroundColor(.secondary)
                            Text("前端默认端口: 3000 (Next.js dev server)").font(.caption).foregroundColor(.secondary)
                        }
                        .padding()
                        .background(theme.surfaceElevated)
                        .cornerRadius(8)
                        FusionButton("重试", style: .secondary, size: .small, isLoading: false, isDisabled: false) {
                            loadError = nil
                            isLoading = true
                        }
                    }
                    .padding()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { checkService() }
    }

    private var serviceStatusBar: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            FusionButton("检查状态", style: .secondary, size: .small, isLoading: false, isDisabled: false) {
                checkService()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(theme.surfaceSecondary)
    }

    private var statusColor: Color {
        switch serviceStatus {
        case .online: return theme.greenDot
        case .offline: return theme.redDot
        case .unknown: return theme.amberDot
        }
    }

    private var statusText: String {
        switch serviceStatus {
        case .online: return "Fusion-Bench API 在线"
        case .offline: return "Fusion-Bench API 离线"
        case .unknown: return "检查中..."
        }
    }

    private func checkService() {
        serviceStatus = .unknown
        let url = URL(string: "\(FusionConfig.shared.mlxBaseURL)/api/v1/system/info")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 3
        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 {
                    self.serviceStatus = .online
                } else {
                    self.serviceStatus = .offline
                }
            }
        }.resume()
    }
}

struct BenchResultCard: View {
    @Environment(\.studioTheme) private var theme
    let result: BenchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: result.testType.icon)
                    .foregroundColor(result.testType.color)
                Text(result.testType.rawValue)
                    .font(.headline)
                Spacer()
                Text(result.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(String(format: "%.1f", result.score))")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text(result.unit)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Text(result.modelName)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()

            ForEach(Array(result.details.keys.sorted()), id: \.self) { key in
                HStack {
                    Text(key)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(result.details[key] ?? "")
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(theme.surfaceSecondary)
        .cornerRadius(10)
    }
}
