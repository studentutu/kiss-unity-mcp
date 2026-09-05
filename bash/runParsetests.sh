#!/usr/bin/env bash
# Compatibility entry point; CI/bash is authoritative.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
exec bash "$SCRIPT_DIR/../CI/bash/runParsetests.sh" "$@"
