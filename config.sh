#!/bin/bash

REPO=./repo
GIT_TEMP_REPO="tmp_manifest_repo"

print_usage() {
    echo "Usage: $0 <device_name> [-b <branch>] [-g <manifest_repo>] [--manifest <local_manifest>]"
    echo
    echo "Valid devices to configure are:"
    echo "  - galaxy-s2"
    echo "  - galaxy-nexus"
    echo "  - nexus-s"
    echo "  - otoro"
    echo "  - pandaboard"
    echo "  - emulator"
    echo "  - emulator-x86"
    echo
    echo " Explanation of config.sh options"
    echo "  -b/--branch: This option controls which branch of b2g-manifest to use.  This is"
    echo "               the option you'll want to use when you are selecting a specific"
    echo "               milestone"
    echo "  -g/--git-repo: This option lets you use a custom location for the repo manifest"
    echo "                 repository that 'repo' will work on"
    echo "  --manifest: This option lets you specify a local file that contains a repo"
    echo "              manifest to use for the repo initialization and syncing operations"
    echo
    exit -1
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

# Run the intial repo init and repo sycn commands
repo_sync() {
    gitrepo=$1 ; shift
    branch=$1 ; shift
    device=$1 ; shift
	rm -rf .repo/manifest* &&
	$REPO init -u ${gitrepo} -b ${branch} -m ${device}.xml &&
	$REPO sync
	ret=$?
	if [ $ret -ne 0 ]; then
		error Repo sync failed
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

# These are the default values.  Those that are empty strings
# are values that must be obtained from the command line if they
# are to be used
gitrepo="git://github.com/mozilla-b2g/b2g-manifest"
branch=master
device=""
tmp_manifest=""

# Parse the command line

# If there are no arguments, pring usage information
if [ $# -eq 0 ] ; then print_usage ; fi

while [ $# -gt 0 ] ; do
    case $1 in
        "--branch" | "-b")
            shift
            branch=$1
            ;;
        "--git-repo" | "-g")
            shift
            gitrepo=$1
            ;;
        "--manifest")
            # There is no shortform for this because I don't want to cause
            # confusion between ./repo -m and ./config.sh -m
            shift
            tmp_manifest=$1
            ;;
        *.xml)
            # This is deprecated and also a little messy.  I think assuming a .xml
            # file is a local manifest is a reasonable assumption in the short term
            error "Using $1 as a bare argument is deprecated.  Please use \"$0 --manifest $1\""
            tmp_manifest=$1
            ;;
        *)
            if [ $device ] ; then
                error It looks like you already have specified a deivce, \"$device\"
                exit -1
            else
                device=$1
            fi
    esac
    shift
done

# We need to make sure that there was at least one device specified
if [ -z "$device" ] ; then error "You need to specify a device!" ; exit -1 ; fi

# If a local manifest file was requested, we should create the local
# repository needed to do repo initialization and sync against
if [ $tmp_manifest ] ; then
    echo "Creating a temporary Git repository"
    create_manifest_repo $tmp_manifest $GIT_TEMP_REPO $device
    gitrepo=$GIT_TEMP_REPO
    if [ $branch != 'master' ] ; then
        echo "NOTE: overriding your branch because local manifest always use 'master'"
    fi
    branch=master
fi


if [ -z "$branch" ] ; then error "You must specify a branch" ; exit -1 ; fi
# This case should never be hit because there is a default value, but it's
# cheap to do the check regardless
if [ -z "$gitrepo" ] ; then error "something's broken" ; exit -1 ; fi

echo MAKE_FLAGS=-j$((CORE_COUNT + 2)) > .tmp-config
echo GECKO_OBJDIR=$PWD/objdir-gecko >> .tmp-config

# Do device specifc actions
case "$device" in
"galaxy-s2")
	echo DEVICE=galaxys2 > .tmp-config &&
	repo_sync $gitrepo $branch galaxy-s2 &&
	(cd device/samsung/galaxys2 && ./extract-files.sh)
	;;

"galaxy-nexus")
	echo DEVICE=maguro > .tmp-config &&
	repo_sync $gitrepo $branch maguro &&
	(cd device/samsung/maguro && ./download-blobs.sh)
	;;

"nexus-s")
	echo DEVICE=crespo >> .tmp-config &&
	repo_sync $gitrepo $branch crespo &&
	(cd device/samsung/crespo && ./download-blobs.sh)
	;;

"otoro")
	echo DEVICE=otoro > .tmp-config &&
	repo_sync $gitrepo $branch otoro &&
	(cd device/qcom/otoro && ./extract-files.sh)
	;;

"pandaboard")
	echo DEVICE=panda > .tmp-config &&
	repo_sync $gitrepo $branch panda &&
	(cd device/ti/panda && ./download-blobs.sh)
	;;

"emulator")
	echo DEVICE=generic > .tmp-config &&
	echo LUNCH=full-eng >> .tmp-config &&
	repo_sync $gitrepo $branch emulator
	;;

"emulator-x86")
	echo DEVICE=generic_x86 > .tmp-config &&
	echo LUNCH=full_x86-eng >> .tmp-config &&
	repo_sync $gitrepo $branch emulator
	;;

*)
	print_usage
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
	;;
esac

if [ $? -ne 0 ]; then
	echo Configuration failed
	exit -1
fi

# If we created a temporary manifest repository, we want to clean it up
if [ $tmp_manifest ] ; then
    rm -rf $GIT_TEMP_REPO
fi

mv .tmp-config .config

echo Run \|./build.sh\| to start building
