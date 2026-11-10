#!/usr/bin/env bash
# Start Vim with the plugin loaded the normal way (from 'runtimepath') and
# check what a user would see.
#   test/check_startup.sh                  supported Vim: commands defined, no errors
#   test/check_startup.sh --expect-guard   too-old Vim: one warning, no errors
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECT_GUARD=0
[ "${1:-}" = "--expect-guard" ] && EXPECT_GUARD=1

OUT="$(mktemp)"
REPORT_VIM="$(mktemp --suffix=.vim 2>/dev/null || mktemp)"
trap 'rm -f "${OUT}" "${REPORT_VIM}"' EXIT

# Report once startup is completely done (SafeState fires after all
# VimEnter autocmds; the plugin shows its version warning on VimEnter).
# Legacy script on one line: it is sourced by --cmd, before 'nocompatible'
# is set, so line continuation is not available yet.
cat > "${REPORT_VIM}" <<'VIM'
autocmd SafeState * ++once call writefile(split(execute('messages'), "\n") + ['commands: ' . exists(':ListFind') . exists(':ListPath') . exists(':ListQuickfix')], $REPORT_OUT) | qall!
VIM

# Run Vim on a pseudo-terminal (script from util-linux): without a real
# terminal Vim stops before VimEnter, so a user's startup isn't reproduced.
# --clean disables plugin loading; turn it back on to load like a user does.
VIM_CMD="$(printf '%q ' vim --clean -n --cmd "set encoding=utf-8" \
    --cmd "set runtimepath^=${ROOT_DIR}" --cmd "set loadplugins" \
    --cmd "source ${REPORT_VIM}")"
# stdin stays open (but idle) so script does not end the session on EOF
REPORT_OUT="${OUT}" timeout 60 script -qec "${VIM_CMD}" /dev/null \
    < <(sleep 60) >/dev/null 2>&1 || true

echo "---- $(vim --version | head -n 1)"
cat "${OUT}"
echo "----"

fail() { echo "FAIL: $*"; exit 1; }

[ -s "${OUT}" ] || fail "Vim produced no report"
if grep -qE 'E[0-9]+:' "${OUT}"; then
    fail "errors at startup"
fi
if [ "${EXPECT_GUARD}" -eq 1 ]; then
    grep -q 'consistent_popup.vim: requires Vim 9.1+' "${OUT}" || fail "expected the version warning"
    grep -q '^commands: 000$' "${OUT}" || fail "commands must not be defined on an unsupported Vim"
else
    grep -q 'requires Vim 9.1+' "${OUT}" && fail "unexpected version warning"
    grep -q '^commands: 222$' "${OUT}" || fail "commands are not defined"
fi
echo "OK"
