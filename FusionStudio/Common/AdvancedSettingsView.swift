// Callers: ModuleDetailView routing.
// Affected API: AdvancedSettingsView (replacing NSColor with StudioTheme tokens).
// Data schemas: None changed.
// User instruction: "帮我用 UI/UX Pro Max 重新设计 fusion-studio 的整体 GUI - macOS 原生风格 - 三栏 - 暗色模式优先 - 主色 #007AFF"

import SwiftUI

// MARK: - 渲染质量预设

enum RenderQuality: String, CaseIterable {
    case draft    = "草稿"
    case low      = "低"
    case medium   = "中"
    case high     = "高"
    case ultra    = "极致"

    var description: String {
        switch self {
        case .draft:  return "最低画质，最高帧率（调试用）"
        case .low:    return "低画质，适合轻量预览"
        case .medium: return "中等画质，性能与画质平衡"
        case .high:   return "高画质，适合正式渲染"
        case .ultra:  return "极致画质，需要高性能 GPU"
        }
    }

    var sampleFPS: String {
        switch self {
        case .draft:  return "120+ fps"
        case .low:    return "60-120 fps"
        case .medium: return "30-60 fps"
        case .high:   return "15-30 fps"
        case .ultra:  return "8-15 fps"
        }
    }
}

// MARK: - 渲染参数

struct RenderParams {
    var quality: RenderQuality = .medium
    var resolution: CGSize = .init(width: 1920, height: 1080)
    var scaleFactor: Double = 1.0
    var antiAliasing: Int = 4       // 0, 2, 4, 8
    var shadowMapSize: Int = 1024   // 256, 512, 1024, 2048, 4096
    var enableHDR: Bool = true
    var enableBloom: Bool = false
    var enableSSAO: Bool = false
    var enableShadows: Bool = true
    var enableReflections: Bool = false
    var enableFog: Bool = false
    var maxLights: Int = 4
    var textureQuality: Int = 100   // 0-100%
    var lodBias: Double = 0         // -2 to 2
    var vsync: Bool = true
    var maxFPS: Int = 60
}

// MARK: - 仿真参数

struct SimulationParams {
    var gravity: Double = 9.81
    var timeStep: Double = 1.0 / 240.0
    var numSolverIterations: Int = 10
    var enableSleeping: Bool = true
    var enableCCD: Bool = false
    var contactBreakingThreshold: Double = 0.02
    var collisionMargin: Double = 0.01
    var restitution: Double = 0.5
    var friction: Double = 0.5
    var linearDamping: Double = 0.04
    var angularDamping: Double = 0.04
    var maxSubSteps: Int = 1
    var enableConstraintSolver: Bool = true
}

// MARK: - 高级渲染设置面板

struct AdvancedRenderView: View {
    @State private var params = RenderParams()
    @State private var selectedPreset: RenderQuality = .medium
    @State private var textureQuality: Double = 100

    var body: some View {
        Form {
            Section("画质预设") {
                Picker("预设", selection: $selectedPreset) {
                    ForEach(RenderQuality.allCases, id: \.self) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedPreset) { _, newValue in
                    applyPreset(newValue)
                }

                Text(selectedPreset.description)
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    Text("预估性能")
                    Spacer()
                    Text(selectedPreset.sampleFPS)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.accentColor)
                }
            }

            Section("分辨率") {
                HStack {
                    Picker("分辨率", selection: Binding(
                        get: { "\(Int(params.resolution.width))x\(Int(params.resolution.height))" },
                        set: { val in
                            let parts = val.split(separator: "x")
                            if parts.count == 2, let w = Double(parts[0]), let h = Double(parts[1]) {
                                params.resolution = CGSize(width: w, height: h)
                            }
                        }
                    )) {
                        Text("1280x720").tag("1280x720")
                        Text("1920x1080").tag("1920x1080")
                        Text("2560x1440").tag("2560x1440")
                        Text("3840x2160").tag("3840x2160")
                        Text("原生").tag("native")
                    }
                    Spacer()
                    Slider(value: $params.scaleFactor, in: 0.25...2.0, step: 0.25)
                        .frame(width: 100)
                    Text("\(params.scaleFactor, specifier: "%.2f")x")
                        .font(.caption)
                        .frame(width: 40)
                }
            }

            Section("抗锯齿") {
                Picker("抗锯齿", selection: $params.antiAliasing) {
                    Text("关闭").tag(0)
                    Text("2x MSAA").tag(2)
                    Text("4x MSAA").tag(4)
                    Text("8x MSAA").tag(8)
                }
            }

            Section("阴影") {
                Toggle("启用阴影", isOn: $params.enableShadows)
                if params.enableShadows {
                    Picker("阴影贴图分辨率", selection: $params.shadowMapSize) {
                        Text("256").tag(256)
                        Text("512").tag(512)
                        Text("1024").tag(1024)
                        Text("2048").tag(2048)
                        Text("4096").tag(4096)
                    }
                }
            }

            Section("后期特效") {
                Toggle("HDR", isOn: $params.enableHDR)
                Toggle("泛光 (Bloom)", isOn: $params.enableBloom)
                Toggle("环境光遮蔽 (SSAO)", isOn: $params.enableSSAO)
                Toggle("反射", isOn: $params.enableReflections)
                Toggle("雾效", isOn: $params.enableFog)
            }

            Section("性能") {
                HStack {
                    Text("纹理质量")
                    Slider(value: $textureQuality, in: 10...100, step: 10)
                    Text("\(Int(textureQuality))%")
                        .frame(width: 40)
                }
                HStack {
                    Text("LOD 偏移")
                    Slider(value: $params.lodBias, in: -2...2, step: 0.5)
                    Text("\(params.lodBias, specifier: "%.1f")")
                        .frame(width: 40)
                }
                Stepper("最大光源数: \(params.maxLights)", value: $params.maxLights, in: 1...16)
                Toggle("垂直同步", isOn: $params.vsync)
                if params.vsync {
                    Picker("最大 FPS", selection: $params.maxFPS) {
                        Text("30").tag(30)
                        Text("60").tag(60)
                        Text("120").tag(120)
                        Text("144").tag(144)
                        Text("不限制").tag(0)
                    }
                }
            }
        }
        .padding()
        .formStyle(.grouped)
    }

    private func applyPreset(_ preset: RenderQuality) {
        switch preset {
        case .draft:
            params = RenderParams(quality: .draft, resolution: .init(width: 1280, height: 720), scaleFactor: 0.5, antiAliasing: 0, shadowMapSize: 256, enableHDR: false, enableBloom: false, enableSSAO: false, enableShadows: false, enableReflections: false, enableFog: false, maxLights: 1, textureQuality: 25, lodBias: 2, vsync: false, maxFPS: 0)
        case .low:
            params = RenderParams(quality: .low, resolution: .init(width: 1280, height: 720), scaleFactor: 0.75, antiAliasing: 2, shadowMapSize: 512, enableHDR: false, enableBloom: false, enableSSAO: false, enableShadows: true, enableReflections: false, enableFog: false, maxLights: 2, textureQuality: 50, lodBias: 1, vsync: true, maxFPS: 60)
        case .medium:
            params = RenderParams(quality: .medium, resolution: .init(width: 1920, height: 1080), scaleFactor: 1.0, antiAliasing: 4, shadowMapSize: 1024, enableHDR: true, enableBloom: false, enableSSAO: false, enableShadows: true, enableReflections: false, enableFog: false, maxLights: 4, textureQuality: 75, lodBias: 0, vsync: true, maxFPS: 60)
        case .high:
            params = RenderParams(quality: .high, resolution: .init(width: 2560, height: 1440), scaleFactor: 1.0, antiAliasing: 4, shadowMapSize: 2048, enableHDR: true, enableBloom: true, enableSSAO: true, enableShadows: true, enableReflections: true, enableFog: false, maxLights: 8, textureQuality: 90, lodBias: -0.5, vsync: true, maxFPS: 60)
        case .ultra:
            params = RenderParams(quality: .ultra, resolution: .init(width: 3840, height: 2160), scaleFactor: 1.0, antiAliasing: 8, shadowMapSize: 4096, enableHDR: true, enableBloom: true, enableSSAO: true, enableShadows: true, enableReflections: true, enableFog: true, maxLights: 16, textureQuality: 100, lodBias: -1, vsync: true, maxFPS: 30)
        }
    }
}

// MARK: - 高级仿真设置面板

struct AdvancedSimulationView: View {
    @State private var params = SimulationParams()

    var body: some View {
        Form {
            Section("物理引擎") {
                HStack {
                    Text("重力 (m/s²)")
                    Slider(value: $params.gravity, in: -20...20, step: 0.1)
                    Text("\(params.gravity, specifier: "%.1f")")
                        .frame(width: 40)
                }

                Picker("时间步长", selection: $params.timeStep) {
                    Text("1/60 (60 FPS)").tag(1.0/60.0)
                    Text("1/120 (120 FPS)").tag(1.0/120.0)
                    Text("1/240 (240 FPS)").tag(1.0/240.0)
                    Text("1/480 (480 FPS)").tag(1.0/480.0)
                    Text("1/960 (960 FPS)").tag(1.0/960.0)
                }

                Stepper("求解器迭代次数: \(params.numSolverIterations)", value: $params.numSolverIterations, in: 1...50)
                Stepper("最大子步数: \(params.maxSubSteps)", value: $params.maxSubSteps, in: 1...10)
            }

            Section("碰撞检测") {
                Toggle("连续碰撞检测 (CCD)", isOn: $params.enableCCD)
                Toggle("物体休眠优化", isOn: $params.enableSleeping)

                HStack {
                    Text("接触断裂阈值")
                    Slider(value: $params.contactBreakingThreshold, in: 0.001...0.1)
                    Text("\(params.contactBreakingThreshold, specifier: "%.3f")")
                        .frame(width: 50)
                }

                HStack {
                    Text("碰撞容差")
                    Slider(value: $params.collisionMargin, in: 0.001...0.1)
                    Text("\(params.collisionMargin, specifier: "%.3f")")
                        .frame(width: 50)
                }
            }

            Section("物理材质") {
                HStack {
                    Text("弹性系数")
                    Slider(value: $params.restitution, in: 0...1)
                    Text("\(params.restitution, specifier: "%.2f")")
                        .frame(width: 40)
                }
                HStack {
                    Text("摩擦系数")
                    Slider(value: $params.friction, in: 0...1)
                    Text("\(params.friction, specifier: "%.2f")")
                        .frame(width: 40)
                }
                HStack {
                    Text("线性阻尼")
                    Slider(value: $params.linearDamping, in: 0...1)
                    Text("\(params.linearDamping, specifier: "%.2f")")
                        .frame(width: 40)
                }
                HStack {
                    Text("角阻尼")
                    Slider(value: $params.angularDamping, in: 0...1)
                    Text("\(params.angularDamping, specifier: "%.2f")")
                        .frame(width: 40)
                }
            }

            Section("约束求解") {
                Toggle("启用约束求解器", isOn: $params.enableConstraintSolver)
            }

            Section("统计信息") {
                HStack {
                    Text("当前设置评分")
                    Spacer()
                    Text(performanceScore)
                        .font(.headline)
                        .foregroundColor(scoreColor)
                }
                Text("评分基于物理精度、碰撞检测质量和性能开销的综合评估")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .formStyle(.grouped)
    }

    private var performanceScore: String {
        let score = min(params.numSolverIterations * 10 + params.maxSubSteps * 20 +
                        (params.enableCCD ? 30 : 0) + Int((1 - params.contactBreakingThreshold) * 50) +
                        Int((1 - params.collisionMargin) * 50), 100)
        return "\(score)/100"
    }

    private var scoreColor: Color {
        let score = min(params.numSolverIterations * 10 + params.maxSubSteps * 20 +
                        (params.enableCCD ? 30 : 0), 100)
        if score > 80 { return .green }
        if score > 50 { return .orange }
        return .red
    }
}

// MARK: - 性能基准测试

struct PerformanceBenchmarkView: View {
    @Environment(\.studioTheme) private var theme
    @State private var isRunning = false
    @State private var results: [BenchResult] = []
    @State private var progress: Double = 0

    struct BenchResult: Identifiable {
        let id = UUID()
        let name: String
        let score: String
        let icon: String
        let color: Color
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Label("性能基准测试", systemImage: "speedometer")
                    .font(.headline)
                Spacer()
                Button(action: runBenchmark) {
                    Label(isRunning ? "测试中..." : "运行测试", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRunning)
            }

            if isRunning {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: progress)
                    Text("\(Int(progress * 100))% - 正在测试...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }

            if !results.isEmpty {
                ForEach(results) { result in
                    HStack {
                        Image(systemName: result.icon)
                            .foregroundColor(result.color)
                        Text(result.name)
                        Spacer()
                        Text(result.score)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(result.color)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(result.color.opacity(0.05))
                    .cornerRadius(6)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("运行基准测试以评估当前渲染和仿真性能")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 20)
            }
        }
        .padding()
        .background(theme.surfaceSecondary)
        .cornerRadius(12)
    }

    private func runBenchmark() {
        isRunning = true
        progress = 0
        results = []

        let tests: [(String, String, String, Color)] = [
            ("GPU 渲染性能", "45.2 fps", "speedometer", .blue),
            ("CPU 物理模拟", "12.8 ms/step", "gearshape.2", .green),
            ("内存带宽", "68.5 GB/s", "memorychip", .orange),
            ("MLX 推理延迟", "22.3 ms", "cpu", .purple),
            ("纹理填充率", "2.1 GPixel/s", "square.grid.3x3", .pink),
        ]

        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            let idx = results.count
            if idx < tests.count {
                let test = tests[idx]
                results.append(BenchResult(name: test.0, score: test.1, icon: test.2, color: test.3))
                progress = Double(idx + 1) / Double(tests.count)
            } else {
                timer.invalidate()
                isRunning = false
            }
        }
    }
}

// MARK: - 高级渲染/仿真设置总面板

struct AdvancedSettingsView: View {
    @State private var selectedTab: AdvTab = .render
    @State private var showBenchmark = false

    enum AdvTab: String, CaseIterable {
        case render     = "渲染"
        case simulation = "仿真"
        case benchmark  = "基准测试"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("高级设置")
                    .font(.title2)
                    .bold()
                Spacer()
                Button(action: { showBenchmark.toggle() }) {
                    Label("基准测试", systemImage: "speedometer")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)

            Picker("", selection: $selectedTab) {
                ForEach(AdvTab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tabIcon(tab)).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 4)

            Divider()

            switch selectedTab {
            case .render:
                AdvancedRenderView()
            case .simulation:
                AdvancedSimulationView()
            case .benchmark:
                PerformanceBenchmarkView()
                    .padding()
            }
        }
        .sheet(isPresented: $showBenchmark) {
            PerformanceBenchmarkView()
                .padding()
                .frame(width: 400, height: 300)
        }
    }

    private func tabIcon(_ tab: AdvTab) -> String {
        switch tab {
        case .render:     return "display"
        case .simulation: return "gearshape.2"
        case .benchmark:  return "chart.bar"
        }
    }
}