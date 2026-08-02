import SwiftUI
import os

private let ragLog = Logger(subsystem: "com.fusion.studio", category: "RAGMainView")

enum RAGSection: String, CaseIterable, Identifiable {
    case dashboard = "知识库总览"
    case files = "文件目录管理"
    case embedConfig = "嵌入模型配置"
    case searchConfig = "检索策略配置"
    case permissions = "权限管控"
    case vectorOps = "向量库运维"
    case callLog = "RAG调用日志"
    case benchEval = "检索性能评测"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard:    return "square.grid.2x2"
        case .files:        return "folder.badge.gearshape"
        case .embedConfig:  return "cpu"
        case .searchConfig: return "slider.horizontal.3"
        case .permissions:  return "lock.shield"
        case .vectorOps:    return "arrow.triangle.2.circlepath"
        case .callLog:      return "list.bullet.rectangle"
        case .benchEval:    return "chart.bar.xaxis"
        }
    }
}

struct RAGMainView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.studioTheme) private var theme
    @StateObject private var client = RAGAPIClient.shared
    @State private var selectedSection: RAGSection = .dashboard
    @State private var selectedKBId: String = ""

    var body: some View {
        HStack(spacing: 0) {
            ragSectionSidebar

            Rectangle().fill(theme.separator).frame(width: 1)

            ragContentArea
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var ragSectionSidebar: some View {
        VStack(spacing: 0) {
            Text("RAG")
                .font(.system(size: theme.titleSize, weight: .bold))
                .foregroundStyle(theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, theme.spacingM)
                .padding(.vertical, theme.spacingM)

            Rectangle().fill(theme.separator).frame(height: 1)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(RAGSection.allCases) { section in
                        sectionRow(section)
                    }
                }
            }

            Rectangle().fill(theme.separator).frame(height: 1)

            kbPickerBar
        }
        .frame(width: 220)
        .background(theme.surfaceSecondary)
    }

    private func sectionRow(_ section: RAGSection) -> some View {
        let isActive = selectedSection == section
        return Button(action: {
            withAnimation(theme.springSnappy) {
                selectedSection = section
            }
            ragLog.info("RAG section: \(section.rawValue)")
        }) {
            HStack(spacing: theme.spacingS) {
                ZStack(alignment: .leading) {
                    if isActive {
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(theme.accent)
                            .frame(width: 3, height: 16)
                            .offset(x: -theme.spacingXS)
                    }
                    Image(systemName: section.icon)
                        .font(.system(size: theme.iconS, weight: isActive ? .semibold : .regular))
                        .foregroundStyle(isActive ? theme.accent : theme.textTertiary)
                        .frame(width: 20)
                }
                Text(section.rawValue)
                    .font(.system(size: theme.textSize, weight: isActive ? .medium : .regular))
                    .foregroundStyle(isActive ? theme.text : theme.textSecondary)
                Spacer()
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                    .fill(isActive ? theme.accent.opacity(0.12) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var kbPickerBar: some View {
        VStack(spacing: theme.spacingXS) {
            Text("当前知识库")
                .font(.system(size: theme.captionSize, weight: .semibold))
                .foregroundStyle(theme.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, theme.spacingM)

            KBPickerView(selectedKBId: $selectedKBId)
                .padding(.horizontal, theme.spacingM)
                .padding(.bottom, theme.spacingS)
        }
        .padding(.top, theme.spacingXS)
    }

    @ViewBuilder
    private var ragContentArea: some View {
        switch selectedSection {
        case .dashboard:
            RAGDashboardView(selectedKBId: $selectedKBId)
        case .files:
            RAGFilesView(selectedKBId: selectedKBId)
        case .embedConfig:
            RAGEmbedConfigView()
        case .searchConfig:
            RAGSearchConfigView(selectedKBId: selectedKBId)
        case .permissions:
            RAGPermissionsView()
        case .vectorOps:
            RAGVectorOpsView(selectedKBId: selectedKBId)
        case .callLog:
            RAGCallLogView(client: client, selectedKbId: $selectedKBId)
        case .benchEval:
            RAGBenchEvalView(selectedKBId: selectedKBId, client: client)
        }
    }
}

struct KBPickerView: View {
    @Binding var selectedKBId: String
    @StateObject private var client = RAGAPIClient.shared

    var body: some View {
        Picker("", selection: $selectedKBId) {
            Text("全部").tag("")
            ForEach(client.knowledgeBases) { kb in
                Text(kb.name).tag(kb.id)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .task {
            if client.knowledgeBases.isEmpty {
                await client.listBases()
            }
        }
    }
}
