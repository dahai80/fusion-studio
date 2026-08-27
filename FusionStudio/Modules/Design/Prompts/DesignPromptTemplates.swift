// F-I11: Design LLM prompt locale 模板机制。
// 28 LLM payload 按 locale 分模板文件 (用户决策 "按 locale 分模板文件")。
// DesignPromptSet = 每 locale 一值 (let 字段 + 13 插值 fragment 闭包)。
// DesignPrompts.dispatcher = 唯一分支点 (读 I18nManager.shared.currentLanguage),
// 保 I18nService 外零 locale 条件分支 invariant。
// zh-CN source of truth 逐字搬现有 Chinese, 行为零改。

import Foundation

// MARK: - DesignPromptSet (per-locale value)

struct DesignPromptSet {
    let systemPrompt: String

    let templatePrompts: [String: String]

    let pageFlowDefaultNames: [String]
    let multiVariantsDefaultStyles: [String]

    let fallbackTextToUI: String
    let fallbackImageToUIHint: String
    let fallbackMultiVariants: String
    let fallbackLocalEditInstruction: String
    let fallbackPartialEditInstruction: String
    let fallbackSimPanel: String
    let fallbackSpecDoc: String
    let fallbackPageFlow: String

    let applyLocalEditContext: (String, String) -> String
    let skillImageToUIPrompt: (String, String, String) -> String
    let skillPartialEditPrompt: (String, String) -> String
    let skillSimPanelPrompt: (String) -> String
    let skillSpecDocPrompt: (String) -> String
    let pageFlowPerPage: (Int, String, String) -> String
    let pageFlowFlowPrompt: (String) -> String
    let pageFlowPagePrompt: (String, Int, String) -> String
    let multiVariantsStyledPrompt: (String, String) -> String
    let sendDesignChatArtifactAppend: (String) -> String
    let sendDesignChatRagAppend: (String) -> String
}

// MARK: - DesignPrompts dispatcher (唯一分支点)

extension DesignPrompts {

    static var dispatcher: DesignPromptSet {
        switch I18nManager.shared.currentLanguage {
        case .zhCN: return zhCN
        case .enUS: return enUS
        case .jaJP: return jaJP
        case .koKR: return koKR
        }
    }
}
