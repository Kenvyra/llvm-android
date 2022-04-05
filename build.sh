#!/bin/bash

set -ex

# Get the latest LLVM commit, which is the one we want to build
COMMIT_HASH=$(curl https://api.github.com/repos/llvm/llvm-project/commits/main | jq .sha -r)

git config --global user.name "leonardo"
git config --global user.email "not@existing.org"

git config --global color.ui true

# Download Google's dependencies
mkdir llvm-toolchain && cd llvm-toolchain
repo init -u https://android.googlesource.com/platform/manifest -b llvm-toolchain
repo sync -c

# Add the upstream LLVM remote
cd /build/llvm-toolchain/toolchain/llvm-project
git remote add upstream https://github.com/llvm/llvm-project
git fetch upstream

# Generate the new SVN for the commit we want to build
cd /build/llvm-toolchain/external/toolchain-utils
NEW_SVN=$(python3 llvm_tools/git_llvm_rev.py --llvm_dir /build/llvm-toolchain/toolchain/llvm-project --sha $COMMIT_HASH --upstream upstream)

# Merge the commit into Android's LLVM fork
cd /build/llvm-toolchain/toolchain/llvm_android
./merge_from_upstream.py --rev $NEW_SVN

# Make sure we have a MAJOR.MINOR.0 build and update the revision
sed "s/_patch_level =.*/_patch_level = '0'/g" -i android_version.py
sed "s/_svn_revision =.*/_svn_revision = '$NEW_SVN'/g" -i android_version.py

# One patch is currently broken, so hotfix it with a local one
mv /build/0001-Revert-two-changes-that-break-Android-builds.patch patches/Revert-two-changes-that-break-Android-builds.v7.patch

# TODO: Figure how to do PGO via --build-instrumented and do_test_build.py
python3 build.py --lto --build-name adrian --skip-tests --no-build windows,lldb

cd /build/llvm-toolchain/out/install/linux-x86/clang-adrian
XZ_OPT="-9 -T0" tar cJf clang-$NEW_SVN.tar.xz .
mv clang-$NEW_SVN.tar.xz /
