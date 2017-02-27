#
# Setup users and security settings
#

# Load utility functions
. ./functions.sh

# Generate crypt(3) password string
# 500000 rounds for extra security. See https://michaelfranzl.com/2016/09/09/hashing-passwords-sha512-stronger-than-bcrypt-rounds/
ENCRYPTED_PASSWORD=`mkpasswd -m sha-512 -R 500000 "${PASSWORD}"`

# Setup default user
if [ "$ENABLE_USER" = true ] ; then
  chroot_exec adduser --gecos $USER_NAME --add_extra_groups \
	--disabled-password $USER_NAME 
  chroot_exec usermod -p "${ENCRYPTED_PASSWORD}" $USER_NAME
fi

# Setup root password or not
if [ "$ENABLE_ROOT" = true ] ; then
  chroot_exec usermod -p "${ENCRYPTED_PASSWORD}" root

  if [ "$ENABLE_ROOT_SSH" = true ] ; then
    if [ "$REDUCE_SSHD" = false ] ; then # dropbear doesn't have this config file
      sed -i "s|[#]*PermitRootLogin.*|PermitRootLogin yes|g" "${ETC_DIR}/ssh/sshd_config"
    fi
  fi
else
  # Set no root password to disable root login
  chroot_exec usermod -p \'!\' root
fi

# Enable serial console systemd style
if [ "$ENABLE_CONSOLE" = true ] ; then
  chroot_exec systemctl enable serial-getty\@ttyAMA0.service
fi
