#!/bin/sh

set -eu

ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
SETUP_SCRIPT="$ROOT/scripts/setup-keybinding"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/herdr-codex-resume-setup-test.XXXXXX")
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

mkdir -p "$TMP/bin"
ln -s "$ROOT/tests/fixtures/herdr" "$TMP/bin/herdr"

export PATH="$TMP/bin:/usr/bin:/bin"
export HERDR_ENV=1
export HERDR_WORKSPACE_ID=w1
export HERDR_TAB_ID=w1:t1
export HERDR_PANE_ID=w1:p1
export HERDR_SOCKET_PATH="$TMP/herdr.sock"
export HERDR_BIN_PATH="$TMP/bin/herdr"
export TEST_HERDR_LOG="$TMP/herdr.log"
export HERDR_CONFIG_PATH="$TMP/config.toml"
unset TEST_CONFIG_CHECK_FAIL TEST_RELOAD_FAIL

assert_contains() {
    grep -F -- "$2" "$1" >/dev/null 2>&1 || {
        printf 'expected %s to contain: %s\n' "$1" "$2" >&2
        exit 1
    }
}

assert_not_contains() {
    ! grep -F -- "$2" "$1" >/dev/null 2>&1 || {
        printf 'expected %s not to contain: %s\n' "$1" "$2" >&2
        exit 1
    }
}

: >"$TEST_HERDR_LOG"
setup_output=$(sh "$SETUP_SCRIPT")
printf '%s\n' "$setup_output" | grep -F 'installed keybinding' >/dev/null
assert_contains "$HERDR_CONFIG_PATH" 'key = "prefix+alt+r"'
assert_contains "$HERDR_CONFIG_PATH" 'command = "adam.herdr-codex-resume.open"'
assert_contains "$TEST_HERDR_LOG" 'config check'
assert_contains "$TEST_HERDR_LOG" 'server reload-config'

setup_output=$(sh "$SETUP_SCRIPT")
printf '%s\n' "$setup_output" | grep -F 'already configured' >/dev/null
[ "$(grep -Fc 'command = "adam.herdr-codex-resume.open"' "$HERDR_CONFIG_PATH")" -eq 1 ] || {
    printf 'setup duplicated the plugin keybinding\n' >&2
    exit 1
}

existing_config="$TMP/existing.toml"
printf 'onboarding = false\n' >"$existing_config"
export HERDR_CONFIG_PATH="$existing_config"
: >"$TEST_HERDR_LOG"
sh "$SETUP_SCRIPT" >"$TMP/existing.out"
assert_contains "$existing_config" 'onboarding = false'
backup_path=$(find "$TMP" -maxdepth 1 -type f -name 'existing.toml.herdr-codex-resume-backup.*' -print | head -n 1)
[ -n "$backup_path" ] || {
    printf 'setup did not create a config backup\n' >&2
    exit 1
}
assert_contains "$backup_path" 'onboarding = false'

bound_config="$TMP/bound.toml"
printf '%s\n' \
    '[[ keys . command ]]' \
    'key = "prefix+shift+r"' \
    'type = "plugin_action"' \
    'command = "adam.herdr-codex-resume.open"' >"$bound_config"
export HERDR_CONFIG_PATH="$bound_config"
: >"$TEST_HERDR_LOG"
sh "$SETUP_SCRIPT" >"$TMP/bound.out"
printf '%s\n' "$(cat "$TMP/bound.out")" | grep -F 'already configured' >/dev/null
[ "$(grep -Fc 'command = "adam.herdr-codex-resume.open"' "$bound_config")" -eq 1 ] || {
    printf 'setup changed an existing plugin keybinding\n' >&2
    exit 1
}
assert_not_contains "$TEST_HERDR_LOG" 'server reload-config'

conflict_config="$TMP/conflict.toml"
printf '%s\n' \
    '[[keys.command]]' \
    'key = "prefix+alt+r"' \
    'type = "shell"' \
    'command = "other-command"' >"$conflict_config"
cp "$conflict_config" "$TMP/conflict.before"
export HERDR_CONFIG_PATH="$conflict_config"
: >"$TEST_HERDR_LOG"
if sh "$SETUP_SCRIPT" >"$TMP/conflict.out" 2>"$TMP/conflict.err"; then
    printf 'setup unexpectedly replaced a conflicting keybinding\n' >&2
    exit 1
fi
assert_contains "$TMP/conflict.err" 'already used'
cmp -s "$conflict_config" "$TMP/conflict.before" || {
    printf 'setup changed the conflicting config\n' >&2
    exit 1
}
assert_not_contains "$TEST_HERDR_LOG" 'server reload-config'

combined_config="$TMP/combined.toml"
printf '%s\n' \
    '[[keys.command]]' \
    'key = "prefix+shift+r"' \
    'type = "plugin_action"' \
    'command = "adam.herdr-codex-resume.open"' \
    '' \
    '[[keys.command]]' \
    'key = "prefix+alt+r"' \
    'type = "shell"' \
    'command = "other-command"' >"$combined_config"
cp "$combined_config" "$TMP/combined.before"
export HERDR_CONFIG_PATH="$combined_config"
: >"$TEST_HERDR_LOG"
if sh "$SETUP_SCRIPT" >"$TMP/combined.out" 2>"$TMP/combined.err"; then
    printf 'setup unexpectedly ignored a conflicting default key\n' >&2
    exit 1
fi
assert_contains "$TMP/combined.err" 'already used'
cmp -s "$combined_config" "$TMP/combined.before" || {
    printf 'setup changed the combined config\n' >&2
    exit 1
}
assert_not_contains "$TEST_HERDR_LOG" 'server reload-config'

validation_config="$TMP/validation.toml"
printf 'onboarding = false\n' >"$validation_config"
export HERDR_CONFIG_PATH="$validation_config"
export TEST_CONFIG_CHECK_FAIL=1
: >"$TEST_HERDR_LOG"
if sh "$SETUP_SCRIPT" >"$TMP/validation.out" 2>"$TMP/validation.err"; then
    printf 'setup unexpectedly ignored config validation failure\n' >&2
    exit 1
fi
assert_contains "$TMP/validation.err" 'config check failed'
assert_contains "$validation_config" 'onboarding = false'
assert_not_contains "$validation_config" 'adam.herdr-codex-resume.open'
assert_not_contains "$TEST_HERDR_LOG" 'server reload-config'
unset TEST_CONFIG_CHECK_FAIL

rollback_config="$TMP/rollback.toml"
printf 'onboarding = false\n' >"$rollback_config"
cp "$rollback_config" "$TMP/rollback.before"
export HERDR_CONFIG_PATH="$rollback_config"
export TEST_RELOAD_FAIL=1
: >"$TEST_HERDR_LOG"
if sh "$SETUP_SCRIPT" >"$TMP/rollback.out" 2>"$TMP/rollback.err"; then
    printf 'setup unexpectedly ignored reload failure\n' >&2
    exit 1
fi
assert_contains "$TMP/rollback.err" 'reload failed'
cmp -s "$rollback_config" "$TMP/rollback.before" || {
    printf 'setup did not roll back after reload failure\n' >&2
    exit 1
}
unset TEST_RELOAD_FAIL

grep -F 'id = "setup-keybinding"' "$ROOT/herdr-plugin.toml" >/dev/null
