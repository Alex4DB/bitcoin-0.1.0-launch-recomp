#!/bin/sh
# Value of one stack slot after each listed call returns (winedbg breakpoints).
# Usage (in btc2009-wine-x): run010b.sh <dir> <label> <slot addr> <addr>...
dir=$1; label=$2; slot=$3; shift 3; out=/wine/drive_c/bitcoin/run_$label; rm -rf $out; mkdir -p $out
echo "127.0.0.1 chat.freenode.net $(hostname)" >> /etc/hosts
perl /work/recomp/scripts/fakeircd-simple.pl > $out/ircd.log 2>&1 &
Xvfb :99 -screen 0 1024x768x16 > /dev/null 2>&1 & sleep 2
export DISPLAY=:99
cp /wine/drive_c/bitcoin/libeay32.dll /wine/drive_c/bitcoin/mingwm10.dll $dir/ 2>/dev/null
rm -rf /wine/drive_c/users/root/AppData/Roaming/Bitcoin; rm -f $dir/debug.log $dir/db.log
{ for a in "$@"; do printf "break *0x%s\n" $a; done
  i=0; while [ $i -lt 120 ]; do printf "cont\nx /1x %s\n" $slot; i=$((i+1)); done; printf "quit\n"; } > /tmp/cmds
cd $dir && WINEDEBUG=-all timeout 300 wine winedbg bitcoin.exe < /tmp/cmds > $out/wine.log 2>&1; echo "exit=$?" >> $out/wine.log
wineserver -k 2>/dev/null; true
