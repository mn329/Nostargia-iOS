@preconcurrency import FirebaseAuth
@preconcurrency import FirebaseCore
import GoogleSignIn
import UIKit

enum GoogleSignInError: Error {
    case missingClientID
    case missingIDToken
}

/// Google でサインインして Firebase の資格情報を作る。戻りの URL は NostargiaApp の onOpenURL で処理する
@MainActor
enum GoogleSignInHelper {
    static func credential(presenting viewController: UIViewController) async throws -> AuthCredential {
        guard let clientID = FirebaseApp.app()?.options.clientID else { throw GoogleSignInError.missingClientID }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)
        guard let idToken = result.user.idToken?.tokenString else { throw GoogleSignInError.missingIDToken }
        return GoogleAuthProvider.credential(withIDToken: idToken, accessToken: result.user.accessToken.tokenString)
    }
}
