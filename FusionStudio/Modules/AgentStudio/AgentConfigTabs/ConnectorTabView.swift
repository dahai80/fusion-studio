import SwiftUI
import Combine
import os.log

// MARK: - ConnectorTabView

struct ConnectorTabView: View {
    let toastManager: FusionToastManager
    @EnvironmentObject private var bridge: AgentBridge
    @Environment(\.studioTheme) var theme
    @State private var showCreateSheet = false
    @State private var newName = ""
    @State private var newType = "http"
    @State private var newConfig = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Connectors")
                    .font(.system(size: theme.titleSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Spacer()
                FusionButton("Add Connector", icon: "plus") { showCreateSheet = true }
            }
            .padding(theme.spacingM)

            if bridge.configState.connectors.isEmpty {
                Spacer()
                Text("No connectors configured")
                    .font(.system(size: theme.textSize))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
            } else {
                ListGroup {
                    ForEach(Array(bridge.configState.connectors.enumerated()), id: \.offset) { idx, conn in
                        let name = conn["name"] as? String ?? "Unknown"
                        let type = conn["type"] as? String ?? ""
                        let status = conn["status"] as? String ?? "unknown"
                        let cid = conn["connector_id"] as? String ?? conn["id"] as? String ?? ""
                        StudioRow(label: name, sublabel: type, isLast: idx == bridge.configState.connectors.count - 1) {
                            FusionTag(status, color: status == "connected" ? .green : status == "disconnected" ? .gray : .orange)
                        }
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button { Task { await testConnector(cid, name: name) } } label: {
                                Label("Test", systemImage: "bolt")
                            }
                            if status != "connected" {
                                Button { Task { await connectConnector(cid, name: name) } } label: {
                                    Label("Connect", systemImage: "link")
                                }
                            }
                            if status == "connected" {
                                Button { Task { await disconnectConnector(cid, name: name) } } label: {
                                    Label("Disconnect", systemImage: "link.badge.plus")
                                }
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                Task { await deleteConnector(cid, name: name) }
                            }
                        }
                    }
                }
            }
        }
        .onAppear { Task { await bridge.fetchConnectors() } }
        .sheet(isPresented: $showCreateSheet) {
            createConnectorSheet
        }
    }

    private var createConnectorSheet: some View {
        VStack(spacing: theme.spacingM) {
            Text("New Connector")
                .font(.system(size: theme.titleSize, weight: .bold))
            TextField("Name", text: $newName)
                .textFieldStyle(.roundedBorder)
            TextField("Type (http, database, api...)", text: $newType)
                .textFieldStyle(.roundedBorder)
            TextField("Config (JSON)", text: $newConfig, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
            HStack {
                FusionButton("Cancel") { showCreateSheet = false }
                Spacer()
                FusionButton("Create", icon: "plus") {
                    Task { await createConnector() }
                }
            }
        }
        .padding(theme.spacingL)
        .frame(width: 400)
    }

    private func createConnector() async {
        guard !newName.isEmpty else { return }
        var config: [String: Any] = [:]
        if let data = newConfig.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            config = json
        }
        do {
            _ = try await bridge.connectorCreate(name: newName, type: newType, config: config)
            toastManager.show(style: .success, title: "Created", message: "\(newName)")
            showCreateSheet = false
            newName = ""; newConfig = ""
        } catch {
            toastManager.show(style: .error, title: "Create Failed", message: error.localizedDescription)
        }
    }

    private func testConnector(_ id: String, name: String) async {
        do {
            let result = try await bridge.connectorTest(connectorId: id)
            let success = result["success"] as? Bool ?? false
            toastManager.show(style: success ? .success : .error, title: success ? "OK" : "Failed", message: "\(name)")
        } catch {
            toastManager.show(style: .error, title: "Test Failed", message: error.localizedDescription)
        }
    }

    private func connectConnector(_ id: String, name: String) async {
        do {
            _ = try await bridge.connectorConnect(connectorId: id)
            toastManager.show(style: .success, title: "Connected", message: name)
            await bridge.fetchConnectors()
        } catch {
            toastManager.show(style: .error, title: "Connect Failed", message: error.localizedDescription)
        }
    }

    private func disconnectConnector(_ id: String, name: String) async {
        do {
            _ = try await bridge.connectorDisconnect(connectorId: id)
            toastManager.show(style: .info, title: "Disconnected", message: name)
            await bridge.fetchConnectors()
        } catch {
            toastManager.show(style: .error, title: "Disconnect Failed", message: error.localizedDescription)
        }
    }

    private func deleteConnector(_ id: String, name: String) async {
        do {
            _ = try await bridge.connectorDelete(connectorId: id)
            toastManager.show(style: .info, title: "Deleted", message: name)
        } catch {
            toastManager.show(style: .error, title: "Delete Failed", message: error.localizedDescription)
        }
    }
}
