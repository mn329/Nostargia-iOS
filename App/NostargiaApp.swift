import GoogleSignIn
import NostargiaKit
import SwiftUI

@main
struct NostargiaApp: App {
    init() {
        FirebaseBootstrap.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    _ = GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}

/// 段階1d で星空とモーダルに置き換える仮の画面
struct ContentView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 8) {
                Text("Nostargia")
                    .font(.largeTitle)
                Text("星座 \(ConstellationCatalog.all.count) 個")
                    .font(.footnote)
            }
            .foregroundStyle(.white)
        }
    }
}
