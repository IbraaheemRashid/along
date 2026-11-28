#!/usr/bin/env bash
set -euo pipefail
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
cd "$(dirname "$0")/.."
mkdir -p .build/ModuleCache
compile_backup() {
  xcrun swiftc "$@" \
    -module-cache-path .build/ModuleCache \
    apps/ios/Along/Models.swift apps/ios/Along/DayIdentity.swift apps/ios/Along/OnboardingModel.swift apps/ios/Along/SetupModel.swift apps/ios/Along/ProtocolModel.swift apps/ios/Along/InjectionSpot.swift \
    apps/ios/Along/PipProgression.swift apps/ios/Along/JournalBackup.swift \
    tests/ios/BackupTests.swift
}
compile_backup -D DEBUG -o .build/backup-tests-debug
.build/backup-tests-debug
compile_backup -o .build/backup-tests-release
.build/backup-tests-release

xcrun swiftc -D DEBUG -module-cache-path .build/ModuleCache \
  apps/ios/Along/Models.swift apps/ios/Along/OnboardingModel.swift apps/ios/Along/SetupModel.swift apps/ios/Along/ProtocolModel.swift apps/ios/Along/InjectionSpot.swift apps/ios/Along/PipProgression.swift \
  apps/ios/Along/DayIdentity.swift apps/ios/Along/JournalBackup.swift tests/ios/DayIdentityTests.swift -o .build/day-identity-tests
.build/day-identity-tests
