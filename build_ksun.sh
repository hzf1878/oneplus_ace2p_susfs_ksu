#!/bin/bash
set -e

OLD_DIR=$(pwd)
ANDROID_VERSION="android15"
KERNEL_VERSION="5.15"
SUSFS_VERSION="1.5.5"
CPUD="pineapple"

# Initialize repo and sync
rm kernel_platform/common/android/abi_gki_protected_exports_* || echo "No protected exports!"
rm kernel_platform/msm-kernel/android/abi_gki_protected_exports_* || echo "No protected exports!"
sed -i 's/ -dirty//g' kernel_platform/common/scripts/setlocalversion
sed -i 's/ -dirty//g' kernel_platform/msm-kernel/scripts/setlocalversion

# Set up KernelSU Next
cd kernel_platform
curl -LSs "https://raw.githubusercontent.com/rifsxd/KernelSU-Next/next/kernel/setup.sh" | bash -s next
cd KernelSU-Next
KSU_VERSION=$(expr $(/usr/bin/git rev-list --count HEAD) "+" 10200)
sed -i "s/DKSU_VERSION=16/DKSU_VERSION=${KSU_VERSION}/" kernel/Makefile

# Set up susfs
cd "$OLD_DIR"
git clone https://gitlab.com/simonpunk/susfs4ksu.git -b gki-${ANDROID_VERSION}-${KERNEL_VERSION}
git clone https://github.com/TheWildJames/kernel_patches.git
cd kernel_platform
cp ../susfs4ksu/kernel_patches/50_add_susfs_in_gki-${ANDROID_VERSION}-${KERNEL_VERSION}.patch ./common/
cp ../susfs4ksu/kernel_patches/fs/* ./common/fs/
cp ../susfs4ksu/kernel_patches/include/linux/* ./common/include/linux/

# Apply patches
cd KernelSU-Next
cp ../../kernel_patches/KernelSU-Next-Implement-SUSFS-v${SUSFS_VERSION}-Universal.patch ./
patch -p1 < KernelSU-Next-Implement-SUSFS-v${SUSFS_VERSION}-Universal.patch || true
cd ../common
patch -p1 < 50_add_susfs_in_gki-${ANDROID_VERSION}-${KERNEL_VERSION}.patch || true
cp ../../kernel_patches/69_hide_stuff.patch ./
patch -p1 -F 3 < 69_hide_stuff.patch

# Build kernel
cd "$OLD_DIR"
./kernel_platform/oplus/build/oplus_build_kernel.sh ${CPUD} gki

# Make AnyKernel3
git clone https://github.com/Kernel-SU/AnyKernel3 --depth=1
rm -rf ./AnyKernel3/.git
cp out/dist/Image ./AnyKernel3/

ZIPNAME="Anykernel3-KSUN-SUSFS-${KSU_VERSION}-OnePlus_ACE_2_Pro.zip"
cd ./AnyKernel3
zip -r "../$ZIPNAME" ./*
