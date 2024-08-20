#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'
zabbixurl="https://cdn.zabbix.com/zabbix/sources/stable/6.4/zabbix-6.4.10.tar.gz"
zabbixarchive=$(basename "$zabbixurl")
srcdir="/usr/local/src"
zabbixconf="/usr/local/etc/zabbix_agent.conf"
zabbixhost="192.168.1.69"
tmpdir="$HOME/temp"
logfile="$PWD/install-agent.log"
rm -f "$logfile"

log() {
    local msg="$1"
    local timestamp
    timestamp=$(date +"%m-%d-%Y %k:%M:%S")
    echo -e "${timestamp} ${msg}"
    echo -e "${timestamp} ${msg}" >> "$logfile" 2>&1
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${YELLOW}$1 is not installed. Installing now...${NC}"
        apt-get install -y "$1"
    fi
}

log_colored() {
    local color="$1"
    local msg="$2"
    log "${color}${msg}${NC}"
}

log_colored "$YELLOW" "Removing temp dir $tmpdir"
rm -rf "$tmpdir" >> "$logfile" 2>&1
mkdir -p "$tmpdir" >> "$logfile" 2>&1

check_command wget
check_command tar

log_colored "$YELLOW" "Downloading $zabbixarchive to $tmpdir"
wget -q --directory-prefix="$tmpdir" "$zabbixurl" >> "$logfile" 2>&1
log_colored "$YELLOW" "Extracting $zabbixarchive to $tmpdir"
tar -xf "$tmpdir/$zabbixarchive" -C "$tmpdir" >> "$logfile" 2>&1

filename="${zabbixarchive%.*}"
filename="${filename%.*}"
mv "$tmpdir/$filename" "${srcdir}" >> "$logfile" 2>&1

log_colored "$GREEN" "Installing Zabbix Agent..."
if [ -f /etc/systemd/system/zabbix-agent.service ]; then
    log_colored "$RED" "Stopping existing Zabbix Agent service..."
    systemctl stop zabbix-agent >> "$logfile" 2>&1
    log_colored "$YELLOW" "Saving existing configuration to ${zabbixconf}.bak"
    mv "${zabbixconf}" "${zabbixconf}.bak"
else
    log_colored "$YELLOW" "Adding Go repository and installing dependencies..."
    add-apt-repository ppa:longsleep/golang-backports -y >> "$logfile" 2>&1
    apt update >> "$logfile" 2>&1
    groupadd zabbix >> "$logfile" 2>&1
    useradd -g zabbix -s /bin/bash zabbix >> "$logfile" 2>&1
    apt-get -y install build-essential pkg-config libpcre3-dev libz-dev golang-go >> "$logfile" 2>&1
fi

cd "${srcdir}/${filename}" >> "$logfile" 2>&1
log_colored "$YELLOW" "Patching source for 32-bit compatibility..."
sed -i 's/strconv.Atoi(strings.TrimSpace(line\[:len(line)-2\]))/strconv.ParseInt(strings.TrimSpace(line[:len(line)-2]),10,64)/' src/go/plugins/proc/procfs_linux.go >> "$logfile" 2>&1
log_colored "$YELLOW" "Configuring Zabbix Agent..."
./configure --enable-agent --prefix=/usr/local >> "$logfile" 2>&1
make install >> "$logfile" 2>&1
log_colored "$YELLOW" "Configuring Zabbix Agent..."
sed -i "s|Server=127.0.0.1|Server=$zabbixhost|g" "$zabbixconf" >> "$logfile" 2>&1
sed -i "s|ServerActive=127.0.0.1|ServerActive=$zabbixhost|g" "$zabbixconf" >> "$logfile" 2>&1
sed -i "s|Hostname=|#Hostname=|g" "$zabbixconf" >> "$logfile" 2>&1

if [ ! -f /etc/systemd/system/zabbix-agent.service ]; then
    log_colored "$YELLOW" "Installing Zabbix Agent Service..."
    sudo tee -a /etc/systemd/system/zabbix-agent.service > /dev/null <<EOT
[Unit]
Description=Zabbix Agent
After=syslog.target network.target

[Service]
Type=simple
User=zabbix
ExecStart=/usr/local/sbin/zabbix_agent -c /usr/local/etc/zabbix_agent.conf
RemainAfterExit=yes
PIDFile=/tmp/zabbix_agent.pid

[Install]
WantedBy=multi-user.target
EOT
    systemctl enable zabbix-agent >> "$logfile" 2>&1
fi

log_colored "$GREEN" "Starting Zabbix Agent..."
systemctl start zabbix-agent >> "$logfile" 2>&1
log_colored "$YELLOW" "Removing temp dir $tmpdir"
rm -rf "$tmpdir" >> "$logfile" 2>&1
log_colored "$GREEN" "Zabbix Agent installation complete."
