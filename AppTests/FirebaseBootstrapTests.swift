@preconcurrency import FirebaseCore
@preconcurrency import FirebaseFirestore
import XCTest
@testable import Nostargia

final class FirebaseBootstrapTests: XCTestCase {
    func testModeSelection() {
        XCTAssertEqual(FirebaseBootstrap.mode(environment: ["XCTestConfigurationFilePath": "x"], arguments: [], hasConfigFile: true), .emulator)
        XCTAssertEqual(FirebaseBootstrap.mode(environment: [:], arguments: ["-useFirebaseEmulator"], hasConfigFile: true), .emulator)
        XCTAssertEqual(FirebaseBootstrap.mode(environment: [:], arguments: [], hasConfigFile: false), .emulator)
        XCTAssertEqual(FirebaseBootstrap.mode(environment: [:], arguments: [], hasConfigFile: true), .production)
    }

    /// リリース版は GoogleService-Info.plist が無くても起動引数があってもエミュレーターに切り替えない（無ければ起動時に落ちて気づける）
    func testReleaseBuildNeverUsesEmulator() {
        XCTAssertEqual(FirebaseBootstrap.mode(environment: [:], arguments: ["-useFirebaseEmulator"], hasConfigFile: false, isDebugBuild: false), .production)
        XCTAssertEqual(FirebaseBootstrap.mode(environment: [:], arguments: [], hasConfigFile: false, isDebugBuild: false), .production)
        XCTAssertEqual(FirebaseBootstrap.mode(environment: ["XCTestConfigurationFilePath": "x"], arguments: [], hasConfigFile: false, isDebugBuild: false), .production)
    }

    func testHostAppIsConfiguredForEmulator() {
        XCTAssertEqual(FirebaseApp.app()?.options.projectID, FirebaseBootstrap.demoProjectID)
        XCTAssertEqual(Firestore.firestore().settings.host, "127.0.0.1:8080")
        XCTAssertFalse(Firestore.firestore().settings.isSSLEnabled)
    }
}
