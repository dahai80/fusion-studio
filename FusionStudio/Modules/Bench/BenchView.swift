// Callers: ModuleDetailView routing.
// Affected API: BenchView (replacing NSColor with StudioTheme tokens).
// Data schemas: None changed.
// User instruction: "帮我用 UI/UX Pro Max 重新设计 fusion-studio 的整体 GUI - macOS 原生风格 - 三栏 - 暗色模式优先 - 主色 #007AFF"

import SwiftUI

/// 基准测试结果
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

let sampleResults: [BenchResult] = [
    BenchResult(id: "b1", modelName: "Qwen3.5 9B 4bit", testType: .speed, score: 45.2, unit: "token/s", timestamp: Date(), details: ["延迟": "22ms", "内存": "5.2 GB", "批处理": "1"]),
    BenchResult(id: "b2", modelName: "Llama 3 8B 4bit", testType: .speed, score: 52.1, unit: "token/s", timestamp: Date(), details: ["延迟": "19ms", "内存": "4.8 GB", "批处理": "1"]),
    BenchResult(id: "b3", modelName: "Qwen3.5 9B 4bit", testType: .memory, score: 5.2, unit: "GB", timestamp: Date(), details: ["峰值": "5.8 GB", "基线": "1.2 GB", "增量": "4.6 GB"]),
    BenchResult(id: "b4", modelName: "Qwen3.5 9B 4bit", testType: .context, score: 8192, unit: "tokens", timestamp: Date(), details: ["最大长度": "8192", "通过率": "100%", "困惑度": "3.2"]),
]

struct BenchView: View {
    @Environment(\.studioTheme) private var theme
    @State private var results: [BenchResult] = sampleResults
    @State private var selectedType: BenchResult.BenchType?
    @State private var isRunning = false

    var filteredResults: [BenchResult] {
        if let type = selectedType {
            return results.filter { $0.testType == type }
        }
        return results
    }

    var body: some View {
        VStack(spacing: 0) {
            // 类型选择
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

            // 运行按钮
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

            // 结果列表
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
        // 调用 fusion-mlx 基准测试 API
        Task {
            do {
                let url = URL(string: "http://localhost:8000/v1/benchmarks/run")!
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
                // 静默失败，保留原有数据
            }
            await MainActor.run { self.isRunning = false }
        }
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