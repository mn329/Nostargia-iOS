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
    @State private var letter: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 8) {
                Text("Nostargia")
                    .font(.largeTitle)
                Text("星座 \(ConstellationCatalog.all.count) 個")
                    .font(.footnote)
                if let letter {
                    Text(letter)
                        .font(.footnote)
                        .padding()
                }
            }
            .foregroundStyle(.white)
        }
        #if DEBUG
        .task {
            // -letterSmokeTest を付けて起動したときだけ、本物の Gemini で手紙を1通作る
            guard ProcessInfo.processInfo.arguments.contains("-letterSmokeTest") else { return }
            let entry = DiaryEntry(mood: MoodValues(all: 70), goodThings: ["散歩した"], tag: nil)
            let generated = await LetterService(generator: GeminiLetterGenerator()).letter(for: entry)
            letter = generated ?? "（AI の手紙は作れなかったので定型文になります）"
            print("letterSmokeTest:", letter ?? "")
        }
        #endif
    }
}
