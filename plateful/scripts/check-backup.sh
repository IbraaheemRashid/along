#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/ModuleCache
compile_backup() {
  env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc "$@" \
    -module-cache-path .build/ModuleCache \
    apps/ios/Along/Models.swift apps/ios/Along/OnboardingModel.swift \
    apps/ios/Along/PipProgression.swift apps/ios/Along/JournalBackup.swift \
    tests/ios/BackupTests.swift
}
compile_backup -D DEBUG -o .build/backup-tests-debug
.build/backup-tests-debug
compile_backup -o .build/backup-tests-release
.build/backup-tests-release
