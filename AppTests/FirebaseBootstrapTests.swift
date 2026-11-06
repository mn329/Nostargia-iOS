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

    func testHostAppIsConfiguredForEmulator() {
        XCTAssertEqual(FirebaseApp.app()?.options.projectID, FirebaseBootstrap.demoProjectID)
        XCTAssertEqual(Firestore.firestore().settings.host, "127.0.0.1:8080")
        XCTAssertFalse(Firestore.firestore().settings.isSSLEnabled)
    }
}
