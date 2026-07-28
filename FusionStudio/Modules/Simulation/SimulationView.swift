// Callers: ModuleDetailView routing.
// Affected API: SimulationView (replacing NSColor with StudioTheme tokens).
// Data schemas: None changed.
// User instruction: "帮我用 UI/UX Pro Max 重新设计 fusion-studio 的整体 GUI - macOS 原生风格 - 三栏 - 暗色模式优先 - 主色 #007AFF"

import SwiftUI
import Metal
import MetalKit
import os.log

/// 仿真场景模型
struct SimulationScene: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var description: String
    var lastModified: Date
    var status: SimulationStatus
    var fps: Double
    var physicsSteps: Int

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: SimulationScene, rhs: SimulationScene) -> Bool {
        lhs.id == rhs.id
    }

    enum SimulationStatus: String, Codable {
        case idle     = "空闲"
        case running  = "运行中"
        case paused   = "已暂停"
        case error    = "错误"
    }
}

/// 仿真参数配置
struct SimulationConfig {
    var gravity: Double = 9.81
    var timeStep: Double = 1.0 / 240.0
    var numSubSteps: Int = 1
    var realTimeFactor: Double = 1.0
    var enableWireframe: Bool = false
    var enableContactPoints: Bool = false
    var enableDebug: Bool = false
}

// MARK: - 主仿真视图

struct SimulationView: View {
    @State private var scenes: [SimulationScene] = []
    @State private var selectedScene: SimulationScene?
    @State private var config = SimulationConfig()
    @State private var isRunning = false
    @State private var showSceneEditor = false
    @State private var selectedTab: SimTab = .viewport

    enum SimTab: String, CaseIterable {
        case viewport    = "视口"
        case scene       = "场景"
        case physics     = "物理"
        case log         = "日志"
    }

    var body: some View {
        HSplitView {
            // 左侧：场景列表
            SceneListView(
                scenes: scenes,
                selectedScene: $selectedScene,
                onNewScene: { showSceneEditor = true },
                onDeleteScene: deleteScene
            )
            .frame(minWidth: 180, maxWidth: 250)

            // 右侧：主区域
            VStack(spacing: 0) {
                // 工具栏
                SimulationToolbar(
                    isRunning: $isRunning,
                    config: $config,
                    selectedScene: selectedScene,
                    onStart: startSimulation,
                    onStop: stopSimulation,
                    onPause: pauseSimulation,
                    onReset: resetSimulation
                )

                // 标签切换
                Picker("", selection: $selectedTab) {
                    ForEach(SimTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 4)

                Divider()

                // 内容区域
                switch selectedTab {
                case .viewport:
                    SimulationViewport(
                        isRunning: isRunning,
                        scene: selectedScene,
                        config: config
                    )
                case .scene:
                    SceneEditorView(
                        scene: $selectedScene,
                        config: $config
                    )
                case .physics:
                    PhysicsConfigView(config: $config)
                case .log:
                    SimulationLogView()
                }
            }
        }
        .frame(minWidth: 800, minHeight: 500)
        .sheet(isPresented: $showSceneEditor) {
            NewSceneDialog { scene in
                scenes.append(scene)
                selectedScene = scene
            }
        }
        .onAppear {
            loadScenes()
        }
    }

    private func loadScenes() {
        // 加载示例场景
        scenes = [
            SimulationScene(
                id: "scene-1",
                name: "机器人手臂",
                description: "六轴机械臂运动仿真",
                lastModified: Date(),
                status: .idle,
                fps: 0,
                physicsSteps: 0
            ),
            SimulationScene(
                id: "scene-2",
                name: "双足行走",
                description: "双足机器人步行仿真",
                lastModified: Date(),
                status: .idle,
                fps: 0,
                physicsSteps: 0
            ),
            SimulationScene(
                id: "scene-3",
                name: "物体抓取",
                description: "机械臂抓取物体测试",
                lastModified: Date(),
                status: .idle,
                fps: 0,
                physicsSteps: 0
            ),
        ]
    }

    private func startSimulation() {
        guard let scene = selectedScene else { return }
        isRunning = true
        if let idx = scenes.firstIndex(where: { $0.id == scene.id }) {
            scenes[idx].status = .running
        }
    }

    private func stopSimulation() {
        isRunning = false
        guard let scene = selectedScene else { return }
        if let idx = scenes.firstIndex(where: { $0.id == scene.id }) {
            scenes[idx].status = .idle
        }
    }

    private func pauseSimulation() {
        guard let scene = selectedScene else { return }
        if let idx = scenes.firstIndex(where: { $0.id == scene.id }) {
            scenes[idx].status = scenes[idx].status == .paused ? .running : .paused
        }
    }

    private func resetSimulation() {
        stopSimulation()
        // 重置物理参数
    }

    private func deleteScene(_ scene: SimulationScene) {
        scenes.removeAll { $0.id == scene.id }
        if selectedScene?.id == scene.id {
            selectedScene = scenes.first
        }
    }
}

// MARK: - 场景列表

struct SceneListView: View {
    let scenes: [SimulationScene]
    @Binding var selectedScene: SimulationScene?
    let onNewScene: () -> Void
    let onDeleteScene: (SimulationScene) -> Void

    var body: some View {
        List(selection: $selectedScene) {
            Section("场景列表") {
                ForEach(scenes) { scene in
                    SceneRow(scene: scene)
                        .tag(scene)
                        .contextMenu {
                            Button("删除", role: .destructive) {
                                onDeleteScene(scene)
                            }
                        }
                }
            }
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItem {
                Button(action: onNewScene) {
                    Label("新建场景", systemImage: "plus")
                }
            }
        }
    }
}

struct SceneRow: View {
    let scene: SimulationScene

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(scene.name)
                    .font(.headline)
            }
            Text(scene.description)
                .font(.caption)
                .foregroundColor(.secondary)
            Text("FPS: \(String(format: "%.1f", scene.fps))")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch scene.status {
        case .idle:    return .gray
        case .running: return .green
        case .paused:  return .orange
        case .error:   return .red
        }
    }
}

// MARK: - 仿真工具栏

struct SimulationToolbar: View {
    @Environment(\.studioTheme) private var theme
    @Binding var isRunning: Bool
    @Binding var config: SimulationConfig
    let selectedScene: SimulationScene?
    let onStart: () -> Void
    let onStop: () -> Void
    let onPause: () -> Void
    let onReset: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if let scene = selectedScene {
                Text(scene.name)
                    .font(.headline)
                Spacer()
                Text("FPS: \(String(format: "%.1f", scene.fps))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Steps: \(scene.physicsSteps)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("请选择或创建一个仿真场景")
                    .foregroundColor(.secondary)
                Spacer()
            }

            Spacer()

            HStack(spacing: 4) {
                Button(action: onStart) {
                    Label("运行", systemImage: "play.fill")
                }
                .disabled(selectedScene == nil || isRunning)
                .buttonStyle(.borderedProminent)

                Button(action: onPause) {
                    Label("暂停", systemImage: "pause.fill")
                }
                .disabled(!isRunning)
                .buttonStyle(.bordered)

                Button(action: onStop) {
                    Label("停止", systemImage: "stop.fill")
                }
                .disabled(!isRunning)
                .buttonStyle(.bordered)

                Button(action: onReset) {
                    Label("重置", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.small)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(theme.surfaceSecondary)
    }
}

// MARK: - 仿真视口

struct SimulationViewport: View {
    let isRunning: Bool
    let scene: SimulationScene?
    let config: SimulationConfig

    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            // Metal 渲染视图占位
            MetalSimulationView()
                .background(Color.black.opacity(0.85))

            // 叠加信息
            VStack {
                HStack {
                    if isRunning {
                        Label("运行中", systemImage: "circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                            .padding(6)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(4)
                    }
                    Spacer()
                }
                .padding(8)
                Spacer()

                // 底部控制提示
                HStack {
                    Text("鼠标拖拽旋转 · 滚轮缩放 · 右键平移")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                }
                .padding(8)
            }
        }
        .cornerRadius(8)
        .padding(8)
    }
}

// MARK: - Metal 仿真渲染视图

private let simLog = Logger(subsystem: "com.fusion.studio", category: "MetalSimulation")

class SimulationRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private var gridVertexBuffer: MTLBuffer?
    private var crossVertexBuffer: MTLBuffer?
    private var vertexCount = 0
    private var crossVertexCount = 0
    private var rotation: Float = 0

    init?(mtkView: MTKView) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            simLog.error("Metal: no default device available")
            return nil
        }
        self.device = device
        guard let queue = device.makeCommandQueue() else {
            simLog.error("Metal: failed to create command queue")
            return nil
        }
        self.commandQueue = queue

        let shaderSource = """
        #include <metal_stdlib>
        using namespace metal;
        struct VertexOut { float4 position [[position]]; };
        struct Uniforms { float rotation; float width; float height; };
        vertex VertexOut gridVertex(constant Uniforms& u [[buffer(0)]],
                                     constant float3* pos [[buffer(1)]],
                                     uint vid [[vertex_id]]) {
            float aspect = u.width / u.height;
            float3 p = pos[vid];
            float c = cos(u.rotation); float s = sin(u.rotation);
            float2 rotated = float2(p.x * c - p.y * s, p.x * s + p.y * c);
            return VertexOut { float4(rotated.x / (aspect * 200.0), rotated.y / 200.0, 0, 1) };
        }
        fragment float4 gridFragment() { return float4(0.3, 0.3, 0.35, 0.4); }
        """
        let library = try? device.makeLibrary(source: shaderSource, options: nil)
        let vertexFunc = library?.makeFunction(name: "gridVertex")
        let fragmentFunc = library?.makeFunction(name: "gridFragment")

        if vertexFunc == nil || fragmentFunc == nil {
            simLog.info("Metal: shader functions not found, using clear-color only renderer")
        }

        let pipelineDesc = MTLRenderPipelineDescriptor()
        pipelineDesc.vertexFunction = vertexFunc
        pipelineDesc.fragmentFunction = fragmentFunc
        pipelineDesc.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat

        guard let pipeline = try? device.makeRenderPipelineState(descriptor: pipelineDesc) else {
            simLog.error("Metal: failed to create pipeline state")
            return nil
        }
        self.pipelineState = pipeline

        super.init()

        buildGridBuffers()
        simLog.info("Metal: renderer initialized with \(self.vertexCount) grid vertices")
    }

    private func buildGridBuffers() {
        let gridSize: Float = 200
        let step: Float = 20
        var vertices: [Float] = []
        var i: Float = -gridSize
        while i <= gridSize {
            vertices.append(contentsOf: [i, -gridSize, 0, i, gridSize, 0])
            vertices.append(contentsOf: [-gridSize, i, 0, gridSize, i, 0])
            i += step
        }
        vertexCount = vertices.count / 3
        gridVertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Float>.size, options: [])

        var crossVerts: [Float] = [-10, 0, 0, 10, 0, 0, 0, -10, 0, 0, 10, 0]
        crossVertexCount = crossVerts.count / 3
        crossVertexBuffer = device.makeBuffer(bytes: crossVerts, length: crossVerts.count * MemoryLayout<Float>.size, options: [])
    }

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let renderPass = view.currentRenderPassDescriptor else { return }

        rotation += 0.002

        guard let cmdBuffer = commandQueue.makeCommandBuffer(),
              let encoder = cmdBuffer.makeRenderCommandEncoder(descriptor: renderPass) else { return }

        encoder.setRenderPipelineState(pipelineState)

        var uniforms: [Float] = [rotation, Float(view.drawableSize.width), Float(view.drawableSize.height)]
        encoder.setVertexBytes(&uniforms, length: uniforms.count * MemoryLayout<Float>.size, index: 0)

        if let gridBuf = gridVertexBuffer {
            encoder.setVertexBuffer(gridBuf, offset: 0, index: 1)
            encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: vertexCount)
        }
        if let crossBuf = crossVertexBuffer {
            encoder.setVertexBuffer(crossBuf, offset: 0, index: 1)
            encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: crossVertexCount)
        }

        encoder.endEncoding()
        cmdBuffer.present(drawable)
        cmdBuffer.commit()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
}

struct MetalSimulationView: NSViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        if let device = MTLCreateSystemDefaultDevice() {
            mtkView.device = device
            mtkView.wantsLayer = true
            mtkView.layer?.backgroundColor = NSColor.black.cgColor
            mtkView.colorPixelFormat = .bgra8Unorm
            mtkView.clearColor = MTLClearColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 1.0)
            mtkView.enableSetNeedsDisplay = false
            mtkView.isPaused = false
            mtkView.preferredFramesPerSecond = 60
            mtkView.delegate = context.coordinator
            simLog.info("Metal: MTKView created with device \(device.name)")
        } else {
            simLog.error("Metal: MTLCreateSystemDefaultDevice returned nil")
            mtkView.wantsLayer = true
            mtkView.layer?.backgroundColor = NSColor.black.cgColor
        }
        return mtkView
    }

    func updateNSView(_ nsView: MTKView, context: Context) {}

    class Coordinator: NSObject, MTKViewDelegate {
        private var renderer: SimulationRenderer?

        override init() {
            super.init()
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            renderer?.mtkView(view, drawableSizeWillChange: size)
        }

        func draw(in view: MTKView) {
            if renderer == nil {
                renderer = SimulationRenderer(mtkView: view)
            }
            renderer?.draw(in: view)
        }
    }
}

// MARK: - 场景编辑器

struct SceneEditorView: View {
    @Binding var scene: SimulationScene?
    @Binding var config: SimulationConfig

    var body: some View {
        Form {
            if let scene = scene {
                Section("基本信息") {
                    LabeledContent("名称") {
                        TextField("场景名称", text: Binding(
                            get: { scene.name },
                            set: { newValue in /* update */ }
                        ))
                    }
                    LabeledContent("描述") {
                        TextField("描述", text: Binding(
                            get: { scene.description },
                            set: { newValue, _ in /* update */ }
                        ))
                    }
                }
            }

            Section("环境参数") {
                LabeledContent("重力 (m/s²)") {
                    Slider(value: $config.gravity, in: 0...20)
                    Text("\(String(format: "%.1f", config.gravity))")
                        .frame(width: 40)
                }
                LabeledContent("时间步长") {
                    Picker("", selection: $config.timeStep) {
                        Text("1/60").tag(1.0/60.0)
                        Text("1/120").tag(1.0/120.0)
                        Text("1/240").tag(1.0/240.0)
                        Text("1/480").tag(1.0/480.0)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 80)
                }
                LabeledContent("实时倍率") {
                    Slider(value: $config.realTimeFactor, in: 0.1...5.0)
                    Text("\(String(format: "%.1f", config.realTimeFactor))x")
                        .frame(width: 40)
                }
            }

            Section("调试选项") {
                Toggle("线框模式", isOn: $config.enableWireframe)
                Toggle("显示接触点", isOn: $config.enableContactPoints)
                Toggle("调试信息", isOn: $config.enableDebug)
            }
        }
        .padding()
        .formStyle(.grouped)
    }

    private func findSceneIndex() -> Int? {
        return nil // 实际实现需传递 scenes binding
    }
}

// MARK: - 物理参数配置

struct PhysicsConfigView: View {
    @Binding var config: SimulationConfig

    var body: some View {
        Form {
            Section("物理引擎") {
                LabeledContent("求解器") {
                    Picker("", selection: .constant("默认")) {
                        Text("默认 (LCP)").tag("lcp")
                        Text("MGS").tag("mgs")
                        Text("Dantzig").tag("dantzig")
                    }
                }
                LabeledContent("子步数") {
                    Stepper("\(config.numSubSteps)", value: $config.numSubSteps, in: 1...10)
                }
                LabeledContent("碰撞检测") {
                    Picker("", selection: .constant("精确")) {
                        Text("精确").tag("precise")
                        Text("快速").tag("fast")
                        Text("禁用").tag("none")
                    }
                }
            }

            Section("约束求解") {
                LabeledContent("ERP") {
                    Slider(value: .constant(0.2), in: 0...1)
                }
                LabeledContent("CFM") {
                    Slider(value: .constant(0.00001), in: 0.000001...0.1)
                }
                LabeledContent("最大接触点") {
                    Stepper("\(3)", value: .constant(3), in: 1...10)
                }
            }
        }
        .padding()
        .formStyle(.grouped)
    }
}

// MARK: - 仿真日志

struct SimulationLogView: View {
    @State private var logs: [SimLogEntry] = [
        SimLogEntry(time: "00:00:00", level: .info, message: "PyBullet 引擎初始化"),
        SimLogEntry(time: "00:00:01", level: .info, message: "物理世界创建完成"),
        SimLogEntry(time: "00:00:02", level: .warning, message: "检测到不稳定约束"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(logs) { entry in
                    HStack(spacing: 8) {
                        Text(entry.time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .trailing)
                        Text(entry.level.rawValue)
                            .font(.caption)
                            .foregroundColor(entry.level.color)
                            .frame(width: 40)
                        Text(entry.message)
                            .font(.system(size: 11, design: .monospaced))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                }
            }
            .padding(8)
        }
        .background(Color.black.opacity(0.05))
    }
}

struct SimLogEntry: Identifiable {
    let id = UUID()
    let time: String
    let level: LogLevel
    let message: String

    enum LogLevel: String {
        case info    = "INFO"
        case warning = "WARN"
        case error   = "ERROR"
        case debug   = "DEBUG"

        var color: Color {
            switch self {
            case .info:    return .blue
            case .warning: return .orange
            case .error:   return .red
            case .debug:   return .gray
            }
        }
    }
}

// MARK: - 新建场景对话框

struct NewSceneDialog: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var description = ""
    let onSave: (SimulationScene) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("新建仿真场景")
                .font(.title2)
                .bold()

            TextField("场景名称", text: $name)
                .textFieldStyle(.roundedBorder)

            TextField("描述（可选）", text: $description)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("取消") { dismiss() }
                    .buttonStyle(.bordered)
                Button("创建") {
                    let scene = SimulationScene(
                        id: "scene-\(UUID().uuidString.prefix(8))",
                        name: name.isEmpty ? "新场景" : name,
                        description: description,
                        lastModified: Date(),
                        status: .idle,
                        fps: 0,
                        physicsSteps: 0
                    )
                    onSave(scene)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty)
            }
        }
        .padding()
        .frame(width: 320)
    }
}

// MARK: - NSBezierPath CGPath 扩展

extension NSBezierPath {
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [NSPoint](repeating: .zero, count: 3)
        for i in 0..<elementCount {
            let type = element(at: i, associatedPoints: &points)
            switch type {
            case .moveTo: path.move(to: points[0])
            case .lineTo: path.addLine(to: points[0])
            case .curveTo: path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .closePath: path.closeSubpath()
            @unknown default: break
            }
        }
        return path
    }
}