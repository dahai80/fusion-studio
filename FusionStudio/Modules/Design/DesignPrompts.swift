// Callers: DesignChatPanel quickTemplateGrid, DesignBridge.sendDesignChat.
// Affected API: DesignPrompts.systemPrompt, DesignPrompts.groupedQuickTemplates, DesignPrompts.quickTemplates.
// Data schemas: DesignQuickTemplate (id/name/icon/prompt/group).
// User instruction: "按照GUI草图实现fusion design，和~/fusion/fusion-design配合，端到端完成fusion设计"

import Foundation

struct DesignQuickTemplate: Identifiable {
    let id: String
    let name: String
    let icon: String
    let prompt: String
    let group: DesignTemplateGroup

    init(id: String, name: String, icon: String, prompt: String, group: DesignTemplateGroup = .pages) {
        self.id = id
        self.name = name
        self.icon = icon
        self.prompt = prompt
        self.group = group
    }

    var localName: String {
        switch id {
        case "login": return I18nManager.shared.t(.design_tpl_login)
        case "dashboard": return I18nManager.shared.t(.design_tpl_dashboard)
        case "landing": return I18nManager.shared.t(.design_tpl_landing)
        case "settings": return I18nManager.shared.t(.design_tpl_settings)
        case "chat": return I18nManager.shared.t(.design_tpl_chat)
        case "profile": return I18nManager.shared.t(.design_tpl_profile)
        case "card": return I18nManager.shared.t(.design_tpl_card)
        case "form": return I18nManager.shared.t(.design_tpl_form)
        case "table": return I18nManager.shared.t(.design_tpl_table)
        case "nav": return I18nManager.shared.t(.design_tpl_nav)
        case "modal": return I18nManager.shared.t(.design_tpl_modal)
        case "buttons": return I18nManager.shared.t(.design_tpl_buttons)
        case "skill-text-to-ui": return I18nManager.shared.t(.design_tpl_textToUI)
        case "skill-image-to-ui": return I18nManager.shared.t(.design_tpl_imageToUI)
        case "skill-partial-edit": return I18nManager.shared.t(.design_tpl_partialEdit)
        case "skill-local-edit": return I18nManager.shared.t(.design_tpl_localEdit)
        case "skill-sim-panel": return I18nManager.shared.t(.design_tpl_simPanel)
        case "skill-multi-variants": return I18nManager.shared.t(.design_tpl_multiVariants)
        case "skill-spec-doc": return I18nManager.shared.t(.design_tpl_specDoc)
        case "skill-page-flow": return I18nManager.shared.t(.design_tpl_pageFlow)
        default: return name
        }
    }

    // F-I11: LLM-bound prompt 按 locale 模板 (dispatcher.templatePrompts)。
    // 12 page/component template 走 locale 模板; SKILL:* sentinel 保 RAW (路由用, 不可本地化)。
    var localPrompt: String {
        if prompt.hasPrefix("SKILL:") { return prompt }
        return DesignPrompts.dispatcher.templatePrompts[id] ?? prompt
    }
}

enum DesignPrompts {

    // F-I11: systemPrompt 走 locale 模板 (dispatcher.systemPrompt), 兼容 test + 旧调用点。
    // zh-CN source of truth 已移 DesignPromptSet_zhCN.swift。
    static var systemPrompt: String { dispatcher.systemPrompt }

    static let groupedQuickTemplates: [DesignQuickTemplate] = [
        DesignQuickTemplate(
            id: "login", name: "登录页", icon: "person.crop.circle.badge.plus",
            prompt: "设计一个现代化的登录页面，深色主题，支持邮箱和密码登录，有「记住我」选项和「忘记密码」链接，底部有社交登录按钮",
            group: .pages
        ),
        DesignQuickTemplate(
            id: "dashboard", name: "仪表盘", icon: "chart.bar",
            prompt: "设计一个数据仪表盘页面，深色主题，顶部导航栏，左侧侧边栏菜单，主区域有 4 个数据卡片 + 一个折线图区域 + 一个数据表格",
            group: .pages
        ),
        DesignQuickTemplate(
            id: "landing", name: "落地页", icon: "globe",
            prompt: "设计一个产品落地页，深色主题，包含：导航栏、Hero 区域（大标题+副标题+CTA 按钮）、特性介绍区（3 列）、定价区（3 个定价卡片）、页脚",
            group: .pages
        ),
        DesignQuickTemplate(
            id: "settings", name: "设置页", icon: "gearshape",
            prompt: "设计一个设置页面，深色主题，左侧标签页导航（通用/安全/通知/外观），右侧对应设置内容，使用表单控件（开关/选择器/输入框）",
            group: .pages
        ),
        DesignQuickTemplate(
            id: "chat", name: "聊天界面", icon: "bubble.left.and.bubble.right",
            prompt: "设计一个聊天界面，深色主题，左侧会话列表，右侧聊天区域（消息气泡+输入框），支持发送按钮和附件按钮",
            group: .pages
        ),
        DesignQuickTemplate(
            id: "profile", name: "个人主页", icon: "person.circle",
            prompt: "设计一个个人主页，深色主题，顶部头像+名称+简介，下方标签页切换（动态/收藏/关于），展示卡片列表",
            group: .pages
        ),
        DesignQuickTemplate(
            id: "card", name: "卡片组件", icon: "rectangle.on.rectangle.angled",
            prompt: "设计一套卡片组件：标准卡片、特色卡片（带图片）、轮廓卡片，每种 3 种尺寸，使用 Fusion Design Token",
            group: .components
        ),
        DesignQuickTemplate(
            id: "form", name: "表单", icon: "doc.text.fill",
            prompt: "设计一个注册表单，深色主题，包含：用户名、邮箱、密码（带强度指示器）、确认密码、同意条款复选框、提交按钮，有表单验证逻辑",
            group: .components
        ),
        DesignQuickTemplate(
            id: "table", name: "数据表格", icon: "tablecells",
            prompt: "设计一个可交互数据表格页面，深色主题，支持排序、搜索筛选、分页，每行有操作按钮（编辑/删除），表头可点击排序",
            group: .components
        ),
        DesignQuickTemplate(
            id: "nav", name: "导航栏", icon: "sidebar.leading",
            prompt: "设计一套导航组件：顶部导航栏（带搜索+用户头像）、侧边栏导航（可折叠+图标+标签）、面包屑导航，深色主题",
            group: .components
        ),
        DesignQuickTemplate(
            id: "modal", name: "弹窗/对话框", icon: "macwindow",
            prompt: "设计一套弹窗组件：确认对话框、表单弹窗、全屏模态、底部抽屉，带遮罩和动画，深色主题",
            group: .components
        ),
        DesignQuickTemplate(
            id: "buttons", name: "按钮组", icon: "hand.tap",
            prompt: "设计一套按钮组件：主要/次要/轮廓/文字/危险按钮，每种含默认/hover/active/disabled 状态，深色主题",
            group: .components
        ),
        DesignQuickTemplate(
            id: "skill-text-to-ui", name: "文生 UI", icon: "text.bubble",
            prompt: "SKILL:text_to_ui", group: .skills
        ),
        DesignQuickTemplate(
            id: "skill-image-to-ui", name: "图生 UI", icon: "photo.on.rectangle",
            prompt: "SKILL:image_to_ui", group: .skills
        ),
        DesignQuickTemplate(
            id: "skill-partial-edit", name: "局部编辑", icon: "pencil.circle",
            prompt: "SKILL:partial_edit", group: .skills
        ),
        DesignQuickTemplate(
            id: "skill-local-edit", name: "精准修改", icon: "scope",
            prompt: "SKILL:local_edit", group: .skills
        ),
        DesignQuickTemplate(
            id: "skill-sim-panel", name: "相似面板", icon: "square.on.square",
            prompt: "SKILL:sim_panel", group: .skills
        ),
        DesignQuickTemplate(
            id: "skill-multi-variants", name: "多方案", icon: "square.grid.3x3",
            prompt: "SKILL:multi_variants", group: .skills
        ),
        DesignQuickTemplate(
            id: "skill-spec-doc", name: "规范文档", icon: "doc.text.magnifyingglass",
            prompt: "SKILL:spec_doc", group: .skills
        ),
        DesignQuickTemplate(
            id: "skill-page-flow", name: "页面流", icon: "arrow.triangle.branch",
            prompt: "SKILL:page_flow", group: .skills
        ),
    ]

    static let quickTemplates: [DesignQuickTemplate] = groupedQuickTemplates.filter { $0.group != .skills }
}
