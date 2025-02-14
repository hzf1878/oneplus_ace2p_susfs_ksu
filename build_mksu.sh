#!/bin/bash
set -e

OLD_DIR=$(pwd)
ANDROID_VERSION="android15"
KERNEL_VERSION="5.15"
SUSFS_VERSION="1.5.5"
CPUD="kalama"

# Initialize repo and sync
rm -f kernel_platform/common/android/abi_gki_protected_exports_* || echo "No protected exports!"
rm -f kernel_platform/msm-kernel/android/abi_gki_protected_exports_* || echo "No protected exports!"
sed -i 's/ -dirty//g' kernel_platform/build/kernel/kleaf/workspace_status_stamp.py

# Set up MKSU
cd kernel_platform
curl -LSs "https://raw.githubusercontent.com/5ec1cff/KernelSU/refs/heads/main/kernel/setup.sh" | bash -
cd KernelSU
git revert -m 1 $(git log --grep="remove devpts hook" --pretty=format:"%H") -n
KSU_VERSION=$(expr $(/usr/bin/git rev-list --count HEAD) "+" 10200)
sed -i "s/DKSU_VERSION=16/DKSU_VERSION=${KSU_VERSION}/" kernel/Makefile

# Set up susfs
cd "$OLD_DIR"
git clone https://gitlab.com/simonpunk/susfs4ksu.git -b gki-${ANDROID_VERSION}-${KERNEL_VERSION} --depth 1
git clone https://github.com/TheWildJames/kernel_patches.git --depth 1
cd kernel_platform
cp ../susfs4ksu/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch ./KernelSU/
cp ../kernel_patches/mksu_susfs.patch ./KernelSU/
cp ../susfs4ksu/kernel_patches/50_add_susfs_in_gki-${ANDROID_VERSION}-${KERNEL_VERSION}.patch ./common/
cp ../susfs4ksu/kernel_patches/fs/* ./common/fs/
cp ../susfs4ksu/kernel_patches/include/linux/* ./common/include/linux/

# Apply patches
cd KernelSU
patch -p1 --forward < 10_enable_susfs_for_ksu.patch || true
patch -p1 --forward < mksu_susfs.patch || true
cd ../common
patch -p1 < 50_add_susfs_in_gki-${ANDROID_VERSION}-${KERNEL_VERSION}.patch || true
cp ../../kernel_patches/69_hide_stuff.patch ./
patch -p1 -F 3 < 69_hide_stuff.patch

# Build kernel
cd "$OLD_DIR"
./kernel_platform/build_with_bazel.py -t ${CPUD} gki


# Make AnyKernel3
git clone https://github.com/Kernel-SU/AnyKernel3 --depth=1
rm -rf ./AnyKernel3/.git
cp out/dist/Image ./AnyKernel3/

ZIPNAME="Anykernel3-MKSU-SUSFS-${KSU_VERSION}-OnePlus_ACE_2_Pro.zip"
cd ./AnyKernel3
zip -r "../$ZIPNAME" ./*
