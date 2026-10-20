#!/bin/sh
# Print the three addresses of Hal Finney's crash report for an UNSTRIPPED build:
#   return address of the lookup call in ThreadIRCSeed      (Hal: 0x508936)
#   packed _Rb_tree<vector<uchar>,pair<..,CAddress>>::find, +0x27 = the fault (Hal: 0x930AF7)
#   instruction after "call _S_construct" in std::string(const char*)    (Hal: 0x942316)
# Usage: anchors.sh bitcoin-unstripped.exe   (needs nm/objdump with pe-i386 support)
set -eu
E=$1
nm -n --defined-only "$E" > /tmp/anchors.nm
a=$(grep " __Z13ThreadIRCSeedPv$" /tmp/anchors.nm | cut -c1-8); b=$(awk -v s=$a 'f{print $1;exit} $1==s{f=1}' /tmp/anchors.nm)
call=$(objdump -d --no-show-raw-insn --start-address=0x$a --stop-address=0x$b "$E" | grep -E "call.*CAddressESt10_Select1stIS6_ESt4lessIS2_ESaIS6_EE4find" | head -1)
ca=$(echo "$call" | awk -F: '{print $1}' | tr -d ' ')
ret=$(objdump -d --no-show-raw-insn --start-address=0x$ca --stop-address=$(printf 0x%x $((0x$ca+16))) "$E" | grep -E "^ +[0-9a-f]+:" | sed -n 2p | awk -F: '{print $1}' | tr -d ' ')
find=$(grep "8CAddressESt10_Select1stIS6_ESt4lessIS2_ESaIS6_EE4findERS4_$" /tmp/anchors.nm | grep " T " | head -1 | cut -c1-8)
s=$(grep " __ZNSsC1EPKcRKSaIcE$" /tmp/anchors.nm | cut -c1-8)
mid=$(objdump -d --no-show-raw-insn --start-address=0x$s --stop-address=$(printf 0x%x $((0x$s+0x50))) "$E" | grep -A1 "_S_construct" | tail -1 | awk -F: '{print $1}' | tr -d ' ')
printf "return into ThreadIRCSeed  0x%s   (Hal 0x508936)\n" $ret
printf "fault = find + 0x27        0x%x   (Hal 0x930af7)\n" $((0x$find + 0x27))
printf "string ctor after call     0x%s   (Hal 0x942316)\n" $mid
