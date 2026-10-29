#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2016 # test helpers: &&/|| pairs and bash -c bodies are intentional
# Tests for cropshot and install.sh. Every external tool (grim, slurp,
# hyprctl, hyprpicker, wl-copy, notifier) is a stub, so this runs headless and
# never touches the real screen, clipboard or Hyprland config.

set -uo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/cropshot-test.XXXXXX")
trap 'rm -rf "$work"' EXIT

pass=0
fail=0

ok() {
  pass=$((pass + 1))
  echo "ok   $1"
}
not_ok() {
  fail=$((fail + 1))
  echo "FAIL $1"
  [[ -n ${2:-} ]] && echo "     $2"
}
check() {
  local name=$1
  shift
  if "$@"; then ok "$name"; else not_ok "$name" "command failed: $*"; fi
}

stubs="$work/stubs"
mkdir -p "$stubs"

stub() {
  cat >"$stubs/$1"
  chmod +x "$stubs/$1"
}

stub grim <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$STUB_LOG/grim.args"
printf 'PNGDATA' >"${@: -1}"
EOF

stub slurp <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$STUB_LOG/slurp.args"
cat >"$STUB_LOG/slurp.stdin"
[[ -n ${STUB_SLURP_CANCEL:-} ]] && exit 1
printf '%s\n' "${STUB_SLURP_OUT:-10,20 300x200}"
EOF

stub hyprpicker <<'EOF'
#!/usr/bin/env bash
echo $$ >"$STUB_LOG/hyprpicker.pid"
exec sleep 30
EOF

stub wl-copy <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$STUB_LOG/wl-copy.args"
cat >"$STUB_LOG/wl-copy.data"
EOF

stub omarchy-notification-send <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$STUB_LOG/notify.args"
EOF

stub pgrep <<'EOF'
#!/usr/bin/env bash
exit 1
EOF

stub date <<'EOF'
#!/usr/bin/env bash
if [[ ${1:-} == "+%Y-%m-%d_%H-%M-%S" && -n ${STUB_DATE:-} ]]; then
  echo "$STUB_DATE"
else
  exec /usr/bin/date "$@"
fi
EOF

stub hyprctl <<'EOF'
#!/usr/bin/env bash
case "$1" in
monitors)
  cat <<'JSON'
[{"name":"DP-1","x":0,"y":0,"width":3840,"height":2160,"scale":1.25,"transform":0,
  "activeWorkspace":{"id":1},"specialWorkspace":{"id":0}},
 {"name":"DP-2","x":3072,"y":324,"width":1920,"height":1080,"scale":1,"transform":0,
  "activeWorkspace":{"id":5},"specialWorkspace":{"id":0}}]
JSON
  ;;
clients)
  cat <<'JSON'
[{"at":[10,10],"size":[800,600],"workspace":{"id":1},"mapped":true,"hidden":false},
 {"at":[3100,400],"size":[640,480],"workspace":{"id":5},"mapped":true,"hidden":false},
 {"at":[50,50],"size":[100,100],"workspace":{"id":2},"mapped":true,"hidden":false},
 {"at":[60,60],"size":[100,100],"workspace":{"id":1},"mapped":true,"hidden":true}]
JSON
  ;;
cursorpos) echo "${STUB_CURSOR:-{\"x\": 3500, \"y\": 500\}}" ;;
reload) echo ok >>"$STUB_LOG/hyprctl.reload" ;;
configerrors) echo "" ;;
esac
EOF

# Run cropshot in an isolated HOME with the stubs first on PATH.
run() {
  STUB_LOG="$work/log" PATH="$stubs:$PATH" HOME="$work/home" \
    CROPSHOT_CONFIG="$work/home/.config/cropshot/config" \
    CROPSHOT_THEME_COLORS="$work/home/colors.toml" \
    CROPSHOT_FREEZE_DELAY=0 \
    "$repo/bin/cropshot" "$@"
}

reset() {
  rm -rf "${work:?}/log" "${work:?}/home"
  mkdir -p "$work/log" "$work/home"
  unset STUB_SLURP_CANCEL STUB_SLURP_OUT STUB_DATE STUB_CURSOR
}

shots() {
  find "$work/home/pics/screenshot" -type f -name '*.png' 2>/dev/null | LC_ALL=C sort
}

# --- region capture -------------------------------------------------------

reset
out=$(run region --print)
status=$?
check "region exits 0" test "$status" -eq 0
check "default dir is ~/pics/screenshot" test "$(dirname "$out")" = "$work/home/pics/screenshot"
[[ $(basename "$out") =~ ^Screenshot_[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}\.png$ ]] &&
  ok "filename is timestamped" || not_ok "filename is timestamped" "got $(basename "$out")"
check "file contains the capture" test "$(cat "$out")" = "PNGDATA"
check "grim got the slurp geometry" grep -qx -- "-g 10,20 300x200 .*" "$work/log/grim.args"
check "image copied to clipboard" grep -q -- "--type image/png" "$work/log/wl-copy.args"
check "notification shows the image" grep -qx -- "--image" "$work/log/notify.args"
check "notification passes the path to actions" grep -qx -- "$out" "$work/log/notify.args"
check "slurp shows dimensions" grep -q -- "-d" "$work/log/slurp.args"
check "no temp file left behind" test -z "$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'cropshot.*' -newer "$work/stubs/grim" 2>/dev/null)"

pid=$(cat "$work/log/hyprpicker.pid" 2>/dev/null)
if [[ -n $pid ]] && ! kill -0 "$pid" 2>/dev/null; then ok "freeze overlay stopped"; else not_ok "freeze overlay stopped" "pid $pid"; fi

# --- window boxes ---------------------------------------------------------

boxes=$(cat "$work/log/slurp.stdin")
expected=$'10,10 800x600\n3100,400 640x480'
check "boxes cover visible windows on active workspaces only" test "$boxes" = "$expected"

reset
run window >/dev/null
check "window mode restricts slurp to boxes" grep -q -- "-r" "$work/log/slurp.args"

# --- unique filenames -----------------------------------------------------

reset
export STUB_DATE="2026-10-29_14-03-22"
run >/dev/null && run >/dev/null && run >/dev/null
mapfile -t names < <(shots | xargs -n1 basename)
expected_names="Screenshot_2026-10-29_14-03-22.png Screenshot_2026-10-29_14-03-22_2.png Screenshot_2026-10-29_14-03-22_3.png"
check "same-second shots get unique names" test "${names[*]}" = "$expected_names"
unset STUB_DATE

# --- cancel ---------------------------------------------------------------

reset
STUB_SLURP_CANCEL=1 run >/dev/null 2>&1
status=$?
check "Esc exits 130" test "$status" -eq 130
check "Esc saves nothing" test -z "$(shots)"
check "Esc copies nothing" test ! -e "$work/log/wl-copy.args"
pid=$(cat "$work/log/hyprpicker.pid" 2>/dev/null)
if [[ -n $pid ]] && ! kill -0 "$pid" 2>/dev/null; then ok "freeze stopped on cancel"; else not_ok "freeze stopped on cancel" "pid $pid"; fi

reset
STUB_SLURP_OUT="100,100 0x0" run >/dev/null 2>&1
status=$?
check "bare click on empty space cancels" test "$status" -eq 130
check "bare click saves nothing" test -z "$(shots)"

# --- clipboard / copy / notify flags --------------------------------------

reset
run --clipboard >/dev/null
check "--clipboard saves nothing" test -z "$(shots)"
check "--clipboard copies the image" test "$(cat "$work/log/wl-copy.data")" = "PNGDATA"
check "--clipboard notifies without an image" bash -c '! grep -qx -- --image "$1"' _ "$work/log/notify.args"

reset
run --no-copy --no-notify >/dev/null
check "--no-copy skips the clipboard" test ! -e "$work/log/wl-copy.args"
check "--no-notify skips the notification" test ! -e "$work/log/notify.args"
check "--no-copy still saves" test -n "$(shots)"

reset
run --no-freeze >/dev/null
check "--no-freeze skips hyprpicker" test ! -e "$work/log/hyprpicker.pid"

# --- screen mode ----------------------------------------------------------

reset
run screen >/dev/null
check "screen mode captures monitor under cursor" grep -qx -- "-g 3072,324 1920x1080 .*" "$work/log/grim.args"
check "screen mode skips slurp" test ! -e "$work/log/slurp.args"

reset
STUB_CURSOR='{"x": 100, "y": 100}' run screen >/dev/null
check "screen mode uses logical size on scaled monitor" grep -qx -- "-g 0,0 3072x1728 .*" "$work/log/grim.args"

# --- settings precedence --------------------------------------------------

reset
mkdir -p "$work/home/.config/cropshot"
printf '# comment\ndir = "~/from-config"\ncopy=false\n' >"$work/home/.config/cropshot/config"
out=$(run --print)
check "config dir with ~ is honored" test "$(dirname "$out")" = "$work/home/from-config"
check "config copy=false is honored" test ! -e "$work/log/wl-copy.args"
out=$(CROPSHOT_DIR="$work/home/from-env" run --print)
check "env overrides config" test "$(dirname "$out")" = "$work/home/from-env"
out=$(CROPSHOT_DIR="$work/home/from-env" run --print --dir "$work/home/from-flag")
check "flag overrides env" test "$(dirname "$out")" = "$work/home/from-flag"

reset
printf 'accent = "#f38ba8"\n' >"$work/home/colors.toml"
run >/dev/null
check "selection uses the theme accent" grep -q -- "-c f38ba8ff" "$work/log/slurp.args"

# --- usage ----------------------------------------------------------------

reset
run --bogus >/dev/null 2>&1
check "unknown argument exits 2" test "$?" -eq 2
check "--help exits 0" run --help >/dev/null

# --- installer ------------------------------------------------------------

reset
bindings="$work/home/.config/hypr/bindings.lua"
mkdir -p "$(dirname "$bindings")"
printf -- '-- user bindings\no.bind("SUPER + B", "Browser", "chromium")\n' >"$bindings"
install_env=(env PATH="$stubs:$PATH" HOME="$work/home" CROPSHOT_NO_RELOAD=1
  CROPSHOT_BIN_DIR="$work/home/.local/bin" CROPSHOT_BINDINGS="$bindings")

"${install_env[@]}" "$repo/install.sh" >/dev/null
"${install_env[@]}" "$repo/install.sh" >/dev/null
check "installer links the command" test "$(readlink "$work/home/.local/bin/cropshot")" = "$repo/bin/cropshot"
check "installer creates the screenshot dir" test -d "$work/home/pics/screenshot"
check "installer is idempotent (one block)" test "$(grep -c '>>> cropshot >>>' "$bindings")" -eq 1
check "installer binds ALT+SHIFT+4" grep -q 'o.bind("ALT + SHIFT + 4", "Cropped screenshot"' "$bindings"
check "installer keeps user bindings" grep -q 'SUPER + B' "$bindings"

if command -v luac >/dev/null; then
  check "bindings file is valid Lua" luac -p "$bindings"
fi

"${install_env[@]}" "$repo/install.sh" --uninstall >/dev/null
check "uninstall removes the link" test ! -e "$work/home/.local/bin/cropshot"
check "uninstall removes the block" bash -c '! grep -q cropshot "$1"' _ "$bindings"
check "uninstall keeps user bindings" grep -q 'SUPER + B' "$bindings"

# --- shell plugin ---------------------------------------------------------

manifest="$repo/manifest.json"
check "manifest is valid JSON" jq empty "$manifest"
check "manifest version matches the command" \
  test "$(jq -r .version "$manifest")" = "$(run --version | awk '{print $2}')"
check "bar widget moduleName matches the plugin id" \
  grep -q "moduleName: \"$(jq -r .id "$manifest")\"" "$repo/BarWidget.qml"
for method in region window screen clipboard; do
  check "service exposes cropshot.$method" grep -q "function $method(): void" "$repo/Service.qml"
done
check "no symlinks in the plugin folder" test -z "$(find "$repo" -name .git -prune -o -type l -print)"
if command -v omarchy-plugin-validate >/dev/null; then
  check "omarchy plugin validate passes" omarchy-plugin-validate "$repo"
fi

echo
echo "$pass passed, $fail failed"
((fail == 0))
