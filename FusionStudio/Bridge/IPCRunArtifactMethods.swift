import Foundation
import os.log

// N9 (#348) GUI parity: run_artifact.list/get/versions over the central router UDS.
// Execution results (graph.execute and async task completion) now include run_artifact_id.
extension IPCClient {
    func runArtifactList(limit: Int = 50, name: String = "") async throws -> [[String: Any]] {
        var params: [String: Any] = ["limit": limit]
        if !name.isEmpty { params["name"] = name }
        let result = try await call(method: RPCMethod.runArtifactList, params: params)
        return result["artifacts"] as? [[String: Any]] ?? []
    }

    func runArtifactGet(artifactId: String) async throws -> [String: Any] {
        return try await call(method: RPCMethod.runArtifactGet, params: ["artifact_id": artifactId])
    }

    func runArtifactVersions(name: String) async throws -> [[String: Any]] {
        let result = try await call(method: RPCMethod.runArtifactVersions, params: ["name": name])
        return result["versions"] as? [[String: Any]] ?? []
    }
}
