import SwiftUI
import os.log

private let iscLog = Logger(subsystem: "com.fusion.studio", category: "industry-scenarios")

// MARK: - 行业场景

struct IndustryScenario: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let industry: String
    let icon: String
    let color: Color
    let modules: [String]
    let difficulty: String
    let estimatedTime: String
    let isBuiltin: Bool
    var isInstalled: Bool

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: IndustryScenario, rhs: IndustryScenario) -> Bool { lhs.id == rhs.id }

    var localizedName: String {
        switch id {
        case "scene-robot-arm":       return I18nManager.shared.t(.isc_name_scene_robot_arm)
        case "scene-robot-walk":      return I18nManager.shared.t(.isc_name_scene_robot_walk)
        case "scene-content-blog":    return I18nManager.shared.t(.isc_name_scene_content_blog)
        case "scene-content-video":   return I18nManager.shared.t(.isc_name_scene_content_video)
        case "scene-enterprise-kb":   return I18nManager.shared.t(.isc_name_scene_enterprise_kb)
        case "scene-enterprise-report": return I18nManager.shared.t(.isc_name_scene_enterprise_report)
        case "scene-ai-agent":        return I18nManager.shared.t(.isc_name_scene_ai_agent)
        case "scene-ai-code-review":  return I18nManager.shared.t(.isc_name_scene_ai_code_review)
        case "scene-design-app":      return I18nManager.shared.t(.isc_name_scene_design_app)
        case "scene-design-dashboard": return I18nManager.shared.t(.isc_name_scene_design_dashboard)
        case "scene-science-lab":     return I18nManager.shared.t(.isc_name_scene_science_lab)
        case "scene-science-paper":   return I18nManager.shared.t(.isc_name_scene_science_paper)
        default: return name
        }
    }

    var localizedDesc: String {
        switch id {
        case "scene-robot-arm":       return I18nManager.shared.t(.isc_desc_scene_robot_arm)
        case "scene-robot-walk":      return I18nManager.shared.t(.isc_desc_scene_robot_walk)
        case "scene-content-blog":    return I18nManager.shared.t(.isc_desc_scene_content_blog)
        case "scene-content-video":   return I18nManager.shared.t(.isc_desc_scene_content_video)
        case "scene-enterprise-kb":   return I18nManager.shared.t(.isc_desc_scene_enterprise_kb)
        case "scene-enterprise-report": return I18nManager.shared.t(.isc_desc_scene_enterprise_report)
        case "scene-ai-agent":        return I18nManager.shared.t(.isc_desc_scene_ai_agent)
        case "scene-ai-code-review":  return I18nManager.shared.t(.isc_desc_scene_ai_code_review)
        case "scene-design-app":      return I18nManager.shared.t(.isc_desc_scene_design_app)
        case "scene-design-dashboard": return I18nManager.shared.t(.isc_desc_scene_design_dashboard)
        case "scene-science-lab":     return I18nManager.shared.t(.isc_desc_scene_science_lab)
        case "scene-science-paper":   return I18nManager.shared.t(.isc_desc_scene_science_paper)
        default: return description
        }
    }

    var localizedTime: String {
        switch id {
        case "scene-robot-arm":       return I18nManager.shared.t(.isc_time_scene_robot_arm)
        case "scene-robot-walk":      return I18nManager.shared.t(.isc_time_scene_robot_walk)
        case "scene-content-blog":    return I18nManager.shared.t(.isc_time_scene_content_blog)
        case "scene-content-video":   return I18nManager.shared.t(.isc_time_scene_content_video)
        case "scene-enterprise-kb":   return I18nManager.shared.t(.isc_time_scene_enterprise_kb)
        case "scene-enterprise-report": return I18nManager.shared.t(.isc_time_scene_enterprise_report)
        case "scene-ai-agent":        return I18nManager.shared.t(.isc_time_scene_ai_agent)
        case "scene-ai-code-review":  return I18nManager.shared.t(.isc_time_scene_ai_code_review)
        case "scene-design-app":      return I18nManager.shared.t(.isc_time_scene_design_app)
        case "scene-design-dashboard": return I18nManager.shared.t(.isc_time_scene_design_dashboard)
        case "scene-science-lab":     return I18nManager.shared.t(.isc_time_scene_science_lab)
        case "scene-science-paper":   return I18nManager.shared.t(.isc_time_scene_science_paper)
        default: return estimatedTime
        }
    }

    var localizedIndustry: String {
        switch industry {
        case "robot":      return I18nManager.shared.t(.isc_ind_robot)
        case "content":    return I18nManager.shared.t(.isc_ind_content)
        case "enterprise": return I18nManager.shared.t(.isc_ind_enterprise)
        case "aitool":     return I18nManager.shared.t(.isc_ind_aitool)
        case "design":     return I18nManager.shared.t(.isc_ind_design)
        case "science":    return I18nManager.shared.t(.isc_ind_science)
        default: return industry
        }
    }

    var localizedDifficulty: String {
        switch difficulty {
        case "beginner":      return I18nManager.shared.t(.isc_diff_beginner)
        case "intermediate":  return I18nManager.shared.t(.isc_diff_intermediate)
        case "advanced":      return I18nManager.shared.t(.isc_diff_advanced)
        default: return difficulty
        }
    }
}

// MARK: - 场景管理器

class IndustryScenarioManager: ObservableObject {
    static let shared = IndustryScenarioManager()

    @Published var scenarios: [IndustryScenario] = []
    @Published var searchText = ""
    @Published var selectedIndustry: String = "all"
    @Published var activeScenario: IndustryScenario?

    static let allKey = "all"

    var industries: [String] {
        [Self.allKey] + Set(scenarios.map(\.industry)).sorted()
    }

    var localizedIndustries: [String: String] {
        var map: [String: String] = [Self.allKey: I18nManager.shared.t(.isc_ind_all)]
        for ind in Set(scenarios.map(\.industry)) {
            map[ind] = IndustryScenario(id: "", name: "", description: "", industry: ind, icon: "", color: .clear, modules: [], difficulty: "", estimatedTime: "", isBuiltin: false, isInstalled: false).localizedIndustry
        }
        return map
    }

    var filteredScenarios: [IndustryScenario] {
        var result = scenarios
        if selectedIndustry != Self.allKey { result = result.filter { $0.industry == selectedIndustry } }
        if !searchText.isEmpty { result = result.filter { $0.localizedName.localizedCaseInsensitiveContains(searchText) || $0.localizedDesc.localizedCaseInsensitiveContains(searchText) } }
        return result
    }

    init() { loadScenarios() }

    private func loadScenarios() {
        scenarios = [
            IndustryScenario(id: "scene-robot-arm", name: "scene-robot-arm", description: "scene-robot-arm", industry: "robot", icon: "gearshape.2.fill", color: .blue, modules: ["Simulation", "Design", "Code"], difficulty: "intermediate", estimatedTime: "scene-robot-arm", isBuiltin: true, isInstalled: false),
            IndustryScenario(id: "scene-robot-walk", name: "scene-robot-walk", description: "scene-robot-walk", industry: "robot", icon: "figure.walk", color: .cyan, modules: ["Simulation", "Code"], difficulty: "advanced", estimatedTime: "scene-robot-walk", isBuiltin: true, isInstalled: false),
            IndustryScenario(id: "scene-content-blog", name: "scene-content-blog", description: "scene-content-blog", industry: "content", icon: "doc.text.fill", color: .orange, modules: ["Code", "MultiModal", "Agent"], difficulty: "beginner", estimatedTime: "scene-content-blog", isBuiltin: true, isInstalled: false),
            IndustryScenario(id: "scene-content-video", name: "scene-content-video", description: "scene-content-video", industry: "content", icon: "video.fill", color: .red, modules: ["MultiModal", "Code", "Agent"], difficulty: "intermediate", estimatedTime: "scene-content-video", isBuiltin: true, isInstalled: false),
            IndustryScenario(id: "scene-enterprise-kb", name: "scene-enterprise-kb", description: "scene-enterprise-kb", industry: "enterprise", icon: "books.vertical.fill", color: .indigo, modules: ["KB", "Doc", "Security"], difficulty: "intermediate", estimatedTime: "scene-enterprise-kb", isBuiltin: true, isInstalled: false),
            IndustryScenario(id: "scene-enterprise-report", name: "scene-enterprise-report", description: "scene-enterprise-report", industry: "enterprise", icon: "chart.bar.fill", color: .purple, modules: ["DataTools", "Analytics", "Code"], difficulty: "beginner", estimatedTime: "scene-enterprise-report", isBuiltin: true, isInstalled: false),
            IndustryScenario(id: "scene-ai-agent", name: "scene-ai-agent", description: "scene-ai-agent", industry: "aitool", icon: "message.fill", color: .green, modules: ["Agent", "KB", "Training"], difficulty: "advanced", estimatedTime: "scene-ai-agent", isBuiltin: true, isInstalled: false),
            IndustryScenario(id: "scene-ai-code-review", name: "scene-ai-code-review", description: "scene-ai-code-review", industry: "aitool", icon: "chevron.left.forwardslash.chevron.right", color: .blue, modules: ["Agent", "Code", "Security"], difficulty: "intermediate", estimatedTime: "scene-ai-code-review", isBuiltin: true, isInstalled: false),
            IndustryScenario(id: "scene-design-app", name: "scene-design-app", description: "scene-design-app", industry: "design", icon: "apps.iphone", color: .pink, modules: ["Design", "Code", "MultiModal"], difficulty: "intermediate", estimatedTime: "scene-design-app", isBuiltin: true, isInstalled: false),
            IndustryScenario(id: "scene-design-dashboard", name: "scene-design-dashboard", description: "scene-design-dashboard", industry: "design", icon: "square.grid.3x3.fill", color: .orange, modules: ["Design", "DataTools", "Analytics"], difficulty: "beginner", estimatedTime: "scene-design-dashboard", isBuiltin: true, isInstalled: false),
            IndustryScenario(id: "scene-science-lab", name: "scene-science-lab", description: "scene-science-lab", industry: "science", icon: "flask.fill", color: .teal, modules: ["Science"], difficulty: "intermediate", estimatedTime: "scene-science-lab", isBuiltin: true, isInstalled: false),
            IndustryScenario(id: "scene-science-paper", name: "scene-science-paper", description: "scene-science-paper", industry: "science", icon: "doc.text.magnifyingglass", color: .mint, modules: ["Science"], difficulty: "advanced", estimatedTime: "scene-science-paper", isBuiltin: true, isInstalled: false),
        ]
        iscLog.info("loaded \(self.scenarios.count) industry scenarios")
    }

    func installScene(_ id: String) {
        guard let idx = scenarios.firstIndex(where: { $0.id == id }) else { return }
        scenarios[idx].isInstalled = true
        activeScenario = scenarios[idx]
        objectWillChange.send()
        iscLog.info("installed scenario \(id)")
    }

    func uninstallScene(_ id: String) {
        guard let idx = scenarios.firstIndex(where: { $0.id == id }) else { return }
        scenarios[idx].isInstalled = false
        objectWillChange.send()
        iscLog.info("uninstalled scenario \(id)")
    }
}

// MARK: - 行业场景面板

struct IndustryScenariosView: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var manager = IndustryScenarioManager.shared
    @State private var viewMode: SceneViewMode = .grid
    @State private var selectedScenario: IndustryScenario?

    enum SceneViewMode: String, CaseIterable {
        case grid
        case list

        var localizedName: String {
            switch self {
            case .grid: return I18nManager.shared.t(.isc_view_grid)
            case .list: return I18nManager.shared.t(.isc_view_list)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(I18nManager.shared.t(.isc_title), systemImage: "square.stack.3d.forward.dottedline").font(.headline)
                Spacer()
                Picker("", selection: $viewMode) {
                    ForEach(SceneViewMode.allCases, id: \.self) { m in Text(m.localizedName).tag(m) }
                }
                .pickerStyle(.segmented).frame(width: 100)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(theme.surfaceSecondary)

            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField(I18nManager.shared.t(.isc_search_hint), text: $manager.searchText).textFieldStyle(.plain)
                Spacer()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(manager.industries, id: \.self) { ind in
                            Button(manager.localizedIndustries[ind] ?? ind) { manager.selectedIndustry = ind }
                                .buttonStyle(.bordered).controlSize(.small)
                                .tint(manager.selectedIndustry == ind ? .accentColor : nil)
                        }
                    }
                }
            }
            .padding(8)

            Divider()

            if manager.filteredScenarios.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "square.stack.3d.forward.dottedline").font(.system(size: 40)).foregroundColor(.secondary)
                    Text(I18nManager.shared.t(.isc_empty)).foregroundColor(.secondary)
                    Spacer()
                }
            } else if viewMode == .grid {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280))], spacing: 12) {
                        ForEach(manager.filteredScenarios) { scene in
                            ScenarioCard(scene: scene)
                                .onTapGesture { selectedScenario = scene }
                        }
                    }
                    .padding()
                }
            } else {
                List(manager.filteredScenarios) { scene in
                    ScenarioRow(scene: scene)
                        .onTapGesture { selectedScenario = scene }
                }
            }
        }
        .sheet(item: $selectedScenario) { scene in ScenarioDetailView(scene: scene) }
    }
}

// MARK: - 场景卡片

struct ScenarioCard: View {
    @Environment(\.studioTheme) private var theme
    let scene: IndustryScenario
    @StateObject private var manager = IndustryScenarioManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: scene.icon).font(.title2).foregroundColor(scene.color)
                Spacer()
                Text(scene.localizedIndustry).font(.system(size: 8)).padding(.horizontal, 4).padding(.vertical, 1)
                    .background(scene.color.opacity(0.1)).cornerRadius(3)
            }
            Text(scene.localizedName).font(.headline)
            Text(scene.localizedDesc).font(.caption).foregroundColor(.secondary).lineLimit(3)
            HStack(spacing: 4) {
                ForEach(scene.modules, id: \.self) { mod in
                    Text(mod).font(.system(size: 7)).padding(.horizontal, 3).padding(.vertical, 1)
                        .background(Color.accentColor.opacity(0.1)).cornerRadius(2)
                }
            }
            HStack {
                Label(scene.localizedDifficulty, systemImage: "signal").font(.caption2).foregroundColor(.secondary)
                Spacer()
                Label(scene.localizedTime, systemImage: "clock").font(.caption2).foregroundColor(.secondary)
            }
            Button(action: { scene.isInstalled ? manager.uninstallScene(scene.id) : manager.installScene(scene.id) }) {
                Label(scene.isInstalled ? I18nManager.shared.t(.isc_installed) : I18nManager.shared.t(.isc_install), systemImage: scene.isInstalled ? "checkmark.circle.fill" : "plus.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).controlSize(.small)
            .tint(scene.isInstalled ? .green : nil)
        }
        .padding()
        .background(theme.surfaceSecondary)
        .cornerRadius(10)
    }
}

// MARK: - 场景行

struct ScenarioRow: View {
    let scene: IndustryScenario
    @StateObject private var manager = IndustryScenarioManager.shared

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: scene.icon).foregroundColor(scene.color).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(scene.localizedName).font(.headline)
                Text(scene.localizedDesc).font(.caption).foregroundColor(.secondary).lineLimit(1)
                HStack(spacing: 8) {
                    Text(scene.localizedIndustry).font(.caption2).padding(.horizontal, 4).background(scene.color.opacity(0.1)).cornerRadius(3)
                    Text(scene.localizedDifficulty).font(.caption2).foregroundColor(.secondary)
                    Text(scene.localizedTime).font(.caption2).foregroundColor(.secondary)
                }
            }
            Spacer()
            Button(scene.isInstalled ? I18nManager.shared.t(.isc_installed) : I18nManager.shared.t(.isc_install_short)) { scene.isInstalled ? manager.uninstallScene(scene.id) : manager.installScene(scene.id) }
                .buttonStyle(.borderedProminent).controlSize(.small).tint(scene.isInstalled ? .green : nil)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 场景详情

struct ScenarioDetailView: View {
    let scene: IndustryScenario
    @Environment(\.dismiss) var dismiss
    @StateObject private var manager = IndustryScenarioManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: scene.icon).font(.title).foregroundColor(scene.color)
                VStack(alignment: .leading, spacing: 4) {
                    Text(scene.localizedName).font(.title2).bold()
                    Text(scene.localizedIndustry).font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                Button(I18nManager.shared.t(.isc_close)) { dismiss() }.buttonStyle(.borderedProminent)
            }

            Divider()

            GroupBox(I18nManager.shared.t(.isc_info)) {
                VStack(alignment: .leading, spacing: 6) {
                    SceneDetailRow(I18nManager.shared.t(.isc_row_desc), scene.localizedDesc)
                    SceneDetailRow(I18nManager.shared.t(.isc_row_diff), scene.localizedDifficulty)
                    SceneDetailRow(I18nManager.shared.t(.isc_row_time), scene.localizedTime)
                    SceneDetailRow(I18nManager.shared.t(.isc_row_type), scene.isBuiltin ? I18nManager.shared.t(.isc_type_builtin) : I18nManager.shared.t(.isc_type_custom))
                }
                .padding(8)
            }

            GroupBox(I18nManager.shared.t(.isc_modules)) {
                HStack {
                    ForEach(scene.modules, id: \.self) { mod in
                        Text(mod).font(.caption).padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.1)).cornerRadius(4)
                    }
                }
                .padding(8)
            }

            GroupBox(I18nManager.shared.t(.isc_install_guide)) {
                Text(I18nManager.shared.t(.isc_install_guide_desc))
                    .font(.subheadline).foregroundColor(.secondary)
                    .padding(8)
            }

            Spacer()

            HStack {
                Spacer()
                Button(action: {
                    scene.isInstalled ? manager.uninstallScene(scene.id) : manager.installScene(scene.id)
                    dismiss()
                }) {
                    Label(scene.isInstalled ? I18nManager.shared.t(.isc_uninstall) : I18nManager.shared.t(.isc_install), systemImage: scene.isInstalled ? "trash" : "plus.circle")
                        .frame(width: 160)
                }
                .buttonStyle(.borderedProminent)
                .tint(scene.isInstalled ? .red : nil)
                Spacer()
            }
        }
        .padding()
        .frame(width: 420, height: 480)
    }
}

struct SceneDetailRow: View {
    let label: String; let value: String
    init(_ label: String, _ value: String) { self.label = label; self.value = value }
    var body: some View {
        HStack(alignment: .top) {
            Text(label).foregroundColor(.secondary).frame(width: 60, alignment: .leading)
            Text(value).font(.system(.body, design: .monospaced))
            Spacer()
        }
    }
}
