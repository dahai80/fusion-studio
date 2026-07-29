import SwiftUI
import os.log

private let codegenLog = Logger(subsystem: "com.fusion.studio", category: "CodegenTargetPanel")

enum CodegenTarget: String, CaseIterable, Identifiable {
    case html = "html"
    case reactTailwind = "react-tailwind"
    case tailwindOnly = "tailwind-only"
    case swiftUI = "swift-ui"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .html: return "HTML"
        case .reactTailwind: return "React + Tailwind"
        case .tailwindOnly: return "Tailwind Only"
        case .swiftUI: return "SwiftUI"
        }
    }

    var icon: String {
        switch self {
        case .html: return "globe"
        case .reactTailwind: return "atom"
        case .tailwindOnly: return "paintbrush"
        case .swiftUI: return "swift"
        }
    }

    var description: String {
        switch self {
        case .html: return "纯 HTML + CSS 导出"
        case .reactTailwind: return "React 组件 + Tailwind CSS"
        case .tailwindOnly: return "纯 Tailwind CSS 类名"
        case .swiftUI: return "SwiftUI View 代码"
        }
    }

    var fileExtension: String {
        switch self {
        case .html: return "html"
        case .reactTailwind: return "tsx"
        case .tailwindOnly: return "html"
        case .swiftUI: return "swift"
        }
    }
}

struct CodegenTargetPanel: View {
    @Environment(\.studioTheme) var theme
    @EnvironmentObject var designBridge: DesignBridge

    @State private var selectedTarget: CodegenTarget = .html
    @State private var componentName: String = "MyComponent"
    @State private var generatedCode: String = ""
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var showCopiedToast = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            targetPicker
            Rectangle().fill(theme.separator).frame(height: 1)
            configBar
            Rectangle().fill(theme.separator).frame(height: 1)
            if let err = errorMessage {
                errorBanner(err)
            }
            codeOutput
        }
    }

    private var targetPicker: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text("导出目标")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(theme.textTertiary)
                .textCase(.uppercase)
                .padding(.horizontal, theme.spacingM)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: theme.spacingXS) {
                    ForEach(CodegenTarget.allCases) { target in
                        Button(action: { selectedTarget = target }) {
                            HStack(spacing: 4) {
                                Image(systemName: target.icon)
                                    .font(.system(size: 10))
                                Text(target.label)
                                    .font(.system(size: theme.captionSize, weight: .medium))
                            }
                            .foregroundStyle(selectedTarget == target ? theme.accentText : theme.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                    .fill(selectedTarget == target ? theme.accent : theme.groupBg)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, theme.spacingM)
            }
        }
        .padding(.vertical, theme.spacingS)
    }

    private var configBar: some View {
        HStack(spacing: theme.spacingS) {
            if selectedTarget == .reactTailwind || selectedTarget == .swiftUI {
                HStack(spacing: 4) {
                    Text("组件名")
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                    TextField("MyComponent", text: $componentName)
                        .textFieldStyle(.plain)
                        .font(.system(size: theme.captionSize, design: .monospaced))
                        .foregroundStyle(theme.text)
                        .frame(width: 100)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(theme.groupBg)
                        .cornerRadius(theme.cornerRadiusSmall)
                }
            }

            Spacer()

            Button(action: runCodegen) {
                HStack(spacing: 4) {
                    if isGenerating {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 12, height: 12)
                    } else {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 10))
                    }
                    Text(isGenerating ? "生成中..." : "生成代码")
                        .font(.system(size: theme.captionSize, weight: .medium))
                }
                .foregroundStyle(theme.accentText)
                .padding(.horizontal, theme.spacingM)
                .padding(.vertical, theme.spacingXS)
                .background(
                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .fill(theme.accent)
                )
            }
            .buttonStyle(.plain)
            .disabled(isGenerating || (designBridge.lastRenderedDocumentJSON ?? "").isEmpty)

            if !generatedCode.isEmpty {
                Button(action: copyToClipboard) {
                    HStack(spacing: 3) {
                        Image(systemName: showCopiedToast ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10))
                        Text(showCopiedToast ? "已复制" : "复制")
                            .font(.system(size: theme.captionSize, weight: .medium))
                    }
                    .foregroundStyle(theme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, theme.spacingXS)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                            .fill(theme.groupBg)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
    }

    private func errorBanner(_ msg: String) -> some View {
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
    }

    private var codeOutput: some View {
        if generatedCode.isEmpty {
            AnyView(
                VStack(spacing: theme.spacingS) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: theme.iconL))
                        .foregroundStyle(theme.textTertiary)
                    Text("选择导出目标\n点击生成代码")
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            )
        } else {
            AnyView(ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("\(selectedTarget.label) — \(componentName).\(selectedTarget.fileExtension)")
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .foregroundStyle(theme.textTertiary)
                            Spacer()
                            Text("\(generatedCode.count) 字符")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(theme.textTertiary)
                        }
                        .padding(.horizontal, theme.spacingS)
                        .padding(.vertical, theme.spacingXS)
                        .background(theme.groupBg)

                        Text(generatedCode)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(theme.text)
                            .textSelection(.enabled)
                            .padding(theme.spacingS)
                    }
                    .background(theme.groupBg)
                    .cornerRadius(theme.cornerRadiusSmall)
                    .padding(theme.spacingS)
                })
            }
    }

    private func runCodegen() {
        guard let docJSON = designBridge.lastRenderedDocumentJSON, !docJSON.isEmpty else { return }
        isGenerating = true
        errorMessage = nil

        let cliPath = findFusionDesignCLI()

        DispatchQueue.global(qos: .userInitiated).async {
            let tempDir = FileManager.default.temporaryDirectory
            let inputFile = tempDir.appendingPathComponent("fusion-codegen-input-\(UUID().uuidString).json")
            do {
                try docJSON.write(to: inputFile, atomically: true, encoding: .utf8)
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "写入临时文件失败: \(error.localizedDescription)"
                    self.isGenerating = false
                }
                return
            }

            let args = ["codegen", "--input", inputFile.path, "--target", selectedTarget.rawValue, "--component", componentName]

            let process = Process()
            process.executableURL = URL(fileURLWithPath: cliPath)
            let pipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = pipe
            process.standardError = errPipe
            process.arguments = args

            do {
                try process.run()
                process.waitUntilExit()

                if process.terminationStatus == 0 {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let output = String(data: data, encoding: .utf8) {
                        DispatchQueue.main.async {
                            self.generatedCode = output
                            codegenLog.info("Codegen completed: \(output.count) chars, target=\(self.selectedTarget.rawValue)")
                        }
                    }
                } else {
                    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    let errMsg = String(data: errData, encoding: .utf8) ?? "unknown error"
                    DispatchQueue.main.async {
                        self.errorMessage = "代码生成失败 (exit \(process.terminationStatus)): \(errMsg.prefix(200))"
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "执行 codegen 命令失败: \(error.localizedDescription)"
                }
            }

            try? FileManager.default.removeItem(at: inputFile)
            DispatchQueue.main.async { self.isGenerating = false }
        }
    }

    private func copyToClipboard() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(generatedCode, forType: .string)
        #endif
        showCopiedToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showCopiedToast = false
        }
    }

    private func findFusionDesignCLI() -> String {
        let devPath = NSHomeDirectory() + "/fusion/fusion-design/target/debug/fusion-design"
        if FileManager.default.fileExists(atPath: devPath) { return devPath }
        if let bundlePath = Bundle.main.path(forResource: "fusion-design", ofType: nil) { return bundlePath }
        return "/usr/local/bin/fusion-design"
    }
}
