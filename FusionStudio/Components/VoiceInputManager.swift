// Callers: UnifiedChatView mic button + voice mode toggle.
// Affected API: VoiceInputManager.startRecording/stopRecording → liveTranscript → UnifiedChatView inputText.
// Data schemas: SFSpeechAudioBufferRecognitionRequest, AVAudioEngine buffer tap.
// User instruction: "bug36、没有实现右下角麦克风和语音的功能，这个要落地"

import SwiftUI
import AVFoundation
import Speech
import os.log

@MainActor
class VoiceInputManager: ObservableObject {
    @Published var isRecording: Bool = false
    @Published var liveTranscript: String = ""
    @Published var isAvailable: Bool = false
    @Published var audioLevel: Float = 0.0
    @Published var inputVolume: Float = 1.0

    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var levelTimer: Timer?
    private let log = Logger(subsystem: "com.fusion.studio", category: "VoiceInput")

    init() {
        checkAvailability()
    }

    private func checkAvailability() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                let ok = status == .authorized
                self?.isAvailable = ok
                self?.log.info("Speech auth: \(status.rawValue), available=\(ok)")
            }
        }
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            Task { @MainActor in
                let current = self?.isAvailable ?? false
                self?.isAvailable = current && granted
                self?.log.info("Mic permission: \(granted)")
            }
        }
    }

    func startRecording() {
        guard !isRecording else { return }
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            log.error("Speech recognizer not available")
            return
        }

        let engine = AVAudioEngine()
        let node = engine.inputNode
        let format = node.outputFormat(forBus: 0)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        recognitionRequest = request

        node.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            request.append(buffer)
            let channelData = buffer.floatChannelData?[0]
            let frameLength = Int(buffer.frameLength)
            guard frameLength > 0, let data = channelData else { return }
            var sum: Float = 0
            for i in 0..<frameLength {
                sum += data[i] * data[i]
            }
            let rms = sqrt(sum / Float(frameLength))
            let db = 20 * log10(max(rms, 0.00001))
            let normalized = max(0, min(1, (db + 60) / 60))
            Task { @MainActor in
                self?.audioLevel = normalized
            }
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            log.error("Audio engine start failed: \(error.localizedDescription)")
            return
        }

        node.volume = inputVolume

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                if let result = result {
                    self?.liveTranscript = result.bestTranscription.formattedString
                }
                if error != nil || result?.isFinal == true {
                    self?.stopRecording()
                }
            }
        }

        audioEngine = engine
        isRecording = true
        liveTranscript = ""
        log.info("Recording started")
    }

    func stopRecording() -> String {
        let transcript = liveTranscript

        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        levelTimer?.invalidate()
        levelTimer = nil
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
        audioLevel = 0
        log.info("Recording stopped, transcript='\(transcript.prefix(100))'")
        return transcript
    }

    func setInputVolume(_ volume: Float) {
        inputVolume = volume
        audioEngine?.inputNode.volume = volume
        log.info("Input volume set to \(volume)")
    }
}
