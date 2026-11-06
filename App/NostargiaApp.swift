import NostargiaKit
import SwiftUI

@main
struct NostargiaApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
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
