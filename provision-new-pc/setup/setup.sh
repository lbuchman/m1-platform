#!/bin/sh
set -e
TYPE=$1          # m1 or mnp
FIXTURE_NUM=$2   # e.g. 1, 2, 3..
ETH_DHCP_IF=$3   # optional: Internet/uplink interface name (skips prompt)
ETH_STATIC_IF=$4 # optional: TestFixture interface name (skips prompt)

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
cd "$SCRIPT_DIR"

# Interface names vary between PCs, so setup.sh asks for the real names and
# substitutes them into the netplan template (see 01-network-manager-all.yaml)
# instead of hardcoding or auto-detecting them.
# Mate disable screen timeout
# sshd no password login
# verify autossh service has correct port
# disable power mng in the control centre

usage() {
        echo "usage: $0 <m1|mnp> <fixtureNumber> [internetInterface] [testFixtureInterface]"
}

if [ -z "$TYPE" ] || [ -z "$FIXTURE_NUM" ]; then
   usage
   exit 1
fi

# List wired ethernet interfaces on this machine as a hint for the operator
# (names like enp0s31f6/enp1s0 vary by PC).
echo "Available wired ethernet interfaces:"
for ifc in $(ip -o link show | awk -F': ' '{print $2}'); do
    ifc=${ifc%%@*}
    case "$ifc" in
        lo|docker*|veth*|virbr*|br-*|wl*) continue ;;
    esac
    [ -d "/sys/class/net/$ifc/wireless" ] && continue
    echo "  $ifc"
done

# If not supplied as arguments, prompt the operator on the controlling
# terminal (falls back here rather than reading a possibly-piped stdin).
if [ -z "$ETH_DHCP_IF" ]; then
    if [ ! -e /dev/tty ]; then
        echo "ERROR: no controlling terminal available to prompt for interface names."
        echo "Pass them as arguments instead: $0 $TYPE $FIXTURE_NUM <internetInterface> <testFixtureInterface>"
        exit 1
    fi
    printf "Enter the Internet/uplink interface name: " > /dev/tty
    read -r ETH_DHCP_IF < /dev/tty
fi
if [ -z "$ETH_STATIC_IF" ]; then
    if [ ! -e /dev/tty ]; then
        echo "ERROR: no controlling terminal available to prompt for interface names."
        echo "Pass them as arguments instead: $0 $TYPE $FIXTURE_NUM <internetInterface> <testFixtureInterface>"
        exit 1
    fi
    printf "Enter the TestFixture interface name: " > /dev/tty
    read -r ETH_STATIC_IF < /dev/tty
fi

if [ ! -d "/sys/class/net/$ETH_DHCP_IF" ]; then
    echo "ERROR: interface '$ETH_DHCP_IF' not found on this machine"
    exit 1
fi
if [ ! -d "/sys/class/net/$ETH_STATIC_IF" ]; then
    echo "ERROR: interface '$ETH_STATIC_IF' not found on this machine"
    exit 1
fi
echo "Using interfaces: internet=$ETH_DHCP_IF testfixture=$ETH_STATIC_IF"

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
# acm-testboard-fw (upload_protocol = teensy-cli), needs libusb-0.1-4.
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
# id_rsa.pub is never deployed: a stale .pub sidecar makes ssh offer the wrong
# public key instead of deriving it from id_rsa, breaking auth silently.
rm -f /home/lenel/.ssh/id_rsa.pub
sudo chown lenel: .* -R /home/lenel/.ssh
chmod 700 /home/lenel/.ssh
sudo usermod -a -G dialout lenel

# Passwordless sudo for lenel (fixture automation runs many unattended sudo commands)
echo 'lenel ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/lenel-nopasswd > /dev/null
sudo chmod 0440 /etc/sudoers.d/lenel-nopasswd
sudo visudo -c

rm -f /etc/netplan/*
sed -e "s/__Internet/$ETH_DHCP_IF/" \
    -e "s/__TestFixture/$ETH_STATIC_IF/" \
    "$SCRIPT_DIR"/01-network-manager-all.yaml > /etc/netplan/01-network-manager-all.yaml
sudo chown root:root /etc/netplan/01-network-manager-all.yaml
sudo chmod 600 /etc/netplan/01-network-manager-all.yaml
cp -f "$SCRIPT_DIR"/autossh.service /lib/systemd/system
systemctl restart autossh
sed -i 's/20007/'"${SSHPORT}"'/'  /lib/systemd/system/autossh.service

# Initialize /var/m1mtf and populate firmware from the Azure `deployment`
# container. The manifest is downloaded first so the firmware download URL
# and expected sha512 always come from the manifest, never hardcoded here.
mkdir -p /var/m1mtf /var/m1mtf/logs /var/m1mtf/m1cli /var/m1mtf/backup /var/m1mtf/synclogs

# conString comes from azureStorage.json, staged into the deploy payload by
# deploy.sh; it is never hardcoded here and never committed to the repo.
if [ ! -f "$SCRIPT_DIR/azureStorage.json" ]; then
    echo "ERROR: $SCRIPT_DIR/azureStorage.json not found"
    exit 1
fi

if ! command -v node >/dev/null 2>&1; then
  curl -sL https://deb.nodesource.com/setup_24.x -o /tmp/nodesource_setup.sh
  sudo bash /tmp/nodesource_setup.sh
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs
fi

if ! command -v node >/dev/null 2>&1; then
  echo "ERROR: node install failed"
  exit 1
fi

CON_STRING=$(node -e "console.log(require('$SCRIPT_DIR/azureStorage.json').conString)")
if [ -z "$CON_STRING" ] || [ "$CON_STRING" = "undefined" ]; then
    echo "ERROR: conString missing from $SCRIPT_DIR/azureStorage.json"
    exit 1
fi

if ! command -v az >/dev/null 2>&1; then
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
fi

MANIFEST_TMP=$(mktemp)
az storage blob download --container-name deployment --name manifestFile.json --file "$MANIFEST_TMP" --connection-string "$CON_STRING" --no-progress --output none

if [ "$TYPE" = "m1" ]; then
    MANIFEST_KEY="m1firmware"
else
    MANIFEST_KEY="mnpfirmware"
fi

FW_URL=$(node -e "
const fs = require('fs');
const manifest = JSON.parse(fs.readFileSync('$MANIFEST_TMP', 'utf8'));
const entry = manifest.find((e) => e.filetype === '$MANIFEST_KEY');
if (!entry) { process.exit(1); }
console.log(entry.filename);
")
FW_SHA512=$(node -e "
const fs = require('fs');
const manifest = JSON.parse(fs.readFileSync('$MANIFEST_TMP', 'utf8'));
const entry = manifest.find((e) => e.filetype === '$MANIFEST_KEY');
if (!entry) { process.exit(1); }
console.log(entry.hash);
")

STM32PROG_URL=$(node -e "
const fs = require('fs');
const manifest = JSON.parse(fs.readFileSync('$MANIFEST_TMP', 'utf8'));
const entry = manifest.find((e) => e.filetype === 'stm32programmer');
if (!entry) { process.exit(1); }
console.log(entry.filename);
")
STM32PROG_SHA512=$(node -e "
const fs = require('fs');
const manifest = JSON.parse(fs.readFileSync('$MANIFEST_TMP', 'utf8'));
const entry = manifest.find((e) => e.filetype === 'stm32programmer');
if (!entry) { process.exit(1); }
console.log(entry.hash);
")
rm -f "$MANIFEST_TMP"

if [ -z "$FW_URL" ] || [ -z "$FW_SHA512" ]; then
    echo "ERROR: manifest entry '$MANIFEST_KEY' not found in firmware manifest"
    exit 1
fi
if [ -z "$STM32PROG_URL" ] || [ -z "$STM32PROG_SHA512" ]; then
    echo "ERROR: manifest entry 'stm32programmer' not found in firmware manifest"
    exit 1
fi

FW_TMP=$(mktemp --suffix=.txz)
az storage blob download --container-name deployment --name "$FW_URL" --file "$FW_TMP" --connection-string "$CON_STRING" --no-progress --output none

FW_ACTUAL_SHA512=$(sha512sum "$FW_TMP" | awk '{print $1}')
if [ "$FW_ACTUAL_SHA512" != "$FW_SHA512" ]; then
    echo "ERROR: firmware sha512 mismatch (expected $FW_SHA512, got $FW_ACTUAL_SHA512)"
    rm -f "$FW_TMP"
    exit 1
fi

rm -rf "/var/m1mtf/${FWDIR}"
tar -xJf "$FW_TMP" -C /var/m1mtf
rm -f "$FW_TMP"

STM32PROG_TMP=$(mktemp --suffix=.txz)
az storage blob download --container-name deployment --name "$STM32PROG_URL" --file "$STM32PROG_TMP" --connection-string "$CON_STRING" --no-progress --output none

STM32PROG_ACTUAL_SHA512=$(sha512sum "$STM32PROG_TMP" | awk '{print $1}')
if [ "$STM32PROG_ACTUAL_SHA512" != "$STM32PROG_SHA512" ]; then
    echo "ERROR: STM32CubeProgrammer sha512 mismatch (expected $STM32PROG_SHA512, got $STM32PROG_ACTUAL_SHA512)"
    rm -f "$STM32PROG_TMP"
    exit 1
fi

sudo tar -xJf "$STM32PROG_TMP" -C /opt
rm -f "$STM32PROG_TMP"

# Install the STM32MP1 ICT FSBL, staged alongside setup.sh in the deploy
# payload (see deploy.sh, which copies it from artifacts/ before packaging).
if [ -f "$SCRIPT_DIR"/fsbl.stm32 ]; then
    cp -f "$SCRIPT_DIR"/fsbl.stm32 /var/m1mtf/fsbl.stm32
else
    echo "ERROR: $SCRIPT_DIR/fsbl.stm32 not found in deploy payload"
    exit 1
fi

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

sed -i '/systemctl/d' /etc/crontab
sed -i '/m1mtf/d' /etc/crontab

echo "@reboot root sleep 120  && systemctl restart autossh" >> /etc/crontab
echo "40  6  * * *   root sudo sed -i '/root snap install/d'" >> /etc/crontab
echo "50  3  * * *   root find /var/m1mtf/synclogs -type f -mtime +365 -delete" >> /etc/crontab
echo "10  4  * * *   root find /var/m1mtf/logs -type d -mtime +365 -delete" >> /etc/crontab
echo "10  4  * * *   root find /var/m1mtf/m1cli -type f -mtime +365 -delete" >> /etc/crontab

snap install --classic --dangerous  m1tfc.snap
snap install --classic --dangerous  m1tfc-rest-server.snap
snap install --dangerous  gui-react.snap

# Install configs to system-wide location /etc/m1platform
sudo mkdir -p /etc/m1platform

# Create config.json on target
cat << EOF > /etc/m1platform/config.json
{
  "conString": "${CON_STRING}",
  "tfInterface": "${ETH_STATIC_IF}",
  "vendorSite": "${TESTSTATION}",
  "skipBatteryTest": false,
  "skipTestpointCheck": false,
  "skipRS485test": false,
  "productName": "${PRODUCTNAME}",
  "forceEppromOverwrite": false,
  "fwDir": "${FWDIR}",
  "layoutFilePath": "${LAYOUTFILEPATH}",
  "productionPassword": "1234",
  "debugPassword": "4321",
  "mtfDir": "/var/m1mtf",
  "programmingCommand": "/opt/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin/STM32_Programmer_CLI",
  "coinCellMinVoltageNew": 3.0,
  "coinCellMinVoltageUsed": 2.9,
  "firmwareManifest": {
    "mnp": "https://lenels2boardsprodsa.blob.core.windows.net/deployment/stm32mp15-lenels2-mnp.txz?sp=r&st=2026-08-01T05:08:12Z&se=2036-08-01T13:23:12Z&spr=https&sv=2026-02-06&sr=b&sig=eEowJn3pTFMuo9%2B9TwIbcFQ%2BXJXCygh7WlZfzyDvbQA%3D",
    "m1": "https://lenels2boardsprodsa.blob.core.windows.net/deployment/stm32mp15-lenels2-m1.txz?sp=r&st=2026-08-01T05:09:51Z&se=2036-08-01T13:24:51Z&spr=https&sv=2026-02-06&sr=b&sig=kK4xGIGbqCr%2BHeqWlATkmo0%2FffRu5VeXlyAV%2Ff983xk%3D"
  },
  "firmwareManifestUrl": "https://lenels2boardsprodsa.blob.core.windows.net/deployment/manifestFile.json?sv=2020-12-06&sr=b&sp=r&st=2026-08-01T06%3A06%3A46Z&se=2036-07-29T06%3A11%3A46Z&spr=https&sig=WO%2FutY%2FvANqwU%2FXxol95l1pT1u%2FfzqU%2FMhqfWfVZpx8%3D"
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
echo "setup script completed successfully"

