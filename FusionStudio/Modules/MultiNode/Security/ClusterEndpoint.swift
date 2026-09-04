import Foundation
import os.log

private let endpointLog = Logger(subsystem: "com.fusion.studio", category: "ClusterEndpoint")

struct ClusterEndpoint: Equatable {
    let host: String
    let port: Int

    // 审计v0.1.58 P0-multinode-3: 远程节点强制 https; 本地保留 http (loopback).
    private static func isLocalHost(_ h: String) -> Bool {
        h == "127.0.0.1" || h == "localhost" || h == "0.0.0.0" || h == "::1"
    }

    var url: URL? {
        let scheme = Self.isLocalHost(host) ? "http" : "https"
        return URL(string: "\(scheme)://\(host):\(port)")
    }

    var urlString: String {
        "\(host):\(port)"
    }

    static func parse(_ csv: String) -> [ClusterEndpoint] {
        let trimmed = csv.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        var result: [ClusterEndpoint] = []
        for raw in trimmed.split(separator: ",") {
            let entry = raw.trimmingCharacters(in: .whitespaces)
            guard let colon = entry.lastIndex(of: ":") else {
                endpointLog.error("parse skip malformed (no port): \(entry, privacy: .public)")
                continue
            }
            let host = String(entry[entry.startIndex..<colon])
            guard let port = Int(entry[entry.index(after: colon)...]), port > 0, !host.isEmpty else {
                endpointLog.error("parse skip malformed (bad host/port): \(entry, privacy: .public)")
                continue
            }
            result.append(ClusterEndpoint(host: host, port: port))
        }
        return result
    }
}

struct AuditRecord: Codable {
    let ts: Int
    let actor: String
    let action: String
    let targetNode: String?
    let targetTask: String?
    let result: String
    let idempotencyKey: String?
    let masterHost: String?
}
