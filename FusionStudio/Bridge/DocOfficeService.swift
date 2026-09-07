import Foundation
import os.log

// ARCH-1 Phase 3 (audit-product-0907 P2-2): DocOffice 行为迁入。DocBridge 留 1 行 stub 转发 (保外部签名:
//   checkOfficeStatus/createOfficeDocument/exportOffice/previewOffice/mergeOffice/importOfficeDir/
//   executeOfficeCommand call site 0 改)。@Published (officeStatus) 现属 DocOfficeState; HTTP 经
//   bridge?.get/post; 错误经 bridge?.handleError。importOfficeDocument 留 DocBridge (协调器:
//   成功后写 libraryState.pages, 跨域)。

private let docOfficeLog = Logger(subsystem: "com.fusion.studio", category: "DocOfficeService")

extension DocOfficeState {

    func checkOfficeStatus() {
        bridge?.get("/api/office/status") { [weak self] (result: Result<DocOfficeStatus, Error>) in
            switch result {
            case .success(let status):
                DispatchQueue.main.async { self?.officeStatus = status }
            case .failure(let error):
                self?.bridge?.handleError(error, context: "officeStatus")
            }
        }
    }

    func createOfficeDocument(format: String, name: String) {
        struct OfficeCreateResp: Decodable { var id: String?; var path: String? }
        bridge?.post("/api/office/create", body: ["format": format, "name": name]) { [weak self] (result: Result<OfficeCreateResp, Error>) in
            switch result {
            case .success:
                docOfficeLog.info("Office doc created: \(name).\(format)")
            case .failure(let error):
                self?.bridge?.handleError(error, context: "createOffice")
            }
        }
    }

    func exportOffice(pageId: String, format: String, completion: @escaping (Result<[String: String], Error>) -> Void) {
        bridge?.post("/api/office/export", body: ["page_id": pageId, "format": format], completion: completion)
    }

    func previewOffice(id: String, completion: @escaping (Result<[String: String], Error>) -> Void) {
        bridge?.get("/api/office/preview/\(id)", completion: completion)
    }

    func mergeOffice(template: String, data: [String: Any], completion: @escaping (Result<[String: String], Error>) -> Void) {
        var body = data
        body["template"] = template
        bridge?.post("/api/office/merge", body: body, completion: completion)
    }

    func importOfficeDir(dirPath: String, bookId: String? = nil, completion: @escaping (Result<[DocPage], Error>) -> Void) {
        var body: [String: Any] = ["dir_path": dirPath]
        if let bid = bookId { body["book_id"] = bid }
        bridge?.post("/api/office/import-dir", body: body, completion: completion)
    }

    func executeOfficeCommand(file: String, command: String, args: [String: Any]? = nil, completion: @escaping (Result<[String: String], Error>) -> Void) {
        var body: [String: Any] = ["file": file, "command": command]
        if let args = args { body["args"] = args }
        bridge?.post("/api/office/command", body: body, completion: completion)
    }
}

extension DocBridge {

    func checkOfficeStatus() { officeState.checkOfficeStatus() }

    func createOfficeDocument(format: String, name: String) {
        officeState.createOfficeDocument(format: format, name: name)
    }

    func exportOffice(pageId: String, format: String, completion: @escaping (Result<[String: String], Error>) -> Void) {
        officeState.exportOffice(pageId: pageId, format: format, completion: completion)
    }

    func previewOffice(id: String, completion: @escaping (Result<[String: String], Error>) -> Void) {
        officeState.previewOffice(id: id, completion: completion)
    }

    func mergeOffice(template: String, data: [String: Any], completion: @escaping (Result<[String: String], Error>) -> Void) {
        officeState.mergeOffice(template: template, data: data, completion: completion)
    }

    func importOfficeDir(dirPath: String, bookId: String? = nil, completion: @escaping (Result<[DocPage], Error>) -> Void) {
        officeState.importOfficeDir(dirPath: dirPath, bookId: bookId, completion: completion)
    }

    func executeOfficeCommand(file: String, command: String, args: [String: Any]? = nil, completion: @escaping (Result<[String: String], Error>) -> Void) {
        officeState.executeOfficeCommand(file: file, command: command, args: args, completion: completion)
    }
}
