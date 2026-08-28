import Foundation
import Combine
import os.log
#if canImport( AVFoundation )
import AVFoundation
#endif

private let speechBridgeLog = Logger(subsystem: "com.fusion.studio", category: "SpeechBridge")

// #337: fusion-speech 守护 (UDS JSON-RPC 2.0, ~/.fusion-speech/run/fusion-speech.sock)。
// 本地低延迟语音: 流式 STT / TTS / 热词唤醒, 推理委托 fusion-mlx。守护 RC 0.1.0rc1。

enum SpeechError: Error, LocalizedError {
    case daemonDown
    case rpcError(code: Int, message: String)
    case invalidResponse
    case micDenied
    var errorDescription: String? {
        switch self {
        case .daemonDown: return "fusion-speech 守护未运行"
        case .rpcError(let c, let m): return "speech RPC 错误 (\(c)): \(m)"
        case .invalidResponse: return "speech 响应无效"
        case .micDenied: return "麦克风权限被拒"
        }
    }
}

struct SpeechStatus: Codable {
    let running: Bool?
    let socketPath: String?
    let port: Int?
    let uptime: Double?
    let listening: Bool?
    let sttModel: String?
    let ttsModel: String?
    let hotwords: [String]?

    enum CodingKeys: String, CodingKey {
        case running, port, uptime, listening, hotwords
        case socketPath = "socket_path"
        case sttModel = "stt_model"
        case ttsModel = "tts_model"
    }
}

struct SpeechTranscribeResult: Codable {
    let text: String
    let language: String?
    let duration: Double?
}

struct SpeechSynthesizeResult: Codable {
    let audio: String
    let format: String
    let size: Int
}

struct SpeechModelsResult: Codable {
    let total: Int
    let audioModels: [String]
    enum CodingKeys: String, CodingKey {
        case total
        case audioModels = "audio_models"
    }
}

// MARK: - SpeechBridge

final class SpeechBridge: ObservableObject {

    @Published var isDaemonReady: Bool = false
    @Published var isListening: Bool = false
    @Published var isArmed: Bool = false
    @Published var lastError: String?
    @Published var status: SpeechStatus?
    @Published var micPermission: MicPermission = .unknown
    @Published var availableModels: [String] = []
    @Published var hotwords: [String] = []
    @Published var partialTranscript: String = ""
    @Published var finalTranscript: String = ""

    enum MicPermission { case unknown, granted, denied }

    private let socketPath: String
    private var ipc: IPCClient?
    private var statusTask: Task<Void, Never>?

    init() {
        self.socketPath = FusionConfig.shared.expandedUpstreamPath(
            FusionConfig.shared.fusionSpeechSocketPath
        )
        speechBridgeLog.info("SpeechBridge init socket=\(self.socketPath, privacy: .public)")
    }

    func setIPCClient(_ client: IPCClient) {
        self.ipc = client
        speechBridgeLog.info("SpeechBridge IPCClient wired")
    }

    // MARK: - 守护状态

    func checkDaemonStatus() async {
        do {
            let res = try await rpc(method: "speech.status")
            if let data = try? JSONSerialization.data(withJSONObject: res),
               let parsed = try? JSONDecoder().decode(SpeechStatus.self, from: data) {
                await MainActor.run {
                    self.status = parsed
                    self.isDaemonReady = parsed.running ?? false
                    self.isListening = parsed.listening ?? false
                    self.hotwords = parsed.hotwords ?? []
                    self.lastError = nil
                }
                speechBridgeLog.info("speech.status ok running=\(parsed.running ?? false, privacy: .public) listening=\(parsed.listening ?? false, privacy: .public)")
            } else {
                await MainActor.run { self.isDaemonReady = true }
            }
        } catch {
            await MainActor.run {
                self.isDaemonReady = false
                self.lastError = error.localizedDescription
            }
            speechBridgeLog.warning("speech.status failed (daemon down?): \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - 麦克风权限

    func requestMicPermission() async {
        #if canImport( AVFoundation )
        // macOS 麦克风权限: AVCaptureDevice.requestAccess(for: .audio) (AVAudioApplication.requestAccess 仅 iOS 17+)。
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        await MainActor.run { self.micPermission = granted ? .granted : .denied }
        speechBridgeLog.info("mic permission result=\(granted, privacy: .public)")
        // #344: TCC 审计上报 fusion-guard (Phase 5, fire-and-forget 非阻塞, 守护缺席静默)。
        await GuardBridge.shared?.reportTcc(permission: "microphone", result: granted ? "granted" : "denied")
        if !granted {
            await MainActor.run { self.lastError = SpeechError.micDenied.localizedDescription }
        }
        #else
        await MainActor.run { self.micPermission = .denied }
        #endif
    }

    // MARK: - RPC 方法包装

    func ping() async throws -> Bool {
        let res = try await rpc(method: "speech.ping")
        return res["pong"] as? Bool ?? false
    }

    func transcribe(audioBase64: String, language: String? = nil, model: String? = nil, filename: String? = nil) async throws -> SpeechTranscribeResult {
        var params: [String: Any] = ["audio": audioBase64]
        if let language = language { params["language"] = language }
        if let model = model { params["model"] = model }
        if let filename = filename { params["filename"] = filename }
        let res = try await rpc(method: "speech.transcribe", params: params)
        guard let data = try? JSONSerialization.data(withJSONObject: res),
              let result = try? JSONDecoder().decode(SpeechTranscribeResult.self, from: data) else {
            throw SpeechError.invalidResponse
        }
        return result
    }

    func synthesize(text: String, voice: String? = nil, model: String? = nil) async throws -> SpeechSynthesizeResult {
        var params: [String: Any] = ["text": text]
        if let voice = voice { params["voice"] = voice }
        if let model = model { params["model"] = model }
        let res = try await rpc(method: "speech.synthesize", params: params)
        guard let data = try? JSONSerialization.data(withJSONObject: res),
              let result = try? JSONDecoder().decode(SpeechSynthesizeResult.self, from: data) else {
            throw SpeechError.invalidResponse
        }
        return result
    }

    func listModels() async throws -> SpeechModelsResult {
        let res = try await rpc(method: "speech.list_models")
        guard let data = try? JSONSerialization.data(withJSONObject: res),
              let result = try? JSONDecoder().decode(SpeechModelsResult.self, from: data) else {
            throw SpeechError.invalidResponse
        }
        await MainActor.run { self.availableModels = result.audioModels }
        return result
    }

    func startListening() async throws {
        let res = try await rpc(method: "speech.start_listening")
        let listening = res["listening"] as? Bool ?? true
        await MainActor.run { self.isListening = listening }
        speechBridgeLog.info("start_listening -> \(listening, privacy: .public)")
    }

    func stopListening() async throws -> Int {
        let res = try await rpc(method: "speech.stop_listening")
        let segments = res["segments"] as? Int ?? 0
        await MainActor.run { self.isListening = false }
        return segments
    }

    func setHotwords(_ words: [String]) async throws -> [String] {
        let res = try await rpc(method: "speech.set_hotwords", params: ["hotwords": words])
        let result = res["hotwords"] as? [String] ?? words
        await MainActor.run { self.hotwords = result }
        return result
    }

    func wake(arm: Bool) async throws -> Bool {
        let res = try await rpc(method: "speech.wake", params: ["arm": arm])
        let armed = res["armed"] as? Bool ?? arm
        let words = res["words"] as? [String] ?? []
        await MainActor.run {
            self.isArmed = armed
            self.hotwords = words
        }
        return armed
    }

    func speak(text: String, voice: String? = nil, model: String? = nil) async throws -> Bool {
        var params: [String: Any] = ["text": text]
        if let voice = voice { params["voice"] = voice }
        if let model = model { params["model"] = model }
        let res = try await rpc(method: "speech.speak", params: params)
        return res["played"] as? Bool ?? false
    }

    func stopTTS() async throws {
        _ = try await rpc(method: "speech.stop_tts")
    }

    func reprobe() async throws -> String? {
        let res = try await rpc(method: "speech.reprobe")
        return res["audio_lane"] as? String
    }

    // MARK: - UDS JSON-RPC 传输 (复用 IPCClient.udsCall 短连接换行分隔)

    private func rpc(method: String, params: [String: Any] = [:]) async throws -> [String: Any] {
        guard let ipc = ipc else {
            speechBridgeLog.error("rpc before IPCClient wired: \(method, privacy: .public)")
            throw SpeechError.daemonDown
        }
        do {
            let result = try await ipc.udsCall(socketPath: socketPath, method: method, params: params)
            return result
        } catch let ipcErr as IPCError {
            if case .disconnected = ipcErr { throw SpeechError.daemonDown }
            if case .rpcError(let code, let msg) = ipcErr { throw SpeechError.rpcError(code: code, message: msg) }
            throw SpeechError.invalidResponse
        } catch {
            throw SpeechError.daemonDown
        }
    }
}
