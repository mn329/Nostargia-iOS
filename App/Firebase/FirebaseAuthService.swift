@preconcurrency import FirebaseAuth
import Foundation
import NostargiaKit

/// Firebase Auth による認証。失敗は AuthFailure に変換して投げる
final class FirebaseAuthService: AuthService, @unchecked Sendable {
    private let auth: Auth

    init(auth: Auth = .auth()) {
        self.auth = auth
    }

    var currentUser: AuthUser? {
        auth.currentUser.map(Self.makeUser)
    }

    func authStates() -> AsyncStream<AuthUser?> {
        let auth = self.auth
        return AsyncStream { continuation in
            let handle = auth.addStateDidChangeListener { _, user in
                continuation.yield(user.map(Self.makeUser))
            }
            nonisolated(unsafe) let listener = handle
            nonisolated(unsafe) let owner = auth
            continuation.onTermination = { _ in owner.removeStateDidChangeListener(listener) }
        }
    }

    func signUp(email: String, password: String) async throws -> AuthUser {
        let result = try await mapErrors { try await self.auth.createUser(withEmail: email, password: password) }
        return Self.makeUser(result.user)
    }

    func signIn(email: String, password: String) async throws -> AuthUser {
        let result = try await mapErrors { try await self.auth.signIn(withEmail: email, password: password) }
        return Self.makeUser(result.user)
    }

    /// Apple / Google の資格情報でサインインする（AppleSignInHelper / GoogleSignInHelper が作る）
    func signIn(with credential: AuthCredential) async throws -> AuthUser {
        let result = try await mapErrors { try await self.auth.signIn(with: credential) }
        return Self.makeUser(result.user)
    }

    func sendPasswordReset(email: String) async throws {
        try await mapErrors { try await self.auth.sendPasswordReset(withEmail: email) }
    }

    func updatePassword(_ password: String) async throws {
        let user = try requireUser()
        try await mapErrors { try await user.updatePassword(to: password) }
    }

    func requestEmailChange(to email: String) async throws {
        let user = try requireUser()
        try await mapErrors { try await user.sendEmailVerification(beforeUpdatingEmail: email) }
    }

    func signOut() throws {
        try mapErrors { try self.auth.signOut() }
    }

    func deleteAccount(appleAuthorizationCode: String?) async throws {
        let user = try requireUser()
        if let appleAuthorizationCode {
            try await mapErrors { try await self.auth.revokeToken(withAuthorizationCode: appleAuthorizationCode) }
        }
        try await mapErrors { try await user.delete() }
    }

    private func requireUser() throws -> User {
        guard let user = auth.currentUser else { throw AuthFailure.requiresRecentLogin }
        return user
    }

    private static func makeUser(_ user: User) -> AuthUser {
        AuthUser(
            uid: user.uid,
            email: user.email,
            providers: Set(user.providerData.compactMap { AuthProvider(rawValue: $0.providerID) })
        )
    }

    private func mapErrors<T>(_ body: () async throws -> T) async throws -> T {
        do {
            return try await body()
        } catch let error as NSError where error.domain == AuthFailure.firebaseErrorDomain {
            throw AuthFailure(code: error.code)
        }
    }

    private func mapErrors<T>(_ body: () throws -> T) throws -> T {
        do {
            return try body()
        } catch let error as NSError where error.domain == AuthFailure.firebaseErrorDomain {
            throw AuthFailure(code: error.code)
        }
    }
}
