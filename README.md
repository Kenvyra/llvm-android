# llvm-android

Build scripts to generate a bleeding edge LLVM toolchain based on [Google's build scripts](https://android.googlesource.com/toolchain/llvm_android/).

## TODO

The script currently requires manual intervention because:

* [One patch](https://android.googlesource.com/toolchain/llvm_android/+/refs/heads/master/patches/Revert-two-changes-that-break-Android-builds.v7.patch) is incompatible with Clang 15, needs to be removed from patches/PATCHES.json manually
* For some reason libxml2 only creates lib64, not lib, needs to be copied over manually

Apart from that, this is missing:

* I can't get PGO to work, there are zero instructions by Google on this topic
