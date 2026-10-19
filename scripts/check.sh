#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
export PATH="$PWD/.tools/bin:/workspace/.roblox-tools/bin:$PATH"
python3 scripts/check.py
