# Nostargia iOS 設計書

- 作成日: 2026-11-06
- 対象: Web版 Nostargia（`~/Documents/Nostargia`, React + R3F + Supabase）を Swift ネイティブの iOS アプリに置き換える
- 開発体制: 1人。締め切りなし（U22コンテストは終了済み）

## 1. 目的と前提

### 目的
1. App Store で一般公開する
2. Swift / iOS 開発を学ぶ

### 決定事項
| 項目 | 決定 |
|---|---|
| 言語・UI | Swift / SwiftUI |
| 星空描画 | Metal（MTKView）。SpriteKit / SceneKit / RealityKit は不採用 |
| バックエンド | Firebase（Auth / Firestore / AI Logic / Remote Config / App Check） |
| Web版・Supabase | 使わない。Supabase の権限がないため既存データの移行はしない |
| 対応環境 | iOS 17 以上、iPhone のみ、縦画面 |
| リポジトリ | `~/Documents/Nostargia-iOS`（Web版とは別リポジトリ） |

### 見た目の基準
- **星空の表現**: Web版が正解。シェーダー・色・座標・動きを忠実に再現する。
- **画面構成・表示内容・操作フロー**: Web版が正解。星空の上にモーダルを重ね、画面遷移を少なくしてユーザーの負荷を下げる、という Web版の意図を引き継ぐ。iOS 標準のシートや NavigationStack による画面遷移は使わない。
- **見た目の仕上げ**: iOS らしく新しく作る。すりガラス風の背景、バネのようなアニメーション、触ったときの振動、日本語フォントの調整、Dynamic Type への配慮。

## 2. 全体構成

```
SwiftUI（UI層）
  ルート: loading → 認証 → 演出 → メイン
  メイン = 星空 + 重ねるUI（ロケットボタン・ユーザーメニュー）+ モーダル層
星空レンダラー（Metal）
状態（@Observable のストア）
  StarStore / UserStore / ThemeStore / FutureMessageStore / TutorialStore
ドメイン（純粋な Swift。UI にも Firebase にも依存しない）
データ（Firebase のリポジトリ群。プロトコル越しに使い、モックに差し替えられる）
端末設定（UserDefaults）
```

| iOS の層 | Web版の対応箇所 |
|---|---|
| ルートのフェーズ遷移 | `src/App.jsx` |
| メインの UI とモーダル | `src/components/ui/UI.jsx`, `src/components/ui/modals/` |
| 星空 | `src/components/canvas/` |
| ストア | `src/store/` |
| ドメイン | `src/utils/`, `src/data/constellationData.js` |

**設計方針**
- 星空レンダラーは「星の一覧・テーマ・カメラの目標」を受け取って描画し、「星がタップされた」というイベントを返すだけにする。UI の作り直しが星空に影響しない。
- ドメインはテストで Web版と同じ結果になることを保証する（7章）。
- Firebase は SPM で導入する。

## 3. 認証

ログイン手段は **Apple / Google / メールアドレスとパスワード** の3つ（Firebase Auth）。

```
loading ─┬─ ログイン済み ──────────────────────────→ メイン
         └─ 未ログイン → ログインモーダル
               ├ Apple / Google でサインイン ─→（初回のみ）プロフィール設定モーダル
               ├ メールでログイン
               ├ メールで新規登録モーダル
               └ パスワード再設定モーダル
                    ↓ 成功
               グリッチ演出（裏で星空を先に描いておく）→ メイン
```

- **メールで新規登録**: ユーザー名、メール、パスワード（2回）、生年月日、規約への同意。Web版の `RegisterModal` と同じ項目。
- **Apple / Google の初回ログイン**: ユーザー名、生年月日、規約への同意を入力するプロフィール設定モーダルを出す。
- **パスワード再設定**: メールアドレスを入力 → Firebase が再設定リンクをメールで送る → 送信完了を案内する（2ステップ）。
- **メールアドレスの変更**: 新しいアドレスに確認リンクを送る（`sendEmailVerification(beforeUpdatingEmail:)`）。
- **メールの送信元**: Firebase 標準の `firebaseapp.com` ドメインを使う。迷惑メールに振り分けられる問題が出たら、独自ドメインを検討する。
- **新規登録時**: `users/{uid}` を作り、初期タグ「休日」「誕生日」「アニバーサリー」を作る。
- **エラー表示**: Firebase のエラーコードを分かりやすい日本語に変換する（Web版 `src/utils/errorTranslator.js` に相当）。
- **アカウント削除**（App Store の必須要件）
  1. 必要なら再ログインしてもらう
  2. `users/{uid}` 以下のサブコレクションと本体を一括削除する
  3. Apple でサインインしたユーザーは `revokeToken` で Apple の認証を取り消す
  4. Auth のユーザーを削除する

## 4. データ（Firestore）

```
users/{uid}
  userName: String
  birthday: Timestamp
  createdAt: Timestamp (サーバー時刻)

  stars/{starId}
    position: { x, y, z }             (Double)
    color: { r, g, b }                (0〜1)
    scale: Double
    random: Double
    createdAt: Timestamp (サーバー時刻)
    displayDate: Timestamp            朝6時区切りの判定とカレンダー表示に使う（デバッグ用の日数ずらしも反映した日時）
    mood: { emotional, motivation, social, physical, fulfillment }  (Int, 0〜100)
    emotion: String                   感情タイプ
    feedback: String                  星からの手紙
    totalScore: Double
    goodThings: [String]              最大3件
    tag: { id, name } | null          タグ名もコピーして持つ（タグを消しても表示できるように）
    constellation: { id, nodeIndex } | null
    isTutorial: Bool

  tags/{tagId}
    name: String
    createdAt: Timestamp

  futureMessages/{messageId}
    message: String
    createdAt: Timestamp
    displayDate: Timestamp
    isRead: Bool
```

**Web版からの変更点**
- `analysis_data`（jsonb）を分解して、フィールドとして直接持たせる。Swift の `Codable` と1対1で対応させるため。
- `display_date` を文字列 "YY/M/D HH:mm" から Timestamp にする。表示の形式は UI 側で整える。
- `t_account.is_frozen` は持ち越さない（Web版で使われている箇所がないため）。

**セキュリティルール**: `users/{uid}` 以下は `request.auth.uid == uid` のときだけ読み書きできる。

**同期とオフライン**
- 星の一覧はスナップショットリスナーで購読する（Web版の Realtime 購読に相当）。
- オフライン対応は Firestore 標準のキャッシュを使う。SwiftData は併用しない。データを2か所で持つと同期処理が必要になり、一番のバグの元になるため。
- 将来もっと強いオフライン対応が必要になったら、データ層の実装だけを差し替える。

## 5. 星空レンダラー（Metal）

### 座標系
Web版と同じ値を使う。

| 項目 | 値 |
|---|---|
| 透視カメラ | fov 50、初期位置 (0, 0, 10) |
| 星の範囲 | X ±320、Y ±160 |
| 各層の板 | 1000×500 の平面を z -50〜-20 に重ねる |
| フォグ | 線形、色 #101020、範囲 10〜150 |

### 1フレームの描画の流れ
1. **シーンパス**（rgba16Float のオフスクリーンテクスチャに描く）
   背景 → 天の川（fbm）→ 遠い星 → 遠くの流れ星 → 霧 → [スカイボックスの種類に応じてネビュラ] → 星座ライン・星座画像 → ユーザーの星（インスタンス描画）→ 未来星・流れ星
2. **後処理**
   ブルーム（mip チェーンで縮小・拡大。Web版の mipmap ブルームに相当）→ トーンマッピング → ビネット → ノイズ → 画面に表示

### 移植元
- シェーダーは `src/components/canvas/` 配下の GLSL を、MSL に1対1で書き換える。
- 移植対象: SkyBox / skyBoxMixed / skyBoxUpGrade / DistantStars / DistantNagareboshi / UserStar / FutureStar / ShootingStar / ConstellationLines / GlitchCanvas。
- **テーマ**（purple, blue, green, space, orange, red, bright_blue の7種）と**スカイボックス**（classic, mixed, upgrade の3種）は、シェーダーに渡す色の値と、どの層を描くかの切り替えで実現する。

### カメラと操作
- 1本指でパン、ピンチでズーム。回転はしない。
- 距離は 10〜100、位置は X ±320、Y ±160 に制限する。
- 指を離した後の慣性と、目標へなめらかに追いつく動きをつける。
- 打ち上げ時は、新しい星の正面（z + 20）へなめらかに移動する。

### 星のタップと日付の表示
- **タップ判定**: 星のワールド座標を画面座標に変換し、指から 44pt 以内で一番近い星を選ぶ。
- **星の下の日付**: SwiftUI の Text を星の画面位置に重ねて表示する。表示のオン/オフは設定で切り替える。

### 性能
- フレームの描画時間を見張り、重ければブルームの解像度と描画解像度を下げる。
- 省電力モード中は描画頻度を下げ、アプリが裏に回ったら描画を止める。

### 見た目の確認
層を1つ作るごとに、Web版と同じカメラ位置でスクリーンショットを撮って並べて比べる。

## 6. UI と画面の流れ

### モーダル層
- 表示中のモーダルを1か所（`ModalRouter`）で管理し、出し入れのアニメーション、背景を暗くする処理、閉じ方を統一する。
- モーダルを開いている間も星空は見えたまま動き続ける。
- 対象のモーダル: ログイン、新規登録、パスワード再設定、プロフィール設定、日記、星の詳細、ログ、マイセイザ、テーマ、プロフィール、未来への手紙（入力と表示）。
- 項目と表示内容は Web版の各モーダルに合わせる。

### ユーザーメニュー
項目は Web版と同じ。

- プロフィール
- マイセイザ
- テーマ
- ログ
- 未来への手紙
- チュートリアル開始
- 設定（日付表示、ウェルカム表示）
- ログアウト

フルスクリーンは iOS では不要なので外す。

### 日記と打ち上げ
Web版 `UI.jsx` の `handleSend` と同じ順序・タイミングで動かす。

1. 日記モーダルで入力する
   - スライダー5本: emotional, motivation, social, physical, fulfillment。0〜100、初期値 50
   - タグを1つ選ぶ
   - いいことを最大3件
2. 打ち上げを押すと、ドメインで次を計算する
   - 感情タイプ
   - totalScore
   - 星の色・大きさ・位置
   - 星座の割り当て
3. 手紙を生成する（8章）
4. Firestore に保存する
5. カメラを新しい星へ移動し、1.5秒後に星を1.5秒かけてフェードインする
6. 全スライダーが 25 未満で、未読の未来への手紙があれば、流れ星を登場させる

### 未来への手紙（段階3）
1. 前回の手紙から2日が経つと、ランダムな位置に未来星が現れる。Web版の `useFutureMessageStore.js` はデバッグ用の 0.001日のままなので、本来の値である2日に戻す。
2. 未来星をタップすると入力モーダルが開く。保存すると星が消える。
3. 打ち上げ時に全スライダーが 25 未満で、未読の手紙があると流れ星が登場する。
4. 流れ星をタップすると、手紙を表示して既読にする。流れ星は加速して画面外へ出ていく。

### クールダウン
- 朝6時から翌朝6時の間に、日記は1回だけ書ける（Web版 `src/utils/appTime.js` と同じ）。
- ロケットボタンのリングで、次に書けるまでの進み具合を表示する。

### 端末設定（UserDefaults）
次の項目を保存する。

- 日付表示のオン/オフ
- ウェルカム表示のオン/オフ
- テーマ
- スカイボックスの種類
- デバッグ用の日数オフセット（ユーザーごと）

### デバッグ機能
日数をずらすデバッグと星座テストは、`#if DEBUG` のビルドでだけ表示する。

## 7. ドメイン（Web版から移植する純粋なロジック）

| Swift の型 | 移植元 | 内容 |
|---|---|---|
| `MoodAnalyzer` | `src/utils/fallbackAnalysis.js` | 3軸（気分 = Q1、エネルギー = (social+physical)/2、自己充足 = (motivation+fulfillment)/2）を ≤33 / ≤66 / それより上で分類 → 27通りの感情タイプ、totalScore（.30/.25/.20/.10/.15 の重み付け）、定型文の手紙 |
| `StarAppearance` | `src/utils/starDataMaker.js` | 色（5色をスライダー値で重み付け。全部 100 なら金、全部 0 なら灰）、scale |
| `StarPlacement` | `src/utils/starDataMaker.js` | 星座の中の座標と、星座の外のランダムな座標（最大50回まで再試行） |
| `ConstellationAssigner` | `src/utils/starDataMaker.js`, `src/data/constellationData.js` | 全5値が 50 以上のとき、配列の順に見て、空いているノードを割り当てる。対象は9星座 |
| `DiaryCycle` | `src/utils/appTime.js` | 朝6時区切り、クールダウンの残り時間と進み具合、デバッグ用の日数オフセット |

- 乱数は注入できる形にして、テストで結果を固定できるようにする。
- 星座データ（9星座のノード座標、説明、特徴、歴史）は JSON としてアプリに同梱する。

## 8. 星からの手紙（Firebase AI Logic）

- **バックエンド**: Gemini Developer API（無料枠）。
- **モデル**: `gemini-3.5-flash`。
  - モデル名はアプリに直接書かず、Remote Config の `letter_model` で配信する。
  - `gemini-2.5-flash` は 2026-11-02 に非推奨になったため使わない。
  - 実装を始める前に、モデル一覧を再確認する。
- **入力**: スライダー5値、いいこと最大3件。プロンプトは Web版 `supabase/functions/analyze-diary/index.ts` から移植する。
- **出力**: JSON の `{feedback}` を構造化出力で受け取る。
- **役割の分担**: 感情タイプと totalScore はドメインで計算する。AI は手紙の文章だけを作る。
- **App Check**: App Attest で有効にする。
- **失敗したとき**: 通信エラー、タイムアウト（10秒）、回数制限、パースの失敗のいずれでも、`MoodAnalyzer` の定型文の手紙を使う。打ち上げは止めず、ユーザーにエラーは見せない。

## 9. エラー処理

| 場面 | 振る舞い |
|---|---|
| 手紙の生成に失敗 | 定型文の手紙で打ち上げを続ける |
| オフラインで打ち上げ | Firestore のキャッシュに書き込み、星空にすぐ表示する。通信が戻ったら自動で送信する |
| 認証の失敗 | 日本語のメッセージをモーダル内に表示する |
| アカウント削除に再ログインが必要 | 再ログインしてもらってから削除を続ける |
| 描画が重い | 画質を自動で下げる |
| Firestore の読み込み失敗 | キャッシュを表示し、控えめなバナーで通知する |

## 10. テスト

- **ドメインの単体テスト（最重要）**
  - Web版の JS 関数を Node で実行して、入力と出力の組（ゴールデンデータ）を JSON に書き出し、リポジトリに保存する。
  - Swift 側の結果がそれと一致するかを XCTest / Swift Testing で確認する。
  - 対象: 感情判定、色、scale、星座の割り当て、朝6時区切りの計算。
- **データ層**: Firebase Emulator Suite（Auth / Firestore）につないで、保存・読み込み・削除・セキュリティルールを確認する。
- **画面**: モックのリポジトリを使って、各モーダルを Xcode Preview で確認する。
- **星空**: 層ごとに Web版と並べて目で比べる。
- **実機**: 各段階の終わりに TestFlight で自分の iPhone に入れて使う。

## 11. 段階的なリリース

| 段階 | 内容 |
|---|---|
| 1. 土台 | 3種のログインと新規登録、パスワード再設定、プロフィール設定、星空（背景・天の川・遠い星・霧・ブルームなどの後処理）、ユーザーの星、日記、打ち上げ演出、星の詳細（手紙）、クールダウン |
| 2. 振り返り | ログ（カレンダー、タグでの絞り込み、星への移動）、プロフィール（名前、メール、パスワード、タグの編集、アカウント削除） |
| 3. 演出 | マイセイザ、星座ライン、完成画像、未来への手紙と流れ星、テーマ7種とスカイボックス3種、遠くの流れ星 |
| 4. 仕上げ | チュートリアル（31ステップ）、イントロとグリッチ演出、App Store 公開の準備（プライバシーポリシー、プライバシー申告、スクリーンショット） |

- 段階ごとに実装計画を作り、TestFlight で確認してから次へ進む。
- App Store での公開は段階4の後とする。

## 12. 範囲外
- Android / Web 版
- 既存の Supabase データの移行
- SwiftData による端末内保存
- iPad 対応、横画面対応
- 音声ガイド、星座への自動移動アニメーション（Web版でも未実装）
