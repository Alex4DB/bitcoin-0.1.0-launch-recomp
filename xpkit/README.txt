Test kit for the reconstructed Bitcoin 0.1.0 - Windows XP SP3
=============================================================

Goal: replay Hal Finney's crash (10 Jan 2009) on a real Windows XP SP3 and read the stack
at the moment of the crash, to confirm where the address 942316 shown by his debugger
comes from.

Contents
  bitcoin.exe      the reconstructed 0.1.0 (-O3, stripped like the original)
                   (a compatible reconstruction, not the original: see the repository README)
  libeay32.dll, mingwm10.dll   the DLLs shipped with 0.1.0 (identical to the original)
  fakeircd.exe     local fake IRC server (127.0.0.1:6667), source: fakeircd.c
  1-setup.bat      run ONCE, as administrator
  2-run.bat        one test run
  3-collect.bat    gathers the results into results\run_N
  EXPECTED.txt     the addresses expected with this build

Precautions
  - Isolated VM: network adapter in "host-only" (or internal network) mode. Bitcoin 0.1.0
    tries to reach 72.233.89.199 (the old whatismyip.com) and 1.2.3.4:8333; no need for
    that traffic to leave the VM.
  - Do not run on a real machine.
  - Take a VM snapshot before 1-setup.bat: the script edits the hosts file and installs
    Dr. Watson as the default debugger.

Steps
  1. Copy the whole folder into the VM, e.g. C:\btc010\
  2. Run 1-setup.bat as administrator (right-click > Run as..., or an admin session).
  3. Run 2-run.bat, then DOUBLE-CLICK bitcoin.exe in the Explorer window it opens
     (Hal: double-click = crash; launched from a cygwin shell = no crash).
     If Windows asks to allow bitcoin.exe through the firewall, accept.
  4. Wait for the crash (10 to 40 s; GetMyExternalIP can take ~20 s on an isolated
     network). The Bitcoin window disappears. Close the fakeircd window.
  5. Run 3-collect.bat, then zip results\run_N.
  6. Repeat 2-run.bat + double-click + 3-collect.bat 2 or 3 times: the leftover content of
     the stack can vary from one run to the next.

Optional (if available in the VM)
  - Visual Studio (6.0 or 2005): the debugger Hal used. Instead of Dr. Watson, choose
    "Debug" at the crash and copy the Call Stack window (or a screenshot), plus the Memory
    window at address ESP.
  - WinDbg (Debugging Tools for Windows 6.x): "windbg -I" installs it as the post-mortem
    debugger; at the crash type:  r   then  kb   then  dds esp L40
    and copy the output.

If bitcoin.exe does not crash
  - Check debug.log for the lines "GOT WHO: [u4HUtbXQT3ySNk]  new" then
    "GOT JOIN: [u4HUtbXQT3ySNk]". If they are missing, the fake IRC server was not
    reached (hosts file, firewall).
  - The crash depends on nearby memory (as for Hal): run again.
