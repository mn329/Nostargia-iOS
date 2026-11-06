# 段階1a：プロジェクト立ち上げとドメイン移植 実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Web版の判定ロジック（感情判定・星の色/大きさ/位置・星座の割り当て・朝6時区切り）を、Web版と同じ結果を返す Swift パッケージとして移植し、それを読み込む空の iOS アプリを立ち上げる。

**Architecture:** ドメインは UI にも Firebase にも依存しないローカル Swift パッケージ `NostargiaKit` に置き、`swift test` で Mac 上でテストする。正しさは「Web版の JS を Node で実行して書き出したゴールデンデータ」と一致するかで確かめる。アプリ本体は XcodeGen の `project.yml` から生成し、パッケージを依存として読み込む。

**Tech Stack:** Swift 6.2 / Swift Testing / Swift Package Manager / XcodeGen / Node 26（ゴールデンデータの生成のみ）/ Xcode 26

**Spec:** `docs/superpowers/specs/2026-11-06-nostargia-ios-design.md`（特に 7章 ドメイン、10章 テスト）

**段階1の分割（この計画は 1a）:**
- 1a. プロジェクト立ち上げ + ドメイン移植 ← この計画
- 1b. Firebase（Auth 3種、Firestore のリポジトリ、AI Logic の手紙）
- 1c. Metal 星空レンダラー（背景〜ブルーム、ユーザーの星、カメラ、タップ判定）
- 1d. UI 統合（ログイン系モーダル、日記、打ち上げ演出、星の詳細、クールダウン）

## Global Constraints

- iOS 17.0 以上、iPhone のみ、縦画面
- Swift 6 言語モード。ドメインの公開型はすべて `Sendable`
- ドメイン（`NostargiaKit`）は SwiftUI / UIKit / Firebase を import しない（Foundation のみ）
- Bundle ID: `com.mn329.nostargia`（App Store Connect に登録するまでは変更可能）
- 秘密情報（`GoogleService-Info.plist` など）はコミットしない。リポジトリは公開
- 移植元の Web版は `~/Documents/Nostargia`（以下「Web版」）。挙動は Web版を正とする
- 星の色は Web版と同じく three.js の作業色空間（リニア）の値で持つ。`#FFD700` などの16進指定は sRGB → リニア変換した値になる
- コミットメッセージの末尾に `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` を付ける

## Review Focus

- 夏時間がある地域・日付の境目：朝6時区切りは端末のカレンダーで計算し、23時間/25時間の日でも「次の朝6時」が正しく出る（Task 7 のテスト）
- デバッグで日数を戻したときの「未来の日付の星」：今の時刻より後の星はクールダウン判定から除外される（Task 7 のテスト）
- いいことの入力に空白だけ・全角スペースだけの行：手紙の「「…」いいですね。」に空の項目が混ざらない（Task 2 のゴールデンケースと Task 3 のテスト）
- 9星座がすべて埋まった後に全スライダー50以上で打ち上げ：星座には割り当てず、通常のランダム配置になる（Task 5・Task 8 のテスト）
- 保存データが壊れていて nodeIndex が範囲外：クラッシュせず、その星座を飛ばして次の空きを探す（Task 5 のテスト）

---

## ファイル構成

```
Nostargia-iOS/
├── .gitignore
├── README.md
├── project.yml                         XcodeGen の設定（.xcodeproj は生成物なのでコミットしない）
├── App/
│   └── NostargiaApp.swift              空のアプリ（パッケージの読み込み確認用）
├── tools/golden/
│   └── generate.mjs                    Web版の JS を実行してゴールデンデータを書き出す
└── Packages/NostargiaKit/
    ├── Package.swift
    ├── Sources/NostargiaKit/
    │   ├── MoodValues.swift            スライダー5値
    │   ├── MoodAnalyzer.swift          感情タイプ・totalScore・定型文の手紙（fallbackAnalysis.js）
    │   ├── StarAppearance.swift        色・大きさ（starDataMaker.js）
    │   ├── Constellation.swift         星座データの型と読み込み
    │   ├── ConstellationAssigner.swift 星座ノードの割り当て（starDataMaker.js）
    │   ├── RandomSource.swift          差し替え可能な乱数
    │   ├── StarPlacement.swift         星座内/ランダム配置（starDataMaker.js）
    │   ├── StarFactory.swift           上記をまとめて新しい星の設計図を作る
    │   ├── DiaryCycle.swift            朝6時区切り・クールダウン（appTime.js）
    │   ├── AppClock.swift              デバッグ用の日数ずらし込みの現在時刻
    │   └── Resources/constellations.json   生成物（Web版 constellationData.js から）
    └── Tests/NostargiaKitTests/
        ├── Support/Fixture.swift       ゴールデンデータの読み込み
        ├── Support/SequenceRandom.swift テスト用の固定乱数
        ├── Fixtures/*.json             生成物（ゴールデンデータ）
        └── <型ごとのテスト>.swift
```

---

### Task 1: Swift パッケージの立ち上げと MoodValues

**Files:**
- Create: `.gitignore`
- Create: `Packages/NostargiaKit/Package.swift`
- Create: `Packages/NostargiaKit/Sources/NostargiaKit/MoodValues.swift`
- Create: `Packages/NostargiaKit/Sources/NostargiaKit/Resources/.gitkeep`
- Create: `Packages/NostargiaKit/Tests/NostargiaKitTests/Fixtures/.gitkeep`
- Test: `Packages/NostargiaKit/Tests/NostargiaKitTests/MoodValuesTests.swift`

**Interfaces:**
- Produces: `public struct MoodValues: Codable, Hashable, Sendable`（`emotional, motivation, social, physical, fulfillment: Int`、`init(emotional:motivation:social:physical:fulfillment:)`、`init(all:)`、`static let neutral`、`var all: [Int]`、`func allAtLeast(_:) -> Bool`、`func allBelow(_:) -> Bool`）

- [ ] **Step 1: .gitignore とパッケージ定義を作る**

`.gitignore`:
```
.DS_Store
.build/
DerivedData/
xcuserdata/
*.xcodeproj/
GoogleService-Info.plist
node_modules/
```

`Packages/NostargiaKit/Package.swift`:
```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NostargiaKit",
    defaultLocalization: "ja",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "NostargiaKit", targets: ["NostargiaKit"]),
    ],
    targets: [
        .target(
            name: "NostargiaKit",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "NostargiaKitTests",
            dependencies: ["NostargiaKit"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
```

空ファイル `Sources/NostargiaKit/Resources/.gitkeep` と `Tests/NostargiaKitTests/Fixtures/.gitkeep` を作る。

- [ ] **Step 2: 失敗するテストを書く**

`Packages/NostargiaKit/Tests/NostargiaKitTests/MoodValuesTests.swift`:
```swift
import Foundation
import Testing
@testable import NostargiaKit

struct MoodValuesTests {
    @Test func neutralIsAllFifty() {
        #expect(MoodValues.neutral.all == [50, 50, 50, 50, 50])
    }

    @Test func thresholds() {
        let mood = MoodValues(emotional: 50, motivation: 60, social: 70, physical: 80, fulfillment: 90)
        #expect(mood.allAtLeast(50))
        #expect(!mood.allAtLeast(51))
        #expect(MoodValues(all: 24).allBelow(25))
        #expect(!MoodValues(all: 25).allBelow(25))
    }

    @Test func decodesWebKeys() throws {
        let json = #"{"emotional":1,"motivation":2,"social":3,"physical":4,"fulfillment":5}"#
        let mood = try JSONDecoder().decode(MoodValues.self, from: Data(json.utf8))
        #expect(mood.all == [1, 2, 3, 4, 5])
    }
}
```

- [ ] **Step 3: 失敗を確認する**

Run: `cd Packages/NostargiaKit && swift test`
Expected: FAIL（`cannot find 'MoodValues' in scope`）

- [ ] **Step 4: 実装する**

`Packages/NostargiaKit/Sources/NostargiaKit/MoodValues.swift`:
```swift
import Foundation

/// 日記のスライダー5値（各0〜100）。キー名は Web版の mood_values と同じ。
public struct MoodValues: Codable, Hashable, Sendable {
    public var emotional: Int
    public var motivation: Int
    public var social: Int
    public var physical: Int
    public var fulfillment: Int

    public init(emotional: Int, motivation: Int, social: Int, physical: Int, fulfillment: Int) {
        self.emotional = emotional
        self.motivation = motivation
        self.social = social
        self.physical = physical
        self.fulfillment = fulfillment
    }

    public init(all value: Int) {
        self.init(emotional: value, motivation: value, social: value, physical: value, fulfillment: value)
    }

    /// スライダーの初期値
    public static let neutral = MoodValues(all: 50)

    public var all: [Int] { [emotional, motivation, social, physical, fulfillment] }

    public func allAtLeast(_ threshold: Int) -> Bool { all.allSatisfy { $0 >= threshold } }

    public func allBelow(_ threshold: Int) -> Bool { all.allSatisfy { $0 < threshold } }
}
```

- [ ] **Step 5: 成功を確認する**

Run: `cd Packages/NostargiaKit && swift test`
Expected: PASS（3 tests）

- [ ] **Step 6: Commit**

```bash
git add .gitignore Packages/NostargiaKit
git commit -m "feat: NostargiaKit パッケージと MoodValues を追加"
```

---

### Task 2: ゴールデンデータの生成

Web版の JS を実際に実行して、Swift 側が一致すべき「正解」を JSON に書き出す。three.js の色変換（sRGB → リニア）も本物で再現するため、Web版の `node_modules` を使う。

**Files:**
- Create: `tools/golden/generate.mjs`
- Create（生成物）: `Packages/NostargiaKit/Tests/NostargiaKitTests/Fixtures/mood_analysis.json`, `mood_color.json`, `constellation_hash.json`, `diary_cycle.json`
- Create（生成物）: `Packages/NostargiaKit/Sources/NostargiaKit/Resources/constellations.json`
- Delete: 上記2ディレクトリの `.gitkeep`

**Interfaces:**
- Produces（後続タスクのテストが読む JSON の形）:
  - `mood_analysis.json`: `[{ mood: MoodValues, goodThings: [String], emotion: String, feedback: String, totalScore: Double }]`
  - `mood_color.json`: `[{ mood: MoodValues, color: { r, g, b } }]`
  - `constellation_hash.json`: `[{ input: String, hash: Int, centerX: Double, centerY: Double, baseZ: Double }]`
  - `diary_cycle.json`: `[{ at: Double, start: Double, end: Double }]`（いずれも UNIX ミリ秒、Asia/Tokyo で計算）
  - `constellations.json`: `[{ id, name, starCount, description, features, history, starPositions: [{x, y}], lines: [[Int]] }]`

- [ ] **Step 1: Web版の依存を入れる**

Run: `cd ~/Documents/Nostargia && npm ci`
Expected: `node_modules/three` が存在する（`ls node_modules/three/package.json` が成功）

- [ ] **Step 2: 生成スクリプトを書く**

`tools/golden/generate.mjs`:
```js
// Web版の JS を実行して、Swift 版が一致すべきゴールデンデータを書き出す。
// 使い方（Nostargia-iOS のルートで）: TZ=Asia/Tokyo node tools/golden/generate.mjs ../Nostargia
import { readFileSync, writeFileSync, mkdirSync, rmSync } from 'node:fs';
import { createRequire } from 'node:module';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';

if (Intl.DateTimeFormat().resolvedOptions().timeZone !== 'Asia/Tokyo') {
  throw new Error('TZ=Asia/Tokyo を付けて実行してください');
}

const webRepo = resolve(process.argv[2] ?? '../Nostargia');
const fixturesDir = resolve('Packages/NostargiaKit/Tests/NostargiaKitTests/Fixtures');
const resourcesDir = resolve('Packages/NostargiaKit/Sources/NostargiaKit/Resources');
mkdirSync(fixturesDir, { recursive: true });
mkdirSync(resourcesDir, { recursive: true });
rmSync(join(fixturesDir, '.gitkeep'), { force: true });
rmSync(join(resourcesDir, '.gitkeep'), { force: true });

const require = createRequire(join(webRepo, 'package.json'));
const THREE = require('three');

const { getFallbackAnalysis } = await import(pathToFileURL(join(webRepo, 'src/utils/fallbackAnalysis.js')));
const { CONSTELLATIONS } = await import(pathToFileURL(join(webRepo, 'src/data/constellationData.js')));

// export されていない関数を、ソースから波括弧の対応で切り出す
function extractFunctions(file, names) {
  const src = readFileSync(join(webRepo, file), 'utf8');
  return { src, code: names.map((name) => {
    const start = src.indexOf(`function ${name}(`);
    if (start < 0) throw new Error(`${file} に ${name} が見つかりません`);
    const open = src.indexOf('{', src.indexOf(')', start));
    let depth = 0;
    let i = open;
    for (; i < src.length; i++) {
      if (src[i] === '{') depth++;
      else if (src[i] === '}' && --depth === 0) break;
    }
    return src.slice(start, i + 1);
  }).join('\n') };
}

const star = extractFunctions('src/utils/starDataMaker.js', ['hashCode', 'generateMoodColor']);
const { hashCode, generateMoodColor } =
  new Function('THREE', `${star.code}\nreturn { hashCode, generateMoodColor };`)(THREE);

const time = extractFunctions('src/utils/appTime.js', ['getDiaryCycleStart', 'getDiaryCycleEnd']);
if (!time.src.includes('const RESET_HOUR = 6;')) throw new Error('RESET_HOUR が 6 ではありません');
const { getDiaryCycleStart, getDiaryCycleEnd } =
  new Function('RESET_HOUR', `${time.code}\nreturn { getDiaryCycleStart, getDiaryCycleEnd };`)(6);

// 再現できる疑似乱数（線形合同法）
let seed = 20261106;
const rand = () => {
  seed = (seed * 1664525 + 1013904223) % 4294967296;
  return seed / 4294967296;
};

const KEYS = ['emotional', 'motivation', 'social', 'physical', 'fulfillment'];
const BOUNDARY = [0, 1, 33, 34, 50, 66, 67, 99, 100];
const moodOf = (f) => Object.fromEntries(KEYS.map((k) => [k, f(k)]));

const moods = [];
for (const v of BOUNDARY) moods.push(moodOf(() => v));
for (const k of KEYS) for (const v of BOUNDARY) moods.push({ ...moodOf(() => 50), [k]: v });
for (let i = 0; i < 400; i++) moods.push(moodOf(() => Math.floor(rand() * 101)));

const GOOD_THINGS = [
  [],
  ['散歩した'],
  ['散歩した', '', 'カフェ'],
  ['  空がきれい  ', '   ', '友達と話した'],
  ['　朝ごはん　', '　'],
  ['a', 'b', 'c'],
];
const toWebGoodThings = (list) => ({ goodThing1: list[0] ?? '', goodThing2: list[1] ?? '', goodThing3: list[2] ?? '' });

const moodAnalysis = moods.map((mood, i) => {
  const goodThings = GOOD_THINGS[i % GOOD_THINGS.length];
  const r = getFallbackAnalysis(mood, toWebGoodThings(goodThings));
  return { mood, goodThings, emotion: r.emotion, feedback: r.feedback, totalScore: r.totalScore };
});
const emotionKinds = new Set(moodAnalysis.map((c) => c.emotion));
if (emotionKinds.size !== 27) throw new Error(`感情タイプが ${emotionKinds.size} 種類しか出ていません`);

const moodColor = moods.map((mood) => {
  const c = generateMoodColor(mood);
  return { mood, color: { r: c.r, g: c.g, b: c.b } };
});

// starDataMaker.js の星座中心の計算をそのまま再現
const hashInputs = [...CONSTELLATIONS.map((c) => c.id), '', 'a', 'ノスタージア', 'x'.repeat(50)];
const constellationHash = hashInputs.map((input) => {
  const boxWidth = 60;
  const boxHeight = 60;
  const minX = -320 + boxWidth / 2 + 10;
  const maxX = 320 - boxWidth / 2 - 10;
  const minY = -160 + boxHeight / 2 + 10;
  const maxY = 160 - boxHeight / 2 - 10;
  const hash = hashCode(input);
  const prngX = (hash % 100) / 100;
  const prngY = ((hash * 13) % 100) / 100;
  const prngZ = ((hash * 17) % 100) / 100;
  return {
    input,
    hash,
    centerX: minX + prngX * (maxX - minX),
    centerY: minY + prngY * (maxY - minY),
    baseZ: -10 + prngZ * 15,
  };
});

const instants = [];
const base = new Date(2026, 0, 1, 0, 0, 0).getTime();
for (let h = 0; h < 72; h += 0.5) instants.push(base + h * 3600e3);
[
  [2026, 2, 1, 5, 59, 59], [2026, 2, 1, 6, 0, 0], [2026, 11, 31, 23, 59, 0],
  [2027, 0, 1, 5, 0, 0], [2028, 1, 29, 6, 0, 0], [2028, 2, 1, 3, 0, 0],
].forEach((a) => instants.push(new Date(...a).getTime()));
instants.push(new Date(2026, 10, 6, 6, 0, 0).getTime() - 1);
const diaryCycle = instants.map((at) => ({
  at,
  start: getDiaryCycleStart(new Date(at)).getTime(),
  end: getDiaryCycleEnd(new Date(at)).getTime(),
}));

const constellations = CONSTELLATIONS.map(({ id, name, starCount, description, features, history, starPositions, lines }) =>
  ({ id, name, starCount, description, features, history, starPositions, lines }));

const write = (dir, name, data) => writeFileSync(join(dir, name), `${JSON.stringify(data, null, 1)}\n`);
write(fixturesDir, 'mood_analysis.json', moodAnalysis);
write(fixturesDir, 'mood_color.json', moodColor);
write(fixturesDir, 'constellation_hash.json', constellationHash);
write(fixturesDir, 'diary_cycle.json', diaryCycle);
write(resourcesDir, 'constellations.json', constellations);
console.log(`mood ${moods.length} 件 / 感情タイプ ${emotionKinds.size} 種 / 星座 ${constellations.length} 個 / 時刻 ${instants.length} 件`);
```

- [ ] **Step 3: 実行する**

Run: `TZ=Asia/Tokyo node tools/golden/generate.mjs ../Nostargia`
Expected: `mood 454 件 / 感情タイプ 27 種 / 星座 9 個 / 時刻 151 件`

- [ ] **Step 4: 中身を目で確認する**

Run: `head -c 600 Packages/NostargiaKit/Tests/NostargiaKitTests/Fixtures/mood_color.json`
Expected: 最初のケース（全部0）の色が `r ≈ 0.3515, g ≈ 0.3515, b ≈ 0.3763`（`#A0A0A5` の sRGB → リニア変換後）になっている。

- [ ] **Step 5: Commit**

```bash
git add tools/golden Packages/NostargiaKit
git commit -m "test: Web版から生成したゴールデンデータと星座データを追加"
```

---

### Task 3: MoodAnalyzer（感情タイプ・totalScore・定型文の手紙）

**Files:**
- Create: `Packages/NostargiaKit/Sources/NostargiaKit/MoodAnalyzer.swift`
- Create: `Packages/NostargiaKit/Tests/NostargiaKitTests/Support/Fixture.swift`
- Test: `Packages/NostargiaKit/Tests/NostargiaKitTests/MoodAnalyzerTests.swift`

**Interfaces:**
- Consumes: `MoodValues`（Task 1）、`mood_analysis.json`（Task 2）
- Produces:
  - `public struct MoodAnalysis: Equatable, Sendable { emotion: String; totalScore: Double; fallbackFeedback: String }`
  - `public enum MoodAnalyzer { static func analyze(_ mood: MoodValues, goodThings: [String]) -> MoodAnalysis; static func totalScore(_ mood: MoodValues) -> Double; static func emotion(_ mood: MoodValues) -> String }`
  - テスト用: `enum Fixture { static func load<T: Decodable>(_ name: String, as: T.Type) throws -> T }`

- [ ] **Step 1: テスト用のゴールデンデータ読み込みを書く**

`Packages/NostargiaKit/Tests/NostargiaKitTests/Support/Fixture.swift`:
```swift
import Foundation
import Testing

/// tools/golden/generate.mjs が書き出した JSON を読み込む
enum Fixture {
    static func load<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }
}
```

- [ ] **Step 2: 失敗するテストを書く**

`Packages/NostargiaKit/Tests/NostargiaKitTests/MoodAnalyzerTests.swift`:
```swift
import Foundation
import Testing
@testable import NostargiaKit

struct MoodAnalyzerTests {
    struct GoldenCase: Decodable {
        let mood: MoodValues
        let goodThings: [String]
        let emotion: String
        let feedback: String
        let totalScore: Double
    }

    @Test func matchesWebFallbackAnalysis() throws {
        let cases = try Fixture.load("mood_analysis", as: [GoldenCase].self)
        #expect(cases.count == 454)
        for c in cases {
            let result = MoodAnalyzer.analyze(c.mood, goodThings: c.goodThings)
            #expect(result.emotion == c.emotion, "\(c.mood)")
            #expect(result.fallbackFeedback == c.feedback, "\(c.mood) \(c.goodThings)")
            #expect(abs(result.totalScore - c.totalScore) < 1e-9, "\(c.mood)")
        }
    }

    @Test func blankGoodThingsAreIgnored() {
        let result = MoodAnalyzer.analyze(.neutral, goodThings: ["  ", "\u{3000}", ""])
        #expect(!result.fallbackFeedback.hasPrefix("「"))
    }

    @Test func boundaryLevels() {
        #expect(MoodAnalyzer.emotion(MoodValues(all: 33)) == "消耗・虚無")
        #expect(MoodAnalyzer.emotion(MoodValues(all: 34)) == "普通・平穏")
        #expect(MoodAnalyzer.emotion(MoodValues(all: 67)) == "うれしい・充実・幸福")
    }
}
```

- [ ] **Step 3: 失敗を確認する**

Run: `cd Packages/NostargiaKit && swift test --filter MoodAnalyzerTests`
Expected: FAIL（`cannot find 'MoodAnalyzer' in scope`）

- [ ] **Step 4: 実装する**

`Packages/NostargiaKit/Sources/NostargiaKit/MoodAnalyzer.swift`:
```swift
import Foundation

public struct MoodAnalysis: Equatable, Sendable {
    /// 27通りの感情タイプ
    public let emotion: String
    public let totalScore: Double
    /// AI の手紙が使えないときの定型文
    public let fallbackFeedback: String
}

/// 三軸感情分析（Web版 src/utils/fallbackAnalysis.js の移植）
/// - 気分 = emotional
/// - エネルギー = (social + physical) / 2
/// - 自己充足 = (motivation + fulfillment) / 2
public enum MoodAnalyzer {
    public static func analyze(_ mood: MoodValues, goodThings: [String]) -> MoodAnalysis {
        let emotion = emotion(mood)
        let base = fallbackMessages[emotion] ?? fallbackMessages["普通・平穏"]!
        let items = goodThings
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let feedback = items.isEmpty ? base : "「\(items.joined(separator: "、"))」いいですね。\(base)"
        return MoodAnalysis(emotion: emotion, totalScore: totalScore(mood), fallbackFeedback: feedback)
    }

    /// 総合スコア = Q1×0.30 + Q2×0.25 + Q3×0.20 + Q4×0.10 + Q5×0.15（小数第1位で四捨五入）
    public static func totalScore(_ mood: MoodValues) -> Double {
        let raw = Double(mood.emotional) * 0.30
            + Double(mood.motivation) * 0.25
            + Double(mood.social) * 0.20
            + Double(mood.physical) * 0.10
            + Double(mood.fulfillment) * 0.15
        return (raw * 10).rounded(.toNearestOrAwayFromZero) / 10
    }

    public static func emotion(_ mood: MoodValues) -> String {
        let kibun = Double(mood.emotional)
        let energy = Double(mood.social + mood.physical) / 2
        let jiko = Double(mood.motivation + mood.fulfillment) / 2
        let key = "\(level(kibun))_\(level(energy))_\(level(jiko))"
        return emotionTypes[key] ?? "普通・平穏"
    }

    /// 0〜33: 低、34〜66: 中、67〜100: 高
    static func level(_ value: Double) -> String {
        if value <= 33 { return "低" }
        if value <= 66 { return "中" }
        return "高"
    }

    static let emotionTypes: [String: String] = [
        "高_高_高": "うれしい・充実・幸福",
        "高_高_中": "満足・安定",
        "高_高_低": "元気だが物足りない",
        "高_中_高": "穏やか・安心",
        "高_中_中": "まずまず・平穏",
        "高_中_低": "気分は良いが空虚",
        "高_低_高": "リラックス・静穏",
        "高_低_中": "のんびり・ゆったり",
        "高_低_低": "気分は良いが無気力",
        "中_高_高": "やる気はあるが不安定",
        "中_高_中": "活動的だが迷い",
        "中_高_低": "空回り・焦り",
        "中_中_高": "静かな充足",
        "中_中_中": "普通・平穏",
        "中_中_低": "なんとなく不満",
        "中_低_高": "疲れているが満足",
        "中_低_中": "無気力・ぼんやり",
        "中_低_低": "停滞・モヤモヤ",
        "低_高_高": "イライラ・怒り",
        "低_高_中": "焦燥・不満",
        "低_高_低": "苛立ち・暴走",
        "低_中_高": "切なさ・寂しさ",
        "低_中_中": "落ち込み・悲しみ",
        "低_中_低": "憂鬱・自己嫌悪",
        "低_低_高": "燃え尽き・喪失感",
        "低_低_中": "疲弊・無力感",
        "低_低_低": "消耗・虚無",
    ]

    static let fallbackMessages: [String: String] = [
        "うれしい・充実・幸福": "今日はとても充実した一日でしたね。その輝きを忘れずに、明日もいい一日になりますように。",
        "満足・安定": "しっかりとした一日を過ごせましたね。その安定感があなたの強さです。",
        "元気だが物足りない": "元気いっぱいなのに、どこか満たされない気持ちがあるのかもしれません。新しい挑戦が良い刺激になるかも。",
        "穏やか・安心": "穏やかな気持ちで過ごせているのは素敵です。そのままのペースで大丈夫ですよ。",
        "まずまず・平穏": "特別ではなくても、穏やかに過ごせた今日は素敵な一日です。",
        "気分は良いが空虚": "気持ちは前向きなのに、心にぽっかり穴が空いたような感覚…。小さなことでも自分を満たしてあげてくださいね。",
        "リラックス・静穏": "ゆったりと心が落ち着いている時間、大切にしてくださいね。",
        "のんびり・ゆったり": "のんびり過ごせる日もあっていいですよね。自分のペースで大丈夫。",
        "気分は良いが無気力": "気持ちは悪くないのに体が動かない…そんな日もありますよ。ゆっくり休んでくださいね。",
        "やる気はあるが不安定": "エネルギーはあるのに気持ちが揺れている…そんな時は深呼吸して、一つずつ進めていきましょう。",
        "活動的だが迷い": "動けているのに方向が定まらない感じ、もどかしいですよね。焦らなくても答えは見つかります。",
        "空回り・焦り": "頑張っているのに空回りしている感覚、辛いですよね。少し立ち止まって休むのも前進です。",
        "静かな充足": "派手さはなくても、心の中に静かな満足感がある。それはとても豊かなことです。",
        "普通・平穏": "特別な日でなくても、今日一日を過ごせたこと自体が素敵なこと。お疲れさまでした。",
        "なんとなく不満": "はっきりしないモヤモヤ、言葉にしにくいですよね。自分の気持ちに耳を傾けてみてください。",
        "疲れているが満足": "体は疲れていても心は満たされている…そんな充実した疲労感は素敵です。ゆっくり休んでくださいね。",
        "無気力・ぼんやり": "ぼんやりする日もあります。無理せず、ただ流れに身を任せるのも悪くないですよ。",
        "停滞・モヤモヤ": "何もかもが止まっているように感じる時もあります。でも、止まっている時間も必要な時間です。",
        "イライラ・怒り": "イライラする気持ち、我慢しなくていいですよ。怒りはあなたが何かを大切にしている証拠です。",
        "焦燥・不満": "焦る気持ちと不満が重なると辛いですよね。少しだけ深呼吸して、今の自分を認めてあげてください。",
        "苛立ち・暴走": "気持ちが収まらない時は、無理に抑えなくても大丈夫。安全な方法で発散してくださいね。",
        "切なさ・寂しさ": "切ない気持ちは、あなたが誰かや何かを大切に思っている証。その優しさを忘れないでください。",
        "落ち込み・悲しみ": "少し辛い気持ちなのかもしれません。大丈夫、いつか必ず前に進めます。今日はゆっくり過ごしてください。",
        "憂鬱・自己嫌悪": "自分を責めてしまう時もありますよね。でも、あなたはそのままで十分頑張っています。",
        "燃え尽き・喪失感": "頑張りすぎた後の空っぽ感、辛いですよね。何もしない時間も回復には必要です。",
        "疲弊・無力感": "心も体もお疲れですね。無理しなくていいですよ。休むことも大切な仕事です。",
        "消耗・虚無": "今はとても辛い時期かもしれません。でも、この夜空のように、暗闇の中にも必ず光はあります。",
    ]
}
```

- [ ] **Step 5: 成功を確認する**

Run: `cd Packages/NostargiaKit && swift test --filter MoodAnalyzerTests`
Expected: PASS（3 tests）

- [ ] **Step 6: Commit**

```bash
git add Packages/NostargiaKit
git commit -m "feat: 三軸感情分析 MoodAnalyzer を Web版から移植"
```

---

### Task 4: StarAppearance（色と大きさ）

**Files:**
- Create: `Packages/NostargiaKit/Sources/NostargiaKit/StarAppearance.swift`
- Test: `Packages/NostargiaKit/Tests/NostargiaKitTests/StarAppearanceTests.swift`

**Interfaces:**
- Consumes: `MoodValues`（Task 1）、`mood_color.json`（Task 2）、`Fixture`（Task 3）
- Produces:
  - `public struct StarColor: Codable, Hashable, Sendable { r, g, b: Double; init(r:g:b:); init(srgbHex: UInt32) }`（値はリニア）
  - `public enum StarAppearance { static func color(for: MoodValues) -> StarColor; static func scale(for: MoodValues, inConstellation: Bool, random: Double) -> Double }`

- [ ] **Step 1: 失敗するテストを書く**

`Packages/NostargiaKit/Tests/NostargiaKitTests/StarAppearanceTests.swift`:
```swift
import Foundation
import Testing
@testable import NostargiaKit

struct StarAppearanceTests {
    struct GoldenCase: Decodable {
        let mood: MoodValues
        let color: StarColor
    }

    @Test func colorMatchesWeb() throws {
        let cases = try Fixture.load("mood_color", as: [GoldenCase].self)
        #expect(cases.count == 454)
        for c in cases {
            let color = StarAppearance.color(for: c.mood)
            #expect(abs(color.r - c.color.r) < 1e-9, "\(c.mood)")
            #expect(abs(color.g - c.color.g) < 1e-9, "\(c.mood)")
            #expect(abs(color.b - c.color.b) < 1e-9, "\(c.mood)")
        }
    }

    @Test func goldWhenAllHundred() {
        let gold = StarAppearance.color(for: MoodValues(all: 100))
        #expect(gold.r == 1)
        #expect(abs(gold.g - 0.6795425) < 1e-6)
        #expect(gold.b == 0)
    }

    @Test func scaleFormula() {
        let mood = MoodValues(emotional: 0, motivation: 0, social: 0, physical: 40, fulfillment: 50)
        // 2.0 + 0.5*2.0 + 0.4*1.5 + 0.2*0.5
        #expect(abs(StarAppearance.scale(for: mood, inConstellation: false, random: 0.2) - 3.7) < 1e-12)
        // 星座の星は基準が 2.5
        #expect(abs(StarAppearance.scale(for: mood, inConstellation: true, random: 0) - 4.1) < 1e-12)
    }
}
```

- [ ] **Step 2: 失敗を確認する**

Run: `cd Packages/NostargiaKit && swift test --filter StarAppearanceTests`
Expected: FAIL（`cannot find 'StarAppearance' in scope`）

- [ ] **Step 3: 実装する**

`Packages/NostargiaKit/Sources/NostargiaKit/StarAppearance.swift`:
```swift
import Foundation

/// 星の色（three.js の作業色空間 = リニア の値。Web版の t_stars.color と同じ）
public struct StarColor: Codable, Hashable, Sendable {
    public var r: Double
    public var g: Double
    public var b: Double

    public init(r: Double, g: Double, b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    /// three.js の `new THREE.Color(0xRRGGBB)` と同じく、sRGB の16進値をリニアに変換する
    public init(srgbHex hex: UInt32) {
        func linear(_ byte: UInt32) -> Double {
            let c = Double(byte) / 255
            return c < 0.04045 ? c * 0.0773993808 : pow(c * 0.9478672986 + 0.0521327014, 2.4)
        }
        self.init(r: linear((hex >> 16) & 0xFF), g: linear((hex >> 8) & 0xFF), b: linear(hex & 0xFF))
    }
}

/// 星の見た目（Web版 src/utils/starDataMaker.js の generateMoodColor と scale 計算の移植）
public enum StarAppearance {
    static let gold = StarColor(srgbHex: 0xFFD700)
    static let grey = StarColor(srgbHex: 0xA0A0A5)

    /// emotional: 黄、motivation: 赤、social: マゼンタ、physical: シアン、fulfillment: 緑 を重み付けで混ぜ、最大成分で正規化する
    public static func color(for mood: MoodValues) -> StarColor {
        if mood.all.allSatisfy({ $0 == 100 }) { return gold }
        if mood.all.allSatisfy({ $0 == 0 }) { return grey }

        let bases: [(r: Double, g: Double, b: Double)] = [(1, 1, 0), (1, 0, 0), (1, 0, 1), (0, 1, 1), (0, 1, 0)]
        let weights = mood.all.map { Double($0) / 100 }
        var r = 0.0
        var g = 0.0
        var b = 0.0
        for (base, w) in zip(bases, weights) {
            r += base.r * w
            g += base.g * w
            b += base.b * w
        }
        let maxComponent = max(r, g, b)
        if maxComponent == 0 { return grey }
        return StarColor(r: r / maxComponent, g: g / maxComponent, b: b / maxComponent)
    }

    /// random は 0..<1 の乱数（Web版の Math.random() に相当）
    public static func scale(for mood: MoodValues, inConstellation: Bool, random: Double) -> Double {
        let baseScale = inConstellation ? 2.5 : 2.0
        let fulfillmentBonus = Double(mood.fulfillment) / 100 * 2.0
        let physicalBonus = Double(mood.physical) / 100 * 1.5
        return baseScale + fulfillmentBonus + physicalBonus + random * 0.5
    }
}
```

- [ ] **Step 4: 成功を確認する**

Run: `cd Packages/NostargiaKit && swift test --filter StarAppearanceTests`
Expected: PASS（3 tests）

- [ ] **Step 5: Commit**

```bash
git add Packages/NostargiaKit
git commit -m "feat: 星の色と大きさ StarAppearance を Web版から移植"
```

---

### Task 5: 星座データと ConstellationAssigner

**Files:**
- Create: `Packages/NostargiaKit/Sources/NostargiaKit/Constellation.swift`
- Create: `Packages/NostargiaKit/Sources/NostargiaKit/ConstellationAssigner.swift`
- Test: `Packages/NostargiaKit/Tests/NostargiaKitTests/ConstellationAssignerTests.swift`

**Interfaces:**
- Consumes: `MoodValues`（Task 1）、`constellations.json`（Task 2）
- Produces:
  - `public struct Constellation: Codable, Hashable, Sendable, Identifiable`（`id, name: String; starCount: Int; description, features, history: String; starPositions: [Node]; lines: [[Int]]`、`struct Node { x, y: Double }`）
  - `public enum ConstellationCatalog { static let all: [Constellation] }`
  - `public struct ConstellationAssignment: Codable, Hashable, Sendable { id: String; nodeIndex: Int }`
  - `public enum ConstellationAssigner { static func assign(mood: MoodValues, existing: [ConstellationAssignment], catalog: [Constellation] = ConstellationCatalog.all) -> ConstellationAssignment? }`

- [ ] **Step 1: 失敗するテストを書く**

`Packages/NostargiaKit/Tests/NostargiaKitTests/ConstellationAssignerTests.swift`:
```swift
import Foundation
import Testing
@testable import NostargiaKit

struct ConstellationAssignerTests {
    let happy = MoodValues(all: 50)

    @Test func catalogHasNineInWebOrder() {
        let ids = ConstellationCatalog.all.map(\.id)
        #expect(ids == ["andromeda", "monoceros", "sagittarius", "delphinus", "indus", "pisces", "lepus", "bootes", "hydra"])
        #expect(ConstellationCatalog.all.allSatisfy { $0.starPositions.count == $0.starCount })
    }

    @Test func notCandidateWhenAnySliderBelowFifty() {
        var mood = happy
        mood.physical = 49
        #expect(ConstellationAssigner.assign(mood: mood, existing: []) == nil)
    }

    @Test func firstFreeNodeOfFirstOpenConstellation() {
        let existing = [
            ConstellationAssignment(id: "andromeda", nodeIndex: 0),
            ConstellationAssignment(id: "andromeda", nodeIndex: 2),
        ]
        #expect(ConstellationAssigner.assign(mood: happy, existing: existing) == ConstellationAssignment(id: "andromeda", nodeIndex: 1))
    }

    @Test func movesToNextWhenFull() {
        let existing = (0..<11).map { ConstellationAssignment(id: "andromeda", nodeIndex: $0) }
        #expect(ConstellationAssigner.assign(mood: happy, existing: existing) == ConstellationAssignment(id: "monoceros", nodeIndex: 0))
    }

    @Test func nilWhenEverythingIsFull() {
        let existing = ConstellationCatalog.all.flatMap { c in
            (0..<c.starCount).map { ConstellationAssignment(id: c.id, nodeIndex: $0) }
        }
        #expect(ConstellationAssigner.assign(mood: happy, existing: existing) == nil)
    }

    @Test func corruptedIndicesDoNotCrash() {
        // 範囲外の nodeIndex が混ざっていても、空きが無い星座は飛ばす
        let existing = (0..<10).map { ConstellationAssignment(id: "andromeda", nodeIndex: $0) }
            + [ConstellationAssignment(id: "andromeda", nodeIndex: 99)]
            + (0..<10).map { ConstellationAssignment(id: "andromeda", nodeIndex: $0) }
        let result = ConstellationAssigner.assign(mood: happy, existing: existing)
        #expect(result == ConstellationAssignment(id: "andromeda", nodeIndex: 10))

        let broken = (1..<11).map { ConstellationAssignment(id: "andromeda", nodeIndex: $0) }
            + [ConstellationAssignment(id: "andromeda", nodeIndex: 0)]
            + [ConstellationAssignment(id: "andromeda", nodeIndex: -1)]
        #expect(ConstellationAssigner.assign(mood: happy, existing: broken) == ConstellationAssignment(id: "monoceros", nodeIndex: 0))
    }
}
```

- [ ] **Step 2: 失敗を確認する**

Run: `cd Packages/NostargiaKit && swift test --filter ConstellationAssignerTests`
Expected: FAIL（`cannot find 'ConstellationCatalog' in scope`）

- [ ] **Step 3: 実装する**

`Packages/NostargiaKit/Sources/NostargiaKit/Constellation.swift`:
```swift
import Foundation

/// 星座データ（Web版 src/data/constellationData.js から生成した constellations.json）
public struct Constellation: Codable, Hashable, Sendable, Identifiable {
    /// 0〜1 に正規化された星の位置（y=0 が上端）
    public struct Node: Codable, Hashable, Sendable {
        public let x: Double
        public let y: Double
    }

    public let id: String
    public let name: String
    public let starCount: Int
    public let description: String
    public let features: String
    public let history: String
    public let starPositions: [Node]
    public let lines: [[Int]]
}

public enum ConstellationCatalog {
    /// Web版と同じ順番の9星座。割り当てはこの順で埋まっていく
    public static let all: [Constellation] = {
        guard let url = Bundle.module.url(forResource: "constellations", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([Constellation].self, from: data)
        else {
            fatalError("constellations.json を読み込めません。tools/golden/generate.mjs を実行してください")
        }
        return list
    }()
}
```

`Packages/NostargiaKit/Sources/NostargiaKit/ConstellationAssigner.swift`:
```swift
import Foundation

public struct ConstellationAssignment: Codable, Hashable, Sendable {
    public let id: String
    public let nodeIndex: Int

    public init(id: String, nodeIndex: Int) {
        self.id = id
        self.nodeIndex = nodeIndex
    }
}

/// 星座ノードの割り当て（Web版 src/utils/starDataMaker.js の星座判定の移植）
public enum ConstellationAssigner {
    /// 全スライダーが 50 以上なら、カタログの順に見て最初に空きがある星座の、最小の空きノードを返す
    public static func assign(
        mood: MoodValues,
        existing: [ConstellationAssignment],
        catalog: [Constellation] = ConstellationCatalog.all
    ) -> ConstellationAssignment? {
        guard mood.allAtLeast(50) else { return nil }

        for constellation in catalog {
            let taken = Set(existing.filter { $0.id == constellation.id }.map(\.nodeIndex))
            // Web版は空きが見つからないと nodeIndex = -1 で壊れた星を作るため、ここでは次の星座へ進む
            if let free = (0..<constellation.starCount).first(where: { !taken.contains($0) }) {
                return ConstellationAssignment(id: constellation.id, nodeIndex: free)
            }
        }
        return nil
    }
}
```

- [ ] **Step 4: 成功を確認する**

Run: `cd Packages/NostargiaKit && swift test --filter ConstellationAssignerTests`
Expected: PASS（6 tests）

- [ ] **Step 5: Commit**

```bash
git add Packages/NostargiaKit
git commit -m "feat: 星座データと星座ノードの割り当てを Web版から移植"
```

---

### Task 6: RandomSource と StarPlacement（星の位置）

**Files:**
- Create: `Packages/NostargiaKit/Sources/NostargiaKit/RandomSource.swift`
- Create: `Packages/NostargiaKit/Sources/NostargiaKit/StarPlacement.swift`
- Create: `Packages/NostargiaKit/Tests/NostargiaKitTests/Support/SequenceRandom.swift`
- Test: `Packages/NostargiaKit/Tests/NostargiaKitTests/StarPlacementTests.swift`

**Interfaces:**
- Consumes: `Constellation`, `ConstellationAssignment`（Task 5）、`constellation_hash.json`（Task 2）、`Fixture`（Task 3）
- Produces:
  - `public protocol RandomSource { mutating func next() -> Double }`（0..<1）、`public struct SystemRandomSource: RandomSource`
  - `public struct StarPosition: Codable, Hashable, Sendable { x, y, z: Double }`
  - `public enum StarPlacement { static func hashCode(_: String) -> Int64; static func constellationCenter(id: String) -> StarPosition; static func position(for: ConstellationAssignment, in: Constellation, random: inout some RandomSource) -> StarPosition; static func randomPosition(avoiding: [StarPosition], random: inout some RandomSource) -> StarPosition }`
  - テスト用: `struct SequenceRandom: RandomSource { init(_ values: [Double]) }`（値を順番に繰り返し返す）

- [ ] **Step 1: テスト用の固定乱数を書く**

`Packages/NostargiaKit/Tests/NostargiaKitTests/Support/SequenceRandom.swift`:
```swift
@testable import NostargiaKit

/// 決めた値を順番に（最後まで行ったら先頭から）返す乱数
struct SequenceRandom: RandomSource {
    private let values: [Double]
    private var index = 0

    init(_ values: [Double]) {
        self.values = values
    }

    mutating func next() -> Double {
        defer { index += 1 }
        return values[index % values.count]
    }
}
```

- [ ] **Step 2: 失敗するテストを書く**

`Packages/NostargiaKit/Tests/NostargiaKitTests/StarPlacementTests.swift`:
```swift
import Foundation
import Testing
@testable import NostargiaKit

struct StarPlacementTests {
    struct GoldenHash: Decodable {
        let input: String
        let hash: Int64
        let centerX: Double
        let centerY: Double
        let baseZ: Double
    }

    @Test func hashAndCenterMatchWeb() throws {
        let cases = try Fixture.load("constellation_hash", as: [GoldenHash].self)
        #expect(cases.count == 13)
        for c in cases {
            #expect(StarPlacement.hashCode(c.input) == c.hash, "\(c.input)")
            let center = StarPlacement.constellationCenter(id: c.input)
            #expect(abs(center.x - c.centerX) < 1e-9, "\(c.input)")
            #expect(abs(center.y - c.centerY) < 1e-9, "\(c.input)")
            #expect(abs(center.z - c.baseZ) < 1e-9, "\(c.input)")
        }
    }

    @Test func constellationNodePosition() throws {
        let andromeda = try #require(ConstellationCatalog.all.first { $0.id == "andromeda" })
        let center = StarPlacement.constellationCenter(id: "andromeda")
        var random = SequenceRandom([0.5])
        let p = StarPlacement.position(for: ConstellationAssignment(id: "andromeda", nodeIndex: 0), in: andromeda, random: &random)
        // node 0 = (0.12, 0.5)。y は反転、z の揺らぎは乱数 0.5 で 0
        #expect(abs(p.x - (center.x + (0.12 - 0.5) * 60)) < 1e-9)
        #expect(abs(p.y - (center.y + (0.5 - 0.5) * 60)) < 1e-9)
        #expect(abs(p.z - center.z) < 1e-9)
    }

    @Test func randomPositionUsesWebRanges() {
        var random = SequenceRandom([0.0, 1.0, 0.5])
        let p = StarPlacement.randomPosition(avoiding: [], random: &random)
        #expect(p == StarPosition(x: -320, y: 160, z: -10))
    }

    @Test func randomPositionRetriesNearConstellationStars() {
        // 1回目 (0,0,-10) は星座の星に近すぎるので、2回目 (64,32,-10) を使う
        var random = SequenceRandom([0.5, 0.5, 0.5, 0.6, 0.6, 0.5])
        let p = StarPlacement.randomPosition(avoiding: [StarPosition(x: 1, y: 1, z: -10)], random: &random)
        #expect(abs(p.x - 64) < 1e-9)
        #expect(abs(p.y - 32) < 1e-9)
    }

    @Test func randomPositionGivesUpAfterFiftyTries() {
        // ずっと近すぎる場合も、50回で諦めて最後の候補を返す
        var random = SequenceRandom([0.5])
        let p = StarPlacement.randomPosition(avoiding: [StarPosition(x: 0, y: 0, z: -10)], random: &random)
        #expect(p == StarPosition(x: 0, y: 0, z: -10))
    }
}
```

- [ ] **Step 3: 失敗を確認する**

Run: `cd Packages/NostargiaKit && swift test --filter StarPlacementTests`
Expected: FAIL（`cannot find type 'RandomSource' in scope`）

- [ ] **Step 4: 実装する**

`Packages/NostargiaKit/Sources/NostargiaKit/RandomSource.swift`:
```swift
import Foundation

/// 0..<1 の乱数。テストで結果を固定できるように差し替え可能にしている
public protocol RandomSource {
    mutating func next() -> Double
}

public struct SystemRandomSource: RandomSource {
    public init() {}

    public mutating func next() -> Double {
        Double.random(in: 0..<1)
    }
}
```

`Packages/NostargiaKit/Sources/NostargiaKit/StarPlacement.swift`:
```swift
import Foundation

public struct StarPosition: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double

    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }
}

/// 星の位置（Web版 src/utils/starDataMaker.js の移植）。星空の範囲は X ±320、Y ±160
public enum StarPlacement {
    static let boxSize = 60.0
    static let minX = -320 + boxSize / 2 + 10
    static let maxX = 320 - boxSize / 2 - 10
    static let minY = -160 + boxSize / 2 + 10
    static let maxY = 160 - boxSize / 2 - 10

    /// Web版 hashCode と同じ（UTF-16 単位で 32bit 整数演算、最後に絶対値）
    public static func hashCode(_ string: String) -> Int64 {
        var hash: Int32 = 0
        for unit in string.utf16 {
            hash = (hash &<< 5) &- hash &+ Int32(unit)
        }
        return abs(Int64(hash))
    }

    /// 星座の中心。z は星座全体の基準の奥行き
    public static func constellationCenter(id: String) -> StarPosition {
        let hash = hashCode(id)
        let prngX = Double(hash % 100) / 100
        let prngY = Double((hash * 13) % 100) / 100
        let prngZ = Double((hash * 17) % 100) / 100
        return StarPosition(
            x: minX + prngX * (maxX - minX),
            y: minY + prngY * (maxY - minY),
            z: -10 + prngZ * 15
        )
    }

    public static func position(
        for assignment: ConstellationAssignment,
        in constellation: Constellation,
        random: inout some RandomSource
    ) -> StarPosition {
        let center = constellationCenter(id: constellation.id)
        let node = constellation.starPositions[assignment.nodeIndex]
        let localX = (node.x - 0.5) * boxSize
        // 星座データは y=0 が上端、星空は y が大きいほど上なので反転する
        let localY = (0.5 - node.y) * boxSize
        return StarPosition(
            x: center.x + localX,
            y: center.y + localY,
            z: center.z + (random.next() - 0.5) * 2
        )
    }

    /// 星座の星から半径5以内を避けてランダムに置く。50回試してもだめなら最後の候補を使う
    public static func randomPosition(
        avoiding constellationStars: [StarPosition],
        random: inout some RandomSource
    ) -> StarPosition {
        var candidate = StarPosition(x: 0, y: 0, z: 0)
        for _ in 0..<50 {
            let x = (random.next() - 0.5) * 640
            let y = (random.next() - 0.5) * 320
            let z = -10 + (random.next() - 0.5) * 15
            candidate = StarPosition(x: x, y: y, z: z)
            let collides = constellationStars.contains { p in
                let dx = p.x - x
                let dy = p.y - y
                let dz = p.z - z
                return dx * dx + dy * dy + dz * dz < 25
            }
            if !collides { break }
        }
        return candidate
    }
}
```

- [ ] **Step 5: 成功を確認する**

Run: `cd Packages/NostargiaKit && swift test --filter StarPlacementTests`
Expected: PASS（5 tests）

- [ ] **Step 6: Commit**

```bash
git add Packages/NostargiaKit
git commit -m "feat: 星の配置 StarPlacement を Web版から移植"
```

---

### Task 7: DiaryCycle と AppClock（朝6時区切り・クールダウン）

**Files:**
- Create: `Packages/NostargiaKit/Sources/NostargiaKit/DiaryCycle.swift`
- Create: `Packages/NostargiaKit/Sources/NostargiaKit/AppClock.swift`
- Test: `Packages/NostargiaKit/Tests/NostargiaKitTests/DiaryCycleTests.swift`

**Interfaces:**
- Consumes: `diary_cycle.json`（Task 2）、`Fixture`（Task 3）
- Produces:
  - `public struct DiaryCycle: Sendable { init(calendar: Calendar = .current); func start(containing: Date) -> Date; func end(containing: Date) -> Date; func isCooldownActive(starDates: [Date], now: Date) -> Bool; func cooldownProgress(starDates: [Date], now: Date) -> Double; func cooldownRemaining(now: Date) -> TimeInterval; func cooldownText(now: Date) -> String }`
  - `public struct AppClock: Sendable { init(debugDayOffset: Int = 0, calendar: Calendar = .current, base: @escaping @Sendable () -> Date = { Date() }); var debugDayOffset: Int; func now() -> Date }`

- [ ] **Step 1: 失敗するテストを書く**

`Packages/NostargiaKit/Tests/NostargiaKitTests/DiaryCycleTests.swift`:
```swift
import Foundation
import Testing
@testable import NostargiaKit

struct DiaryCycleTests {
    static func calendar(_ identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier)!
        return calendar
    }

    let tokyo = calendar("Asia/Tokyo")
    var cycle: DiaryCycle { DiaryCycle(calendar: tokyo) }

    func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int = 0, _ s: Int = 0, calendar: Calendar? = nil) -> Date {
        (calendar ?? tokyo).date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi, second: s))!
    }

    struct GoldenCase: Decodable {
        let at: Double
        let start: Double
        let end: Double
    }

    @Test func boundariesMatchWeb() throws {
        let cases = try Fixture.load("diary_cycle", as: [GoldenCase].self)
        #expect(cases.count == 151)
        for c in cases {
            let at = Date(timeIntervalSince1970: c.at / 1000)
            #expect(cycle.start(containing: at).timeIntervalSince1970 * 1000 == c.start, "\(at)")
            #expect(cycle.end(containing: at).timeIntervalSince1970 * 1000 == c.end, "\(at)")
        }
    }

    @Test func dstDayIsTwentyThreeHours() {
        let newYork = Self.calendar("America/New_York")
        let dstCycle = DiaryCycle(calendar: newYork)
        let noon = date(2026, 3, 8, 12, calendar: newYork)
        let start = dstCycle.start(containing: noon)
        #expect(start == date(2026, 3, 8, 6, calendar: newYork))
        #expect(dstCycle.end(containing: noon) == date(2026, 3, 9, 6, calendar: newYork))
        #expect(dstCycle.end(containing: noon).timeIntervalSince(start) == 23 * 3600)
    }

    @Test func noStarsMeansReady() {
        #expect(!cycle.isCooldownActive(starDates: [], now: date(2026, 11, 6, 12)))
        #expect(cycle.cooldownProgress(starDates: [], now: date(2026, 11, 6, 12)) == 1)
    }

    @Test func starInCurrentCycleStartsCooldown() {
        let stars = [date(2026, 11, 6, 7)]
        #expect(cycle.isCooldownActive(starDates: stars, now: date(2026, 11, 7, 5, 59)))
        #expect(!cycle.isCooldownActive(starDates: stars, now: date(2026, 11, 7, 6)))
    }

    @Test func starBeforeSixBelongsToPreviousCycle() {
        let stars = [date(2026, 11, 6, 5, 59)]
        #expect(!cycle.isCooldownActive(starDates: stars, now: date(2026, 11, 6, 6)))
    }

    @Test func futureStarsAreIgnored() {
        // デバッグで日数を戻したとき、今より後の星は数えない
        let stars = [date(2026, 11, 6, 8), date(2026, 11, 9, 8)]
        let now = date(2026, 11, 7, 12)
        #expect(!cycle.isCooldownActive(starDates: stars, now: now))
        #expect(cycle.cooldownProgress(starDates: stars, now: now) == 1)
    }

    @Test func progressIsElapsedShareOfCycle() {
        let stars = [date(2026, 11, 6, 7)]
        #expect(abs(cycle.cooldownProgress(starDates: stars, now: date(2026, 11, 6, 18)) - 0.5) < 1e-12)
    }

    @Test func remainingText() {
        // 残り59分30秒 → 分は切り上げで 60分 → "1h 00m"
        #expect(cycle.cooldownText(now: date(2026, 11, 6, 5, 0, 30)) == "1h 00m")
        #expect(cycle.cooldownText(now: date(2026, 11, 6, 6)) == "24h 00m")
        #expect(cycle.cooldownRemaining(now: date(2026, 11, 6, 22, 30)) == 7.5 * 3600)
    }

    @Test func appClockAddsDebugDays() {
        let base = date(2026, 11, 6, 12)
        let clock = AppClock(debugDayOffset: 2, calendar: tokyo, base: { base })
        #expect(clock.now() == date(2026, 11, 8, 12))
        #expect(AppClock(calendar: tokyo, base: { base }).now() == base)
    }
}
```

- [ ] **Step 2: 失敗を確認する**

Run: `cd Packages/NostargiaKit && swift test --filter DiaryCycleTests`
Expected: FAIL（`cannot find 'DiaryCycle' in scope`）

- [ ] **Step 3: 実装する**

`Packages/NostargiaKit/Sources/NostargiaKit/DiaryCycle.swift`:
```swift
import Foundation

/// 日記の周期とクールダウン（Web版 src/utils/appTime.js の移植）
/// 毎日 6:00 から翌日 6:00 までを1周期とし、1周期に書ける日記は1回
public struct DiaryCycle: Sendable {
    public static let resetHour = 6

    public let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// 6:00 より前なら前日の 6:00、以降なら当日の 6:00
    public func start(containing date: Date) -> Date {
        var day = calendar.startOfDay(for: date)
        if calendar.component(.hour, from: date) < Self.resetHour {
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return calendar.date(bySettingHour: Self.resetHour, minute: 0, second: 0, of: day)!
    }

    /// 次の 6:00
    public func end(containing date: Date) -> Date {
        calendar.date(byAdding: .day, value: 1, to: start(containing: date))!
    }

    public func isCooldownActive(starDates: [Date], now: Date) -> Bool {
        guard let latest = latestPastStar(starDates, now: now) else { return false }
        return latest >= start(containing: now)
    }

    /// 0 = 書いた直後、1 = 書ける状態
    public func cooldownProgress(starDates: [Date], now: Date) -> Double {
        guard let latest = latestPastStar(starDates, now: now) else { return 1 }
        let cycleStart = start(containing: now)
        if latest < cycleStart { return 1 }
        let total = end(containing: now).timeIntervalSince(cycleStart)
        let elapsed = now.timeIntervalSince(cycleStart)
        return min(1, max(0, elapsed / total))
    }

    public func cooldownRemaining(now: Date) -> TimeInterval {
        max(0, end(containing: now).timeIntervalSince(now))
    }

    /// "7h 05m" の形式（分は切り上げ）
    public func cooldownText(now: Date) -> String {
        let totalMinutes = Int((cooldownRemaining(now: now) / 60).rounded(.up))
        return "\(totalMinutes / 60)h \(String(format: "%02d", totalMinutes % 60))m"
    }

    /// 今より前に作られた星のうち最新のもの（デバッグで日数を戻したときの未来の星は除外）
    private func latestPastStar(_ starDates: [Date], now: Date) -> Date? {
        starDates.filter { $0 <= now }.max()
    }
}
```

`Packages/NostargiaKit/Sources/NostargiaKit/AppClock.swift`:
```swift
import Foundation

/// アプリの現在時刻。デバッグ用の日数ずらし（Web版の debugDayOffset）を反映する
public struct AppClock: Sendable {
    public var debugDayOffset: Int
    public let calendar: Calendar
    private let base: @Sendable () -> Date

    public init(debugDayOffset: Int = 0, calendar: Calendar = .current, base: @escaping @Sendable () -> Date = { Date() }) {
        self.debugDayOffset = debugDayOffset
        self.calendar = calendar
        self.base = base
    }

    public func now() -> Date {
        let date = base()
        guard debugDayOffset != 0 else { return date }
        return calendar.date(byAdding: .day, value: debugDayOffset, to: date)!
    }
}
```

- [ ] **Step 4: 成功を確認する**

Run: `cd Packages/NostargiaKit && swift test --filter DiaryCycleTests`
Expected: PASS（9 tests）

- [ ] **Step 5: Commit**

```bash
git add Packages/NostargiaKit
git commit -m "feat: 朝6時区切りのクールダウン DiaryCycle と AppClock を移植"
```

---

### Task 8: StarFactory（新しい星の設計図）

**Files:**
- Create: `Packages/NostargiaKit/Sources/NostargiaKit/StarFactory.swift`
- Test: `Packages/NostargiaKit/Tests/NostargiaKitTests/StarFactoryTests.swift`

**Interfaces:**
- Consumes: `MoodValues`, `StarAppearance`, `StarColor`, `ConstellationAssigner`, `ConstellationAssignment`, `ConstellationCatalog`, `StarPlacement`, `StarPosition`, `RandomSource`（Task 1, 4, 5, 6）、`SequenceRandom`（Task 6）
- Produces:
  - `public struct ExistingStar: Sendable { init(position: StarPosition, constellation: ConstellationAssignment?) }`
  - `public struct StarBlueprint: Equatable, Sendable { position: StarPosition; color: StarColor; scale: Double; random: Double; constellation: ConstellationAssignment? }`
  - `public enum StarFactory { static func make(mood: MoodValues, existing: [ExistingStar], catalog: [Constellation] = ConstellationCatalog.all, random: inout some RandomSource) -> StarBlueprint }`
  - 乱数を使う順番は Web版と同じ：位置 → scale → random

- [ ] **Step 1: 失敗するテストを書く**

`Packages/NostargiaKit/Tests/NostargiaKitTests/StarFactoryTests.swift`:
```swift
import Foundation
import Testing
@testable import NostargiaKit

struct StarFactoryTests {
    @Test func ordinaryStarIsRandomlyPlaced() {
        let mood = MoodValues(emotional: 10, motivation: 20, social: 30, physical: 40, fulfillment: 50)
        // 位置で3回、scale で1回、random で1回
        var random = SequenceRandom([0.5, 0.5, 0.5, 0.2, 0.9])
        let star = StarFactory.make(mood: mood, existing: [], random: &random)
        #expect(star.constellation == nil)
        #expect(star.position == StarPosition(x: 0, y: 0, z: -10))
        #expect(star.color == StarAppearance.color(for: mood))
        #expect(abs(star.scale - StarAppearance.scale(for: mood, inConstellation: false, random: 0.2)) < 1e-12)
        #expect(star.random == 0.9)
    }

    @Test func happyStarJoinsConstellation() throws {
        let mood = MoodValues(all: 80)
        var random = SequenceRandom([0.5, 0.3, 0.7])
        let star = StarFactory.make(mood: mood, existing: [], random: &random)
        #expect(star.constellation == ConstellationAssignment(id: "andromeda", nodeIndex: 0))
        let andromeda = try #require(ConstellationCatalog.all.first)
        var same = SequenceRandom([0.5])
        #expect(star.position == StarPlacement.position(for: ConstellationAssignment(id: "andromeda", nodeIndex: 0), in: andromeda, random: &same))
        #expect(abs(star.scale - StarAppearance.scale(for: mood, inConstellation: true, random: 0.3)) < 1e-12)
        #expect(star.random == 0.7)
    }

    @Test func happyStarFallsBackToRandomWhenAllFull() {
        let existing = ConstellationCatalog.all.flatMap { c in
            (0..<c.starCount).map { i in
                ExistingStar(position: StarPosition(x: 0, y: 0, z: 0), constellation: ConstellationAssignment(id: c.id, nodeIndex: i))
            }
        }
        var random = SequenceRandom([0.9, 0.9, 0.5, 0.1, 0.4])
        let star = StarFactory.make(mood: MoodValues(all: 100), existing: existing, random: &random)
        #expect(star.constellation == nil)
        #expect(abs(star.position.x - 256) < 1e-9)
        #expect(abs(star.scale - StarAppearance.scale(for: MoodValues(all: 100), inConstellation: false, random: 0.1)) < 1e-12)
    }
}
```

- [ ] **Step 2: 失敗を確認する**

Run: `cd Packages/NostargiaKit && swift test --filter StarFactoryTests`
Expected: FAIL（`cannot find 'StarFactory' in scope`）

- [ ] **Step 3: 実装する**

`Packages/NostargiaKit/Sources/NostargiaKit/StarFactory.swift`:
```swift
import Foundation

/// 配置済みの星（位置の衝突判定と星座の空き確認に使う）
public struct ExistingStar: Sendable {
    public let position: StarPosition
    public let constellation: ConstellationAssignment?

    public init(position: StarPosition, constellation: ConstellationAssignment?) {
        self.position = position
        self.constellation = constellation
    }
}

/// 保存前の新しい星の見た目と位置
public struct StarBlueprint: Equatable, Sendable {
    public let position: StarPosition
    public let color: StarColor
    public let scale: Double
    /// 瞬きなどの個体差に使う 0..<1 の値（Web版 t_stars.random）
    public let random: Double
    public let constellation: ConstellationAssignment?
}

/// Web版 starDataMaker の移植。日付や ID は保存時にデータ層で付ける
public enum StarFactory {
    public static func make(
        mood: MoodValues,
        existing: [ExistingStar],
        catalog: [Constellation] = ConstellationCatalog.all,
        random: inout some RandomSource
    ) -> StarBlueprint {
        let assignment = ConstellationAssigner.assign(
            mood: mood,
            existing: existing.compactMap(\.constellation),
            catalog: catalog
        )

        let position: StarPosition
        if let assignment, let constellation = catalog.first(where: { $0.id == assignment.id }) {
            position = StarPlacement.position(for: assignment, in: constellation, random: &random)
        } else {
            let constellationStars = existing.filter { $0.constellation != nil }.map(\.position)
            position = StarPlacement.randomPosition(avoiding: constellationStars, random: &random)
        }

        return StarBlueprint(
            position: position,
            color: StarAppearance.color(for: mood),
            scale: StarAppearance.scale(for: mood, inConstellation: assignment != nil, random: random.next()),
            random: random.next(),
            constellation: assignment
        )
    }
}
```

- [ ] **Step 4: 成功を確認する**

Run: `cd Packages/NostargiaKit && swift test`
Expected: PASS（全テスト。合計 32 tests）

- [ ] **Step 5: Commit**

```bash
git add Packages/NostargiaKit
git commit -m "feat: 新しい星の設計図を作る StarFactory を追加"
```

---

### Task 9: iOS アプリの立ち上げ（XcodeGen）

**Files:**
- Create: `project.yml`
- Create: `App/NostargiaApp.swift`
- Create: `README.md`

**Interfaces:**
- Consumes: `ConstellationCatalog`（Task 5）
- Produces: Xcode プロジェクト `Nostargia.xcodeproj`（`xcodegen generate` で生成。コミットしない）、スキーム `Nostargia`

- [ ] **Step 1: XcodeGen を入れる**

Run: `brew install xcodegen && xcodegen --version`
Expected: バージョンが表示される

- [ ] **Step 2: project.yml を書く**

`project.yml`:
```yaml
name: Nostargia
options:
  bundleIdPrefix: com.mn329
  deploymentTarget:
    iOS: "17.0"
packages:
  NostargiaKit:
    path: Packages/NostargiaKit
targets:
  Nostargia:
    type: application
    platform: iOS
    sources: [App]
    dependencies:
      - package: NostargiaKit
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.mn329.nostargia
        PRODUCT_NAME: Nostargia
        TARGETED_DEVICE_FAMILY: "1"
        SWIFT_VERSION: "6.0"
        GENERATE_INFOPLIST_FILE: YES
        INFOPLIST_KEY_CFBundleDisplayName: ノスタージア
        INFOPLIST_KEY_UISupportedInterfaceOrientations: UIInterfaceOrientationPortrait
        INFOPLIST_KEY_UILaunchScreen_Generation: YES
        MARKETING_VERSION: "0.1.0"
        CURRENT_PROJECT_VERSION: "1"
```

- [ ] **Step 3: 空のアプリを書く**

`App/NostargiaApp.swift`:
```swift
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
```

- [ ] **Step 4: プロジェクトを生成してビルドする**

Run: `xcodegen generate && xcodebuild -project Nostargia.xcodeproj -scheme Nostargia -destination 'generic/platform=iOS Simulator' build -quiet`
Expected: エラーなく終了する（`** BUILD SUCCEEDED **` または `-quiet` で出力なし、終了コード 0）

- [ ] **Step 5: シミュレーターで起動を確認する**

Run: `open Nostargia.xcodeproj` → Xcode で iPhone シミュレーターを選んで実行
Expected: 黒い画面に「Nostargia」と「星座 9 個」が表示される

- [ ] **Step 6: README を書く**

`README.md`:
```markdown
# Nostargia iOS

Web版 [Nostargia](https://github.com/JIsaiah/Nostargia) の iOS ネイティブ版（Swift / SwiftUI / Metal / Firebase）。

- 設計書: `docs/superpowers/specs/2026-11-06-nostargia-ios-design.md`
- 実装計画: `docs/superpowers/plans/`

## 開発の始め方

1. Xcode 26 以上と XcodeGen（`brew install xcodegen`）を入れる
2. `xcodegen generate` で `Nostargia.xcodeproj` を生成する（生成物なのでコミットしない）
3. `open Nostargia.xcodeproj`

## テスト

ドメインロジックは Swift パッケージ `Packages/NostargiaKit` にあり、Mac 上でテストできる。

    cd Packages/NostargiaKit && swift test

## ゴールデンデータの再生成

Web版と同じ結果になるかを確かめる正解データは、Web版の JS を実行して作る。

    cd ../Nostargia && npm ci && cd -
    TZ=Asia/Tokyo node tools/golden/generate.mjs ../Nostargia
```

- [ ] **Step 7: Commit**

```bash
git add project.yml App README.md
git commit -m "feat: XcodeGen で iOS アプリを立ち上げ、NostargiaKit を読み込む"
```
