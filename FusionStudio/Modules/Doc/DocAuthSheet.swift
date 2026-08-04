// IMPORTERS/CALLERS: DocSidebar connectionBar (sheet)
// AFFECTED API: DocBridge — authSetup, authLogin
// DATA SCHEMAS: DocAuthSetup, DocAuthLogin, DocAuthResponse
// USER INSTRUCTION: "立即启动4项GUI增强 — auth登录界面"

import SwiftUI
import os.log

private let docAuthLog = Logger(subsystem: "com.fusion.studio", category: "DocAuthSheet")

struct DocAuthSheet: View {
    @Environment(\.studioTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var bridge: DocBridge
    @State private var mode: AuthMode = .login
    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private enum AuthMode: String, CaseIterable {
        case login = "登录"
        case setup = "初始设置"
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Fusion Doc 认证")
                .font(.title2)
                .fontWeight(.semibold)

            Picker("模式", selection: $mode) {
                ForEach(AuthMode.allCases, id: \.self) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 240)

            VStack(spacing: 10) {
                TextField("用户名", text: $username)
                    .textFieldStyle(.roundedBorder)
                SecureField("密码", text: $password)
                    .textFieldStyle(.roundedBorder)
                if mode == .setup {
                    SecureField("确认密码", text: $confirmPassword)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .frame(width: 240)

            if let err = errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(width: 240, alignment: .leading)
            }

            if let authErr = bridge.authError {
                Text(authErr)
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(width: 240, alignment: .leading)
            }

            HStack(spacing: 12) {
                Button("取消") { dismiss() }
                Button(action: performAuth) {
                    HStack(spacing: 4) {
                        if isLoading { ProgressView().controlSize(.small) }
                        Text(mode == .login ? "登录" : "创建管理员")
                    }
                }
                .disabled(!canSubmit || isLoading)
                .buttonStyle(.borderedProminent)
            }

            if bridge.isAuthenticated {
                Label("已认证 ✓", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
        }
        .padding(24)
        .frame(width: 320)
        .background(theme.surfacePrimary)
    }

    private var canSubmit: Bool {
        guard !username.isEmpty, !password.isEmpty else { return false }
        if mode == .setup { return password == confirmPassword }
        return true
    }

    private func performAuth() {
        isLoading = true
        errorMessage = nil
        docAuthLog.info("performAuth mode=\(mode.rawValue) user=\(username)")

        let handler: (Result<DocAuthResponse, Error>) -> Void = { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let resp):
                    docAuthLog.info("auth success: \(resp.message ?? "ok")")
                    if bridge.isAuthenticated { dismiss() }
                case .failure(let err):
                    errorMessage = err.localizedDescription
                    docAuthLog.error("auth failed: \(err.localizedDescription)")
                }
            }
        }

        switch mode {
        case .login:
            bridge.authLogin(username: username, password: password, completion: handler)
        case .setup:
            bridge.authSetup(username: username, password: password, completion: handler)
        }
    }
}
