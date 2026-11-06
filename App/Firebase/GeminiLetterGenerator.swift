@preconcurrency import FirebaseAILogic
@preconcurrency import FirebaseRemoteConfig
import Foundation
import NostargiaKit

/// Firebase AI Logic（Gemini Developer API）で星からの手紙を作る。モデル名は Remote Config で切り替える
final class GeminiLetterGenerator: LetterGenerating, @unchecked Sendable {
    static let modelKey = "letter_model"
    static let defaultModel = "gemini-3.5-flash"

    enum Failure: Error {
        case emptyResponse
    }

    func generate(prompt: String) async throws -> String {
        let model = FirebaseAI.firebaseAI(backend: .googleAI()).generativeModel(
            modelName: await modelName(),
            generationConfig: GenerationConfig(
                responseMIMEType: "application/json",
                responseSchema: .object(properties: ["feedback": .string()])
            )
        )
        let response = try await model.generateContent(prompt)
        guard let text = response.text else { throw Failure.emptyResponse }
        return text
    }

    /// Remote Config の値（取得に失敗したらキャッシュか既定値）
    private func modelName() async -> String {
        let config = RemoteConfig.remoteConfig()
        config.setDefaults([Self.modelKey: Self.defaultModel as NSObject])
        _ = try? await config.fetchAndActivate()
        let value: String? = config.configValue(forKey: Self.modelKey).stringValue
        guard let value, !value.isEmpty else { return Self.defaultModel }
        return value
    }
}
