# Cropshot

macOS-style screenshots for [Omarchy](https://omarchy.org) (Hyprland).
Press a key, drag a box, and you get a timestamped PNG in `~/pics/screenshot/`.

Cropshot is an Omarchy shell plugin. It adds a camera button to the bar and a
`cropshot` IPC target for keybindings. It also ships a standalone `cropshot`
command, so you can use it without the shell.

| Key (suggested) | Does | macOS equivalent |
|---|---|---|
| `ALT + SHIFT + 4` | Drag a region, or click a window. Saves and copies it. | `Cmd + Shift + 4` |
| `ALT + CTRL + SHIFT + 4` | Same selection, clipboard only | `Ctrl + Cmd + Shift + 4` |
| `ALT + SHIFT + 3` | The monitor under the cursor | `Cmd + Shift + 3` |

On a PC keyboard, `ALT` sits where `Cmd` sits on a Mac. Omarchy already uses
`SUPER + SHIFT + 4` to move a window to workspace 4, so cropshot leaves that
key alone.

While you select:

- The screen freezes, so menus and hover states stay as you saw them.
- A live `W×H` readout follows the selection, outlined in your theme's accent color.
- Clicking a window captures exactly that window. Dragging captures a region.
- `Esc` cancels. A click on empty desktop also cancels.

After the capture, a notification shows a thumbnail with **Open**, **Edit**
(Omarchy's omasnap annotator) and **Show in folder** buttons.

Files are named `Screenshot_2026-10-29_14-03-22.png`. Two shots in the same
second become `…_2.png`, `…_3.png`, so nothing is ever overwritten. Shots on
a scaled (HiDPI) monitor keep the monitor's full native resolution.

## Install

### As an Omarchy plugin

```bash
omarchy plugin add https://github.com/anonb3ll/cropshot --enable
```

This clones the plugin into `~/.config/omarchy/plugins/io.github.anonb3ll.cropshot/`,
starts its service and puts the bar button in the bar. Bar button actions:
left-click for a region, right-click for the monitor, middle-click to copy only.

The plugin never edits your configuration on its own. To get the keyboard
shortcuts, choose one of the following.

**Add the lines yourself** to `~/.config/hypr/bindings.lua`:

```lua
o.bind("ALT + SHIFT + 4", "Cropped screenshot", { ipc = "cropshot.region" })
o.bind("ALT + CTRL + SHIFT + 4", "Cropped screenshot to clipboard", { ipc = "cropshot.clipboard" })
o.bind("ALT + SHIFT + 3", "Screenshot of monitor", { ipc = "cropshot.screen" })
```

**Or let the installer add them**, in a marked block with a backup of your file:

```bash
~/.config/omarchy/plugins/io.github.anonb3ll.cropshot/install.sh
```

The IPC methods are `region`, `window`, `screen` and `clipboard`. Test one from
a terminal with `omarchy-shell cropshot region`.

### Standalone, without the shell plugin

```bash
git clone https://github.com/anonb3ll/cropshot ~/dev/cropshot
~/dev/cropshot/install.sh
```

The installer:

1. Links `~/.local/bin/cropshot` to `bin/cropshot`.
2. Creates `~/pics/screenshot/`.
3. Adds a marked `-- >>> cropshot >>>` block to `~/.config/hypr/bindings.lua`, keeping a backup.
4. Reloads Hyprland and checks `hyprctl configerrors`.

Running it again is safe, because it replaces its own block. Other options:

```bash
./install.sh --no-bind      # command only, no keybindings
CROPSHOT_KEY_REGION="SUPER + SHIFT + 4" ./install.sh   # pick your own keys
```

If you bind `SUPER + SHIFT + 4`, also add `hl.unbind("SUPER + SHIFT + 4")`
above the binding. Otherwise both actions fire.

## Remove

```bash
# If you ran install.sh: remove the command link and the keybinding block
~/.config/omarchy/plugins/io.github.anonb3ll.cropshot/install.sh --uninstall

# Remove the plugin
omarchy plugin remove io.github.anonb3ll.cropshot
```

If you added the `o.bind` lines by hand, delete them from
`~/.config/hypr/bindings.lua`. Removal keeps your screenshots.

## Dependencies

All of these ship with Omarchy: `grim`, `slurp`, `hyprctl`, `jq`, `wl-copy`,
`hyprpicker` (for the screen freeze), `omarchy-notification-send`, plus
`xdg-open`, `nautilus` and `omasnap` for the notification buttons. If one is
missing, install it with `omarchy pkg add <name>`.

## Use the command directly

```text
cropshot [region|window|screen] [options]

  -d, --dir DIR     Save directory (default: ~/pics/screenshot)
  -c, --clipboard   Copy only, do not save
      --no-copy     Save without copying
      --no-notify   No notification
      --no-freeze   Do not freeze the screen while selecting
  -p, --print       Print the saved path (handy in scripts)
```

Exit codes: `0` saved or copied, `1` capture failed, `2` usage error,
`130` cancelled.

## Configure

Copy `examples/config` to `~/.config/cropshot/config`. It holds `dir`, `copy`,
`notify` and `freeze` as `KEY=value` lines. The file is parsed as data and
never sourced. Settings resolve in this order: flags, then the
`CROPSHOT_DIR` / `CROPSHOT_COPY` / `CROPSHOT_NOTIFY` / `CROPSHOT_FREEZE`
environment variables, then the config file.

## Test

```bash
tests/run.sh
```

The suite stubs every external tool, so it runs headless and never touches
your screen, clipboard or Hyprland config. When `omarchy` is installed, it
also validates the plugin manifest.

## License

[MIT](LICENSE)
