// Callers: ModuleDetailView routing.
// Affected API: AdvancedSettingsView (replacing NSColor with StudioTheme tokens).
// Data schemas: None changed.
// User instruction: "帮我用 UI/UX Pro Max 重新设计 fusion-studio 的整体 GUI - macOS 原生风格 - 三栏 - 暗色模式优先 - 主色 #007AFF"

import SwiftUI

// MARK: - 渲染质量预设

enum RenderQuality: String, CaseIterable {
    case draft    = "draft"
    case low      = "low"
    case medium   = "medium"
    case high     = "high"
    case ultra    = "ultra"

    var localizedName: String {
        switch self {
        case .draft:  return I18nManager.shared.t(.as_quality_draft)
        case .low:    return I18nManager.shared.t(.as_quality_low)
        case .medium: return I18nManager.shared.t(.as_quality_medium)
        case .high:   return I18nManager.shared.t(.as_quality_high)
        case .ultra:  return I18nManager.shared.t(.as_quality_ultra)
        }
    }

    var localizedDescription: String {
        switch self {
        case .draft:  return I18nManager.shared.t(.as_quality_desc_draft)
        case .low:    return I18nManager.shared.t(.as_quality_desc_low)
        case .medium: return I18nManager.shared.t(.as_quality_desc_medium)
        case .high:   return I18nManager.shared.t(.as_quality_desc_high)
        case .ultra:  return I18nManager.shared.t(.as_quality_desc_ultra)
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
            Section(I18nManager.shared.t(.as_sec_quality)) {
                Picker(I18nManager.shared.t(.as_preset), selection: $selectedPreset) {
                    ForEach(RenderQuality.allCases, id: \.self) { preset in
                        Text(preset.localizedName).tag(preset)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedPreset) { _, newValue in
                    applyPreset(newValue)
                }

                Text(selectedPreset.localizedDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    Text(I18nManager.shared.t(.as_est_perf))
                    Spacer()
                    Text(selectedPreset.sampleFPS)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.accentColor)
                }
            }

            Section(I18nManager.shared.t(.as_sec_resolution)) {
                HStack {
                    Picker(I18nManager.shared.t(.as_resolution), selection: Binding(
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
                        Text(I18nManager.shared.t(.as_native)).tag("native")
                    }
                    Spacer()
                    Slider(value: $params.scaleFactor, in: 0.25...2.0, step: 0.25)
                        .frame(width: 100)
                    Text("\(params.scaleFactor, specifier: "%.2f")x")
                        .font(.caption)
                        .frame(width: 40)
                }
            }

            Section(I18nManager.shared.t(.as_sec_aa)) {
                Picker(I18nManager.shared.t(.as_aa), selection: $params.antiAliasing) {
                    Text(I18nManager.shared.t(.as_off)).tag(0)
                    Text("2x MSAA").tag(2)
                    Text("4x MSAA").tag(4)
                    Text("8x MSAA").tag(8)
                }
            }

            Section(I18nManager.shared.t(.as_sec_shadow)) {
                Toggle(I18nManager.shared.t(.as_enable_shadow), isOn: $params.enableShadows)
                if params.enableShadows {
                    Picker(I18nManager.shared.t(.as_shadow_map), selection: $params.shadowMapSize) {
                        Text("256").tag(256)
                        Text("512").tag(512)
                        Text("1024").tag(1024)
                        Text("2048").tag(2048)
                        Text("4096").tag(4096)
                    }
                }
            }

            Section(I18nManager.shared.t(.as_sec_postfx)) {
                Toggle("HDR", isOn: $params.enableHDR)
                Toggle(I18nManager.shared.t(.as_bloom), isOn: $params.enableBloom)
                Toggle(I18nManager.shared.t(.as_ssao), isOn: $params.enableSSAO)
                Toggle(I18nManager.shared.t(.as_reflections), isOn: $params.enableReflections)
                Toggle(I18nManager.shared.t(.as_fog), isOn: $params.enableFog)
            }

            Section(I18nManager.shared.t(.as_sec_perf)) {
                HStack {
                    Text(I18nManager.shared.t(.as_texture_quality))
                    Slider(value: $textureQuality, in: 10...100, step: 10)
                    Text("\(Int(textureQuality))%")
                        .frame(width: 40)
                }
                HStack {
                    Text(I18nManager.shared.t(.as_lod_bias))
                    Slider(value: $params.lodBias, in: -2...2, step: 0.5)
                    Text("\(params.lodBias, specifier: "%.1f")")
                        .frame(width: 40)
                }
                Stepper(I18nManager.shared.tf(.as_max_lights, params.maxLights), value: $params.maxLights, in: 1...16)
                Toggle(I18nManager.shared.t(.as_vsync), isOn: $params.vsync)
                if params.vsync {
                    Picker(I18nManager.shared.t(.as_max_fps), selection: $params.maxFPS) {
                        Text("30").tag(30)
                        Text("60").tag(60)
                        Text("120").tag(120)
                        Text("144").tag(144)
                        Text(I18nManager.shared.t(.as_unlimited)).tag(0)
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
            Section(I18nManager.shared.t(.as_sec_physics)) {
                HStack {
                    Text(I18nManager.shared.t(.as_gravity))
                    Slider(value: $params.gravity, in: -20...20, step: 0.1)
                    Text("\(params.gravity, specifier: "%.1f")")
                        .frame(width: 40)
                }

                Picker(I18nManager.shared.t(.as_time_step), selection: $params.timeStep) {
                    Text("1/60 (60 FPS)").tag(1.0/60.0)
                    Text("1/120 (120 FPS)").tag(1.0/120.0)
                    Text("1/240 (240 FPS)").tag(1.0/240.0)
                    Text("1/480 (480 FPS)").tag(1.0/480.0)
                    Text("1/960 (960 FPS)").tag(1.0/960.0)
                }

                Stepper(I18nManager.shared.tf(.as_solver_iter, params.numSolverIterations), value: $params.numSolverIterations, in: 1...50)
                Stepper(I18nManager.shared.tf(.as_max_substeps, params.maxSubSteps), value: $params.maxSubSteps, in: 1...10)
            }

            Section(I18nManager.shared.t(.as_sec_collision)) {
                Toggle(I18nManager.shared.t(.as_ccd), isOn: $params.enableCCD)
                Toggle(I18nManager.shared.t(.as_sleeping), isOn: $params.enableSleeping)

                HStack {
                    Text(I18nManager.shared.t(.as_contact_break))
                    Slider(value: $params.contactBreakingThreshold, in: 0.001...0.1)
                    Text("\(params.contactBreakingThreshold, specifier: "%.3f")")
                        .frame(width: 50)
                }

                HStack {
                    Text(I18nManager.shared.t(.as_collision_margin))
                    Slider(value: $params.collisionMargin, in: 0.001...0.1)
                    Text("\(params.collisionMargin, specifier: "%.3f")")
                        .frame(width: 50)
                }
            }

            Section(I18nManager.shared.t(.as_sec_material)) {
                HStack {
                    Text(I18nManager.shared.t(.as_restitution))
                    Slider(value: $params.restitution, in: 0...1)
                    Text("\(params.restitution, specifier: "%.2f")")
                        .frame(width: 40)
                }
                HStack {
                    Text(I18nManager.shared.t(.as_friction))
                    Slider(value: $params.friction, in: 0...1)
                    Text("\(params.friction, specifier: "%.2f")")
                        .frame(width: 40)
                }
                HStack {
                    Text(I18nManager.shared.t(.as_linear_damping))
                    Slider(value: $params.linearDamping, in: 0...1)
                    Text("\(params.linearDamping, specifier: "%.2f")")
                        .frame(width: 40)
                }
                HStack {
                    Text(I18nManager.shared.t(.as_angular_damping))
                    Slider(value: $params.angularDamping, in: 0...1)
                    Text("\(params.angularDamping, specifier: "%.2f")")
                        .frame(width: 40)
                }
            }

            Section(I18nManager.shared.t(.as_sec_constraint)) {
                Toggle(I18nManager.shared.t(.as_enable_constraint), isOn: $params.enableConstraintSolver)
            }

            Section(I18nManager.shared.t(.as_sec_stats)) {
                HStack {
                    Text(I18nManager.shared.t(.as_score))
                    Spacer()
                    Text(performanceScore)
                        .font(.headline)
                        .foregroundColor(scoreColor)
                }
                Text(I18nManager.shared.t(.as_score_desc))
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
                Label(I18nManager.shared.t(.as_bench_title), systemImage: "speedometer")
                    .font(.headline)
                Spacer()
                Button(action: runBenchmark) {
                    Label(isRunning ? I18nManager.shared.t(.as_bench_running) : I18nManager.shared.t(.as_bench_run), systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRunning)
            }

            if isRunning {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: progress)
                    Text(I18nManager.shared.tf(.as_bench_progress, Int(progress * 100)))
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
                    Text(I18nManager.shared.t(.as_bench_empty))
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
        // 假基准结果已清理：等待接通真实硬件基准后端后填充
        isRunning = false
        progress = 0
        results = []
    }
}

// MARK: - 高级渲染/仿真设置总面板

struct AdvancedSettingsView: View {
    @State private var selectedTab: AdvTab = .render
    @State private var showBenchmark = false

    enum AdvTab: String, CaseIterable {
        case render     = "render"
        case simulation = "simulation"
        case benchmark  = "benchmark"

        var localizedName: String {
            switch self {
            case .render:     return I18nManager.shared.t(.as_tab_render)
            case .simulation: return I18nManager.shared.t(.as_tab_simulation)
            case .benchmark:  return I18nManager.shared.t(.as_tab_benchmark)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(I18nManager.shared.t(.as_title))
                    .font(.title2)
                    .bold()
                Spacer()
                Button(action: { showBenchmark.toggle() }) {
                    Label(I18nManager.shared.t(.as_tab_benchmark), systemImage: "speedometer")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)

            Picker("", selection: $selectedTab) {
                ForEach(AdvTab.allCases, id: \.self) { tab in
                    Label(tab.localizedName, systemImage: tabIcon(tab)).tag(tab)
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