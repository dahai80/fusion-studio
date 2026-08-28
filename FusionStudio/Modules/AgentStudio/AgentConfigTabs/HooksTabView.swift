import SwiftUI
import Combine
import os.log

// MARK: - HooksTabView

struct HooksTabView: View {
    let toastManager: FusionToastManager
    @EnvironmentObject private var bridge: AgentBridge
    @Environment(\.studioTheme) var theme
    @State private var showCreateSheet = false
    @State private var newEvent = "agent.execute"
    @State private var newAgentId = ""
    @State private var newAction = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Hooks")
                    .font(.system(size: theme.titleSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Spacer()
                FusionButton("Add Hook", icon: "plus") { showCreateSheet = true }
            }
            .padding(theme.spacingM)

            if bridge.configState.hooks.isEmpty {
                Spacer()
                Text("No hooks registered")
                    .font(.system(size: theme.textSize))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
            } else {
                ListGroup {
                    ForEach(Array(bridge.configState.hooks.enumerated()), id: \.offset) { idx, hook in
                        let event = hook["event"] as? String ?? "Unknown"
                        let agentId = hook["agent_id"] as? String ?? ""
                        let action = hook["action"] as? String ?? ""
                        let hookId = hook["hook_id"] as? String ?? hook["id"] as? String ?? ""
                        StudioRow(label: event, sublabel: "\(agentId) → \(action)", isLast: idx == bridge.configState.hooks.count - 1) {
                            FusionTag("hook", color: .blue)
                        }
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button {
                                Task { await testHook(hookId) }
                            } label: {
                                Label("Test", systemImage: "bolt")
                            }
                        }
                    }
                }
            }
        }
        .onAppear { Task { await bridge.fetchHooks() } }
        .sheet(isPresented: $showCreateSheet) {
            createHookSheet
        }
    }

    private var createHookSheet: some View {
        VStack(spacing: theme.spacingM) {
            Text("New Hook")
                .font(.system(size: theme.titleSize, weight: .bold))
            TextField("Event (e.g. agent.execute)", text: $newEvent)
                .textFieldStyle(.roundedBorder)
            Picker("Agent", selection: $newAgentId) {
                Text("Select agent").tag("")
                ForEach(bridge.agentState.agents) { a in
                    Text(a.name).tag(a.id)
                }
            }
            .pickerStyle(.menu)
            TextField("Action", text: $newAction)
                .textFieldStyle(.roundedBorder)
            HStack {
                FusionButton("Cancel") { showCreateSheet = false }
                Spacer()
                FusionButton("Create", icon: "plus") {
                    Task { await createHook() }
                }
            }
        }
        .padding(theme.spacingL)
        .frame(width: 400)
    }

    private func createHook() async {
        guard !newEvent.isEmpty, !newAgentId.isEmpty, !newAction.isEmpty else { return }
        do {
            _ = try await bridge.hooksRegister(event: newEvent, agentId: newAgentId, action: newAction)
            toastManager.show(style: .success, title: "Hook Created", message: newEvent)
            showCreateSheet = false
            newAction = ""
        } catch {
            toastManager.show(style: .error, title: "Create Failed", message: error.localizedDescription)
        }
    }

    private func testHook(_ id: String) async {
        do {
            let result = try await bridge.hooksTest(hookId: id)
            let success = result["success"] as? Bool ?? false
            toastManager.show(style: success ? .success : .error, title: success ? "Hook OK" : "Hook Failed", message: "")
        } catch {
            toastManager.show(style: .error, title: "Test Failed", message: error.localizedDescription)
        }
    }
}
