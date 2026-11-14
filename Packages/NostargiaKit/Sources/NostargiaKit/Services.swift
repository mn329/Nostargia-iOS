import Foundation

public enum AuthProvider: String, Hashable, Sendable {
    case password
    case apple = "apple.com"
    case google = "google.com"
}

public struct AuthUser: Hashable, Sendable {
    public let uid: String
    public let email: String?
    public let providers: Set<AuthProvider>

    public init(uid: String, email: String?, providers: Set<AuthProvider>) {
        self.uid = uid
        self.email = email
        self.providers = providers
    }
}

/// 認証。失敗は AuthFailure で投げる
public protocol AuthService: Sendable {
    var currentUser: AuthUser? { get }
    func authStates() -> AsyncStream<AuthUser?>
    func signUp(email: String, password: String) async throws -> AuthUser
    func signIn(email: String, password: String) async throws -> AuthUser
    func sendPasswordReset(email: String) async throws
    func updatePassword(_ password: String) async throws
    /// 新しいアドレスに確認リンクを送る。リンクを押すと変更が確定する
    func requestEmailChange(to email: String) async throws
    func signOut() throws
    /// Apple でサインインしたユーザーは、直前に取得した認可コードを渡して Apple の認証も取り消す
    func deleteAccount(appleAuthorizationCode: String?) async throws
}

/// ログイン中のユーザーの星
public protocol StarRepository: Sendable {
    /// 表示日時の古い順。変更があるたびに全件を流す
    func stars() -> AsyncThrowingStream<[Star], Error>
    func add(_ draft: StarDraft) async throws -> String
    func delete(ids: [String]) async throws
}

/// ログイン中のユーザーのタグ（作成順）
public protocol TagRepository: Sendable {
    func tags() async throws -> [Tag]
    func add(name: String) async throws -> Tag
    func rename(id: String, to name: String) async throws
    func delete(id: String) async throws
}

public protocol ProfileRepository: Sendable {
    /// まだ作っていなければ nil（Apple / Google の初回ログイン）
    func profile() async throws -> UserProfile?
    /// プロフィールと初期タグ（休日・誕生日・アニバーサリー）を作る
    func create(_ profile: UserProfile) async throws
    func updateUserName(_ name: String) async throws
    /// users/{uid} 以下をすべて消す。何度呼んでもよい
    func deleteAllData() async throws
}
