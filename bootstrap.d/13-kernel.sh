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

# Copy zImage kernel to the boot directory
install_readonly "${KERNEL_DIR}/arch/${KERNEL_ARCH}/boot/zImage" "${BOOT_DIR}/${KERNEL_IMAGE}"

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

# Add encrypted root partition to cmdline.txt
if [ "$ENABLE_CRYPTFS" = true ] ; then
  CMDLINE=$(echo ${CMDLINE} | sed "s/mmcblk0p2/mapper\/${CRYPTFS_MAPPING} cryptdevice=\/dev\/mmcblk0p2:${CRYPTFS_MAPPING}/")
fi

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

# Setup boot with initramfs
if [ "$ENABLE_INITRAMFS" = true ] ; then
  echo "initramfs initramfs-${KERNEL_VERSION} followkernel" >> "${BOOT_DIR}/config.txt"
fi

# Install and setup fstab
install_readonly files/mount/fstab "${ETC_DIR}/fstab"

# Add encrypted root partition to fstab and crypttab
if [ "$ENABLE_CRYPTFS" = true ] ; then
  # Replace fstab root partition with encrypted partition mapping
  sed -i "s/mmcblk0p2/mapper\/${CRYPTFS_MAPPING}/" "${ETC_DIR}/fstab"

  # Add encrypted partition to crypttab and fstab
  install_readonly files/mount/crypttab "${ETC_DIR}/crypttab"
  echo "${CRYPTFS_MAPPING} /dev/mmcblk0p2 none luks" >> "${ETC_DIR}/crypttab"
fi

# Generate initramfs file
if [ "$ENABLE_INITRAMFS" = true ] ; then
  if [ "$ENABLE_CRYPTFS" = true ] ; then
    # Include initramfs scripts to auto expand encrypted root partition
    
    # Disable SSHD inside initramfs
    printf "#\n# DROPBEAR: [ y | n ]\n#\n\nDROPBEAR=n\n" >> "${ETC_DIR}/initramfs-tools/initramfs.conf"

    # Dummy mapping required by mkinitramfs
    echo "0 1 crypt $(echo ${CRYPTFS_CIPHER} | cut -d ':' -f 1) ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff 0 7:0 4096" | chroot_exec dmsetup create "${CRYPTFS_MAPPING}"

    # Generate initramfs with encrypted root partition support
    chroot_exec mkinitramfs -o "/boot/firmware/initramfs-${KERNEL_VERSION}" "${KERNEL_VERSION}"

    # Remove dummy mapping
    chroot_exec cryptsetup close "${CRYPTFS_MAPPING}"
  else
    # Generate initramfs without encrypted root partition support
    chroot_exec mkinitramfs -o "/boot/firmware/initramfs-${KERNEL_VERSION}" "${KERNEL_VERSION}"
  fi
fi

# Install sysctl.d configuration files
install_readonly files/sysctl.d/81-rpi-vm.conf "${ETC_DIR}/sysctl.d/81-rpi-vm.conf"
