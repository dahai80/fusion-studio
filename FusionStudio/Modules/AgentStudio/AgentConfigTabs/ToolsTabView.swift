import SwiftUI
import Combine
import os.log

// MARK: - ToolsTabView

struct ToolsTabView: View {
    let toastManager: FusionToastManager
    @EnvironmentObject private var bridge: AgentBridge
    @Environment(\.studioTheme) var theme
    @State private var showRegisterSheet = false
    @State private var newName = ""
    @State private var newDesc = ""
    @State private var newParams = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Tools")
                    .font(.system(size: theme.titleSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Spacer()
                FusionButton("Register", icon: "plus") { showRegisterSheet = true }
            }
            .padding(theme.spacingM)

            if bridge.moduleState.tools.isEmpty {
                Spacer()
                Text("No tools available")
                    .font(.system(size: theme.textSize))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
            } else {
                ScrollView {
                    ListGroup {
                        ForEach(Array(bridge.moduleState.tools.enumerated()), id: \.offset) { idx, tool in
                            let name = tool["name"] as? String ?? "unknown"
                            let desc = tool["description"] as? String ?? ""
                            let isDynamic = (tool["dynamic"] as? Bool ?? false) || (tool["source"] as? String == "dynamic")
                            StudioRow(label: name, sublabel: desc, isLast: idx == bridge.moduleState.tools.count - 1) {
                                HStack(spacing: 6) {
                                    if isDynamic {
                                        FusionTag("dynamic", color: .orange)
                                        FusionButton("Remove", icon: "trash", style: .destructive, size: .small) {
                                            Task { await unregisterTool(name) }
                                        }
                                    } else {
                                        FusionTag("builtin", color: .gray)
                                    }
                                }
                            }
                        }
                    }
                }
                Spacer()
            }
        }
        .onAppear {
            Task {
                do { try await bridge.fetchTools() } catch { agentStudioLog.warning("fetchTools failed: \(error)") }
            }
        }
        .sheet(isPresented: $showRegisterSheet) {
            registerSheet
        }
    }

    private var registerSheet: some View {
        VStack(spacing: theme.spacingM) {
            Text("Register Dynamic Tool")
                .font(.system(size: theme.titleSize, weight: .bold))
            TextField("Name", text: $newName)
                .textFieldStyle(.roundedBorder)
            TextField("Description", text: $newDesc, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
            TextField("Parameters (JSON)", text: $newParams, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...8)
                .font(.system(size: theme.footnoteSize, design: .monospaced))
            HStack {
                FusionButton("Cancel") { showRegisterSheet = false }
                Spacer()
                FusionButton("Register", icon: "plus", isDisabled: newName.isEmpty) {
                    Task { await registerTool() }
                }
            }
        }
        .padding(theme.spacingL)
        .frame(width: 450, height: 420)
    }

    private func registerTool() async {
        let params = parseParams(newParams)
        do {
            _ = try await bridge.toolDynamicRegister(name: newName, description: newDesc, parameters: params)
            toastManager.show(style: .success, title: "Registered", message: "Tool \(newName) added")
            showRegisterSheet = false
            newName = ""
            newDesc = ""
            newParams = ""
        } catch {
            toastManager.show(style: .error, title: "Failed", message: error.localizedDescription)
        }
    }

    private func unregisterTool(_ name: String) async {
        do {
            _ = try await bridge.toolDynamicUnregister(name: name)
            toastManager.show(style: .success, title: "Removed", message: "Tool \(name) unregistered")
        } catch {
            toastManager.show(style: .error, title: "Failed", message: error.localizedDescription)
        }
    }

    private func parseParams(_ json: String) -> [String: Any] {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return obj
    }
}
