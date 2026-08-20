// Callers: ModuleDetailView.designInfoPanel lint tab, DesignLintRuleLockSheet.
// Affected API: DesignLintPanel.runLint, DesignLintRuleLockSheet for rule lock/unlock.
// Data schemas: LintViolation, LintResult, LintStats, DesignLintIssue, lockedRules Set<String>.
// User instruction: "继续实施Phase 6"

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
        case .contrastCheck: return I18nManager.shared.t(.design_lint_rule_contrastCheck)
        case .unlabeledInput: return I18nManager.shared.t(.design_lint_rule_unlabeledInput)
        case .textEffects: return I18nManager.shared.t(.design_lint_rule_textEffects)
        case .abnormalRotation: return I18nManager.shared.t(.design_lint_rule_abnormalRotation)
        case .emptyEffects: return I18nManager.shared.t(.design_lint_rule_emptyEffects)
        case .tokenInconsistency: return I18nManager.shared.t(.design_lint_rule_tokenInconsistency)
        case .unnamedNode: return I18nManager.shared.t(.design_lint_rule_unnamedNode)
        case .textOverflow: return I18nManager.shared.t(.design_lint_rule_textOverflow)
        case .overlappingNodes: return I18nManager.shared.t(.design_lint_rule_overlappingNodes)
        case .hardcodedSpacing: return I18nManager.shared.t(.design_lint_rule_hardcodedSpacing)
        case .hardcodedFontSize: return I18nManager.shared.t(.design_lint_rule_hardcodedFontSize)
        case .missingInteractionState: return I18nManager.shared.t(.design_lint_rule_missingInteractionState)
        case .layoutInconsistency: return I18nManager.shared.t(.design_lint_rule_layoutInconsistency)
        }
    }

    var icon: String {
        switch self {
        case .contrastCheck: return "eye"
        case .unlabeledInput: return "textformat"
        case .textEffects: return "text.badge.star"
        case .abnormalRotation: return "rotate.3d"
        case .emptyEffects: return "sparkles"
        case .tokenInconsistency: return "paintbrush"
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

enum LintSeverity: String {
    case error
    case warning
    case info

    var color: Color {
        switch self {
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }

    var icon: String {
        switch self {
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
}

struct LintViolation: Identifiable {
    let id: String
    let rule: String
    let node_id: String
    let message: String
    let suggestion: String
    let severity: LintSeverity
}

struct LintStats {
    let total_nodes: Int
    let total_violations: Int
    let errors: Int
    let warnings: Int
    let infos: Int
}

// MARK: - Locked Rules Store

class DesignLintRuleStore: ObservableObject {
    static let shared = DesignLintRuleStore()
    @Published var lockedRules: Set<String> = []

    private let lockFilePath: String = {
        let dir = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first ?? "/tmp"
        return (dir as NSString).appendingPathComponent("fusion-studio/lint-locked-rules.json")
    }()

    private init() {
        loadLockedRules()
    }

    func toggleLock(_ rule: String) {
        if self.lockedRules.contains(rule) {
            self.lockedRules.remove(rule)
        } else {
            self.lockedRules.insert(rule)
        }
        self.saveLockedRules()
        lintLog.info("LintRuleStore: toggled lock for \(rule), now \(self.lockedRules.contains(rule) ? "locked" : "unlocked")")
    }

    func isLocked(_ rule: String) -> Bool {
        lockedRules.contains(rule)
    }

    private func loadLockedRules() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: self.lockFilePath)),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [String] else { return }
        self.lockedRules = Set(arr)
        lintLog.info("LintRuleStore: loaded \(self.lockedRules.count) locked rules")
    }

    func saveLockedRules() {
        let arr = Array(self.lockedRules)
        guard let data = try? JSONSerialization.data(withJSONObject: arr, options: .prettyPrinted) else { return }
        let dir = (lockFilePath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? data.write(to: URL(fileURLWithPath: lockFilePath))
    }
}

// MARK: - DesignLintPanel

struct DesignLintPanel: View {
    @EnvironmentObject var designBridge: DesignBridge
    @Environment(\.studioTheme) var theme
    @StateObject private var i18n = I18nManager.shared
    @State private var violations: [LintViolation] = []
    @State private var stats: LintStats?
    @State private var isRunning = false
    @State private var errorMessage: String?
    @State private var showRuleLockSheet = false
    @ObservedObject var ruleStore = DesignLintRuleStore.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(i18n.t(.design_lint_title))
                    .font(.system(size: theme.titleSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Spacer()
                FusionButton(i18n.t(.design_lint_ruleLock), icon: "lock.shield", style: .ghost, size: .small) {
                    showRuleLockSheet = true
                }
                FusionButton(i18n.t(.design_lint_run), icon: "play.fill", style: .primary, size: .small) {
                    runLint()
                }
                .disabled(isRunning)
            }
            .padding(theme.spacingM)

            if isRunning {
                ProgressView()
                    .padding(theme.spacingL)
            } else if let error = errorMessage {
                VStack(spacing: theme.spacingS) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 24))
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textSecondary)
                }
                .padding(theme.spacingL)
            } else if violations.isEmpty {
                VStack(spacing: theme.spacingS) {
                    Image(systemName: "checkmark.shield")
                        .font(.system(size: 32))
                        .foregroundStyle(.green)
                    Text(i18n.t(.design_lint_noViolation))
                        .font(.system(size: theme.textSize))
                        .foregroundStyle(theme.textSecondary)
                }
                .padding(theme.spacingL)
            } else {
                lintStatsBar
                violationList
            }
        }
        .sheet(isPresented: $showRuleLockSheet) {
            DesignLintRuleLockSheet()
        }
    }

    private var lintStatsBar: some View {
        HStack(spacing: theme.spacingM) {
            if let s = stats {
                HStack(spacing: theme.spacingXS) {
                    Circle().fill(.red).frame(width: 8, height: 8)
                    Text(String(format: i18n.t(.design_lint_errCountFmt), s.errors)).font(.system(size: theme.captionSize)).foregroundStyle(theme.textSecondary)
                }
                HStack(spacing: theme.spacingXS) {
                    Circle().fill(.orange).frame(width: 8, height: 8)
                    Text(String(format: i18n.t(.design_lint_warnCountFmt), s.warnings)).font(.system(size: theme.captionSize)).foregroundStyle(theme.textSecondary)
                }
                HStack(spacing: theme.spacingXS) {
                    Circle().fill(.blue).frame(width: 8, height: 8)
                    Text(String(format: i18n.t(.design_lint_infoCountFmt), s.infos)).font(.system(size: theme.captionSize)).foregroundStyle(theme.textSecondary)
                }
            }
            Spacer()
            Text(String(format: i18n.t(.design_lint_violationCountFmt), violations.count))
                .font(.system(size: theme.captionSize, weight: .medium))
                .foregroundStyle(theme.textTertiary)
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
        .background(theme.surfaceSecondary)
    }

    private var violationList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: theme.spacingXS) {
                ForEach(violations) { v in
                    violationRow(v)
                }
            }
            .padding(theme.spacingM)
        }
    }

    private func violationRow(_ v: LintViolation) -> some View {
        HStack(alignment: .top, spacing: theme.spacingS) {
            Image(systemName: v.severity.icon)
                .foregroundStyle(v.severity.color)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(v.message)
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(theme.text)
                if !v.suggestion.isEmpty {
                    Text(v.suggestion)
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textSecondary)
                }
                if !v.node_id.isEmpty {
                    Text(String(format: i18n.t(.design_lint_nodeFmt), v.node_id))
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                }
            }
            Spacer()
            if ruleStore.isLocked(v.rule) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .padding(theme.spacingS)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .fill(ruleStore.isLocked(v.rule) ? theme.surfaceSecondary.opacity(0.5) : theme.surfaceSecondary)
        )
    }

    private func runLint() {
        guard let docJSON = designBridge.lastRenderedDocumentJSON, !docJSON.isEmpty else {
            errorMessage = I18nManager.shared.t(.design_lint_genDocFirst)
            return
        }
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
                    self.errorMessage = I18nManager.shared.t(.design_lint_noResult)
                } else {
                    let filtered = issues.filter { !ruleStore.isLocked($0.rule) }
                    let mapped = filtered.map { issue -> LintViolation in
                        LintViolation(
                            id: issue.id.uuidString,
                            rule: issue.rule,
                            node_id: issue.nodeID ?? "",
                            message: issue.message,
                            suggestion: issue.suggestion ?? "",
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
                    lintLog.info("Lint completed: \(mapped.count) violations (\(issues.count - filtered.count) locked/hidden)")
                }
                self.isRunning = false
            }
        }
    }
}

// MARK: - Rule Lock Sheet

struct DesignLintRuleLockSheet: View {
    @Environment(\.studioTheme) var theme
    @Environment(\.dismiss) var dismiss
    @StateObject private var i18n = I18nManager.shared
    @ObservedObject var ruleStore = DesignLintRuleStore.shared

    var body: some View {
        VStack(spacing: theme.spacingM) {
            HStack {
                Text(i18n.t(.design_lint_lockTitle))
                    .font(.system(size: theme.titleSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Spacer()
                FusionButton(i18n.t(.design_lint_done), style: .ghost) { dismiss() }
            }

            Text(i18n.t(.design_lint_lockHint))
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textSecondary)

            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacingXS) {
                    ForEach(LintRuleOption.allCases) { rule in
                        HStack(spacing: theme.spacingS) {
                            Image(systemName: rule.icon)
                                .foregroundStyle(theme.accent)
                                .frame(width: 20)
                            Text(rule.label)
                                .font(.system(size: theme.textSize))
                                .foregroundStyle(theme.text)
                            Spacer()
                            Image(systemName: ruleStore.isLocked(rule.rawValue) ? "lock.fill" : "lock.open")
                                .foregroundStyle(ruleStore.isLocked(rule.rawValue) ? .orange : theme.textTertiary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { ruleStore.toggleLock(rule.rawValue) }
                        .padding(theme.spacingS)
                        .background(
                            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                .fill(ruleStore.isLocked(rule.rawValue) ? theme.surfaceElevated : theme.surfaceSecondary)
                        )
                    }
                }
            }

            HStack {
                Text(String(format: i18n.t(.design_lint_lockedCountFmt), ruleStore.lockedRules.count))
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
                if !ruleStore.lockedRules.isEmpty {
                    FusionButton(i18n.t(.design_lint_unlockAll), style: .ghost, size: .small) {
                        ruleStore.lockedRules.removeAll()
                        ruleStore.saveLockedRules()
                    }
                }
            }
        }
        .padding(theme.spacingL)
        .frame(width: 360, height: 480)
        .background(theme.surfacePrimary)
    }
}
