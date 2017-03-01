#!/bin/bash

DEBIAN_RELEASE="stretch" \
USER_NAME="pi" \
PASSWORD="xxx" \
APT_INCLUDES="i2c-tools,rng-tools,avahi-daemon,rsync,vim" \
UBOOTSRC_DIR="$(pwd)/../u-boot" \
KERNELSRC_DIR="$(pwd)/../linux-rpi" \
KERNEL_FLAVOR="raspberry" \
RPI_MODEL=3 \
RPI_FIRMWARE_DIR="$(pwd)/../raspberry-firmware" \
ENABLE_REDUCE=true \
REDUCE_SSHD=true \
./rpi23-gen-image.sh

# make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- bcm2709_defconfig
# make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- INSTALL_MOD_PATH=/mnt/raspcard modules_install
