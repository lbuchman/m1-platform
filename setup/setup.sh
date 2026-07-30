#!/bin/sh
set -e
TYPE=$1          # m1 or mnp
FIXTURE_NUM=$2   # e.g. 1, 2, 3..

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
cd "$SCRIPT_DIR"

# Interface names vary between PCs; setup.sh auto-detects the real names via
# `ip link` and substitutes them into the netplan template (see
# 01-network-manager-all.yaml) instead of hardcoding them.
# Mate disable screen timeout
# sshd no password login
# verify autossh service has correct port
# disable power mng in the control centre

usage() {
        echo "usage: $0 <m1|mnp> <fixtureNumber>"
}

if [ -z "$TYPE" ] || [ -z "$FIXTURE_NUM" ]; then
   usage
   exit 1
fi

# Auto-detect real wired ethernet interface names on this machine (order-
# matched to `ip link`, since names like enp0s31f6/enp1s0 vary by PC). First
# wired interface found -> DHCP uplink, second wired interface found ->
# static-IP test-fixture interface (also used as tfInterface below).
ETH_DHCP_IF=""
ETH_STATIC_IF=""
for ifc in $(ip -o link show | awk -F': ' '{print $2}'); do
    ifc=${ifc%%@*}
    case "$ifc" in
        lo|docker*|veth*|virbr*|br-*|wl*) continue ;;
    esac
    [ -d "/sys/class/net/$ifc/wireless" ] && continue
    if [ -z "$ETH_DHCP_IF" ]; then
        ETH_DHCP_IF="$ifc"
    elif [ -z "$ETH_STATIC_IF" ]; then
        ETH_STATIC_IF="$ifc"
    fi
done

if [ -z "$ETH_DHCP_IF" ] || [ -z "$ETH_STATIC_IF" ]; then
    echo "ERROR: could not detect two wired ethernet interfaces (found: ETH_DHCP_IF=$ETH_DHCP_IF ETH_STATIC_IF=$ETH_STATIC_IF)"
    exit 1
fi
echo "Detected interfaces: dhcp-uplink=$ETH_DHCP_IF static-fixture=$ETH_STATIC_IF"

# Calculate parameters based on type and fixture number
if [ "$TYPE" = "m1" ]; then
    SSHPORT=$((20010 + FIXTURE_NUM))
    HOSTNAME="m1testf${FIXTURE_NUM}"
    TESTSTATION="p${FIXTURE_NUM}"
    idx=$((FIXTURE_NUM - 1))
    PRODUCTNAME="m1-3200"
    FWDIR="stm32mp15-lenels2-m1"
    LAYOUTFILEPATH="flashlayout_st-ls2m1-image-core/optee/FlashLayout_emmc_stm32mp151f-ls2m1-optee.tsv"
elif [ "$TYPE" = "mnp" ]; then
    SSHPORT=$((20020 + FIXTURE_NUM))
    HOSTNAME="mnptestf${FIXTURE_NUM}"
    TESTSTATION="s${FIXTURE_NUM}"
    idx=$((8 + FIXTURE_NUM - 1))
    PRODUCTNAME="mnplus"
    FWDIR="stm32mp15-lenels2-mnp"
    LAYOUTFILEPATH="flashlayout_st-ls2m1c-image-core/optee/FlashLayout_emmc_stm32mp151f-ls2m1c-optee.tsv"
else
    echo "Invalid type: $TYPE. Use 'm1' or 'mnp'."
    usage
    exit 1
fi

# Calculate STARTMAC (1,000,000 addresses per station slot)
offset=$((idx * 1000000))
STARTMAC=$(printf "58:FC:C8:%02X:%02X:%02X" $(( (offset >> 16) & 0xFF )) $(( (offset >> 8) & 0xFF )) $(( offset & 0xFF )))

echo "Config: TYPE=$TYPE FIXTURE=$FIXTURE_NUM SSHPORT=$SSHPORT HOSTNAME=$HOSTNAME TESTSTATION=$TESTSTATION STARTMAC=$STARTMAC"

sudo DEBIAN_FRONTEND=noninteractive apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y net-tools openssh-server
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y sqlite3 arp-scan curl python3-pip autossh ethtool imagemagick libusb-1.0-0 libusb-0.1-4 cron
sudo chmod 4755  /usr/sbin/arp-scan

# teensy_loader_cli: headless Teensy flashing tool used by m1testBoardFw/
# mercury-testboard-fw (upload_protocol = teensy-cli), needs libusb-0.1-4.
sudo cp -f "$SCRIPT_DIR"/teensy_loader_cli /usr/sbin/teensy_loader_cli
sudo chown root:root /usr/sbin/teensy_loader_cli
sudo chmod 755 /usr/sbin/teensy_loader_cli

# Relax ImageMagick's default "path" policy that blocks reading draw commands
# from a file ("convert ... -draw @file.txt ..."), used by label generation.
# Ubuntu's stock policy.xml disables this via pattern="@*" for security on
# general-purpose/multi-tenant systems; this fixture is a trusted, closed
# appliance, so comment out just that one rule (idempotent - already-wrapped
# lines won't match again).
for policy in /etc/ImageMagick-6/policy.xml /etc/ImageMagick-7/policy.xml; do
    [ -f "$policy" ] || continue
    sudo sed -i -E 's#(<policy domain="path" rights="none" pattern="@\*"[[:space:]]*/>)#<!-- \1 -->#' "$policy"
done
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

# Passwordless sudo for lenel (fixture automation runs many unattended sudo commands)
echo 'lenel ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/lenel-nopasswd > /dev/null
sudo chmod 0440 /etc/sudoers.d/lenel-nopasswd
sudo visudo -c

sudo tar -xJf "$SCRIPT_DIR"/STMicroelectronics.txz -C /opt
rm -f /etc/netplan/*
sed -e "s/__ETH_DHCP_IF__/$ETH_DHCP_IF/" \
    -e "s/__ETH_STATIC_IF__/$ETH_STATIC_IF/" \
    "$SCRIPT_DIR"/01-network-manager-all.yaml > /etc/netplan/01-network-manager-all.yaml
sudo chown root:root /etc/netplan/01-network-manager-all.yaml
sudo chmod 600 /etc/netplan/01-network-manager-all.yaml
cp -f "$SCRIPT_DIR"/autossh.service /lib/systemd/system
systemctl restart autossh
sed -i 's/20007/'"${SSHPORT}"'/'  /lib/systemd/system/autossh.service

# Initialize /var/m1mtf from base archive and set station UID
mkdir -p /var/m1mtf
sudo tar -xzf "$SCRIPT_DIR"/fixture_m1mtf_base.tgz -C /var
rm -rf /var/m1mtf/logs/* /var/m1mtf/m1cli/* /var/m1mtf/backup/*
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
snap install --classic --dangerous  m1tfc.snap
snap install --classic --dangerous  m1tfc-rest-server.snap
snap install --dangerous  gui-react.snap

# Install configs to system-wide location /etc/m1platform
sudo mkdir -p /etc/m1platform

# Create config.json on target
cat << EOF > /etc/m1platform/config.json
{
  "conString": "DefaultEndpointsProtocol=https;AccountName=lenels2boardsprodsa;AccountKey=b9gso5tT+rbbfQLSUd68Bw5AtTGCdHrQRdMAdWowWNaRfxd9Li51LfTc7dhYP+ptu0Cox6GTk9kN+ASt5dI6rw==;EndpointSuffix=core.windows.net",
  "tfInterface": "${ETH_STATIC_IF}",
  "vendorSite": "${TESTSTATION}",
  "skipBatteryTest": false,
  "skipTestpointCheck": false,
  "skipRS485test": false,
  "productName": "${PRODUCTNAME}",
  "forceEppromOverwrite": false,
  "fwDir": "${FWDIR}",
  "layoutFilePath": "${LAYOUTFILEPATH}",
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
        "minVoltageAged": 2.9,
        "scale": 1
      }
    }
  ]
}
EOF

cp "$SCRIPT_DIR"/public.key /etc/m1platform/
sudo chown lenel: -R /etc/m1platform

#### $TESTSTATION

echo $HOSTNAME > /etc/hostname
#sed -i 's/F333/'"${$TESTSTATION}"'/' /etc/hosts
sudo chown lenel: * -R /home/lenel
sudo systemctl enable autossh.service
sudo chown lenel: -R  /var/m1mtf
netplan generate
m1client update
echo "setup script completed successfully"

