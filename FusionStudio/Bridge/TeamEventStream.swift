import Foundation
import os.log

private let teamStreamLog = Logger(subsystem: "com.fusion.studio", category: "TeamEventStream")

// M2-1: team.events WebSocket consumer. Mirrors EventBridge lifecycle (Task-based start/stop,
// exponential backoff reconnect, LRU-capped @Published events, scenePhase-gated) but uses
// URLSessionWebSocketTask (team.events is TCP WS on ws_port, NOT POSIX UDS like fusion-event).
// Auth: Sec-WebSocket-Protocol: Bearer <ws_token> header (M1-6).
// Subscribe frame: {"action":"subscribe","team":"<team>","last_event_id":<N>}
// Events: task.created, execution.progress/completed/cancelled/failed (5 types, M1-6).

@MainActor
final class TeamEventStream: ObservableObject {

    @Published var isConnected: Bool = false
    @Published var lastEventId: Int = 0
    @Published var events: [TeamEvent] = []

    static let maxEvents = 500

    private var webSocketTask: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var reconnectAttempt: Int = 0
    private var team: String = "default"
    private var wsURL: URL?
    private var wsToken: String = ""
    private var isStopped: Bool = false

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        return URLSession(configuration: config)
    }()

    // MARK: - Lifecycle

    func start(team: String, wsURL: URL, wsToken: String) {
        isStopped = false
        guard webSocketTask == nil else {
            teamStreamLog.info("TeamEventStream already connected, skip start")
            return
        }
        self.team = team
        self.wsURL = wsURL
        self.wsToken = wsToken
        teamStreamLog.info("TeamEventStream start team=\(team, privacy: .public) url=\(wsURL.absoluteString, privacy: .public)")
        connect()
    }

    func stop() {
        isStopped = true
        receiveTask?.cancel()
        receiveTask = nil
        reconnectTask?.cancel()
        reconnectTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
        teamStreamLog.info("TeamEventStream stopped")
    }

    deinit {
        receiveTask?.cancel()
        reconnectTask?.cancel()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
    }

    // MARK: - Connect + subscribe

    private func connect() {
        guard !isStopped, let url = wsURL else {
            teamStreamLog.error("TeamEventStream: no wsURL set")
            return
        }
        var request = URLRequest(url: url)
        if !wsToken.isEmpty {
            request.setValue("Bearer \(wsToken)", forHTTPHeaderField: "Sec-WebSocket-Protocol")
        }
        let task = session.webSocketTask(with: request)
        self.webSocketTask = task
        task.resume()
        teamStreamLog.info("TeamEventStream connecting...")
        sendSubscribe()
        startReceiveLoop()
    }

    private func sendSubscribe() {
        guard let task = webSocketTask else { return }
        let frame: [String: Any] = [
            "action": "subscribe",
            "team": team,
            "last_event_id": lastEventId,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: frame),
              let str = String(data: data, encoding: .utf8) else {
            teamStreamLog.error("TeamEventStream: subscribe frame encode failed")
            return
        }
        task.send(.string(str)) { [weak self] error in
            if let error = error {
                teamStreamLog.error("TeamEventStream subscribe send failed: \(error.localizedDescription, privacy: .public)")
                Task { @MainActor [weak self] in self?.handleDisconnect() }
            } else {
                teamStreamLog.info("TeamEventStream subscribe sent team=\(self?.team ?? "-", privacy: .public) lastEventId=\(self?.lastEventId ?? 0)")
            }
        }
    }

    // MARK: - Receive loop (callback-based recursive, mirror StreamingBridge.receiveWebSocketLoop)

    private func startReceiveLoop() {
        receiveTask?.cancel()
        receiveTask = Task { [weak self] in
            guard let self = self else { return }
            while !Task.isCancelled {
                do {
                    let msg = try await self.webSocketTask?.receive()
                    guard !Task.isCancelled else { break }
                    switch msg {
                    case .string(let text):
                        self.handleMessage(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            self.handleMessage(text)
                        }
                    case .none:
                        break
                    @unknown default:
                        break
                    }
                } catch {
                    if Task.isCancelled { break }
                    teamStreamLog.error("TeamEventStream receive error: \(error.localizedDescription, privacy: .public)")
                    self.handleDisconnect()
                    break
                }
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            teamStreamLog.warning("TeamEventStream: non-JSON frame: \(text.prefix(120))")
            return
        }
        let type = (json["type"] as? String) ?? ""

        // subscribed ack — mark connected, reset backoff
        if type == TeamEvent.subscribed {
            isConnected = true
            reconnectAttempt = 0
            let ackLast = (json["last_event_id"] as? Int) ?? lastEventId
            teamStreamLog.info("TeamEventStream subscribed ack lastEventId=\(ackLast)")
            return
        }

        // decode event
        guard let eventData = try? JSONSerialization.data(withJSONObject: json),
              let event = try? JSONDecoder().decode(TeamEvent.self, from: eventData) else {
            teamStreamLog.warning("TeamEventStream: decode failed for type=\(type, privacy: .public)")
            return
        }

        // mark connected on first real event (handshake confirmed)
        if !isConnected {
            isConnected = true
            reconnectAttempt = 0
        }

        // dedup by event_id (monotonic)
        if event.id > lastEventId {
            lastEventId = event.id
            events.append(event)
            trimEvents()
            teamStreamLog.info("TeamEventStream event type=\(event.type, privacy: .public) id=\(event.id) team=\(event.team, privacy: .public)")
        }
    }

    @MainActor
    private func handleDisconnect() {
        guard !isStopped else { return }
        isConnected = false
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        scheduleReconnect()
    }

    // MARK: - Reconnect (exponential backoff, mirror EventBridge.scheduleReconnect)

    private func scheduleReconnect() {
        guard !isStopped else { return }
        reconnectTask?.cancel()
        reconnectAttempt += 1
        let baseSec = min(5 * (1 << min(reconnectAttempt - 1, 4)), 60)
        let jitterMs = Int.random(in: 0..<1000)
        let delayNs = UInt64(baseSec) * 1_000_000_000 + UInt64(jitterMs) * 1_000_000
        teamStreamLog.info("TeamEventStream reconnect in \(baseSec)s+\(jitterMs)ms (attempt #\(self.reconnectAttempt))")
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delayNs)
            guard let self = self, !Task.isCancelled else { return }
            teamStreamLog.info("TeamEventStream reconnecting...")
            self.connect()
        }
    }

    @MainActor
    private func trimEvents() {
        while events.count > Self.maxEvents {
            events.removeFirst()
        }
    }
}
