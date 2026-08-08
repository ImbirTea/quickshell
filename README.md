# Minimal Quickshell shell

A small, intentionally focused [Quickshell](https://quickshell.outfoxxed.me/) configuration.

It currently provides a top bar and a minimal application launcher. Other
surfaces—such as a notification centre, widgets, and additional popups—are
deliberately left out.

## Included

- Hyprland workspaces;
- clock and system tray;
- current keyboard layout;
- PipeWire volume control: scroll to adjust volume, right-click to mute;
- application launcher: searches installed `.desktop` entries and supports
  keyboard navigation, mouse selection, and Enter to launch.

## Requirements

- [Quickshell](https://quickshell.outfoxxed.me/)
- [Hyprland](https://hyprland.org/)
- [Rust](https://www.rust-lang.org/tools/install) (`cargo`)—only needed to
  build `list-applications`, the helper the launcher shells out to for its
  application index. Nothing else in this repo needs compiling.

## Setup

1. Clone this repository to `~/.config/quickshell` or a path of your choice.
2. Build the launcher helper:

   ```bash
   make build
   ```

3. Run:

   ```bash
   quickshell -p /path/to/shell.qml
   ```

   If you used the default path, running `quickshell` is enough.

## Application launcher

Open or close the launcher with:

```bash
quickshell ipc call launcher toggle
```

For Hyprland, add a binding such as `Super + Space` to its configuration:

```lua
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("qs ipc call launcher toggle"))
```

The launcher opens on the focused monitor.

After installing or removing applications, refresh the launcher's index
without reloading the shell:

```bash
quickshell ipc call launcher reload
```

This only re-scans `.desktop` entries—it does not rebuild the helper. If
`modules/launcher/list-applications` itself changes, run `make build` again.

