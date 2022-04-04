#!/bin/bash

set -ex

COMMIT_HASH=$(curl https://api.github.com/repos/llvm/llvm-project/commits/main | jq .sha -r)

git config --global user.name "leonardo"
git config --global user.email "not@existing.org"

git config --global color.ui true

mkdir llvm-toolchain && cd llvm-toolchain
repo init -u https://android.googlesource.com/platform/manifest -b llvm-toolchain
repo sync -c

cd /build/llvm-toolchain/toolchain/llvm-project
git remote add upstream https://github.com/llvm/llvm-project
git fetch upstream

cd /build/llvm-toolchain/external/toolchain-utils
NEW_SVN=$(python3 llvm_tools/git_llvm_rev.py --llvm_dir /build/llvm-toolchain/toolchain/llvm-project --sha $COMMIT_HASH --upstream upstream)

cd /build/llvm-toolchain/toolchain/llvm_android
./merge_from_upstream.py --rev $NEW_SVN

sed "s/_patch_level =.*/_patch_level = '0'/g" -i android_version.py
sed "s/_svn_revision =.*/_svn_revision = '$NEW_SVN'/g" -i android_version.py

# TODO: Figure how to do PGO via --build-instrumented and do_test_build.py
# One patch breaks it right now, so don't apply them
python3 build.py --lto --build-name adrian --skip-tests --no-build windows,lldb

cd /build/llvm-toolchain/out/install/linux-x86/clang-adrian
XZ_OPT="-9 -T0" tar cJf clang-$NEW_SVN.tar.xz .
mv clang-$NEW_SVN.tar.xz /
