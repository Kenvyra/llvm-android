#!/bin/bash

set -ex

BUILDER_USER="leonardo"
BUILDER_EMAIL="not@existing.org"
THREAD_COUNT=$(nproc --all)

# Get the latest LLVM commit, which is the one we want to build
COMMIT_HASH=$(curl https://api.github.com/repos/llvm/llvm-project/commits/main | jq .sha -r)

git config --global user.name $BUILDER_USER
git config --global user.email $BUILDER_EMAIL

git config --global color.ui true

# Download Google's dependencies
mkdir llvm-toolchain && cd llvm-toolchain
repo init -u https://android.googlesource.com/platform/manifest -b llvm-toolchain-testing
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

# Merge the commit into Android's LLVM fork
./merge_from_upstream.py --rev $NEW_SVN

cd /build/llvm-toolchain/toolchain/llvm_android

# Apply patches
git am -3 /build/0001-Update-applied-patches.patch
git am -3 /build/0001-Fix-BOLT.patch

# Make sure we have a MAJOR.MINOR.0 build and update the revision
sed "s/_patch_level =.*/_patch_level = '0'/g" -i android_version.py
sed "s/_svn_revision =.*/_svn_revision = '$NEW_SVN'/g" -i android_version.py

# Fixup patches for upstream compatibility
cp /build/disable-symlink-resolve-test-on-android.patch patches/disable-symlink-resolve-test-on-android.patch
cp /build/avoid-fifo-socket-hardlink-in-libcxx-tests.patch patches/avoid-fifo-socket-hardlink-in-libcxx-tests.patch
cp /build/hide-locale-lit-features-for-bionic.patch patches/hide-locale-lit-features-for-bionic.patch
cp /build/bionic-includes-plus-sign-for-nan.patch patches/bionic-includes-plus-sign-for-nan.patch

# Do an initial build ready for PGO generation
python3 build.py --lto --mlgo --build-instrumented --build-name adrian --skip-tests --no-build windows,lldb

# Build is in /build/llvm-toolchain/out/stage2-install
git clone https://github.com/Kenvyra/tc-build /build/tc-build
mkdir -p /build/tc-build/build/llvm/
mv /build/llvm-toolchain/out/stage2-install /build/tc-build/build/llvm/stage2

# Free some space
rm -rf /build/llvm-toolchain/out/stage2
rm -rf /build/llvm-toolchain/out/stage1-install
rm -rf /build/llvm-toolchain/out/stage1

# Do a PGO profiling run
cd /build/tc-build/
kernel/build.sh --pgo -t "ARM;AArch64;X86" -b /build/tc-build/build/llvm/

# PGO data is in /build/llvm-toolchain/out/stage2/profiles/*.profraw

cd /build/llvm-toolchain/out/stage2/profiles
/build/tc-build/build/llvm/stage2/bin/llvm-profdata merge -o $NEW_SVN.profdata *.profraw
tar -cvjSf pgo-$NEW_SVN.tar.bz2 $NEW_SVN.profdata

# Copy profdata to where Google wants it to be
cp pgo-$NEW_SVN.tar.bz2 /build/llvm-toolchain/prebuilts/clang/host/linux-x86/profiles/

# Delete old LLVM build
rm -rf /build/llvm-toolchain/out/

# Do a new LLVM build with the profdata and ready for BOLT instrumentation
cd /build/llvm-toolchain/toolchain/llvm_android
python3 build.py --pgo --lto --mlgo --bolt-instrument --build-name adrian --skip-tests --no-build windows,lldb

cd /build/tc-build/
rm -rf build
mkdir -p /build/tc-build/build/llvm/
mv /build/llvm-toolchain/out/stage2-install /build/tc-build/build/llvm/stage2

# Intermediate cleanup
rm -rf /build/llvm-toolchain/out/stage2
rm -rf /build/llvm-toolchain/out/stage1-install
rm -rf /build/llvm-toolchain/out/stage1

kernel/build.sh --pgo -t X86 -b /build/tc-build/build/llvm/

# Merge all the bolt data into one
cd /build/llvm-toolchain/out/bolt_collection/clang
/build/tc-build/build/llvm/stage2/bin/merge-fdata *.fdata > clang.fdata
tar -cvjf bolt-$NEW_SVN.tar.bz2 clang.fdata

# Copy bolt data to where Google wants it to be
cp /build/llvm-toolchain/out/bolt_collection/clang/bolt-$NEW_SVN.tar.bz2 /build/llvm-toolchain/prebuilts/clang/host/linux-x86/profiles/

# Delete old builds
rm -rf /build/llvm-toolchain/out/
rm -rf /build/tc-build

# Do a final build
cd /build/llvm-toolchain/toolchain/llvm_android
python3 build.py --pgo --lto --mlgo --bolt --build-name adrian --skip-tests --no-build windows,lldb

cd /build/llvm-toolchain/out/install/linux-x86/clang-adrian
XZ_OPT="-9 -T0" tar cJf clang-$NEW_SVN.tar.xz .
mv clang-$NEW_SVN.tar.xz /
