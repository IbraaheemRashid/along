#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/runtime.sh"
"$along_node_bin" --test tests/api/*.test.mjs tests/web/*.test.mjs
mkdir -p .build/ModuleCache
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc -D DEBUG -module-cache-path .build/ModuleCache apps/ios/Along/Models.swift apps/ios/Along/WeekSummary.swift apps/ios/Along/DayIdentity.swift apps/ios/Along/PipProgression.swift apps/ios/Along/JournalBackup.swift apps/ios/Along/OnboardingModel.swift apps/ios/Along/JournalStore.swift apps/ios/Along/API.swift tests/ios/CoreTests.swift -o .build/core-tests
.build/core-tests
bash scripts/check-billing.sh
bash scripts/check-reminders.sh
bash scripts/check-backup.sh
if [[ -f apps/web/node_modules/vite/bin/vite.js ]]; then
  (cd apps/web && "$along_node_bin" node_modules/vite/bin/vite.js build)
else
  echo "Web build skipped: install the locked apps/web dependencies first."
fi
