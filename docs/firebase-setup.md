# Firebase の準備（本物のプロジェクト）

自動テストはエミュレーター上の仮プロジェクト `demo-nostargia` で動くので、ここは実機・TestFlight・手紙の確認に必要な作業。

1. **プロジェクトを作る**: https://console.firebase.google.com/ で新しいプロジェクトを作る（Google アナリティクスは不要なら無効）。プラン は Spark（無料）のまま。
2. **iOS アプリを登録する**: バンドル ID `com.mn329.nostargia`、App Store ID は空欄。`GoogleService-Info.plist` をダウンロードして `App/GoogleService-Info.plist` に置く（コミットしない）。
3. **Google でサインインの URL**: `GoogleService-Info.plist` の `REVERSED_CLIENT_ID` を `Config/Firebase.xcconfig` の `GOOGLE_REVERSED_CLIENT_ID` に書く。
4. **Authentication**: 「始める」→ ログイン方法で「メール/パスワード」「Google」「Apple」を有効にする（Apple はネイティブの iOS アプリだけなので、サービス ID などの入力は不要）。
5. **Firestore**: データベースを作成。ロケーションは `asia-northeast1`（東京）、本番モードで開始。続けてルールを反映する：
   `firebase deploy --only firestore:rules --project <プロジェクトID>`
6. **AI Logic**: 「AI Logic」→「始める」→ Gemini Developer API を選ぶ。
7. **Remote Config**: パラメータ `letter_model`（文字列）、既定値 `gemini-3.5-flash` を作って公開する。
8. **App Check**: アプリを App Attest で登録する（Team ID `K3BSAX58ZG`）。シミュレーターではデバッグプロバイダーを使うので、アプリを1度起動して Xcode のログに出る「Firebase App Check debug token」をコンソールの「デバッグトークンを管理」に登録する。実機での動作を確認したら、**App Store 公開前に必ず** AI Logic・Cloud Firestore・Authentication の3つすべてで App Check を「適用」にする（API キーはアプリに含まれるので、適用しないと、アプリ以外から大量の登録や書き込みをされて無料枠を使い切られるおそれがある）。
9. **Apple Developer**: Xcode の Signing & Capabilities で Sign in with Apple と App Attest が付いていることを確認する（project.yml から自動で付く）。
