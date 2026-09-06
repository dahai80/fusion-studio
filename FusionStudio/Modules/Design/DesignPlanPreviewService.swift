import Foundation
import os.log

// ARCH-1 Phase 6 (审计product-0906 P1): DesignPlanPreview 行为迁入。DesignBridge 留 1 行 stub 转发
//   (保外部签名: DesignChatPanel.acceptPlan/rejectPlan 0 改)。
//   acceptPlan 跨域写 canvas (renderDocumentToCanvas + sendCanvasCommand) 经 self.bridge?.X reach-through。
//   纯状态 + canvas 调用, 0 IPC → 无 ipcClient ref。

private let designPlanPreviewLog = Logger(subsystem: "com.fusion.studio", category: "DesignPlanPreviewService")

extension DesignPlanPreviewState {

    func acceptPlan() {
        guard let code = pendingPlanCode else { return }
        bridge?.renderDocumentToCanvas(code)
        pendingPlanCode = nil
        isPlanPreviewActive = false
        bridge?.sendCanvasCommand(.planApply)
        designPlanPreviewLog.info("DesignPlanPreview: plan accepted and rendered to canvas")
    }

    func rejectPlan() {
        pendingPlanCode = nil
        isPlanPreviewActive = false
        bridge?.sendCanvasCommand(.planReject)
        designPlanPreviewLog.info("DesignPlanPreview: plan rejected, preview cleared")
    }
}
