#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export TEST_FILTER="${1:-}"
export TEST_REPORT_FILE="$(mktemp)"
trap 'rm -f "${TEST_REPORT_FILE}"' EXIT

set +e
vim --clean -n --not-a-term -S "${SCRIPT_DIR}/runner.vim" >/dev/null 2>&1
exit_code=$?
set -e

cat "${TEST_REPORT_FILE}"
exit "${exit_code}"
