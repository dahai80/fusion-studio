import Foundation
import SwiftUI
import os.log

// 审计0830 P1-缓存-1: ForEach(Array(dictArr.enumerated()), id: \.offset) 反模式 —
//   offset 作 id → 数组增删触发全量 diff O(n) 重渲染, 长列表卡顿。
//   [String:Any] 无 Identifiable, 用本包装按稳定 key (id/name/... 抽取) 生成 Hashable id,
//   ForEach(dictArr.identifiable(by: "id"), id: \.id) 增量 diff。
//   key 缺失或重复 → 退化为 "<idx>" (保唯一), 不崩。
private let identDictLog = Logger(subsystem: "com.fusion.studio", category: "IdentifiableDict")

struct IdentifiableDict: Identifiable, Hashable {
    let id: String
    let dict: [String: Any]
    static func == (lhs: IdentifiableDict, rhs: IdentifiableDict) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension Array where Element == [String: Any] {
    func identifiable(by key: String) -> [IdentifiableDict] {
        var seen = Set<String>()
        var out: [IdentifiableDict] = []
        out.reserveCapacity(count)
        for (idx, d) in enumerated() {
            var raw = (d[key].map { "\($0)" }) ?? ""
            if raw.isEmpty {
                raw = (d["id"].map { "\($0)" }) ?? ""
            }
            if raw.isEmpty || !seen.insert(raw).inserted {
                raw = "<\(idx)>"
                identDictLog.warning("identifiable: key='\(key, privacy: .public)' missing/dup at idx=\(idx), fallback='<\(idx)>'")
            }
            out.append(IdentifiableDict(id: raw, dict: d))
        }
        return out
    }
}
