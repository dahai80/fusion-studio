import SwiftUI
import os.log

private let dsListLog = Logger(subsystem: "com.fusion.studio", category: "DesignSystemListView")

struct DesignSystemInfo: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let cliId: String
    let tokenCount: Int

    static let builtIn: [DesignSystemInfo] = [
        DesignSystemInfo(id: "apple-hig", name: "Apple HIG", description: "Apple Human Interface Guidelines", icon: "apple.logo", cliId: "apple-hig", tokenCount: 28),
        DesignSystemInfo(id: "minimal-dashboard", name: "极简后台", description: "极简风格后台管理", icon: "rectangle.split.3x1", cliId: "minimal-dashboard", tokenCount: 22),
        DesignSystemInfo(id: "robot-sim", name: "机器人仿真", description: "工业仿真控制面板", icon: "gearshape.2", cliId: "robot-sim", tokenCount: 24)
    ]
}

struct DesignSystemListView: View {
    @Environment(\.studioTheme) var theme
    @EnvironmentObject var designBridge: DesignBridge

    @State private var activeSystemId: String = "apple-hig"
    @State private var availableSystems: [DesignSystemInfo] = DesignSystemInfo.builtIn
    @State private var isRefreshing = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Rectangle().fill(theme.separator).frame(height: 1)
            systemList
            Rectangle().fill(theme.separator).frame(height: 1)
            activeSystemFooter
        }
    }

    private var header: some View {
        HStack {
            Text("设计系统")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(theme.textTertiary)
                .textCase(.uppercase)
            Spacer()
            Button(action: refreshSystems) {
                HStack(spacing: 3) {
                    if isRefreshing {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 10, height: 10)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 9))
                    }
                    Text("刷新")
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)
            .disabled(isRefreshing)
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
    }

    private var systemList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: theme.spacingXS) {
                if let err = errorMessage {
                    errorRow(err)
                }
                ForEach(availableSystems) { sys in
                    systemRow(sys)
                }
            }
            .padding(theme.spacingS)
        }
    }

    private func systemRow(_ sys: DesignSystemInfo) -> some View {
        let isActive = sys.cliId == activeSystemId

        return Button(action: { activateSystem(sys) }) {
            HStack(spacing: theme.spacingS) {
                Image(systemName: sys.icon)
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(isActive ? theme.accentText : theme.textSecondary)
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                            .fill(isActive ? theme.accent : theme.groupBg)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(sys.name)
                        .font(.system(size: theme.footnoteSize, weight: isActive ? .semibold : .medium))
                        .foregroundStyle(theme.text)
                    Text(sys.description)
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                }

                Spacer()

                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(theme.greenDot)
                } else {
                    Text("\(sys.tokenCount) tokens")
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                }
            }
            .padding(theme.spacingS)
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                    .fill(isActive ? theme.accent.opacity(0.08) : theme.groupBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                    .stroke(isActive ? theme.accent : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isActive)
    }

    private func errorRow(_ msg: String) -> some View {
        HStack(spacing: theme.spacingXS) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(theme.amberDot)
            Text(msg)
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.textSecondary)
                .lineLimit(2)
            Spacer()
            Button(action: { errorMessage = nil }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(theme.spacingS)
        .background(theme.warningBg)
        .cornerRadius(theme.cornerRadiusSmall)
    }

    private var activeSystemFooter: some View {
        HStack(spacing: theme.spacingXS) {
            Circle().fill(theme.greenDot).frame(width: 6, height: 6)
            Text("当前激活: \(activeSystemName)")
                .font(.system(size: theme.captionSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)
            Spacer()
            Button(action: applyActiveSystem) {
                HStack(spacing: 3) {
                    Image(systemName: "paintbrush.fill")
                        .font(.system(size: 9))
                    Text("应用到画布")
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundStyle(theme.accentText)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .fill(theme.accent)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
    }

    private var activeSystemName: String {
        availableSystems.first(where: { $0.cliId == activeSystemId })?.name ?? activeSystemId
    }

    private func activateSystem(_ sys: DesignSystemInfo) {
        let cliPath = findFusionDesignCLI()

        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: cliPath)
            process.arguments = ["activate", sys.cliId]

            let pipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = pipe
            process.standardError = errPipe

            do {
                try process.run()
                process.waitUntilExit()

                if process.terminationStatus == 0 {
                    DispatchQueue.main.async {
                        self.activeSystemId = sys.cliId
                        dsListLog.info("Activated design system: \(sys.cliId)")
                    }
                } else {
                    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    let errMsg = String(data: errData, encoding: .utf8) ?? "unknown error"
                    DispatchQueue.main.async {
                        self.errorMessage = "激活失败: \(errMsg.prefix(200))"
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "执行激活命令失败: \(error.localizedDescription)"
                }
            }
        }
    }

    private func refreshSystems() {
        isRefreshing = true
        errorMessage = nil

        let cliPath = findFusionDesignCLI()

        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: cliPath)
            process.arguments = ["list-design-systems"]

            let pipe = Pipe()
            process.standardOutput = pipe

            do {
                try process.run()
                process.waitUntilExit()

                if process.terminationStatus == 0 {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let output = String(data: data, encoding: .utf8) {
                        let ids = output.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
                        DispatchQueue.main.async {
                            var systems = [DesignSystemInfo]()
                            for id in ids {
                                if let builtin = DesignSystemInfo.builtIn.first(where: { $0.cliId == id }) {
                                    systems.append(builtin)
                                } else {
                                    systems.append(DesignSystemInfo(id: id, name: id, description: "自定义设计系统", icon: "paintpalette", cliId: id, tokenCount: 0))
                                }
                            }
                            self.availableSystems = systems
                            dsListLog.info("Refreshed design systems: \(ids)")
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "获取设计系统列表失败: \(error.localizedDescription)"
                }
            }

            DispatchQueue.main.async { self.isRefreshing = false }
        }
    }

    private func applyActiveSystem() {
        designBridge.applyDesignTokensToCanvas(systemId: activeSystemId)
    }

    private func findFusionDesignCLI() -> String {
        let devPath = NSHomeDirectory() + "/fusion/fusion-design/target/debug/fusion-design"
        if FileManager.default.fileExists(atPath: devPath) { return devPath }
        if let bundlePath = Bundle.main.path(forResource: "fusion-design", ofType: nil) { return bundlePath }
        return "/usr/local/bin/fusion-design"
    }
}
