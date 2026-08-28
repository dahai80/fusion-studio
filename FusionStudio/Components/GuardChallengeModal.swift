import SwiftUI

// #344: guard L3 人机确认弹窗 (mirror HubSecurityView SecApprovalReviewSheet)。
// GuardBridge.requestApproval 设 pendingChallenge 后此 sheet 弹出; 用户点 Approve/Reject
// → resolveApproval → guard.confirm 落审计 → resume continuation (executeGraph 继续/终止)。
// L4 (requiresApproval 恒 false) 不弹此窗, 直接 guardBlocked。

struct GuardChallengeModal: View {
    @ObservedObject var guardBridge: GuardBridge
    let challenge: GuardBridge.GuardChallenge
    @Environment(\.studioTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @StateObject private var i18n = I18nManager.shared
    @State private var isResolving = false

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            HStack {
                Text(i18n.t(.guard_title))
                    .font(.title2)
                    .bold()
                Spacer()
                Text(challenge.riskLevel)
                    .font(.caption)
                    .bold()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(theme.warningBg)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .foregroundStyle(theme.warningText)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(String(format: i18n.t(.guard_action_fmt), challenge.action))
                    .font(.system(size: theme.textSize))
                Text(String(format: i18n.t(.guard_reason_fmt), challenge.reason))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(i18n.t(.guard_content))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ScrollView {
                    Text(challenge.content.isEmpty ? "(empty)" : challenge.content)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, maxHeight: 120)
                .padding(6)
                .background(theme.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            if isResolving {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }

            Spacer()

            HStack {
                Spacer()
                Button(i18n.t(.guard_reject)) {
                    resolve(approved: false)
                }
                .buttonStyle(.bordered)
                .foregroundStyle(.red)
                .disabled(isResolving)

                Button(i18n.t(.guard_approve)) {
                    resolve(approved: true)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isResolving)
            }
        }
        .padding()
        .frame(width: 460, height: 360)
        .background(theme.windowBg)
    }

    private func resolve(approved: Bool) {
        isResolving = true
        Task {
            await guardBridge.resolveApproval(approved: approved)
            await MainActor.run {
                isResolving = false
                dismiss()
            }
        }
    }
}
