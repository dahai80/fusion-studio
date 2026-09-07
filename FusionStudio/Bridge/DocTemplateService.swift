import Foundation
import os.log

// ARCH-1 Phase 3 (audit-product-0907 P2-2): DocTemplate 行为迁入。DocBridge 留 1 行 stub 转发 (保外部签名:
//   fetchTemplates/createTemplate/updateTemplate/deleteTemplate/fetchTemplateVariables call site 0 改)。
//   @Published (templates) 现属 DocTemplateState; HTTP 经 bridge?.get/post/put/delete; 错误经
//   bridge?.handleError; LRU cap 经 DocBridge.cap。instantiateTemplate 留 DocBridge (协调器:
//   成功后写 libraryState.pages, 跨域)。

private let docTemplateLog = Logger(subsystem: "com.fusion.studio", category: "DocTemplateService")

extension DocTemplateState {

    func fetchTemplates() {
        bridge?.get("/api/templates") { [weak self] (result: Result<[DocTemplate], Error>) in
            switch result {
            case .success(let list):
                DispatchQueue.main.async { self?.templates = Array(list.suffix(200)) }
            case .failure(let error):
                self?.bridge?.handleError(error, context: "templates")
            }
        }
    }

    func createTemplate(name: String, type: String? = nil, content: String? = nil, category: String? = nil, completion: @escaping (Result<DocTemplate, Error>) -> Void) {
        var body: [String: Any] = ["name": name]
        if let t = type { body["type"] = t }
        if let c = content { body["content"] = c }
        if let cat = category { body["category"] = cat }
        bridge?.post("/api/templates", body: body) { [weak self] (result: Result<DocTemplate, Error>) in
            switch result {
            case .success(let tmpl):
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.templates.append(tmpl)
                    DocBridge.cap(&self.templates, 200)
                }
                completion(.success(tmpl))
            case .failure(let error):
                self?.bridge?.handleError(error, context: "createTemplate")
                completion(.failure(error))
            }
        }
    }

    func updateTemplate(id: String, name: String? = nil, content: String? = nil, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        var body: [String: Any] = [:]
        if let n = name { body["name"] = n }
        if let c = content { body["content"] = c }
        bridge?.put("/api/templates/\(id)", body: body, completion: completion)
    }

    func deleteTemplate(id: String, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        bridge?.delete("/api/templates/\(id)") { [weak self] (result: Result<[String: Bool], Error>) in
            switch result {
            case .success:
                DispatchQueue.main.async { self?.templates.removeAll { $0.id == id } }
                completion(.success(["deleted": true]))
            case .failure(let error):
                self?.bridge?.handleError(error, context: "deleteTemplate")
                completion(.failure(error))
            }
        }
    }

    func fetchTemplateVariables(id: String, completion: @escaping (Result<[String: [String]], Error>) -> Void) {
        bridge?.get("/api/templates/\(id)/variables", completion: completion)
    }
}

extension DocBridge {

    func fetchTemplates() { templateState.fetchTemplates() }

    func createTemplate(name: String, type: String? = nil, content: String? = nil, category: String? = nil, completion: @escaping (Result<DocTemplate, Error>) -> Void) {
        templateState.createTemplate(name: name, type: type, content: content, category: category, completion: completion)
    }

    func updateTemplate(id: String, name: String? = nil, content: String? = nil, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        templateState.updateTemplate(id: id, name: name, content: content, completion: completion)
    }

    func deleteTemplate(id: String, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        templateState.deleteTemplate(id: id, completion: completion)
    }

    func fetchTemplateVariables(id: String, completion: @escaping (Result<[String: [String]], Error>) -> Void) {
        templateState.fetchTemplateVariables(id: id, completion: completion)
    }
}
