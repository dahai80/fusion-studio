import SwiftUI

struct FinanceCopilotPanel: View {
    @EnvironmentObject var financeBridge: FinanceBridge
    @State private var inputText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            Text("AI Copilot")
                .font(.headline)
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(Color.accentColor.opacity(0.1))

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(financeBridge.copilotMessages.indices, id: \.self) { idx in
                            let msg = financeBridge.copilotMessages[idx]
                            messageBubble(msg, index: idx)
                        }
                    }
                    .padding(10)
                }
                .onChange(of: financeBridge.copilotMessages.count) { _ in
                    if let last = financeBridge.copilotMessages.indices.last {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }

            Divider()

            HStack(spacing: 8) {
                TextField("输入问题…", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { send() }
                Button(action: send) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(10)
        }
        .frame(minWidth: 240)
    }

    private func messageBubble(_ msg: FinanceCopilotMessage, index: Int) -> some View {
        let isUser = msg.role == "user"
        return HStack {
            if isUser { Spacer() }
            Text(msg.content)
                .font(.subheadline)
                .padding(8)
                .background(isUser ? Color.accentColor.opacity(0.15) : Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .frame(maxWidth: 260, alignment: isUser ? .trailing : .leading)
            if !isUser { Spacer() }
        }
        .id(index)
    }

    private func send() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        inputText = ""
        financeBridge.copilotChat(message: text)
    }
}
