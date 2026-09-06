import Foundation
import os.log

// ARCH-1 Phase 7 (审计product-0906 P1): DesignTheme 行为迁入。DesignBridge 留 1 行 stub 转发 (保外部签名:
//   DesignThemePanel.switchTheme/switchDesignSystem/ingestDesignTokens 0 改)。
//   switchTheme 调 skillTheme (skill 跨域) + applyDesignTokensToCanvas (canvas 跨域) 经 self.bridge?.X。
//   switchDesignSystem 调 applyDesignTokensToCanvas(systemId:) (共享 CLI 助手, 留 DesignBridge) 经 bridge?.X。
//   ingestDesignTokens 读 ipcClient (bridge?.ipcClient, ARCH-1 Phase 7 改 internal) + knowledgeIngest (RAG)。

private let designThemeLog = Logger(subsystem: "com.fusion.studio", category: "DesignThemeService")

extension DesignThemeState {

    func switchTheme(_ mode: String) {
        activeTheme = mode
        if let css = bridge?.skillTheme(designSystem: activeDesignSystem, mode: mode) {
            bridge?.applyDesignTokensToCanvas(css)
            designThemeLog.info("DesignTheme: switched theme to \(mode)")
        }
    }

    func switchDesignSystem(_ systemId: String) {
        activeDesignSystem = systemId
        let captured = systemId
        Task { @MainActor in
            await bridge?.applyDesignTokensToCanvas(systemId: captured)
        }
        designThemeLog.info("DesignTheme: switched design system to \(systemId)")
    }

    func ingestDesignTokens() async {
        guard let ipc = bridge?.ipcClient else { return }
        let _ = StudioTheme.dark
        let tokenDoc = """
        # Fusion Studio Design Tokens
        ## Colors
        - accent: #007AFF
        - accentDestructive: red
        - greenDot: success green
        - amberDot: warning amber
        - redDot: error red
        ## Spacing (4pt grid)
        - XS: 4pt, S: 8pt, M: 12pt, L: 16pt, XL: 24pt, 2XL: 32pt
        ## Typography
        - caption: 12pt, footnote: 13pt, small: 14pt, text: 15pt, body: 16pt, title: 19pt, headline: 22pt, largeTitle: 30pt
        ## Radius
        - small: 8pt, default: 12pt, large: 16pt
        ## Animation
        - fast: 0.15s, normal: 0.25s, slow: 0.35s
        """
        let scope = "design:tokens"
        do {
            _ = try await ipc.knowledgeIngest(content: tokenDoc, scope: scope, metadata: ["type": "design_tokens"])
            designThemeLog.info("DesignTheme: design tokens ingested to RAG")
        } catch {
            designThemeLog.warning("DesignTheme token ingest failed: \(error.localizedDescription)")
        }
    }
}
