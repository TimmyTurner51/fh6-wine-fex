# Forza Horizon 6 on ARM64 — Wine + FEX patches

Run Forza Horizon 6 on ARM64 (Snapdragon 8 Elite / DroidDeck-class devices) through
Wine + FEX, pass its anti-tamper checks, and hold a playable in-world frame rate.

These are **compatibility/correctness patches, not anti-cheat bypasses**. They make the
ARM64EC runtime behave the way native Windows x64 does, so the game's own integrity
checks pass honestly.

## Result

- Boots through the anti-tamper checks with no workarounds or disabled checks.
- **~38.9 FPS in-world** on a DroidDeck (Snapdragon 8 Elite), 120 Hz panel.
- Built and tested on top of upstream FEX `main` and Proton 11.0.

## What's inside

| Path | What it is | Drop-in? |
|------|------------|----------|
| `bin/libarm64ecfex.dll` | Prebuilt FEX (ARM64EC) with both FEX patches applied | Yes |
| `fex/0001-per-block-invalidation.patch` | FEX: invalidate only the block that changed instead of its whole page | Source |
| `fex/0002-block-level-smc-validation.patch` | FEX: self-modifying-code checks in 255-byte chunks instead of per-instruction | Source |
| `wine/spec32-arm64x-import-thunk.patch` | Wine: ARM64EC import thunks get the same hotpatch prologue as native x64 | Source |

## How it works (short version)

**Wine** — Forza's anti-tamper inspects the prologue of every exported function. On
ARM64EC, Wine emitted a bare `jmp [import]` thunk where native Windows emits the standard
8-byte hotpatch prologue, so the game classified each import as "hooked". The patch makes
the ARM64EC thunks byte-identical to native x64 (`48 8d a4 24 00 00 00 00 ff 25`).

**FEX** — with `FEX_SMCCHECKS=full`, FEX validates the bytes of every instruction before
it runs. The two patches make that check cheap enough for real gameplay: a changed block
invalidates *only that block* (not the page), and validation runs once per 255-byte chunk
(not once per instruction).

## Import

Step-by-step instructions for **DroidDeck** and **GameNative** (and any other app that
accepts custom Wine + FEX packages) are in [IMPORT.md](IMPORT.md).

## Source

The patches are tracked as clean branches against upstream:

- Wine — `TimmyTurner51/proton-wine`, branch `fh6`
- FEX — `TimmyTurner51/FEX`, branch `fh6`

## License

Each patch is a modification of its parent project and carries that project's license:
Wine is LGPL-2.1-or-later, FEX is MIT. See the upstream repositories for the full text.
