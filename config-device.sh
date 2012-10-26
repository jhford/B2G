#!/bin/bash

case `uname` in
"Darwin")
	CORE_COUNT=`system_profiler SPHardwareDataType | grep "Cores:" | sed -e 's/[ a-zA-Z:]*\([0-9]*\)/\1/'`
	;;
"Linux")
	CORE_COUNT=`grep processor /proc/cpuinfo | wc -l`
	;;
*)
	echo Unsupported platform: `uname`
	exit -1
esac

echo MAKE_FLAGS=-j$((CORE_COUNT + 2)) > .tmp-config
echo GECKO_OBJDIR=$PWD/objdir-gecko >> .tmp-config
echo DEVICE_NAME=$1 >> .tmp-config

case "$1" in
"galaxy-s2")
	echo DEVICE=galaxys2 >> .tmp-config
	;;

"galaxy-nexus")
	echo DEVICE=maguro >> .tmp-config
	;;

"optimus-l5")
	echo DEVICE=m4 >> .tmp-config
	;;

"nexus-s")
	echo DEVICE=crespo >> .tmp-config
	;;

"nexus-s-4g")
	echo DEVICE=crespo4g >> .tmp-config
	;;

"otoro"|"unagi")
	echo DEVICE=$1 >> .tmp-config
	;;

"pandaboard")
	echo DEVICE=panda >> .tmp-config
	;;

"emulator")
	echo DEVICE=generic >> .tmp-config
	echo LUNCH=full-eng >> .tmp-config
	;;

"emulator-x86")
	echo DEVICE=generic_x86 >> .tmp-config
	echo LUNCH=full_x86-eng >> .tmp-config
	;;

*)
	echo Usage: $0 \(device name\)
	echo
	echo Valid devices to configure are:
	echo - galaxy-s2
	echo - galaxy-nexus
	echo - nexus-s
	echo - nexus-s-4g
	echo - otoro
	echo - unagi
	echo - pandaboard
	echo - emulator
	echo - emulator-x86
	exit -1
	;;
esac

if [ $? -ne 0 ]; then
	echo Configuration failed
	exit -1
fi

mv .tmp-config .config

echo Run \|./build.sh\| to start building
