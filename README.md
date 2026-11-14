# Forza Horizon 6 on ARM64 Android (DroidDeck)

A patched FEX that lets Forza Horizon 6 boot past its anti-tamper checks and play on
Snapdragon 8 Elite phones and handhelds running [DroidDeck](https://github.com/Droid-Deck).

Everything installs on the phone itself. You don't need a PC, adb or any scripts.

## What you need

- DroidDeck, with Steam set up and Forza Horizon 6 installed (Steam AppID 2483190).
- A Snapdragon 8 Elite class device. That's what this was tested on (Adreno 830, 120 Hz panel).
- About 12 GB of free RAM plus swap. The game uses 9–11 GB in the world.

## Install (DroidDeck, 5 steps)

1. **Download the FEX package on your phone.**
   Open the [latest release](https://github.com/TimmyTurner51/fh6-wine-fex/releases/latest)
   and download **`fh6-fex-droiddeck.wcp`**.

2. **Install DroidDeck-Proton.**
   Open **Setup**, press the **Components** card, then switch to the **Proton** tab. The tabs
   run **GPU · Proton · DXVK · VKD3D · FEX**, so Proton is the second one. DroidDeck-Proton
   appears under the **Available** heading; press **Get** beside it. Install version
   **11-12.3 or newer** (11-12.7 is current; 11-12.5 is what the frame rates below were
   measured on).

   Valve's *Proton Experimental (ARM64)* will **not** work. It is missing a Wine fix the
   anti-tamper needs (see [Why DroidDeck-Proton](#why-droiddeck-proton)).

3. **Import the package.**
   Open **Components**, tap **Import .wcp**, and pick `fh6-fex-droiddeck.wcp` from your
   Downloads. It shows up as FEX **FH6-1.2**.

4. **Set up Forza Horizon 6's profile.**
   Go back to **Setup** with **Forza Horizon 6** selected as the current game, and press the
   **Components** card. With a game selected, that card opens *that game's* profile instead of
   the general components page. Set:

   | Setting | Value |
   |---|---|
   | Proton | **DroidDeck-Proton 11-12.3** (or newer; tested on 11-12.5) |
   | FEX | **FH6-1.2** |
   | FEX preset | **Denuvo** — pick this *first* |
   | Per-game environment | the 20 variables below, added one at a time |

   **The variables are not optional.** Without them the game runs, but every second or so
   it stalls for about half a second. That beat is the reason this section exists.

   **Denuvo first, then the variables.** Selecting the Denuvo preset writes the anti-tamper
   baseline into the game's environment (`FEX_SMCCHECKS=full`, `FEX_HIDEHYPERVISORBIT=1`,
   `FEX_MULTIBLOCK=1`, `FEX_X87REDUCEDPRECISION=1`). The list below only *overrides* four of
   those keys and adds the rest, so it has to sit on top of the preset. Do not re-select the
   Denuvo preset afterwards: that rewrites the preset's own keys and throws the overrides away.

   There is **no "Custom FEX variables" field to paste into**. That label is not a setting — it
   is what the preset chip *displays* when the game's stored values no longer match any built-in
   preset. So after you add the first override below, the chip will read **Custom FEX
   variables** instead of **Denuvo**. That is the correct end state; it is not a mistake, and
   the baseline is still in place.

   Add the variables in **per-game environment → Add variable**, one name and value at a time.
   They apply to this game only.

   ```
   FEX_TSOENABLED=1
   FEX_HALFBARRIERTSOENABLED=1
   FEX_VECTORTSOENABLED=0
   FEX_MEMCPYSETTSOENABLED=0
   FEX_SMCCHECKS=full
   FEX_POOL_CLONE=1
   FEX_FH6_FASTUD=1
   FEX_DYNAMICL1CACHE=0
   FEX_PROFILESTATS=0
   FEX_SILENTLOG=1
   FEX_DISKCACHEMAXFILESIZE=8589934592
   FEX_SKIP_SRA_FLUSH=0
   FEX_FH6_STATS=0
   FEX_FH6_UDINPROC=0
   PROTON_NO_NTSYNC=1
   PROTON_NO_ESYNC=1
   PROTON_NO_FSYNC=0
   WINE_FAST_YIELD=1
   WINEDEBUG=-all
   TU_DEBUG=startup
   ```

   What the important ones do:

   | Variable | Value | Why |
   |---|---|---|
   | `FEX_TSOENABLED` | `1` | The Denuvo preset sets this to `0`. Without it the game stalls on the splash or loading screen. |
   | `FEX_HALFBARRIERTSOENABLED` | `1` | Same reason. |
   | `FEX_DYNAMICL1CACHE` | `0` | Keeps FEX's lookup table a fixed size, so it cannot grow in the middle of a drive. |
   | `FEX_PROFILESTATS` | `0` | Proton defaults it on, and it puts a clock read around FEX's own locks. |
   | `FEX_POOL_CLONE` | `1` | Holds back the recompile storm during load. |
   | `PROTON_NO_NTSYNC` / `PROTON_NO_ESYNC` | `1` | Steps around a sync path that can block a frame. |
   | `WINEDEBUG` | `-all` | Otherwise Wine logs every call and the frame rate collapses. |

   The rest set the preset's memory-ordering flags explicitly, keep logging off the hot
   path, and give the disk cache room. They are in the list because the measurement used
   them.

   The `.wcp` cannot set these itself. A DroidDeck package only carries files, and the FEX
   preset is applied underneath it, so the game's own environment entries are the only place
   that can override the preset.

5. **Launch the game** from Steam.
   The first launch takes several minutes, because FEX translates the game and fills its
   cache. Later launches are faster.

If the overlay shows `DroidDeck-Proton 11-12.5` (or whatever you installed) and the game
reaches the main menu, it worked.

## What to expect

- It boots and passes the anti-tamper checks, with no checks disabled.
- About **44–49 FPS** in the world at 1590×720, mean over a 180-second hold, with the
  slowest second at 39–41 and the fastest at 50–56. That is roughly 15 FPS above 1.1 on
  the same road.
- The regular frame-time beat that 1.1 showed once a second is gone. That depends on the
  variables in step 4 being set; see the troubleshooting table if it comes back.
- No crash and no core. Re-measured on **stock DroidDeck-Proton 11-12.5 with its own
  ntdll**, importing only the `.wcp` from this release: no 550 ms beat, and 56 FPS in the
  world on the last sample. The Wine patch below is *not* required for that result.
- The phone gets hot. Expect throttling after about 6–8 minutes without a cooler. The game
  reaches 80 °C+ and then the frame rate drops; everything above is measured on a cool
  device.

## What changed in 1.2

The frame graph rather than the crash was the thing left to fix. 1.1 spent a large share
of each second in FEX's lookup-table lock and in single-entry SMC invalidations, and it
threw away a code buffer as soon as it grew. 1.2 changes the runtime instead of the game:

- A code buffer that grows now continues its chain. It used to be freed while exit links
  and lookup entries still pointed into its code.
- Any live code buffer counts as JIT, so a thread that moved to a newer chain is still
  recognised when a signal lands in an older one.
- SMC invalidations are batched, with a gap between batches so readers get the lock.

Result on the test device: 30.3 FPS mean before, 48.5 and 44.5 on two consecutive holds,
with no 550 ms frame beats and no frames slower than 80 ms.

## Troubleshooting

| Problem | Fix |
|---|---|
| Game closes about a second after launch | Proton is wrong. Select DroidDeck-Proton for the game, not Proton Experimental. |
| Stuck on splash or loading screen, CPU busy, nothing progresses | `FEX_TSOENABLED=1` and `FEX_HALFBARRIERTSOENABLED=1` are missing from the game's custom FEX variables. |
| Stalls for about half a second, roughly once a second | The step 4 variables are missing or incomplete. Apply the whole list exactly as written; that is the combination that was measured. |
| Good for a while, then stutters as it heats up | Thermal throttling, not the package. Let it cool or add a cooler. |
| Anti-tamper or "integrity" error | The FEX package isn't active. Check that the game's FEX shows **FH6-1.2**, and the preset is **Denuvo** (it turns on full code checks). |
| Hard halt on garage / world loading | You are on FH6-1.0. Import **FH6-1.2**, which keeps the L1 lookup table committed when it grows. |
| FPS stuck around 30 like 1.1 | The game is still on the old package. Re-import `fh6-fex-droiddeck.wcp` and check the FEX shows **FH6-1.2**. |
| Game disappears mid-session at a suspend | Rare, and not covered by the package. `wine/arm64ec-frame-regs.patch` in this repo addresses it if you build your own Proton. See [BUILDING.md](BUILDING.md). |
| Very slow, single-digit FPS | Check that the preset is **Denuvo**. Other presets turn the code checks off or use a slower mode. Let the phone cool down too, because a throttled CPU halves the frame rate. |
| Steam updated Proton and things broke | Your DroidDeck-Proton choice is per game and isn't touched by Steam updates. Re-check step 4. |

## GameNative and other Winlator-style apps (untested)

`fh6-fex-gamenative.wcp` in the same release is the same FEX in the `FEXCore` package
format these apps import. It won't be enough on its own. The app's Wine must also include
the import-thunk fix in [`wine/spec32-arm64x-import-thunk.patch`](wine/spec32-arm64x-import-thunk.patch),
and you need the same FEX variables as above (`FEX_SMCCHECKS=full`, `FEX_HIDEHYPERVISORBIT=1`,
`FEX_TSOENABLED=1`, `FEX_HALFBARRIERTSOENABLED=1`). This path hasn't been tested.

## Why DroidDeck-Proton

Forza's anti-tamper checks the first bytes of exported Windows functions. Native Windows,
and Wine on x86_64, start those import thunks with a standard 8-byte "hotpatch" prologue.
Wine on ARM64EC used to emit a bare `jmp` instead, so the game decided its imports were
hooked. The Wine patch in this repo fixes that. DroidDeck-Proton 11-12.3 already ships
`kernel32` with the fixed thunks (797 of them). Valve's current Proton Experimental (ARM64)
has none.

## What's in this repo

| Path | What it is |
|---|---|
| Releases → `fh6-fex-droiddeck.wcp` | The FEX package for DroidDeck (use this) |
| Releases → `fh6-fex-gamenative.wcp` | Same FEX, packaged for GameNative/Winlator-style apps |
| `bin/libarm64ecfex.dll` | The bare FEX DLL inside both packages (sha256 `694c52e7…`) |
| `fex/*.patch` | FEX source patches: SMC checks, L1 grow recommit, and the 1.2 runtime work |
| `wine/*.patch` | The Wine import-thunk patch and the ARM64EC frame-register patch |
| `tools/make-wcp.sh` | Rebuilds both `.wcp` packages from `bin/libarm64ecfex.dll` |
| [`BUILDING.md`](BUILDING.md) | How to build FEX and Wine from source |

The FEX patches make `FEX_SMCCHECKS=full` cheap enough to play with (block-level
invalidation and 255-byte chunk validation), recommit the dynamic L1 lookup table on
grow so Windows does not leave that table decommitted, and in 1.2 keep a growing code
buffer chain alive, treat every live buffer as JIT when a signal arrives, and erase SMC
entries in batches so a writer cannot park every reader. Twelve patch files would be
noise, so the 1.2 runtime work is one patch: `0004-jit-stability-and-smc-batching.patch`.
The four FEX patches together reproduce `bin/libarm64ecfex.dll` exactly.

These are compatibility fixes, not anti-cheat bypasses. They make the ARM64EC runtime
behave the way native x64 Windows does, so the game's own checks pass honestly.

## Source

- FEX: [`TimmyTurner51/FEX`](https://github.com/TimmyTurner51/FEX), branch `fh6-dev` (prebuilt); `fh6` plus `fex/*.patch` for the compatibility fixes alone
- Wine: [`TimmyTurner51/proton-wine`](https://github.com/TimmyTurner51/proton-wine), branch `fh6`; `wine/arm64ec-frame-regs.patch` applies at `462e0d2f`
- Every FEX patch in `fex/` applies in order to FEX `main` at `14c92681`

## License

Each patch is a modification of its parent project and carries that project's license:
Wine is LGPL-2.1-or-later, FEX is MIT.
