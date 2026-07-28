#!/bin/sh
set -e
TYPE=$1          # m1 or mnp
FIXTURE_NUM=$2   # e.g. 1, 2, 3..

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
cd "$SCRIPT_DIR"

# Interface names may not match
# Mate disable screen timeout
# sshd no password login
# Interface names may not match so mkake sure netplan names are correct
# sshd no password login
# verify autossh service has correct port
# disable power mng in the control centre
# change Imagemagic policy in /etc

usage() {
        echo "usage: $0 <m1|mnp> <fixtureNumber>"
}

if [ -z "$TYPE" ] || [ -z "$FIXTURE_NUM" ]; then
   usage
   exit 1
fi

# Calculate parameters based on type and fixture number
if [ "$TYPE" = "m1" ]; then
    SSHPORT=$((20010 + FIXTURE_NUM))
    HOSTNAME="m1testf${FIXTURE_NUM}"
    TESTSTATION="p${FIXTURE_NUM}"
    idx=$((FIXTURE_NUM - 1))
elif [ "$TYPE" = "mnp" ]; then
    SSHPORT=$((20020 + FIXTURE_NUM))
    HOSTNAME="mnptestf${FIXTURE_NUM}"
    TESTSTATION="s${FIXTURE_NUM}"
    idx=$((8 + FIXTURE_NUM - 1))
else
    echo "Invalid type: $TYPE. Use 'm1' or 'mnp'."
    usage
    exit 1
fi

# Calculate STARTMAC (1,000,000 addresses per station slot)
offset=$((idx * 1000000))
STARTMAC=$(printf "58:FC:C8:%02X:%02X:%02X" $(( (offset >> 16) & 0xFF )) $(( (offset >> 8) & 0xFF )) $(( offset & 0xFF )))

echo "Config: TYPE=$TYPE FIXTURE=$FIXTURE_NUM SSHPORT=$SSHPORT HOSTNAME=$HOSTNAME TESTSTATION=$TESTSTATION STARTMAC=$STARTMAC"

mkdir -p /var/m1mtf
sudo DEBIAN_FRONTEND=noninteractive apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y net-tools openssh-server
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y sqlite3 arp-scan curl python3-pip autossh ethtool imagemagick libusb-1.0-0 cron
sudo chmod 4755  /usr/sbin/arp-scan
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y pipx
sudo PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin pipx install --force brother_ql || sudo PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin pipx upgrade brother_ql
for app in brother_ql brother_ql_analyse brother_ql_create brother_ql_debug brother_ql_info brother_ql_print; do
  if [ ! -x "/usr/local/bin/$app" ]; then
    echo "ERROR: missing /usr/local/bin/$app after brother_ql install"
    exit 1
  fi
done
if systemctl cat ipp-usb.service >/dev/null 2>&1; then
  sudo systemctl disable ipp-usb >/dev/null 2>&1 || true
  sudo systemctl stop ipp-usb >/dev/null 2>&1 || true
fi
if dpkg -s ipp-usb >/dev/null 2>&1; then
  sudo apt-mark hold ipp-usb || true
  sudo DEBIAN_FRONTEND=noninteractive apt-get remove -y ipp-usb || true
fi
# sudo apt remove ippusbxd
# sudo apt-mark hold ippusbxd
sudo sed -i '/CMDLINE_LINUX_DEFAULT/c\CMDLINE_LINUX_DEFAULT="quiet pcie_aspm=off splash libata.noacpi=1"' /etc/default/grub
sudo update-grub
echo "PATH=\"/home/lenel/.local/bin:/opt/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin\"" > /etc/environment
sed -i '/BROTHER_QL_PRINTER/d;/BROTHER_QL_MODEL/d;/export BROTHER_QL_/d' /etc/environment
echo "BROTHER_QL_PRINTER=usb://0x04f9:0x209c" >> /etc/environment
echo "BROTHER_QL_MODEL=QL-810W" >> /etc/environment

for rule in "$SCRIPT_DIR"/rules.d/*; do
  [ -e "$rule" ] || continue
  cp -f "$rule" /etc/udev/rules.d/
done
mkdir -p /home/lenel/.ssh
echo "cp -f cloud.key id_rsa authorized_keys /home/lenel/.ssh"
cp -f "$SCRIPT_DIR"/cloud.key "$SCRIPT_DIR"/id_rsa "$SCRIPT_DIR"/authorized_keys /home/lenel/.ssh/
sudo chown lenel: .* -R /home/lenel/.ssh
chmod 700 /home/lenel/.ssh
sudo usermod -a -G dialout lenel
sudo tar -xJf "$SCRIPT_DIR"/STMicroelectronics.txz -C /opt
rm -f /etc/netplan/*
cp -f "$SCRIPT_DIR"/01-network-manager-all.yaml /etc/netplan
sudo chown root:root /etc/netplan/01-network-manager-all.yaml
sudo chmod 600 /etc/netplan/01-network-manager-all.yaml
cp -f "$SCRIPT_DIR"/autossh.service /lib/systemd/system
systemctl restart autossh
sed -i 's/20007/'"${SSHPORT}"'/'  /lib/systemd/system/autossh.service

# Initialize /var/m1mtf from base archive and set station UID
mkdir -p /var/m1mtf
sudo tar -xJf "$SCRIPT_DIR"/fixture_m1mtf_base.txz -C /var
sqlite3 /var/m1mtf/tf.db << SQL
CREATE TABLE IF NOT EXISTS records ( 
  vendorSerial TEXT PRIMARY KEY,
  dateAndTime TEXT,
  uid TEXT UNIQUE,
  secret TEXT UNIQUE,
  boardS2Serial TEXT UNIQUE,
  downloadedCumulus Integer,
  ictTestPassed Integer,
  functionalTestPassed Integer,
  flashProgrammed Integer,
  cpuSerial Text UNIQUE,
  cloudPushed Integer,
  errorcode Text
);
CREATE TABLE IF NOT EXISTS UID ( 
  uid TEXT UNIQUE NOT NULL
);
CREATE TABLE IF NOT EXISTS Perm ( 
  mac Integer,
  eeprom Integer
);
DELETE FROM UID;
INSERT INTO UID (uid) VALUES ('${STARTMAC}');
SQL

curl -sL https://deb.nodesource.com/setup_24.x -o /tmp/nodesource_setup.sh
sudo bash /tmp/nodesource_setup.sh
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs
sed -i '/m1client/d' /etc/crontab
sed -i '/systemctl/d' /etc/crontab
sed -i '/m1mtf/d' /etc/crontab

echo "@reboot root sleep 120  && systemctl restart autossh" >> /etc/crontab
echo "0  3  * * *   root /snap/bin/m1client update" >> /etc/crontab
echo "20  3  * * *   root /snap/bin/m1client synclogs" >> /etc/crontab
echo "40  3  * * *   root /snap/bin/m1client syncsecrets" >> /etc/crontab
echo "40  4  * * *   root /snap/bin/m1client backupdb" >> /etc/crontab
echo "40  6  * * *   root sudo sed -i '/root snap install/d'" >> /etc/crontab
echo "50  3  * * *   root find /var/m1mtf/synclogs -type f -mtime +365 -delete" >> /etc/crontab
echo "10  4  * * *   root find /var/m1mtf/logs -type d -mtime +365 -delete" >> /etc/crontab
echo "10  4  * * *   root find /var/m1mtf/m1cli -type f -mtime +365 -delete" >> /etc/crontab

snap install --classic --dangerous  m1client.snap 
snap install --classic --dangerous  m1tfd1.snap

# Install configs to system-wide location /etc/m1platform
sudo mkdir -p /etc/m1platform

# Create config.json on target
cat << EOF > /etc/m1platform/config.json
{
  "conString": "DefaultEndpointsProtocol=https;AccountName=lenels2boardsprodsa;AccountKey=b9gso5tT+rbbfQLSUd68Bw5AtTGCdHrQRdMAdWowWNaRfxd9Li51LfTc7dhYP+ptu0Cox6GTk9kN+ASt5dI6rw==;EndpointSuffix=core.windows.net",
  "tfInterface": "enp1s0",
  "vendorSite": "${TESTSTATION}",
  "skipBatteryTest": false,
  "skipTestpointCheck": false,
  "skipRS485test": false,
  "productName": "${TYPE}plus",
  "forceEppromOverwrite": false,
  "fwDir": "stm32mp15-lenels2-mnp",
  "layoutFilePath": "flashlayout_st-ls2m1c-image-core/optee/FlashLayout_emmc_stm32mp151f-ls2m1c-optee.tsv",
  "productionPassword": "1221",
  "debugPassword": "3443",
  "mtfDir": "/var/m1mtf",
  "programmingCommand": "/opt/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin/STM32_Programmer_CLI",
  "coinCellMinVoltageNew": 3.0,
  "coinCellMinVoltageUsed": 2.9
}
EOF

# Create calibration.json on target (Base template)
cat << EOF > /etc/m1platform/calibration.json
{
  "boards": [
    {
      "testPointsMnp": [],
      "testPointsM1": [],
      "ribbonCableA2DPins": [],
      "strikeReg": [],
      "ddrVoltageM1": {},
      "ddrVoltageMnp": {},
      "coinCellBattery": {
        "name": "BatCellBat",
        "minVoltageNew": 3.0,
        "minVoltageUsed": 2.9
      }
    }
  ]
}
EOF

sudo chown lenel: -R /etc/m1platform

# Also copy to snap writable area for the UI/REST server
cp /etc/m1platform/config.json /etc/m1platform/calibration.json /var/snap/m1tfd1/current/
cp "$SCRIPT_DIR"/public.key /var/snap/m1tfd1/current/

sed -i 's/20007/'"${SSHPORT}"'/'  /var/snap/m1tfd1/current/config.json

#### $TESTSTATION

echo $HOSTNAME > /etc/hostname
#sed -i 's/F333/'"${$TESTSTATION}"'/' /etc/hosts
sudo chown lenel: * -R /home/lenel
sudo systemctl enable autossh.service
sudo chown lenel: -R  /var/m1mtf
netplan generate
m1client update
echo "setup script completed successfully"

