#!/usr/bin/env bash
set -euo pipefail
along_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
along_node_bin="$(command -v node || true)"
if [[ -z "$along_node_bin" ]]; then
  along_node_bin="$HOME/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node"
fi
if [[ ! -x "$along_node_bin" ]]; then
  echo "Node 22.18+ is required. Install Node or add it to PATH." >&2
  exit 1
fi
export PATH="$(dirname "$along_node_bin"):$PATH"
cd "$along_root"
