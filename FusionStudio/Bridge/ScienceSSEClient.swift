import Foundation
import Combine
import os.log

private let sseLog = Logger(subsystem: "com.fusion.studio", category: "ScienceSSEClient")

@MainActor
class ScienceSSEClient: ObservableObject {
    @Published var streamingContent: String = ""
    @Published var isStreaming: Bool = false
    @Published var streamError: String?

    private var currentTask: URLSessionDataTask?
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }

    func streamChat(baseURL: String = FusionConfig.shared.scienceBaseURL, sessionId: String, message: String) {
        guard let url = URL(string: "\(baseURL)/api/v1/sessions/\(sessionId)/chat") else {
            sseLog.error("SSE: invalid URL")
            return
        }

        cancelStream()
        streamingContent = ""
        isStreaming = true
        streamError = nil

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["message": message, "stream": true]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let task = session.dataTask(with: request) { data, response, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isStreaming = false

                if let error = error {
                    let msg = error.localizedDescription
                    if !msg.contains("cancelled") {
                        sseLog.error("SSE stream error: \(msg)")
                        self.streamError = msg
                    }
                    return
                }

                guard let data = data else { return }
                if let text = String(data: data, encoding: .utf8) {
                    self.parseSSE(text)
                }
            }
        }
        currentTask = task
        task.resume()
        sseLog.info("SSE stream started for session \(sessionId)")
    }

    func cancelStream() {
        currentTask?.cancel()
        currentTask = nil
        isStreaming = false
    }

    private func parseSSE(_ text: String) {
        let lines = text.components(separatedBy: "\n")
        for line in lines {
            if line.hasPrefix("data: ") {
                let jsonString = String(line.dropFirst(6))
                if jsonString == "[DONE]" {
                    isStreaming = false
                    sseLog.info("SSE stream done, content length: \(self.streamingContent.count)")
                    return
                }
                if let data = jsonString.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let content = json["content"] as? String {
                        streamingContent += content
                    } else if let delta = json["delta"] as? [String: Any],
                              let content = delta["content"] as? String {
                        streamingContent += content
                    }
                } else {
                    streamingContent += jsonString
                }
            }
        }
    }
}
