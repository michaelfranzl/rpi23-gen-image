#!/bin/bash

DEBIAN_RELEASE="stretch" \
USER_NAME="pi" \
PASSWORD="xxx" \
APT_INCLUDES="i2c-tools,rng-tools,avahi-daemon,rsync,vim" \
UBOOTSRC_DIR="$(pwd)/../u-boot" \
KERNELSRC_DIR="$(pwd)/../linux" \
RPI_MODEL=3 \
HOSTNAME="rpi3" \
RPI_FIRMWARE_DIR="$(pwd)/../raspberry-firmware" \
ENABLE_REDUCE=true \
REDUCE_SSHD=true \
./rpi23-gen-image.sh
