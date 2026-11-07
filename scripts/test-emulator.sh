#!/bin/bash
# Auth / Firestore エミュレーターを起動して、アプリをホストにした結合テストを流す
# 使い方: scripts/test-emulator.sh [-only-testing:NostargiaTests/クラス名 ...]
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f Config/Firebase.xcconfig ] || cp Config/Firebase.xcconfig.example Config/Firebase.xcconfig
xcodegen generate --quiet
firebase emulators:exec --only auth,firestore --project demo-nostargia \
  "xcodebuild test -project Nostargia.xcodeproj -scheme Nostargia -destination 'platform=iOS Simulator,name=iPhone 17' -clonedSourcePackagesDirPath build/SourcePackages -derivedDataPath build/dd -disableAutomaticPackageResolution -quiet $*"
