#
# Build and Setup RPi2/3 Kernel
#

# Load utility functions
. ./functions.sh


# Copy kernel sources
mkdir -p "${KERNEL_DIR}"
rsync -a --exclude=".git" "${KERNELSRC_DIR}/" "${KERNEL_DIR}/"


# Install kernel modules
if [ "$ENABLE_REDUCE" = true ] ; then
  make -C "${KERNEL_DIR}" ARCH="${KERNEL_ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" INSTALL_MOD_STRIP=1 INSTALL_MOD_PATH=../../.. modules_install
  
else
  make -C "${KERNEL_DIR}" ARCH="${KERNEL_ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" INSTALL_MOD_PATH=../../.. modules_install

  # Install kernel firmware
  make -C "${KERNEL_DIR}" ARCH="${KERNEL_ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" INSTALL_FW_PATH=../../../lib firmware_install
fi



# Install kernel headers
if [ "$KERNEL_HEADERS" = true ] ; then
  make -C "${KERNEL_DIR}" ARCH="${KERNEL_ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" INSTALL_HDR_PATH=../.. headers_install
fi


# Prepare boot (firmware) directory
mkdir "${BOOT_DIR}"

# Get kernel release version
KERNEL_VERSION=`cat "${KERNEL_DIR}/include/config/kernel.release"`

# Copy kernel configuration file to the boot directory
install_readonly "${KERNEL_DIR}/.config" "${R}/boot/config-${KERNEL_VERSION}"


# Copy device tree binaries
install_readonly "${KERNEL_DIR}/arch/${KERNEL_ARCH}/boot/dts/${DTB_FILE}" "${BOOT_DIR}/"



if [ "$RPI_MODEL" = 3 ] ; then
  # The default Linux kernel 'make' target generates an uncompressed 'Image' and a gzip-compresesd 'Image.gz'. We use latter and wrap it into an uImage. u-boot can decompress gzip images.
  
  # Load and entry address can be gotten by inspecting `text_offset` (bytes 64-128) of the uncompressed Linux 'Image' (0x80000). See https://www.kernel.org/doc/Documentation/arm64/booting.txt
  
  ${UBOOTSRC_DIR}/tools/mkimage -A ${KERNEL_ARCH} -O linux -T kernel -C gzip -a 0x80000 -e 0x80000 -d "${KERNEL_DIR}/arch/${KERNEL_ARCH}/boot/${KERNEL_IMAGE_SOURCE}" "${BOOT_DIR}/${KERNEL_IMAGE_TARGET}"
  
else
  # RPI_MODEL 2
  
  # The default Linux kernel 'make' target generates a self-extracting 'zImage'. From the perspective of u-boot this image is uncompressed because u-boot doesn't have to do anything to decompress it. So we don't have to wrap it with the `mkimage` command.
  install_readonly "${KERNEL_DIR}/arch/${KERNEL_ARCH}/boot/${KERNEL_IMAGE_SOURCE}" "${BOOT_DIR}/${KERNEL_IMAGE_TARGET}"
fi


# Clean the kernel sources in the chroot
make -C "${KERNEL_DIR}" ARCH="${KERNEL_ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" mrproper



cp ${RPI_FIRMWARE_DIR}/boot/bootcode.bin ${BOOT_DIR}/bootcode.bin
cp ${RPI_FIRMWARE_DIR}/boot/fixup_cd.dat ${BOOT_DIR}/fixup_cd.dat
cp ${RPI_FIRMWARE_DIR}/boot/fixup.dat ${BOOT_DIR}/fixup.dat
cp ${RPI_FIRMWARE_DIR}/boot/fixup_x.dat ${BOOT_DIR}/fixup_x.dat
cp ${RPI_FIRMWARE_DIR}/boot/start_cd.elf ${BOOT_DIR}/start_cd.elf
cp ${RPI_FIRMWARE_DIR}/boot/start.elf ${BOOT_DIR}/start.elf
cp ${RPI_FIRMWARE_DIR}/boot/start_x.elf ${BOOT_DIR}/start_x.elf




# Setup firmware boot cmdline
CMDLINE="dwc_otg.lpm_enable=0 root=/dev/mmcblk0p2 rootfstype=ext4 rootflags=commit=100,data=writeback elevator=deadline rootwait console=tty1 cma=256M@512M"


# Add serial console support
if [ "$ENABLE_CONSOLE" = true ] ; then
  CMDLINE="${CMDLINE} console=ttyAMA0,115200 kgdboc=ttyAMA0,115200"
fi

# Remove IPv6 networking support
if [ "$ENABLE_IPV6" = false ] ; then
  CMDLINE="${CMDLINE} ipv6.disable=1"
fi

# Automatically assign predictable network interface names
if [ "$ENABLE_IFNAMES" = false ] ; then
  CMDLINE="${CMDLINE} net.ifnames=0"
else
  CMDLINE="${CMDLINE} net.ifnames=1"
fi

CMDLINE="${CMDLINE} init=/bin/systemd"

# Install firmware boot cmdline
echo "${CMDLINE}" > "${BOOT_DIR}/cmdline.txt"

# Install firmware config
install_readonly files/boot/config.txt "${BOOT_DIR}/config.txt"


# Install and setup fstab
install_readonly files/mount/fstab "${ETC_DIR}/fstab"

# Install sysctl.d configuration files
install_readonly files/sysctl.d/81-rpi-vm.conf "${ETC_DIR}/sysctl.d/81-rpi-vm.conf"
