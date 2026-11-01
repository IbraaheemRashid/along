#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/runtime.sh"
cd apps/web
exec "$along_node_bin" node_modules/vite/bin/vite.js --host 127.0.0.1
