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

    @StateObject private var i18n = I18nManager.shared

    @State private var selectedTab = 0
    @State private var produceTopic = ""
    @State private var produceVariant = "A"
    @State private var publishDryRun = true
    @State private var planExpression = "5 12,19 * * *"
    @State private var planDryRun = true

    private let variants = ["A", "B", "C"]
    // 钩子变体说明, 与 mlx_script.py VARIANT_HOOK 同源. 用户选择时知道每个变体代表什么钩子风格.
    private let variantHints: [String: I18nKey] = [
        "A": .dy_prod_hint_a,
        "B": .dy_prod_hint_b,
        "C": .dy_prod_hint_c,
    ]
    private var tabs: [FusionTabItem] {
        [
            FusionTabItem(title: i18n.t(.dy_tab_inventory), icon: "shippingbox"),
            FusionTabItem(title: i18n.t(.dy_tab_produce), icon: "film.stack"),
            FusionTabItem(title: i18n.t(.dy_tab_publish), icon: "paperplane"),
            FusionTabItem(title: i18n.t(.dy_tab_plan), icon: "clock.badge"),
            FusionTabItem(title: i18n.t(.dy_tab_comment), icon: "bubble.left.and.bubble.right"),
            FusionTabItem(title: i18n.t(.dy_tab_evolve), icon: "chart.line.uptrend.xyaxis"),
            FusionTabItem(title: i18n.t(.dy_tab_stats), icon: "chart.bar"),
        ]
    }

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
            queueBadge(i18n.t(.dy_queue_pending), count: bridge.queueCounts.pending, color: theme.amberDot, icon: "tray")
            queueBadge(i18n.t(.dy_queue_published), count: bridge.queueCounts.published, color: theme.greenDot, icon: "checkmark.circle")
            queueBadge(i18n.t(.dy_queue_failed), count: bridge.queueCounts.failed, color: theme.redDot, icon: "exclamationmark.triangle")
            Spacer()
            if let error = bridge.lastError {
                Text(error).font(.system(size: 11)).foregroundStyle(theme.accentDestructive).lineLimit(1).help(error)
            }
            Button {
                bridge.refreshAll()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless).help(i18n.t(.dy_queue_refresh))
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
            sectionLabel(i18n.t(.dy_inv_pending_queue), icon: "tray.fill")
            if bridge.pendingItems.isEmpty {
                emptyHint(i18n.t(.dy_inv_pending_empty))
            } else {
                ForEach(bridge.pendingItems) { item in
                    queueItemRow(item)
                }
            }

            sectionLabel(i18n.t(.dy_inv_published_recent), icon: "checkmark.circle.fill")
            if bridge.publishedItems.isEmpty {
                emptyHint(i18n.t(.dy_inv_published_empty))
            } else {
                ForEach(bridge.publishedItems) { item in
                    queueItemRow(item)
                }
            }

            if !bridge.failedItems.isEmpty {
                sectionLabel(i18n.t(.dy_inv_failed_queue), icon: "exclamationmark.triangle.fill")
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
                    Text(String(format: i18n.t(.dy_inv_variant_label), item.hookVariant)).font(.system(size: 10)).foregroundStyle(theme.accent)
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
            sectionLabel(i18n.t(.dy_prod_title), icon: "film.stack.fill")
            Text(i18n.t(.dy_prod_desc))
                .font(.system(size: theme.footnoteSize)).foregroundStyle(theme.textSecondary)

            VStack(alignment: .leading, spacing: theme.spacingS) {
                Text(i18n.t(.dy_prod_topic_label)).font(.system(size: 11)).foregroundStyle(theme.textSecondary)
                TextField(i18n.t(.dy_prod_topic_ph), text: $produceTopic)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: theme.footnoteSize))
            }

            HStack(spacing: theme.spacingS) {
                Text(i18n.t(.dy_prod_variant_label)).font(.system(size: 11)).foregroundStyle(theme.textSecondary)
                Picker("Variant", selection: $produceVariant) {
                    ForEach(variants, id: \.self) { Text($0).tag($0) }
                }.pickerStyle(.segmented).frame(width: 200)
            }
            VStack(alignment: .leading, spacing: 2) {
                ForEach(variants, id: \.self) { v in
                    Text(String(format: i18n.t(variantHints[v] ?? .dy_prod_hint_a), v))
                        .font(.system(size: 11))
                        .foregroundStyle(produceVariant == v ? theme.accent : theme.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            FusionButton(i18n.t(.dy_prod_start), icon: "wand.and.stars", style: .primary, size: .small,
                         isLoading: bridge.isLoading && bridge.runningAction.hasPrefix("produce")) {
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
            sectionLabel(i18n.t(.dy_pub_title), icon: "paperplane.fill")
            Text(i18n.t(.dy_pub_desc))
                .font(.system(size: theme.footnoteSize)).foregroundStyle(theme.textSecondary)

            Toggle(i18n.t(.dy_pub_dryrun_toggle), isOn: $publishDryRun)
                .font(.system(size: theme.footnoteSize))

            HStack(spacing: theme.spacingS) {
                FusionButton(publishDryRun ? i18n.t(.dy_pub_dryrun_btn) : i18n.t(.dy_pub_real_btn),
                             icon: publishDryRun ? "eye" : "paperplane",
                             style: publishDryRun ? .secondary : .primary, size: .small,
                             isLoading: bridge.isLoading && bridge.runningAction.hasPrefix("publish")) {
                    bridge.publishFromQueue(dryRun: publishDryRun, ipc: ipc)
                }
            }

            if !publishDryRun {
                Text(i18n.t(.dy_pub_real_warn))
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
            sectionLabel(i18n.t(.dy_plan_title), icon: "clock.badge.fill")
            Text(i18n.t(.dy_plan_desc))
                .font(.system(size: theme.footnoteSize)).foregroundStyle(theme.textSecondary)

            VStack(alignment: .leading, spacing: theme.spacingS) {
                Text(i18n.t(.dy_plan_expr_label)).font(.system(size: 11)).foregroundStyle(theme.textSecondary)
                TextField("5 12,19 * * *", text: $planExpression)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: theme.footnoteSize, design: .monospaced))
                Text(i18n.t(.dy_plan_expr_default))
                    .font(.system(size: 10)).foregroundStyle(theme.textTertiary)
            }

            Toggle(i18n.t(.dy_plan_dryrun_toggle), isOn: $planDryRun)
                .font(.system(size: theme.footnoteSize))
            if !planDryRun {
                Text(i18n.t(.dy_plan_real_warn))
                    .font(.system(size: 11)).foregroundStyle(theme.accentDestructive)
            }

            HStack(spacing: theme.spacingS) {
                FusionButton(i18n.t(.dy_plan_register), icon: "clock.badge.plus", style: .primary, size: .small,
                             isLoading: bridge.cronLoading) {
                    bridge.registerPublishPlan(expression: planExpression, dryRun: planDryRun, ipc: ipc)
                }
                if !bridge.cronJobs.isEmpty {
                    FusionButton(i18n.t(.dy_plan_refresh), icon: "arrow.clockwise", style: .secondary, size: .small) {
                        bridge.refreshCron(ipc: ipc)
                    }
                }
            }

            if let r = bridge.lastRunResult, bridge.runningAction.isEmpty, r.status == "registered" || r.status == "failed" {
                runResultRow(r)
            }

            if bridge.cronJobs.isEmpty {
                emptyHint(i18n.t(.dy_plan_empty))
            } else {
                sectionLabel(i18n.t(.dy_plan_registered), icon: "clock.fill")
                ForEach(bridge.cronJobs) { job in
                    cronJobRow(job)
                }

                if !bridge.cronExecutions.isEmpty {
                    sectionLabel(i18n.t(.dy_plan_history), icon: "list.bullet.rectangle")
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
                    Label(String(format: i18n.t(.dy_cron_next), formatEpoch(job.nextRun)), systemImage: "arrow.clockwise")
                }
                if job.lastRun > 0 {
                    Label(String(format: i18n.t(.dy_cron_last), formatEpoch(job.lastRun)), systemImage: "checkmark")
                }
            }.font(.system(size: 10)).foregroundStyle(theme.textTertiary)
            if !job.inputData.isEmpty {
                Text(String(format: i18n.t(.dy_cron_params), job.inputData)).font(.system(size: 10, design: .monospaced)).foregroundStyle(theme.textTertiary)
            }
            FusionButton(i18n.t(.dy_cron_cancel), icon: "trash", style: .secondary, size: .small,
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
            sectionLabel(i18n.t(.dy_comment_title), icon: "bubble.left.and.bubble.right.fill")
            Text(i18n.t(.dy_comment_desc))
                .font(.system(size: theme.footnoteSize)).foregroundStyle(theme.textSecondary)

            FusionButton(i18n.t(.dy_comment_start), icon: "text.bubble", style: .primary, size: .small,
                         isLoading: bridge.isLoading && bridge.runningAction == "comment_reply") {
                bridge.replyComments(ipc: ipc)
            }

            if !bridge.repliedIds.isEmpty {
                sectionLabel(i18n.t(.dy_comment_replied_title), icon: "checkmark.bubble")
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
            sectionLabel(i18n.t(.dy_evolve_title), icon: "chart.line.uptrend.xyaxis")
            Text(i18n.t(.dy_evolve_desc))
                .font(.system(size: theme.footnoteSize)).foregroundStyle(theme.textSecondary)

            FusionButton(i18n.t(.dy_evolve_run), icon: "arrow.triangle.2.circlepath", style: .primary, size: .small,
                         isLoading: bridge.isLoading && bridge.runningAction == "evolve") {
                bridge.evolve(ipc: ipc)
            }

            sectionLabel(i18n.t(.dy_evolve_repair_title), icon: "wrench.adjustable")
            Text(i18n.t(.dy_evolve_repair_desc))
                .font(.system(size: theme.footnoteSize)).foregroundStyle(theme.textSecondary)
            FusionButton(i18n.t(.dy_evolve_repair_scan), icon: "wrench.and.screwdriver", style: .secondary, size: .small,
                         isLoading: bridge.isLoading && bridge.runningAction == "repair") {
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
            sectionLabel(i18n.t(.dy_win_title), icon: "flame.fill")
            Text(String(format: i18n.t(.dy_win_summary), bridge.winning.samples, bridge.winning.hotCount, bridge.winning.updatedAt))
                .font(.system(size: 11)).foregroundStyle(theme.textTertiary)

            if !bridge.winning.titleFormula.isEmpty {
                patternRow(i18n.t(.dy_win_title_formula), bridge.winning.titleFormula)
            }
            ForEach(Array(bridge.winning.winningTopics.enumerated()), id: \.offset) { _, t in
                patternRow(i18n.t(.dy_win_hot_topic), t)
            }
            ForEach(Array(bridge.winning.winningHooks.enumerated()), id: \.offset) { _, t in
                patternRow(i18n.t(.dy_win_hot_hook), t)
            }
            ForEach(Array(bridge.winning.losingPatterns.enumerated()), id: \.offset) { _, t in
                patternRow(i18n.t(.dy_win_lose), t)
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
            sectionLabel(i18n.t(.dy_stats_title), icon: "chart.bar.fill")
            Text(i18n.t(.dy_stats_desc))
                .font(.system(size: 11)).foregroundStyle(theme.textTertiary)

            if bridge.statsSnapshots.isEmpty {
                emptyHint(i18n.t(.dy_stats_empty))
            } else {
                statsSummary
                statsVariantDistribution
            }

            // ---- 第二部分：逐视频细节排行 ----
            if !bridge.statsSnapshots.isEmpty {
                sectionLabel(i18n.t(.dy_stats_detail_title), icon: "list.number")
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
                statsMetricCard(i18n.t(.dy_stats_total_plays), "\(totalPlays)", theme.accent)
                statsMetricCard(i18n.t(.dy_stats_total_likes), "\(totalLikes)", theme.greenDot)
                statsMetricCard(i18n.t(.dy_stats_total_comments), "\(totalComments)", theme.textSecondary)
                statsMetricCard(i18n.t(.dy_stats_total_shares), "\(totalShares)", theme.textSecondary)
            }
            HStack(spacing: theme.spacingS) {
                statsMetricCard(i18n.t(.dy_stats_count), "\(snaps.count)", theme.text)
                statsMetricCard(i18n.t(.dy_stats_avg_plays), String(format: "%.0f", avgPlays), theme.text)
                statsMetricCard(i18n.t(.dy_stats_avg_ir), String(format: "%.2f%%", avgIR * 100), theme.accent)
                statsMetricCard(i18n.t(.dy_stats_hot_count), "\(hot)", theme.greenDot)
            }
            // 表现分布
            HStack(spacing: theme.spacingM) {
                Label(String(format: i18n.t(.dy_stats_dist_hot), hot), systemImage: "flame.fill").foregroundStyle(theme.greenDot)
                Label(String(format: i18n.t(.dy_stats_dist_mid), mid), systemImage: "minus.circle").foregroundStyle(theme.textSecondary)
                Label(String(format: i18n.t(.dy_stats_dist_cold), cold), systemImage: "snowflake").foregroundStyle(theme.amberDot)
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
                Text(i18n.t(.dy_stats_variant_dist)).font(.system(size: 11, weight: .medium)).foregroundStyle(theme.textSecondary)
                HStack(spacing: theme.spacingM) {
                    ForEach(["A", "B", "C"], id: \.self) { v in
                        Text(String(format: i18n.t(.dy_stats_variant_count), v, counts[v] ?? 0))
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
                    Text(String(format: i18n.t(.dy_stats_row_plays), snap.plays)).foregroundStyle(theme.text)
                    Text(String(format: i18n.t(.dy_stats_row_likes), snap.likes)).foregroundStyle(theme.textSecondary)
                    Text(String(format: i18n.t(.dy_stats_row_comments), snap.comments)).foregroundStyle(theme.textSecondary)
                    Text(String(format: i18n.t(.dy_stats_row_shares), snap.shares)).foregroundStyle(theme.textSecondary)
                    Text(String(format: i18n.t(.dy_stats_row_ir), snap.interactionRate * 100))
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
                Text(bridge.runningAction.isEmpty ? i18n.t(.dy_action_running) : localizedActionLabel(bridge.runningAction))
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

    private func localizedActionLabel(_ action: String) -> String {
        if action.hasPrefix("produce") { return i18n.t(.dy_action_produce) }
        if action.hasPrefix("publish") { return i18n.t(.dy_action_publish) }
        switch action {
        case "comment_reply": return i18n.t(.dy_action_comment_reply)
        case "evolve": return i18n.t(.dy_action_evolve)
        case "repair": return i18n.t(.dy_action_repair)
        default: return action
        }
    }
}
