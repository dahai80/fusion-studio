// Callers: Design/Code/Science/KB chat panels — reuse Chat voice input pattern.
// Affected API: VoiceInputButton — mic toggle + volume slider + audio level + live transcript + voice mode.
// Data schemas: @Binding text, onSend callback, VoiceInputManager (SFSpeech zh-CN).
// User instruction: "排查所有对话框，都支持语音输入，都支持选择模型"

import SwiftUI
import os.log

private let voiceBtnLog = Logger(subsystem: "com.fusion.studio", category: "VoiceInputButton")

struct VoiceInputButton: View {
    @Environment(\.studioTheme) private var theme
    @ObservedObject var voice: VoiceInputManager
    @Binding var text: String
    let onSend: () -> Void

    @State private var showVolumeSlider: Bool = false
    @State private var isVoiceMode: Bool = false

    var body: some View {
        HStack(spacing: theme.spacingS) {
            micControl
            if showVolumeSlider {
                volumeSlider
                    .transition(.opacity)
            }
            if voice.isRecording {
                RoundedRectangle(cornerRadius: 1)
                    .fill(theme.accent)
                    .frame(width: max(2, CGFloat(voice.audioLevel) * 16), height: 4)
                    .animation(.easeInOut(duration: 0.1), value: voice.audioLevel)
            }
            if voice.isRecording && !voice.liveTranscript.isEmpty {
                Text(voice.liveTranscript)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
                    .frame(maxWidth: 120, alignment: .leading)
            }
            voiceModeToggle
        }
    }

    private var micControl: some View {
        Button {
            toggleRecording()
            showVolumeSlider = true
            voiceBtnLog.info("VoiceInputButton: showVolumeSlider=true, isRecording=\(voice.isRecording)")
        } label: {
            Image(systemName: voice.isRecording ? "mic.fill" : "mic")
                .font(.system(size: 16))
                .foregroundStyle(voice.isRecording ? theme.accent : theme.textSecondary)
        }
        .buttonStyle(.plain)
        .help(voice.isRecording ? "停止录音" : "语音输入")
    }

    private var volumeSlider: some View {
        HStack(spacing: 4) {
            Image(systemName: "speaker.wave.1")
                .font(.system(size: 10))
                .foregroundStyle(theme.textSecondary)
            Slider(value: Binding(
                get: { voice.inputVolume },
                set: { voice.setInputVolume($0) }
            ), in: 0...2)
            .frame(width: 80)
            .tint(theme.accent)
            Image(systemName: "speaker.wave.3")
                .font(.system(size: 10))
                .foregroundStyle(theme.textSecondary)
            Button {
                showVolumeSlider = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
    }

    private var voiceModeToggle: some View {
        Button {
            isVoiceMode.toggle()
            voiceBtnLog.info("Voice mode: \(isVoiceMode)")
        } label: {
            Image(systemName: isVoiceMode ? "waveform" : "waveform.badge.mic")
                .font(.system(size: 16))
                .foregroundStyle(isVoiceMode ? theme.accent : theme.textSecondary)
        }
        .buttonStyle(.plain)
        .help("语音模式（说完即发送）")
    }

    private func toggleRecording() {
        if voice.isRecording {
            let transcript = voice.stopRecording()
            let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            if isVoiceMode {
                text = trimmed
                onSend()
            } else {
                text += (text.isEmpty ? "" : " ") + trimmed
            }
        } else {
            voice.startRecording()
        }
    }
}
