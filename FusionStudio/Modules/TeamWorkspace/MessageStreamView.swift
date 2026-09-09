import SwiftUI
import os.log

private let messageStreamLog = Logger(subsystem: "com.fusion.studio", category: "MessageStreamView")

// M2-4: Plaza message timeline + break_in. Read-only message stream from
// team.plaza_messages (channel=team_<team>). break_in sends highest-priority
// message to Lead via team.plaza_break_in RPC (daemon hard-gate).
// GUI 不做本地状态 — daemon SSOT, refresh on appear + manual reload.
struct MessageStreamView: View {
    @EnvironmentObject var teamBridge: TeamBridge
    @State private var breakInText: String = ""
    @State private var isSendingBreakIn: Bool = false
    @State private var breakInResult: String?

    var body: some View {
        VStack(spacing: 0) {
            breakInBar
            Divider()
            if teamBridge.messages.isEmpty {
                emptyState
            } else {
                messageList
            }
        }
        .onAppear {
            Task { await teamBridge.refreshMessages() }
            messageStreamLog.info("MessageStreamView appeared team=\(teamBridge.selectedTeam, privacy: .public)")
        }
    }

    // MARK: - Break-in bar

    private var breakInBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.bubble.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 13))
                TextField("break_in message to Lead...", text: $breakInText, axis: .vertical)
                    .font(.system(size: 13))
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
                Button {
                    sendBreakIn()
                } label: {
                    HStack(spacing: 4) {
                        if isSendingBreakIn {
                            ProgressView().scaleEffect(0.6)
                        } else {
                            Image(systemName: "paperplane.fill")
                        }
                        Text("Break-in")
                    }
                    .font(.system(size: 12, weight: .medium))
                }
                .disabled(breakInText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSendingBreakIn)
            }
            if let result = breakInResult {
                Text(result)
                    .font(.system(size: 11))
                    .foregroundColor(result.hasPrefix("Error") ? .red : .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
    }

    // MARK: - Message list

    private var messageList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(teamBridge.messages) { msg in
                    PlazaMessageRow(message: msg)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("No plaza messages")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Text("Messages from team agents will appear here")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Break-in action

    private func sendBreakIn() {
        let trimmed = breakInText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSendingBreakIn = true
        breakInResult = nil
        messageStreamLog.info("break_in send team=\(teamBridge.selectedTeam, privacy: .public) msg_len=\(trimmed.count)")
        Task {
            do {
                let res = try await teamBridge.sendBreakIn(message: trimmed)
                let status = (res["status"] as? String) ?? "sent"
                breakInResult = "Break-in \(status)"
                breakInText = ""
                await teamBridge.refreshMessages()
            } catch {
                breakInResult = "Error: \(BridgeError.sanitize(error))"
                messageStreamLog.warning("break_in failed: \(error.localizedDescription, privacy: .public)")
            }
            isSendingBreakIn = false
        }
    }
}

// MARK: - Message row

private struct PlazaMessageRow: View {
    let message: PlazaMessage

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 20))
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(message.sender.isEmpty ? "unknown" : message.sender)
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Text(formatTimestamp(message.ts))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Text(message.content)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !message.channel.isEmpty {
                    Text(message.channel)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .overlay(Divider().frame(maxWidth: .infinity).padding(.leading, 42), alignment: .bottom)
    }

    private func formatTimestamp(_ ts: Double) -> String {
        guard ts > 0 else { return "" }
        let date = Date(timeIntervalSince1970: ts)
        let fmt = DateFormatter()
        fmt.dateStyle = .none
        fmt.timeStyle = .medium
        return fmt.string(from: date)
    }
}
