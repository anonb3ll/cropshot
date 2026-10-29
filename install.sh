#!/usr/bin/env bash
# Install cropshot: link the command into ~/.local/bin and add Hyprland
# keybindings to ~/.config/hypr/bindings.lua inside a marked block.
#
#   ./install.sh               install with the default keys
#   ./install.sh --no-bind     install the command only
#   ./install.sh --uninstall   remove the link and the keybinding block
#
# Default keys (ALT sits where Cmd does on a PC keyboard; SUPER+SHIFT+4 is
# Omarchy's "move window to workspace 4"):
#   ALT+SHIFT+4        region or window, saved      (Cmd+Shift+4)
#   ALT+CTRL+SHIFT+4   region or window, clipboard  (Ctrl+Cmd+Shift+4)
#   ALT+SHIFT+3        whole monitor, saved         (Cmd+Shift+3)
# Override with CROPSHOT_KEY_REGION, CROPSHOT_KEY_CLIPBOARD, CROPSHOT_KEY_SCREEN.

set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
bin_dir=${CROPSHOT_BIN_DIR:-$HOME/.local/bin}
bindings=${CROPSHOT_BINDINGS:-${XDG_CONFIG_HOME:-$HOME/.config}/hypr/bindings.lua}
shot_dir=${CROPSHOT_DIR:-$HOME/pics/screenshot}
key_region=${CROPSHOT_KEY_REGION:-ALT + SHIFT + 4}
key_clip=${CROPSHOT_KEY_CLIPBOARD:-ALT + CTRL + SHIFT + 4}
key_screen=${CROPSHOT_KEY_SCREEN:-ALT + SHIFT + 3}

readonly begin_marker="-- >>> cropshot >>>"
readonly end_marker="-- <<< cropshot <<<"

bind=1
uninstall=0
for arg in "$@"; do
  case $arg in
  --no-bind) bind=0 ;;
  --uninstall) uninstall=1 ;;
  -h | --help)
    sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  *)
    echo "install.sh: unknown argument: $arg" >&2
    exit 2
    ;;
  esac
done

# Drop any existing cropshot block from the bindings file (keeps a backup).
strip_block() {
  [[ -f $bindings ]] || return 0
  grep -qF -- "$begin_marker" "$bindings" || return 0
  cp "$bindings" "$bindings.bak.cropshot.$(date +%s)"
  awk -v b="$begin_marker" -v e="$end_marker" '
    $0 == b { skip = 1; next }
    $0 == e { skip = 0; next }
    !skip
  ' "$bindings" >"$bindings.tmp"
  mv "$bindings.tmp" "$bindings"
}

reload_hyprland() {
  command -v hyprctl >/dev/null || return 0
  [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] || return 0
  [[ -n ${CROPSHOT_NO_RELOAD:-} ]] && return 0
  hyprctl reload >/dev/null
  local errors
  errors=$(hyprctl configerrors 2>/dev/null || true)
  if [[ -n ${errors//[[:space:]]/} ]]; then
    echo "Hyprland reported config errors:" >&2
    echo "$errors" >&2
    return 1
  fi
}

if ((uninstall)); then
  if [[ -L $bin_dir/cropshot ]]; then
    rm "$bin_dir/cropshot"
  fi
  strip_block
  reload_hyprland
  echo "cropshot uninstalled (screenshots in $shot_dir were kept)"
  exit 0
fi

for dep in grim slurp hyprctl jq wl-copy hyprpicker; do
  command -v "$dep" >/dev/null || echo "warning: $dep not found; install it with: omarchy pkg add $dep" >&2
done

chmod +x "$repo/bin/cropshot"
mkdir -p "$bin_dir" "$shot_dir"
ln -sfn "$repo/bin/cropshot" "$bin_dir/cropshot"
echo "linked $bin_dir/cropshot -> $repo/bin/cropshot"

if ((bind)); then
  mkdir -p "$(dirname "$bindings")"
  touch "$bindings"
  strip_block
  cmd="$bin_dir/cropshot"
  {
    echo "$begin_marker"
    echo "-- macOS-style screenshots (managed by $repo/install.sh)"
    echo "o.bind(\"$key_region\", \"Cropped screenshot\", \"$cmd region\")"
    echo "o.bind(\"$key_clip\", \"Cropped screenshot to clipboard\", \"$cmd region --clipboard\")"
    echo "o.bind(\"$key_screen\", \"Screenshot of monitor\", \"$cmd screen\")"
    echo "$end_marker"
  } >>"$bindings"
  echo "added keybindings to $bindings: $key_region, $key_clip, $key_screen"
  reload_hyprland
fi

echo "screenshots save to $shot_dir"
