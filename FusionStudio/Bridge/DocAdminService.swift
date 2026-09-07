import Foundation
import os.log

// ARCH-1 Phase 5 (audit-product-0907 P2-2): DocAdmin 行为迁入。DocBridge 留 1 行 stub 转发 (保外部签名:
//   fetchUsers/updateUser/deleteUser/fetchBranding/updateBranding/fetchThemes/createTheme/deleteTheme/
//   fetchVocabulary/createVocabulary/deleteVocabulary/fetchWebhooks/createWebhook/deleteWebhook/testWebhook/
//   fetchMetadata/setMetadata/deleteMetadata/fetchSystemInfo/fetchSystemConfig/updateSystemConfig/exportBook/
//   fetchExportStatus/fetchNotifications/markNotificationRead/markAllNotificationsRead call site 0 改)。
//   @Published (users/branding/themes/vocabulary/webhooks/systemInfo/systemConfig/exportJobs/notifications)
//   现属 DocAdminState。HTTP 经 bridge?.get/post/put/delete; 错误经 bridge?.handleError; LRU cap 经
//   DocBridge.cap。本域纯 self.X。uploadFile (multipart, 977-1011) 属 Social 域 (DocSocialService)。

private let docAdminLog = Logger(subsystem: "com.fusion.studio", category: "DocAdminService")

extension DocAdminState {

    func fetchUsers(completion: @escaping (Result<[DocUser], Error>) -> Void) {
        docAdminLog.info("fetchUsers")
        bridge?.get("/api/users") { [weak self] (result: Result<[DocUser], Error>) in
            switch result {
            case .success(let list): DispatchQueue.main.async { self?.users = Array(list.suffix(200)) }; completion(.success(list))
            case .failure(let error): self?.bridge?.handleError(error, context: "fetchUsers"); completion(.failure(error))
            }
        }
    }

    func updateUser(id: String, username: String? = nil, email: String? = nil, role: String? = nil, completion: @escaping (Result<DocUser, Error>) -> Void) {
        docAdminLog.info("updateUser: id=\(id)")
        var body: [String: Any] = [:]
        if let u = username { body["username"] = u }
        if let e = email { body["email"] = e }
        if let r = role { body["role"] = r }
        bridge?.put("/api/users/\(id)", body: body) { [weak self] (result: Result<DocUser, Error>) in
            switch result {
            case .success(let user):
                DispatchQueue.main.async { self?.users = self?.users.map { $0.id == user.id ? user : $0 } ?? [] }
                completion(.success(user))
            case .failure(let error): self?.bridge?.handleError(error, context: "updateUser"); completion(.failure(error))
            }
        }
    }

    func deleteUser(id: String, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        docAdminLog.info("deleteUser: id=\(id)")
        bridge?.delete("/api/users/\(id)") { [weak self] (result: Result<[String: Bool], Error>) in
            switch result {
            case .success(let resp):
                DispatchQueue.main.async { self?.users = self?.users.filter { $0.id != id } ?? [] }
                completion(.success(resp))
            case .failure(let error): self?.bridge?.handleError(error, context: "deleteUser"); completion(.failure(error))
            }
        }
    }

    func fetchBranding(completion: @escaping (Result<DocBranding, Error>) -> Void) {
        docAdminLog.info("fetchBranding")
        bridge?.get("/api/branding") { [weak self] (result: Result<DocBranding, Error>) in
            switch result {
            case .success(let b): DispatchQueue.main.async { self?.branding = b }; completion(.success(b))
            case .failure(let error): self?.bridge?.handleError(error, context: "fetchBranding"); completion(.failure(error))
            }
        }
    }

    func updateBranding(branding: DocBranding, completion: @escaping (Result<DocBranding, Error>) -> Void) {
        docAdminLog.info("updateBranding")
        let body: [String: Any?] = [
            "logo_url": branding.logo_url,
            "primary_color": branding.primary_color,
            "secondary_color": branding.secondary_color,
            "font": branding.font,
            "custom_css": branding.custom_css,
        ]
        bridge?.put("/api/branding", body: body.compactMapValues { $0 }) { [weak self] (result: Result<DocBranding, Error>) in
            switch result {
            case .success(let b): DispatchQueue.main.async { self?.branding = b }; completion(.success(b))
            case .failure(let error): self?.bridge?.handleError(error, context: "updateBranding"); completion(.failure(error))
            }
        }
    }

    func fetchThemes(completion: @escaping (Result<[DocTheme], Error>) -> Void) {
        docAdminLog.info("fetchThemes")
        bridge?.get("/api/themes") { [weak self] (result: Result<[DocTheme], Error>) in
            switch result {
            case .success(let list): DispatchQueue.main.async { self?.themes = Array(list.suffix(200)) }; completion(.success(list))
            case .failure(let error): self?.bridge?.handleError(error, context: "fetchThemes"); completion(.failure(error))
            }
        }
    }

    func createTheme(name: String, css: String? = nil, isDark: Bool? = nil, completion: @escaping (Result<DocTheme, Error>) -> Void) {
        docAdminLog.info("createTheme: name=\(name)")
        var body: [String: Any] = ["name": name]
        if let c = css { body["css"] = c }
        if let d = isDark { body["is_dark"] = d }
        bridge?.post("/api/themes", body: body) { [weak self] (result: Result<DocTheme, Error>) in
            switch result {
            case .success(let t): DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.themes.append(t)
                DocBridge.cap(&self.themes, 100)
            }; completion(.success(t))
            case .failure(let error): self?.bridge?.handleError(error, context: "createTheme"); completion(.failure(error))
            }
        }
    }

    func deleteTheme(id: String, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        docAdminLog.info("deleteTheme: id=\(id)")
        bridge?.delete("/api/themes/\(id)") { [weak self] (result: Result<[String: Bool], Error>) in
            switch result {
            case .success(let resp):
                DispatchQueue.main.async { self?.themes = self?.themes.filter { $0.id != id } ?? [] }
                completion(.success(resp))
            case .failure(let error): self?.bridge?.handleError(error, context: "deleteTheme"); completion(.failure(error))
            }
        }
    }

    func fetchVocabulary(completion: @escaping (Result<[DocVocabulary], Error>) -> Void) {
        docAdminLog.info("fetchVocabulary")
        bridge?.get("/api/vocabulary") { [weak self] (result: Result<[DocVocabulary], Error>) in
            switch result {
            case .success(let list): DispatchQueue.main.async { self?.vocabulary = Array(list.suffix(200)) }; completion(.success(list))
            case .failure(let error): self?.bridge?.handleError(error, context: "fetchVocabulary"); completion(.failure(error))
            }
        }
    }

    func createVocabulary(term: String, definition: String? = nil, category: String? = nil, completion: @escaping (Result<DocVocabulary, Error>) -> Void) {
        docAdminLog.info("createVocabulary: term=\(term)")
        var body: [String: Any] = ["term": term]
        if let d = definition { body["definition"] = d }
        if let c = category { body["category"] = c }
        bridge?.post("/api/vocabulary", body: body) { [weak self] (result: Result<DocVocabulary, Error>) in
            switch result {
            case .success(let v): DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.vocabulary.append(v)
                DocBridge.cap(&self.vocabulary, 500)
            }; completion(.success(v))
            case .failure(let error): self?.bridge?.handleError(error, context: "createVocabulary"); completion(.failure(error))
            }
        }
    }

    func deleteVocabulary(id: String, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        docAdminLog.info("deleteVocabulary: id=\(id)")
        bridge?.delete("/api/vocabulary/\(id)") { [weak self] (result: Result<[String: Bool], Error>) in
            switch result {
            case .success(let resp):
                DispatchQueue.main.async { self?.vocabulary = self?.vocabulary.filter { $0.id != id } ?? [] }
                completion(.success(resp))
            case .failure(let error): self?.bridge?.handleError(error, context: "deleteVocabulary"); completion(.failure(error))
            }
        }
    }

    func fetchWebhooks(completion: @escaping (Result<[DocWebhook], Error>) -> Void) {
        docAdminLog.info("fetchWebhooks")
        bridge?.get("/api/webhooks") { [weak self] (result: Result<[DocWebhook], Error>) in
            switch result {
            case .success(let list): DispatchQueue.main.async { self?.webhooks = Array(list.suffix(200)) }; completion(.success(list))
            case .failure(let error): self?.bridge?.handleError(error, context: "fetchWebhooks"); completion(.failure(error))
            }
        }
    }

    func createWebhook(url: String, events: [String]? = nil, secret: String? = nil, completion: @escaping (Result<DocWebhook, Error>) -> Void) {
        docAdminLog.info("createWebhook: url=\(url)")
        var body: [String: Any] = ["url": url]
        if let e = events { body["events"] = e }
        if let s = secret { body["secret"] = s }
        bridge?.post("/api/webhooks", body: body) { [weak self] (result: Result<DocWebhook, Error>) in
            switch result {
            case .success(let w): DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.webhooks.append(w)
                DocBridge.cap(&self.webhooks, 100)
            }; completion(.success(w))
            case .failure(let error): self?.bridge?.handleError(error, context: "createWebhook"); completion(.failure(error))
            }
        }
    }

    func deleteWebhook(id: String, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        docAdminLog.info("deleteWebhook: id=\(id)")
        bridge?.delete("/api/webhooks/\(id)") { [weak self] (result: Result<[String: Bool], Error>) in
            switch result {
            case .success(let resp):
                DispatchQueue.main.async { self?.webhooks = self?.webhooks.filter { $0.id != id } ?? [] }
                completion(.success(resp))
            case .failure(let error): self?.bridge?.handleError(error, context: "deleteWebhook"); completion(.failure(error))
            }
        }
    }

    func testWebhook(id: String, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        docAdminLog.info("testWebhook: id=\(id)")
        bridge?.post("/api/webhooks/\(id)/test", body: nil, completion: completion)
    }

    func fetchMetadata(entity: String, entityId: String, completion: @escaping (Result<[DocMetadataEntry], Error>) -> Void) {
        docAdminLog.info("fetchMetadata: \(entity)/\(entityId)")
        bridge?.get("/api/\(entity)/\(entityId)/metadata", completion: completion)
    }

    func setMetadata(entity: String, entityId: String, key: String, value: String, completion: @escaping (Result<DocMetadataEntry, Error>) -> Void) {
        docAdminLog.info("setMetadata: \(entity)/\(entityId) key=\(key)")
        bridge?.put("/api/\(entity)/\(entityId)/metadata", body: ["key": key, "value": value], completion: completion)
    }

    func deleteMetadata(entity: String, entityId: String, key: String, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        docAdminLog.info("deleteMetadata: \(entity)/\(entityId) key=\(key)")
        bridge?.delete("/api/\(entity)/\(entityId)/metadata/\(key)", completion: completion)
    }

    func fetchSystemInfo(completion: @escaping (Result<DocSystemInfo, Error>) -> Void) {
        docAdminLog.info("fetchSystemInfo")
        bridge?.get("/api/system/info") { [weak self] (result: Result<DocSystemInfo, Error>) in
            switch result {
            case .success(let info): DispatchQueue.main.async { self?.systemInfo = info }; completion(.success(info))
            case .failure(let error): self?.bridge?.handleError(error, context: "fetchSystemInfo"); completion(.failure(error))
            }
        }
    }

    func fetchSystemConfig(completion: @escaping (Result<[DocSystemConfig], Error>) -> Void) {
        docAdminLog.info("fetchSystemConfig")
        bridge?.get("/api/system/config") { [weak self] (result: Result<[DocSystemConfig], Error>) in
            switch result {
            case .success(let cfg):
                let capped = Array(cfg.prefix(200))
                DispatchQueue.main.async { self?.systemConfig = capped }; completion(.success(capped))
            case .failure(let error): self?.bridge?.handleError(error, context: "fetchSystemConfig"); completion(.failure(error))
            }
        }
    }

    func updateSystemConfig(key: String, value: String, completion: @escaping (Result<DocSystemConfig, Error>) -> Void) {
        docAdminLog.info("updateSystemConfig: key=\(key)")
        bridge?.put("/api/system/config", body: ["key": key, "value": value], completion: completion)
    }

    func exportBook(bookId: String, format: String, completion: @escaping (Result<DocExportJob, Error>) -> Void) {
        docAdminLog.info("exportBook: bookId=\(bookId) format=\(format)")
        bridge?.post("/api/export/\(format)", body: ["book_id": bookId]) { [weak self] (result: Result<DocExportJob, Error>) in
            switch result {
            case .success(let job): DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.exportJobs.append(job)
                DocBridge.cap(&self.exportJobs, 100)
            }; completion(.success(job))
            case .failure(let error): self?.bridge?.handleError(error, context: "exportBook"); completion(.failure(error))
            }
        }
    }

    func fetchExportStatus(jobId: String, completion: @escaping (Result<DocExportJob, Error>) -> Void) {
        docAdminLog.info("fetchExportStatus: jobId=\(jobId)")
        bridge?.get("/api/export/\(jobId)/status", completion: completion)
    }

    func fetchNotifications(completion: @escaping (Result<[DocNotification], Error>) -> Void) {
        docAdminLog.info("fetchNotifications")
        bridge?.get("/api/notifications") { [weak self] (result: Result<[DocNotification], Error>) in
            switch result {
            case .success(let list): DispatchQueue.main.async { self?.notifications = Array(list.suffix(500)) }; completion(.success(list))
            case .failure(let error): self?.bridge?.handleError(error, context: "fetchNotifications"); completion(.failure(error))
            }
        }
    }

    func markNotificationRead(id: String, completion: @escaping (Result<DocNotification, Error>) -> Void) {
        docAdminLog.info("markNotificationRead: id=\(id)")
        bridge?.put("/api/notifications/\(id)/read", body: [:], completion: completion)
    }

    func markAllNotificationsRead(completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        docAdminLog.info("markAllNotificationsRead")
        bridge?.put("/api/notifications/read-all", body: [:], completion: completion)
    }
}

extension DocBridge {

    func fetchUsers(completion: @escaping (Result<[DocUser], Error>) -> Void) { adminState.fetchUsers(completion: completion) }

    func updateUser(id: String, username: String? = nil, email: String? = nil, role: String? = nil, completion: @escaping (Result<DocUser, Error>) -> Void) {
        adminState.updateUser(id: id, username: username, email: email, role: role, completion: completion)
    }

    func deleteUser(id: String, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        adminState.deleteUser(id: id, completion: completion)
    }

    func fetchBranding(completion: @escaping (Result<DocBranding, Error>) -> Void) { adminState.fetchBranding(completion: completion) }

    func updateBranding(branding: DocBranding, completion: @escaping (Result<DocBranding, Error>) -> Void) {
        adminState.updateBranding(branding: branding, completion: completion)
    }

    func fetchThemes(completion: @escaping (Result<[DocTheme], Error>) -> Void) { adminState.fetchThemes(completion: completion) }

    func createTheme(name: String, css: String? = nil, isDark: Bool? = nil, completion: @escaping (Result<DocTheme, Error>) -> Void) {
        adminState.createTheme(name: name, css: css, isDark: isDark, completion: completion)
    }

    func deleteTheme(id: String, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        adminState.deleteTheme(id: id, completion: completion)
    }

    func fetchVocabulary(completion: @escaping (Result<[DocVocabulary], Error>) -> Void) { adminState.fetchVocabulary(completion: completion) }

    func createVocabulary(term: String, definition: String? = nil, category: String? = nil, completion: @escaping (Result<DocVocabulary, Error>) -> Void) {
        adminState.createVocabulary(term: term, definition: definition, category: category, completion: completion)
    }

    func deleteVocabulary(id: String, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        adminState.deleteVocabulary(id: id, completion: completion)
    }

    func fetchWebhooks(completion: @escaping (Result<[DocWebhook], Error>) -> Void) { adminState.fetchWebhooks(completion: completion) }

    func createWebhook(url: String, events: [String]? = nil, secret: String? = nil, completion: @escaping (Result<DocWebhook, Error>) -> Void) {
        adminState.createWebhook(url: url, events: events, secret: secret, completion: completion)
    }

    func deleteWebhook(id: String, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        adminState.deleteWebhook(id: id, completion: completion)
    }

    func testWebhook(id: String, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        adminState.testWebhook(id: id, completion: completion)
    }

    func fetchMetadata(entity: String, entityId: String, completion: @escaping (Result<[DocMetadataEntry], Error>) -> Void) {
        adminState.fetchMetadata(entity: entity, entityId: entityId, completion: completion)
    }

    func setMetadata(entity: String, entityId: String, key: String, value: String, completion: @escaping (Result<DocMetadataEntry, Error>) -> Void) {
        adminState.setMetadata(entity: entity, entityId: entityId, key: key, value: value, completion: completion)
    }

    func deleteMetadata(entity: String, entityId: String, key: String, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        adminState.deleteMetadata(entity: entity, entityId: entityId, key: key, completion: completion)
    }

    func fetchSystemInfo(completion: @escaping (Result<DocSystemInfo, Error>) -> Void) { adminState.fetchSystemInfo(completion: completion) }

    func fetchSystemConfig(completion: @escaping (Result<[DocSystemConfig], Error>) -> Void) { adminState.fetchSystemConfig(completion: completion) }

    func updateSystemConfig(key: String, value: String, completion: @escaping (Result<DocSystemConfig, Error>) -> Void) {
        adminState.updateSystemConfig(key: key, value: value, completion: completion)
    }

    func exportBook(bookId: String, format: String, completion: @escaping (Result<DocExportJob, Error>) -> Void) {
        adminState.exportBook(bookId: bookId, format: format, completion: completion)
    }

    func fetchExportStatus(jobId: String, completion: @escaping (Result<DocExportJob, Error>) -> Void) {
        adminState.fetchExportStatus(jobId: jobId, completion: completion)
    }

    func fetchNotifications(completion: @escaping (Result<[DocNotification], Error>) -> Void) { adminState.fetchNotifications(completion: completion) }

    func markNotificationRead(id: String, completion: @escaping (Result<DocNotification, Error>) -> Void) {
        adminState.markNotificationRead(id: id, completion: completion)
    }

    func markAllNotificationsRead(completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        adminState.markAllNotificationsRead(completion: completion)
    }
}
