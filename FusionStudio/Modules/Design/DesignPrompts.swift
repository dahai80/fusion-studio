// Callers: DesignBridge.sendDesignChat — injects system prompt into LLM chat context.
// Affected API: DesignPrompts static properties (systemPrompt, quickTemplates).
// Data schemas: DesignQuickTemplate (id/name/icon/prompt).
// User instruction: "按照你的方案和优先级启动落地" — Fusion Design Phase 1 per claude_design_insight.md

import Foundation

struct DesignQuickTemplate: Identifiable {
    let id: String
    let name: String
    let icon: String
    let prompt: String
}

enum DesignPrompts {

    static let systemPrompt = """
    你是 Fusion Studio 的专业 UI 设计师和前端工程师。根据用户需求生成高质量的 HTML 组件代码。

    ## 输出规范

    1. 使用 Tailwind CSS (CDN) 进行样式设计，不使用内联 style
    2. 组件必须是自包含的完整 HTML 文档，可直接在浏览器运行
    3. 支持 dark 主题（页面默认深色背景 #1a1a2e，文字 #e0e0e0）
    4. 响应式布局，使用 Tailwind 的 responsive 前缀
    5. 交互逻辑用内联 <script> 实现
    6. 不使用任何框架（React/Vue/Angular），纯 HTML + Tailwind + vanilla JS
    7. 使用 CSS 变量定义设计 Token:

    :root {
      --color-primary: #007AFF;
      --color-secondary: #5856D6;
      --color-success: #34C759;
      --color-warning: #FF9500;
      --color-error: #FF3B30;
      --color-bg: #1a1a2e;
      --color-surface: #16213e;
      --color-text: #e0e0e0;
      --color-text-secondary: #a0a0a0;
      --radius-sm: 6px;
      --radius-md: 10px;
      --radius-lg: 16px;
      --spacing-xs: 4px;
      --spacing-sm: 8px;
      --spacing-md: 16px;
      --spacing-lg: 24px;
    }

    ## 输出格式

    用 antArtifact 标签包裹生成的代码:

    <antArtifact type="html" title="组件名称">
    完整 HTML 代码...
    </antArtifact>

    如果用户要求修改现有设计，只输出修改后的完整代码（仍然用 antArtifact 包裹），不要输出 diff。
    不要在代码之外添加额外解释，代码即最终产物。
    """

    static let quickTemplates: [DesignQuickTemplate] = [
        DesignQuickTemplate(
            id: "login",
            name: "登录页",
            icon: "person.crop.circle.badge.plus",
            prompt: "设计一个现代化的登录页面，深色主题，支持邮箱和密码登录，有「记住我」选项和「忘记密码」链接，底部有社交登录按钮"
        ),
        DesignQuickTemplate(
            id: "dashboard",
            name: "仪表盘",
            icon: "chart.bar",
            prompt: "设计一个数据仪表盘页面，深色主题，顶部导航栏，左侧侧边栏菜单，主区域有 4 个数据卡片 + 一个折线图区域 + 一个数据表格"
        ),
        DesignQuickTemplate(
            id: "card",
            name: "卡片组件",
            icon: "rectangle.on.rectangle.angled",
            prompt: "设计一套卡片组件：标准卡片、特色卡片（带图片）、轮廓卡片，每种 3 种尺寸，使用 Fusion Design Token"
        ),
        DesignQuickTemplate(
            id: "form",
            name: "表单",
            icon: "doc.text.fill",
            prompt: "设计一个注册表单，深色主题，包含：用户名、邮箱、密码（带强度指示器）、确认密码、同意条款复选框、提交按钮，有表单验证逻辑"
        ),
        DesignQuickTemplate(
            id: "landing",
            name: "落地页",
            icon: "globe",
            prompt: "设计一个产品落地页，深色主题，包含：导航栏、Hero 区域（大标题+副标题+CTA 按钮）、特性介绍区（3 列）、定价区（3 个定价卡片）、页脚"
        ),
        DesignQuickTemplate(
            id: "settings",
            name: "设置页",
            icon: "gearshape",
            prompt: "设计一个设置页面，深色主题，左侧标签页导航（通用/安全/通知/外观），右侧对应设置内容，使用表单控件（开关/选择器/输入框）"
        ),
        DesignQuickTemplate(
            id: "table",
            name: "数据表格",
            icon: "tablecells",
            prompt: "设计一个可交互数据表格页面，深色主题，支持排序、搜索筛选、分页，每行有操作按钮（编辑/删除），表头可点击排序"
        ),
        DesignQuickTemplate(
            id: "chat",
            name: "聊天界面",
            icon: "bubble.left.and.bubble.right",
            prompt: "设计一个聊天界面，深色主题，左侧会话列表，右侧聊天区域（消息气泡+输入框），支持发送按钮和附件按钮"
        ),
    ]
}
