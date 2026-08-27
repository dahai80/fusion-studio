import SwiftUI
import WebKit
import os.log

private let artifactsLog = Logger(subsystem: "com.fusion.studio", category: "ArtifactsPanel")

struct TemplatePickerSheet: View {
    @Environment(\.studioTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    let onSelect: (ArtifactTemplate) -> Void

    @State private var hoveredTemplate: String?
    @State private var selectedId: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Choose a Template")
                    .font(.system(size: theme.headlineSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: theme.iconM))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, theme.spacingXL)
            .padding(.top, theme.spacingL)
            .padding(.bottom, theme.spacingS)

            Text("Let's get cooking! Pick an artifact category or start building your idea from scratch.")
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, theme.spacingXL)
                .padding(.bottom, theme.spacingL)

            Rectangle().fill(theme.separator).frame(height: 1)

            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: theme.spacingM), count: 4),
                    spacing: theme.spacingM
                ) {
                    ForEach(artifactTemplates) { template in
                        templateCard(template)
                    }
                }
                .padding(theme.spacingXL)
            }

            if let selId = selectedId, let sel = artifactTemplates.first(where: { $0.id == selId }) {
                HStack {
                    Spacer()
                    Button("Cancel") { dismiss() }
                        .buttonStyle(.plain)
                        .foregroundStyle(theme.textSecondary)
                    Button(action: {
                        artifactsLog.info("Template confirmed: \(sel.id)")
                        onSelect(sel)
                    }) {
                        HStack(spacing: theme.spacingXS) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: theme.iconS))
                            Text("Continue")
                                .font(.system(size: theme.textSize, weight: .medium))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, theme.spacingL)
                        .padding(.vertical, theme.spacingS)
                        .background(
                            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                                .fill(theme.accent)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, theme.spacingXL)
                .padding(.vertical, theme.spacingM)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(width: 640, height: 480)
        .background(theme.contentBg)
        .animation(.easeInOut(duration: theme.animationFast), value: selectedId)
    }

    private func templateCard(_ template: ArtifactTemplate) -> some View {
        let isHovered = hoveredTemplate == template.id
        let isSelected = selectedId == template.id
        let isOtherSelected = selectedId != nil && !isSelected
        let color = template.kind.color

        return VStack(alignment: .leading, spacing: theme.spacingXS) {
            HStack(spacing: theme.spacingXS) {
                Image(systemName: template.icon)
                    .font(.system(size: theme.iconL))
                    .foregroundStyle(color)
                    .rotationEffect(.degrees(isHovered ? 2 : 0))
                    .scaleEffect(isHovered ? 1.05 : 1.0)

                Spacer()
            }

            Text(template.name)
                .font(.system(size: theme.captionSize, weight: .semibold))
                .foregroundStyle(theme.text)
                .lineLimit(1)

            Text(template.description)
                .font(.system(size: 9))
                .foregroundStyle(theme.textSecondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(theme.spacingM)
        .frame(minHeight: 112)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .fill(isSelected ? color.opacity(0.08) : (isHovered ? theme.surfaceElevated : theme.groupBg))
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .stroke(isSelected ? color : (isHovered ? color.opacity(0.4) : theme.groupBorder),
                        lineWidth: isSelected ? 2 : 1)
        )
        .opacity(isOtherSelected ? 0.5 : 1.0)
        .contentShape(Rectangle())
        .onHover { hovering in
            hoveredTemplate = hovering ? template.id : nil
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: theme.animationFast)) {
                selectedId = isSelected ? nil : template.id
            }
            artifactsLog.info("Template \(isSelected ? "deselected" : "selected"): \(template.id)")
        }
        .animation(.easeInOut(duration: 0.3), value: isHovered)
    }
}

// MARK: - ArtifactCreateChatSheet

