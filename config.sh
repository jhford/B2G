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
    cp $manifest $local_repo/$device.xml &&
    pushd $local_repo > /dev/null &&
    git add $device.xml &&
    git commit -m "Local Manifest" &&
    popd > /dev/null
}

repo_sync() {
    gitrepo=$1 ; shift
    device=$1 ; shift
    branch=$1 ; shift
	rm -rf .repo/manifest* &&
	$REPO init -u $gitrepo -b $branch -m $device.xml &&
	$REPO sync
	ret=$?
	if [ $ret -ne 0 ]; then
		echo ERROR: repo sync failed
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
	echo ERROR: unsupported platform: `uname`
	exit -1
esac

# Default values
device=""
branch="master"
tmp_manifest=""
gitrepo="git://github.com/mozilla-b2g/b2g-manifest"

# Make sure that at least a device is specified
if [ $# -eq 0 ] ; then
	echo "Usage: $0 <device name> [--branch <branch>] [--git-repo <repo_uri>] [--manifest <localmanifest>]"
	echo
	echo Valid devices to configure are:
	echo - galaxy-s2
	echo - galaxy-nexus
	echo - nexus-s
	echo - otoro
	echo - pandaboard
	echo - emulator
	echo - emulator-x86
    exit -1
fi

# Parse the arguments
while [ $# -gt 0 ] ; do
    case $1 in
        "--branch")
            shift
            branch=$1
            ;;
        "--git-repo")
            shift
            gitrepo=$1
            ;;
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
    gitrepo="$GIT_TEMP_REPO"
fi

echo MAKE_FLAGS=-j$((CORE_COUNT + 2)) > .tmp-config
echo GECKO_OBJDIR=$PWD/objdir-gecko >> .tmp-config
echo DEVICE_NAME=$1 >> .tmp-config

case "$device" in
"galaxy-s2")
	echo DEVICE=galaxys2 >> .tmp-config &&
	repo_sync $gitrepo galaxy-s2 $branch &&
	(cd device/samsung/galaxys2 && ./extract-files.sh)
	;;

"galaxy-nexus")
	echo DEVICE=maguro >> .tmp-config &&
	repo_sync $gitrepo maguro $branch &&
	(cd device/samsung/maguro && ./download-blobs.sh)
	;;

"optimus-l5")
	echo DEVICE=m4 >> .tmp-config &&
	repo_sync m4 &&
	(cd device/lge/m4 && ./extract-files.sh)
	;;

"nexus-s")
	echo DEVICE=crespo >> .tmp-config &&
	repo_sync $gitrepo crespo $branch &&
	(cd device/samsung/crespo && ./download-blobs.sh)
	;;

"nexus-s-4g")
	echo DEVICE=crespo4g >> .tmp-config &&
	repo_sync $gitrepo crespo4g $branch &&
	(cd device/samsung/crespo4g && ./download-blobs.sh)
	;;

"otoro")
	echo DEVICE=otoro >> .tmp-config &&
	repo_sync $gitrepo otoro $branch &&
	(cd device/qcom/otoro && ./extract-files.sh)
	;;

"pandaboard")
	echo DEVICE=panda >> .tmp-config &&
	repo_sync $gitrepo panda $branch &&
	(cd device/ti/panda && ./download-blobs.sh)
	;;

"emulator")
	echo DEVICE=generic >> .tmp-config &&
	echo LUNCH=full-eng >> .tmp-config &&
	repo_sync $gitrepo emulator $branch 
	;;

"emulator-x86")
	echo DEVICE=generic_x86 >> .tmp-config &&
	echo LUNCH=full_x86-eng >> .tmp-config &&
	repo_sync $gitrepo emulator $branch 
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
