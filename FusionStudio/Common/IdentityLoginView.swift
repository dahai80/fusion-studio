import SwiftUI
import os.log

// #394 fusion-identity login sheet — shown when identity reachable + loggedOut.
struct IdentityLoginView: View {
    @StateObject private var i18n = I18nManager.shared
    @Environment(\.studioTheme) private var theme
    @ObservedObject var service: IdentityService

    @State private var username = ""
    @State private var password = ""
    @State private var error: String?
    @State private var submitting = false

    private let logger = Logger(subsystem: "com.fusion.studio", category: "identity.login")

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(i18n.t(.identity_login_title)).font(.title2.bold())
            TextField(i18n.t(.identity_login_username), text: $username)
                .textFieldStyle(.roundedBorder)
            SecureField(i18n.t(.identity_login_password), text: $password)
                .textFieldStyle(.roundedBorder)
            if let error = error {
                Text(error).foregroundStyle(.red).font(.caption)
            }
            Text(i18n.t(.identity_login_bootstrap_hint))
                .font(.caption2).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button {
                    Task { await submit() }
                } label: {
                    Label(i18n.t(.identity_login_submit), systemImage: "arrow.right.square.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(username.isEmpty || password.isEmpty || submitting)
            }
            if submitting { ProgressView().scaleEffect(0.8) }
        }
        .padding(24)
        .frame(width: 360)
        .background(theme.surfaceSecondary)
        .cornerRadius(12)
    }

    private func submit() async {
        submitting = true
        error = nil
        do {
            try await service.login(username: username, password: password)
            logger.info("login submitted: ok user=\(username, privacy: .public)")
        } catch {
            self.error = i18n.t(.identity_login_error)
            logger.error("login failed: \(error.localizedDescription)")
        }
        submitting = false
    }
}
