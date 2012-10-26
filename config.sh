#!/bin/bash
# This script understands how to create and sync a B2G source tree.
# config.sh script used to also configure the .config file and even
# further back also drove the blob setup

REPO=./repo

GITREPO=${GITREPO:-"git://github.com/mozilla-b2g/b2g-manifest"}
BRANCH=${BRANCH:-master}

GIT_TEMP_REPO="tmp_manifest_repo"
if [ -n "$2" ]; then
	GITREPO=$GIT_TEMP_REPO
	rm -rf $GITREPO &&
	git init $GITREPO &&
	cp $2 $GITREPO/$1.xml &&
	cd $GITREPO &&
	git add $1.xml &&
	git commit -m "manifest" &&
	cd ..

    if [ $? -ne 0 ] ; then
        echo Could not set up temporary manifest repository
        exit -1
    fi
fi

rm -rf .repo/manifest* &&
$REPO init -u $GITREPO -b $BRANCH -m $1.xml &&
$REPO sync
ret=$?
if [ "$GITREPO" = "$GIT_TEMP_REPO" ]; then
	rm -rf $GIT_TEMP_REPO
fi
if [ $ret -ne 0 ]; then
	echo Repo sync failed
	exit -1
fi

if [ $? -ne 0 ]; then
	echo Source tree sync failed
	exit -1
fi

# Start to actually configure the device
./config-device.sh $1

