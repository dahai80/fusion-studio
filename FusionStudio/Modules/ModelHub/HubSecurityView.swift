import SwiftUI
import os.log

struct HubSecurityView: View {
    @ObservedObject var client: ModelHubAPIClient
    @Environment(\.studioTheme) private var theme
    @State private var selectedTab = 0
    @State private var scanResult: HubSecurityScanResponse?
    @State private var watermarkInfo: HubWatermarkResponse?
    @State private var encryptionInfo: HubEncryptionResponse?
    @State private var approvals: [HubApproval] = []
    @State private var loading = false
    @State private var lastError: String?
    @State private var showScanSheet = false
    @State private var showWatermarkSheet = false
    @State private var showEncryptionSheet = false
    @State private var selectedApproval: HubApproval?

    private let secLog = Logger(subsystem: "com.fusion.studio", category: "HubSecurity")

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            tabContent
        }
        .onAppear { loadAll() }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            secTabItem("安全扫描", index: 0, icon: "shield.checkered")
            secTabItem("水印管理", index: 1, icon: "drop.fill")
            secTabItem("加密管理", index: 2, icon: "lock.shield")
            secTabItem("审批流程", index: 3, icon: "checkmark.seal")
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.top, theme.spacingS)
    }

    private func secTabItem(_ title: String, index: Int, icon: String) -> some View {
        Button(action: { selectedTab = index }) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11))
                Text(title).font(.system(size: theme.footnoteSize, weight: selectedTab == index ? .semibold : .regular))
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(selectedTab == index ? theme.accent.opacity(0.12) : Color.clear)
            .foregroundStyle(selectedTab == index ? theme.accent : theme.textSecondary)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case 0: scanTab
        case 1: watermarkTab
        case 2: encryptionTab
        case 3: approvalTab
        default: EmptyView()
        }
    }

    // MARK: - Scan Tab

    private var scanTab: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            HStack {
                Text("安全扫描")
                    .font(.system(size: theme.titleSize, weight: .bold)).foregroundStyle(theme.text)
                Spacer()
                Button("扫描模型") { showScanSheet = true }
                    .buttonStyle(.borderedProminent).controlSize(.small)
                Button("刷新") { loadScanResult() }
                    .buttonStyle(.bordered).controlSize(.small)
            }
            if loading { ProgressView().padding() }
            else if let result = scanResult { scanResultView(result) }
            else { secEmpty("shield.checkered", "尚未进行安全扫描") }
        }
        .padding(theme.spacingL)
        .sheet(isPresented: $showScanSheet) { scanModelSheet }
    }

    private func scanResultView(_ result: HubSecurityScanResponse) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            HStack(spacing: theme.spacingM) {
                secScoreCard(result)
                secIssueSummary(result)
            }
            if let issues = result.issues, !issues.isEmpty {
                VStack(alignment: .leading, spacing: theme.spacingS) {
                    Text("发现问题")
                        .font(.system(size: theme.textSize, weight: .semibold)).foregroundStyle(theme.text)
                    ForEach(issues) { issue in secIssueRow(issue) }
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("未发现安全问题").foregroundStyle(theme.textSecondary)
                }
                .padding(theme.spacingS).frame(maxWidth: .infinity)
                .background(Color.green.opacity(0.06)).cornerRadius(8)
            }
        }
    }

    private func secScoreCard(_ result: HubSecurityScanResponse) -> some View {
        let issues = result.issues ?? []
        let critical = issues.filter { $0.severity == "critical" }.count
        let high = issues.filter { $0.severity == "high" }.count
        let score = max(0, 100 - critical * 25 - high * 10 - issues.filter { $0.severity == "medium" }.count * 5)
        return VStack(spacing: 8) {
            ZStack {
                Circle().stroke(Color.gray.opacity(0.2), lineWidth: 6).frame(width: 80, height: 80)
                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100.0)
                    .stroke(secScoreColor(score), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 80, height: 80).rotationEffect(.degrees(-90))
                Text("\(score)")
                    .font(.system(size: 24, weight: .bold)).foregroundStyle(theme.text)
            }
            Text("安全评分").font(.system(size: theme.footnoteSize)).foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity).padding(theme.spacingM)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3)).cornerRadius(8)
    }

    private func secIssueSummary(_ result: HubSecurityScanResponse) -> some View {
        let issues = result.issues ?? []
        return VStack(spacing: 8) {
            Text("问题汇总").font(.system(size: theme.footnoteSize, weight: .medium)).foregroundStyle(theme.textSecondary)
            HStack(spacing: theme.spacingM) {
                secIssueCount("严重", count: issues.filter { $0.severity == "critical" }.count, color: .red)
                secIssueCount("高危", count: issues.filter { $0.severity == "high" }.count, color: .orange)
                secIssueCount("中危", count: issues.filter { $0.severity == "medium" }.count, color: .yellow)
                secIssueCount("低危", count: issues.filter { $0.severity == "low" }.count, color: .blue)
            }
        }
        .frame(maxWidth: .infinity).padding(theme.spacingM)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3)).cornerRadius(8)
    }

    private func secIssueCount(_ label: String, count: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)").font(.system(size: 20, weight: .bold)).foregroundStyle(color)
            Text(label).font(.system(size: 9)).foregroundStyle(theme.textSecondary)
        }
    }

    private func secIssueRow(_ issue: HubSecurityIssue) -> some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: secSeverityIcon(issue.severity))
                .foregroundStyle(secSeverityColor(issue.severity)).font(.system(size: 14))
            VStack(alignment: .leading, spacing: 2) {
                Text(issue.type ?? "未知问题").font(.system(size: theme.textSize, weight: .medium)).foregroundStyle(theme.text)
                if let desc = issue.description {
                    Text(desc).font(.system(size: theme.footnoteSize)).foregroundStyle(theme.textSecondary).lineLimit(2)
                }
            }
            Spacer()
            Text(issue.severity?.uppercased() ?? "")
                .font(.system(size: 9, weight: .medium))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Capsule().fill(secSeverityColor(issue.severity).opacity(0.15)))
                .foregroundStyle(secSeverityColor(issue.severity))
        }
        .padding(theme.spacingS)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.2)).cornerRadius(6)
    }

    private var scanModelSheet: some View {
        VStack(spacing: theme.spacingM) {
            Text("扫描模型安全").font(.title2).bold()
            Text("将对指定模型进行安全漏洞扫描").font(.caption).foregroundStyle(theme.textSecondary)
            SecScanForm(client: client, isPresented: $showScanSheet) { scanResult = $0 }
        }
        .padding().frame(width: 400, height: 300)
    }

    // MARK: - Watermark Tab

    private var watermarkTab: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            HStack {
                Text("水印管理")
                    .font(.system(size: theme.titleSize, weight: .bold)).foregroundStyle(theme.text)
                Spacer()
                Button("添加水印") { showWatermarkSheet = true }
                    .buttonStyle(.borderedProminent).controlSize(.small)
                Button("刷新") { loadWatermark() }
                    .buttonStyle(.bordered).controlSize(.small)
            }
            if loading { ProgressView().padding() }
            else if let info = watermarkInfo {
                VStack(alignment: .leading, spacing: theme.spacingS) {
                    secConfigRow("模型ID", value: info.modelId ?? "--")
                    secConfigRow("水印状态", value: info.status ?? "--")
                    secConfigRow("水印ID", value: info.watermarkId ?? "--")
                    secConfigRow("验证状态", value: info.verified == true ? "已验证" : "未验证")
                    secConfigRow("嵌入时间", value: info.embeddedAt ?? "--")
                }
                .padding(theme.spacingS)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.3)).cornerRadius(8)
            } else { secEmpty("drop.fill", "暂无水印信息") }
        }
        .padding(theme.spacingL)
        .sheet(isPresented: $showWatermarkSheet) {
            VStack(spacing: theme.spacingM) {
                Text("添加水印").font(.title2).bold()
                Text("为模型添加数字水印以保护知识产权").font(.caption).foregroundStyle(theme.textSecondary)
                SecWatermarkForm(client: client, isPresented: $showWatermarkSheet) { loadWatermark() }
            }
            .padding().frame(width: 400, height: 300)
        }
    }

    // MARK: - Encryption Tab

    private var encryptionTab: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            HStack {
                Text("加密管理")
                    .font(.system(size: theme.titleSize, weight: .bold)).foregroundStyle(theme.text)
                Spacer()
                Button("加密模型") { showEncryptionSheet = true }
                    .buttonStyle(.borderedProminent).controlSize(.small)
                Button("刷新") { loadEncryption() }
                    .buttonStyle(.bordered).controlSize(.small)
            }
            if loading { ProgressView().padding() }
            else if let info = encryptionInfo {
                VStack(alignment: .leading, spacing: theme.spacingS) {
                    secConfigRow("模型ID", value: info.modelId ?? "--")
                    secConfigRow("加密状态", value: info.status ?? "--")
                    secConfigRow("加密算法", value: info.algorithm ?? "--")
                    secConfigRow("加密时间", value: info.encryptedAt ?? "--")
                }
                .padding(theme.spacingS)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.3)).cornerRadius(8)
            } else { secEmpty("lock.shield", "暂无加密信息") }
        }
        .padding(theme.spacingL)
        .sheet(isPresented: $showEncryptionSheet) {
            VStack(spacing: theme.spacingM) {
                Text("加密模型").font(.title2).bold()
                Text("对模型权重进行加密保护").font(.caption).foregroundStyle(theme.textSecondary)
                SecEncryptForm(client: client, isPresented: $showEncryptionSheet) { loadEncryption() }
            }
            .padding().frame(width: 400, height: 300)
        }
    }

    // MARK: - Approval Tab

    private var approvalTab: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            HStack {
                Text("审批流程")
                    .font(.system(size: theme.titleSize, weight: .bold)).foregroundStyle(theme.text)
                Spacer()
                Button("刷新") { loadApprovals() }
                    .buttonStyle(.bordered).controlSize(.small)
            }
            if loading { ProgressView().padding() }
            else if approvals.isEmpty { secEmpty("checkmark.seal", "暂无审批记录") }
            else {
                List(approvals, id: \.id) { a in
                    HStack(spacing: theme.spacingS) {
                        Image(systemName: secApprovalIcon(a.status))
                            .foregroundStyle(secApprovalColor(a.status)).font(.system(size: 14))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(a.modelName ?? a.modelId ?? "未知")
                                .font(.system(size: theme.textSize, weight: .medium)).foregroundStyle(theme.text)
                            HStack(spacing: 8) {
                                if let t = a.operation { Text(t).font(.caption).foregroundStyle(.secondary) }
                                if let r = a.requestedBy { Text("申请人: \(r)").font(.caption).foregroundStyle(.secondary) }
                            }
                        }
                        Spacer()
                        Text(a.status ?? "")
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(secApprovalColor(a.status).opacity(0.15)))
                            .foregroundStyle(secApprovalColor(a.status))
                    }
                    .padding(.vertical, 4)
                    .onTapGesture { selectedApproval = a }
                }
                .listStyle(.sidebar)
            }
        }
        .padding(theme.spacingL)
        .sheet(item: $selectedApproval) { a in
            SecApprovalReviewSheet(client: client, approval: a) { loadApprovals() }
        }
    }

    // MARK: - Helpers

    private func secEmpty(_ icon: String, _ msg: String) -> some View {
        VStack(spacing: theme.spacingS) {
            Image(systemName: icon).font(.system(size: 32)).foregroundStyle(theme.textTertiary)
            Text(msg).font(.system(size: theme.textSize)).foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func secConfigRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).font(.system(size: theme.footnoteSize)).foregroundStyle(theme.textSecondary)
            Spacer()
            Text(value).font(.system(size: theme.footnoteSize)).foregroundStyle(theme.text)
        }
    }

    private func secScoreColor(_ score: Int) -> Color {
        if score >= 80 { return .green }; if score >= 60 { return .yellow }
        if score >= 40 { return .orange }; return .red
    }

    private func secSeverityIcon(_ s: String?) -> String {
        switch s {
        case "critical": return "xmark.octagon.fill"
        case "high": return "exclamationmark.triangle.fill"
        case "medium": return "exclamationmark.circle.fill"
        case "low": return "info.circle.fill"
        default: return "questionmark.circle"
        }
    }

    private func secSeverityColor(_ s: String?) -> Color {
        switch s { case "critical": .red; case "high": .orange; case "medium": .yellow; case "low": .blue; default: .secondary }
    }

    private func secApprovalIcon(_ s: String?) -> String {
        switch s { case "pending": "clock"; case "approved": "checkmark.circle.fill"; case "rejected": "xmark.circle.fill"; default: "questionmark.circle" }
    }

    private func secApprovalColor(_ s: String?) -> Color {
        switch s { case "pending": .orange; case "approved": .green; case "rejected": .red; default: .secondary }
    }

    private func loadAll() { loadScanResult(); loadWatermark(); loadEncryption(); loadApprovals() }

    private func loadScanResult() {
        loading = true
        Task { @MainActor in
            do { scanResult = try await client.getSecurityScanResult(modelId: ""); secLog.info("Scan loaded") }
            catch { secLog.warning("Scan failed: \(error.localizedDescription)") }
            loading = false
        }
    }

    private func loadWatermark() {
        Task { @MainActor in
            do { watermarkInfo = try await client.verifyWatermark(modelId: ""); secLog.info("Watermark loaded") }
            catch { secLog.warning("Watermark failed: \(error.localizedDescription)") }
        }
    }

    private func loadEncryption() {
        Task { @MainActor in
            do { encryptionInfo = try await client.getEncryptionStatus(modelId: ""); secLog.info("Encryption loaded") }
            catch { secLog.warning("Encryption failed: \(error.localizedDescription)") }
        }
    }

    private func loadApprovals() {
        Task { @MainActor in
            do {
                let resp = try await client.listApprovals()
                approvals = resp.approvals
                secLog.info("Loaded \(approvals.count) approvals")
            } catch { secLog.warning("Approvals failed: \(error.localizedDescription)") }
        }
    }
}

// MARK: - Sub Forms

private struct SecScanForm: View {
    @ObservedObject var client: ModelHubAPIClient
    @Binding var isPresented: Bool
    let onResult: (HubSecurityScanResponse) -> Void
    @State private var modelId = ""
    @State private var error: String?
    @Environment(\.studioTheme) private var theme

    var body: some View {
        VStack(spacing: theme.spacingM) {
            TextField("模型ID", text: $modelId).textFieldStyle(.roundedBorder)
            if let err = error { Text(err).font(.caption).foregroundStyle(.red) }
            HStack {
                Button("取消") { isPresented = false }.buttonStyle(.bordered)
                Button("开始扫描") { run() }.buttonStyle(.borderedProminent).disabled(modelId.isEmpty)
            }
        }
    }
    private func run() {
        Task { @MainActor in
            do { let r = try await client.triggerSecurityScan(modelId: modelId); onResult(r); isPresented = false }
            catch { self.error = error.localizedDescription }
        }
    }
}

private struct SecWatermarkForm: View {
    @ObservedObject var client: ModelHubAPIClient
    @Binding var isPresented: Bool
    let onAdded: () -> Void
    @State private var modelId = ""
    @State private var watermarkText = ""
    @State private var error: String?
    @Environment(\.studioTheme) private var theme

    var body: some View {
        VStack(spacing: theme.spacingM) {
            TextField("模型ID", text: $modelId).textFieldStyle(.roundedBorder)
            TextField("水印文本", text: $watermarkText).textFieldStyle(.roundedBorder)
            if let err = error { Text(err).font(.caption).foregroundStyle(.red) }
            HStack {
                Button("取消") { isPresented = false }.buttonStyle(.bordered)
                Button("添加") { add() }.buttonStyle(.borderedProminent).disabled(modelId.isEmpty)
            }
        }
    }
    private func add() {
        Task { @MainActor in
            do {
                _ = try await client.embedWatermark(modelId: modelId, text: watermarkText.isEmpty ? nil : watermarkText)
                isPresented = false; onAdded()
            } catch { self.error = error.localizedDescription }
        }
    }
}

private struct SecEncryptForm: View {
    @ObservedObject var client: ModelHubAPIClient
    @Binding var isPresented: Bool
    let onDone: () -> Void
    @State private var modelId = ""
    @State private var algorithm = "AES-256"
    @State private var error: String?
    @Environment(\.studioTheme) private var theme

    var body: some View {
        VStack(spacing: theme.spacingM) {
            TextField("模型ID", text: $modelId).textFieldStyle(.roundedBorder)
            Picker("加密算法", selection: $algorithm) {
                Text("AES-256").tag("AES-256"); Text("ChaCha20").tag("ChaCha20"); Text("RSA-4096").tag("RSA-4096")
            }
            if let err = error { Text(err).font(.caption).foregroundStyle(.red) }
            HStack {
                Button("取消") { isPresented = false }.buttonStyle(.bordered)
                Button("加密") { enc() }.buttonStyle(.borderedProminent).disabled(modelId.isEmpty)
            }
        }
    }
    private func enc() {
        Task { @MainActor in
            do { _ = try await client.encryptModel(modelId: modelId, algorithm: algorithm); isPresented = false; onDone() }
            catch { self.error = error.localizedDescription }
        }
    }
}

private struct SecApprovalReviewSheet: View {
    @ObservedObject var client: ModelHubAPIClient
    let approval: HubApproval
    let onDone: () -> Void
    @State private var comment = ""
    @State private var error: String?
    @Environment(\.studioTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: theme.spacingM) {
            Text("审批详情").font(.title2).bold()
            VStack(alignment: .leading, spacing: 4) {
                Text("模型: \(approval.modelName ?? approval.modelId ?? "--")").font(.system(size: theme.textSize))
                Text("类型: \(approval.operation ?? "--")").font(.caption).foregroundStyle(.secondary)
                Text("申请人: \(approval.requestedBy ?? "--")").font(.caption).foregroundStyle(.secondary)
                Text("状态: \(approval.status ?? "--")").font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            TextField("审批意见", text: $comment).textFieldStyle(.roundedBorder)
            if let err = error { Text(err).font(.caption).foregroundStyle(.red) }
            HStack {
                Button("拒绝") { review(approved: false) }.buttonStyle(.bordered).foregroundStyle(.red)
                Button("通过") { review(approved: true) }.buttonStyle(.borderedProminent)
            }
        }
        .padding().frame(width: 400, height: 320)
    }
    private func review(approved: Bool) {
        Task { @MainActor in
            do {
                if approved {
                    _ = try await client.approveRequest(id: approval.id, comment: comment.isEmpty ? nil : comment)
                } else {
                    _ = try await client.rejectRequest(id: approval.id, comment: comment.isEmpty ? nil : comment)
                }
                dismiss(); onDone()
            } catch { self.error = error.localizedDescription }
        }
    }
}
