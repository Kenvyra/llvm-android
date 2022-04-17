#!/bin/bash

set -ex

BUILDER_USER="leonardo"
BUILDER_EMAIL="not@existing.org"
CACHE_SIZE="100GB"
THREAD_COUNT=$(nproc --all)

# Get the latest LLVM commit, which is the one we want to build
COMMIT_HASH=$(curl https://api.github.com/repos/llvm/llvm-project/commits/main | jq .sha -r)

git config --global user.name "leonardo"
git config --global user.email "not@existing.org"

git config --global color.ui true

export USE_CCACHE=1
mkdir -p /build/ccache
export CCACHE_DIR="/build/ccache"
ccache -M $CACHE_SIZE

# Download Google's dependencies
mkdir llvm-toolchain && cd llvm-toolchain
repo init -u https://android.googlesource.com/platform/manifest -b master-plus-llvm
repo sync -c --jobs-network=$(( $THREAD_COUNT < 16 ? $THREAD_COUNT : 16 )) -j$THREAD_COUNT --jobs-checkout=$THREAD_COUNT --no-clone-bundle --no-tags

# Add the upstream LLVM remote
cd /build/llvm-toolchain/toolchain/llvm-project
git remote add upstream https://github.com/llvm/llvm-project
git fetch upstream

# Generate the new SVN for the commit we want to build
cd /build/llvm-toolchain/external/toolchain-utils
NEW_SVN=$(python3 llvm_tools/git_llvm_rev.py --llvm_dir /build/llvm-toolchain/toolchain/llvm-project --sha $COMMIT_HASH --upstream upstream)

# Merge the commit into Android's LLVM fork
cd /build/llvm-toolchain/toolchain/llvm_android

# Remove a broken commit
git reset --hard aosp/master
git revert 7c753cca8935f747175e0dae932970b0f9d9cac0 --no-edit

# Apply a patch that fixes issue with Android's libxml2
git am -3 /build/0001-Do-not-install-LLDB-deps-if-not-building-LLDB.patch

# Merge the commit into Android's LLVM fork
./merge_from_upstream.py --rev $NEW_SVN

# Make sure we have a MAJOR.MINOR.0 build and update the revision
sed "s/_patch_level =.*/_patch_level = '0'/g" -i android_version.py
sed "s/_svn_revision =.*/_svn_revision = '$NEW_SVN'/g" -i android_version.py

# One patch is currently broken, so hotfix it with a local one
mv /build/0001-Revert-two-changes-that-break-Android-builds.patch patches/Revert-two-changes-that-break-Android-builds.v7.patch

# Do an initial build ready for PGO generation
python3 build.py --build-instrumented --build-name adrian --skip-tests --no-build windows,lldb

# Do a PGO profiling run

# Patch some new warnings to make Android build
cd /build/llvm-toolchain/platform/build/soong
git am -3 /build/0001-Ignore-new-clang-15-warnings.patch

cd /build/llvm-toolchain

# Now run the PGO
prebuilts/python/linux-x86/bin/python3 toolchain/llvm_android/test_compiler.py --build-only --target aosp_raven-eng --no-clean-built-target --generate-clang-profile --clang-path out/install/linux-x86/clang-adrian/ ./

# Copy profdata to where Google wants it to be
cp /build/llvm-toolchain/out/pgo-$NEW_SVN.tar.bz2 /build/llvm-toolchain/prebuilts/clang/host/linux-x86/profiles/

# Delete old LLVM build
rm -rf /build/llvm-toolchain/out/

# Do a new LLVM build with the profdata
cd /build/llvm-toolchain/toolchain/llvm_android
python3 build.py --lto --build-name adrian --skip-tests --no-build windows,lldb

cd /build/llvm-toolchain/out/install/linux-x86/clang-adrian
XZ_OPT="-9 -T0" tar cJf clang-$NEW_SVN.tar.xz .
mv clang-$NEW_SVN.tar.xz /
