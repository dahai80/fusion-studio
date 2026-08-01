// Callers: ModuleDetailView.designInfoPanel lint tab.
// Affected API: DesignLintPanel.runLint now uses DesignBridge.skillLint unified bridge.
// Data schemas: LintViolation, LintResult, LintStats, DesignLintIssue.
// User instruction: "按照GUI草图实现fusion design，和~/fusion/fusion-design配合，端到端完成fusion设计"

import SwiftUI
import os.log

private let lintLog = Logger(subsystem: "com.fusion.studio", category: "DesignLintPanel")

enum LintRuleOption: String, CaseIterable, Identifiable {
    case contrastCheck = "contrast-check"
    case unlabeledInput = "unlabeled-input"
    case textEffects = "text-effects"
    case abnormalRotation = "abnormal-rotation"
    case emptyEffects = "empty-effects"
    case tokenInconsistency = "token-inconsistency"
    case unnamedNode = "unnamed-node"
    case textOverflow = "text-overflow"
    case overlappingNodes = "overlapping-nodes"
    case hardcodedSpacing = "hardcoded-spacing"
    case hardcodedFontSize = "hardcoded-font-size"
    case missingInteractionState = "missing-interaction-state"
    case layoutInconsistency = "layout-inconsistency"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .contrastCheck: return "对比度检查"
        case .unlabeledInput: return "无标签输入框"
        case .textEffects: return "文本特效"
        case .abnormalRotation: return "异常旋转"
        case .emptyEffects: return "空特效"
        case .tokenInconsistency: return "Token 不一致"
        case .unnamedNode: return "未命名节点"
        case .textOverflow: return "文本溢出"
        case .overlappingNodes: return "节点重叠"
        case .hardcodedSpacing: return "硬编码间距"
        case .hardcodedFontSize: return "硬编码字号"
        case .missingInteractionState: return "缺失交互状态"
        case .layoutInconsistency: return "布局不一致"
        }
    }

    var icon: String {
        switch self {
        case .contrastCheck: return "circle.lefthalf.filled"
        case .unlabeledInput: return "text.rectangle"
        case .textEffects: return "sparkles"
        case .abnormalRotation: return "rotate.3d"
        case .emptyEffects: return "eye.trianglebadge.exclamationmark"
        case .tokenInconsistency: return "paintpalette"
        case .unnamedNode: return "questionmark.square"
        case .textOverflow: return "text.append"
        case .overlappingNodes: return "square.on.square"
        case .hardcodedSpacing: return "ruler"
        case .hardcodedFontSize: return "textformat.size"
        case .missingInteractionState: return "hand.tap"
        case .layoutInconsistency: return "grid"
        }
    }
}

enum LintSeverity: String, Decodable {
    case error
    case warning
    case info
}

struct LintViolation: Identifiable, Decodable {
    let id: String
    let rule: String
    let node_id: String
    let message: String
    let suggestion: String?
    let severity: LintSeverity
}

struct LintResult: Decodable {
    let violations: [LintViolation]
    let stats: LintStats
}

struct LintStats: Decodable {
    let total_nodes: Int
    let total_violations: Int
    let errors: Int
    let warnings: Int
    let infos: Int
}

struct DesignLintPanel: View {
    @Environment(\.studioTheme) var theme
    @EnvironmentObject var designBridge: DesignBridge

    @State private var enabledRules: Set<LintRuleOption> = Set(LintRuleOption.allCases)
    @State private var violations: [LintViolation] = []
    @State private var stats: LintStats?
    @State private var isRunning = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ruleSelector
            Rectangle().fill(theme.separator).frame(height: 1)
            actionBar
            Rectangle().fill(theme.separator).frame(height: 1)
            if let err = errorMessage {
                errorBanner(err)
            }
            resultContent
        }
    }

    private var ruleSelector: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            HStack {
                Text("规则选择")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(theme.textTertiary)
                    .textCase(.uppercase)
                Spacer()
                Button(action: toggleAllRules) {
                    Text(enabledRules.count == LintRuleOption.allCases.count ? "全不选" : "全选")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, theme.spacingM)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(LintRuleOption.allCases) { rule in
                        Button(action: { toggleRule(rule) }) {
                            HStack(spacing: 3) {
                                Image(systemName: rule.icon)
                                    .font(.system(size: 9))
                                Text(rule.label)
                                    .font(.system(size: 9, weight: .medium))
                            }
                            .foregroundStyle(enabledRules.contains(rule) ? theme.accentText : theme.textTertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                    .fill(enabledRules.contains(rule) ? theme.accent : theme.groupBg)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, theme.spacingM)
            }
        }
        .padding(.vertical, theme.spacingS)
    }

    private var actionBar: some View {
        HStack(spacing: theme.spacingS) {
            Button(action: runLint) {
                HStack(spacing: 4) {
                    if isRunning {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 12, height: 12)
                    } else {
                        Image(systemName: "checkmark.shield")
                            .font(.system(size: 11))
                    }
                    Text(isRunning ? "检查中..." : "运行检查")
                        .font(.system(size: theme.footnoteSize, weight: .medium))
                }
                .foregroundStyle(theme.accentText)
                .padding(.horizontal, theme.spacingM)
                .padding(.vertical, theme.spacingXS)
                .background(
                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .fill(theme.accent)
                )
            }
            .buttonStyle(.plain)
            .disabled(isRunning || (designBridge.lastRenderedDocumentJSON ?? "").isEmpty)

            Spacer()

            if let s = stats {
                HStack(spacing: theme.spacingS) {
                    statBadge(count: s.errors, label: "错误", color: theme.accentDestructive)
                    statBadge(count: s.warnings, label: "警告", color: theme.amberDot)
                    statBadge(count: s.infos, label: "信息", color: theme.blueDot)
                    Text("\(s.total_nodes) 节点")
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                }
            }
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
    }

    private func statBadge(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 2) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(count) \(label)")
                .font(.system(size: theme.captionSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)
        }
    }

    private func errorBanner(_ msg: String) -> some View {
        HStack(spacing: theme.spacingXS) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(theme.amberDot)
            Text(msg)
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.textSecondary)
                .lineLimit(2)
            Spacer()
            Button(action: { errorMessage = nil }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(theme.spacingS)
        .background(theme.warningBg)
    }

    private var resultContent: some View {
        Group {
            if violations.isEmpty && stats == nil {
                VStack(spacing: theme.spacingS) {
                    Image(systemName: "checkmark.shield")
                        .font(.system(size: theme.iconL))
                        .foregroundStyle(theme.textTertiary)
                    Text("点击运行检查\n扫描设计规范问题")
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if violations.isEmpty {
                VStack(spacing: theme.spacingS) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: theme.iconXL))
                        .foregroundStyle(theme.greenDot)
                    Text("全部通过，无规范问题")
                        .font(.system(size: theme.footnoteSize, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: theme.spacingXS) {
                        ForEach(violations) { v in
                            violationRow(v)
                        }
                    }
                    .padding(theme.spacingS)
                }
            }
        }
    }

    private func violationRow(_ v: LintViolation) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: theme.spacingXS) {
                Image(systemName: severityIcon(v.severity))
                    .font(.system(size: 10))
                    .foregroundStyle(severityColor(v.severity))
                Text(v.rule)
                    .font(.system(size: theme.captionSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                Spacer()
                Text(v.node_id)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(theme.textTertiary)
            }
            Text(v.message)
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.textSecondary)
                .lineLimit(2)
            if let suggestion = v.suggestion, !suggestion.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(theme.amberDot)
                    Text(suggestion)
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(2)
                }
            }
        }
        .padding(theme.spacingS)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .fill(theme.groupBg)
        )
    }

    private func severityIcon(_ s: LintSeverity) -> String {
        switch s {
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    private func severityColor(_ s: LintSeverity) -> Color {
        switch s {
        case .error: return theme.accentDestructive
        case .warning: return theme.amberDot
        case .info: return theme.blueDot
        }
    }

    private func toggleRule(_ rule: LintRuleOption) {
        if enabledRules.contains(rule) {
            enabledRules.remove(rule)
        } else {
            enabledRules.insert(rule)
        }
    }

    private func toggleAllRules() {
        if enabledRules.count == LintRuleOption.allCases.count {
            enabledRules.removeAll()
        } else {
            enabledRules = Set(LintRuleOption.allCases)
        }
    }

    private func runLint() {
        guard let docJSON = designBridge.lastRenderedDocumentJSON, !docJSON.isEmpty else { return }
        isRunning = true
        errorMessage = nil
        violations = []
        stats = nil

        DispatchQueue.global(qos: .userInitiated).async {
            let issues = designBridge.skillLint(
                documentJSON: docJSON,
                designSystem: "apple-hig",
                fix: false
            )
            DispatchQueue.main.async {
                if issues.isEmpty && (designBridge.lastRenderedDocumentJSON ?? "").isEmpty {
                    self.errorMessage = "Lint 未返回结果"
                } else {
                    let mapped = issues.map { issue -> LintViolation in
                        LintViolation(
                            id: issue.id.uuidString,
                            rule: issue.rule,
                            node_id: issue.nodeID ?? "",
                            message: issue.message,
                            suggestion: issue.suggestion,
                            severity: LintSeverity(rawValue: issue.severity) ?? .info
                        )
                    }
                    self.violations = mapped
                    self.stats = LintStats(
                        total_nodes: 0,
                        total_violations: mapped.count,
                        errors: mapped.filter { $0.severity == .error }.count,
                        warnings: mapped.filter { $0.severity == .warning }.count,
                        infos: mapped.filter { $0.severity == .info }.count
                    )
                    lintLog.info("Lint completed: \(mapped.count) violations via unified bridge")
                }
                self.isRunning = false
            }
        }
    }

}
