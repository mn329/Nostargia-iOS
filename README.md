# Nostargia iOS

Web版 [Nostargia](https://github.com/JIsaiah/Nostargia) の iOS ネイティブ版（Swift / SwiftUI / Metal / Firebase）。

- 設計書: `docs/superpowers/specs/2026-11-06-nostargia-ios-design.md`
- 実装計画: `docs/superpowers/plans/`

## 開発の始め方

1. Xcode 26 以上と XcodeGen（`brew install xcodegen`）を入れる（firebase-ios-sdk は Xcode 26.0 で使える 12.19.3 に固定。Xcode 26.2 以上にしたら 13 系へ上げる）
2. `cp Config/Firebase.xcconfig.example Config/Firebase.xcconfig`
3. `xcodegen generate` で `Nostargia.xcodeproj` を生成する（生成物なのでコミットしない）
4. `open Nostargia.xcodeproj`

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

## ゴールデンデータの再生成

Web版と同じ結果になるかを確かめる正解データは、Web版の JS を実行して作る。

    cd ../Nostargia && npm ci && cd -
    TZ=Asia/Tokyo node tools/golden/generate.mjs ../Nostargia
