# Bitcoin v0.1.0 launch-day build: a compatible reconstruction

**This is not the original 0.1.0.** It is a rebuild consistent with everything known about the launch-day release of 8–9 January 2009. About 1.4 KB of its code is unknown and has been replaced by clearly marked placeholders that never run. No copy or hash of the original is known, so the bytes cannot be verified. Do not present the exe or the archive as the genuine release.

## Context

- The archive circulating as `bitcoin-0.1.0.rar` (MD5 `91e2dfa2…`) actually contains **0.1.1** (`VERSION = 101`, built 10 January 2009), as The Chain Bulletin showed in 2020.
- t4t5/bitcoin-0.1-rebuilt (October 2026) rebuilt that 0.1.1 exe and archive byte for byte, and our independent rebuild agrees.
- The launch-day package was on SourceForge for about two days before being replaced. This work starts from there.

## What is concrete

- **Known launch-day differences**, all present here:
  - the `mapAddresses.count` block that Satoshi quoted to Hal Finney as removed in 0.1.1 (`reconstruction/irc.cpp`);
  - `VERSION = 100`, visible in Hal's debug.log;
  - an optimized build: 0.1.1 "turns off optimization". The exe is compiled with `-O3` **throughout**. Building like the packaged makefile (everything `-O0`, only `sha.cpp` at `-O3`) lands ~300 KB away from Hal's addresses and calls `count` out of line, unlike Hal's stack.
  - The **packaged** makefile stays the shipped one (`-O0`, dated 07/01 01:00). In the 0.1.1 archive it still carries the 0.1.0 time while the files edited for 0.1.1 were re-dated, so the launch package most likely contained it unchanged. Details in `reconstruction/CHANGES.md`.
- **Root cause of Hal's crash.** An unclosed `#pragma pack(1)` in `irc.cpp` makes gcc compile a packed copy of `map::find` for `mapAddresses`. It is the only copy, so the linker keeps it, and it reads the tree root at the wrong offset. An empty map is harmless; a populated one crashes.
- **Satoshi's workaround** ("call count once in the main thread") worked through the linker's choice of copy, not through threads: a never-called function is enough. It was only a partial fix. See `docs/crash-mechanism.md`.
- **Hal's three addresses** ("The exception was at address 00930AF7. The displayed call stack was 942316 called by 508936."):
  - `00930AF7` is `find+0x27`;
  - `942316` is a stale return address from the `std::string(const char*)` built for `DecodeAddress`, left in a stack slot that nothing overwrites before the fault (except Windows' `EnterCriticalSection`, which XP's implementation leaves alone);
  - `508936` is the return into `ThreadIRCSeed`.
- **This build hits all three exactly** (`scripts/anchors.sh`, `docs/results/reconstruction.out`) and replays Hal's crash under Wine (`docs/results/scenarios.out`).

| | MD5 | Size |
|---|---|---|
| 0.1.1 `bitcoin.exe` (circulating) | `307ad86c412c02abeb821afbb900355b` | 6,440,960 |
| **this** `bitcoin.exe` | `d4ec9a9966f6b5787c3228495d24cea1` | 6,512,128 |
| **this** archive `bitcoin-0.1.0-reconstruction.rar` | `32453c7373bf25d4c80ec37ffb1d9d33` | 2,349,492 |

SHA-256: exe `dfbbabe33b8ee759057b687d69ac9e6449c48ac27a8303549a5350d75cff1e1a`, archive `2f86033081a4342870f58095375b84ee9fbeb28dbca3ab1d7d34055a5a0bd19e`.

## Reproducing Hal's crash (IRC set-up)

The crash path only runs when IRC announces an address that is already known, or that `AddAddress` rejects. `scripts/fakeircd-scenarios.pl` (scenario `hal1`) replays Hal's first session:

1. `chat.freenode.net` → 127.0.0.1. The server sends `NOTICE AUTH :*** Found your hostname`, then `001`/`004` after `USER`.
2. After `WHO #bitcoin` it sends **our own JOIN**, then two `352` lines (**ours**, and a new peer `u4HUtbXQT3ySNk` = 1.2.3.4:8333), then `315`.
   - Our own address (127.0.0.1 → `u88qSoM5z3FYruu` here; Hal's LAN address on his machine) is not routable, so `AddAddress` returns false and `count` runs on an **empty** map: no crash.
3. A few seconds later the peer **re-JOINs**, as a node did in Hal's log after a "Read error". `count` runs on a populated map → fault at `00930AF7`.

The log then reads as Hal's:
```
GOT JOIN: [own] CAddress(...)
GOT WHO: [own] CAddress(...)
GOT WHO: [u4HUtbXQT3ySNk]  new  CAddress(1.2.3.4:8333)
GOT JOIN: [u4HUtbXQT3ySNk]
```
and stops at the last line.

- **Hal's sessions 2 and 3:** scenario `own` with `addr.dat` kept from the first run. Our own JOIN then crashes immediately, on the first lookup.
- **Nicknames** are `"u"` + Base58Check(IPv4 + port) (`EncodeAddress`).
- **Runner:** `scripts/run-scenario.sh <dir> <label> <hal1|own|quiet> <keep 0|1>`.

## Limits

- **About 1.4 KB (net) of launch-day `irc.cpp` code is unknown.** Hal's addresses sit 548 bytes (return) and 1,456 bytes (`find`) beyond the plain model, and the return offset modulo 16 shows that `ThreadIRCSeed`'s own body differed. Hundreds of compiler, linker and source variants did not explain it.
  - Here it is filled with placeholders (`IRCPlaceholderA/B`, `CIRCPlaceholderInit`) that never run, so behaviour is identical.
  - Their content is invented, and the bytes differ from the original wherever that code sits.
  - Whether the real code ran silently or not is unknown.
- **Assumptions:**
  - an IRC-reconnect variant: on a read error, set the unused `fRestartIRCSeed` flag and reconnect. It is motivated by that vestige and by the re-JOIN in Hal's log, and it gives the right return offset modulo 16;
  - the `windres` and `strip` times embedded in the exe (estimated or modelled).
- **The stack-slot mechanism behind `942316`** was checked under Wine only, not on a real Windows XP SP3. `xpkit/` contains a kit for that test.
- **Prior work.** To our knowledge, neither a launch-day reconstruction nor a mechanical explanation of Hal's addresses had been published before. Satoshi's 0.1.5 comment names the pack pragma only.

## What would settle it

- The original launch-day archive, or just its hash. A copy kept from 9–10 January 2009 would have a `bitcoin.exe` of about 6.5 MB, `VERSION = 100`, the `mapAddresses.count` block, and an MD5 other than `91e2dfa2…`.
- The unstripped exe Satoshi emailed to Hal on 10 January 2009.

## Build

1. Check out [t4t5/bitcoin-0.1-rebuilt](https://github.com/t4t5/bitcoin-0.1-rebuilt) and build its toolchain container and dependencies.
2. Check out this repository as `recomp/` inside it.
3. Run `scripts/shell.sh sh /work/recomp/scripts/build-recomp.sh`. It compiles with Satoshi's makefile, strips, and packs the archive with WinRAR 3.51 the way the release was packed.
4. Check the three addresses with `scripts/anchors.sh build/bitcoin/rec010/bitcoin-unstripped.exe`.

Changes to the 0.1.1 sources are listed in `reconstruction/CHANGES.md`.

## Credits and prior art

- t4t5/bitcoin-0.1-rebuilt (byte-exact 0.1.1, toolchain, archive recipe).
- The Chain Bulletin (2020).
- Dan Bryant, "Bitcoin Archaeology" (bitcoin-dev, 2020): functional builds; his "0.1.0" is the circulating archive, i.e. 0.1.1.
- 1stbitcoinminer.com (2026).
- The Satoshi Nakamoto Institute, Marc Bevand's archive of Hal Finney's files, and lugaxker/nakamoto-archive (the Hal–Satoshi emails and Hal's debug.log).

## License

Bitcoin sources: MIT, Copyright (c) 2009 Satoshi Nakamoto (see `license.txt` in the original archive). Scripts and documentation in this repository: MIT.
