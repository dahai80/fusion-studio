import Foundation
import os.log

// ARCH-1 Phase 5 (audit-product-0907 P2-2): DocSocial 行为迁入。DocBridge 留 1 行 stub 转发 (保外部签名:
//   fetchFiles/uploadFile(pageId)/deleteFile/fetchComments/createComment/deleteComment/fetchFavorites/
//   addFavorite/removeFavorite/fetchActivity/recordActivity/uploadFile(fileData) call site 0 改)。
//   @Published (activities/files/comments/favorites) 现属 DocSocialState。HTTP 经 bridge?.get/post/delete;
//   错误经 bridge?.handleError; LRU cap 经 DocBridge.cap。uploadFile(fileData) multipart 走
//   bridge?.baseURL/session/authToken + IdentityService + DocBridge.httpStatusError (reach-through)。

private let docSocialLog = Logger(subsystem: "com.fusion.studio", category: "DocSocialService")

extension DocSocialState {

    func fetchFiles(pageId: String, completion: @escaping (Result<[DocFileUpload], Error>) -> Void) {
        docSocialLog.info("fetchFiles: pageId=\(pageId)")
        bridge?.get("/api/pages/\(pageId)/files") { [weak self] (result: Result<[DocFileUpload], Error>) in
            switch result {
            case .success(let list): DispatchQueue.main.async { self?.files = Array(list.suffix(200)) }; completion(.success(list))
            case .failure(let error): self?.bridge?.handleError(error, context: "fetchFiles"); completion(.failure(error))
            }
        }
    }

    func uploadFile(pageId: String, name: String, mime: String, content: String, completion: @escaping (Result<DocFileUpload, Error>) -> Void) {
        docSocialLog.info("uploadFile: pageId=\(pageId) name=\(name)")
        bridge?.post("/api/pages/\(pageId)/files", body: ["name": name, "mime": mime, "content": content]) { [weak self] (result: Result<DocFileUpload, Error>) in
            switch result {
            case .success(let file):
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.files.append(file)
                    DocBridge.cap(&self.files, 500)
                }
                completion(.success(file))
            case .failure(let error): self?.bridge?.handleError(error, context: "uploadFile"); completion(.failure(error))
            }
        }
    }

    func deleteFile(id: String, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        docSocialLog.info("deleteFile: id=\(id)")
        bridge?.delete("/api/files/\(id)") { [weak self] (result: Result<[String: Bool], Error>) in
            switch result {
            case .success:
                DispatchQueue.main.async { self?.files.removeAll { $0.id == id } }
                completion(.success(["deleted": true]))
            case .failure(let error): self?.bridge?.handleError(error, context: "deleteFile"); completion(.failure(error))
            }
        }
    }

    func fetchComments(pageId: String, completion: @escaping (Result<[DocComment], Error>) -> Void) {
        docSocialLog.info("fetchComments: pageId=\(pageId)")
        bridge?.get("/api/pages/\(pageId)/comments") { [weak self] (result: Result<[DocComment], Error>) in
            switch result {
            case .success(let list): DispatchQueue.main.async { self?.comments = Array(list.suffix(200)) }; completion(.success(list))
            case .failure(let error): self?.bridge?.handleError(error, context: "fetchComments"); completion(.failure(error))
            }
        }
    }

    func createComment(pageId: String, content: String, parentId: String? = nil, completion: @escaping (Result<DocComment, Error>) -> Void) {
        docSocialLog.info("createComment: pageId=\(pageId)")
        var body: [String: Any] = ["content": content]
        if let pid = parentId { body["parent_id"] = pid }
        bridge?.post("/api/pages/\(pageId)/comments", body: body) { [weak self] (result: Result<DocComment, Error>) in
            switch result {
            case .success(let comment):
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.comments.append(comment)
                    DocBridge.cap(&self.comments, 500)
                }
                completion(.success(comment))
            case .failure(let error): self?.bridge?.handleError(error, context: "createComment"); completion(.failure(error))
            }
        }
    }

    func deleteComment(id: String, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        docSocialLog.info("deleteComment: id=\(id)")
        bridge?.delete("/api/comments/\(id)") { [weak self] (result: Result<[String: Bool], Error>) in
            switch result {
            case .success:
                DispatchQueue.main.async { self?.comments.removeAll { $0.id == id } }
                completion(.success(["deleted": true]))
            case .failure(let error): self?.bridge?.handleError(error, context: "deleteComment"); completion(.failure(error))
            }
        }
    }

    func fetchFavorites(completion: @escaping (Result<[DocFavorite], Error>) -> Void) {
        docSocialLog.info("fetchFavorites")
        bridge?.get("/api/favorites") { [weak self] (result: Result<[DocFavorite], Error>) in
            switch result {
            case .success(let list): DispatchQueue.main.async { self?.favorites = Array(list.suffix(200)) }; completion(.success(list))
            case .failure(let error): self?.bridge?.handleError(error, context: "fetchFavorites"); completion(.failure(error))
            }
        }
    }

    func addFavorite(pageId: String, completion: @escaping (Result<DocFavorite, Error>) -> Void) {
        docSocialLog.info("addFavorite: pageId=\(pageId)")
        bridge?.post("/api/favorites", body: ["page_id": pageId]) { [weak self] (result: Result<DocFavorite, Error>) in
            switch result {
            case .success(let fav):
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.favorites.append(fav)
                    DocBridge.cap(&self.favorites, 200)
                }
                completion(.success(fav))
            case .failure(let error): self?.bridge?.handleError(error, context: "addFavorite"); completion(.failure(error))
            }
        }
    }

    func removeFavorite(pageId: String, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        docSocialLog.info("removeFavorite: pageId=\(pageId)")
        bridge?.delete("/api/favorites/\(pageId)") { [weak self] (result: Result<[String: Bool], Error>) in
            switch result {
            case .success:
                DispatchQueue.main.async { self?.favorites.removeAll { $0.page_id == pageId } }
                completion(.success(["deleted": true]))
            case .failure(let error): self?.bridge?.handleError(error, context: "removeFavorite"); completion(.failure(error))
            }
        }
    }

    func fetchActivity(limit: Int = 50, completion: @escaping (Result<[DocActivity], Error>) -> Void) {
        docSocialLog.info("fetchActivity: limit=\(limit)")
        bridge?.get("/api/activity?limit=\(limit)") { [weak self] (result: Result<[DocActivity], Error>) in
            switch result {
            case .success(let list): DispatchQueue.main.async { self?.activities = Array(list.suffix(500)) }; completion(.success(list))
            case .failure(let error): self?.bridge?.handleError(error, context: "fetchActivity"); completion(.failure(error))
            }
        }
    }

    func recordActivity(event: String, data: [String: Any]? = nil, completion: @escaping (Result<DocActivity, Error>) -> Void) {
        docSocialLog.info("recordActivity: event=\(event)")
        var body: [String: Any] = ["event": event]
        if let d = data { body["data"] = d }
        bridge?.post("/api/activity", body: body, completion: completion)
    }

    func uploadFile(fileData: Data, fileName: String, mimeType: String, completion: @escaping (Result<DocFileUpload, Error>) -> Void) {
        docSocialLog.info("uploadFile(multipart): name=\(fileName)")
        guard let baseURL = bridge?.baseURL,
              let url = URL(string: "\(baseURL)/api/files/upload") else {
            completion(.failure(NSError(domain: "DocBridge", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = bridge?.authToken { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        IdentityService.applyIdentityHeaders(to: &request)
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        bridge?.session.dataTask(with: request) { data, response, error in
            if let error = error { completion(.failure(error)); return }
            if let statusErr = DocBridge.httpStatusError(response, data) { completion(.failure(statusErr)); return }
            guard let data = data else {
                completion(.failure(NSError(domain: "DocBridge", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data"])))
                return
            }
            do {
                let decoded = try JSONDecoder().decode(DocFileUpload.self, from: data)
                completion(.success(decoded))
            } catch { completion(.failure(error)) }
        }.resume()
    }
}

extension DocBridge {

    func fetchFiles(pageId: String, completion: @escaping (Result<[DocFileUpload], Error>) -> Void) {
        socialState.fetchFiles(pageId: pageId, completion: completion)
    }

    func uploadFile(pageId: String, name: String, mime: String, content: String, completion: @escaping (Result<DocFileUpload, Error>) -> Void) {
        socialState.uploadFile(pageId: pageId, name: name, mime: mime, content: content, completion: completion)
    }

    func deleteFile(id: String, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        socialState.deleteFile(id: id, completion: completion)
    }

    func fetchComments(pageId: String, completion: @escaping (Result<[DocComment], Error>) -> Void) {
        socialState.fetchComments(pageId: pageId, completion: completion)
    }

    func createComment(pageId: String, content: String, parentId: String? = nil, completion: @escaping (Result<DocComment, Error>) -> Void) {
        socialState.createComment(pageId: pageId, content: content, parentId: parentId, completion: completion)
    }

    func deleteComment(id: String, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        socialState.deleteComment(id: id, completion: completion)
    }

    func fetchFavorites(completion: @escaping (Result<[DocFavorite], Error>) -> Void) { socialState.fetchFavorites(completion: completion) }

    func addFavorite(pageId: String, completion: @escaping (Result<DocFavorite, Error>) -> Void) {
        socialState.addFavorite(pageId: pageId, completion: completion)
    }

    func removeFavorite(pageId: String, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        socialState.removeFavorite(pageId: pageId, completion: completion)
    }

    func fetchActivity(limit: Int = 50, completion: @escaping (Result<[DocActivity], Error>) -> Void) {
        socialState.fetchActivity(limit: limit, completion: completion)
    }

    func recordActivity(event: String, data: [String: Any]? = nil, completion: @escaping (Result<DocActivity, Error>) -> Void) {
        socialState.recordActivity(event: event, data: data, completion: completion)
    }

    func uploadFile(fileData: Data, fileName: String, mimeType: String, completion: @escaping (Result<DocFileUpload, Error>) -> Void) {
        socialState.uploadFile(fileData: fileData, fileName: fileName, mimeType: mimeType, completion: completion)
    }
}
