import Foundation
import os.log

// ARCH-1 Phase 2 (audit-product-0907 P2-2): DocAuth 行为迁入。DocBridge 留 1 行 stub 转发 (保外部签名:
//   DocView/Settings call site 0 改)。@Published (isAuthenticated/authError) 现属 DocAuthState;
//   authToken (Keychain infra) 留 DocBridge (internal), 经 bridge?.authToken reach-through。
//   restoreAuth/verifyToken 留 DocBridge (协调器: restoreAuth 编排, verifyToken 用 /api/workspaces 路由)。

private let docAuthLog = Logger(subsystem: "com.fusion.studio", category: "DocAuthService")

extension DocAuthState {

    func authSetup(username: String, password: String, completion: @escaping (Result<DocAuthResponse, Error>) -> Void) {
        docAuthLog.info("authSetup: username=\(username)")
        bridge?.post("/api/auth/setup", body: ["email": username, "password": password]) { [weak self] (result: Result<DocAuthResponse, Error>) in
            switch result {
            case .success(let resp):
                if let token = resp.token {
                    self?.bridge?.authToken = token
                    DispatchQueue.main.async { self?.isAuthenticated = true; self?.authError = nil }
                    docAuthLog.info("authSetup success, token saved")
                }
                completion(.success(resp))
            case .failure(let error):
                DispatchQueue.main.async { self?.authError = BridgeError.sanitize(error) }
                docAuthLog.error("authSetup failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }

    func authLogin(username: String, password: String, completion: @escaping (Result<DocAuthResponse, Error>) -> Void) {
        docAuthLog.info("authLogin: username=\(username)")
        bridge?.post("/api/auth/login", body: ["email": username, "password": password]) { [weak self] (result: Result<DocAuthResponse, Error>) in
            switch result {
            case .success(let resp):
                if let token = resp.token {
                    self?.bridge?.authToken = token
                    DispatchQueue.main.async { self?.isAuthenticated = true; self?.authError = nil }
                    docAuthLog.info("authLogin success, token saved")
                }
                completion(.success(resp))
            case .failure(let error):
                DispatchQueue.main.async { self?.authError = BridgeError.sanitize(error) }
                docAuthLog.error("authLogin failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }

    func authRefresh(completion: @escaping (Result<DocAuthResponse, Error>) -> Void) {
        docAuthLog.info("authRefresh")
        bridge?.post("/api/auth/refresh", body: nil) { [weak self] (result: Result<DocAuthResponse, Error>) in
            switch result {
            case .success(let resp):
                if let token = resp.token {
                    self?.bridge?.authToken = token
                    DispatchQueue.main.async { self?.isAuthenticated = true }
                    docAuthLog.info("authRefresh success")
                }
                completion(.success(resp))
            case .failure(let error):
                docAuthLog.error("authRefresh failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }

    func authLogout() {
        docAuthLog.info("authLogout")
        bridge?.authToken = nil
        DispatchQueue.main.async { self.isAuthenticated = false }
    }
}

extension DocBridge {

    func authSetup(username: String, password: String, completion: @escaping (Result<DocAuthResponse, Error>) -> Void) {
        authState.authSetup(username: username, password: password, completion: completion)
    }

    func authLogin(username: String, password: String, completion: @escaping (Result<DocAuthResponse, Error>) -> Void) {
        authState.authLogin(username: username, password: password, completion: completion)
    }

    func authRefresh(completion: @escaping (Result<DocAuthResponse, Error>) -> Void) {
        authState.authRefresh(completion: completion)
    }

    func authLogout() { authState.authLogout() }
}
