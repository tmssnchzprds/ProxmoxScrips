#!/usr/bin/env bash
# Wrapper to run the Python dedupe script
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PY="$(command -v python3 || command -v python)"
if [ -z "$PY" ]; then
  echo "Python3 not found; install python3 to run this script." >&2
  exit 2
fi
"$PY" "$ROOT_DIR/tools/fix_catalog_arch_duplicates.py" "$ROOT_DIR/catalog/apps.json"
echo "Done. Review catalog/apps.json and commit if it looks good." 
