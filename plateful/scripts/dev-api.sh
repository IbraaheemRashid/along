#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/runtime.sh"
exec "$along_node_bin" apps/api/dev.mjs
