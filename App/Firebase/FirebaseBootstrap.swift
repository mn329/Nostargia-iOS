@preconcurrency import FirebaseAppCheck
@preconcurrency import FirebaseAuth
@preconcurrency import FirebaseCore
@preconcurrency import FirebaseFirestore
import Foundation

/// Firebase の初期化。DEBUG ビルドで、テスト中・-useFirebaseEmulator 指定時・GoogleService-Info.plist が無いときはエミュレーターにつなぐ
enum FirebaseBootstrap {
    enum Mode: Equatable {
        case production
        case emulator
    }

    static let demoProjectID = "demo-nostargia"
    static let emulatorHost = "127.0.0.1"

    #if DEBUG
    static let isDebugBuild = true
    #else
    static let isDebugBuild = false
    #endif

    /// エミュレーターに切り替えるのは DEBUG ビルドだけ。リリース版は常に本番（plist が無ければ FirebaseApp.configure() で落ちて気づける）
    static func mode(environment: [String: String], arguments: [String], hasConfigFile: Bool, isDebugBuild: Bool = isDebugBuild) -> Mode {
        guard isDebugBuild else { return .production }
        if environment["XCTestConfigurationFilePath"] != nil { return .emulator }
        if arguments.contains("-useFirebaseEmulator") { return .emulator }
        return hasConfigFile ? .production : .emulator
    }

    static func configure(processInfo: ProcessInfo = .processInfo, bundle: Bundle = .main) {
        guard FirebaseApp.app() == nil else { return }
        let hasConfigFile = bundle.path(forResource: "GoogleService-Info", ofType: "plist") != nil

        switch mode(environment: processInfo.environment, arguments: processInfo.arguments, hasConfigFile: hasConfigFile) {
        case .production:
            #if targetEnvironment(simulator)
            AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
            #else
            AppCheck.setAppCheckProviderFactory(AppAttestFactory())
            #endif
            FirebaseApp.configure()

        case .emulator:
            let options = FirebaseOptions(googleAppID: "1:1234567890:ios:0000000000000000", gcmSenderID: "1234567890")
            options.projectID = demoProjectID
            options.apiKey = "AIzaSyDemoDemoDemoDemoDemoDemoDemoDemo0"
            options.bundleID = bundle.bundleIdentifier ?? "com.mn329.nostargia"
            FirebaseApp.configure(options: options)
            Auth.auth().useEmulator(withHost: emulatorHost, port: 9099)
            let settings = Firestore.firestore().settings
            settings.host = "\(emulatorHost):8080"
            settings.isSSLEnabled = false
            settings.cacheSettings = MemoryCacheSettings()
            Firestore.firestore().settings = settings
        }
    }
}

/// 実機では App Attest で App Check を行う
private final class AppAttestFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> (any AppCheckProvider)? {
        AppAttestProvider(app: app)
    }
}
