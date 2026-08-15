#!/bin/sh

set -eu

ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
SCRIPT="$ROOT/scripts/herdr-codex-resume"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/herdr-codex-resume-test.XXXXXX")
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

mkdir -p "$TMP/bin"
ln -s "$ROOT/tests/fixtures/herdr" "$TMP/bin/herdr"
ln -s "$ROOT/tests/fixtures/codex" "$TMP/bin/codex"

export PATH="$TMP/bin:/usr/bin:/bin"
export HERDR_ENV=1
export HERDR_WORKSPACE_ID=w1
export HERDR_TAB_ID=w1:t1
export HERDR_PANE_ID=w1:p1
export HERDR_SOCKET_PATH="$TMP/herdr.sock"
export HERDR_BIN_PATH="$TMP/bin/herdr"
export TEST_HERDR_LOG="$TMP/herdr.log"
export TEST_PANE_CWD="/tmp/project with spaces"
export TEST_PANE_WIDTH=140
unset CODEX_THREAD_ID

assert_contains() {
    grep -F -- "$2" "$1" >/dev/null 2>&1 || {
        printf 'expected %s to contain: %s\n' "$1" "$2" >&2
        exit 1
    }
}

: >"$TEST_HERDR_LOG"
open_output=$(sh "$SCRIPT" open)
printf '%s\n' "$open_output" | grep -F 'right split' >/dev/null
assert_contains "$TEST_HERDR_LOG" \
    'pane split --pane w1:p1 --direction right --cwd /tmp/project with spaces --focus'
assert_contains "$TEST_HERDR_LOG" 'pane run w1:p2 sh '
assert_contains "$TEST_HERDR_LOG" ' picker'

: >"$TEST_HERDR_LOG"
export TEST_PANE_WIDTH=80
open_output=$(sh "$SCRIPT" open)
printf '%s\n' "$open_output" | grep -F 'down split' >/dev/null
assert_contains "$TEST_HERDR_LOG" \
    'pane split --pane w1:p1 --direction down --cwd /tmp/project with spaces --focus'

: >"$TEST_HERDR_LOG"
export HERDR_PANE_ID=w1:p2
picker_output=$(sh "$SCRIPT" picker)
[ "$picker_output" = 'codex args: resume' ] || {
    printf 'unexpected picker output: %s\n' "$picker_output" >&2
    exit 1
}
assert_contains "$TEST_HERDR_LOG" 'pane current --pane w1:p2'

check_output=$(sh "$SCRIPT" check)
printf '%s\n' "$check_output" | grep -F 'resume_guard=ready' >/dev/null

if CODEX_THREAD_ID=019-test sh "$SCRIPT" picker >"$TMP/nested.out" 2>"$TMP/nested.err"; then
    printf 'picker unexpectedly allowed a nested Codex resume\n' >&2
    exit 1
fi
assert_contains "$TMP/nested.err" 'refusing an unsafe nested resume'

sh "$ROOT/tests/setup-keybinding.sh"

printf 'all tests passed\n'
