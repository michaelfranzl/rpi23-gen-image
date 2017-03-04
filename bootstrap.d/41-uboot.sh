#
# Bootloader configuration
#

# Load utility functions
. ./functions.sh


install_readonly "${UBOOTSRC_DIR}/u-boot.bin" "${BOOT_DIR}/u-boot.bin"


# Install and setup U-Boot command file
install_readonly files/boot/uboot.mkimage "${BOOT_DIR}/uboot.mkimage"

printf "# Set the kernel boot command line\nsetenv bootargs \"earlyprintk ${CMDLINE}\"\n\n$(cat ${BOOT_DIR}/uboot.mkimage)" > "${BOOT_DIR}/uboot.mkimage"

if [ "$ENABLE_INITRAMFS" = true ] ; then
  # Convert generated initramfs for U-Boot using mkimage
  ${UBOOTSRC_DIR}/tools/mkimage -A "${KERNEL_ARCH}" -T ramdisk -C none -n "initramfs-${KERNEL_VERSION}" -d "/boot/firmware/initramfs-${KERNEL_VERSION}" "/boot/firmware/initramfs-${KERNEL_VERSION}.uboot"

  # Remove original initramfs file
  rm -f "${BOOT_DIR}/initramfs-${KERNEL_VERSION}"

  # Configure U-Boot to load generated initramfs
  printf "# Set initramfs file\nsetenv initramfs initramfs-${KERNEL_VERSION}.uboot\n\n$(cat ${BOOT_DIR}/uboot.mkimage)" > "${BOOT_DIR}/uboot.mkimage"
  printf "\nbootz \${kernel_addr_r} \${ramdisk_addr_r} \${fdt_addr_r}" >> "${BOOT_DIR}/uboot.mkimage"
    
else

  if [ "$RPI_MODEL" = 3 ] ; then
    printf "\nbootm \${kernel_addr_r} - \${fdt_addr_r}" >> "${BOOT_DIR}/uboot.mkimage"
  else
    # RPI_MODEL 2
    printf "\nbootz \${kernel_addr_r} - \${fdt_addr_r}" >> "${BOOT_DIR}/uboot.mkimage"
  fi
fi


DTB_FILE_BASENAME=$(basename $DTB_FILE)
sed -i "s/^\(setenv dtbfile \).*/\1${DTB_FILE_BASENAME}/" "${BOOT_DIR}/uboot.mkimage"


sed -i "s/^\(fatload mmc 0:1 \${kernel_addr_r} \).*/\1${KERNEL_IMAGE_TARGET}/" "${BOOT_DIR}/uboot.mkimage"

# Remove all leading blank lines
sed -i "/./,\$!d" "${BOOT_DIR}/uboot.mkimage"

# Generate U-Boot bootloader image
# http://www.denx.de/wiki/view/DULG/UBootScripts
# http://www.denx.de/wiki/view/DULG/UBootEnvVariables
${UBOOTSRC_DIR}/tools/mkimage -A "${KERNEL_ARCH}" -O linux -T script -C none -a 0x00000000 -e 0x00000000 -n "RPi${RPI_MODEL}" -d "${BOOT_DIR}/uboot.mkimage" "${BOOT_DIR}/boot.scr"

# The raspberry firmware blobs will boot u-boot
printf "\n# boot u-boot kernel\nkernel=u-boot.bin\n" >> "${BOOT_DIR}/config.txt"


if [ "$RPI_MODEL" = 3 ] ; then
  # See:
  # https://kernelnomicon.org/?p=682
  # https://www.raspberrypi.org/forums/viewtopic.php?f=72&t=137963
  printf "\n# run in 64bit mode\narm_control=0x200\n" >> "${BOOT_DIR}/config.txt"
  
  printf "\n# enable serial console\nenable_uart=1\n" >> "${BOOT_DIR}/config.txt"
fi

