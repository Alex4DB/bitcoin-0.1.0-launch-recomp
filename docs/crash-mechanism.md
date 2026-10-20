# Hal Finney's 0.1.0 crash, mechanically

Report (10/01/2009, Windows XP SP3, stripped launch-day exe): "The exception was at address 00930AF7. The displayed call stack was 942316 called by 508936."

## 1. The packed `find`

`irc.cpp` declares `struct ircaddr` after `#pragma pack(1)` and never restores packing. Everything instantiated later in that file is laid out with 1-byte packing, including `_Rb_tree<vector<uchar>, pair<const vector<uchar>, CAddress>, …>::find`, reached through the inlined `mapAddresses.count`.

- `mapAddresses` itself is defined in `net.cpp` with normal alignment.
- The packed `find` reads the header at `this+1` instead of `this+4`, so the root at `this+5` instead of `this+8`. That gives ESI = (low byte of the root node's address) << 24 (bytes 5–7 are the header colour, 0 or 1).
- The fault is `mov 0x14(%esi),%ecx` at `find+0x27`, e.g. reading 0x88000014. Under Wine the faulting addresses seen were 0x70/0x78/0x80/0x88/0x90/0xC8000014.

Consequences:
- **empty map** → root 0 → ESI 0 → the loop ends, `count` returns 0, no crash;
- **populated map** → crash, unless the root's low byte is 0 or 0xXX000014 happens to be mapped (then the crash moves, e.g. into `lexicographical_compare`).

## 2. Why the linker kept that copy

GNU ld keeps the first `.text$<symbol>` it meets in link order. In the launch build, the `const find` of this map is instantiated **only** in `irc.o`, so the packed copy is the one linked. `irc.o`'s other copies for the same map (`lower_bound`, `insert_unique`, `CAddress::GetKey`, …) all lose to `net.o`/`db.o`.

Satoshi's 0.1.3 workaround (`mapAddresses.count(vector<unsigned char>(18));` in `db.cpp`) adds a normal copy in `db.o`, which comes earlier in the link, so that copy wins:
- a version where the extra `count` sits in a function that is **never called** removes the crash just as well;
- it is a link effect, not a thread effect.

It was partial. `count` stays inlined in `ThreadIRCSeed` with the packed `end()` (`&mapAddresses+1`). A correct `find` returning the real `end()` (`&mapAddresses+4`) for an absent key therefore gives count = 1, and `operator[]` reads the tree header as a node. With `addr.dat` loaded, an unroutable nickname (e.g. one's own) then crashes elsewhere.

Satoshi fixed the pragma itself in 0.1.5 (`#pragma pack(push, 1)` / `pop`), with the comment "The bug was the pack pragma in irc.cpp".

## 3. The three addresses

At `-O3`, `ThreadIRCSeed` passes arguments with `mov …,(%esp)`, so all its calls start from the same stack pointer S.

- **`508936`**: return address of the call to `find`, at S−4.
- **`00930AF7`**: `find+0x27`, the faulting instruction above.
- **`942316`**:
  - `DecodeAddress(pszName, addr)` takes a `std::string` by value, built by `std::string(const char*)` called directly from `ThreadIRCSeed`. That constructor calls `_S_construct` with its own ESP at S−32, leaving the return address (`942316`) at **S−36**.
  - `find` reserves its frame down to S−48 but writes S−36 only after `+0x27`, and `GetKey`, called just before, never touches it.
  - Breakpoints after every call (`scripts/trace-slot.sh`, `docs/results/slot-s36.out`) show the value survives `DecodeAddress`, the `CDB` constructor and `AddAddress`. Only `EnterCriticalSection` overwrites it, and that is Wine's C implementation. XP's `RtlEnterCriticalSection` uses no stack when uncontended.
  - A debugger scanning up from `find`'s ESP therefore meets `942316` before `508936`.

## 4. Replaying the sessions

`scripts/fakeircd-scenarios.pl` + `scripts/run-scenario.sh` (`docs/results/scenarios.out`):
- **session 1** (own JOIN/WHO on the empty map pass, new 1.2.3.4, its re-JOIN crashes) and **sessions 2–3** (`addr.dat` kept, own JOIN crashes at once) both fault at `00930AF7`;
- Satoshi's "count as the very first thing in the thread" test faults if the map is loaded and passes if empty.

## 5. Not checked here

- A real XP SP3 run (see `xpkit/`).
- Hal's observation that the gcc-symbols build "does not crash" when launched from cygwin. It is plausible as a heap-layout effect (needs a 0x00 low byte or a mapped page), but 37 Wine runs with different environment sizes all crashed (low bytes 0x70–0x90).
