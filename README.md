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
