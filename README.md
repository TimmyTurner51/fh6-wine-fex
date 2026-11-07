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
   In DroidDeck, open **Setup**, add **DroidDeck-Proton**, and install version **11-12.3 or newer**.
   Valve's *Proton Experimental (ARM64)* will **not** work. It is missing a Wine fix the
   anti-tamper needs (see [Why DroidDeck-Proton](#why-droiddeck-proton)).

3. **Import the package.**
   Open **Components**, tap **Import .wcp**, and pick `fh6-fex-droiddeck.wcp` from your
   Downloads. It shows up as FEX **FH6-1.1**.

4. **Set up Forza Horizon 6's profile.**
   On the Components page, open the profile for **Forza Horizon 6** and set:

   | Setting | Value |
   |---|---|
   | Proton | **DroidDeck-Proton 11-12.3** (or newer) |
   | FEX | **FH6-1.1** |
   | FEX preset | **Denuvo** |
   | Custom FEX variables | `FEX_TSOENABLED=1`, `FEX_HALFBARRIERTSOENABLED=1`, and `FEX_POOL_CLONE=1` |

   Don't skip TSO. The Denuvo preset turns x86 memory ordering off, and without it the
   game stalls on the splash or loading screen. `FEX_POOL_CLONE=1` stops a recompile
   storm during load. Optional: `FEX_FH6_FASTUD=1` makes the anti-tamper's illegal-opcode
   traps cheaper (same guest exception, no host SIGILL).

5. **Launch the game** from Steam.
   The first launch takes several minutes, because FEX translates the game and fills its
   cache. Later launches are faster.

If the overlay shows `DroidDeck-Proton 11-12.3` and the game reaches the main menu, it
worked.

## What to expect

- It boots and passes the anti-tamper checks, with no checks disabled.
- About **30 FPS** in the world at 1590×720 (highway overlay ~31 AVG, 1% low ~12).
  Dense city streaming can hitch while buildings page in.
- 1.0 could hard-halt on garage / world entry. 1.1 recommits FEX's L1 lookup table
  when it grows, so that load completes.
- The phone gets hot. Expect throttling after about 6–8 minutes without a cooler.

## Troubleshooting

| Problem | Fix |
|---|---|
| Game closes about a second after launch | Proton is wrong. Select DroidDeck-Proton for the game, not Proton Experimental. |
| Stuck on splash or loading screen, CPU busy, nothing progresses | `FEX_TSOENABLED=1` and `FEX_HALFBARRIERTSOENABLED=1` are missing from the game's custom FEX variables. |
| Anti-tamper or "integrity" error | The FEX package isn't active. Check that the game's FEX shows **FH6-1.1**, and the preset is **Denuvo** (it turns on full code checks). |
| Hard halt on garage / world loading | You are still on FH6-1.0. Import **FH6-1.1**. |
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
| `bin/libarm64ecfex.dll` | The bare FEX DLL inside both packages (sha256 `fabe72dd…`) |
| `fex/*.patch` | FEX source patches (SMC checks + L1 grow recommit) |
| `wine/*.patch` | The Wine import-thunk patch |
| `tools/make-wcp.sh` | Rebuilds both `.wcp` packages from `bin/libarm64ecfex.dll` |
| [`BUILDING.md`](BUILDING.md) | How to build FEX and Wine from source |

The FEX patches make `FEX_SMCCHECKS=full` cheap enough to play with (block-level
invalidation and 255-byte chunk validation), and they recommit the dynamic L1
lookup table on grow so Windows does not leave that table decommitted.

These are compatibility fixes, not anti-cheat bypasses. They make the ARM64EC runtime
behave the way native x64 Windows does, so the game's own checks pass honestly.

## Source

- FEX: [`TimmyTurner51/FEX`](https://github.com/TimmyTurner51/FEX), branch `fh6-dev` (prebuilt); `fh6` plus `fex/*.patch` for the compatibility fixes alone
- Wine: [`TimmyTurner51/proton-wine`](https://github.com/TimmyTurner51/proton-wine), branch `fh6`

## License

Each patch is a modification of its parent project and carries that project's license:
Wine is LGPL-2.1-or-later, FEX is MIT.
