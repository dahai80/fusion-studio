import SwiftUI

/// 关于页面
struct AboutView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bolt.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.linearGradient(
                    colors: [.purple, .orange],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            Text("Fusion Studio")
                .font(.largeTitle)
                .bold()

            Text("版本 0.1.1")
                .font(.title3)
                .foregroundColor(.secondary)

            Divider()
                .frame(width: 200)

            VStack(alignment: .leading, spacing: 8) {
                Label("macOS Apple Silicon 原生", systemImage: "cpu")
                Label("100% 本地离线", systemImage: "lock.shield")
                Label("一核九端 · 全生态收口", systemImage: "square.grid.3x3")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)

            Divider()
                .frame(width: 200)

            Text("© 2026 Fusion-MLX Team")
                .font(.caption)
                .foregroundColor(.secondary)

            Button("关闭") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .padding(40)
        .frame(width: 320)
    }
}