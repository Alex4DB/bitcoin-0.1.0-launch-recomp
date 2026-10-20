#!/bin/sh
# Build the COMPATIBLE RECONSTRUCTION of the launch-day 0.1.0 (not the original;
# see README.md of this repository) with Satoshi's makefile, in a
# container-local tree C:\rec, then pack it like the release archive.
# Inputs: the release tgz (0.1.1 source), reconstruction/irc.cpp of this repository,
# VERSION = 100, CFLAGS -O3. Embedded times (assumptions, see README):
#   windres 2009-01-07 15:36:26 (last new object in src\obj, i.e. ui_res.o; fact-based estimate)
#   strip   2009-01-07 15:44:24 (windres + the 0.1.1 gap of 7 min 58 s; assumption)
# Output: build/bitcoin/rec010/{bitcoin.exe, bitcoin-unstripped.exe, bitcoin.map,
# bitcoin-0.1.0-reconstruction.rar} in the t4t5 checkout. Runs in its build container
# (scripts/shell.sh sh /work/recomp/scripts/build-recomp.sh), with this repository
# checked out as recomp/ inside the t4t5 checkout.
set -eu
export TZ=UTC
c=/wine/drive_c; R=$c/rec; O=$c/bitcoin/rec010
WINDRES_TIME=$(date -d '2009-01-07 15:36:26' +%s); STRIP_TIME=$(date -d '2009-01-07 15:44:24' +%s)
rm -rf $R $O; mkdir -p $R $O
bsdtar -xzf /work/original/archives/bitcoin-0.1.0.tgz --no-same-owner --strip-components=2 -C $R bitcoin/src
cp /work/recomp/reconstruction/irc.cpp $R/irc.cpp
perl -pi -e 's/static const int VERSION = 101;/static const int VERSION = 100;/' $R/serialize.h
perl -pi -e 's/^CFLAGS=-mthreads -O0 /CFLAGS=-mthreads -O3 /; s/-mwindows -Wl,--subsystem,windows /-mwindows -Wl,--subsystem,windows -Wl,-Map=bitcoin.map /' $R/makefile
mkdir -p $c/wxWidgets/lib/vc_lib/mswd/wx
cp $c/wxWidgets/lib/gcc_lib/mswd/wx/setup.h $c/wxWidgets/lib/vc_lib/mswd/wx/setup.h
for d in boost wxWidgets DB OpenSSL; do ln -sfn $c/$d /$d; done
wineserver -p 2>/dev/null || true
at() { t=$1; shift; rc=0; LD_PRELOAD=/usr/local/lib/i386/fixedtime.so FIXED_TIME=$t "$@" 2>/tmp/at.err || rc=$?; grep -v 'wrong ELF class' /tmp/at.err >&2 || true; return $rc; }
at $WINDRES_TIME wine cmd /c "cd /d C:\\rec && mingw32-make obj/ui_res.o" < /dev/null > $O/make.log 2>&1
wine cmd /c "cd /d C:\\rec && mingw32-make" < /dev/null >> $O/make.log 2>&1 || { tail -5 $O/make.log; exit 1; }
cd $R; cp bitcoin.exe $O/bitcoin-unstripped.exe; cp bitcoin.map $O/
at $STRIP_TIME wine strip bitcoin.exe < /dev/null; cp bitcoin.exe $O/bitcoin.exe
# Pack like the release (build-rar.sh), with launch-day times: every file 07/01 01:00
# (version 0.1.0 = minute 00), folders obj/rc as in the 0.1.1 archive, src = assumption.
P=$c/rrec; rm -rf $P; mkdir -p $P/bin $P/files
unar -q -D -o $P/bin /downloads/wrar351.exe Rar.exe
bsdtar -xzf /work/original/archives/bitcoin-0.1.0.tgz --no-same-owner --strip-components=1 -C $P/files
cp $R/irc.cpp $R/serialize.h $P/files/src/; cp $O/bitcoin.exe $P/files/bitcoin.exe
cd $P/files
find . -type f -exec touch -d '2009-01-07 01:00:00' {} +
touch -d '2009-01-07 15:36:27.46875' src/obj
touch -d '2009-01-07 15:37:33.671875' src/rc
touch -d '2009-01-07 15:43:30' src
wine $P/bin/Rar.exe a -m5 -md4096 -s -r -y 'C:\rrec\bitcoin-0.1.0-reconstruction.rar' '*' < /dev/null > /dev/null
perl /work/scripts/rar-attributes.pl $P/bitcoin-0.1.0-reconstruction.rar
cp $P/bitcoin-0.1.0-reconstruction.rar $O/
ls -l $O | awk '{print $5, $9}'
