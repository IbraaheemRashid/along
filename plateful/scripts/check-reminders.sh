#!/usr/bin/env bash
set -euo pipefail
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
cd "$(dirname "$0")/.."
mkdir -p .build/ModuleCache
xcrun swiftc \
  -target arm64-apple-macosx14.0 -module-cache-path .build/ModuleCache \
  apps/ios/Along/ReminderModel.swift apps/ios/Along/ReminderStore.swift \
  tests/ios/ReminderTests.swift -o .build/reminder-tests
.build/reminder-tests
