#!/bin/sh
#
# Copyright (c) Facebook, Inc. and its affiliates. All Rights Reserved.
#

set -x
set -e

cd -- "$(dirname -- "$0")"

# Download data in temp dir.
rcd_fishhook_path="$(pwd)/rcd_fishhook/"
git_fishhook_path=$(mktemp -d /tmp/rcd-fishhook.XXXXXX)
if [ $? -ne 0 ]; then
    echo "$0: Can't create temp file, exiting..."
    exit 1
fi
cd -- "$git_fishhook_path"
git clone 'git@github.com:facebook/fishhook.git'

# Update repo.
cd "${rcd_fishhook_path}"
rm -- rcd_fishhook.* || true
cp -r "${git_fishhook_path}"/fishhook/* .
rm fishhook.podspec

sed -i '' 's/fishhook_h/rcd_fishhook_h/g' fishhook.*
sed -i '' 's/fishhook\.h/rcd_fishhook\.h/g' fishhook.*
sed -i '' 's/struct rebinding/struct rcd_rebinding/g' fishhook.*
sed -E -i '' 's/(rebind_symbols(_image)?|prepend_rebindings|perform_rebinding_with_section)\(/rcd_\1\(/g' fishhook.*

mv fishhook.h rcd_fishhook.h
mv fishhook.c rcd_fishhook.c

# Clean up.
rm -rf "$git_fishhook"
