// F-I11: zh-CN locale prompt set — source of truth, 逐字搬现有 Chinese, 行为零改。
// 现有 payload 源: DesignPrompts.swift systemPrompt (52-94) + 12 template .prompt + DesignBridge 13 fragment + 2 default array + DesignChatPanel 8 fallback。

import Foundation

extension DesignPrompts {

    static let zhCN = DesignPromptSet(
        systemPrompt: """
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
        """,
        templatePrompts: [
            "login": "设计一个现代化的登录页面，深色主题，支持邮箱和密码登录，有「记住我」选项和「忘记密码」链接，底部有社交登录按钮",
            "dashboard": "设计一个数据仪表盘页面，深色主题，顶部导航栏，左侧侧边栏菜单，主区域有 4 个数据卡片 + 一个折线图区域 + 一个数据表格",
            "landing": "设计一个产品落地页，深色主题，包含：导航栏、Hero 区域（大标题+副标题+CTA 按钮）、特性介绍区（3 列）、定价区（3 个定价卡片）、页脚",
            "settings": "设计一个设置页面，深色主题，左侧标签页导航（通用/安全/通知/外观），右侧对应设置内容，使用表单控件（开关/选择器/输入框）",
            "chat": "设计一个聊天界面，深色主题，左侧会话列表，右侧聊天区域（消息气泡+输入框），支持发送按钮和附件按钮",
            "profile": "设计一个个人主页，深色主题，顶部头像+名称+简介，下方标签页切换（动态/收藏/关于），展示卡片列表",
            "card": "设计一套卡片组件：标准卡片、特色卡片（带图片）、轮廓卡片，每种 3 种尺寸，使用 Fusion Design Token",
            "form": "设计一个注册表单，深色主题，包含：用户名、邮箱、密码（带强度指示器）、确认密码、同意条款复选框、提交按钮，有表单验证逻辑",
            "table": "设计一个可交互数据表格页面，深色主题，支持排序、搜索筛选、分页，每行有操作按钮（编辑/删除），表头可点击排序",
            "nav": "设计一套导航组件：顶部导航栏（带搜索+用户头像）、侧边栏导航（可折叠+图标+标签）、面包屑导航，深色主题",
            "modal": "设计一套弹窗组件：确认对话框、表单弹窗、全屏模态、底部抽屉，带遮罩和动画，深色主题",
            "buttons": "设计一套按钮组件：主要/次要/轮廓/文字/危险按钮，每种含默认/hover/active/disabled 状态，深色主题",
        ],
        pageFlowDefaultNames: ["首页", "列表", "详情"],
        multiVariantsDefaultStyles: ["简约", "现代", "极简"],
        fallbackTextToUI: "设计一个现代深色主题页面",
        fallbackImageToUIHint: "参考图片生成UI布局",
        fallbackMultiVariants: "设计一个数据卡片组件",
        fallbackLocalEditInstruction: "修改选中元素",
        fallbackPartialEditInstruction: "优化选中节点的视觉样式",
        fallbackSimPanel: "生成风格变体",
        fallbackSpecDoc: "输出完整设计规范",
        fallbackPageFlow: "首页→列表→详情的导航流程",
        applyLocalEditContext: { nodesJSON, instruction in
            "选中节点的当前状态:\n\(nodesJSON)\n\n请修改以上节点，使其满足: \(instruction)\n\n只输出修改后节点的 JSON 数组，不要输出其他内容。格式: [{\"id\":\"...\", ...修改的属性}]"
        },
        skillImageToUIPrompt: { imagePath, hint, pageName in
            "参考图片路径: \(imagePath)\n补充说明: \(hint)\n生成页面「\(pageName)」对应的 UI 布局"
        },
        skillPartialEditPrompt: { nodesJSON, instruction in
            "对以下节点进行局部修改:\n\(nodesJSON)\n\n修改要求: \(instruction)\n\n只输出修改后节点的完整 JSON，保持 id 不变。格式: [{\"id\":\"...\", ...所有属性}]"
        },
        skillSimPanelPrompt: { prompt in
            "生成与当前设计相似但风格不同的面板变体。要求: \(prompt)\n\n保持功能相同，但调整配色、间距、圆角等视觉属性，产出3个变体方案。"
        },
        skillSpecDocPrompt: { prompt in
            "根据当前设计，生成设计规范文档，包含:\n1. 设计 Token（颜色、字体、间距、圆角）\n2. 组件规范（按钮、卡片、输入框等）\n3. 布局规则\n4. 交互状态规范\n\n补充要求: \(prompt)"
        },
        pageFlowPerPage: { idx, name, prompt in
            "页面\(idx+1)「\(name)」: \(prompt)"
        },
        pageFlowFlowPrompt: { flowDesc in
            "设计一个多页面流程，包含以下页面之间的导航关系:\n\(flowDesc)\n\n每页需包含导航元素（按钮/链接）指向下一页。"
        },
        pageFlowPagePrompt: { flowPrompt, idx, pageName in
            "\(flowPrompt)\n\n当前生成: 页面\(idx+1)「\(pageName)」"
        },
        multiVariantsStyledPrompt: { prompt, style in
            "\(prompt)（风格：\(style)）"
        },
        sendDesignChatArtifactAppend: { currentArtifactCode in
            "\n\n当前设计代码:\n```html\n\(currentArtifactCode)\n```\n请基于此代码进行迭代修改。"
        },
        sendDesignChatRagAppend: { rag in
            "\n\n项目设计规范:\n\(rag)"
        }
    )
}
