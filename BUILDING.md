# Building from source

You only need this if you want to build the FEX DLL or Wine yourself. To play, follow the
[install steps in the README](README.md#install-droiddeck-5-steps).

## FEX (`libarm64ecfex.dll`)

The release DLL matches [`TimmyTurner51/FEX`](https://github.com/TimmyTurner51/FEX)
branch `fh6-dev` at `3fe750d85`. To rebuild that binary, check out that commit.

To apply the same changes to upstream FEX `main`, apply the four patches in order:

```sh
git clone https://github.com/FEX-Emu/FEX.git
cd FEX
git submodule update --init --depth 1
git apply /path/to/fh6-wine-fex/fex/0001-per-block-invalidation.patch
git apply /path/to/fh6-wine-fex/fex/0002-block-level-smc-validation.patch
git apply /path/to/fh6-wine-fex/fex/0003-l1-recommit-on-grow.patch
git apply /path/to/fh6-wine-fex/fex/0004-jit-stability-and-smc-batching.patch
```

That series is checked against FEX `main` at `14c92681`, and the four patches together
reproduce `bin/libarm64ecfex.dll` byte for byte after `llvm-strip --strip-all`.

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

## Wine (ARM64EC frame registers)

`wine/arm64ec-frame-regs.patch` is optional. An ARM64EC `CONTEXT` has no slot for `x13`,
`x14`, `x23`, `x24` or `x28`, so translating to and from one zeroes them; FEX's JIT keeps
live values there. The patch restores them from the syscall frame on a continue, and
carries them across `wait_suspend()`. Apply it at `TimmyTurner51/proton-wine` `462e0d2f`
(branch `fh6`) and rebuild Wine:

```sh
git apply /path/to/fh6-wine-fex/wine/arm64ec-frame-regs.patch
```

It changes `dlls/ntdll/unix/signal_arm64.c` only. The 1.2 frame rate and the absence of
the per-second beat were reproduced on **stock DroidDeck-Proton 11-12.5 with its own
ntdll**, so this patch is not needed for either. Keep it in mind only if a session ends
with the game vanishing at a suspend.
