import Foundation
import os.log

// ARCH-1 Phase 4 (审计product-0906 P1): DesignPage 行为迁入。DesignBridge 留 1 行 stub 转发 (保外部签名:
//   DesignChatPanel.addPage/deletePage/switchToPage + DesignWorkflowOrchestrator.loadDocumentJSON +
//   EcosystemSyncPanel.mutateNode 0 改)。
//   跨域写 (artifact: currentArtifactCode/Title/Type/artifactId; version: versionHistory) 经
//   self.bridge?.artifactState.X / self.bridge?.versionState.X reach-through。
//   跨域协调器 (switchToPage 调 saveCurrentPageState; renderDocumentToCanvas; mutateCanvasNode) 留
//   DesignBridge → 显式 self.bridge?.X 调用。switchToPage 自身留 DesignBridge (3 域协调器), addPage/deletePage
//   经 self.bridge?.switchToPage(at:) reach-through。

private let designPageLog = Logger(subsystem: "com.fusion.studio", category: "DesignPageService")

extension DesignPageState {

    func addPage() {
        let page = DesignPage(title: "Page \(pages.count + 1)")
        pages.append(page)
        bridge?.switchToPage(at: pages.count - 1)
        designPageLog.info("DesignPage: added page '\(page.title)', total=\(self.pages.count)")
    }

    func deletePage(at index: Int) {
        guard pages.indices.contains(index) else { return }
        let wasCurrent = index == currentPageIndex
        pages.remove(at: index)
        if pages.isEmpty {
            currentPageIndex = -1
            bridge?.artifactState.currentArtifactCode = ""
            bridge?.artifactState.currentArtifactTitle = ""
            bridge?.artifactState.currentArtifactType = "html"
            bridge?.artifactState.artifactId = ""
        } else if wasCurrent {
            let newIndex = min(index, pages.count - 1)
            bridge?.switchToPage(at: newIndex)
        } else if currentPageIndex > index {
            currentPageIndex -= 1
        }
        designPageLog.info("DesignPage: deleted page at \(index), remaining=\(self.pages.count)")
    }

    // switchToPage 留 DesignBridge (3 域协调器: page + artifact + version)。addPage/deletePage 经
    //   self.bridge?.switchToPage(at:) reach-through。

    func renamePage(at index: Int, newTitle: String) {
        guard pages.indices.contains(index) else { return }
        pages[index].title = newTitle
        if index == currentPageIndex {
            bridge?.artifactState.currentArtifactTitle = newTitle
        }
        designPageLog.info("DesignPage: renamed page at \(index) to '\(newTitle)'")
    }

    func saveCurrentPageState() {
        guard pages.indices.contains(currentPageIndex) else { return }
        pages[currentPageIndex].code = bridge?.artifactState.currentArtifactCode ?? ""
        pages[currentPageIndex].title = bridge?.artifactState.currentArtifactTitle ?? ""
        pages[currentPageIndex].type = bridge?.artifactState.currentArtifactType ?? "html"
        pages[currentPageIndex].artifactId = bridge?.artifactState.artifactId ?? ""
    }

    func loadDocumentJSON(_ json: String) {
        bridge?.renderDocumentToCanvas(json)
        designPageLog.info("DesignPage: loaded document JSON (\(json.count) chars)")
    }

    func mutateNode(nodeId: String, fill: String? = nil, stroke: String? = nil) {
        bridge?.mutateCanvasNode(nodeId, x: nil, y: nil, w: nil, h: nil, fill: fill, stroke: stroke)
    }
}
