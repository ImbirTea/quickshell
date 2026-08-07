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

## Application launcher

Open or close the launcher with:

```bash
quickshell ipc call launcher toggle
```

For Hyprland, add a binding such as `Super + Space` to its configuration:

```ini
bind = SUPER, SPACE, exec, quickshell ipc call launcher toggle
```

The launcher opens on the focused monitor. After installing or removing
applications, refresh its index without reloading the shell:

```bash
quickshell ipc call launcher reload
```

## Running

Place this directory at `~/.config/quickshell`, then run:

```bash
quickshell -p ~/.config/quickshell
```

If Quickshell already uses this configuration path, `quickshell` is enough.

Future ideas are collected in [TODO.md](TODO.md).
