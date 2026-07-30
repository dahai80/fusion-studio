// Callers: UnifiedChatView chatInputBox.
// Affected API: SendableTextEditor — NSViewRepresentable wrapping NSTextView, Enter-to-send, auto-refocus.
// Data schemas: @Binding text, onSend callback. User instruction: "bug29 输入框大模型回复后无法再次输入"
// Fix: onSend 后 makeFirstResponder; updateNSView 清空 text 时保持焦点

import SwiftUI
import os.log

private let sendableLog = Logger(subsystem: "com.fusion.studio", category: "SendableTextEditor")

struct SendableTextEditor: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    var font: NSFont = .systemFont(ofSize: 14)
    var textColor: NSColor = .textColor
    var placeholderColor: NSColor = .tertiaryLabelColor
    var maxHeight: CGFloat = 88
    var onSend: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.verticalScroller?.controlSize = .small
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        let textView = SendableTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.font = font
        textView.textColor = textColor
        textView.insertionPointColor = textColor
        textView.onSend = onSend
        textView.maxHeight = maxHeight

        let container = textView.textContainer!
        container.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        container.widthTracksTextView = true
        container.lineBreakMode = .byWordWrapping

        scrollView.documentView = textView
        scrollView.contentView.postsBoundsChangedNotifications = true

        context.coordinator.textView = textView
        context.coordinator.updatePlaceholder()

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? SendableTextView else { return }
        context.coordinator.parent = self
        textView.onSend = onSend
        textView.maxHeight = maxHeight

        if textView.string != text {
            let wasFirstResponder = textView.window?.firstResponder == textView
            textView.string = text
            textView.invalidateIntrinsicContentSize()
            if wasFirstResponder && text.isEmpty {
                DispatchQueue.main.async {
                    textView.window?.makeFirstResponder(textView)
                }
            }
        }
        textView.font = font
        textView.textColor = textColor
        context.coordinator.updatePlaceholder()
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SendableTextEditor
        weak var textView: SendableTextView?
        private var placeholderTextView: NSTextView?

        init(_ parent: SendableTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = textView else { return }
            parent.text = textView.string
            textView.invalidateIntrinsicContentSize()
            updatePlaceholder()
        }

        func updatePlaceholder() {
            guard let textView = textView else { return }
            if textView.string.isEmpty {
                if placeholderTextView == nil {
                    let ph = NSTextView()
                    ph.isEditable = false
                    ph.isSelectable = false
                    ph.drawsBackground = false
                    ph.isRichText = false
                    ph.font = parent.font
                    ph.textColor = parent.placeholderColor
                    ph.string = parent.placeholder
                    ph.textContainerInset = textView.textContainerInset
                    ph.textContainer?.lineBreakMode = .byWordWrapping
                    textView.addSubview(ph)
                    placeholderTextView = ph
                    ph.translatesAutoresizingMaskIntoConstraints = false
                    ph.topAnchor.constraint(equalTo: textView.topAnchor).isActive = true
                    ph.leadingAnchor.constraint(equalTo: textView.leadingAnchor).isActive = true
                    ph.trailingAnchor.constraint(equalTo: textView.trailingAnchor).isActive = true
                    ph.bottomAnchor.constraint(equalTo: textView.bottomAnchor).isActive = true
                }
                placeholderTextView?.isHidden = false
            } else {
                placeholderTextView?.isHidden = true
            }
        }
    }
}

class SendableTextView: NSTextView {
    var onSend: (() -> Void)?
    var maxHeight: CGFloat = 88

    override var intrinsicContentSize: NSSize {
        guard let container = textContainer, let manager = layoutManager else {
            return super.intrinsicContentSize
        }
        manager.ensureLayout(for: container)
        let rect = manager.usedRect(for: container)
        let height = min(rect.height + textContainerInset.height * 2, maxHeight)
        return NSSize(width: NSView.noIntrinsicMetric, height: height)
    }

    override func keyDown(with event: NSEvent) {
        let isReturn = event.keyCode == 36
        let isShift = event.modifierFlags.contains(.shift)

        if isReturn && isShift {
            super.keyDown(with: event)
            return
        }
        if isReturn {
            onSend?()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.window?.makeFirstResponder(self)
            }
            return
        }
        super.keyDown(with: event)
    }
}
