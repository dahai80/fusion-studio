import SwiftUI
import Combine
import os.log

// MARK: - ApikeyTabView

struct ApikeyTabView: View {
    let toastManager: FusionToastManager
    @EnvironmentObject private var bridge: AgentBridge
    @Environment(\.studioTheme) var theme
    @State private var showCreateSheet = false
    @State private var newName = ""
    @State private var newPermissions = "read,execute"

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("API Keys")
                    .font(.system(size: theme.titleSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Spacer()
                FusionButton("Create Key", icon: "plus") { showCreateSheet = true }
            }
            .padding(theme.spacingM)

            if bridge.configState.apikeys.isEmpty {
                Spacer()
                Text("No API keys")
                    .font(.system(size: theme.textSize))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
            } else {
                ListGroup {
                    ForEach(Array(bridge.configState.apikeys.enumerated()), id: \.offset) { idx, key in
                        let name = key["name"] as? String ?? "Unknown"
                        let kid = key["key_id"] as? String ?? key["id"] as? String ?? ""
                        let prefix = key["key_prefix"] as? String ?? ""
                        let perms = key["permissions"] as? [String] ?? []
                        StudioRow(label: name, sublabel: prefix.isEmpty ? kid : prefix, isLast: idx == bridge.configState.apikeys.count - 1) {
                            if perms.contains("admin") {
                                FusionTag("admin", color: .red)
                            } else if perms.contains("execute") {
                                FusionTag("execute", color: .green)
                            } else {
                                FusionTag("read", color: .blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button {
                                Task { await rotateKey(kid, name: name) }
                            } label: {
                                Label("Rotate Key", systemImage: "arrow.triangle.2.circlepath")
                            }
                            Divider()
                            Button("Revoke", role: .destructive) {
                                Task { await revokeKey(kid, name: name) }
                            }
                        }
                    }
                }
            }
        }
        .onAppear { Task { await bridge.fetchApikeys() } }
        .sheet(isPresented: $showCreateSheet) {
            createApikeySheet
        }
    }

    private var createApikeySheet: some View {
        VStack(spacing: theme.spacingM) {
            Text("New API Key")
                .font(.system(size: theme.titleSize, weight: .bold))
            TextField("Name", text: $newName)
                .textFieldStyle(.roundedBorder)
            TextField("Permissions (comma-separated)", text: $newPermissions)
                .textFieldStyle(.roundedBorder)
            VStack(alignment: .leading, spacing: theme.spacingXS) {
                Text("Agent Restrictions")
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: theme.spacingXS) {
                        ForEach(bridge.agentState.agents.prefix(10), id: \.id) { agent in
                            FusionTag(agent.name, color: .blue)
                        }
                    }
                }
                Text("Leave empty to allow all agents")
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
            }
            HStack {
                FusionButton("Cancel") { showCreateSheet = false }
                Spacer()
                FusionButton("Create", icon: "plus") {
                    Task { await createKey() }
                }
            }
        }
        .padding(theme.spacingL)
        .frame(width: 400)
    }

    private func createKey() async {
        guard !newName.isEmpty else { return }
        let perms = newPermissions.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        do {
            let result = try await bridge.apikeyCreate(name: newName, permissions: perms)
            let keyVal = result["key"] as? String ?? ""
            toastManager.show(style: .success, title: "Key Created", message: keyVal.isEmpty ? newName : "Copy key: \(keyVal.prefix(12))...")
            showCreateSheet = false
            newName = ""; newPermissions = "read,execute"
        } catch {
            toastManager.show(style: .error, title: "Create Failed", message: error.localizedDescription)
        }
    }

    private func revokeKey(_ id: String, name: String) async {
        do {
            _ = try await bridge.apikeyRevoke(keyId: id)
            toastManager.show(style: .info, title: "Revoked", message: name)
        } catch {
            toastManager.show(style: .error, title: "Revoke Failed", message: error.localizedDescription)
        }
    }

    private func rotateKey(_ id: String, name: String) async {
        do {
            let result = try await bridge.apikeyRotate(keyId: id)
            let newKey = result["key"] as? String ?? ""
            toastManager.show(style: .success, title: "Key Rotated", message: newKey.isEmpty ? name : "New key: \(newKey.prefix(12))...")
        } catch {
            toastManager.show(style: .error, title: "Rotate Failed", message: error.localizedDescription)
        }
    }
}
