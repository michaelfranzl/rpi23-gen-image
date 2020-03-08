#!/bin/bash
cd ..
cd linux
make mrproper
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- defconfig
cp ../rpi23-gen-image/working-rpi3-linux-config.txt .config
make -j2 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-
