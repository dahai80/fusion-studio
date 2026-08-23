import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.fusion.studio", category: "DesignSystem")

enum ComponentVariant: String, Codable, CaseIterable, Identifiable {
    case primary = "primary"
    case secondary = "secondary"
    case ghost = "ghost"
    case outlined = "outlined"
    case featured = "featured"
    case destructive = "destructive"

    var id: String { rawValue }
}

enum ComponentSize: String, Codable, CaseIterable, Identifiable {
    case small = "sm"
    case medium = "md"
    case large = "lg"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .small: return I18nManager.shared.t(.design_ds_sizeSM)
        case .medium: return I18nManager.shared.t(.design_ds_sizeMD)
        case .large: return I18nManager.shared.t(.design_ds_sizeLG)
        }
    }
}

struct DesignComponent: Codable, Identifiable {
    let id: UUID
    var name: String
    var category: ComponentCategory
    var variants: [ComponentVariant]
    var sizes: [ComponentSize]
    var description: String
    var htmlTemplate: String
    var tags: [String]

    init(
        id: UUID = UUID(),
        name: String,
        category: ComponentCategory,
        variants: [ComponentVariant] = [.primary],
        sizes: [ComponentSize] = [.small, .medium, .large],
        description: String,
        htmlTemplate: String,
        tags: [String] = []
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.variants = variants
        self.sizes = sizes
        self.description = description
        self.htmlTemplate = htmlTemplate
        self.tags = tags
    }

    var localDescription: String {
        switch name {
        case "Button": return I18nManager.shared.t(.design_ds_desc_button)
        case "Card": return I18nManager.shared.t(.design_ds_desc_card)
        case "Input": return I18nManager.shared.t(.design_ds_desc_input)
        case "Select": return I18nManager.shared.t(.design_ds_desc_select)
        case "Modal": return I18nManager.shared.t(.design_ds_desc_modal)
        case "Navigation": return I18nManager.shared.t(.design_ds_desc_nav)
        case "Table": return I18nManager.shared.t(.design_ds_desc_table)
        case "Chart": return I18nManager.shared.t(.design_ds_desc_chart)
        case "Form": return I18nManager.shared.t(.design_ds_desc_form)
        default: return description
        }
    }
}

enum ComponentCategory: String, Codable, CaseIterable, Identifiable {
    case button
    case card
    case input
    case select
    case modal
    case navigation
    case table
    case chart
    case form

    var id: String { rawValue }

    var localLabel: String {
        switch self {
        case .button: return I18nManager.shared.t(.design_ds_cat_button)
        case .card: return I18nManager.shared.t(.design_ds_cat_card)
        case .input: return I18nManager.shared.t(.design_ds_cat_input)
        case .select: return I18nManager.shared.t(.design_ds_cat_select)
        case .modal: return I18nManager.shared.t(.design_ds_cat_modal)
        case .navigation: return I18nManager.shared.t(.design_ds_cat_nav)
        case .table: return I18nManager.shared.t(.design_ds_cat_table)
        case .chart: return I18nManager.shared.t(.design_ds_cat_chart)
        case .form: return I18nManager.shared.t(.design_ds_cat_form)
        }
    }

    var icon: String {
        switch self {
        case .button: return "capsule"
        case .card: return "rectangle.on.rectangle"
        case .input: return "text.cursor"
        case .select: return "list.bullet"
        case .modal: return "uiwindow.split.2x1"
        case .navigation: return "sidebar.left"
        case .table: return "tablecells"
        case .chart: return "chart.bar"
        case .form: return "text.page.badge.magnifyingglass"
        }
    }
}

enum DesignTemplate: String, Codable, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case landing = "Landing"
    case settings = "Settings"
    case login = "Login"
    case profile = "Profile"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .landing: return "globe"
        case .settings: return "gearshape"
        case .login: return "lock.shield"
        case .profile: return "person.crop.circle"
        }
    }

    var description: String {
        switch self {
        case .dashboard: return I18nManager.shared.t(.fds_tpl_desc_dashboard)
        case .landing: return I18nManager.shared.t(.fds_tpl_desc_landing)
        case .settings: return I18nManager.shared.t(.fds_tpl_desc_settings)
        case .login: return I18nManager.shared.t(.fds_tpl_desc_login)
        case .profile: return I18nManager.shared.t(.fds_tpl_desc_profile)
        }
    }
}

class FusionDesignSystem: ObservableObject {
    static let shared = FusionDesignSystem()

    @Published var components: [DesignComponent] = []
    @Published var templates: [DesignTemplate: String] = [:]
    @Published var selectedCategory: ComponentCategory? = nil
    @Published var searchQuery: String = ""

    var filteredComponents: [DesignComponent] {
        var result = components
        if let cat = selectedCategory {
            result = result.filter { $0.category == cat }
        }
        if !searchQuery.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchQuery) ||
                $0.tags.contains { $0.localizedCaseInsensitiveContains(searchQuery) }
            }
        }
        return result
    }

    init() {
        loadPresetComponents()
        loadPresetTemplates()
        logger.info("FusionDesignSystem loaded \(self.components.count) components, \(self.templates.count) templates")
    }

    func component(by name: String) -> DesignComponent? {
        components.first { $0.name == name }
    }

    func components(in category: ComponentCategory) -> [DesignComponent] {
        components.filter { $0.category == category }
    }

    func renderComponent(_ component: DesignComponent, variant: ComponentVariant = .primary, size: ComponentSize = .medium) -> String {
        var html = component.htmlTemplate
        html = html.replacingOccurrences(of: "{{variant}}", with: variant.rawValue)
        html = html.replacingOccurrences(of: "{{size}}", with: size.rawValue)
        html = html.replacingOccurrences(of: "{{sizeClass}}", with: "component-\(size.rawValue)")
        return html
    }

    func injectIntoPrompt(_ component: DesignComponent) -> String {
        """
        可用组件: \(component.name)
        分类: \(component.category.rawValue)
        变体: \(component.variants.map(\.rawValue).joined(separator: ", "))
        尺寸: \(component.sizes.map(\.displayName).joined(separator: "/"))
        说明: \(component.description)
        """
    }

    private func loadPresetComponents() {
        components = [
            presetButton(),
            presetCard(),
            presetInput(),
            presetSelect(),
            presetModal(),
            presetNavigation(),
            presetTable(),
            presetChart(),
            presetForm()
        ]
    }

    private func loadPresetTemplates() {
        templates = [
            .dashboard: dashboardTemplate,
            .landing: landingTemplate,
            .settings: settingsTemplate,
            .login: loginTemplate,
            .profile: profileTemplate
        ]
    }

    private func presetButton() -> DesignComponent {
        DesignComponent(
            name: "Button",
            category: .button,
            variants: [.primary, .secondary, .ghost, .destructive],
            sizes: [.small, .medium, .large],
            description: "操作按钮组件，支持多种样式变体和尺寸",
            htmlTemplate: """
            <button class="fusion-btn fusion-btn-{{variant}} {{sizeClass}}">
              按钮
            </button>
            """,
            tags: ["action", "交互", "按钮"]
        )
    }

    private func presetCard() -> DesignComponent {
        DesignComponent(
            name: "Card",
            category: .card,
            variants: [.primary, .outlined, .featured],
            sizes: [.small, .medium, .large],
            description: "内容卡片组件，支持标准/描边/特色样式",
            htmlTemplate: """
            <div class="fusion-card fusion-card-{{variant}} {{sizeClass}}">
              <div class="fusion-card-header">
                <h3 class="fusion-card-title">卡片标题</h3>
              </div>
              <div class="fusion-card-body">
                <p>卡片内容区域</p>
              </div>
            </div>
            """,
            tags: ["container", "布局", "卡片"]
        )
    }

    private func presetInput() -> DesignComponent {
        DesignComponent(
            name: "Input",
            category: .input,
            variants: [.primary, .outlined],
            sizes: [.small, .medium, .large],
            description: "文本输入组件，支持多种输入类型",
            htmlTemplate: """
            <div class="fusion-input {{sizeClass}}">
              <label class="fusion-input-label">标签</label>
              <input type="text" class="fusion-input-field fusion-input-{{variant}}" placeholder="请输入..." />
            </div>
            """,
            tags: ["form", "输入", "文本"]
        )
    }

    private func presetSelect() -> DesignComponent {
        DesignComponent(
            name: "Select",
            category: .select,
            variants: [.primary, .outlined],
            sizes: [.small, .medium, .large],
            description: "下拉选择组件，支持单选/多选",
            htmlTemplate: """
            <div class="fusion-select {{sizeClass}}">
              <label class="fusion-select-label">选择项</label>
              <select class="fusion-select-field fusion-select-{{variant}}">
                <option>选项 1</option>
                <option>选项 2</option>
                <option>选项 3</option>
              </select>
            </div>
            """,
            tags: ["form", "选择", "下拉"]
        )
    }

    private func presetModal() -> DesignComponent {
        DesignComponent(
            name: "Modal",
            category: .modal,
            variants: [.primary, .secondary],
            sizes: [.small, .medium, .large],
            description: "弹窗组件，支持信息/确认/表单模式",
            htmlTemplate: """
            <div class="fusion-modal-overlay">
              <div class="fusion-modal fusion-modal-{{variant}} {{sizeClass}}">
                <div class="fusion-modal-header">
                  <h3>弹窗标题</h3>
                  <button class="fusion-modal-close">&times;</button>
                </div>
                <div class="fusion-modal-body">
                  <p>弹窗内容</p>
                </div>
                <div class="fusion-modal-footer">
                  <button class="fusion-btn fusion-btn-secondary">取消</button>
                  <button class="fusion-btn fusion-btn-primary">确定</button>
                </div>
              </div>
            </div>
            """,
            tags: ["overlay", "弹窗", "对话框"]
        )
    }

    private func presetNavigation() -> DesignComponent {
        DesignComponent(
            name: "Navigation",
            category: .navigation,
            variants: [.primary, .secondary],
            sizes: [.medium, .large],
            description: "导航组件，支持顶栏/侧边栏/标签页",
            htmlTemplate: """
            <nav class="fusion-nav fusion-nav-{{variant}} {{sizeClass}}">
              <div class="fusion-nav-brand">Brand</div>
              <div class="fusion-nav-links">
                <a href="#" class="fusion-nav-link active">首页</a>
                <a href="#" class="fusion-nav-link">关于</a>
                <a href="#" class="fusion-nav-link">联系</a>
              </div>
            </nav>
            """,
            tags: ["nav", "导航", "菜单"]
        )
    }

    private func presetTable() -> DesignComponent {
        DesignComponent(
            name: "Table",
            category: .table,
            variants: [.primary, .outlined],
            sizes: [.small, .medium, .large],
            description: "数据表格组件，支持基础/可排序/分页",
            htmlTemplate: """
            <table class="fusion-table fusion-table-{{variant}} {{sizeClass}}">
              <thead>
                <tr>
                  <th>列 1</th>
                  <th>列 2</th>
                  <th>列 3</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <td>数据 1</td>
                  <td>数据 2</td>
                  <td>数据 3</td>
                </tr>
              </tbody>
            </table>
            """,
            tags: ["data", "表格", "列表"]
        )
    }

    private func presetChart() -> DesignComponent {
        DesignComponent(
            name: "Chart",
            category: .chart,
            variants: [.primary, .outlined],
            sizes: [.medium, .large],
            description: "图表组件，支持折线/柱状/饼图",
            htmlTemplate: """
            <div class="fusion-chart fusion-chart-{{variant}} {{sizeClass}}">
              <div class="fusion-chart-header">
                <h4>图表标题</h4>
              </div>
              <div class="fusion-chart-body">
                <svg viewBox="0 0 200 100" class="fusion-chart-svg">
                  <polyline fill="none" stroke="currentColor" stroke-width="2" points="0,80 40,60 80,70 120,40 160,50 200,20"/>
                </svg>
              </div>
            </div>
            """,
            tags: ["可视化", "图表", "数据"]
        )
    }

    private func presetForm() -> DesignComponent {
        DesignComponent(
            name: "Form",
            category: .form,
            variants: [.primary, .outlined],
            sizes: [.medium, .large],
            description: "表单组件，支持登录/注册/联系表单",
            htmlTemplate: """
            <form class="fusion-form fusion-form-{{variant}} {{sizeClass}}">
              <div class="fusion-form-group">
                <label>用户名</label>
                <input type="text" placeholder="请输入用户名" />
              </div>
              <div class="fusion-form-group">
                <label>密码</label>
                <input type="password" placeholder="请输入密码" />
              </div>
              <button type="submit" class="fusion-btn fusion-btn-primary">提交</button>
            </form>
            """,
            tags: ["form", "表单", "输入"]
        )
    }

    private var dashboardTemplate: String {
        """
        <div class="fusion-dashboard">
          <nav class="fusion-nav fusion-nav-primary">
            <div class="fusion-nav-brand">Dashboard</div>
          </nav>
          <main class="fusion-dashboard-main">
            <div class="fusion-dashboard-stats">
              <div class="fusion-card fusion-card-primary">
                <div class="fusion-card-body"><h3>统计 1</h3><p>1,234</p></div>
              </div>
              <div class="fusion-card fusion-card-primary">
                <div class="fusion-card-body"><h3>统计 2</h3><p>567</p></div>
              </div>
            </div>
          </main>
        </div>
        """
    }

    private var landingTemplate: String {
        """
        <div class="fusion-landing">
          <nav class="fusion-nav fusion-nav-primary">
            <div class="fusion-nav-brand">Fusion</div>
            <div class="fusion-nav-links">
              <a href="#">功能</a>
              <a href="#">定价</a>
              <a href="#">关于</a>
            </div>
          </nav>
          <section class="fusion-landing-hero">
            <h1>构建下一代应用</h1>
            <p>Fusion Studio — 本地 AI 驱动的设计开发平台</p>
            <button class="fusion-btn fusion-btn-primary">开始使用</button>
          </section>
        </div>
        """
    }

    private var settingsTemplate: String {
        """
        <div class="fusion-settings">
          <nav class="fusion-nav fusion-nav-secondary">
            <a href="#" class="active">通用</a>
            <a href="#">外观</a>
            <a href="#">高级</a>
          </nav>
          <main class="fusion-settings-content">
            <form class="fusion-form fusion-form-primary">
              <div class="fusion-form-group">
                <label>语言</label>
                <select><option>简体中文</option></select>
              </div>
              <div class="fusion-form-group">
                <label>主题</label>
                <select><option>深色</option><option>浅色</option></select>
              </div>
            </form>
          </main>
        </div>
        """
    }

    private var loginTemplate: String {
        """
        <div class="fusion-login">
          <div class="fusion-card fusion-card-outlined fusion-card-medium">
            <div class="fusion-card-header"><h3>登录</h3></div>
            <div class="fusion-card-body">
              <form class="fusion-form fusion-form-primary">
                <div class="fusion-form-group">
                  <label>邮箱</label>
                  <input type="email" placeholder="name@example.com" />
                </div>
                <div class="fusion-form-group">
                  <label>密码</label>
                  <input type="password" placeholder="••••••••" />
                </div>
                <button type="submit" class="fusion-btn fusion-btn-primary">登录</button>
              </form>
            </div>
          </div>
        </div>
        """
    }

    private var profileTemplate: String {
        """
        <div class="fusion-profile">
          <div class="fusion-card fusion-card-featured">
            <div class="fusion-card-header">
              <div class="fusion-avatar"></div>
              <h3>用户名</h3>
            </div>
            <div class="fusion-card-body">
              <form class="fusion-form fusion-form-primary">
                <div class="fusion-form-group">
                  <label>显示名称</label>
                  <input type="text" value="用户" />
                </div>
                <div class="fusion-form-group">
                  <label>个人简介</label>
                  <textarea placeholder="介绍一下自己..."></textarea>
                </div>
                <button type="submit" class="fusion-btn fusion-btn-primary">保存</button>
              </form>
            </div>
          </div>
        </div>
        """
    }
}

struct DesignComponentLibraryView: View {
    @StateObject private var designSystem = FusionDesignSystem.shared
    @StateObject private var i18n = I18nManager.shared
    @Environment(\.studioTheme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBar
            Rectangle().fill(theme.separator).frame(height: 1)
            HStack(spacing: 0) {
                categorySidebar
                Rectangle().fill(theme.separator).frame(width: 1)
                componentList
            }
        }
    }

    private var headerBar: some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: "square.grid.3x3")
                .foregroundColor(theme.accent)
            Text(i18n.t(.design_ds_compLibrary))
                .font(.system(size: theme.bodySize, weight: .semibold))
                .foregroundColor(theme.text)
            Spacer()
            HStack(spacing: theme.spacingXS) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(theme.textTertiary)
                TextField(i18n.t(.design_ds_searchCompPh), text: $designSystem.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: theme.captionSize))
                    .foregroundColor(theme.text)
            }
            .padding(.horizontal, theme.spacingS)
            .padding(.vertical, theme.spacingXS)
            .background(theme.inputBg)
            .cornerRadius(theme.cornerRadiusSmall)
            .frame(width: 160)
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
    }

    private var categorySidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { designSystem.selectedCategory = nil }) {
                HStack(spacing: theme.spacingXS) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 11))
                    Text(i18n.t(.design_ds_catAll))
                        .font(.system(size: theme.captionSize))
                }
                .foregroundColor(designSystem.selectedCategory == nil ? theme.accentText : theme.textSecondary)
                .padding(.horizontal, theme.spacingS)
                .padding(.vertical, theme.spacingXS)
                .background(designSystem.selectedCategory == nil ? theme.accentSoft : Color.clear)
                .cornerRadius(theme.cornerRadiusSmall)
            }
            .buttonStyle(.plain)

            ForEach(ComponentCategory.allCases) { cat in
                Button(action: { designSystem.selectedCategory = cat }) {
                    HStack(spacing: theme.spacingXS) {
                        Image(systemName: cat.icon)
                            .font(.system(size: 11))
                        Text(cat.localLabel)
                            .font(.system(size: theme.captionSize))
                        Spacer()
                        Text("\(designSystem.components(in: cat).count)")
                            .font(.system(size: 10))
                            .foregroundColor(theme.textTertiary)
                    }
                    .foregroundColor(designSystem.selectedCategory == cat ? theme.accentText : theme.textSecondary)
                    .padding(.horizontal, theme.spacingS)
                    .padding(.vertical, theme.spacingXS)
                    .background(designSystem.selectedCategory == cat ? theme.accentSoft : Color.clear)
                    .cornerRadius(theme.cornerRadiusSmall)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            VStack(alignment: .leading, spacing: theme.spacingXS) {
                Text(i18n.t(.design_ds_template))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(theme.textTertiary)
                    .textCase(.uppercase)
                ForEach(DesignTemplate.allCases) { tmpl in
                    HStack(spacing: theme.spacingXS) {
                        Image(systemName: tmpl.icon)
                            .font(.system(size: 10))
                        Text(tmpl.rawValue)
                            .font(.system(size: theme.captionSize))
                    }
                    .foregroundColor(theme.textSecondary)
                }
            }
            .padding(theme.spacingS)
        }
        .frame(width: 140)
        .padding(.vertical, theme.spacingS)
    }

    private var componentList: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: theme.spacingS),
                GridItem(.flexible(), spacing: theme.spacingS)
            ], spacing: theme.spacingS) {
                ForEach(designSystem.filteredComponents) { comp in
                    ComponentCard(component: comp)
                }
            }
            .padding(theme.spacingM)
        }
    }
}

struct ComponentCard: View {
    let component: DesignComponent
    @Environment(\.studioTheme) var theme
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            HStack {
                Image(systemName: component.category.icon)
                    .foregroundColor(theme.accent)
                    .font(.system(size: 12))
                Text(component.name)
                    .font(.system(size: theme.bodySize, weight: .semibold))
                    .foregroundColor(theme.text)
                Spacer()
            }

            Text(component.localDescription)
                .font(.system(size: theme.captionSize))
                .foregroundColor(theme.textSecondary)
                .lineLimit(2)

            HStack(spacing: theme.spacingXS) {
                ForEach(component.variants, id: \.self) { v in
                    Text(v.rawValue)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(theme.accentText)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(theme.accentSoft)
                        .cornerRadius(3)
                }
            }

            HStack(spacing: 4) {
                ForEach(component.sizes, id: \.self) { s in
                    Text(s.displayName)
                        .font(.system(size: 9))
                        .foregroundColor(theme.textTertiary)
                }
            }
        }
        .padding(theme.spacingS)
        .background(isHovered ? theme.surfaceElevated : theme.surfacePrimary)
        .cornerRadius(theme.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius)
                .stroke(isHovered ? theme.accentSoft : theme.groupBorder, lineWidth: 1)
        )
        .onHover { h in isHovered = h }
    }
}
