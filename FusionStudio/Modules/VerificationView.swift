// Callers: ModuleDetailView routing. Affected API: verify.verify. Data schemas: content=String, criteria=[String], auto_fix=Bool, returns {passed: Bool, score: Double, issues: [{type, message}], fixed_content: String}. User instruction: "审视是否所有需要功能和api所有需要的GUI都在~/fusion/fusion-studio都已经有对应GUI了，所有有问题的都要在fusion-studio补齐GUI"

import SwiftUI
import os.log

struct VerificationView: View {
    @EnvironmentObject var bridge: AgentBridge
    @Environment(\.studioTheme) var theme
    @State private var contentInput: String = ""
    @State private var criteriaInput: String = ""
    @State private var autoFix: Bool = false
    @State private var isVerifying: Bool = false
    @State private var result: [String: Any]?
    @State private var errorMsg: String?

    private let logger = Logger(subsystem: "com.fusion.studio", category: "Verification")

    var body: some View {
        VStack(spacing: theme.spacingM) {
            Text("Verification")
                .font(.system(size: theme.titleSize, weight: .bold))
                .foregroundStyle(theme.text)

            VStack(alignment: .leading, spacing: theme.spacingS) {
                Text("Content to Verify")
                    .font(.system(size: theme.smallTextSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                TextEditor(text: $contentInput)
                    .font(.system(size: theme.textSize, design: .monospaced))
                    .frame(minHeight: 120)
                    .padding(theme.spacingS)
                    .background(theme.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))

                HStack(spacing: theme.spacingM) {
                    TextField("Criteria (comma-separated)", text: $criteriaInput)
                        .textFieldStyle(.roundedBorder)
                    Toggle("Auto Fix", isOn: $autoFix)
                    Button("Verify") { performVerify() }
                        .disabled(contentInput.isEmpty || isVerifying)
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, theme.spacingM)

            if isVerifying {
                ProgressView("Verifying...")
            }

            if let err = errorMsg {
                Text(err).foregroundStyle(.red).font(.caption)
                    .padding(.horizontal, theme.spacingM)
            }

            if let res = result {
                verificationResultView(res)
            }

            Spacer()
        }
        .navigationTitle("Verification")
    }

    private func verificationResultView(_ res: [String: Any]) -> some View {
        GroupBox("Result") {
            VStack(alignment: .leading, spacing: theme.spacingS) {
                HStack {
                    Label(
                        (res["passed"] as? Bool == true) ? "Passed" : "Failed",
                        systemImage: (res["passed"] as? Bool == true) ? "checkmark.circle.fill" : "xmark.circle.fill"
                    )
                    .foregroundStyle((res["passed"] as? Bool == true) ? .green : .red)
                    Spacer()
                    if let score = res["score"] as? Double {
                        Text(String(format: "Score: %.2f", score))
                            .font(.caption).foregroundStyle(theme.textTertiary)
                    }
                }

                if let issues = res["issues"] as? [[String: Any]], !issues.isEmpty {
                    Divider()
                    Text("Issues").font(.system(size: theme.smallTextSize, weight: .semibold))
                    ForEach(Array(issues.enumerated()), id: \.offset) { _, issue in
                        HStack(spacing: theme.spacingS) {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                            Text(issue["message"] as? String ?? "")
                                .font(.system(size: theme.smallTextSize))
                        }
                    }
                }

                if let fixed = res["fixed_content"] as? String, !fixed.isEmpty {
                    Divider()
                    Text("Fixed Content").font(.system(size: theme.smallTextSize, weight: .semibold))
                    ScrollView {
                        Text(fixed)
                            .font(.system(size: theme.smallTextSize, design: .monospaced))
                            .foregroundStyle(theme.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 200)
                }
            }
        }
        .padding(.horizontal, theme.spacingM)
    }

    private func performVerify() {
        isVerifying = true
        errorMsg = nil
        result = nil
        let criteria = criteriaInput
            .split(separator: ",")
            .map { String($0.trimmingCharacters(in: .whitespaces)) }
            .filter { !$0.isEmpty }
        Task {
            do {
                let res = try await bridge.ipcClient!.verifyVerify(
                    content: contentInput, criteria: criteria, autoFix: autoFix
                )
                result = res
                logger.info("Verification complete: passed=\(res["passed"] as? Bool ?? false)")
            } catch {
                errorMsg = error.localizedDescription
                logger.error("verifyVerify failed: \(error.localizedDescription)")
            }
            isVerifying = false
        }
    }
}
