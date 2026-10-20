# Changes from the 0.1.1 sources (circulating `bitcoin-0.1.0.rar`)

| File | Change | Basis |
|---|---|---|
| `irc.cpp` | `else` branch with `CRITICAL_BLOCK(cs_mapAddresses) if (mapAddresses.count(addr.GetKey())) mapAddresses[addr.GetKey()].nLastFailed = 0;` after `AddAddress` | Quoted verbatim by Satoshi to Hal Finney, 10/01/2009, as the code removed for 0.1.1 |
| `irc.cpp` | Inner loop: on `fShutdown` close and return; on a read error set `fRestartIRCSeed = true` and `break` (reconnect) | Assumption: the unused `extern bool fRestartIRCSeed` vestige, and a node re-JOINing IRC seconds after a "Read error" in Hal's log |
| `irc.cpp` | `IRCPlaceholderA`, `IRCPlaceholderB` (never called), `CIRCPlaceholderInit` (static constructor, guarded by `fRestartIRCSeed`, prints nothing) | **Placeholders**, size stand-ins for ~1.4 KB of unknown code; invented content |
| `serialize.h` | `VERSION = 100` | Hal's debug.log (`version` message `64 00 00 00`) |
| `makefile` (build only) | The exe is compiled with `CFLAGS=-mthreads -O3 …` | 0.1.1 "turns off optimization"; `-O3` gives the observed layout and fault |
| `makefile` (in the package) | **Unchanged** (`-O0`, dated 07/01 01:00) | In the 0.1.1 archive the makefile still carries the 0.1.0 time (01:00) while the two files edited for 0.1.1 were re-dated (01:01), so the launch package most likely shipped this same `-O0` makefile. Satoshi built from a tree separate from his release folder, and the makefile's extra `-O3` rule for `sha.cpp` only makes sense with optimization off by default |

Packaging: every file dated 07/01/2009 01:00 (version-coded times: 01:00 = 0.1.0); the folder times of `src\obj` and `src\rc` are those of the circulating archive; the `src` folder time, the `windres` time and the `strip` time are assumptions.
