#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/runtime.sh"
"$along_node_bin" --test tests/api/*.test.mjs tests/web/*.test.mjs
mkdir -p .build/ModuleCache
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc -module-cache-path .build/ModuleCache apps/ios/Along/Models.swift tests/ios/CoreTests.swift -o .build/core-tests
.build/core-tests
if [[ -f apps/web/node_modules/vite/bin/vite.js ]]; then
  (cd apps/web && "$along_node_bin" node_modules/vite/bin/vite.js build)
else
  echo "Web build skipped: install the locked apps/web dependencies first."
fi
