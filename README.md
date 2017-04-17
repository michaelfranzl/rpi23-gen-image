# rpi23-gen-image

## Introduction

`rpi23-gen-image.sh` is an Debian Linux bootstrapping shell script for generating Debian OS images for Raspberry Pi 2 (RPi2, 32 bit) and Raspberry Pi 3 (RPi3, 64 bit) computers.


*Note by Michael Franzl:*

This is a fork of the original project by github user "drtyhlpr". My fork is developed into a slightly different direction:

* Only official Debian releases 9 ("Stretch") and newer are supported.
* Only the official/mainline/vanilla Linux kernel is supported (not the raspberry flavor kernel).
* The Linux kernel must be pre-cross-compiled on the PC running this script (instructions below).
* Only U-Boot booting is supported.
* The U-Boot sources must be pre-downloaded and pre-cross-compiled on the PC running this script (instructions below).
* An apt caching proxy server must be installed to save bandwidth (instructions below).
* The installation of the system to an SD card is done by simple copying or rsyncing, rather than creating, shrinking and expanding file system images.
* The FBTURBO option is removed in favor or the working VC4 OpenGL drivers of the mainline Linux kernel.

All of these simplifications are aimed at higher bootstrapping speed and maintainability of the script. For example, we want to *avoid* testing of all of the following combinations:

RPi2 with    u-boot, with official kernel  
RPi2 without u-boot, with official kernel  
RPi2 with    u-boot, with raspberry kernel  
RPi2 without u-boot, with raspberry kernel  
RPi3 with    u-boot, with official kernel  
RPi3 without u-boot, with official kernel  
RPi3 with    u-boot, with raspberry kernel  
RPi3 without u-boot, with raspberry kernel  

Thus, this script only supports:

RPi2 with u-boot with official kernel  
RPi3 with u-boot with official kernel


A **RPi2** (setting RPI_MODEL=2) is well supported. It will run the arm architecture of Debian, and a 32-bit kernel. You should get very good results, see my related blog posts:

https://michaelfranzl.com/2016/10/31/raspberry-pi-debian-stretch/

https://michaelfranzl.com/2016/11/10/setting-i2c-speed-raspberry-pi/

https://michaelfranzl.com/2016/11/10/reading-cpu-temperature-raspberry-pi-mainline-linux-kernel/



The newer **RPi3** (setting RPI_MODEL=3) is supported too. It will run the arm64 architecture of Debian, and a 64-bit kernel. The support of this board by the Linux kernel will very likely improve over time.


In general, this script is EXPERIMENTAL. I do not provide ISO file system images. It is better to master the process rather than to rely on precompiled images. In this sense, use this project only for educational purposes.


## Setting up host environment

Basically, we will deboostrap a minimal *Debian 9 ("Stretch")* system for the Raspberry on a regular PC running also *Debian 9 ("Stretch")*. Then we copy that system on a SD card, then boot it on the Raspberry.

We will work with the following directories:

    ~/workspace
      |- rpi23-gen-image
      |- linux
      |- u-boot
      |- raspberry-firmware

Set up your working directory:

    mkdir workspace
    cd workspace

Do the following steps as root user.
    

### Set up caching for apt

This way, you won't have to re-download hundreds of megabytes of Debian packages from the Debian server every time you run the `rpi23-gen-image` script.

    apt-get install apt-cacher-ng

Check its status page:

    http://localhost:3142
    

### Install dependencies

The following list of Debian packages must be installed on the build system because they are essentially required for the bootstrapping process.

    apt-get install debootstrap debian-archive-keyring qemu-user-static binfmt-support dosfstools rsync bmap-tools whois git bc device-tree-compiler dbus psmisc
    
For a RPi2, you also need:

    apt-get install crossbuild-essential-armhf
    
For a RPi3, you also need:

    apt-get install crossbuild-essential-arm64
    
    
    

    
### Kernel compilation

Get the latest Linux mainline kernel. This is a very large download, about 2GB. (For a smaller download of about 90 MB, consider downloading the latest stable kernel as .tar.xz from https://kernel.org.)

    git clone https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
    cd linux
    
Confirmed working revision (approx. version 4.10, Feb 2017): 60e8d3e11645a1b9c4197d9786df3894332c1685

    git checkout 60e8d3e116

Working configuration files for this Linux kernel revision are included in this repository. (`working-rpi2-linux-config.txt` and `working-rpi3-linux-config.txt`).
    
If you want to generate the default `.config` file that is also working on the Raspberry, execute

    make mrproper
    
For a RPi2:

    make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- multi_v7_defconfig
    
For a RPi3:
    
    make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- defconfig
    
    
Whichever `.config` file you have at this point, if you want to get more control as to what is enabled in the kernel, you can run the graphical configuration tool at this point:

    apt-get install libglib2.0-dev libgtk2.0-dev libglade2-dev
    
For a RPi2:

    make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- gconfig
    
For a RPi3:
    
    make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- gconfig

    
Before compiling the kernel, back up your `.config` file so that you don't lose it after the next `make mrproper`:

    cp .config ../kernelconfig-backup.txt
    

#### Compiling the kernel

Clean the sources:

    make mrproper
    
Optionally, copy your previously backed up `.config`:

    cp ../kernelconfig-backup.txt .config

Find out how many CPU cores you have to speed up compilation:

    NUM_CPU_CORES=$(grep -c processor /proc/cpuinfo)
    
Run the compilation on all CPU cores. This takes about 10 minutes on a modern PC:

For a RPi2:

    make -j${NUM_CPU_CORES} ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf-
    
For a RPi3:
    
    make -j${NUM_CPU_CORES} ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-
    
    
Verify that you have the required kernel image.

For a RPi2 this is:

    ./arch/arm/boot/zImage
    
For a RPi3 this is:

    ./arch/arm64/boot/Image.gz
    
    
### U-Boot bootloader compilation

    cd ..
    git clone git://git.denx.de/u-boot.git

Confirmed working revision: b24cf8540a85a9bf97975aadd6a7542f166c78a3

    git checkout b24cf8540a

Let's increase the maximum kernel image size from the default (8 MB) to 64 MB. This way, u-boot will be able to boot even larger kernels. Edit `./u-boot/include/configs/rpi.h` and add above the very last line (directly above "#endif"):

    #define CONFIG_SYS_BOOTM_LEN (64 * 1024 * 1024)

Find out how many CPU cores you have to speed up compilation:

    NUM_CPU_CORES=$(grep -c processor /proc/cpuinfo)

Compile for a RPi model 2 (32 bits):

    make -j${NUM_CPU_CORES} ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- rpi_2_defconfig all
    
Compile for a RPi model 3 (64 bits):
    
    make -j${NUM_CPU_CORES} ARCH=arm CROSS_COMPILE=aarch64-linux-gnu- rpi_3_defconfig all
    
Verify that you have the required bootloader file:

    ./u-boot.bin


    
### Pre-download Raspberry firmware

The Raspberry Pi still needs some binary proprietary blobs for booting. Get them:

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
    
Confirmed working revision: bf5201e9682bf36370bc31d26b37fd4d84e1cfca
    
    
### Build the system!


This is where you call the `rpi23-gen-image.sh` script contained in this repository.

    cd ../..
    git clone https://github.com/michaelfranzl/rpi23-gen-image.git
    cd rpi23-gen-image

For example:

    DEBIAN_RELEASE="stretch" \
    USER_NAME="pi" \
    PASSWORD="xxx" \
    APT_INCLUDES="i2c-tools,rng-tools,avahi-daemon,rsync,vim" \
    UBOOTSRC_DIR="$(pwd)/../u-boot" \
    KERNELSRC_DIR="$(pwd)/../linux" \
    RPI_MODEL=2 \
    HOSTNAME="rpi2" \
    RPI_FIRMWARE_DIR="$(pwd)/../raspberry-firmware" \
    ENABLE_REDUCE=true \
    REDUCE_SSHD=true \
    ./rpi23-gen-image.sh

You may want to modify the variables according to the section "Command-line parameters" below.

The file `example.sh` in this repostory contains a working example.


    
### Install the system on a SD card

Insert a SD card into the card reader of your host PC. You'll need two partitions on it. I'll leave as an exercise for the reader the creation of a  partition table according to the following output of `fdisk` for a 32GB card:

    Device         Boot  Start        End    Sectors    Size   Id  Type
    /dev/mmcblk0p1        2048     500000     497953  243.1M    c  W95 FAT32 (LBA)
    /dev/mmcblk0p2      501760   62552063   62050304   29.6G   83  Linux

The following commands will erase all contents of the SD card and install the system (copy via rsync) on the SD card:

    umount /dev/mmcblk0p1
    umount /dev/mmcblk0p2

    mkfs.vfat /dev/mmcblk0p1
    mkfs.ext4 /dev/mmcblk0p2

    mkdir -p /mnt/raspcard

    mount /dev/mmcblk0p2 /mnt/raspcard
    mkdir -p /mnt/raspcard/boot/firmware
    mount /dev/mmcblk0p1 /mnt/raspcard/boot/firmware

    rsync -a ./images/stretch/build/chroot/ /mnt/raspcard

    umount /dev/mmcblk0p1
    umount /dev/mmcblk0p2
    

*Note about SD cards:* Cheap (or sometimes even professional) SD cards can be weird at times. I've repeatedly noticed corrupt/truncated files even after proper rsync and proper umount on different brand new SD cards. TODO: Add a method to verify all file checksums after rsync.


    
### Try booting the Raspberry

Insert the SD card into the Raspberry Pi, and if everything went well, you should see a console-based login prompt on the screen. Login with the login details you've passed into the script (USER_NAME and PASSWORD).

Alternatively, if you have included "avahi-daemon" in your APT_INCLUDES, you don't need a screen and keyboard and can simply log in via SSH from another computer, even without knowing the Rasberry's dynamic/DHCP IP address (replace "hostname" and "username" with what you have set as USER_NAME and HOSTNAME above):

    ssh username@hostname.local


### Finishing touches directly on the Raspberry

Remember to change usernames, passwords, and SSH keys!


#### Check uber-low RAM usage

Running `top` shows that the freshly booted system uses only 23 MB out of the availabl 1GB RAM! Confirmed for both RPi2 and RPi3.


#### Network Time Synchronization

The Raspberry doesn't have a real time clock. But the default `systemd` conveniently syncs time from the network. Check the output of `timedatectl`. Confirmed working for both RPi2 and RPi3.


#### Hardware Random Number Generator

The working device node is available at `/dev/hwrng`. Confirmed working for both RPi2 and RPi3.


#### I2C Bus

Also try I2C support:

    apt-get install ic2-tools
    i2cdetect -y 0

Confirmed working for both RPi2 and RPi3.


#### Test onboard LEDs

As of the kernel revision referenced above, this only works on the RPi2. The RPi3  has only the red PWR LED on all the time, but otherwise is working fine.

By default, the green onboard LED of the RPi blinks in a heartbeat pattern according to the system load (this is done by kernel feature LEDS_TRIGGER_HEARTBEAT).

To use the green ACT LED as an indicator for disc access, execute:

    echo mmc0 > /sys/class/leds/ACT/trigger

To toggle the red PWR LED:

    echo 0 > /sys/class/leds/PWR/brightness # Turn off
    echo 1 > /sys/class/leds/PWR/brightness # Turn on 
    
Or use the red PWR LED as heartbeat indicator:

    echo heartbeat > /sys/class/leds/PWR/trigger
    
    
#### Notes about systemd

`systemd` now replaces decades-old low-level system administration tools. Here is a quick cheat sheet:

Reboot machine:

    systemctl reboot
    
Halt machine (this actually turns off the RPi):

    systemctl halt
    
Show all networking interfaces:

    networkctl
    
Show status of the Ethernet adapter:

    networkctl status eth0
    
Show status of the local DNS caching client:

    systemctl status systemd-resolved
    

#### Install GUI

Successfully tested on the RPi2 and RPI3.

If you want to install a graphical user interface, I would suggest the light-weight LXDE window manager. Gnome is still too massive to run even on a GPU-accelerated Raspberry.

    apt-get install lightdm lxde lxde-common task-lxde-desktop

Reboot, and you should be greeted by the LightDM greeter screen!

    
    
#### Test GPU acceleration via VC4 kernel driver

Successfully tested on the RPi2 and RPI3.

    apt-get install mesa-utils
    glxgears
    glxinfo | grep '^OpenGL'
    
Glxinfo should output:

    OpenGL vendor string: Broadcom
    OpenGL renderer string: Gallium 0.4 on VC4
    OpenGL version string: 2.1 Mesa 12.0.3
    OpenGL shading language version string: 1.20
    OpenGL ES profile version string: OpenGL ES 2.0 Mesa 12.0.3
    OpenGL ES profile shading language version string: OpenGL ES GLSL ES 1.0.16


    


    
### Kernel compilation directly on the Rasberry

Only successfully tested on the RPi2. Not yet tested on the RPI3.

In case you want to compile and deploy another Mainline Linux kernel directly on the Raspberry, proceed as described above, but you don't need the `ARCH` and `CROSS_COMPILE` flags. Instead, you need the `-fno-pic` compiler flag for modules. The following is just the compilation step (configuration and installation omitted):

    make -j5 CFLAGS_MODULE="-fno-pic"
    make modules_install


    

## Documentaion of all command-line parameters

The script accepts certain command-line parameters to enable or disable specific OS features, services and configuration settings. These parameters are passed to the `rpi23-gen-image.sh` script via (simple) shell-variables. Unlike environment shell-variables (simple) shell-variables are defined at the beginning of the command-line call of the `rpi23-gen-image.sh` script.


#### APT settings:
##### `APT_SERVER`="ftp.debian.org"
Set Debian packages server address. Choose a server from the list of Debian worldwide [mirror sites](https://www.debian.org/mirror/list). Using a nearby server will probably speed-up all required downloads within the bootstrapping process.

##### `APT_PROXY`=""
Set Proxy server address. Using a local Proxy-Cache like `apt-cacher-ng` will speed-up the bootstrapping process because all required Debian packages will only be downloaded from the Debian mirror site once.

##### `APT_INCLUDES`=""
A comma separated list of additional packages to be installed during bootstrapping.

#### General system settings:
##### `RPI_MODEL`=2
Specifiy the target Raspberry Pi hardware model. The script at this time supports the Raspberry Pi models `2` and `3`.

##### `DEBIAN_RELEASE`="stretch"
Set the desired Debian release name. Only use "stretch" or newer.

##### `HOSTNAME`="rpi$RPI_MODEL-$RELEASE"
Set system host name. It's recommended that the host name is unique in the corresponding subnet.

##### `PASSWORD`="raspberry"
Set system `root` password. The same password is used for the created user `pi`. It's **STRONGLY** recommended that you choose a custom password.

##### `DEFLOCAL`="en_US.UTF-8"
Set default system locale. This setting can also be changed inside the running OS using the `dpkg-reconfigure locales` command. Please note that on using this parameter the script will automatically install the required packages `locales`, `keyboard-configuration` and `console-setup`.

##### `TIMEZONE`="Europe/Berlin"
Set default system timezone. All available timezones can be found in the `/usr/share/zoneinfo/` directory. This setting can also be changed inside the running OS using the `dpkg-reconfigure tzdata` command.

#### Keyboard settings:
These options are used to configure keyboard layout in `/etc/default/keyboard` for console and Xorg. These settings can also be changed inside the running OS using the `dpkg-reconfigure keyboard-configuration` command.

##### `XKB_MODEL`=""
Set the name of the model of your keyboard type.

##### `XKB_LAYOUT`=""
Set the supported keyboard layout(s).

##### `XKB_VARIANT`=""
Set the supported variant(s) of the keyboard layout(s).

##### `XKB_OPTIONS`=""
Set extra xkb configuration options.

#### Networking settings (DHCP):
This parameter is used to set up networking auto configuration in `/etc/systemd/network/eth.network`.

#####`ENABLE_DHCP`=true
Set the system to use DHCP. This requires an DHCP server running in your local network.

#### Networking settings (static):
These parameters are used to set up a static networking configuration in `/etc/systemd/network/eth.network`. The following static networking parameters are only supported if `ENABLE_DHCP` was set to `false`.

#####`NET_ADDRESS`=""
Set a static IPv4 or IPv6 address and its prefix, separated by "/", eg. "192.169.0.3/24".

#####`NET_GATEWAY`=""
Set the IP address for the default gateway.

#####`NET_DNS_1`=""
Set the IP address for the first DNS server.

#####`NET_DNS_2`=""
Set the IP address for the second DNS server.

#####`NET_DNS_DOMAINS`=""
Set the default DNS search domains to use for non fully qualified host names.

#####`NET_NTP_1`=""
Set the IP address for the first NTP server.

#####`NET_NTP_2`=""
Set the IP address for the second NTP server.

#### Basic system features:
##### `ENABLE_CONSOLE`=true
Enable serial console interface. Recommended if no monitor or keyboard is connected to the RPi2/3. In case of problems fe. if the network (auto) configuration failed - the serial console can be used to access the system.

##### `ENABLE_IPV6`=true
Enable IPv6 support. The network interface configuration is managed via systemd-networkd.

##### `ENABLE_SSHD`=true
Install and enable OpenSSH service. The default configuration of the service doesn't allow `root` to login. Please use the user `pi` instead and `su -` or `sudo` to execute commands as root.

##### `ENABLE_NONFREE`=false
Allow the installation of non-free Debian packages that do not comply with the DFSG. This is required to install closed-source firmware binary blobs.

##### `ENABLE_WIRELESS`=false
Download and install the [closed-source firmware binary blob](https://github.com/RPi-Distro/firmware-nonfree/tree/master/brcm80211/brcm) that is required to run the internal wireless interface of the Raspberry Pi model `3`. This parameter is ignored if the specified `RPI_MODEL` is not `3`.

##### `ENABLE_RSYSLOG`=true
If set to false, disable and uninstall rsyslog (so logs will be available only in journal files)

##### `ENABLE_SOUND`=false
Enable sound hardware and install Advanced Linux Sound Architecture.

##### `ENABLE_DBUS`=true
Install and enable D-Bus message bus. Please note that systemd should work without D-bus but it's recommended to be enabled.

##### `ENABLE_XORG`=false
Install Xorg open-source X Window System.

##### `ENABLE_WM`=""
Install a user defined window manager for the X Window System. To make sure all X related package dependencies are getting installed `ENABLE_XORG` will automatically get enabled if `ENABLE_WM` is used. The `rpi23-gen-image.sh` script has been tested with the following list of window managers: `blackbox`, `openbox`, `fluxbox`, `jwm`, `dwm`, `xfce4`, `awesome`.

#### Advanced system features:
##### `ENABLE_MINBASE`=false
Use debootstrap script variant `minbase` which only includes essential packages and apt. This will reduce the disk usage by about 65 MB.

##### `ENABLE_REDUCE`=false
Reduce the disk space usage by deleting packages and files. See `REDUCE_*` parameters for detailed information.

##### `ENABLE_IPTABLES`=false
Enable iptables IPv4/IPv6 firewall. Simplified ruleset: Allow all outgoing connections. Block all incoming connections except to OpenSSH service.

##### `ENABLE_USER`=true
Create non-root user with password set via $PASSWORD variable. Unless overridden with `USER_NAME`=user, username will be `pi`.

##### `USER_NAME`=pi
Non-root user to create.  Ignored if `ENABLE_USER`=false

##### `ENABLE_ROOT`=true
Set root user password so root login will be enabled

##### `ENABLE_ROOT_SSH`=true
Enable password root login via SSH. May be a security risk with default
password, use only in trusted environments.

##### `ENABLE_HARDNET`=false
Enable IPv4/IPv6 network stack hardening settings.

##### `CHROOT_SCRIPTS`=""
Path to a directory with scripts that should be run in the chroot before the image is finally built. Every executable file in this directory is run in lexicographical order.

##### `ENABLE_IFNAMES`=true
Enable automatic assignment of predictable, stable network interface names for all local Ethernet, WLAN interfaces. This might create complex and long interface names. This parameter is only supported if the Debian release `stretch` is used. See: https://www.freedesktop.org/wiki/Software/systemd/PredictableNetworkInterfaceNames/

#### Kernel, Firmware, and bootloader:

##### `KERNEL_HEADERS`=true
Install kernel headers with built kernel.

##### `KERNELSRC_DIR`=""
Path to a directory of a pre-built and cross-compiled Linux kernel.

#### `KERNEL_FLAVOR`="raspberry"
Specifies the flavor of Linux kernel pointed at by `KERNELSRC_DIR`. Either "raspberry" or "vanilla".

##### `UBOOTSRC_DIR`=""
Path to a directory of a pre-built and cross-compiled u-boot bootoader. Download it with `git clone git://git.denx.de/u-boot.git`.

##### `RPI_FIRMWARE_DIR`=""
The directory containing a local copy of the firmware from the [RaspberryPi firmware project](https://github.com/raspberrypi/firmware). The directory must be specified and must exist.

#### Reduce disk usage:
The following list of parameters is ignored if `ENABLE_REDUCE`=false.

##### `REDUCE_APT`=true
Configure APT to use compressed package repository lists and no package caching files.

##### `REDUCE_DOC`=true
Remove all doc files (harsh). Configure APT to not include doc files on future `apt-get` package installations.

##### `REDUCE_MAN`=true
Remove all man pages and info files (harsh).  Configure APT to not include man pages on future `apt-get` package installations.

##### `REDUCE_VIM`=false
Replace `vim-tiny` package by `levee` a tiny vim clone.

##### `REDUCE_BASH`=false
Remove `bash` package and switch to `dash` shell (experimental).

##### `REDUCE_HWDB`=true
Remove PCI related hwdb files (experimental).

##### `REDUCE_SSHD`=true
Replace `openssh-server` with `dropbear`.

##### `REDUCE_LOCALE`=true
Remove all `locale` translation files.



## Understanding the script
The functions of this script that are required for the different stages of the bootstrapping are split up into single files located inside the `bootstrap.d` directory. During the bootstrapping every script in this directory gets executed in lexicographical order:

| Script | Description |
| --- | --- |
| `10-bootstrap.sh` | Debootstrap basic system |
| `11-apt.sh` | Setup APT repositories |
| `12-locale.sh` | Setup Locales and keyboard settings |
| `13-kernel.sh` | Build and install RPi2/3 Kernel |
| `20-networking.sh` | Setup Networking |
| `21-firewall.sh` | Setup Firewall |
| `30-security.sh` | Setup Users and Security settings |
| `31-logging.sh` | Setup Logging |
| `41-uboot.sh` | Build and Setup U-Boot |
| `50-firstboot.sh` | First boot actions |
| `99-reduce.sh` | Reduce the disk space usage |

All the required configuration files that will be copied to the generated OS image are located inside the `files` directory. It is not recommended to modify these configuration files manually.

| Directory | Description |
| --- | --- |
| `apt` | APT management configuration files |
| `boot` | Boot and RPi2/3 configuration files |
| `dpkg` | Package Manager configuration |
| `etc` | Configuration files and rc scripts |
| `firstboot` | Scripts that get executed on first boot  |
| `initramfs` | Initramfs scripts |
| `iptables` | Firewall configuration files |
| `locales` | Locales configuration |
| `modules` | Kernel Modules configuration |
| `mount` | Fstab configuration |
| `network` | Networking configuration files |
| `sysctl.d` | Swapping and Network Hardening configuration |
| `xorg` | fbturbo Xorg driver configuration |

Debian custom packages, i.e. those not in the debian repositories, can be installed by placing them in the `packages` directory. They are installed immediately after packages from the repositories are installed. Any dependencies listed in the custom packages will be downloaded automatically from the repositories. Do not list these custom packages in `APT_INCLUDES`.

Scripts in the custom.d directory will be executed after all other installation is complete but before the image is created.

## Logging of the bootstrapping process
All information related to the bootstrapping process and the commands executed by the `rpi23-gen-image.sh` script can easily be saved into a logfile. The common shell command `script` can be used for this purpose:

```shell
script -c 'APT_SERVER=ftp.de.debian.org ./rpi23-gen-image.sh' ./build.log
```
