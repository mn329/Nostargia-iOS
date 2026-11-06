import Foundation

/// 認証の失敗（Web版 src/utils/errorTranslator.js に相当）
public enum AuthFailure: Error, Hashable, Sendable {
    case emailAlreadyInUse
    case invalidEmail
    case invalidCredential
    case weakPassword
    case network
    case tooManyRequests
    case requiresRecentLogin
    case accountExistsWithDifferentCredential
    case userDisabled
    case unknown(code: Int)

    /// Firebase Auth の NSError のドメイン
    public static let firebaseErrorDomain = "FIRAuthErrorDomain"

    /// Firebase Auth のエラーコード（AuthErrorCode の rawValue）から作る
    public init(code: Int) {
        switch code {
        case 17007: self = .emailAlreadyInUse
        case 17008: self = .invalidEmail
        case 17004, 17009, 17011: self = .invalidCredential
        case 17026: self = .weakPassword
        case 17020: self = .network
        case 17010: self = .tooManyRequests
        case 17014: self = .requiresRecentLogin
        case 17012: self = .accountExistsWithDifferentCredential
        case 17005: self = .userDisabled
        default: self = .unknown(code: code)
        }
    }

    public var message: String {
        switch self {
        case .emailAlreadyInUse: "このメールアドレスはすでに登録されています。"
        case .invalidEmail: "メールアドレスの形式が正しくありません。"
        case .invalidCredential: "メールアドレスまたはパスワードが違います。"
        case .weakPassword: "パスワードは6文字以上にしてください。"
        case .network: "通信できませんでした。電波の良い場所でもう一度お試しください。"
        case .tooManyRequests: "試行回数が多すぎます。しばらく時間をおいてからお試しください。"
        case .requiresRecentLogin: "安全のため、もう一度ログインしてからお試しください。"
        case .accountExistsWithDifferentCredential: "このメールアドレスは別のログイン方法で登録されています。"
        case .userDisabled: "このアカウントは利用できません。"
        case .unknown(let code): "エラーが発生しました。（コード: \(code)）"
        }
    }
}
