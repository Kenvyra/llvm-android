#!/bin/bash

set -ex

BUILDER_USER="leonardo"
BUILDER_EMAIL="not@existing.org"
CACHE_SIZE="100GB"
THREAD_COUNT=$(nproc --all)

# Get the latest LLVM commit, which is the one we want to build
COMMIT_HASH=$(curl https://api.github.com/repos/llvm/llvm-project/commits/main | jq .sha -r)

git config --global user.name $BUILDER_USER
git config --global user.email $BUILDER_EMAIL

git config --global color.ui true

export USE_CCACHE=1
mkdir -p /build/ccache
export CCACHE_DIR="/build/ccache"
ccache -M $CACHE_SIZE

# Download Google's dependencies
mkdir llvm-toolchain && cd llvm-toolchain
repo init -u https://android.googlesource.com/platform/manifest -b llvm-toolchain
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

git am -3 /build/0001-Check-lib64-for-libs-too.patch

# Merge the commit into Android's LLVM fork
./merge_from_upstream.py --rev $NEW_SVN

cd /build/llvm-toolchain/toolchain/llvm_android

# Make sure we have a MAJOR.MINOR.0 build and update the revision
sed "s/_patch_level =.*/_patch_level = '0'/g" -i android_version.py
sed "s/_svn_revision =.*/_svn_revision = '$NEW_SVN'/g" -i android_version.py

# Do an initial build ready for PGO generation
python3 build.py --lto --build-instrumented --build-name adrian --skip-tests --no-build windows,lldb

# Build is in /build/llvm-toolchain/out/stage2-install
git clone https://github.com/ClangBuiltLinux/tc-build /tc-build
mkdir -p /tc-build/build/llvm/
cp -r /build/llvm-toolchain/out/stage2-install /tc-build/build/llvm/stage2


# Do a PGO profiling run
cd /tc-build/
kernel/build.sh --pgo -t "ARM;AArch64;X86" -b /tc-build/build/llvm/

# PGO data is in /build/llvm-toolchain/out/stage2/profiles/*.profraw

cd /build/llvm-toolchain/out/stage2/profiles
/build/llvm-toolchain/out/stage1-install/bin/llvm-profdata merge -o $NEW_SVN.profdata *.profraw
tar -cvjSf pgo-$NEW_SVN.tar.bz2 $NEW_SVN.profdata

# Copy profdata to where Google wants it to be
cp pgo-$NEW_SVN.tar.bz2 /build/llvm-toolchain/prebuilts/clang/host/linux-x86/profiles/

# Delete old LLVM build
rm -rf /build/llvm-toolchain/out/

# Do a new LLVM build with the profdata and ready for BOLT instrumentation
cd /build/llvm-toolchain/toolchain/llvm_android
python3 build.py --pgo --lto --bolt-instrument --build-name adrian --skip-tests --no-build windows,lldb

cd /tc-build/
rm -rf build
mkdir -p /tc-build/build/llvm/
cp -r /build/llvm-toolchain/out/stage2-install /tc-build/build/llvm/stage2
kernel/build.sh --pgo -t X86 -b /tc-build/build/llvm/

# Merge all the bolt data into one
cd /build/llvm-toolchain/out/bolt_collection/clang
/build/llvm-toolchain/out/stage2-install/bin/merge-fdata *.fdata > clang.fdata
tar -cvjf bolt-$NEW_SVN.tar.bz2 clang.fdata

# Copy bolt data to where Google wants it to be
cp /build/llvm-toolchain/out/bolt_collection/clang/bolt-$NEW_SVN.tar.bz2 /build/llvm-toolchain/prebuilts/clang/host/linux-x86/profiles/

# Delete old builds
rm -rf /build/llvm-toolchain/out/

# Do a final build
cd /build/llvm-toolchain/toolchain/llvm_android
python3 build.py --pgo --lto --bolt --build-name adrian --skip-tests --no-build windows,lldb

cd /build/llvm-toolchain/out/install/linux-x86/clang-adrian
XZ_OPT="-9 -T0" tar cJf clang-$NEW_SVN.tar.xz .
mv clang-$NEW_SVN.tar.xz /
