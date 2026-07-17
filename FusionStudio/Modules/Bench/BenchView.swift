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
            .background(Color(nsColor: .controlBackgroundColor))

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
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            isRunning = false
            // 添加模拟结果
            let newResult = BenchResult(
                id: "b-\(UUID().uuidString.prefix(6))",
                modelName: "Qwen3.5 9B 4bit",
                testType: .speed,
                score: Double.random(in: 40...55),
                unit: "token/s",
                timestamp: Date(),
                details: ["延迟": "\(Int.random(in: 18...25))ms", "内存": "\(String(format: "%.1f", Double.random(in: 4.5...5.5))) GB"]
            )
            results.append(newResult)
        }
    }
}

struct BenchResultCard: View {
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
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
    }
}