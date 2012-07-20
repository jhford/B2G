#!/bin/bash

REPO=./repo
GIT_TEMP_REPO="tmp_manifest_repo"

# This function understands how to create the repository
# that contains the xml manifests used by repo
create_manifest_repo() {
    device=$1 ; shift
    local_repo=$1 ; shift
    manifest=$1 ; shift
    rm -rf $local_repo &&
    git init $local_repo &&
    cp $manifest $local_repo/default.xml &&
    pushd $local_repo > /dev/null &&
    git add default.xml &&
    git commit -m "Local Manifest" &&
    popd > /dev/null
}

repo_sync() {
	if [ "$GITREPO" = "$GIT_TEMP_REPO" ]; then
		BRANCH="master"
	else
		BRANCH=$1
	fi
	rm -rf .repo/manifest* &&
	$REPO init -u $GITREPO -b $BRANCH &&
	$REPO sync
	ret=$?
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

# Default values
device=""
tmp_manifest=""

# Make sure that at least a device is specified
if [ $# -eq 0 ] ; then
    echo "ERROR: you must specify a device"
    exit -1
fi

# Parse the arguments
while [ $# -gt 0 ] ; do
    case $1 in
        "--manifest")
            shift
            tmp_manifest=$1
            ;;
        *.xml )
            echo "WARNING: using a bare argument as an xml manifest is deprecated"
            echo "         use --manifest $1 instead"
            tmp_manifest=$1
            ;;
        *)
            if [ $device ] ; then
                echo "ERROR: You've already specified the device $device"
                exit -1
            else
                device="$1"
            fi
    esac
    shift
done

if [ -n "$tmp_manifest" ]; then
    create_manifest_repo $device $GIT_TEMP_REPO $tmp_manifest
    GITREPO="$GIT_TEMP_REPO"
else
	GITREPO="git://github.com/mozilla-b2g/b2g-manifest"
fi

echo MAKE_FLAGS=-j$((CORE_COUNT + 2)) > .tmp-config
echo GECKO_OBJDIR=$PWD/objdir-gecko >> .tmp-config
echo DEVICE_NAME=$1 >> .tmp-config

case "$device" in
"galaxy-s2")
	echo DEVICE=galaxys2 >> .tmp-config &&
	repo_sync galaxy-s2 &&
	(cd device/samsung/galaxys2 && ./extract-files.sh)
	;;

"galaxy-nexus")
	echo DEVICE=maguro >> .tmp-config &&
	repo_sync maguro &&
	(cd device/samsung/maguro && ./download-blobs.sh)
	;;

"optimus-l5")
	echo DEVICE=m4 >> .tmp-config &&
	repo_sync m4 &&
	(cd device/lge/m4 && ./extract-files.sh)
	;;

"nexus-s")
	echo DEVICE=crespo >> .tmp-config &&
	repo_sync crespo &&
	(cd device/samsung/crespo && ./download-blobs.sh)
	;;

"nexus-s-4g")
	echo DEVICE=crespo4g >> .tmp-config &&
	repo_sync crespo4g &&
	(cd device/samsung/crespo4g && ./download-blobs.sh)
	;;

"otoro_m4-demo")
    echo DEVICE=otoro >> .tmp-config &&
    repo_sync otoro_m4-demo &&
    (cd device/qcom/otoro && ./extract-files.sh)
    ;;

"otoro")
	echo DEVICE=otoro >> .tmp-config &&
	repo_sync otoro &&
	(cd device/qcom/otoro && ./extract-files.sh)
	;;

"pandaboard")
	echo DEVICE=panda >> .tmp-config &&
	repo_sync panda &&
	(cd device/ti/panda && ./download-blobs.sh)
	;;

"emulator")
	echo DEVICE=generic >> .tmp-config &&
	echo LUNCH=full-eng >> .tmp-config &&
	repo_sync master
	;;

"emulator-x86")
	echo DEVICE=generic_x86 >> .tmp-config &&
	echo LUNCH=full_x86-eng >> .tmp-config &&
	repo_sync master
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
	echo - pandaboard
	echo - emulator
	echo - emulator-x86
	exit -1
	;;
esac

if [ -n $tmp_manifest ] ; then
    rm -rf $GIT_TEMP_REPO
fi

if [ $? -ne 0 ]; then
	echo Configuration failed
	exit -1
fi

mv .tmp-config .config

echo Run \|./build.sh\| to start building
