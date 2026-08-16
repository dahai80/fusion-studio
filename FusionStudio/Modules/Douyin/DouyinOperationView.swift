// Callers: SectionContentView (.douyinOperation section), FusionStudioApp (@StateObject injection).
// Affected API: DouyinOperationView - 抖音运营看板 GUI（库存/造片/发布/评论/进化/统计），IPC 调 agent-studio graph.execute。
// Data schemas: DouyinOperationBridge @Published state (queueCounts/pendingItems/publishedItems/winning/statsSnapshots/lastRunResult)。
// User instruction: "fusion-operation 最多做一些 GUI 页面" + ~/operation/reconstruct-operation.md Phase 4。

import SwiftUI
import os.log

private let douyinViewLog = Logger(subsystem: "com.fusion.studio", category: "DouyinOperationView")

struct DouyinOperationView: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var bridge: DouyinOperationBridge
    @EnvironmentObject var ipc: IPCClient
    @EnvironmentObject var upstream: UpstreamServiceManager

    @State private var selectedTab = 0
    @State private var produceTopic = ""
    @State private var produceVariant = "A"
    @State private var publishDryRun = true
    @State private var planExpression = "5 12,19 * * *"
    @State private var planDryRun = true

    private let variants = ["A", "B", "C"]
    // 钩子变体说明, 与 mlx_script.py VARIANT_HOOK 同源. 用户选择时知道每个变体代表什么钩子风格.
    private let variantHints: [String: String] = [
        "A": "数字+反常：首句用一个极端数字搭配反常识结论",
        "B": "提问+代入：首句用第二人称提问把观众代入场景",
        "C": "悬念+冲突：首句抛出一个待解的悬念冲突",
    ]
    private let tabs = [
        FusionTabItem(title: "库存", icon: "shippingbox"),
        FusionTabItem(title: "造片", icon: "film.stack"),
        FusionTabItem(title: "发布", icon: "paperplane"),
        FusionTabItem(title: "计划", icon: "clock.badge"),
        FusionTabItem(title: "评论", icon: "bubble.left.and.bubble.right"),
        FusionTabItem(title: "进化", icon: "chart.line.uptrend.xyaxis"),
        FusionTabItem(title: "统计", icon: "chart.bar"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            UpstreamServiceStatusBanner(serviceId: "agent-studio")
            Rectangle().fill(theme.separator).frame(height: 1)

            queueOverviewBar

            Rectangle().fill(theme.separator).frame(height: 1)
            FusionTabBar(selected: $selectedTab, tabs: tabs)
            Rectangle().fill(theme.separator).frame(height: 1)

            ScrollView(showsIndicators: false) {
                Group {
                    switch selectedTab {
                    case 0: inventoryPanel
                    case 1: producePanel
                    case 2: publishPanel
                    case 3: schedulePanel
                    case 4: commentPanel
                    case 5: evolvePanel
                    default: statsPanel
                    }
                }
                .padding(theme.spacingL)
            }
            .background(theme.contentBg)

            Rectangle().fill(theme.separator).frame(height: 1)
            actionBar
        }
        .background(theme.contentBg)
        .onAppear {
            bridge.refreshAll()
            bridge.refreshCron(ipc: ipc)
            bridge.startPolling(interval: 30)
            douyinViewLog.info("DouyinOperationView appeared")
        }
        .onDisappear {
            bridge.stopPolling()
        }
    }

    // MARK: - 库存概览条

    private var queueOverviewBar: some View {
        HStack(spacing: theme.spacingM) {
            queueBadge("待发布", count: bridge.queueCounts.pending, color: theme.amberDot, icon: "tray")
            queueBadge("已发布", count: bridge.queueCounts.published, color: theme.greenDot, icon: "checkmark.circle")
            queueBadge("失败", count: bridge.queueCounts.failed, color: theme.redDot, icon: "exclamationmark.triangle")
            Spacer()
            if let err = bridge.lastError {
                Text(err).font(.system(size: 11)).foregroundStyle(theme.accentDestructive).lineLimit(1).help(err)
            }
            Button {
                bridge.refreshAll()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless).help("刷新数据")
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingS)
        .background(theme.surfaceSecondary)
    }

    private func queueBadge(_ label: String, count: Int, color: Color, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(color).font(.system(size: 12))
            Text(label).font(.system(size: 12)).foregroundStyle(theme.textSecondary)
            Text("\(count)").font(.system(size: 14, weight: .semibold)).foregroundStyle(theme.text)
        }
    }

    // MARK: - 库存面板

    private var inventoryPanel: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            sectionLabel("待发布队列", icon: "tray.fill")
            if bridge.pendingItems.isEmpty {
                emptyHint("暂无待发布视频，去「造片」补充库存")
            } else {
                ForEach(bridge.pendingItems) { item in
                    queueItemRow(item)
                }
            }

            sectionLabel("已发布（最近 20 条）", icon: "checkmark.circle.fill")
            if bridge.publishedItems.isEmpty {
                emptyHint("暂无已发布视频")
            } else {
                ForEach(bridge.publishedItems) { item in
                    queueItemRow(item)
                }
            }

            if !bridge.failedItems.isEmpty {
                sectionLabel("失败队列", icon: "exclamationmark.triangle.fill")
                ForEach(bridge.failedItems) { item in
                    queueItemRow(item)
                }
            }
        }
    }

    private func queueItemRow(_ item: DouyinQueueItem) -> some View {
        HStack(alignment: .top, spacing: theme.spacingS) {
            Image(systemName: item.hasVideo ? "video.fill" : "video.slash")
                .foregroundStyle(item.hasVideo ? theme.accent : theme.textTertiary)
                .font(.system(size: 12))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.system(size: 13, weight: .medium)).foregroundStyle(theme.text).lineLimit(2)
                HStack(spacing: 8) {
                    Text("variant \(item.hookVariant)").font(.system(size: 10)).foregroundStyle(theme.accent)
                    Text(item.status).font(.system(size: 10)).foregroundStyle(theme.textTertiary)
                }
            }
            Spacer()
        }
        .padding(theme.spacingS)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surfaceSecondary)
        .cornerRadius(6)
    }

    // MARK: - 造片面板（Graph C）

    private var producePanel: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            sectionLabel("一键造片", icon: "film.stack.fill")
            Text("调 agent-studio 跑 Graph C（script→img→tts→compose→enqueue），单轮造 1 条入待发布队列。")
                .font(.system(size: theme.footnoteSize)).foregroundStyle(theme.textSecondary)

            VStack(alignment: .leading, spacing: theme.spacingS) {
                Text("选题（留空则自动 topic_gen）").font(.system(size: 11)).foregroundStyle(theme.textSecondary)
                TextField("如：如果你掉进黑洞会发生什么", text: $produceTopic)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: theme.footnoteSize))
            }

            HStack(spacing: theme.spacingS) {
                Text("钩子变体").font(.system(size: 11)).foregroundStyle(theme.textSecondary)
                Picker("Variant", selection: $produceVariant) {
                    ForEach(variants, id: \.self) { Text($0).tag($0) }
                }.pickerStyle(.segmented).frame(width: 200)
            }
            VStack(alignment: .leading, spacing: 2) {
                ForEach(variants, id: \.self) { v in
                    Text("\(v)：\(variantHints[v] ?? "")")
                        .font(.system(size: 11))
                        .foregroundStyle(produceVariant == v ? theme.accent : theme.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            FusionButton("开始造片", icon: "wand.and.stars", style: .primary, size: .small,
                         isLoading: bridge.isLoading && bridge.runningAction.hasPrefix("造片")) {
                bridge.produceOne(topic: produceTopic, hookVariant: produceVariant, ipc: ipc)
            }

            if let r = bridge.lastRunResult, bridge.runningAction.isEmpty {
                runResultRow(r)
            }
        }
    }

    // MARK: - 发布面板（Graph D）

    private var publishPanel: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            sectionLabel("库存发布", icon: "paperplane.fill")
            Text("调 agent-studio 跑 Graph D（dequeue→gate_stock→publish→archive），从待发布队列取 1 条发布。")
                .font(.system(size: theme.footnoteSize)).foregroundStyle(theme.textSecondary)

            Toggle("Dry-run（不真实发布，停在发布前）", isOn: $publishDryRun)
                .font(.system(size: theme.footnoteSize))

            HStack(spacing: theme.spacingS) {
                FusionButton(publishDryRun ? "Dry-run 发布" : "真实发布",
                             icon: publishDryRun ? "eye" : "paperplane",
                             style: publishDryRun ? .secondary : .primary, size: .small,
                             isLoading: bridge.isLoading && bridge.runningAction.hasPrefix("发布")) {
                    bridge.publishFromQueue(dryRun: publishDryRun, ipc: ipc)
                }
            }

            if !publishDryRun {
                Text("⚠️ 真实发布会上传视频到抖音账号，请确认库存与登录态。")
                    .font(.system(size: 11)).foregroundStyle(theme.accentDestructive)
            }
            if let r = bridge.lastRunResult, bridge.runningAction.isEmpty {
                runResultRow(r)
            }
        }
    }

    // MARK: - 发布计划面板（cron 调度，高峰时段自动发布）

    private var schedulePanel: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            sectionLabel("高峰时段发布计划", icon: "clock.badge.fill")
            Text("注册 cron 计划，每天高峰窗口（12-13 / 19-21）自动跑 Graph D 从库存取片发布，无需人工点按钮。底层为 agent-studio cron 运行时（PR #140）。")
                .font(.system(size: theme.footnoteSize)).foregroundStyle(theme.textSecondary)

            VStack(alignment: .leading, spacing: theme.spacingS) {
                Text("Cron 表达式（分 时 日 月 周）").font(.system(size: 11)).foregroundStyle(theme.textSecondary)
                TextField("5 12,19 * * *", text: $planExpression)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: theme.footnoteSize, design: .monospaced))
                Text("默认 `5 12,19 * * *` = 每天 12:05 与 19:05 各触发一次（高峰窗口开场后 5 分钟）。")
                    .font(.system(size: 10)).foregroundStyle(theme.textTertiary)
            }

            Toggle("Dry-run（不真实发布，验证计划触发）", isOn: $planDryRun)
                .font(.system(size: theme.footnoteSize))
            if !planDryRun {
                Text("⚠️ 真实计划会在高峰时段自动上传视频到抖音，请确认库存与登录态。")
                    .font(.system(size: 11)).foregroundStyle(theme.accentDestructive)
            }

            HStack(spacing: theme.spacingS) {
                FusionButton("注册发布计划", icon: "clock.badge.plus", style: .primary, size: .small,
                             isLoading: bridge.cronLoading) {
                    bridge.registerPublishPlan(expression: planExpression, dryRun: planDryRun, ipc: ipc)
                }
                if !bridge.cronJobs.isEmpty {
                    FusionButton("刷新", icon: "arrow.clockwise", style: .secondary, size: .small) {
                        bridge.refreshCron(ipc: ipc)
                    }
                }
            }

            if let r = bridge.lastRunResult, bridge.runningAction.isEmpty, r.status == "registered" || r.status == "failed" {
                runResultRow(r)
            }

            if bridge.cronJobs.isEmpty {
                emptyHint("暂无发布计划，注册后将在此显示下次触发时间与执行历史")
            } else {
                sectionLabel("已注册计划", icon: "clock.fill")
                ForEach(bridge.cronJobs) { job in
                    cronJobRow(job)
                }

                if !bridge.cronExecutions.isEmpty {
                    sectionLabel("执行历史", icon: "list.bullet.rectangle")
                    ForEach(bridge.cronExecutions) { exe in
                        cronExecutionRow(exe)
                    }
                }
            }
        }
    }

    private func cronJobRow(_ job: DouyinCronJob) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Circle().fill(job.enabled ? theme.greenDot : theme.textTertiary).frame(width: 6, height: 6)
                Text(job.name).font(.system(size: 13, weight: .medium)).foregroundStyle(theme.text)
                Spacer()
                Text(job.expression).font(.system(size: 11, design: .monospaced)).foregroundStyle(theme.accent)
            }
            HStack(spacing: 8) {
                if job.nextRun > 0 {
                    Label("下次: \(formatEpoch(job.nextRun))", systemImage: "arrow.clockwise")
                }
                if job.lastRun > 0 {
                    Label("上次: \(formatEpoch(job.lastRun))", systemImage: "checkmark")
                }
            }.font(.system(size: 10)).foregroundStyle(theme.textTertiary)
            if !job.inputData.isEmpty {
                Text("参数: \(job.inputData)").font(.system(size: 10, design: .monospaced)).foregroundStyle(theme.textTertiary)
            }
            FusionButton("取消计划", icon: "trash", style: .secondary, size: .small,
                         isLoading: bridge.cronLoading) {
                bridge.unregisterPlan(jobId: job.id, ipc: ipc)
            }
        }
        .padding(theme.spacingS)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surfaceSecondary)
        .cornerRadius(6)
    }

    private func cronExecutionRow(_ exe: DouyinCronExecution) -> some View {
        let statusColor = exe.status == "success" ? theme.greenDot : (exe.status == "failed" ? theme.redDot : theme.amberDot)
        return HStack(alignment: .top, spacing: theme.spacingS) {
            Circle().fill(statusColor).frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(exe.status).font(.system(size: 11, weight: .semibold)).foregroundStyle(theme.text)
                    Text(formatEpoch(exe.startedAt)).font(.system(size: 10)).foregroundStyle(theme.textTertiary)
                }
                if !exe.resultPreview.isEmpty {
                    Text(exe.resultPreview).font(.system(size: 10, design: .monospaced)).foregroundStyle(theme.textSecondary).lineLimit(2)
                }
                if !exe.error.isEmpty {
                    Text(exe.error).font(.system(size: 10)).foregroundStyle(theme.accentDestructive).lineLimit(2)
                }
            }
            Spacer()
        }
        .padding(theme.spacingS)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surfaceSecondary)
        .cornerRadius(6)
    }

    private func formatEpoch(_ ts: Double) -> String {
        guard ts > 0 else { return "—" }
        let date = Date(timeIntervalSince1970: ts)
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f.string(from: date)
    }

    // MARK: - 评论面板（Graph B）

    private var commentPanel: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            sectionLabel("评论回复", icon: "bubble.left.and.bubble.right.fill")
            Text("调 agent-studio 跑 Graph B（fetch→gate→draft→reply），抓取新评论并批量回复，幂等。")
                .font(.system(size: theme.footnoteSize)).foregroundStyle(theme.textSecondary)

            FusionButton("开始评论回复", icon: "text.bubble", style: .primary, size: .small,
                         isLoading: bridge.isLoading && bridge.runningAction == "评论回复") {
                bridge.replyComments(ipc: ipc)
            }

            if !bridge.repliedIds.isEmpty {
                sectionLabel("已回复评论 ID", icon: "checkmark.bubble")
                ForEach(bridge.repliedIds, id: \.self) { id in
                    Text(id).font(.system(size: 11, design: .monospaced)).foregroundStyle(theme.textSecondary)
                }
            }
            if let r = bridge.lastRunResult, bridge.runningAction.isEmpty {
                runResultRow(r)
            }
        }
    }

    // MARK: - 进化面板（Graph E + F）

    private var evolvePanel: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            sectionLabel("进化分析", icon: "chart.line.uptrend.xyaxis")
            Text("调 agent-studio 跑 Graph E（snapshot→rank→analyze→repair_scan），更新爆款模式与差片扫描。")
                .font(.system(size: theme.footnoteSize)).foregroundStyle(theme.textSecondary)

            FusionButton("运行进化闭环", icon: "arrow.triangle.2.circlepath", style: .primary, size: .small,
                         isLoading: bridge.isLoading && bridge.runningAction == "进化分析") {
                bridge.evolve(ipc: ipc)
            }

            sectionLabel("差片修复重发", icon: "wrench.adjustable")
            Text("调 agent-studio 跑 Graph F（scan→gate→retitle），对差片换标题重入队列。")
                .font(.system(size: theme.footnoteSize)).foregroundStyle(theme.textSecondary)
            FusionButton("扫描并修复", icon: "wrench.and.screwdriver", style: .secondary, size: .small,
                         isLoading: bridge.isLoading && bridge.runningAction == "差片修复") {
                bridge.repairPublish(ipc: ipc)
            }

            if let r = bridge.lastRunResult, bridge.runningAction.isEmpty {
                runResultRow(r)
            }

            winningPatternsSection
        }
    }

    private var winningPatternsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            sectionLabel("爆款模式（winning_patterns）", icon: "flame.fill")
            Text("样本 \(bridge.winning.samples) · 爆款 \(bridge.winning.hotCount) · 更新于 \(bridge.winning.updatedAt)")
                .font(.system(size: 11)).foregroundStyle(theme.textTertiary)

            if !bridge.winning.titleFormula.isEmpty {
                patternRow("标题公式", bridge.winning.titleFormula)
            }
            ForEach(Array(bridge.winning.winningTopics.enumerated()), id: \.offset) { _, t in
                patternRow("✅ 爆款选题", t)
            }
            ForEach(Array(bridge.winning.winningHooks.enumerated()), id: \.offset) { _, t in
                patternRow("✅ 爆款钩子", t)
            }
            ForEach(Array(bridge.winning.losingPatterns.enumerated()), id: \.offset) { _, t in
                patternRow("❌ 失败模式", t)
            }
        }
    }

    private func patternRow(_ tag: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: theme.spacingS) {
            Text(tag).font(.system(size: 10, weight: .semibold)).foregroundStyle(theme.accent)
            Text(text).font(.system(size: 11)).foregroundStyle(theme.textSecondary).lineLimit(3)
            Spacer()
        }
        .padding(theme.spacingS)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surfaceSecondary)
        .cornerRadius(6)
    }

    // MARK: - 统计面板

    private var statsPanel: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            // ---- 第一部分：全貌摘要 ----
            sectionLabel("统计报表 · 全貌", icon: "chart.bar.fill")
            Text("账号整体表现概览：汇总指标 + 表现分布 + 钩子变体对比。")
                .font(.system(size: 11)).foregroundStyle(theme.textTertiary)

            if bridge.statsSnapshots.isEmpty {
                emptyHint("暂无统计快照，先运行「进化分析」抓取 snapshot")
            } else {
                statsSummary
                statsVariantDistribution
            }

            // ---- 第二部分：逐视频细节排行 ----
            if !bridge.statsSnapshots.isEmpty {
                sectionLabel("逐视频细节（按播放降序，优秀在前）", icon: "list.number")
                ForEach(Array(bridge.statsSnapshots.prefix(20))) { snap in
                    statsRow(snap)
                }
            }
        }
    }

    private var statsSummary: some View {
        let snaps = bridge.statsSnapshots
        let totalPlays = snaps.reduce(0) { $0 + $1.plays }
        let totalLikes = snaps.reduce(0) { $0 + $1.likes }
        let totalComments = snaps.reduce(0) { $0 + $1.comments }
        let totalShares = snaps.reduce(0) { $0 + $1.shares }
        let avgPlays = snaps.isEmpty ? 0 : Double(totalPlays) / Double(snaps.count)
        let avgIR = snaps.isEmpty ? 0 : snaps.reduce(0) { $0 + $1.interactionRate } / Double(snaps.count)
        let hot = snaps.filter { $0.stage == "hot" }.count
        let cold = snaps.filter { $0.stage == "cold" && $0.plays < 50 }.count
        let mid = snaps.count - hot - cold
        return VStack(alignment: .leading, spacing: theme.spacingS) {
            // 汇总指标卡片
            HStack(spacing: theme.spacingS) {
                statsMetricCard("总播放", "\(totalPlays)", theme.accent)
                statsMetricCard("总点赞", "\(totalLikes)", theme.greenDot)
                statsMetricCard("总评论", "\(totalComments)", theme.textSecondary)
                statsMetricCard("总分享", "\(totalShares)", theme.textSecondary)
            }
            HStack(spacing: theme.spacingS) {
                statsMetricCard("作品数", "\(snaps.count)", theme.text)
                statsMetricCard("均播放", String(format: "%.0f", avgPlays), theme.text)
                statsMetricCard("均互动率", String(format: "%.2f%%", avgIR * 100), theme.accent)
                statsMetricCard("爆款数", "\(hot)", theme.greenDot)
            }
            // 表现分布
            HStack(spacing: theme.spacingM) {
                Label("爆款 \(hot)", systemImage: "flame.fill").foregroundStyle(theme.greenDot)
                Label("平稳 \(mid)", systemImage: "minus.circle").foregroundStyle(theme.textSecondary)
                Label("差片 \(cold)", systemImage: "snowflake").foregroundStyle(theme.amberDot)
            }.font(.system(size: 11))
        }
    }

    private func statsMetricCard(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 16, weight: .semibold)).foregroundStyle(color)
            Text(title).font(.system(size: 10)).foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacingS)
        .background(theme.surfaceSecondary)
        .cornerRadius(6)
    }

    @ViewBuilder
    private var statsVariantDistribution: some View {
        let counts = variantCounts()
        let hasVariant = counts.values.contains { $0 > 0 }
        if hasVariant {
            VStack(alignment: .leading, spacing: theme.spacingXS) {
                Text("钩子变体样本分布").font(.system(size: 11, weight: .medium)).foregroundStyle(theme.textSecondary)
                HStack(spacing: theme.spacingM) {
                    ForEach(["A", "B", "C"], id: \.self) { v in
                        Text("\(v)：\(counts[v] ?? 0) 条")
                            .font(.system(size: 11)).foregroundStyle(theme.textTertiary)
                    }
                }
            }
        }
    }

    private func variantCounts() -> [String: Int] {
        var counts: [String: Int] = ["A": 0, "B": 0, "C": 0]
        for it in bridge.pendingItems + bridge.publishedItems {
            let v = it.hookVariant.isEmpty ? "—" : it.hookVariant
            counts[v, default: 0] += 1
        }
        return counts
    }

    private func statsRow(_ snap: DouyinStatsSnapshot) -> some View {
        let stageColor = snap.stage == "hot" ? theme.greenDot : (snap.plays < 50 ? theme.amberDot : theme.textTertiary)
        return HStack(alignment: .top, spacing: theme.spacingS) {
            VStack(alignment: .leading, spacing: 2) {
                Text(snap.title).font(.system(size: 12, weight: .medium)).foregroundStyle(theme.text).lineLimit(2)
                HStack(spacing: 8) {
                    Text("播放 \(snap.plays)").foregroundStyle(theme.text)
                    Text("赞 \(snap.likes)").foregroundStyle(theme.textSecondary)
                    Text("评 \(snap.comments)").foregroundStyle(theme.textSecondary)
                    Text("转 \(snap.shares)").foregroundStyle(theme.textSecondary)
                    Text(String(format: "互动率 %.2f%%", snap.interactionRate * 100))
                        .foregroundStyle(theme.accent)
                }.font(.system(size: 10))
            }
            Spacer()
            HStack(spacing: 4) {
                Circle().fill(stageColor).frame(width: 6, height: 6)
                Text(snap.stage).font(.system(size: 10)).foregroundStyle(theme.textTertiary)
            }
        }
        .padding(theme.spacingS)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surfaceSecondary)
        .cornerRadius(6)
    }

    // MARK: - 底部动作条

    private var actionBar: some View {
        HStack(spacing: theme.spacingM) {
            if bridge.isLoading {
                ProgressView().controlSize(.small)
                Text(bridge.runningAction.isEmpty ? "执行中…" : bridge.runningAction)
                    .font(.system(size: 11)).foregroundStyle(theme.textSecondary)
            }
            Spacer()
            if let r = bridge.lastRunResult, !bridge.isLoading {
                HStack(spacing: 6) {
                    Circle().fill(r.success ? theme.greenDot : theme.redDot).frame(width: 6, height: 6)
                    Text(r.message).font(.system(size: 11)).foregroundStyle(theme.textSecondary).lineLimit(1)
                }
            }
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingS)
        .background(theme.surfaceSecondary)
    }

    // MARK: - Helpers

    private func sectionLabel(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: theme.footnoteSize, weight: .semibold))
            .foregroundStyle(theme.text)
    }

    private func emptyHint(_ text: String) -> some View {
        Text(text).font(.system(size: 11)).foregroundStyle(theme.textTertiary).padding(theme.spacingS)
    }

    private func runResultRow(_ r: DouyinRunResult) -> some View {
        HStack(spacing: 6) {
            Circle().fill(r.success ? theme.greenDot : theme.redDot).frame(width: 6, height: 6)
            Text(r.message).font(.system(size: 11)).foregroundStyle(theme.textSecondary)
        }
        .padding(theme.spacingS)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surfaceSecondary)
        .cornerRadius(6)
    }
}
