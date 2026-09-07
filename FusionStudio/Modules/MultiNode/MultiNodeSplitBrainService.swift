import Foundation
import os.log

// ARCH-1 (PR-C1) Phase 3: SplitBrain 域 — 纯状态域, 0 行为迁入。
//   检测逻辑 (三层确定性信号: #72 partitioned / #76 epoch / master-count heuristic) 嵌在
//   NodeState.fetchNodes (MultiNodeNodeService.swift), 经 self.bridge?.splitBrainState.X reach-through 写。
//   协调器 assertNoSplitBrain (读 splitBrainDetected 阻断写) 留 engine (跨域协调器, 读此域 + 被各域写方法调)。
//   此文件留空 extension 占位 (Phase 3 完整域覆盖), 后续若拆出独立检测方法可在此扩展。

private let mnSplitBrainLog = Logger(subsystem: "com.fusion.studio", category: "MultiNodeSplitBrainService")

extension MultiNodeSplitBrainState {
    // Phase 3: 0 方法迁入。检测逻辑在 NodeState.fetchNodes, 协调器 assertNoSplitBrain 留 engine。
}
