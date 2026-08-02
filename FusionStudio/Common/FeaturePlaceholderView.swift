import SwiftUI

struct FeaturePlaceholderView: View {
    @Environment(\.studioTheme) private var theme

    let featureName: String
    var methodName: String = ""

    var body: some View {
        VStack(spacing: theme.spacingM) {
            Image(systemName: "hammer.and.wrench")
                .font(.system(size: 28))
                .foregroundStyle(theme.textTertiary)
            Text(featureName)
                .font(.system(size: theme.captionSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)
            Text("功能开发中")
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textTertiary)
            if !methodName.isEmpty {
                Text("RPC: \(methodName)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(theme.textTertiary.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(theme.spacingL)
    }
}
