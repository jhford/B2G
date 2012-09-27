#!/bin/bash

REPO=./repo

repo_sync() {
	rm -rf .repo/manifest* &&
	$REPO init -u $GITREPO -b master -m $2.xml &&
	$REPO sync
	ret=$?
	if [ "$GITREPO" = "$GIT_TEMP_REPO" ]; then
		rm -rf $GIT_TEMP_REPO
	fi
	if [ $ret -ne 0 ]; then
		echo Repo sync failed
		exit -1
	fi
}

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

GIT_TEMP_REPO="tmp_manifest_repo"
if [ -n "$2" ]; then
	GITREPO=$GIT_TEMP_REPO
	GITBRANCH="master"
	rm -rf $GITREPO &&
	git init $GITREPO &&
	cp $2 $GITREPO/$1.xml &&
	cd $GITREPO &&
	git add $1.xml &&
	git commit -m "manifest" &&
	cd ..
else
	GITREPO="git://github.com/mozilla-b2g/b2g-manifest"
fi

echo MAKE_FLAGS=-j$((CORE_COUNT + 2)) > .tmp-config
echo GECKO_OBJDIR=$PWD/objdir-gecko >> .tmp-config
echo DEVICE_NAME=$1 >> .tmp-config

case "$1" in
"galaxy-s2")
	echo DEVICE=galaxys2 >> .tmp-config &&
	repo_sync galaxy-s2 $1 &&
	(cd device/samsung/galaxys2 && ./extract-files.sh)
	;;

"galaxy-nexus")
	echo DEVICE=maguro >> .tmp-config &&
	repo_sync maguro $1 &&
	(cd device/samsung/maguro && ./download-blobs.sh)
	;;

"optimus-l5")
	echo DEVICE=m4 >> .tmp-config &&
	repo_sync m4 $1 &&
	(cd device/lge/m4 && ./extract-files.sh)
	;;

"nexus-s")
	echo DEVICE=crespo >> .tmp-config &&
	repo_sync crespo $1 &&
	(cd device/samsung/crespo && ./download-blobs.sh)
	;;

"nexus-s-4g")
	echo DEVICE=crespo4g >> .tmp-config &&
	repo_sync crespo4g $1 &&
	(cd device/samsung/crespo4g && ./download-blobs.sh)
	;;

"otoro_m4-demo")
    echo DEVICE=otoro >> .tmp-config &&
    repo_sync otoro_m4-demo $1 &&
    (cd device/qcom/otoro && ./extract-files.sh)
    ;;

"otoro"|"unagi")
	echo DEVICE=$1 >> .tmp-config &&
	repo_sync otoro $1 &&
	(cd device/qcom/$1 && ./extract-files.sh)
	;;

"pandaboard")
	echo DEVICE=panda >> .tmp-config &&
	repo_sync panda $1 &&
	(cd device/ti/panda && ./download-blobs.sh)
	;;

"emulator")
	echo DEVICE=generic >> .tmp-config &&
	echo LUNCH=full-eng >> .tmp-config &&
	repo_sync master $1
	;;

"emulator-x86")
	echo DEVICE=generic_x86 >> .tmp-config &&
	echo LUNCH=full_x86-eng >> .tmp-config &&
	repo_sync master emulator
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
