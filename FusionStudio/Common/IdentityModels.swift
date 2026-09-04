import Foundation

enum AuthState: Equatable {
    case loggedOut
    case loggingIn
    case loggedIn
    case error(String)
}

// #394: CustomStringConvertible redacts jwt + refreshToken so accidental
//   String(describing:) / print / os_log interpolation never leaks secrets.
//   Structural guarantee complementing the jwt-never-logged test.
struct IdentitySession: Equatable, CustomStringConvertible {
    let jwt: String
    let refreshToken: String
    let tenantId: String
    let tenantName: String
    let role: String
    let scopes: [String]
    let expiresAt: Date

    var description: String {
        // Redacted: never emit jwt/refreshToken. Only tenant id (non-secret, logged with .public).
        "IdentitySession(tenant=\(tenantId), role=\(role), redacted)"
    }
}
