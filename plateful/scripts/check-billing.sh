#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/ModuleCache
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcrun swiftc -module-cache-path .build/ModuleCache \
  apps/ios/Along/BillingConfiguration.swift apps/ios/Along/BillingPolicy.swift \
  tests/ios/billing/BillingTests.swift -o .build/billing-tests
.build/billing-tests
