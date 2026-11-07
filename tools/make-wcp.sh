#!/usr/bin/env bash
# Package bin/libarm64ecfex.dll as importable .wcp files:
#   dist/fh6-fex-droiddeck.wcp   DroidDeck (Components -> Import .wcp)
#   dist/fh6-fex-gamenative.wcp  GameNative / Winlator-style apps
# Needs: bash, tar with zstd support (GNU tar >= 1.31, plus zstd), sha256sum.
set -euo pipefail

VERSION="${1:-FH6-1.0}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DLL="$ROOT/bin/libarm64ecfex.dll"
OUT="$ROOT/dist"
DESC="FEX for Forza Horizon 6 (per-block invalidation + block-level SMC validation). github.com/TimmyTurner51/fh6-wine-fex"

[ -f "$DLL" ] || { echo "missing $DLL" >&2; exit 1; }
mkdir -p "$OUT"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/droiddeck/files/lib/wine/aarch64-windows"
cp "$DLL" "$WORK/droiddeck/files/lib/wine/aarch64-windows/"
cat > "$WORK/droiddeck/profile.json" <<EOF
{
  "type": "FEXCore-Linux",
  "versionName": "$VERSION",
  "versionCode": 1,
  "description": "$DESC",
  "files": [
    {
      "source": "files/lib/wine/aarch64-windows/libarm64ecfex.dll",
      "target": "\${proton}/files/lib/wine/aarch64-windows/libarm64ecfex.dll"
    }
  ]
}
EOF
(cd "$WORK/droiddeck" && tar --zstd -cf "$OUT/fh6-fex-droiddeck.wcp" --owner=0 --group=0 profile.json files)

mkdir -p "$WORK/gamenative/system32"
cp "$DLL" "$WORK/gamenative/system32/"
cat > "$WORK/gamenative/profile.json" <<EOF
{
  "type": "FEXCore",
  "versionName": "$VERSION",
  "versionCode": 1,
  "description": "$DESC",
  "files": [
    { "source": "system32/libarm64ecfex.dll", "target": "\${system32}/libarm64ecfex.dll" }
  ]
}
EOF
(cd "$WORK/gamenative" && tar --zstd -cf "$OUT/fh6-fex-gamenative.wcp" --owner=0 --group=0 ./profile.json ./system32)

echo "dll: $(sha256sum "$DLL" | cut -c1-64)"
ls -l "$OUT"/*.wcp
