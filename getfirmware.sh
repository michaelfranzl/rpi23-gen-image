#!/bin/bash
cd ..
mkdir -p raspberry-firmware/boot
cd raspberry-firmware/boot
wget https://github.com/raspberrypi/firmware/raw/master/boot/bootcode.bin
wget https://github.com/raspberrypi/firmware/raw/master/boot/fixup_cd.dat
wget https://github.com/raspberrypi/firmware/raw/master/boot/fixup.dat
wget https://github.com/raspberrypi/firmware/raw/master/boot/fixup_x.dat
wget https://github.com/raspberrypi/firmware/raw/master/boot/start_cd.elf
wget https://github.com/raspberrypi/firmware/raw/master/boot/start.elf
wget https://github.com/raspberrypi/firmware/raw/master/boot/start_x.elf
