// Callers: all views via .toast() modifier
// Affected API: FusionToast view, FusionToastItem model, ToastStyle enum, FusionToastContainer modifier, FusionToastManager ObservableObject
// Data schemas: FusionToastItem (id: UUID, style: ToastStyle, title: String, message: String, duration: Double)
// User instruction: "落地外壳（SwiftUI）：负责 120fps 的极致交互、系统级感知（FSEvents, Accessibility）和沙箱管理。调用 frontend-design 来做好 UI 和 UX 交互设计"

import SwiftUI
import os.log

private let fusionToastLog = os.Logger(subsystem: "com.fusion.studio", category: "FusionToast")

enum ToastStyle {
    case success, warning, error, info
}

struct FusionToastItem: Identifiable, Equatable {
    let id: UUID
    let style: ToastStyle
    let title: String
    let message: String
    let duration: Double

    init(style: ToastStyle, title: String, message: String, duration: Double = 3.0) {
        self.id = UUID()
        self.style = style
        self.title = title
        self.message = message
        self.duration = duration
    }

    static func == (lhs: FusionToastItem, rhs: FusionToastItem) -> Bool {
        lhs.id == rhs.id
    }
}

class FusionToastManager: ObservableObject {
    @Published var items: [FusionToastItem] = []

    func show(style: ToastStyle, title: String, message: String, duration: Double = 3.0) {
        let item = FusionToastItem(style: style, title: title, message: message, duration: duration)
        fusionToastLog.info("FusionToast show: \(title, privacy: .public) style=\(String(describing: style))")
        DispatchQueue.main.async {
            self.items.append(item)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            self.dismiss(item.id)
        }
    }

    func dismiss(_ id: UUID) {
        fusionToastLog.info("FusionToast dismiss: \(id)")
        items.removeAll { $0.id == id }
    }
}

struct FusionToast: View {
    let item: FusionToastItem
    let onDismiss: () -> Void

    @Environment(\.studioTheme) var theme

    private var styleConfig: (icon: String, bg: Color, text: Color, iconColor: Color) {
        switch item.style {
        case .success: return ("checkmark.circle.fill", theme.successBg, theme.successText, theme.greenDot)
        case .warning: return ("exclamationmark.triangle.fill", theme.warningBg, theme.warningText, theme.amberDot)
        case .error:   return ("xmark.circle.fill", theme.errorBg, theme.errorText, theme.redDot)
        case .info:    return ("info.circle.fill", theme.infoBg, theme.infoText, theme.blueDot)
        }
    }

    var body: some View {
        let cfg = styleConfig
        HStack(spacing: theme.spacingS) {
            Image(systemName: cfg.icon)
                .font(.system(size: theme.iconM))
                .foregroundStyle(cfg.iconColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: theme.textSize, weight: .semibold))
                    .foregroundStyle(cfg.text)
                Text(item.message)
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(cfg.text.opacity(0.8))
                    .lineLimit(2)
            }

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: theme.iconXS, weight: .bold))
                    .foregroundStyle(cfg.text.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
        .background(cfg.bg)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .stroke(cfg.iconColor.opacity(0.2), lineWidth: 1)
        }
        .studioShadow(theme.shadowMedium)
    }
}

struct FusionToastContainer: ViewModifier {
    @ObservedObject var manager: FusionToastManager

    @Environment(\.studioTheme) var theme

    func body(content: Content) -> some View {
        content.overlay(alignment: .topTrailing) {
            VStack(spacing: theme.spacingS) {
                ForEach(manager.items) { item in
                    FusionToast(item: item) {
                        withAnimation(theme.springSnappy) {
                            manager.dismiss(item.id)
                        }
                    }
                    .transition(theme.transitionSlide)
                }
            }
            .padding(.top, 48)
            .padding(.trailing, theme.spacingL)
            .animation(theme.springSnappy, value: manager.items)
        }
    }
}

extension View {
    func toast(manager: FusionToastManager) -> some View {
        modifier(FusionToastContainer(manager: manager))
    }
}
