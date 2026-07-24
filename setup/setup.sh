#!/bin/sh
set -e
SSHPORT=$1
HOSTNAME=$2
STARTMAC=$3
TESTSTATION=$4

# Todo need to set test station ID in config.json,   

# Interface names may not match
# Mate disable screen timeout
# sshd no password login
# Interface names may not match so mkake sure netplan names are correct
# sshd no password login
# verify autossh service has correct port
# disable power mng in the control centre
# change Imagemagic policy in /etc

usage() {
        echo "usage: $0 SSHPORT HOSTNAME<m1testf?> STARTMAC<00:0F:A6:00:00:00> <test Station ID>"
}



if [ -z "$SSHPORT" ]; then
   usage
   exit 1
fi

if [ -z "$HOSTNAME" ]; then
   usage
   exit 1
fi


if [ -z "$STARTMAC" ]; then
   usage
   exit 1
fi


if [ -z "$TESTSTATION" ]; then
   usage
   exit 1
fi

echo SSHPORT=$SSHPORT HOSTNAME=$HOSTNAME STARTMAC=$STARTMAC

mkdir -p /home/lenel/m1mtf
sudo apt update
sudo apt upgrade
sudo apt install net-tools openssh-server
sudo apt install sqlite3 arp-scan curl  python3-pip autossh ethtool imagemagick-6.q16  libusb-1.0-0 cron
sudo chmod 4755  /usr/sbin/arp-scan
sudo apt install pipx
pipx install  brother_ql
sudo systemctl disable ipp-usb
sudo systemctl stop ipp-usb
sudo apt-mark hold ipp-usb
sudo apt remove ipp-usb
# sudo apt remove ippusbxd
# sudo apt-mark hold ippusbxd
sudo sed -i '/CMDLINE_LINUX_DEFAULT/c\CMDLINE_LINUX_DEFAULT="quiet pcie_aspm=off splash libata.noacpi=1"' /etc/default/grub
sudo update-grub
echo "PATH=\"/home/lenel/.local/bin:/home/lenel/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin\"" > /etc/environment
sed -i '/BROTHER_QL_PRINTER/d' /etc/environment
echo "export BROTHER_QL_PRINTER=usb://0x04f9:0x209c" >> /etc/environment
echo "export BROTHER_QL_MODEL=QL-810W" >> /etc/environment

cp -f rules.d/* /etc/udev/rules.d
mkdir -p /home/lenel/.ssh
echo "cp -f cloud.key id_rsa authorized_keys /home/lenel/.ssh"
cp -f cloud.key id_rsa authorized_keys /home/lenel/.ssh
sudo chown lenel: .* -R /home/lenel/.ssh
chmod 700 /home/lenel/.ssh
sudo usermod -a -G dialout lenel
cp -f M1-3200.desktop /home/lenel/Desktop
tar -xJf STMicroelectronics.txz -C /home/lenel
rm -f /etc/netplan/*
cp -f 01-network-manager-all.yaml /etc/netplan
cp -f autossh.service /lib/systemd/system
systemctl restart autossh
sed -i 's/20007/'"${SSHPORT}"'/'  /lib/systemd/system/autossh.service
curl -sL https://deb.nodesource.com/setup_20.x -o /tmp/nodesource_setup.sh
sudo bash /tmp/nodesource_setup.sh
sudo apt update
sudo apt  install nodejs

cp -f tf.db  /home/lenel/m1mtf
sqlite3 /home/lenel/m1mtf/tf.db "insert into uid values ('${STARTMAC}')"
sed -i '/m1client/d' /etc/crontab
sed -i '/systemctl/d' /etc/crontab
sed -i '/m1mtf/d' /etc/crontab

echo "@reboot root sleep 120  && systemctl restart autossh" >> /etc/crontab
echo "0  3  * * *   root /snap/bin/m1client update" >> /etc/crontab
echo "20  3  * * *   root /snap/bin/m1client synclogs" >> /etc/crontab
echo "40  3  * * *   root /snap/bin/m1client syncsecrets" >> /etc/crontab
echo "40  4  * * *   root /snap/bin/m1client backupdb" >> /etc/crontab
echo "40  6  * * *   root sudo sed -i '/root snap install/d'" >> /etc/crontab
echo "50  3  * * *   root find //home/lenel/m1mtf/synclogs -type f -mtime +365 -delete" >> /etc/crontab
echo "10  4  * * *   root find /home/lenel/m1mtf/logs -type d -mtime +365 -delete" >> /etc/crontab
echo "10  4  * * *   root find /home/lenel/m1mtf/m1cli -type f -mtime +365 -delete" >> /etc/crontab

snap install --classic --dangerous  m1client.snap 
snap install --classic --dangerous  m1tfd1.snap
cp config.json public.key /var/snap/m1tfd1/current
sed -i 's/20007/'"${SSHPORT}"'/'  /var/snap/m1tfd1/current/config.json

#### $TESTSTATION

echo $HOSTNAME > /etc/hostname
#sed -i 's/F333/'"${$TESTSTATION}"'/' /etc/hosts
sudo chown lenel: * -R /home/lenel
sudo systemctl enable autossh.service
chown lenel: -R  /home/lenel/m1mtf
netplan generate
m1client update

