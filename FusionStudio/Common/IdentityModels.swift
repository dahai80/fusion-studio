import Foundation

enum AuthState: Equatable {
    case loggedOut
    case loggingIn
    case loggedIn
    case error(String)
}

struct IdentitySession: Equatable {
    let jwt: String
    let refreshToken: String
    let tenantId: String
    let tenantName: String
    let role: String
    let scopes: [String]
    let expiresAt: Date
}
