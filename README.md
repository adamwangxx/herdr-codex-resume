# Herdr Codex Resume

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
```

Add a keybinding to `~/.config/herdr/config.toml`:

```toml
[[keys.command]]
key = "prefix+alt+r"
type = "plugin_action"
command = "adam.herdr-codex-resume.open"
description = "open Codex resume picker in a new split"
```

Then reload Herdr:

```sh
herdr server reload-config
```

Install directly from GitHub on another machine:

```sh
herdr plugin install adamwangxx/herdr-codex-resume
```

The keybinding remains a per-machine Herdr setting because plugin manifest v1
does not install default keys.

## Safety model

Before starting Codex, the plugin requires `HERDR_ENV=1` and all injected
workspace, tab, pane, and socket identifiers. It also asks the running Herdr
server to resolve the pane, so stale context fails closed. The picker refuses
to start if the new pane inherited a `CODEX_THREAD_ID`.

The plugin has no background process, transcript index, network request, or
build step. It only calls the local `herdr`, `jq`, and `codex` executables.

## Test

```sh
sh tests/run.sh
```
