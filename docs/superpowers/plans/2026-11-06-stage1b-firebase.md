# 段階1b：Firebase（認証・データ・星からの手紙）実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** メール/Apple/Google の認証、Firestore への保存（プロフィール・タグ・星・アカウント削除）、Gemini による星からの手紙を、UI から呼べるサービスとして実装する。

**Architecture:** UI から使う型と約束（プロトコル）と、Firebase に依存しない処理（星の組み立て、手紙のプロンプト、タイムアウトと定型文への切り替え、エラーの日本語化）は `NostargiaKit` に置き、`swift test` で確かめる。Firebase に触れる実装はアプリ本体の `App/Firebase/` に置き、アプリをホストにしたテストターゲット `NostargiaTests` から Firebase Emulator（Auth / Firestore、仮プロジェクト `demo-nostargia`）に対して確かめる。セキュリティルールは Node の `@firebase/rules-unit-testing` で確かめる。Gemini（AI Logic）は本物のプロジェクトが要るため、最後に手動で確認する。

**Tech Stack:** Swift 6.2 / Swift Testing（Kit）/ XCTest（エミュレーター結合テスト）/ firebase-ios-sdk 13.1.1（FirebaseAuth, FirebaseFirestore, FirebaseAILogic, FirebaseRemoteConfig, FirebaseAppCheck）/ GoogleSignIn-iOS 10.1.0 / firebase-tools 15 / Node 26

**Spec:** `docs/superpowers/specs/2026-11-06-nostargia-ios-design.md`（3章 認証、4章 データ、8章 手紙、9章 エラー、10章 テスト）

**前提:** 段階1a（`NostargiaKit` のドメイン、XcodeGen のアプリ）がマージ済み。シミュレーター「iPhone 17」（iOS 26.0）が作成済み。

**この計画に UI は含まない。** ログイン画面・日記・打ち上げなどの画面は段階1d で作る。Apple / Google のサインインを実際に画面から通す確認も1d で行う。

## Global Constraints

- iOS 17.0 以上、iPhone のみ、縦画面。Bundle ID `com.mn329.nostargia`、Team ID `K3BSAX58ZG`、署名は Automatic
- `NostargiaKit` は Foundation 以外を import しない。公開型はすべて `Sendable`
- Firebase を import するファイルは `@preconcurrency import` を使う（Swift 6 モードで Firebase の非 Sendable 型を扱うため）
- 秘密情報・環境固有の値はコミットしない：`GoogleService-Info.plist`、`Config/Firebase.xcconfig`（`.example` だけコミット）
- Firestore のパスは `users/{uid}`、`users/{uid}/stars/{id}`、`users/{uid}/tags/{id}`（spec 4章）。フィールド名も spec 4章どおり
- 新規登録時の初期タグは「休日」「誕生日」「アニバーサリー」の順
- 手紙のモデル名は Remote Config `letter_model`、既定値 `gemini-3.5-flash`。タイムアウト 10 秒。失敗時は `MoodAnalyzer` の定型文
- いいことは前後の空白を除き、空の行を捨て、最大3件（段階1a の軽微な指摘への対応）
- エミュレーターのポート：Auth 9099、Firestore 8080。仮プロジェクト ID `demo-nostargia`
- コミットメッセージの末尾に `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` を付ける

## Review Focus

- 他人のデータ：ログイン中のユーザーが別ユーザーの `users/{uid}` 以下を読み書きしようとすると拒否される（Task 6 のルールテスト、Task 7 の結合テスト）
- AI が返事をしない・遅い：Gemini が応答しない場合も 10 秒で定型文に切り替わり、打ち上げが止まらない（Task 3 のテスト）
- AI の返事が壊れている：コードブロック付き、JSON でない、feedback が空 のいずれでも定型文になる（Task 3 のテスト）
- アカウント削除の途中失敗：データ削除の後に認証の削除が「再ログインが必要」で失敗しても、もう一度実行すれば最後まで消せる（Task 8・Task 9 のテスト）
- いいことを4件以上・空白だけで渡された場合：保存される星にも手紙のプロンプトにも、空の項目や4件目が入らない（Task 1・Task 2 のテスト）

---

## ファイル構成

```
Nostargia-iOS/
├── .gitignore                         （Config/Firebase.xcconfig と生成物を追加）
├── project.yml                        （Firebase / GoogleSignIn、エンタイトルメント、テストターゲット）
├── firebase.json                      エミュレーターとルールの設定
├── firestore.rules                    本人の users/{uid} 以下だけ読み書き可
├── scripts/test-emulator.sh           エミュレーターを起動して iOS テストを流す
├── Config/Firebase.xcconfig.example   GOOGLE_REVERSED_CLIENT_ID のひな形
├── docs/firebase-setup.md             Firebase コンソールでの準備手順
├── tools/golden/generate.mjs          （手紙プロンプトのゴールデンデータを追加）
├── tools/rules-test/                  セキュリティルールのテスト（Node）
├── App/
│   ├── NostargiaApp.swift             （Firebase の初期化と Google の URL 処理を追加）
│   ├── Nostargia.entitlements         生成物（project.yml から。コミットしない）
│   ├── Info.plist                     生成物（project.yml から。コミットしない）
│   └── Firebase/
│       ├── FirebaseBootstrap.swift    本番 / エミュレーターの切り替えと App Check
│       ├── FirestoreStarMapping.swift Star ⇔ Firestore の辞書
│       ├── FirestoreStarRepository.swift
│       ├── FirestoreProfileRepository.swift  プロフィール・初期タグ・全データ削除
│       ├── FirestoreTagRepository.swift
│       ├── FirebaseAuthService.swift  メール認証・資格情報でのサインイン・アカウント削除
│       ├── AppleSignInHelper.swift    nonce と Apple の資格情報
│       ├── GoogleSignInHelper.swift
│       └── GeminiLetterGenerator.swift
├── AppTests/                          エミュレーター結合テスト（XCTest、アプリがホスト）
│   ├── EmulatorSupport.swift
│   ├── FirebaseBootstrapTests.swift
│   ├── FirestoreStarRepositoryTests.swift
│   ├── FirestoreProfileTagTests.swift
│   ├── FirebaseAuthServiceTests.swift
│   └── AppleSignInHelperTests.swift
└── Packages/NostargiaKit/Sources/NostargiaKit/
    ├── Records.swift                  Star / StarDraft / Tag / TagRef / UserProfile
    ├── StarComposer.swift             DiaryEntry と保存前の星の組み立て
    ├── Services.swift                 AuthService / StarRepository / TagRepository / ProfileRepository
    ├── LetterPrompt.swift             Web版 analyze-diary のプロンプト
    ├── LetterService.swift            タイムアウト・応答の解析・失敗時は nil
    └── AuthFailure.swift              Firebase Auth のエラーコード → 日本語
```

---

### Task 1: 保存する記録の型と StarComposer

**Files:**
- Create: `Packages/NostargiaKit/Sources/NostargiaKit/Records.swift`
- Create: `Packages/NostargiaKit/Sources/NostargiaKit/StarComposer.swift`
- Create: `Packages/NostargiaKit/Sources/NostargiaKit/Services.swift`
- Test: `Packages/NostargiaKit/Tests/NostargiaKitTests/StarComposerTests.swift`

**Interfaces:**
- Consumes: `MoodValues`, `MoodAnalyzer`, `StarFactory`, `ExistingStar`, `StarPosition`, `StarColor`, `ConstellationAssignment`, `ConstellationCatalog`, `RandomSource`（段階1a）、テスト用 `SequenceRandom`（段階1a）
- Produces:
  - `public struct TagRef: Codable, Hashable, Sendable { id: String; name: String }`
  - `public struct Tag: Hashable, Sendable, Identifiable { id: String; name: String; createdAt: Date }`
  - `public struct UserProfile: Hashable, Sendable { userName: String; birthday: Date }`
  - `public struct StarDraft: Hashable, Sendable`（`position, color, scale, random, displayDate: Date, mood, emotion, feedback, totalScore, goodThings: [String], tag: TagRef?, constellation: ConstellationAssignment?, isTutorial: Bool`）
  - `public struct Star: Hashable, Sendable, Identifiable`（`id: String; createdAt: Date?` と StarDraft と同じフィールド、`init(id:createdAt:draft:)`、`var draft: StarDraft`）
  - `public struct DiaryEntry: Hashable, Sendable { mood; goodThings: [String]; tag: TagRef?; isTutorial: Bool; static let maxGoodThings = 3; static func normalize(_: [String]) -> [String]; var normalizedGoodThings: [String] }`
  - `public enum StarComposer { static func draft(entry: DiaryEntry, existing: [Star], letter: String?, now: Date, catalog: [Constellation] = ConstellationCatalog.all, random: inout some RandomSource) -> StarDraft }`
  - `Services.swift` のプロトコル（後続タスクが実装する）:
    - `public enum AuthProvider: String, Sendable { case password, apple = "apple.com", google = "google.com" }`
    - `public struct AuthUser: Hashable, Sendable { uid: String; email: String?; providers: Set<AuthProvider> }`
    - `public protocol AuthService: Sendable { var currentUser: AuthUser? { get }; func authStates() -> AsyncStream<AuthUser?>; func signUp(email: String, password: String) async throws -> AuthUser; func signIn(email: String, password: String) async throws -> AuthUser; func sendPasswordReset(email: String) async throws; func updatePassword(_ password: String) async throws; func requestEmailChange(to email: String) async throws; func signOut() throws; func deleteAccount(appleAuthorizationCode: String?) async throws }`
    - `public protocol StarRepository: Sendable { func stars() -> AsyncThrowingStream<[Star], Error>; func add(_ draft: StarDraft) async throws -> String; func delete(ids: [String]) async throws }`
    - `public protocol TagRepository: Sendable { func tags() async throws -> [Tag]; func add(name: String) async throws -> Tag; func rename(id: String, to name: String) async throws; func delete(id: String) async throws }`
    - `public protocol ProfileRepository: Sendable { func profile() async throws -> UserProfile?; func create(_ profile: UserProfile) async throws; func updateUserName(_ name: String) async throws; func deleteAllData() async throws }`

- [ ] **Step 1: 失敗するテストを書く**

`Packages/NostargiaKit/Tests/NostargiaKitTests/StarComposerTests.swift`:
```swift
import Foundation
import Testing
@testable import NostargiaKit

struct StarComposerTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func normalizesGoodThings() {
        #expect(DiaryEntry.normalize(["  散歩  ", "", "\u{3000}", "カフェ", "読書", "映画"]) == ["散歩", "カフェ", "読書"])
    }

    @Test func usesLetterWhenAvailable() {
        var random = SequenceRandom([0.5])
        let entry = DiaryEntry(mood: MoodValues(all: 20), goodThings: [" 散歩 "], tag: TagRef(id: "t1", name: "休日"))
        let draft = StarComposer.draft(entry: entry, existing: [], letter: "星からの手紙", now: now, random: &random)
        #expect(draft.feedback == "星からの手紙")
        #expect(draft.emotion == "消耗・虚無")
        #expect(draft.totalScore == 20)
        #expect(draft.goodThings == ["散歩"])
        #expect(draft.tag == TagRef(id: "t1", name: "休日"))
        #expect(draft.displayDate == now)
        #expect(draft.mood == MoodValues(all: 20))
        #expect(!draft.isTutorial)
    }

    @Test func fallsBackToTemplateLetter() {
        var random = SequenceRandom([0.5])
        let entry = DiaryEntry(mood: MoodValues(all: 20), goodThings: ["散歩"], tag: nil)
        let draft = StarComposer.draft(entry: entry, existing: [], letter: nil, now: now, random: &random)
        #expect(draft.feedback == MoodAnalyzer.analyze(MoodValues(all: 20), goodThings: ["散歩"]).fallbackFeedback)
    }

    @Test func matchesStarFactoryBlueprint() {
        let mood = MoodValues(all: 80)
        var a = SequenceRandom([0.5, 0.3, 0.7])
        var b = SequenceRandom([0.5, 0.3, 0.7])
        let draft = StarComposer.draft(entry: DiaryEntry(mood: mood, goodThings: [], tag: nil), existing: [], letter: nil, now: now, random: &a)
        let blueprint = StarFactory.make(mood: mood, existing: [], random: &b)
        #expect(draft.position == blueprint.position)
        #expect(draft.color == blueprint.color)
        #expect(draft.scale == blueprint.scale)
        #expect(draft.random == blueprint.random)
        #expect(draft.constellation == blueprint.constellation)
    }

    @Test func existingConstellationStarsAreRespected() {
        let taken = Star(
            id: "s1",
            createdAt: nil,
            draft: StarDraft(
                position: StarPosition(x: 0, y: 0, z: 0), color: StarColor(r: 1, g: 1, b: 1), scale: 2, random: 0,
                displayDate: now, mood: MoodValues(all: 80), emotion: "", feedback: "", totalScore: 80,
                goodThings: [], tag: nil, constellation: ConstellationAssignment(id: "andromeda", nodeIndex: 0), isTutorial: false
            )
        )
        var random = SequenceRandom([0.5])
        let draft = StarComposer.draft(entry: DiaryEntry(mood: MoodValues(all: 80), goodThings: [], tag: nil), existing: [taken], letter: nil, now: now, random: &random)
        #expect(draft.constellation == ConstellationAssignment(id: "andromeda", nodeIndex: 1))
    }
}
```

- [ ] **Step 2: 失敗を確認する**

Run: `cd Packages/NostargiaKit && swift test --filter StarComposerTests`
Expected: FAIL（`cannot find 'DiaryEntry' in scope`）

- [ ] **Step 3: 実装する**

`Packages/NostargiaKit/Sources/NostargiaKit/Records.swift`:
```swift
import Foundation

/// 星に付けたタグ。タグを削除しても表示できるように名前もコピーして持つ
public struct TagRef: Codable, Hashable, Sendable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public struct Tag: Hashable, Sendable, Identifiable {
    public let id: String
    public var name: String
    public let createdAt: Date

    public init(id: String, name: String, createdAt: Date) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}

public struct UserProfile: Hashable, Sendable {
    public var userName: String
    public var birthday: Date

    public init(userName: String, birthday: Date) {
        self.userName = userName
        self.birthday = birthday
    }
}

/// 保存前の星（ID と保存時刻はデータ層が付ける）
public struct StarDraft: Hashable, Sendable {
    public var position: StarPosition
    public var color: StarColor
    public var scale: Double
    public var random: Double
    /// 朝6時区切りの判定とカレンダー表示に使う日時（デバッグ用の日数ずらし込み）
    public var displayDate: Date
    public var mood: MoodValues
    public var emotion: String
    public var feedback: String
    public var totalScore: Double
    public var goodThings: [String]
    public var tag: TagRef?
    public var constellation: ConstellationAssignment?
    public var isTutorial: Bool

    public init(
        position: StarPosition, color: StarColor, scale: Double, random: Double, displayDate: Date,
        mood: MoodValues, emotion: String, feedback: String, totalScore: Double, goodThings: [String],
        tag: TagRef?, constellation: ConstellationAssignment?, isTutorial: Bool
    ) {
        self.position = position
        self.color = color
        self.scale = scale
        self.random = random
        self.displayDate = displayDate
        self.mood = mood
        self.emotion = emotion
        self.feedback = feedback
        self.totalScore = totalScore
        self.goodThings = goodThings
        self.tag = tag
        self.constellation = constellation
        self.isTutorial = isTutorial
    }
}

/// 保存済みの星
public struct Star: Hashable, Sendable, Identifiable {
    public let id: String
    /// サーバー時刻。オフラインで書いた直後は推定値
    public let createdAt: Date?
    public var position: StarPosition
    public var color: StarColor
    public var scale: Double
    public var random: Double
    public var displayDate: Date
    public var mood: MoodValues
    public var emotion: String
    public var feedback: String
    public var totalScore: Double
    public var goodThings: [String]
    public var tag: TagRef?
    public var constellation: ConstellationAssignment?
    public var isTutorial: Bool

    public init(id: String, createdAt: Date?, draft: StarDraft) {
        self.id = id
        self.createdAt = createdAt
        position = draft.position
        color = draft.color
        scale = draft.scale
        random = draft.random
        displayDate = draft.displayDate
        mood = draft.mood
        emotion = draft.emotion
        feedback = draft.feedback
        totalScore = draft.totalScore
        goodThings = draft.goodThings
        tag = draft.tag
        constellation = draft.constellation
        isTutorial = draft.isTutorial
    }

    public var draft: StarDraft {
        StarDraft(
            position: position, color: color, scale: scale, random: random, displayDate: displayDate,
            mood: mood, emotion: emotion, feedback: feedback, totalScore: totalScore, goodThings: goodThings,
            tag: tag, constellation: constellation, isTutorial: isTutorial
        )
    }
}
```

`Packages/NostargiaKit/Sources/NostargiaKit/StarComposer.swift`:
```swift
import Foundation

/// 日記モーダルで入力された内容
public struct DiaryEntry: Hashable, Sendable {
    public static let maxGoodThings = 3

    public var mood: MoodValues
    public var goodThings: [String]
    public var tag: TagRef?
    public var isTutorial: Bool

    public init(mood: MoodValues, goodThings: [String], tag: TagRef?, isTutorial: Bool = false) {
        self.mood = mood
        self.goodThings = goodThings
        self.tag = tag
        self.isTutorial = isTutorial
    }

    /// 前後の空白を除き、空の行を捨て、最大3件にする
    public static func normalize(_ goodThings: [String]) -> [String] {
        Array(
            goodThings
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .prefix(maxGoodThings)
        )
    }

    public var normalizedGoodThings: [String] { Self.normalize(goodThings) }
}

/// 日記の入力から保存前の星を組み立てる（Web版 UI.jsx の handleSend で行っていた組み立て）
public enum StarComposer {
    /// letter が nil のとき（AI が使えなかったとき）は定型文の手紙を使う
    public static func draft(
        entry: DiaryEntry,
        existing: [Star],
        letter: String?,
        now: Date,
        catalog: [Constellation] = ConstellationCatalog.all,
        random: inout some RandomSource
    ) -> StarDraft {
        let goodThings = entry.normalizedGoodThings
        let analysis = MoodAnalyzer.analyze(entry.mood, goodThings: goodThings)
        let blueprint = StarFactory.make(
            mood: entry.mood,
            existing: existing.map { ExistingStar(position: $0.position, constellation: $0.constellation) },
            catalog: catalog,
            random: &random
        )
        return StarDraft(
            position: blueprint.position,
            color: blueprint.color,
            scale: blueprint.scale,
            random: blueprint.random,
            displayDate: now,
            mood: entry.mood,
            emotion: analysis.emotion,
            feedback: letter ?? analysis.fallbackFeedback,
            totalScore: analysis.totalScore,
            goodThings: goodThings,
            tag: entry.tag,
            constellation: blueprint.constellation,
            isTutorial: entry.isTutorial
        )
    }
}
```

`Packages/NostargiaKit/Sources/NostargiaKit/Services.swift`:
```swift
import Foundation

public enum AuthProvider: String, Hashable, Sendable {
    case password
    case apple = "apple.com"
    case google = "google.com"
}

public struct AuthUser: Hashable, Sendable {
    public let uid: String
    public let email: String?
    public let providers: Set<AuthProvider>

    public init(uid: String, email: String?, providers: Set<AuthProvider>) {
        self.uid = uid
        self.email = email
        self.providers = providers
    }
}

/// 認証。失敗は AuthFailure で投げる
public protocol AuthService: Sendable {
    var currentUser: AuthUser? { get }
    func authStates() -> AsyncStream<AuthUser?>
    func signUp(email: String, password: String) async throws -> AuthUser
    func signIn(email: String, password: String) async throws -> AuthUser
    func sendPasswordReset(email: String) async throws
    func updatePassword(_ password: String) async throws
    /// 新しいアドレスに確認リンクを送る。リンクを押すと変更が確定する
    func requestEmailChange(to email: String) async throws
    func signOut() throws
    /// Apple でサインインしたユーザーは、直前に取得した認可コードを渡して Apple の認証も取り消す
    func deleteAccount(appleAuthorizationCode: String?) async throws
}

/// ログイン中のユーザーの星
public protocol StarRepository: Sendable {
    /// 表示日時の古い順。変更があるたびに全件を流す
    func stars() -> AsyncThrowingStream<[Star], Error>
    func add(_ draft: StarDraft) async throws -> String
    func delete(ids: [String]) async throws
}

/// ログイン中のユーザーのタグ（作成順）
public protocol TagRepository: Sendable {
    func tags() async throws -> [Tag]
    func add(name: String) async throws -> Tag
    func rename(id: String, to name: String) async throws
    func delete(id: String) async throws
}

public protocol ProfileRepository: Sendable {
    /// まだ作っていなければ nil（Apple / Google の初回ログイン）
    func profile() async throws -> UserProfile?
    /// プロフィールと初期タグ（休日・誕生日・アニバーサリー）を作る
    func create(_ profile: UserProfile) async throws
    func updateUserName(_ name: String) async throws
    /// users/{uid} 以下をすべて消す。何度呼んでもよい
    func deleteAllData() async throws
}
```

- [ ] **Step 4: 成功を確認する**

Run: `cd Packages/NostargiaKit && swift test`
Expected: PASS（38 tests：既存 33 + 新規 5）

- [ ] **Step 5: Commit**

```bash
git add Packages/NostargiaKit
git commit -m "feat: 保存する記録の型と StarComposer、サービスのプロトコルを追加"
```

---

### Task 2: 手紙のプロンプト（Web版と一字一句同じ）

**Files:**
- Modify: `tools/golden/generate.mjs`（末尾の書き出しの前に追加）
- Create（生成物）: `Packages/NostargiaKit/Tests/NostargiaKitTests/Fixtures/letter_prompt.json`
- Create: `Packages/NostargiaKit/Sources/NostargiaKit/LetterPrompt.swift`
- Test: `Packages/NostargiaKit/Tests/NostargiaKitTests/LetterPromptTests.swift`

**Interfaces:**
- Consumes: `MoodValues`, `MoodAnalyzer`（`emotion`, `totalScore`, `level`）、`DiaryEntry.normalize`（Task 1）、`Fixture`（段階1a）
- Produces: `public enum LetterPrompt { static func build(mood: MoodValues, goodThings: [String]) -> String }`（goodThings は normalize 済みを渡す）

- [ ] **Step 1: ゴールデンデータの生成を追加する**

`tools/golden/generate.mjs` の `const write = ...` の行の直前に追加する:
```js
// supabase/functions/analyze-diary/index.ts のプロンプト組み立て部分をそのまま実行する
const edgeSrc = readFileSync(join(webRepo, 'supabase/functions/analyze-diary/index.ts'), 'utf8');
const promptStart = edgeSrc.indexOf('const goodThingsSection');
const promptEnd = edgeSrc.indexOf('}`', promptStart) + 2;
if (promptStart < 0 || promptEnd < 2) throw new Error('analyze-diary のプロンプトが見つかりません');
const buildPrompt = new Function(
  'axes', 'emotion', 'emotional', 'motivation', 'social', 'physical', 'fulfillment', 'goodThingsList',
  `${edgeSrc.slice(promptStart, promptEnd)}\nreturn prompt;`,
);
const axesFns = extractFunctions('src/utils/fallbackAnalysis.js', ['toLevel', 'calculateThreeAxes']);
const { calculateThreeAxes } = new Function(`${axesFns.code}\nreturn { calculateThreeAxes };`)();
const PROMPT_GOOD_THINGS = [[], ['散歩した'], ['  空がきれい  ', '', '友達と話した'], ['a', 'b', 'c']];
const letterPrompt = moods.slice(0, 60).map((mood, i) => {
  const goodThings = PROMPT_GOOD_THINGS[i % PROMPT_GOOD_THINGS.length];
  const goodThingsList = goodThings.filter((s) => !!s && typeof s === 'string').map((s) => s.trim()).filter(Boolean);
  const axes = calculateThreeAxes(mood);
  const { emotion } = getFallbackAnalysis(mood);
  const prompt = buildPrompt(axes, emotion, mood.emotional, mood.motivation, mood.social, mood.physical, mood.fulfillment, goodThingsList);
  return { mood, goodThings, prompt };
});
```

さらに、既存の `write(fixturesDir, 'diary_cycle.json', diaryCycle);` の次の行に追加する:
```js
write(fixturesDir, 'letter_prompt.json', letterPrompt);
```

- [ ] **Step 2: 生成して、既存のゴールデンデータが変わっていないことを確認する**

Run: `TZ=Asia/Tokyo node tools/golden/generate.mjs ../Nostargia && git status --short Packages`
Expected: 1行目は `mood 454 件 / 感情タイプ 27 種 / 星座 9 個 / 時刻 151 件`。`git status` に出るのは `?? .../Fixtures/letter_prompt.json` だけ（既存の JSON に変更なし）

- [ ] **Step 3: 失敗するテストを書く**

`Packages/NostargiaKit/Tests/NostargiaKitTests/LetterPromptTests.swift`:
```swift
import Foundation
import Testing
@testable import NostargiaKit

struct LetterPromptTests {
    struct GoldenCase: Decodable {
        let mood: MoodValues
        let goodThings: [String]
        let prompt: String
    }

    @Test func matchesWebEdgeFunction() throws {
        let cases = try Fixture.load("letter_prompt", as: [GoldenCase].self)
        #expect(cases.count == 60)
        for c in cases {
            #expect(LetterPrompt.build(mood: c.mood, goodThings: DiaryEntry.normalize(c.goodThings)) == c.prompt, "\(c.mood) \(c.goodThings)")
        }
    }

    @Test func halfPointsAreWrittenLikeJavaScript() {
        let prompt = LetterPrompt.build(mood: MoodValues(emotional: 50, motivation: 50, social: 50, physical: 51, fulfillment: 50), goodThings: [])
        #expect(prompt.contains("エネルギー軸（身体・心理の元気度）: 50.5/100"))
        #expect(prompt.contains("気分軸（直感的な良い/悪い）: 50/100"))
    }
}
```

- [ ] **Step 4: 失敗を確認する**

Run: `cd Packages/NostargiaKit && swift test --filter LetterPromptTests`
Expected: FAIL（`cannot find 'LetterPrompt' in scope`）

- [ ] **Step 5: 実装する**

`Packages/NostargiaKit/Sources/NostargiaKit/LetterPrompt.swift`:
```swift
import Foundation

/// 星からの手紙を Gemini に頼むプロンプト（Web版 supabase/functions/analyze-diary/index.ts と同じ文面）
public enum LetterPrompt {
    /// goodThings は DiaryEntry.normalize 済みのものを渡す
    public static func build(mood: MoodValues, goodThings: [String]) -> String {
        let kibun = Double(mood.emotional)
        let energy = Double(mood.social + mood.physical) / 2
        let jiko = Double(mood.motivation + mood.fulfillment) / 2
        let emotion = MoodAnalyzer.emotion(mood)
        let totalScore = MoodAnalyzer.totalScore(mood)
        let goodThingsSection = goodThings.isEmpty
            ? ""
            : "\n【今日のいいこと】\n" + goodThings.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n") + "\n"
        let goodThingsLead = goodThings.isEmpty ? "" : "今日のいいことに触れつつ、"

        return """
        あなたは宇宙の星のように優しく見守る存在です。ユーザーが今日の気持ちを5つのスライダーで記録しました。

        【三軸感情分析システム】
        このシステムでは、5つのスライダー値を3つの軸に集約して感情を判定しています。

        ■ 三軸の定義:
        1. 気分軸（直感的な良い/悪い）: \(js(kibun))/100 → \(MoodAnalyzer.level(kibun))
        2. エネルギー軸（身体・心理の元気度）: \(js(energy))/100 → \(MoodAnalyzer.level(energy))
        3. 自己充足軸（自己満足・充足感）: \(js(jiko))/100 → \(MoodAnalyzer.level(jiko))

        ■ 各軸の区間: 低(0〜33) / 中(34〜66) / 高(67〜100)

        ■ 総合スコア: \(js(totalScore))/100
        （計算式: Q1×0.30 + Q2×0.25 + Q3×0.20 + Q4×0.10 + Q5×0.15）

        ■ 判定された感情タイプ: \(emotion)

        【元データ（5つのスライダー値）】
        - Q1 気分（今の気持ちは心地いい？）: \(mood.emotional)/100
        - Q2 自分らしさ（今日は自分らしく過ごせた？）: \(mood.motivation)/100
        - Q3 心の満たされ方: \(mood.social)/100
        - Q4 体の状態: \(mood.physical)/100
        - Q5 充実感: \(mood.fulfillment)/100
        \(goodThingsSection)
        上記の三軸分析結果と総合スコアを参考にして、この感情タイプ「\(emotion)」にふさわしい「星からの手紙」として、温かく共感的なメッセージを1-2文で生成してください。
        \(goodThingsLead)ユーザーの気持ちをそのまま受け止め、前向きになれる言葉をかけてください。夜空の星が語りかけるような優しいトーンで。

        注意事項:
        - 総合スコアが低い場合は無理にポジティブにせず、寄り添うメッセージにしてください
        - 三軸のバランス（例: 気分は良いがエネルギーが低いなど）を考慮してメッセージを作成してください
        - 感情タイプの名称をそのまま文中に使わないでください

        回答は以下のJSON形式のみで返してください（他の説明やマークダウンは不要です）：
        {
          "feedback": "フィードバックメッセージ"
        }
        """
    }

    /// JavaScript のテンプレート文字列と同じ数値の書き方（50.0 → "50"、50.5 → "50.5"）
    static func js(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(value)
    }
}
```

- [ ] **Step 6: 成功を確認する**

Run: `cd Packages/NostargiaKit && swift test --filter LetterPromptTests`
Expected: PASS（2 tests）

- [ ] **Step 7: Commit**

```bash
git add tools/golden/generate.mjs Packages/NostargiaKit
git commit -m "feat: 星からの手紙のプロンプトを Web版から移植"
```

---

### Task 3: LetterService（タイムアウトと応答の解析）

**Files:**
- Create: `Packages/NostargiaKit/Sources/NostargiaKit/LetterService.swift`
- Test: `Packages/NostargiaKit/Tests/NostargiaKitTests/LetterServiceTests.swift`

**Interfaces:**
- Consumes: `LetterPrompt`（Task 2）、`DiaryEntry`（Task 1）
- Produces:
  - `public protocol LetterGenerating: Sendable { func generate(prompt: String) async throws -> String }`（AI の生の返事を返す）
  - `public enum LetterResponse { static func feedback(from text: String) -> String? }`
  - `public struct LetterService: Sendable { init(generator: any LetterGenerating, timeout: Duration = .seconds(10)); func letter(for entry: DiaryEntry) async -> String? }`（nil のときは呼び出し側が定型文を使う。StarComposer の `letter:` にそのまま渡せる）

- [ ] **Step 1: 失敗するテストを書く**

`Packages/NostargiaKit/Tests/NostargiaKitTests/LetterServiceTests.swift`:
```swift
import Foundation
import Testing
@testable import NostargiaKit

struct LetterServiceTests {
    struct FixedGenerator: LetterGenerating {
        let text: String
        func generate(prompt: String) async throws -> String { text }
    }

    struct FailingGenerator: LetterGenerating {
        struct Boom: Error {}
        func generate(prompt: String) async throws -> String { throw Boom() }
    }

    /// キャンセルにも応じず、ずっと返事をしない AI
    struct HangingGenerator: LetterGenerating {
        func generate(prompt: String) async throws -> String {
            try? await Task.sleep(for: .seconds(30))
            try? await Task.sleep(for: .seconds(30))
            return #"{"feedback":"遅すぎる返事"}"#
        }
    }

    actor PromptRecorder: LetterGenerating {
        private(set) var prompts: [String] = []
        func generate(prompt: String) async throws -> String {
            prompts.append(prompt)
            return #"{"feedback":"ok"}"#
        }
    }

    let entry = DiaryEntry(mood: MoodValues(all: 70), goodThings: [" 散歩 ", "", "a", "b", "c"], tag: nil)

    @Test func parsesPlainAndFencedJSON() {
        #expect(LetterResponse.feedback(from: #"{"feedback":"きれいな夜ですね。"}"#) == "きれいな夜ですね。")
        #expect(LetterResponse.feedback(from: "```json\n{\"feedback\": \" 星が見ています。 \"}\n```") == "星が見ています。")
    }

    @Test func rejectsBrokenResponses() {
        #expect(LetterResponse.feedback(from: "こんばんは") == nil)
        #expect(LetterResponse.feedback(from: #"{"feedback":"   "}"#) == nil)
        #expect(LetterResponse.feedback(from: #"{"message":"x"}"#) == nil)
    }

    @Test func returnsLetter() async {
        let service = LetterService(generator: FixedGenerator(text: #"{"feedback":"おつかれさま。"}"#))
        #expect(await service.letter(for: entry) == "おつかれさま。")
    }

    @Test func nilWhenGeneratorFails() async {
        #expect(await LetterService(generator: FailingGenerator()).letter(for: entry) == nil)
        #expect(await LetterService(generator: FixedGenerator(text: "JSONではない")).letter(for: entry) == nil)
    }

    @Test func nilAfterTimeoutEvenIfGeneratorHangs() async {
        let service = LetterService(generator: HangingGenerator(), timeout: .milliseconds(200))
        let clock = ContinuousClock()
        let start = clock.now
        let letter = await service.letter(for: entry)
        #expect(letter == nil)
        #expect(clock.now - start < .seconds(2))
    }

    @Test func sendsNormalizedPrompt() async {
        let recorder = PromptRecorder()
        _ = await LetterService(generator: recorder).letter(for: entry)
        let prompts = await recorder.prompts
        #expect(prompts == [LetterPrompt.build(mood: MoodValues(all: 70), goodThings: ["散歩", "a", "b"])])
    }
}
```

- [ ] **Step 2: 失敗を確認する**

Run: `cd Packages/NostargiaKit && swift test --filter LetterServiceTests`
Expected: FAIL（`cannot find type 'LetterGenerating' in scope`）

- [ ] **Step 3: 実装する**

`Packages/NostargiaKit/Sources/NostargiaKit/LetterService.swift`:
```swift
import Foundation

/// 星からの手紙を作る AI。プロンプトを受け取り、生の返事（JSON のはず）を返す
public protocol LetterGenerating: Sendable {
    func generate(prompt: String) async throws -> String
}

/// AI の返事から手紙の本文を取り出す（Web版 analyze-diary と同じくコードブロックの記号を取り除く）
public enum LetterResponse {
    private struct Body: Decodable {
        let feedback: String
    }

    public static func feedback(from text: String) -> String? {
        let cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = cleaned.data(using: .utf8),
              let body = try? JSONDecoder().decode(Body.self, from: data)
        else { return nil }
        let feedback = body.feedback.trimmingCharacters(in: .whitespacesAndNewlines)
        return feedback.isEmpty ? nil : feedback
    }
}

/// 手紙の生成。失敗・タイムアウト・壊れた返事のときは nil を返し、呼び出し側は定型文を使う
public struct LetterService: Sendable {
    private let generator: any LetterGenerating
    private let timeout: Duration

    public init(generator: any LetterGenerating, timeout: Duration = .seconds(10)) {
        self.generator = generator
        self.timeout = timeout
    }

    public func letter(for entry: DiaryEntry) async -> String? {
        let prompt = LetterPrompt.build(mood: entry.mood, goodThings: entry.normalizedGoodThings)
        guard let text = await firstOf(generate: prompt) else { return nil }
        return LetterResponse.feedback(from: text)
    }

    /// AI の返事とタイムアウトのうち先に来た方を返す。AI がキャンセルに応じなくても待たない
    private func firstOf(generate prompt: String) async -> String? {
        let generator = self.generator
        let timeout = self.timeout
        let once = Once()
        return await withCheckedContinuation { continuation in
            let work = Task {
                let text = try? await generator.generate(prompt: prompt)
                if await once.claim() { continuation.resume(returning: text) }
            }
            Task {
                try? await Task.sleep(for: timeout)
                if await once.claim() {
                    work.cancel()
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

/// 一度だけ true を返す
private actor Once {
    private var claimed = false

    func claim() -> Bool {
        if claimed { return false }
        claimed = true
        return true
    }
}
```

- [ ] **Step 4: 成功を確認する**

Run: `cd Packages/NostargiaKit && swift test --filter LetterServiceTests`
Expected: PASS（6 tests）

- [ ] **Step 5: Commit**

```bash
git add Packages/NostargiaKit
git commit -m "feat: 手紙の生成にタイムアウトと応答の解析を行う LetterService を追加"
```

---

### Task 4: AuthFailure（認証エラーの日本語化）

**Files:**
- Create: `Packages/NostargiaKit/Sources/NostargiaKit/AuthFailure.swift`
- Test: `Packages/NostargiaKit/Tests/NostargiaKitTests/AuthFailureTests.swift`

**Interfaces:**
- Produces: `public enum AuthFailure: Error, Hashable, Sendable { case emailAlreadyInUse, invalidEmail, invalidCredential, weakPassword, network, tooManyRequests, requiresRecentLogin, accountExistsWithDifferentCredential, userDisabled, unknown(code: Int); static let firebaseErrorDomain: String; init(code: Int); var message: String }`

- [ ] **Step 1: 失敗するテストを書く**

`Packages/NostargiaKit/Tests/NostargiaKitTests/AuthFailureTests.swift`:
```swift
import Foundation
import Testing
@testable import NostargiaKit

struct AuthFailureTests {
    @Test func mapsFirebaseAuthCodes() {
        #expect(AuthFailure(code: 17007) == .emailAlreadyInUse)
        #expect(AuthFailure(code: 17008) == .invalidEmail)
        #expect(AuthFailure(code: 17009) == .invalidCredential)
        #expect(AuthFailure(code: 17004) == .invalidCredential)
        #expect(AuthFailure(code: 17011) == .invalidCredential)
        #expect(AuthFailure(code: 17026) == .weakPassword)
        #expect(AuthFailure(code: 17020) == .network)
        #expect(AuthFailure(code: 17010) == .tooManyRequests)
        #expect(AuthFailure(code: 17014) == .requiresRecentLogin)
        #expect(AuthFailure(code: 17012) == .accountExistsWithDifferentCredential)
        #expect(AuthFailure(code: 17005) == .userDisabled)
        #expect(AuthFailure(code: 99999) == .unknown(code: 99999))
    }

    @Test func messagesAreJapanese() {
        #expect(AuthFailure.invalidCredential.message == "メールアドレスまたはパスワードが違います。")
        #expect(AuthFailure.unknown(code: 42).message == "エラーが発生しました。（コード: 42）")
    }
}
```

- [ ] **Step 2: 失敗を確認する**

Run: `cd Packages/NostargiaKit && swift test --filter AuthFailureTests`
Expected: FAIL（`cannot find 'AuthFailure' in scope`）

- [ ] **Step 3: 実装する**

`Packages/NostargiaKit/Sources/NostargiaKit/AuthFailure.swift`:
```swift
import Foundation

/// 認証の失敗（Web版 src/utils/errorTranslator.js に相当）
public enum AuthFailure: Error, Hashable, Sendable {
    case emailAlreadyInUse
    case invalidEmail
    case invalidCredential
    case weakPassword
    case network
    case tooManyRequests
    case requiresRecentLogin
    case accountExistsWithDifferentCredential
    case userDisabled
    case unknown(code: Int)

    /// Firebase Auth の NSError のドメイン
    public static let firebaseErrorDomain = "FIRAuthErrorDomain"

    /// Firebase Auth のエラーコード（AuthErrorCode の rawValue）から作る
    public init(code: Int) {
        switch code {
        case 17007: self = .emailAlreadyInUse
        case 17008: self = .invalidEmail
        case 17004, 17009, 17011: self = .invalidCredential
        case 17026: self = .weakPassword
        case 17020: self = .network
        case 17010: self = .tooManyRequests
        case 17014: self = .requiresRecentLogin
        case 17012: self = .accountExistsWithDifferentCredential
        case 17005: self = .userDisabled
        default: self = .unknown(code: code)
        }
    }

    public var message: String {
        switch self {
        case .emailAlreadyInUse: "このメールアドレスはすでに登録されています。"
        case .invalidEmail: "メールアドレスの形式が正しくありません。"
        case .invalidCredential: "メールアドレスまたはパスワードが違います。"
        case .weakPassword: "パスワードは6文字以上にしてください。"
        case .network: "通信できませんでした。電波の良い場所でもう一度お試しください。"
        case .tooManyRequests: "試行回数が多すぎます。しばらく時間をおいてからお試しください。"
        case .requiresRecentLogin: "安全のため、もう一度ログインしてからお試しください。"
        case .accountExistsWithDifferentCredential: "このメールアドレスは別のログイン方法で登録されています。"
        case .userDisabled: "このアカウントは利用できません。"
        case .unknown(let code): "エラーが発生しました。（コード: \(code)）"
        }
    }
}
```

- [ ] **Step 4: 成功を確認する**

Run: `cd Packages/NostargiaKit && swift test`
Expected: PASS（48 tests）

- [ ] **Step 5: Commit**

```bash
git add Packages/NostargiaKit
git commit -m "feat: Firebase 認証エラーを日本語にする AuthFailure を追加"
```

---

### Task 5: Firebase の組み込みとエミュレーターのテスト環境

**Files:**
- Modify: `.gitignore`（`Config/Firebase.xcconfig`、生成物の `App/Info.plist`・`App/Nostargia.entitlements`、`build/` を追加）
- Modify: `project.yml`
- Modify: `App/NostargiaApp.swift`
- Create: `Config/Firebase.xcconfig.example`
- Create: `App/Firebase/FirebaseBootstrap.swift`
- Create: `firebase.json`
- Create: `scripts/test-emulator.sh`
- Create: `AppTests/EmulatorSupport.swift`
- Test: `AppTests/FirebaseBootstrapTests.swift`

**Interfaces:**
- Consumes: `AuthUser`, `AuthService`（Task 1）
- Produces:
  - `enum FirebaseBootstrap { enum Mode { case production, emulator }; static let demoProjectID = "demo-nostargia"; static func mode(environment: [String: String], arguments: [String], hasConfigFile: Bool) -> Mode; static func configure(processInfo: ProcessInfo = .processInfo, bundle: Bundle = .main) }`
  - テスト用: `enum EmulatorSupport { static func freshEmail() -> String; static let password: String; static func firstValue<T: Sendable>(of: AsyncThrowingStream<T, Error>, timeout: Duration = .seconds(10), where: @escaping @Sendable (T) -> Bool) async throws -> T }`
  - `scripts/test-emulator.sh [xcodebuild の追加引数...]`：Auth/Firestore エミュレーターを起動して `NostargiaTests` を流す

- [ ] **Step 1: 設定ファイルを用意する**

`.gitignore` の末尾に追加（Info.plist とエンタイトルメントは XcodeGen の生成物）:
```
Config/Firebase.xcconfig
App/Info.plist
App/Nostargia.entitlements
build/
```

`Config/Firebase.xcconfig.example`:
```
// cp Config/Firebase.xcconfig.example Config/Firebase.xcconfig して値を書き換える
// 値は GoogleService-Info.plist の REVERSED_CLIENT_ID（Google でサインインのコールバック URL）
GOOGLE_REVERSED_CLIENT_ID = com.googleusercontent.apps.000000000000-placeholder
```

Run: `cp Config/Firebase.xcconfig.example Config/Firebase.xcconfig`

`firebase.json`:
```json
{
  "firestore": {
    "rules": "firestore.rules"
  },
  "emulators": {
    "auth": { "host": "127.0.0.1", "port": 9099 },
    "firestore": { "host": "127.0.0.1", "port": 8080 },
    "ui": { "enabled": false },
    "singleProjectMode": true
  }
}
```

この時点ではルールファイルがまだ無いので、空でよいルールを置く（Task 6 で本物にする）。

`firestore.rules`:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

`scripts/test-emulator.sh`:
```bash
#!/bin/bash
# Auth / Firestore エミュレーターを起動して、アプリをホストにした結合テストを流す
# 使い方: scripts/test-emulator.sh [-only-testing:NostargiaTests/クラス名 ...]
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f Config/Firebase.xcconfig ] || cp Config/Firebase.xcconfig.example Config/Firebase.xcconfig
xcodegen generate --quiet
firebase emulators:exec --only auth,firestore --project demo-nostargia \
  "xcodebuild test -project Nostargia.xcodeproj -scheme Nostargia -destination 'platform=iOS Simulator,name=iPhone 17' -quiet $*"
```

Run: `chmod +x scripts/test-emulator.sh`

- [ ] **Step 2: project.yml を書き換える**

`project.yml` 全体を次の内容にする:
```yaml
name: Nostargia
options:
  bundleIdPrefix: com.mn329
  deploymentTarget:
    iOS: "17.0"
packages:
  NostargiaKit:
    path: Packages/NostargiaKit
  Firebase:
    url: https://github.com/firebase/firebase-ios-sdk
    exactVersion: 13.1.1
  GoogleSignIn:
    url: https://github.com/google/GoogleSignIn-iOS
    exactVersion: 10.1.0
targets:
  Nostargia:
    type: application
    platform: iOS
    sources:
      - path: App
        excludes:
          - Info.plist
          - Nostargia.entitlements
    configFiles:
      Debug: Config/Firebase.xcconfig
      Release: Config/Firebase.xcconfig
    info:
      path: App/Info.plist
      properties:
        CFBundleURLTypes:
          - CFBundleURLSchemes:
              - $(GOOGLE_REVERSED_CLIENT_ID)
    entitlements:
      path: App/Nostargia.entitlements
      properties:
        com.apple.developer.applesignin:
          - Default
        com.apple.developer.devicecheck.appattest-environment: development
    dependencies:
      - package: NostargiaKit
      - package: Firebase
        product: FirebaseAuth
      - package: Firebase
        product: FirebaseFirestore
      - package: Firebase
        product: FirebaseAILogic
      - package: Firebase
        product: FirebaseRemoteConfig
      - package: Firebase
        product: FirebaseAppCheck
      - package: GoogleSignIn
        product: GoogleSignIn
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.mn329.nostargia
        PRODUCT_NAME: Nostargia
        DEVELOPMENT_TEAM: K3BSAX58ZG
        CODE_SIGN_STYLE: Automatic
        TARGETED_DEVICE_FAMILY: "1"
        SWIFT_VERSION: "6.0"
        GENERATE_INFOPLIST_FILE: YES
        INFOPLIST_KEY_CFBundleDisplayName: ノスタージア
        INFOPLIST_KEY_UISupportedInterfaceOrientations: UIInterfaceOrientationPortrait
        INFOPLIST_KEY_UILaunchScreen_Generation: YES
        MARKETING_VERSION: "0.1.0"
        CURRENT_PROJECT_VERSION: "1"
  NostargiaTests:
    type: bundle.unit-test
    platform: iOS
    sources: [AppTests]
    dependencies:
      - target: Nostargia
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
        DEVELOPMENT_TEAM: K3BSAX58ZG
        SWIFT_VERSION: "6.0"
schemes:
  Nostargia:
    build:
      targets:
        Nostargia: all
        NostargiaTests: [test]
    test:
      targets:
        - NostargiaTests
```

- [ ] **Step 3: 失敗するテストを書く**

`AppTests/EmulatorSupport.swift`:
```swift
import Foundation
import XCTest

/// エミュレーター結合テストの共通部品。アプリ（ホスト）は起動時にエミュレーター向けに Firebase を初期化している
enum EmulatorSupport {
    static let password = "password123"

    /// テストごとに別のユーザーを作るためのメールアドレス
    static func freshEmail() -> String {
        "user-\(UUID().uuidString.prefix(8).lowercased())@example.com"
    }

    enum Failure: Error {
        case timeout
        case streamEnded
    }

    /// 条件を満たす値が流れてくるまで待つ
    static func firstValue<T: Sendable>(
        of stream: AsyncThrowingStream<T, Error>,
        timeout: Duration = .seconds(10),
        where predicate: @escaping @Sendable (T) -> Bool
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                for try await value in stream where predicate(value) {
                    return value
                }
                throw Failure.streamEnded
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw Failure.timeout
            }
            defer { group.cancelAll() }
            return try await group.next()!
        }
    }
}
```

`AppTests/FirebaseBootstrapTests.swift`:
```swift
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
```

- [ ] **Step 4: 失敗を確認する**

Run: `xcodegen generate --quiet && xcodebuild build-for-testing -project Nostargia.xcodeproj -scheme Nostargia -destination 'platform=iOS Simulator,name=iPhone 17' -quiet 2>&1 | grep -m1 "error:"`
Expected: `cannot find 'FirebaseBootstrap' in scope`（初回は Firebase のパッケージ取得とビルドに 5〜10 分かかる）

- [ ] **Step 5: 実装する**

`App/Firebase/FirebaseBootstrap.swift`:
```swift
@preconcurrency import FirebaseAppCheck
@preconcurrency import FirebaseAuth
@preconcurrency import FirebaseCore
@preconcurrency import FirebaseFirestore
import Foundation

/// Firebase の初期化。テスト中・-useFirebaseEmulator 指定時・GoogleService-Info.plist が無いときはエミュレーターにつなぐ
enum FirebaseBootstrap {
    enum Mode: Equatable {
        case production
        case emulator
    }

    static let demoProjectID = "demo-nostargia"
    static let emulatorHost = "127.0.0.1"

    static func mode(environment: [String: String], arguments: [String], hasConfigFile: Bool) -> Mode {
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
```

`App/NostargiaApp.swift` 全体を次の内容にする:
```swift
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
```

- [ ] **Step 6: 成功を確認する**

Run: `scripts/test-emulator.sh -only-testing:NostargiaTests/FirebaseBootstrapTests`
Expected: 終了コード 0（`-quiet` なので失敗が無ければほぼ出力なし。末尾に `Script exited successfully (code 0)`）

- [ ] **Step 7: Commit**

```bash
git add .gitignore project.yml App Config/Firebase.xcconfig.example firebase.json firestore.rules scripts AppTests
git commit -m "feat: Firebase を組み込み、エミュレーターで結合テストできるようにする"
```

---

### Task 6: Firestore セキュリティルール

**Files:**
- Modify: `firestore.rules`
- Modify: `.gitignore`（`tools/rules-test/node_modules` は既存の `node_modules/` で除外済み）
- Create: `tools/rules-test/package.json`
- Test: `tools/rules-test/rules.test.mjs`

**Interfaces:**
- Produces: `firestore.rules`（本人の `users/{uid}` とその下だけ読み書き可、それ以外はすべて拒否）、`npm --prefix tools/rules-test test`

- [ ] **Step 1: テスト用の Node プロジェクトを作る**

`tools/rules-test/package.json`:
```json
{
  "name": "nostargia-rules-test",
  "private": true,
  "type": "module",
  "scripts": {
    "test": "node --test"
  },
  "devDependencies": {
    "@firebase/rules-unit-testing": "^5.0.0",
    "firebase": "^12.0.0"
  }
}
```

Run: `npm --prefix tools/rules-test install`
Expected: `node_modules` ができ、`package-lock.json` が作られる

- [ ] **Step 2: 失敗するテストを書く**

`tools/rules-test/rules.test.mjs`:
```js
// firebase emulators:exec --only firestore --project demo-nostargia "npm --prefix tools/rules-test test"
import { after, before, beforeEach, test } from 'node:test';
import { readFileSync } from 'node:fs';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { deleteDoc, doc, getDoc, setDoc } from 'firebase/firestore';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-nostargia',
    firestore: {
      rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

beforeEach(() => env.clearFirestore());
after(() => env.cleanup());

test('本人はプロフィールと星とタグを読み書き・削除できる', async () => {
  const db = env.authenticatedContext('alice').firestore();
  await assertSucceeds(setDoc(doc(db, 'users/alice'), { userName: 'アリス' }));
  await assertSucceeds(getDoc(doc(db, 'users/alice')));
  await assertSucceeds(setDoc(doc(db, 'users/alice/stars/s1'), { scale: 2 }));
  await assertSucceeds(getDoc(doc(db, 'users/alice/stars/s1')));
  await assertSucceeds(setDoc(doc(db, 'users/alice/tags/t1'), { name: '休日' }));
  await assertSucceeds(deleteDoc(doc(db, 'users/alice/stars/s1')));
  await assertSucceeds(deleteDoc(doc(db, 'users/alice')));
});

test('他人のデータは読み書きできない', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users/alice/stars/s1'), { scale: 2 });
  });
  const bob = env.authenticatedContext('bob').firestore();
  await assertFails(getDoc(doc(bob, 'users/alice')));
  await assertFails(getDoc(doc(bob, 'users/alice/stars/s1')));
  await assertFails(setDoc(doc(bob, 'users/alice/stars/s2'), { scale: 2 }));
  await assertFails(deleteDoc(doc(bob, 'users/alice/stars/s1')));
});

test('未ログインでは何もできない', async () => {
  const anon = env.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(anon, 'users/alice')));
  await assertFails(setDoc(doc(anon, 'users/alice'), { userName: 'x' }));
});

test('users 以外の場所には書けない', async () => {
  const db = env.authenticatedContext('alice').firestore();
  await assertFails(setDoc(doc(db, 'public/x'), { a: 1 }));
  await assertFails(setDoc(doc(db, 'alice/x'), { a: 1 }));
});
```

- [ ] **Step 3: 失敗を確認する**

Run: `firebase emulators:exec --only firestore --project demo-nostargia "npm --prefix tools/rules-test test" 2>&1 | grep -E "^# (pass|fail)"`
Expected: `# pass 3` と `# fail 1`（Task 5 の「すべて拒否」ルールでは、本人の読み書きのテストだけが失敗する）

- [ ] **Step 4: ルールを書く**

`firestore.rules`:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // 本人の users/{uid} とその下（stars, tags, futureMessages）だけ読み書きできる
    match /users/{uid}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```

- [ ] **Step 5: 成功を確認する**

Run: `firebase emulators:exec --only firestore --project demo-nostargia "npm --prefix tools/rules-test test" 2>&1 | grep -E "^# (pass|fail)"`
Expected: `# pass 4` と `# fail 0`

- [ ] **Step 6: Commit**

```bash
git add firestore.rules tools/rules-test/package.json tools/rules-test/package-lock.json tools/rules-test/rules.test.mjs
git commit -m "feat: 本人のデータだけ読み書きできる Firestore ルールとテストを追加"
```

---

### Task 7: 星の保存（FirestoreStarRepository）

**Files:**
- Create: `App/Firebase/FirestoreStarMapping.swift`
- Create: `App/Firebase/FirestoreStarRepository.swift`
- Create: `App/Firebase/FirebaseAuthService.swift`（全メソッド。星のテストでユーザーを作るのに必要なため先に置く）
- Test: `AppTests/FirestoreStarRepositoryTests.swift`

**Interfaces:**
- Consumes: `Star`, `StarDraft`, `StarRepository`, `StarComposer`, `DiaryEntry`, `TagRef`, `AuthService`, `AuthUser`, `AuthFailure`（Task 1, 4）、`EmulatorSupport`（Task 5）
- Produces:
  - `enum FirestoreStarMapping { static func data(from: StarDraft) -> [String: Any]; static func star(id: String, data: [String: Any]) -> Star? }`
  - `final class FirestoreStarRepository: StarRepository { init(uid: String, db: Firestore = .firestore()) }`
  - `final class FirebaseAuthService: AuthService { init(auth: Auth = .auth()); func signIn(with credential: AuthCredential) async throws -> AuthUser }`（全メソッドをこのタスクで実装し、Task 9 でエミュレーターに対して確かめる）

- [ ] **Step 1: 失敗するテストを書く**

`AppTests/FirestoreStarRepositoryTests.swift`:
```swift
@preconcurrency import FirebaseFirestore
import NostargiaKit
import XCTest
@testable import Nostargia

final class FirestoreStarRepositoryTests: XCTestCase {
    let auth = FirebaseAuthService()

    override func tearDown() async throws {
        try? auth.signOut()
    }

    private func makeDraft(tag: TagRef? = TagRef(id: "t1", name: "休日")) -> StarDraft {
        var random = SystemRandomSource()
        return StarComposer.draft(
            entry: DiaryEntry(mood: MoodValues(all: 80), goodThings: ["散歩", "カフェ"], tag: tag),
            existing: [],
            letter: "星からの手紙",
            now: Date(timeIntervalSince1970: 1_800_000_000),
            random: &random
        )
    }

    func testMappingRoundTrip() {
        let draft = makeDraft()
        var data = FirestoreStarMapping.data(from: draft)
        data["createdAt"] = Timestamp(date: Date(timeIntervalSince1970: 1_800_000_100))
        let star = FirestoreStarMapping.star(id: "s1", data: data)
        XCTAssertEqual(star?.draft, draft)
        XCTAssertEqual(star?.createdAt, Date(timeIntervalSince1970: 1_800_000_100))

        let untagged = makeDraft(tag: nil)
        XCTAssertEqual(FirestoreStarMapping.star(id: "s2", data: FirestoreStarMapping.data(from: untagged))?.tag, nil)
    }

    func testMappingRejectsBrokenDocuments() {
        XCTAssertNil(FirestoreStarMapping.star(id: "x", data: ["scale": 2.0]))
    }

    func testAddObserveDelete() async throws {
        let user = try await auth.signUp(email: EmulatorSupport.freshEmail(), password: EmulatorSupport.password)
        let repo = FirestoreStarRepository(uid: user.uid)
        let draft = makeDraft()

        let id = try await repo.add(draft)
        let stars = try await EmulatorSupport.firstValue(of: repo.stars()) { $0.count == 1 }
        XCTAssertEqual(stars[0].id, id)
        XCTAssertEqual(stars[0].draft, draft)
        XCTAssertNotNil(stars[0].createdAt)

        try await repo.delete(ids: [id])
        _ = try await EmulatorSupport.firstValue(of: repo.stars()) { $0.isEmpty }
    }

    func testStarsAreOrderedByDisplayDate() async throws {
        let user = try await auth.signUp(email: EmulatorSupport.freshEmail(), password: EmulatorSupport.password)
        let repo = FirestoreStarRepository(uid: user.uid)
        var later = makeDraft()
        later.displayDate = Date(timeIntervalSince1970: 1_900_000_000)
        _ = try await repo.add(later)
        _ = try await repo.add(makeDraft())

        let stars = try await EmulatorSupport.firstValue(of: repo.stars()) { $0.count == 2 }
        XCTAssertEqual(stars.map(\.displayDate), [Date(timeIntervalSince1970: 1_800_000_000), Date(timeIntervalSince1970: 1_900_000_000)])
    }

    func testCannotReadAnotherUsersStars() async throws {
        let alice = try await auth.signUp(email: EmulatorSupport.freshEmail(), password: EmulatorSupport.password)
        _ = try await FirestoreStarRepository(uid: alice.uid).add(makeDraft())
        try auth.signOut()
        _ = try await auth.signUp(email: EmulatorSupport.freshEmail(), password: EmulatorSupport.password)

        do {
            _ = try await EmulatorSupport.firstValue(of: FirestoreStarRepository(uid: alice.uid).stars()) { _ in true }
            XCTFail("他人の星が読めてしまった")
        } catch {
            XCTAssertEqual((error as NSError).code, 7) // FirestoreErrorCode permissionDenied
        }
    }
}
```

- [ ] **Step 2: 失敗を確認する**

Run: `xcodegen generate --quiet && xcodebuild build-for-testing -project Nostargia.xcodeproj -scheme Nostargia -destination 'platform=iOS Simulator,name=iPhone 17' -quiet 2>&1 | grep -m1 "error:"`
Expected: `cannot find 'FirebaseAuthService' in scope`

- [ ] **Step 3: 実装する**

`App/Firebase/FirestoreStarMapping.swift`:
```swift
@preconcurrency import FirebaseFirestore
import Foundation
import NostargiaKit

/// Star と Firestore のドキュメント（spec 4章のフィールド）の変換
enum FirestoreStarMapping {
    static func data(from draft: StarDraft) -> [String: Any] {
        [
            "position": ["x": draft.position.x, "y": draft.position.y, "z": draft.position.z],
            "color": ["r": draft.color.r, "g": draft.color.g, "b": draft.color.b],
            "scale": draft.scale,
            "random": draft.random,
            "createdAt": FieldValue.serverTimestamp(),
            "displayDate": Timestamp(date: draft.displayDate),
            "mood": [
                "emotional": draft.mood.emotional,
                "motivation": draft.mood.motivation,
                "social": draft.mood.social,
                "physical": draft.mood.physical,
                "fulfillment": draft.mood.fulfillment,
            ],
            "emotion": draft.emotion,
            "feedback": draft.feedback,
            "totalScore": draft.totalScore,
            "goodThings": draft.goodThings,
            "tag": draft.tag.map { ["id": $0.id, "name": $0.name] } ?? NSNull(),
            "constellation": draft.constellation.map { ["id": $0.id, "nodeIndex": $0.nodeIndex] } ?? NSNull(),
            "isTutorial": draft.isTutorial,
        ]
    }

    /// 必須の項目が欠けている・型が違うドキュメントは nil
    static func star(id: String, data: [String: Any]) -> Star? {
        guard let position = data["position"] as? [String: Any],
              let x = position["x"] as? Double, let y = position["y"] as? Double, let z = position["z"] as? Double,
              let color = data["color"] as? [String: Any],
              let r = color["r"] as? Double, let g = color["g"] as? Double, let b = color["b"] as? Double,
              let scale = data["scale"] as? Double,
              let random = data["random"] as? Double,
              let displayDate = (data["displayDate"] as? Timestamp)?.dateValue(),
              let mood = data["mood"] as? [String: Any],
              let emotional = mood["emotional"] as? Int, let motivation = mood["motivation"] as? Int,
              let social = mood["social"] as? Int, let physical = mood["physical"] as? Int,
              let fulfillment = mood["fulfillment"] as? Int,
              let emotion = data["emotion"] as? String,
              let feedback = data["feedback"] as? String,
              let totalScore = data["totalScore"] as? Double
        else { return nil }

        let tag = (data["tag"] as? [String: Any]).flatMap { dict -> TagRef? in
            guard let id = dict["id"] as? String, let name = dict["name"] as? String else { return nil }
            return TagRef(id: id, name: name)
        }
        let constellation = (data["constellation"] as? [String: Any]).flatMap { dict -> ConstellationAssignment? in
            guard let id = dict["id"] as? String, let nodeIndex = dict["nodeIndex"] as? Int else { return nil }
            return ConstellationAssignment(id: id, nodeIndex: nodeIndex)
        }

        let draft = StarDraft(
            position: StarPosition(x: x, y: y, z: z),
            color: StarColor(r: r, g: g, b: b),
            scale: scale,
            random: random,
            displayDate: displayDate,
            mood: MoodValues(emotional: emotional, motivation: motivation, social: social, physical: physical, fulfillment: fulfillment),
            emotion: emotion,
            feedback: feedback,
            totalScore: totalScore,
            goodThings: data["goodThings"] as? [String] ?? [],
            tag: tag,
            constellation: constellation,
            isTutorial: data["isTutorial"] as? Bool ?? false
        )
        return Star(id: id, createdAt: (data["createdAt"] as? Timestamp)?.dateValue(), draft: draft)
    }
}
```

`App/Firebase/FirestoreStarRepository.swift`:
```swift
@preconcurrency import FirebaseFirestore
import Foundation
import NostargiaKit

/// users/{uid}/stars
final class FirestoreStarRepository: StarRepository, @unchecked Sendable {
    private let collection: CollectionReference

    init(uid: String, db: Firestore = .firestore()) {
        collection = db.collection("users").document(uid).collection("stars")
    }

    func stars() -> AsyncThrowingStream<[Star], Error> {
        let query = collection.order(by: "displayDate")
        return AsyncThrowingStream { continuation in
            let registration = query.addSnapshotListener { snapshot, error in
                if let error {
                    continuation.finish(throwing: error)
                    return
                }
                guard let snapshot else { return }
                // 書き込み直後でまだサーバー時刻が無いものは推定値を使う
                let stars = snapshot.documents.compactMap {
                    FirestoreStarMapping.star(id: $0.documentID, data: $0.data(with: .estimate))
                }
                continuation.yield(stars)
            }
            nonisolated(unsafe) let listener = registration
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    /// オフラインでもすぐに返る（送信は通信が戻ってから Firestore が行う）
    func add(_ draft: StarDraft) async throws -> String {
        let document = collection.document()
        document.setData(FirestoreStarMapping.data(from: draft))
        return document.documentID
    }

    func delete(ids: [String]) async throws {
        let batch = collection.firestore.batch()
        for id in ids {
            batch.deleteDocument(collection.document(id))
        }
        try await batch.commit()
    }
}
```

`App/Firebase/FirebaseAuthService.swift`:
```swift
@preconcurrency import FirebaseAuth
import Foundation
import NostargiaKit

/// Firebase Auth による認証。失敗は AuthFailure に変換して投げる
final class FirebaseAuthService: AuthService, @unchecked Sendable {
    private let auth: Auth

    init(auth: Auth = .auth()) {
        self.auth = auth
    }

    var currentUser: AuthUser? {
        auth.currentUser.map(Self.makeUser)
    }

    func authStates() -> AsyncStream<AuthUser?> {
        let auth = self.auth
        return AsyncStream { continuation in
            let handle = auth.addStateDidChangeListener { _, user in
                continuation.yield(user.map(Self.makeUser))
            }
            nonisolated(unsafe) let listener = handle
            nonisolated(unsafe) let owner = auth
            continuation.onTermination = { _ in owner.removeStateDidChangeListener(listener) }
        }
    }

    func signUp(email: String, password: String) async throws -> AuthUser {
        let result = try await mapErrors { try await self.auth.createUser(withEmail: email, password: password) }
        return Self.makeUser(result.user)
    }

    func signIn(email: String, password: String) async throws -> AuthUser {
        let result = try await mapErrors { try await self.auth.signIn(withEmail: email, password: password) }
        return Self.makeUser(result.user)
    }

    /// Apple / Google の資格情報でサインインする（AppleSignInHelper / GoogleSignInHelper が作る）
    func signIn(with credential: AuthCredential) async throws -> AuthUser {
        let result = try await mapErrors { try await self.auth.signIn(with: credential) }
        return Self.makeUser(result.user)
    }

    func sendPasswordReset(email: String) async throws {
        try await mapErrors { try await self.auth.sendPasswordReset(withEmail: email) }
    }

    func updatePassword(_ password: String) async throws {
        let user = try requireUser()
        try await mapErrors { try await user.updatePassword(to: password) }
    }

    func requestEmailChange(to email: String) async throws {
        let user = try requireUser()
        try await mapErrors { try await user.sendEmailVerification(beforeUpdatingEmail: email) }
    }

    func signOut() throws {
        try mapErrors { try self.auth.signOut() }
    }

    func deleteAccount(appleAuthorizationCode: String?) async throws {
        let user = try requireUser()
        if let appleAuthorizationCode {
            try await mapErrors { try await self.auth.revokeToken(withAuthorizationCode: appleAuthorizationCode) }
        }
        try await mapErrors { try await user.delete() }
    }

    private func requireUser() throws -> User {
        guard let user = auth.currentUser else { throw AuthFailure.requiresRecentLogin }
        return user
    }

    private static func makeUser(_ user: User) -> AuthUser {
        AuthUser(
            uid: user.uid,
            email: user.email,
            providers: Set(user.providerData.compactMap { AuthProvider(rawValue: $0.providerID) })
        )
    }

    private func mapErrors<T>(_ body: () async throws -> T) async throws -> T {
        do {
            return try await body()
        } catch let error as NSError where error.domain == AuthFailure.firebaseErrorDomain {
            throw AuthFailure(code: error.code)
        }
    }

    private func mapErrors<T>(_ body: () throws -> T) throws -> T {
        do {
            return try body()
        } catch let error as NSError where error.domain == AuthFailure.firebaseErrorDomain {
            throw AuthFailure(code: error.code)
        }
    }
}
```

- [ ] **Step 4: 成功を確認する**

Run: `scripts/test-emulator.sh -only-testing:NostargiaTests/FirestoreStarRepositoryTests`
Expected: 終了コード 0（5 tests）

- [ ] **Step 5: Commit**

```bash
git add App AppTests
git commit -m "feat: Firestore に星を保存する FirestoreStarRepository と認証サービスを追加"
```

---

### Task 8: プロフィール・タグ・全データ削除

**Files:**
- Create: `App/Firebase/FirestoreProfileRepository.swift`
- Create: `App/Firebase/FirestoreTagRepository.swift`
- Test: `AppTests/FirestoreProfileTagTests.swift`

**Interfaces:**
- Consumes: `UserProfile`, `Tag`, `ProfileRepository`, `TagRepository`（Task 1）、`FirebaseAuthService`, `FirestoreStarRepository`（Task 7）、`EmulatorSupport`（Task 5）
- Produces:
  - `final class FirestoreProfileRepository: ProfileRepository { init(uid: String, db: Firestore = .firestore(), now: @escaping @Sendable () -> Date = { Date() }); static let defaultTagNames = ["休日", "誕生日", "アニバーサリー"] }`
  - `final class FirestoreTagRepository: TagRepository { init(uid: String, db: Firestore = .firestore()) }`

- [ ] **Step 1: 失敗するテストを書く**

`AppTests/FirestoreProfileTagTests.swift`:
```swift
import NostargiaKit
import XCTest
@testable import Nostargia

final class FirestoreProfileTagTests: XCTestCase {
    let auth = FirebaseAuthService()
    let birthday = Date(timeIntervalSince1970: 946_652_400)

    override func tearDown() async throws {
        try? auth.signOut()
    }

    private func signUp() async throws -> String {
        try await auth.signUp(email: EmulatorSupport.freshEmail(), password: EmulatorSupport.password).uid
    }

    func testProfileIsNilBeforeCreation() async throws {
        let uid = try await signUp()
        let profile = try await FirestoreProfileRepository(uid: uid).profile()
        XCTAssertNil(profile)
    }

    func testCreateProfileWithDefaultTags() async throws {
        let uid = try await signUp()
        let profiles = FirestoreProfileRepository(uid: uid)
        try await profiles.create(UserProfile(userName: "みなと", birthday: birthday))

        let profile = try await profiles.profile()
        XCTAssertEqual(profile, UserProfile(userName: "みなと", birthday: birthday))
        let tags = try await FirestoreTagRepository(uid: uid).tags()
        XCTAssertEqual(tags.map(\.name), ["休日", "誕生日", "アニバーサリー"])

        try await profiles.updateUserName("ミナト")
        let renamed = try await profiles.profile()
        XCTAssertEqual(renamed?.userName, "ミナト")
    }

    func testTagCRUD() async throws {
        let uid = try await signUp()
        let tags = FirestoreTagRepository(uid: uid)
        let added = try await tags.add(name: "旅行")
        try await tags.rename(id: added.id, to: "旅")
        var names = try await tags.tags().map(\.name)
        XCTAssertEqual(names, ["旅"])
        try await tags.delete(id: added.id)
        names = try await tags.tags().map(\.name)
        XCTAssertEqual(names, [])
    }

    func testDeleteAllDataIsIdempotent() async throws {
        let uid = try await signUp()
        let profiles = FirestoreProfileRepository(uid: uid)
        try await profiles.create(UserProfile(userName: "みなと", birthday: birthday))
        var random = SystemRandomSource()
        let draft = StarComposer.draft(
            entry: DiaryEntry(mood: .neutral, goodThings: [], tag: nil), existing: [], letter: nil, now: Date(), random: &random
        )
        let stars = FirestoreStarRepository(uid: uid)
        _ = try await stars.add(draft)
        _ = try await EmulatorSupport.firstValue(of: stars.stars()) { $0.count == 1 }

        try await profiles.deleteAllData()
        try await profiles.deleteAllData()

        let profile = try await profiles.profile()
        XCTAssertNil(profile)
        let remainingTags = try await FirestoreTagRepository(uid: uid).tags()
        XCTAssertEqual(remainingTags, [])
        _ = try await EmulatorSupport.firstValue(of: stars.stars()) { $0.isEmpty }
    }
}
```

- [ ] **Step 2: 失敗を確認する**

Run: `xcodegen generate --quiet && xcodebuild build-for-testing -project Nostargia.xcodeproj -scheme Nostargia -destination 'platform=iOS Simulator,name=iPhone 17' -quiet 2>&1 | grep -m1 "error:"`
Expected: `cannot find 'FirestoreProfileRepository' in scope`

- [ ] **Step 3: 実装する**

`App/Firebase/FirestoreProfileRepository.swift`:
```swift
@preconcurrency import FirebaseFirestore
import Foundation
import NostargiaKit

/// users/{uid} のプロフィールと、アカウント全体のデータ
final class FirestoreProfileRepository: ProfileRepository, @unchecked Sendable {
    static let defaultTagNames = ["休日", "誕生日", "アニバーサリー"]
    /// users/{uid} の下にあるサブコレクション（futureMessages は段階3で使う）
    static let subcollections = ["stars", "tags", "futureMessages"]

    private let document: DocumentReference
    private let now: @Sendable () -> Date

    init(uid: String, db: Firestore = .firestore(), now: @escaping @Sendable () -> Date = { Date() }) {
        document = db.collection("users").document(uid)
        self.now = now
    }

    func profile() async throws -> UserProfile? {
        let snapshot = try await document.getDocument()
        guard let data = snapshot.data(),
              let userName = data["userName"] as? String,
              let birthday = (data["birthday"] as? Timestamp)?.dateValue()
        else { return nil }
        return UserProfile(userName: userName, birthday: birthday)
    }

    func create(_ profile: UserProfile) async throws {
        let batch = document.firestore.batch()
        batch.setData([
            "userName": profile.userName,
            "birthday": Timestamp(date: profile.birthday),
            "createdAt": FieldValue.serverTimestamp(),
        ], forDocument: document)
        // 並び順を保つため、作成日時を 1 ミリ秒ずつずらす
        let base = now()
        for (index, name) in Self.defaultTagNames.enumerated() {
            batch.setData([
                "name": name,
                "createdAt": Timestamp(date: base.addingTimeInterval(Double(index) / 1000)),
            ], forDocument: document.collection("tags").document())
        }
        try await batch.commit()
    }

    func updateUserName(_ name: String) async throws {
        try await document.updateData(["userName": name])
    }

    func deleteAllData() async throws {
        for name in Self.subcollections {
            let snapshot = try await document.collection(name).getDocuments()
            // 1回のバッチは最大500件
            for chunk in stride(from: 0, to: snapshot.documents.count, by: 500) {
                let batch = document.firestore.batch()
                for item in snapshot.documents[chunk..<min(chunk + 500, snapshot.documents.count)] {
                    batch.deleteDocument(item.reference)
                }
                try await batch.commit()
            }
        }
        try await document.delete()
    }
}
```

`App/Firebase/FirestoreTagRepository.swift`:
```swift
@preconcurrency import FirebaseFirestore
import Foundation
import NostargiaKit

/// users/{uid}/tags
final class FirestoreTagRepository: TagRepository, @unchecked Sendable {
    private let collection: CollectionReference

    init(uid: String, db: Firestore = .firestore()) {
        collection = db.collection("users").document(uid).collection("tags")
    }

    func tags() async throws -> [Tag] {
        let snapshot = try await collection.order(by: "createdAt").getDocuments()
        return snapshot.documents.compactMap { document in
            let data = document.data()
            guard let name = data["name"] as? String,
                  let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
            else { return nil }
            return Tag(id: document.documentID, name: name, createdAt: createdAt)
        }
    }

    func add(name: String) async throws -> Tag {
        let document = collection.document()
        let createdAt = Date()
        try await document.setData(["name": name, "createdAt": Timestamp(date: createdAt)])
        return Tag(id: document.documentID, name: name, createdAt: createdAt)
    }

    /// 星にコピーしたタグ名は変えない（その日に付けた名前のまま残す）
    func rename(id: String, to name: String) async throws {
        try await collection.document(id).updateData(["name": name])
    }

    func delete(id: String) async throws {
        try await collection.document(id).delete()
    }
}
```

- [ ] **Step 4: 成功を確認する**

Run: `scripts/test-emulator.sh -only-testing:NostargiaTests/FirestoreProfileTagTests`
Expected: 終了コード 0（4 tests）

- [ ] **Step 5: Commit**

```bash
git add App AppTests
git commit -m "feat: プロフィール・初期タグ・タグ編集・全データ削除を Firestore に実装"
```

---

### Task 9: メール認証とアカウント削除

**Files:**
- Test: `AppTests/FirebaseAuthServiceTests.swift`
- Modify（テストが落ちた場合のみ）: `App/Firebase/FirebaseAuthService.swift`

**Interfaces:**
- Consumes: `FirebaseAuthService`（Task 7）、`FirestoreProfileRepository`（Task 8）、`AuthFailure`（Task 4）、`EmulatorSupport`（Task 5）
- Produces: なし（Task 7 で書いた `FirebaseAuthService` の全メソッドを、エミュレーターで確かめる）

- [ ] **Step 1: テストを書く**

`AppTests/FirebaseAuthServiceTests.swift`:
```swift
import NostargiaKit
import XCTest
@testable import Nostargia

final class FirebaseAuthServiceTests: XCTestCase {
    let auth = FirebaseAuthService()

    override func tearDown() async throws {
        try? auth.signOut()
    }

    func testSignUpSignOutSignIn() async throws {
        let email = EmulatorSupport.freshEmail()
        let user = try await auth.signUp(email: email, password: EmulatorSupport.password)
        XCTAssertEqual(user.email, email)
        XCTAssertEqual(user.providers, [.password])
        XCTAssertEqual(auth.currentUser?.uid, user.uid)

        try auth.signOut()
        XCTAssertNil(auth.currentUser)

        let again = try await auth.signIn(email: email, password: EmulatorSupport.password)
        XCTAssertEqual(again.uid, user.uid)
    }

    func testFailuresAreTranslated() async throws {
        let email = EmulatorSupport.freshEmail()
        _ = try await auth.signUp(email: email, password: EmulatorSupport.password)
        try auth.signOut()

        await assertFailure(.invalidCredential) { _ = try await self.auth.signIn(email: email, password: "wrong-password") }
        await assertFailure(.emailAlreadyInUse) { _ = try await self.auth.signUp(email: email, password: EmulatorSupport.password) }
        await assertFailure(.weakPassword) { _ = try await self.auth.signUp(email: EmulatorSupport.freshEmail(), password: "123") }
        await assertFailure(.invalidEmail) { _ = try await self.auth.signUp(email: "not-an-email", password: EmulatorSupport.password) }
    }

    func testPasswordResetAndChange() async throws {
        let email = EmulatorSupport.freshEmail()
        _ = try await auth.signUp(email: email, password: EmulatorSupport.password)
        try await auth.sendPasswordReset(email: email)
        try await auth.updatePassword("newpassword456")
        try await auth.requestEmailChange(to: EmulatorSupport.freshEmail())
        try auth.signOut()
        _ = try await auth.signIn(email: email, password: "newpassword456")
    }

    func testAuthStatesFollowSignInAndOut() async throws {
        let states = auth.authStates()
        var iterator = states.makeAsyncIterator()
        _ = await iterator.next()
        let user = try await auth.signUp(email: EmulatorSupport.freshEmail(), password: EmulatorSupport.password)
        var seen = await iterator.next()
        XCTAssertEqual(seen??.uid, user.uid)
        try auth.signOut()
        seen = await iterator.next()
        XCTAssertNil(seen ?? nil)
    }

    func testDeleteAccountRemovesDataAndUser() async throws {
        let email = EmulatorSupport.freshEmail()
        let user = try await auth.signUp(email: email, password: EmulatorSupport.password)
        let profiles = FirestoreProfileRepository(uid: user.uid)
        try await profiles.create(UserProfile(userName: "みなと", birthday: Date(timeIntervalSince1970: 0)))

        try await profiles.deleteAllData()
        try await auth.deleteAccount(appleAuthorizationCode: nil)
        XCTAssertNil(auth.currentUser)

        // 同じメールアドレスでもう一度登録できる = 認証のユーザーも消えている
        _ = try await auth.signUp(email: email, password: EmulatorSupport.password)
    }

    private func assertFailure(_ expected: AuthFailure, file: StaticString = #filePath, line: UInt = #line, _ body: () async throws -> Void) async {
        do {
            try await body()
            XCTFail("\(expected) が投げられなかった", file: file, line: line)
        } catch let failure as AuthFailure {
            XCTAssertEqual(failure, expected, file: file, line: line)
        } catch {
            XCTFail("AuthFailure ではないエラー: \(error)", file: file, line: line)
        }
    }
}
```

- [ ] **Step 2: 実行する**

Run: `scripts/test-emulator.sh -only-testing:NostargiaTests/FirebaseAuthServiceTests`
Expected: 終了コード 0（5 tests）。`FirebaseAuthService` は Task 7 で全メソッドを実装済みなので、ここで初めて落ちるものがあれば、それは Task 7 の実装の不具合として superpowers:systematic-debugging で原因を調べて直す（エミュレーターが返すエラーコードがテストの想定と違う場合は、AuthFailure の対応表を直して Task 4 のテストにもそのコードを追加する）。

- [ ] **Step 3: Commit**

```bash
git add App AppTests Packages/NostargiaKit
git commit -m "test: メール認証とアカウント削除をエミュレーターで確認"
```

---

### Task 10: Apple / Google でサインインの準備

**Files:**
- Create: `App/Firebase/AppleSignInHelper.swift`
- Create: `App/Firebase/GoogleSignInHelper.swift`
- Test: `AppTests/AppleSignInHelperTests.swift`

**Interfaces:**
- Consumes: `FirebaseAuthService.signIn(with:)`（Task 7）
- Produces:
  - `@MainActor final class AppleSignInHelper { func prepare(_ request: ASAuthorizationAppleIDRequest); func credential(from authorization: ASAuthorization) throws -> AppleSignInResult; static func randomNonce(length: Int = 32) -> String; static func sha256(_ input: String) -> String }`
  - `struct AppleSignInResult { let credential: AuthCredential; let authorizationCode: String? }`（authorizationCode はアカウント削除時の `deleteAccount(appleAuthorizationCode:)` に渡す）
  - `enum AppleSignInError: Error { case missingNonce, missingIdentityToken, unexpectedCredential }`
  - `@MainActor enum GoogleSignInHelper { static func credential(presenting: UIViewController) async throws -> AuthCredential }`、`enum GoogleSignInError: Error { case missingClientID, missingIDToken }`
  - 画面からの使い方（段階1d）：Apple は SwiftUI の `SignInWithAppleButton(onRequest: helper.prepare, onCompletion: ...)` → `helper.credential(from:)` → `FirebaseAuthService.signIn(with:)`。Google は `GoogleSignInHelper.credential(presenting:)` → `signIn(with:)`

- [ ] **Step 1: 失敗するテストを書く**

`AppTests/AppleSignInHelperTests.swift`:
```swift
import XCTest
@testable import Nostargia

@MainActor
final class AppleSignInHelperTests: XCTestCase {
    func testNonceHasRequestedLengthAndSafeCharacters() {
        let allowed = Set("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = AppleSignInHelper.randomNonce()
        XCTAssertEqual(nonce.count, 32)
        XCTAssertTrue(nonce.allSatisfy(allowed.contains))
        XCTAssertNotEqual(nonce, AppleSignInHelper.randomNonce())
    }

    func testSHA256MatchesKnownVector() {
        XCTAssertEqual(AppleSignInHelper.sha256("abc"), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }
}
```

- [ ] **Step 2: 失敗を確認する**

Run: `xcodegen generate --quiet && xcodebuild build-for-testing -project Nostargia.xcodeproj -scheme Nostargia -destination 'platform=iOS Simulator,name=iPhone 17' -quiet 2>&1 | grep -m1 "error:"`
Expected: `cannot find 'AppleSignInHelper' in scope`

- [ ] **Step 3: 実装する**

`App/Firebase/AppleSignInHelper.swift`:
```swift
import AuthenticationServices
import CryptoKit
@preconcurrency import FirebaseAuth
import Foundation

struct AppleSignInResult {
    let credential: AuthCredential
    /// アカウント削除時に Apple の認証を取り消すために使う
    let authorizationCode: String?
}

enum AppleSignInError: Error {
    case missingNonce
    case missingIdentityToken
    case unexpectedCredential
}

/// Apple でサインイン。prepare でリクエストに nonce を付け、結果から Firebase の資格情報を作る
@MainActor
final class AppleSignInHelper {
    private var currentNonce: String?

    func prepare(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonce()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    func credential(from authorization: ASAuthorization) throws -> AppleSignInResult {
        guard let apple = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AppleSignInError.unexpectedCredential
        }
        guard let nonce = currentNonce else { throw AppleSignInError.missingNonce }
        guard let tokenData = apple.identityToken, let idToken = String(data: tokenData, encoding: .utf8) else {
            throw AppleSignInError.missingIdentityToken
        }
        let credential = OAuthProvider.appleCredential(withIDToken: idToken, rawNonce: nonce, fullName: apple.fullName)
        let code = apple.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
        return AppleSignInResult(credential: credential, authorizationCode: code)
    }

    static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        precondition(status == errSecSuccess, "SecRandomCopyBytes に失敗しました: \(status)")
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
```

`App/Firebase/GoogleSignInHelper.swift`:
```swift
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
```

- [ ] **Step 4: 成功を確認する**

Run: `scripts/test-emulator.sh -only-testing:NostargiaTests/AppleSignInHelperTests`
Expected: 終了コード 0（2 tests）

- [ ] **Step 5: Commit**

```bash
git add App AppTests
git commit -m "feat: Apple と Google でサインインするための資格情報の作成を追加"
```

---

### Task 11: Gemini の手紙と本物の Firebase プロジェクトでの確認

**Files:**
- Create: `App/Firebase/GeminiLetterGenerator.swift`
- Modify: `App/NostargiaApp.swift`（DEBUG ビルドだけの手紙の動作確認）
- Create: `docs/firebase-setup.md`
- Modify: `README.md`（Firebase とエミュレーターの手順を追記）

**Interfaces:**
- Consumes: `LetterGenerating`, `LetterService`, `DiaryEntry`（Task 3, 1）、`FirebaseBootstrap`（Task 5）
- Produces: `final class GeminiLetterGenerator: LetterGenerating { static let modelKey = "letter_model"; static let defaultModel = "gemini-3.5-flash" }`

- [ ] **Step 1: 実装する**

`App/Firebase/GeminiLetterGenerator.swift`:
```swift
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
```

`App/NostargiaApp.swift` の `ContentView` を次の内容に置き換える（`NostargiaApp` はそのまま）:
```swift
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
```

- [ ] **Step 2: ビルドと既存テストが通ることを確認する**

Run: `scripts/test-emulator.sh`
Expected: 終了コード 0（NostargiaTests の全 18 tests）

Run: `cd Packages/NostargiaKit && swift test 2>&1 | tail -1`
Expected: `Test run with 48 tests in 11 suites passed`

- [ ] **Step 3: Firebase コンソールでの準備手順を書く**

`docs/firebase-setup.md`:
```markdown
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
8. **App Check**: アプリを App Attest で登録する（Team ID `K3BSAX58ZG`）。シミュレーターではデバッグプロバイダーを使うので、アプリを1度起動して Xcode のログに出る「Firebase App Check debug token」をコンソールの「デバッグトークンを管理」に登録する。AI Logic の App Check を「適用」にするのは、実機での動作を確認してから。
9. **Apple Developer**: Xcode の Signing & Capabilities で Sign in with Apple と App Attest が付いていることを確認する（project.yml から自動で付く）。
```

`README.md` の「## テスト」の節を次の内容に置き換える:
```markdown
## テスト

ドメインロジックは Swift パッケージ `Packages/NostargiaKit` にあり、Mac 上でテストできる。

    cd Packages/NostargiaKit && swift test

Firebase につなぐ部分は、エミュレーター（仮プロジェクト `demo-nostargia`）に対して iOS シミュレーターで結合テストする。Java と firebase-tools が必要。

    scripts/test-emulator.sh

Firestore のセキュリティルールのテスト:

    npm --prefix tools/rules-test install
    firebase emulators:exec --only firestore --project demo-nostargia "npm --prefix tools/rules-test test"

## Firebase

本物のプロジェクトの準備は `docs/firebase-setup.md`。`GoogleService-Info.plist` と `Config/Firebase.xcconfig` はコミットしない。
```

- [ ] **Step 4: Commit**

```bash
git add App docs/firebase-setup.md README.md
git commit -m "feat: Gemini で星からの手紙を作る GeminiLetterGenerator と Firebase 準備手順を追加"
```

- [ ] **Step 5: 本物のプロジェクトで手紙を確認する（人の作業が必要）**

ユーザーが `docs/firebase-setup.md` の 1〜8 を終えた後に行う。

Run: `xcodegen generate --quiet && xcodebuild -project Nostargia.xcodeproj -scheme Nostargia -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build/dd build -quiet && xcrun simctl install booted build/dd/Build/Products/Debug-iphonesimulator/Nostargia.app && xcrun simctl launch --console-pty booted com.mn329.nostargia -letterSmokeTest`
Expected: ログに `letterSmokeTest:` に続いて、Gemini が作った1〜2文の日本語の手紙が出る。`（AI の手紙は作れなかったので定型文になります）` の場合は、App Check のデバッグトークン登録・AI Logic の有効化・Remote Config の値を確認する。

- [ ] **Step 6: ブランチの外に出るものがないことを確認する**

Run: `git status --short`
Expected: 何も出ない（`App/GoogleService-Info.plist`、`Config/Firebase.xcconfig`、`build/` は Task 5 で無視する設定にしてある）
