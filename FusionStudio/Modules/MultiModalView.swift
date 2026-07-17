import SwiftUI

// MARK: - 多模态任务类型

enum MultiModalTask: String, CaseIterable {
    case textToImage = "文生图"
    case imageToImage = "图生图"
    case ocr = "OCR 文字识别"
    case speechToText = "语音转文字"
    case textToSpeech = "文字转语音"
    case imageDescribe = "图片描述"

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
                            Label(task.rawValue, systemImage: task.icon)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(selectedTask == task ? task.color : nil)
                    }
                }
                .padding(8)
            }
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            HSplitView {
                // 左侧：输入
                VStack(spacing: 12) {
                    GroupBox("输入") {
                        VStack(alignment: .leading, spacing: 8) {
                            Picker("模型", selection: $selectedModel) {
                                ForEach(models, id: \.self) { m in Text(m).tag(m) }
                            }

                            if selectedTask == .textToImage || selectedTask == .imageToImage || selectedTask == .imageDescribe {
                                TextField("描述提示词...", text: $prompt, axis: .vertical)
                                    .textFieldStyle(.roundedBorder)
                                    .lineLimit(3...6)

                                if selectedTask == .textToImage {
                                    TextField("负面提示词（可选）", text: $negativePrompt, axis: .vertical)
                                        .textFieldStyle(.roundedBorder)
                                        .lineLimit(2...3)

                                    Picker("尺寸", selection: $imageSize) {
                                        ForEach(ImageSize.allCases, id: \.self) { s in Text(s.rawValue).tag(s) }
                                    }
                                    HStack {
                                        Text("质量: \(Int(quality))%")
                                        Slider(value: $quality, in: 10...100, step: 5)
                                    }
                                }

                                if selectedTask == .imageToImage || selectedTask == .imageDescribe || selectedTask == .ocr {
                                    HStack {
                                        Button("选择图片") { }
                                            .buttonStyle(.bordered)
                                        if selectedImageURL != nil {
                                            Text("已选择").font(.caption).foregroundColor(.green)
                                        }
                                    }
                                }
                            }

                            if selectedTask == .speechToText {
                                HStack {
                                    Button("选择音频文件") { }
                                        .buttonStyle(.bordered)
                                    Button("录制音频") { }
                                        .buttonStyle(.bordered)
                                }
                            }

                            if selectedTask == .textToSpeech {
                                TextField("输入要转语音的文字...", text: $prompt, axis: .vertical)
                                    .textFieldStyle(.roundedBorder)
                                    .lineLimit(3...6)
                            }

                            HStack {
                                Spacer()
                                Button(action: generate) {
                                    Label(isGenerating ? "生成中..." : "开始生成", systemImage: "play.fill")
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
                            Button("保存到工作区") { }
                                .buttonStyle(.borderedProminent)
                            Button("复制到剪贴板") {
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

                        Button("复制结果") {
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
                            Text("输入提示词并点击「开始生成」")
                                .foregroundColor(.secondary)
                            Text("调用 fusion-mlx \(selectedModel) 模型")
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
                DisclosureGroup("生成历史 (\(history.count))") {
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
        progress = 0
        let start = Date()

        // 模拟生成进度（实际应调用 fusion-mlx API）
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { timer in
            progress += Double.random(in: 0.05...0.15)
            if progress >= 1.0 {
                timer.invalidate()
                completeGeneration(start: start)
            }
        }

        // 模拟结果
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if selectedTask == .textToImage || selectedTask == .imageToImage {
                generatedImage = NSImage(systemSymbolName: "photo.fill", accessibilityDescription: nil)
                generatedText = ""
            } else {
                generatedImage = nil
                generatedText = "## 生成结果\n\n使用 fusion-mlx \(selectedModel) 模型\n\n**提示词**: \(prompt)\n\n这是 fusion-mlx 返回的模拟结果。实际使用时会调用 fusion-mlx HTTP API。"
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

            Text(isRecording ? "录制中..." : "点击开始录制")
                .font(.headline)

            if isRecording {
                Text(String(format: "%.1f", recordingDuration) + "s")
                    .font(.system(.body, design: .monospaced))
            }

            Button(action: toggleRecording) {
                Label(isRecording ? "停止录制" : "开始录制", systemImage: isRecording ? "stop.fill" : "record.circle")
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
                    Text("暂无图片").foregroundColor(.secondary)
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
                    Button("< 上一张") { selectedIndex = max(0, selectedIndex - 1) }
                        .disabled(selectedIndex == 0)
                    Text("\(selectedIndex + 1) / \(images.count)")
                    Button("下一张 >") { selectedIndex = min(images.count - 1, selectedIndex + 1) }
                        .disabled(selectedIndex == images.count - 1)
                }
            }
        }
    }
}