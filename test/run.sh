#!/usr/bin/env bash
# Usage: test/run.sh [filter]   (or TEST_FILTER=<filter> test/run.sh)
#   filter: case-insensitive pattern matched against test file names
# Env:    TEST_TIMEOUT  seconds before a hung run is killed (default 300)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export TEST_FILTER="${1:-${TEST_FILTER:-}}"
export TEST_REPORT_FILE="$(mktemp)"
VIM_LOG="$(mktemp)"
trap 'rm -f "${TEST_REPORT_FILE}" "${VIM_LOG}"' EXIT

# A test waiting for input would otherwise hang the run (and CI) forever
TIMEOUT=()
if command -v timeout >/dev/null 2>&1; then
    TIMEOUT=(timeout "${TEST_TIMEOUT:-300}")
fi

set +e
"${TIMEOUT[@]}" vim --clean -n --not-a-term --cmd "set encoding=utf-8" \
    -S "${SCRIPT_DIR}/runner.vim" </dev/null >"${VIM_LOG}" 2>&1
exit_code=$?
set -e

cat "${TEST_REPORT_FILE}"

# No summary means Vim died, hung or the runner itself broke: show why
if ! grep -q '^Summary:' "${TEST_REPORT_FILE}"; then
    if [ "${exit_code}" -eq 124 ]; then
        echo "ERROR: test run timed out after ${TEST_TIMEOUT:-300}s"
    else
        echo "ERROR: test run did not finish (vim exit code ${exit_code})"
    fi
    echo "---- last vim output ----"
    # Strip terminal escape sequences so the log is readable
    tail -c 4000 "${VIM_LOG}" | sed -e 's/\x1b\[[0-9;?<>=]*[a-zA-Z]//g' | tr -d '\r' | tail -n 40
    [ "${exit_code}" -eq 0 ] && exit_code=1
fi

exit "${exit_code}"
