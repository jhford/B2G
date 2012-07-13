#!/bin/bash

. load-config.sh

# Map the build system device name back to the one used against config.sh
case $DEVICE in
    generic)
        pr_dev=emulator ;;
    generic_x86)
        pr_dev=emulator-x86 ;;
    panda)
        pr_dev=pandaboard ;;
    maguro)
        pr_dev=galaxy-nexus ;;
    crespo)
        pr_dev=nexus-s ;;
    *)
        pr_dev=$DEVICE ;;
esac 

b2g_root=$(cd `dirname $0` ; pwd)
b2g_basename=$(basename $b2g_root)
b2g_parent=$(dirname $b2g_root)
branch=$(cd $b2g_root/.repo/manifests && git rev-parse --abbrev-ref HEAD)
manifest_file=sources.xml
output="B2G_${branch}_${pr_dev}.tar.gz"

if [ $OUT_DIR ] ; then
    if [ -d $b2g_root/$OUT_DIR ] ; then
        gecko_exclude="--exclude=${b2g_basename}/$OUT_DIR"
    fi
fi

if [ $GECKO_OBJDIR ] ; then
    if [ -d $b2g_root/$GECKO_OBJDIR ] ; then
        gecko_exclude="--exclude=${b2g_basename}/$GECKO_OBJDIR"
    fi
fi

test $pr_dev && test $branch &&
echo Creating manifest &&
$b2g_root/gonk-misc/add-revision.py $b2g_root/.repo/manifest.xml \
        --output $manifest_file --force --b2g-path $b2g_root --tags &&
echo Creating Tarball &&
nice tar zcf "$output" \
    -C $b2g_parent \
    --checkpoint=1000 \
    --checkpoint-action=dot \
    --transform="s,^$b2g_basename,B2G_${branch}_${pr_dev}," \
    --exclude=".git" \
    --exclude=".hg" \
    --exclude="$b2g_basename/$output" \
    --exclude="$b2g_basename/.repo" \
    --exclude="$b2g_basename/repo" \
    --exclude="$b2g_basename/out" \
    --exclude="$b2g_basename/objdir-gecko" \
    $gecko_exclude \
    $android_exclude \
    $b2g_basename &&
rm $manifest_file &&
echo Done! &&
echo "{'output': '$b2g_root/$output'}"

