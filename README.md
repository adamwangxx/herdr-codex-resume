# Herdr Codex Resume

[![CI](https://github.com/adamwangxx/herdr-codex-resume/actions/workflows/ci.yml/badge.svg)](https://github.com/adamwangxx/herdr-codex-resume/actions/workflows/ci.yml)

A small Herdr plugin that opens the native `codex resume` picker in a new,
Herdr-managed split.

The action preserves the focused pane's working directory, chooses a right
split when the pane is at least 120 columns wide and a down split otherwise,
focuses the new pane, and leaves its shell available after Codex exits.

## Requirements

- Herdr 0.8.0 or newer
- Codex CLI on `PATH`
- `jq`
- macOS or Linux

## Install from a checkout

```sh
herdr plugin link "$PWD"
herdr plugin action invoke adam.herdr-codex-resume.setup-keybinding
```

The setup action adds the recommended `prefix+alt+r` binding to the active Herdr
config and reloads Herdr. The resulting TOML entry is:

```toml
[[keys.command]]
key = "prefix+alt+r"
type = "plugin_action"
command = "adam.herdr-codex-resume.open"
description = "open Codex resume picker in a new split"
```

The action is safe to run more than once. It keeps an existing binding for this
plugin unchanged, refuses to replace another command using `prefix+alt+r`, and
creates a backup before changing an existing config. If the reload fails, it
restores the previous file.

Install directly from GitHub on another machine:

```sh
herdr plugin install adamwangxx/herdr-codex-resume
herdr plugin action invoke adam.herdr-codex-resume.setup-keybinding
```

The keybinding remains a per-machine Herdr setting. Plugin manifest v1 does not
install default keys automatically, so the setup action is an explicit step
after linking or installing the plugin.

## Safety model

Before starting Codex, the plugin requires `HERDR_ENV=1` and all injected
workspace, tab, pane, and socket identifiers. It also asks the running Herdr
server to resolve the pane, so stale context fails closed. The picker refuses
to start if the new pane inherited a `CODEX_THREAD_ID`.

The plugin has no background process, transcript index, network request, or
build step. The resume action only calls local `herdr`, `jq`, and `codex`; the
setup action uses Herdr plus standard POSIX file and text utilities.

## Test

```sh
sh tests/run.sh
```
