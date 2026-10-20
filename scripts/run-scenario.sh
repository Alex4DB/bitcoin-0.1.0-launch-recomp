#!/bin/sh
# Scenario run of a build under Wine with winedbg --auto on faults.
# Usage (in btc2009-wine-x): run010s.sh <dir> <label> <scenario> <keep appdata 0|1> [env padding bytes] [seconds] [keep dir name]
dir=$1; label=$2; scen=$3; keep=$4; pad=${5:-0}; secs=${6:-90}; kd=${7:-appdata_keep}
out=/wine/drive_c/bitcoin/run_$label; rm -rf $out; mkdir -p $out
grep -q chat.freenode.net /etc/hosts || echo "127.0.0.1 chat.freenode.net $(hostname)" >> /etc/hosts
SCEN=$scen perl /work/recomp/scripts/fakeircd-scenarios.pl > $out/ircd.log 2>&1 &
Xvfb :99 -screen 0 1024x768x16 > /dev/null 2>&1 & sleep 2
export DISPLAY=:99
cp /wine/drive_c/bitcoin/libeay32.dll /wine/drive_c/bitcoin/mingwm10.dll $dir/ 2>/dev/null
wine reg add 'HKCU\Software\Wine\WineDbg' /v ShowCrashDialog /t REG_DWORD /d 0 /f > /dev/null 2>&1
wine reg add 'HKLM\Software\Microsoft\Windows NT\CurrentVersion\AeDebug' /v Debugger /t REG_SZ /d 'winedbg --auto %ld %ld' /f > /dev/null 2>&1
wine reg add 'HKLM\Software\Microsoft\Windows NT\CurrentVersion\AeDebug' /v Auto /t REG_SZ /d 1 /f > /dev/null 2>&1
A=/wine/drive_c/users/root/AppData/Roaming/Bitcoin; K=/wine/drive_c/bitcoin/$kd
if [ "$keep" = 1 ] && [ -d $K ]; then rm -rf $A; mkdir -p $(dirname $A); cp -a $K $A; else rm -rf $A; fi
rm -f $dir/debug.log $dir/db.log
PAD=$(head -c $pad /dev/zero | tr '\0' x); export PADDING="$PAD"
cd $dir && WINEDEBUG=-all timeout $secs wine bitcoin.exe > $out/wine.log 2>&1; echo "exit=$?" >> $out/wine.log
cp $dir/debug.log $out/ 2>/dev/null
wineserver -k 2>/dev/null; sleep 1
[ -d $A ] && { rm -rf $K; cp -a $A $K; }
f=$(grep -o "read access to [0-9a-fA-Fx]* at address [0-9a-fA-F]*" $out/wine.log | head -1)
echo "$label scen=$scen keep=$keep pad=$pad: ${f:-NO FAULT}; last IRC: $(grep -a 'GOT\|IRC :' $out/debug.log | tail -1 | cut -c1-70)"
