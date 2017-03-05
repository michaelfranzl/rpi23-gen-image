logger -t "rc.firstboot" "Configuring network interface name"

INTERFACE_NAME=$(dmesg | perl -pe 's/.* (\w+): renamed from.*/\1/')

if [ ! -z "${INTERFACE_NAME}" ] ; then
  if [ -r "/etc/systemd/network/eth.network" ] ; then
    sed -i "s/eth0/${INTERFACE_NAME}/" /etc/systemd/network/eth.network
  fi
fi
