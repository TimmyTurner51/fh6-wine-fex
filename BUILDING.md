# Building from source

You only need this if you want to build the FEX DLL or Wine yourself. To play, follow the
[install steps in the README](README.md#install-droiddeck-5-steps).

## FEX (`libarm64ecfex.dll`)

Apply both patches to upstream FEX `main`, or check out the `fh6` branch of
[`TimmyTurner51/FEX`](https://github.com/TimmyTurner51/FEX), which already has them.

```sh
git clone https://github.com/FEX-Emu/FEX.git
cd FEX
git submodule update --init --depth 1
git apply /path/to/fh6-wine-fex/fex/0001-per-block-invalidation.patch
git apply /path/to/fh6-wine-fex/fex/0002-block-level-smc-validation.patch
```

Cross-compile the ARM64EC target with [llvm-mingw](https://github.com/mstorsjo/llvm-mingw).
Point the toolchain file at your llvm-mingw install:

```sh
cmake -S . -B build_ec -G Ninja \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_TOOLCHAIN_FILE=Data/CMake/toolchain_mingw.cmake \
  -DMINGW_TRIPLE=arm64ec-w64-mingw32 \
  -DENABLE_LTO=False -DBUILD_TESTING=False
ninja -C build_ec arm64ecfex
llvm-strip --strip-all build_ec/Bin/libarm64ecfex.dll
```

To turn the DLL into installable packages, copy it to `bin/libarm64ecfex.dll` in this repo
and run:

```sh
./tools/make-wcp.sh        # writes dist/fh6-fex-droiddeck.wcp and dist/fh6-fex-gamenative.wcp
```

## Wine (import-thunk fix)

`wine/spec32-arm64x-import-thunk.patch` changes `winebuild`, so the ARM64EC PE files it
emits start their x64 import thunks with the same hotpatch prologue as native Windows
(`48 8d a4 24 00 00 00 00 ff 25`). Apply it to a Proton/Wine tree and rebuild Wine:

```sh
git apply /path/to/fh6-wine-fex/wine/spec32-arm64x-import-thunk.patch
```

The patch changes build output only, so there's no drop-in binary. DroidDeck-Proton
11-12.3 and newer already include it. You can check any Proton's `kernel32.dll` by counting
that byte pattern:

```sh
python3 -c "import sys; print(open(sys.argv[1],'rb').read().count(bytes.fromhex('488da42400000000ff25')))" \
  "<proton>/files/lib/wine/aarch64-windows/kernel32.dll"
```

Hundreds of matches means the fix is present. Zero means the game's anti-tamper rejects it.
