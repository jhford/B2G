#!/bin/bash

REPO=./repo

print_usage() {
    echo "Usage: $0 [-d <device_name>] [-b <branch>] [-g <manifest_repo>] [--manifest <local_manifest>]"
    echo
    echo "=================================================================================="
    echo "  -d/--device: This option is used to select a specific device to configure for."
    echo "               the list of available devices can be obtained by running $0 with"
    echo "               no arguments"
    echo "  -b/--branch: This option controls which branch of b2g-manifest to use.  This is"
    echo "               the option you'll want to use when you are selecting a specific"
    echo "               milestone"
    echo "  -g/--git-repo: This option lets you use a custom location for the repo manifest"
    echo "                 repository that 'repo' will work on"
    echo "  --manifest: This option lets you specify a local file that contains a repo"
    echo "              manifest to use for the repo initialization and syncing operations"
    echo "=================================================================================="
    echo
}

error() {
    echo "ERROR: $@" 1>&2
}

# When using a local manifest file, we need to create a temporary repository
# because repo only knows how to work with manifests that are stored in git
create_manifest_repo() {
    manifest=$1 ; shift
    local_repo=$1 ; shift
    device=$1 ; shift
    rm -rf $local_repo &&
    git init $local_repo &&
    cp $manifest $local_repo/${device}.xml &&
    pushd $local_repo > /dev/null &&
    git add ${device}.xml &&
    git commit -m "local manifest" &&
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
    create_manifest_repo $2 $GIT_TEMP_REPO $1
    GITREPO=$GIT_TEMP_REPO
else
	GITREPO="git://github.com/mozilla-b2g/b2g-manifest"
fi

case "$1" in
"galaxy-s2")
	echo DEVICE=galaxys2 > .config &&
	repo_sync galaxy-s2 &&
	(cd device/samsung/galaxys2 && ./extract-files.sh)
	;;

"galaxy-nexus")
	echo DEVICE=maguro > .config &&
	repo_sync maguro &&
	(cd device/samsung/maguro && ./download-blobs.sh)
	;;

"nexus-s")
	echo DEVICE=crespo > .config &&
	repo_sync crespo &&
	(cd device/samsung/crespo && ./download-blobs.sh)
	;;

"otoro")
	echo DEVICE=otoro > .config &&
	repo_sync otoro &&
	(cd device/qcom/otoro && ./extract-files.sh)
	;;

"emulator")
	echo DEVICE=generic > .config &&
	echo LUNCH=full-eng >> .config &&
	repo_sync master
	;;

"emulator-x86")
	echo DEVICE=generic_x86 > .config &&
	echo LUNCH=full_x86-eng >> .config &&
	repo_sync master
	;;

*)
	echo Usage: $0 \(device name\)
	echo
	echo Valid devices to configure are:
	echo - galaxy-s2
	echo - galaxy-nexus
	echo - nexus-s
	echo - otoro
	echo - emulator
	echo - emulator-x86
	exit -1
	;;
esac

if [ $? -ne 0 ]; then
	echo Configuration failed
	exit -1
fi

echo MAKE_FLAGS=-j$((CORE_COUNT + 2)) >> .config
echo GECKO_OBJDIR=$PWD/objdir-gecko >> .config

echo Run \|./build.sh\| to start building
