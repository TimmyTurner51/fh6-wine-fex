# Import guide

This project ships two things:

1. **A prebuilt FEX** (`bin/libarm64ecfex.dll`) — drop this into your Wine tool.
2. **Source patches** — apply them if you build Wine/FEX from source.

For a full anti-tamper pass you need *both* the FEX behavior and the Wine thunk fix. The
FEX is a runtime drop-in; the Wine change is build-time, so it is only needed if your Wine
doesn't already emit x64-style import thunks (see "Wine patch" below).

---

## DroidDeck

### 1. Replace the FEX DLL

The FEX binary lives inside your Proton tool's Wine libraries. For the standard
`proton-fh6` tool the path is:

```
<tool>/files/lib/wine/aarch64-windows/libarm64ecfex.dll
```

where `<tool>` is under:

```
/root/.local/share/Steam/compatibilitytools.d/<your-proton-tool>/
```

Steps:

1. Copy `bin/libarm64ecfex.dll` over that file (back up the original first).
2. The game prefix's `system32/libarm64ecfex.dll` is usually a symlink to the tool copy,
   so updating the tool copy is enough. If it is a real file, replace it too:
   ```
   /root/.local/share/Steam/steamapps/compatdata/2483190/pfx/drive_c/windows/system32/libarm64ecfex.dll
   ```

### 2. Confirm the FEX environment

The patches only take effect with full self-modifying-code checking enabled. Make sure the
game runs with:

| Variable | Value | Why |
|----------|-------|-----|
| `FEX_SMCCHECKS` | `full` | enables the block-level SMC path this FEX optimizes |
| `FEX_TSOENABLED` | `1` | x86 total-store-order memory model |
| `FEX_HIDEHYPERVISORBIT` | `1` | reports a native CPUID, not a hypervisor |

DroidDeck's FEX preset normally sets these already. To check what a running process
actually received, read `/proc/<pid>/environ` of `forzahorizon6.exe`.

### 3. Launch

Start Steam, launch Forza Horizon 6, and drive the menus to the in-world HUD. If it boots
past the anti-tamper screen and shows the world, the import worked.

---

## GameNative (and other apps with custom Wine/FEX packages)

GameNative accepts custom Wine + FEX packages the same way DroidDeck does. The FEX binary
is the same file (`libarm64ecfex.dll`); only the install path differs.

1. Locate your package's Wine library directory (it contains `libarm64ecfex.dll`).
2. Replace it with `bin/libarm64ecfex.dll`.
3. Set the same three FEX variables above (`FEX_SMCCHECKS=full`,
   `FEX_TSOENABLED=1`, `FEX_HIDEHYPERVISORBIT=1`).
4. If the app lets you select a custom Wine build, ensure that build emits x64-style
   import thunks (see next section), or apply the Wine patch when building it.

---

## Building from source

### FEX

Apply both patches to upstream FEX `main`, then build the ARM64EC target:

```
git clone https://github.com/FEX-Emu/FEX.git
cd FEX
git apply fex/0001-per-block-invalidation.patch
git apply fex/0002-block-level-smc-validation.patch
# cross-build with llvm-mingw for arm64ec-w64-mingw32
```

The resulting `libarm64ecfex.dll` is what you drop into the Wine tool.

### Wine patch

`wine/spec32-arm64x-import-thunk.patch` changes `winebuild` so the ARM64EC PE files it
emits use x64-style import thunks. Apply it to the Proton/Wine source and rebuild:

```
git apply wine/spec32-arm64x-import-thunk.patch
```

This is a build-time change; there is no drop-in binary for it. If your Wine tool already
produces x64-style import thunks (the DroidDeck `proton-fh6` tool does), you can skip it.
