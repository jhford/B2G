#!/bin/bash

export B2G_PATCH_DIRS="patches"
export B2G_TREEID_SH="$PWD/caf-build/treeid.sh"
export B2G_HASHED_FILES="$B2G_TREEID_SH $PWD/caf-build/vendorsetup.sh"
export REPO="$PWD/repo"

case $(uname) in
    "Darwin")
cat << EOF | scripts/bash4-mac/bash
source build/envsetup.sh
source caf-build/vendorsetup.sh $1
EOF
        ;;
    *)
        source build/envsetup.sh
        source caf-build/vendorsetup.sh $1
        ;;
esac

exit $?

