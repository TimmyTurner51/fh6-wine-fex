#!/usr/bin/env bash
#
# install.sh — drop the prebuilt ARM64EC FEX into a DroidDeck guest.
#
# What it does:
#   1. Finds the connected Android device (adb), so it works on any device.
#   2. Pushes bin/libarm64ecfex.dll to the device's Download folder.
#   3. Runs a small Python snippet *inside* the DroidDeck guest that backs up
#      and replaces the FEX binary in your Proton tool (and in the game prefix
#      system32 when that copy is a real file rather than a symlink to the tool).
#   4. Prints the sha256 of what was installed so you can confirm it against the
#      expected build (sha8 67dc9fda).
#
# Requires:
#   - adb on PATH (USB debugging, or Wireless debugging already paired).
#   - A way to run a command inside the guest. Auto-detected in this order:
#       1. --guest-command   (fully custom, e.g. GameNative's CLI)
#       2. --ctl PATH        (path to DroidDeck's droiddeckctl)
#       3. droiddeckctl on PATH
#     If none is available, it prints the exact steps to do by hand.
#
# Works under Linux, macOS, WSL, and Git Bash on Windows.
#
# Paths under /root/.local/share/... are DroidDeck's *guest* filesystem, so they
# are the same on every device. The only per-device value is the adb serial,
# which is auto-detected.
set -euo pipefail

APPID="${FH6_APPID:-2483190}"          # Steam AppID for Forza Horizon 6
TOOL="${FH6_TOOL:-auto}"               # Proton tool name; "auto" finds it
SERIAL="${ANDROID_SERIAL:-}"           # adb serial; auto-detected if empty
CTL=""                                  # explicit path to droiddeckctl
GUEST_CMD=""                            # custom guest runner (reads script on stdin)

usage() {
  cat <<'EOF'
Usage:
  ./install.sh [--serial SERIAL] [--tool NAME] [--appid 2483190]
               [--ctl PATH] [--guest-command 'CMD']

Options:
  --serial SERIAL       adb device serial (auto-detected if omitted)
  --tool NAME           Proton tool name under compatibilitytools.d (default: auto)
  --appid ID            Steam AppID of the game (default: 2483190)
  --ctl PATH            path to DroidDeck's droiddeckctl
  --guest-command CMD   custom command that runs the in-guest script from stdin
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --serial) SERIAL="$2"; shift 2;;
    --tool)   TOOL="$2"; shift 2;;
    --appid)  APPID="$2"; shift 2;;
    --ctl)    CTL="$2"; shift 2;;
    --guest-command) GUEST_CMD="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2;;
  esac
done

case "$TOOL$APPID" in
  *"'"*) echo "tool/appid must not contain a single quote" >&2; exit 2;;
esac

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DLL="$HERE/bin/libarm64ecfex.dll"
[ -f "$DLL" ] || { echo "missing $DLL (run from the repo root)" >&2; exit 1; }

# ---- 1. device -------------------------------------------------------------
if [ -z "$SERIAL" ]; then
  SERIAL="$(adb devices 2>/dev/null | awk 'NR>1 && $2=="device" {print $1; exit}')"
fi
[ -n "$SERIAL" ] || { echo "no adb device online; connect one or pass --serial" >&2; exit 1; }
echo "device: $SERIAL"

# ---- 2. push ---------------------------------------------------------------
DL="/storage/emulated/0/Download"
echo "pushing $DLL -> $DL/libarm64ecfex.dll"
adb -s "$SERIAL" push "$DLL" "$DL/libarm64ecfex.dll" >/dev/null

# ---- 3. in-guest install ---------------------------------------------------
PROG="$(mktemp)"
COMBINED="$(mktemp)"
trap 'rm -f "$PROG" "$COMBINED"' EXIT
cat > "$PROG" <<'PY'
import hashlib, os, shutil, sys

steam = "/root/.local/share/Steam"
tools_dir = os.path.join(steam, "compatibilitytools.d")
src = "/storage/emulated/0/Download/libarm64ecfex.dll"

def sha(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()[:8]

if not os.path.isfile(src):
    sys.exit("missing " + src)

t = tool
if t == "auto":
    hits = []
    for name in sorted(os.listdir(tools_dir)):
        dll = os.path.join(tools_dir, name, "files/lib/wine/aarch64-windows/libarm64ecfex.dll")
        if os.path.isfile(dll):
            hits.append(name)
    if not hits:
        sys.exit("no Proton tool under " + tools_dir + " has libarm64ecfex.dll; rerun with --tool <name>")
    if len(hits) > 1:
        print("multiple tools found:", ", ".join(hits))
        sys.exit("rerun with --tool <name>")
    t = hits[0]

target = os.path.join(tools_dir, t, "files/lib/wine/aarch64-windows/libarm64ecfex.dll")
if not os.path.isfile(target):
    sys.exit("no FEX binary at " + target)

def install(dst):
    if os.path.islink(dst):
        print("skip (symlink to tool copy):", dst, "->", os.readlink(dst))
        return
    bak = dst + ".fh6-bak"
    if not os.path.isfile(bak):
        shutil.copyfile(dst, bak)
        print("backup:", bak)
    shutil.copyfile(src, dst)
    print("installed", sha(dst), dst)

print("tool:", t)
print("before:", sha(target), target)
install(target)

pfx = os.path.join(steam, "steamapps/compatdata", appid,
                   "pfx/drive_c/windows/system32/libarm64ecfex.dll")
if os.path.isfile(pfx):
    install(pfx)
print("done")
PY

setup="$(printf 'tool = %s\nappid = %s\n' "'$TOOL'" "'$APPID'")"
printf '%s%s' "$setup" "$(cat "$PROG")" > "$COMBINED"

if [ -n "$GUEST_CMD" ]; then
  sh -c "$GUEST_CMD" < "$COMBINED"
elif [ -n "$CTL" ] || command -v droiddeckctl >/dev/null 2>&1; then
  CTL="${CTL:-droiddeckctl}"
  echo "installing via $CTL"
  DROIDDECK_PACKAGE="${DROIDDECK_PACKAGE:-com.antutu.benchmark.full}" \
    "$CTL" guest --timeout 120 --stdin "$(cat "$COMBINED")" -- python3
else
  echo
  echo "Pushed bin/libarm64ecfex.dll to the device, but no guest runner found."
  echo "Finish by hand (see IMPORT.md), replacing the FEX binary at:"
  echo "  <tool>/files/lib/wine/aarch64-windows/libarm64ecfex.dll"
  echo "  (and <prefix>/drive_c/windows/system32/libarm64ecfex.dll if it is a real file)"
  echo "Or install DroidDeck's droiddeckctl and rerun, or pass --guest-command / --ctl."
  exit 1
fi

echo
echo "Confirm these are set for the game (DroidDeck's FEX preset usually sets them):"
echo "  FEX_SMCCHECKS=full  FEX_TSOENABLED=1  FEX_HIDEHYPERVISORBIT=1"
