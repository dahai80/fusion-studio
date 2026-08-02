import SwiftUI
import os.log

private let viewLog = Logger(subsystem: "com.fusion.studio", category: "ScienceWorkbenchView")

struct ScienceWorkbenchView: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var scienceBridge: ScienceBridge
    @EnvironmentObject var scienceSSE: ScienceSSEClient
    @State private var inputText: String = ""
    @State private var selectedPipeline: SciencePipelineTemplate?

    var body: some View {
        HSplitView {
            ScienceSessionList()
                .frame(minWidth: 200, idealWidth: 240, maxWidth: 280)

            ScienceChatView(inputText: $inputText, selectedPipeline: $selectedPipeline)
                .frame(minWidth: 400, idealWidth: 600)

            ScienceContextPanel()
                .frame(minWidth: 260, idealWidth: 320, maxWidth: 380)
        }
        .background(theme.contentBg)
        .onAppear {
            scienceBridge.checkHealth()
            scienceBridge.fetchSessions()
            scienceBridge.fetchDatabases()
            viewLog.info("ScienceWorkbenchView appeared")
        }
    }
}
