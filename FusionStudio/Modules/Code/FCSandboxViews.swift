import SwiftUI
import Foundation
import os.log

private let sandboxLog = Logger(subsystem: "com.fusion.studio", category: "FCSandbox")

enum FCSecurityMode: String, CaseIterable {
    case readonly = "readonly"
    case manual = "manual"
    case auto = "auto"

    var label: String {
        switch self {
        case .readonly: return "只读"
        case .manual: return "手动审批"
        case .auto: return "自动批准"
        }
    }

    var icon: String {
        switch self {
        case .readonly: return "lock.shield"
        case .manual: return "hand.raised"
        case .auto: return "bolt.shield"
        }
    }

    var color: Color {
        switch self {
        case .readonly: return .red
        case .manual: return .yellow
        case .auto: return .green
        }
    }
}

struct FCSandboxPolicy: Identifiable {
    let id = UUID()
    var securityMode: FCSecurityMode
    var allowedDirs: [String]
    var ignoredPatterns: [String]
}

struct FCAuditEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let action: String
    let target: String
    let allowed: Bool
    let reason: String

    var formattedTime: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: timestamp)
    }
}

class FCSandboxStore: ObservableObject {
    static let shared = FCSandboxStore()

    @Published var policy = FCSandboxPolicy(securityMode: .manual, allowedDirs: [], ignoredPatterns: [])
    @Published var auditLog: [FCAuditEntry] = []

    func setMode(_ mode: FCSecurityMode) {
        policy.securityMode = mode
        sandboxLog.info("sandbox mode set to \(mode.rawValue)")
    }

    func addAllowedDir(_ dir: String) {
        guard !policy.allowedDirs.contains(dir) else { return }
        policy.allowedDirs.append(dir)
        sandboxLog.info("allowed dir added: \(dir)")
    }

    func removeAllowedDir(_ dir: String) {
        policy.allowedDirs.removeAll { $0 == dir }
    }

    func addIgnoredPattern(_ pattern: String) {
        guard !policy.ignoredPatterns.contains(pattern) else { return }
        policy.ignoredPatterns.append(pattern)
        sandboxLog.info("ignore pattern added: \(pattern)")
    }

    func removeIgnoredPattern(_ pattern: String) {
        policy.ignoredPatterns.removeAll { $0 == pattern }
    }

    func logAction(action: String, target: String, allowed: Bool, reason: String = "") {
        let entry = FCAuditEntry(
            timestamp: Date(),
            action: action,
            target: target,
            allowed: allowed,
            reason: reason
        )
        auditLog.insert(entry, at: 0)
        if auditLog.count > 200 { auditLog = Array(auditLog.prefix(200)) }
    }

    func exportAuditLog() -> String {
        auditLog.map { entry in
            "\(entry.formattedTime) [\(entry.allowed ? "ALLOW" : "BLOCK")] \(entry.action) \(entry.target)\(entry.reason.isEmpty ? "" : " — \(entry.reason)")"
        }.joined(separator: "\n")
    }
}

struct FCSandboxPanel: View {
    @Environment(\.studioTheme) private var theme
    @ObservedObject var store = FCSandboxStore.shared
    @State private var newDir = ""
    @State private var newPattern = ""
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: theme.spacingS) {
            HStack {
                Text("Sandbox")
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                Spacer()
                modePicker
            }

            TabView(selection: $selectedTab) {
                policyTab
                    .tabItem { Label("策略", systemImage: "shield") }
                    .tag(0)
                auditTab
                    .tabItem { Label("审计", systemImage: "list.bullet.clipboard") }
                    .tag(1)
            }
            .frame(minHeight: 200, maxHeight: 350)
        }
        .padding(theme.spacingM)
    }

    private var modePicker: some View {
        HStack(spacing: 4) {
            ForEach(FCSecurityMode.allCases, id: \.self) { mode in
                Button(action: { store.setMode(mode) }) {
                    HStack(spacing: 3) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 9))
                        Text(mode.label)
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(store.policy.securityMode == mode ? .white : mode.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(store.policy.securityMode == mode ? mode.color : mode.color.opacity(0.15))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var policyTab: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Text("允许目录")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.textSecondary)

            ForEach(store.policy.allowedDirs, id: \.self) { dir in
                HStack {
                    Image(systemName: "folder")
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                    Text(dir)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                    Spacer()
                    Button(action: { store.removeAllowedDir(dir) }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 8))
                            .foregroundStyle(theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                TextField("添加目录...", text: $newDir)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 10))
                Button("Add") {
                    if !newDir.isEmpty {
                        store.addAllowedDir(newDir)
                        newDir = ""
                    }
                }
                .controlSize(.small)
            }

            Divider()

            Text("忽略模式 (.fusionignore)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.textSecondary)

            ForEach(store.policy.ignoredPatterns, id: \.self) { pattern in
                HStack {
                    Text(pattern)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(theme.text)
                    Spacer()
                    Button(action: { store.removeIgnoredPattern(pattern) }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 8))
                            .foregroundStyle(theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                TextField("添加模式...", text: $newPattern)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 10))
                Button("Add") {
                    if !newPattern.isEmpty {
                        store.addIgnoredPattern(newPattern)
                        newPattern = ""
                    }
                }
                .controlSize(.small)
            }
        }
    }

    private var auditTab: some View {
        VStack(spacing: 0) {
            if store.auditLog.isEmpty {
                Text("暂无审计记录")
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack {
                    Text("\(store.auditLog.count) 条记录")
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                    Spacer()
                    Button("导出") {
                        let text = store.exportAuditLog()
                        let panel = NSSavePanel()
                        panel.nameFieldStringValue = "sandbox-audit.log"
                        panel.begin { response in
                            if response == .OK, let url = panel.url {
                                try? text.write(to: url, atomically: true, encoding: .utf8)
                            }
                        }
                    }
                    .font(.system(size: 10))
                    .controlSize(.small)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)

                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(store.auditLog) { entry in
                            auditRow(entry)
                        }
                    }
                }
            }
        }
    }

    private func auditRow(_ entry: FCAuditEntry) -> some View {
        HStack(spacing: 4) {
            Text(entry.formattedTime)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(theme.textTertiary)
                .frame(width: 55, alignment: .leading)
            Text(entry.allowed ? "✓" : "✗")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(entry.allowed ? .green : .red)
                .frame(width: 12)
            Text(entry.action)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(theme.text)
                .frame(width: 60, alignment: .leading)
            Text(entry.target)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(theme.textSecondary)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }
}
