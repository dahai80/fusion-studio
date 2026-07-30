// APIKeyGenerator - 生成 sk-fusion- 前缀的随机 API Key。
// 复用自 fusion-mac Sources/Config/APIKeyGenerator.swift，纯 Foundation 无依赖。
// 随机源为 Swift SystemRandomNumberGenerator（Apple 平台底层 SecRandomCopyBytes，密码学级）。

import Foundation

enum APIKeyGenerator {
    static let prefix = "sk-fusion-"
    static let bodyAlphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    static let bodyLength = 24

    static func random() -> String {
        let body = (0..<bodyLength).map { _ in bodyAlphabet.randomElement()! }
        return prefix + String(body)
    }
}
