#!/bin/bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

error () {
    echo ERROR: "$@"
    exit 1 
}

# Specify some defaults
GECKO_OBJDIR=objdir-gecko
OUT_DIR=out
DEVICE="unknown"

# This script should (and currently does) fail if the .config
# file is not present
. load-config.sh

b2g_root=$(cd `dirname $0` ; pwd)

output=$1 ; shift
if [ x$output == "x" ] ; then
    echo "Assuming output base name of \"B2G\""
    output="B2G"
fi
# Figure out the absolute path for the output base
output=$(cd `dirname $output` ; echo `pwd`/`basename $output`)

# Create a manifest that describes the state of the repositories
# that created this source tree
if [[ -f $b2g_root/.repo/manifest.xml && -x $b2g_root/gonk-misc/add-revision.py ]] ; then
    echo Generating an annotated copy of the manifest for the snapshot
    manifest_file=sources.xml
    $b2g_root/gonk-misc/add-revision.py $b2g_root/.repo/manifest.xml \
        --output $manifest_file --force --b2g-path $b2g_root --tags
    if [ $? -eq 0 ] ; then
        echo "Done!  The manifest file is located at \"$manifest_file\""
    else
        error "Failed to create manifest"
    fi
else
    error "Either there is no repo manifest or gonk-misc/add_revision.py is not executable"
fi

# If the GECKO_OBJDIR is absolute, we don't need to change it
if [ ! -d $GECKO_OBJDIR ] ; then
    # but if it isn't, lets address it relative to the b2g root
    GECKO_OBJDIR="$b2g_root/$GECKO_OBJDIR"
fi
# If it still doesn't exist, we probably haven't built yet
if [ ! -d $GECKO_OBJDIR ] ; then
    GECKO_OBJDIR=""
fi


if [ ! -d $OUT_DIR ] ; then
    OUT_DIR="$b2g_root/$OUT_DIR"
fi
if [ ! -d $OUT_DIR ] ; then
    OUT_DIR=""
fi

if [ $DEVICE == "unknown" ] ; then
    error "no DEVICE specified in $b2g_root/.config. Did you run $b2g_root/config.sh?"
fi

# These are useful values, lets keep them around
b2g_basename=$(basename $b2g_root)
b2g_parent=$(dirname $b2g_root)

# We need to figure out whether or not to bother excluding the gecko objdir.
# If the Objdir exists outside the source tree, we probably don't care about it
if [ "x$GECKO_OBJDIR" != "x" ] ; then
    echo $GECKO_OBJDIR | grep $b2g_parent &> /dev/null
    if [ $? -eq 0 ] ; then
        gecko_exclude="--exclude=$(echo $GECKO_OBJDIR | sed "s,^$b2g_parent/,,g")"
    fi
fi
# Same for the android OUT_DIR
if [ "x$OUT_DIR" != "x" ] ; then
    echo $OUT_DIR | grep $b2g_parent &> /dev/null
    if [ $? -eq 0 ] ; then
        android_exclude="--exclude=$(echo $OUT_DIR | sed "s,^$b2g_parent/,,g")"
    fi
fi

# Compute the actual output filename we'll use
real_output="$output-$DEVICE.tar.gz"

# If the real output file is to be under the B2G root,
# we want to exclude it
echo $real_output | grep $b2g_parent &> /dev/null
if [ $? -eq 0 ] ; then
    self_exclude="--exclude=$(echo $real_output | sed "s,^$b2g_parent/,,g")"
fi

echo "Creating tarball"

echo nice tar zcf "$real_output" \
    -C $b2g_parent \
    --checkpoint=1000 \
    --checkpoint-action=dot \
    --transform="s,^$b2g_basename,B2G-$DEVICE," \
    --transform="s,^$manifest_file,B2G-$DEVICE/sources.xml," \
    --exclude=".git" \
    --exclude="$b2g_basename/.repo" \
    --exclude="$b2g_basename/repo" \
    --exclude="$b2g_basename/out" \
    --exclude="$b2g_basename/objdir-gecko" \
    $gecko_exclude \
    $android_exclude \
    $self_exclude \
    $manifest_file $b2g_basename
if [ $? -eq 0 ] ; then
    echo 'Done!'
    echo "SNAPSHOT_OUTPUT: \"$real_output\""
    echo "DEVICE: \"$DEVICE\""
else
    error "tar failed"
fi

