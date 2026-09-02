// Callers: ModuleDetailView routing.
// Affected API: MultiModalView (replacing NSColor with StudioTheme tokens).
// Data schemas: None changed.
// User instruction: "帮我用 UI/UX Pro Max 重新设计 fusion-studio 的整体 GUI - macOS 原生风格 - 三栏 - 暗色模式优先 - 主色 #007AFF"

import SwiftUI
import os.log

private let mmlLog = Logger(subsystem: "com.fusion.studio", category: "MultiModal")

// MARK: - 多模态任务类型

enum MultiModalTask: String, CaseIterable {
    case textToImage
    case imageToImage
    case ocr
    case speechToText
    case textToSpeech
    case imageDescribe

    var localizedName: String {
        switch self {
        case .textToImage:   return I18nManager.shared.t(.mml_task_text_to_image)
        case .imageToImage:  return I18nManager.shared.t(.mml_task_image_to_image)
        case .ocr:           return I18nManager.shared.t(.mml_task_ocr)
        case .speechToText:  return I18nManager.shared.t(.mml_task_speech_to_text)
        case .textToSpeech:  return I18nManager.shared.t(.mml_task_text_to_speech)
        case .imageDescribe: return I18nManager.shared.t(.mml_task_image_describe)
        }
    }

    var icon: String {
        switch self {
        case .textToImage:   return "photo.on.rectangle"
        case .imageToImage:  return "arrow.triangle.2.circlepath"
        case .ocr:           return "doc.text.viewfinder"
        case .speechToText:  return "waveform"
        case .textToSpeech:  return "speaker.wave.2"
        case .imageDescribe: return "eye"
        }
    }
    var color: Color {
        switch self {
        case .textToImage:   return .blue
        case .imageToImage:  return .green
        case .ocr:           return .orange
        case .speechToText:  return .purple
        case .textToSpeech:  return .pink
        case .imageDescribe: return .indigo
        }
    }
}

// MARK: - 生成历史

struct GenerationRecord: Identifiable {
    let id = UUID()
    let task: MultiModalTask
    let prompt: String
    let result: String
    let imageData: Data?
    let timestamp: Date
    let model: String
    let duration: Double
}

// MARK: - 多模态面板

struct MultiModalView: View {
    @Environment(\.studioTheme) private var theme
    @State private var selectedTask: MultiModalTask = .textToImage
    @State private var prompt = ""
    @State private var negativePrompt = ""
    @State private var selectedModel = "sdxl"
    @State private var imageSize: ImageSize = .square
    @State private var quality = 85.0
    @State private var generatedImage: NSImage?
    @State private var generatedText = ""
    @State private var isGenerating = false
    @State private var progress: Double = 0
    @State private var history: [GenerationRecord] = []
    @State private var selectedImageURL: URL?

    enum ImageSize: String, CaseIterable {
        case square = "1024x1024"
        case landscape = "1280x720"
        case portrait = "720x1280"
        case wide = "1920x1080"
    }

    let models = ["sdxl", "sd3.5-medium", "qwen2-vl-7b", "whisper-large-v3"]

    var body: some View {
        VStack(spacing: 0) {
            // 任务选择
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(MultiModalTask.allCases, id: \.self) { task in
                        Button(action: { selectedTask = task }) {
                            Label(task.localizedName, systemImage: task.icon)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(selectedTask == task ? task.color : nil)
                    }
                }
                .padding(8)
            }
            .background(theme.surfaceSecondary)

            Divider()

            HSplitView {
                // 左侧：输入
                VStack(spacing: 12) {
                    GroupBox(I18nManager.shared.t(.mml_group_input)) {
                        VStack(alignment: .leading, spacing: 8) {
                            Picker(I18nManager.shared.t(.mml_pick_model), selection: $selectedModel) {
                                ForEach(models, id: \.self) { m in Text(m).tag(m) }
                            }

                            if selectedTask == .textToImage || selectedTask == .imageToImage || selectedTask == .imageDescribe {
                                TextField(I18nManager.shared.t(.mml_tf_prompt), text: $prompt, axis: .vertical)
                                    .textFieldStyle(.roundedBorder)
                                    .lineLimit(3...6)

                                if selectedTask == .textToImage {
                                    TextField(I18nManager.shared.t(.mml_tf_negative_prompt), text: $negativePrompt, axis: .vertical)
                                        .textFieldStyle(.roundedBorder)
                                        .lineLimit(2...3)

                                    Picker(I18nManager.shared.t(.mml_pick_size), selection: $imageSize) {
                                        ForEach(ImageSize.allCases, id: \.self) { s in Text(s.rawValue).tag(s) }
                                    }
                                    HStack {
                                        Text(I18nManager.shared.tf(.mml_quality_fmt, Int(quality)))
                                        Slider(value: $quality, in: 10...100, step: 5)
                                    }
                                }

                                if selectedTask == .imageToImage || selectedTask == .imageDescribe || selectedTask == .ocr {
                                    HStack {
                                        Button(I18nManager.shared.t(.mml_btn_select_image)) { }
                                            .buttonStyle(.bordered)
                                        if selectedImageURL != nil {
                                            Text(I18nManager.shared.t(.mml_selected)).font(.caption).foregroundColor(.green)
                                        }
                                    }
                                }
                            }

                            if selectedTask == .speechToText {
                                HStack {
                                    Button(I18nManager.shared.t(.mml_btn_select_audio)) { }
                                        .buttonStyle(.bordered)
                                    Button(I18nManager.shared.t(.mml_btn_record)) { }
                                        .buttonStyle(.bordered)
                                }
                            }

                            if selectedTask == .textToSpeech {
                                TextField(I18nManager.shared.t(.mml_tf_tts_text), text: $prompt, axis: .vertical)
                                    .textFieldStyle(.roundedBorder)
                                    .lineLimit(3...6)
                            }

                            HStack {
                                Spacer()
                                Button(action: generate) {
                                    Label(isGenerating ? I18nManager.shared.t(.mml_generating) : I18nManager.shared.t(.mml_btn_generate), systemImage: "play.fill")
                                        .frame(width: 120)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(prompt.isEmpty || isGenerating)
                                Spacer()
                            }
                        }
                        .padding(8)
                    }
                    .padding(.horizontal)

                    if isGenerating {
                        VStack(spacing: 4) {
                            ProgressView(value: progress)
                            Text("\(Int(progress * 100))%").font(.caption).foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                    }

                    Spacer()
                }
                .frame(minWidth: 280, maxWidth: 350)

                // 右侧：结果
                VStack {
                    if let image = generatedImage {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(8)
                            .padding()

                        HStack(spacing: 8) {
                            Button(I18nManager.shared.t(.mml_btn_save)) { }
                                .buttonStyle(.borderedProminent)
                            Button(I18nManager.shared.t(.mml_btn_copy_clipboard)) {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.writeObjects([image])
                            }
                            .buttonStyle(.bordered)
                        }
                    } else if !generatedText.isEmpty {
                        ScrollView {
                            Text(generatedText)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .padding()
                        }

                        Button(I18nManager.shared.t(.mml_btn_copy_result)) {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(generatedText, forType: .string)
                        }
                        .buttonStyle(.bordered)
                    } else {
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: selectedTask.icon)
                                .font(.system(size: 48))
                                .foregroundColor(selectedTask.color.opacity(0.5))
                            Text(I18nManager.shared.t(.mml_empty_hint))
                                .foregroundColor(.secondary)
                            Text(I18nManager.shared.tf(.mml_model_hint_fmt, selectedModel))
                                .font(.caption).foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                }
                .frame(minWidth: 300)
            }

            // 历史记录
            if !history.isEmpty {
                Divider()
                DisclosureGroup(I18nManager.shared.tf(.mml_history_fmt, history.count)) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(history.reversed()) { record in
                                VStack(spacing: 4) {
                                    if let data = record.imageData, let img = NSImage(data: data) {
                                        Image(nsImage: img)
                                            .resizable()
                                            .frame(width: 60, height: 60)
                                            .cornerRadius(4)
                                    } else {
                                        Image(systemName: record.task.icon)
                                            .foregroundColor(record.task.color)
                                    }
                                    Text(record.prompt.prefix(20))
                                        .font(.system(size: 8))
                                        .lineLimit(1)
                                }
                                .frame(width: 70)
                            }
                        }
                        .padding(8)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func generate() {
        isGenerating = true
        progress = 0.1
        generatedText = ""
        generatedImage = nil
        let start = Date()

        // 调用 fusion-mlx 的真实 API
        let promptText = prompt
        let taskType = selectedTask

        Task {
            do {
                // 通过 fusion-mlx HTTP API 调用
                switch taskType {
                case .textToImage, .imageToImage:
                    // F-ft-5: 旧 URL(string:)! 在 mlxBaseURL 含非法字符时 fatalError。
                    guard let url = URL(string: FusionConfig.shared.mlxBaseURL + "/v1/images/generations") else {
                        mmlLog.error("F-ft-5: invalid images/generations URL, base=\(FusionConfig.shared.mlxBaseURL)")
                        throw URLError(.badURL)
                    }
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    let body: [String: Any] = [
                        "model": selectedModel,
                        "prompt": promptText,
                        "n": 1,
                        "size": imageSize.rawValue
                    ]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)
                    request.timeoutInterval = 120
                    let (data, response) = try await URLSession.shared.data(for: request)
                    if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 {
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let dataArr = json["data"] as? [[String: Any]],
                           let b64 = dataArr.first?["b64_json"] as? String,
                           let imgData = Data(base64Encoded: b64),
                           let img = NSImage(data: imgData) {
                            await MainActor.run { self.generatedImage = img }
                        }
                    }
                case .speechToText:
                    // 调用 fusion-mlx 语音识别 API
                    // F-ft-5: guard 替代 force-unwrap, 防 mlxBaseURL 非法时 fatalError。
                    guard let url = URL(string: FusionConfig.shared.mlxBaseURL + "/v1/audio/transcriptions") else {
                        mmlLog.error("F-ft-5: invalid audio/transcriptions URL, base=\(FusionConfig.shared.mlxBaseURL)")
                        throw URLError(.badURL)
                    }
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.timeoutInterval = 120
                    let (data, _) = try await URLSession.shared.data(for: request)
                    let result = String(data: data, encoding: .utf8) ?? ""
                    await MainActor.run { self.generatedText = result }
                case .textToSpeech:
                    // F-ft-5: guard 替代 force-unwrap, 防 mlxBaseURL 非法时 fatalError。
                    guard let url = URL(string: FusionConfig.shared.mlxBaseURL + "/v1/audio/speech") else {
                        mmlLog.error("F-ft-5: invalid audio/speech URL")
                        throw URLError(.badURL)
                    }
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    let body: [String: Any] = ["model": selectedModel, "input": promptText, "voice": "alloy"]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)
                    request.timeoutInterval = 120
                    let (data, _) = try await URLSession.shared.data(for: request)
                    await MainActor.run { self.generatedText = I18nManager.shared.tf(.mml_audio_generated_fmt, data.count) }
                case .ocr, .imageDescribe:
                    // 调用 fusion-mlx 视觉模型 API
                    // F-ft-5: guard 替代 force-unwrap, 防 mlxBaseURL 非法时 fatalError。
                    guard let url = URL(string: FusionConfig.shared.mlxBaseURL + "/v1/chat/completions") else {
                        mmlLog.error("F-ft-5: invalid chat/completions URL")
                        throw URLError(.badURL)
                    }
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    let messages: [[String: Any]] = [
                        ["role": "user", "content": [
                            // DEFERRED i18n: LLM prompt content (API payload, not UI) — see DesignBridge precedent
                            ["type": "text", "text": taskType == .ocr ? "请识别图片中的文字" : "请描述图片内容"],
                        ]]
                    ]
                    let body: [String: Any] = ["model": selectedModel, "messages": messages, "max_tokens": 1024]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)
                    request.timeoutInterval = 120
                    let (data, _) = try await URLSession.shared.data(for: request)
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let choices = json["choices"] as? [[String: Any]],
                       let msg = choices.first?["message"] as? [String: Any],
                       let content = msg["content"] as? String {
                        await MainActor.run { self.generatedText = content }
                    }
                }
                await MainActor.run {
                    self.progress = 1.0
                    self.completeGeneration(start: start)
                }
            } catch {
                await MainActor.run {
                    self.generatedText = I18nManager.shared.tf(.mml_error_fmt, error.localizedDescription, FusionConfig.shared.mlxBaseURL)
                    self.progress = 1.0
                    self.isGenerating = false
                }
            }
        }
    }

    private func completeGeneration(start: Date) {
        let duration = Date().timeIntervalSince(start)
        let record = GenerationRecord(
            task: selectedTask,
            prompt: prompt,
            result: generatedText,
            imageData: generatedImage?.tiffRepresentation,
            timestamp: Date(),
            model: selectedModel,
            duration: duration
        )
        history.append(record)
        if history.count > 50 { history.removeFirst(history.count - 50) }
        isGenerating = false
        progress = 0
    }
}

// MARK: - 语音录制组件

struct AudioRecorderView: View {
    @State private var isRecording = false
    @State private var recordingDuration: TimeInterval = 0
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: isRecording ? "waveform.circle.fill" : "mic.circle")
                .font(.system(size: 48))
                .foregroundColor(isRecording ? .red : .accentColor)

            Text(isRecording ? I18nManager.shared.t(.mml_recording) : I18nManager.shared.t(.mml_click_to_record))
                .font(.headline)

            if isRecording {
                Text(String(format: "%.1f", recordingDuration) + "s")
                    .font(.system(.body, design: .monospaced))
            }

            Button(action: toggleRecording) {
                Label(isRecording ? I18nManager.shared.t(.mml_btn_stop_record) : I18nManager.shared.t(.mml_btn_start_record), systemImage: isRecording ? "stop.fill" : "record.circle")
            }
            .buttonStyle(.borderedProminent)
            .tint(isRecording ? .red : .accentColor)
        }
        .padding()
        .frame(width: 200, height: 200)
    }

    private func toggleRecording() {
        if isRecording {
            timer?.invalidate()
            timer = nil
            isRecording = false
        } else {
            recordingDuration = 0
            isRecording = true
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                recordingDuration += 0.1
            }
        }
    }
}

// MARK: - 图片浏览器

struct ImageGalleryView: View {
    let images: [NSImage]
    @State private var selectedIndex = 0

    var body: some View {
        VStack {
            if images.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle").font(.system(size: 40)).foregroundColor(.secondary)
                    Text(I18nManager.shared.t(.mml_no_images)).foregroundColor(.secondary)
                }
            } else {
                TabView(selection: $selectedIndex) {
                    ForEach(images.indices, id: \.self) { i in
                        Image(nsImage: images[i])
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .tag(i)
                    }
                }
                .tabViewStyle(.automatic)

                HStack {
                    Button(I18nManager.shared.t(.mml_btn_prev)) { selectedIndex = max(0, selectedIndex - 1) }
                        .disabled(selectedIndex == 0)
                    Text("\(selectedIndex + 1) / \(images.count)")
                    Button(I18nManager.shared.t(.mml_btn_next)) { selectedIndex = min(images.count - 1, selectedIndex + 1) }
                        .disabled(selectedIndex == images.count - 1)
                }
            }
        }
    }
}