#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

zabbixurl="https://cdn.zabbix.com/zabbix/sources/stable/6.4/zabbix-6.4.10.tar.gz"
zabbixarchive=$(basename "$zabbixurl")
srcdir="/usr/local/src"
zabbixconf="/usr/local/etc/zabbix_agent.conf"
tmpdir="$HOME/temp"
logfile="$PWD/install-agent.log"
rm -f "$logfile"

log(){
    local msg="$1"
    local timestamp
    timestamp=$(date +"%m-%d-%Y %k:%M:%S")
    echo -e "${timestamp} $msg"
    echo -e "${timestamp} $msg" >> "$logfile" 2>&1
}

log_colored(){
    local color="$1"
    local msg="$2"
    log "${color}${msg}${NC}"
}

echo -e "${RED}TIP!!${NC}"
echo -e "${YELLOW}If the server and agent are on the same machine, you can use ${GREEN}127.0.0.1${NC}"
echo && echo
read -p "Enter the IP address or hostname of the Zabbix Server: " zabbixhost

if [ -z "$zabbixhost" ]; then
    log_colored "$RED" "Zabbix Server IP/hostname cannot be empty. Exiting."
    exit 1
fi

log_colored "$YELLOW" "Zabbix Server set to: $zabbixhost"

log_colored "$YELLOW" "Removing temp dir $tmpdir"
rm -rf "$tmpdir" >> "$logfile" 2>&1
mkdir -p "$tmpdir" >> "$logfile" 2>&1

log_colored "$YELLOW" "Downloading $zabbixarchive to $tmpdir"
if ! wget -q --directory-prefix="$tmpdir" "$zabbixurl" >> "$logfile" 2>&1; then
    log_colored "$RED" "Download failed. Exiting."
    exit 1
fi

log_colored "$YELLOW" "Extracting $zabbixarchive to $tmpdir"
if ! tar -xf "$tmpdir/$zabbixarchive" -C "$tmpdir" >> "$logfile" 2>&1; then
    log_colored "$RED" "Extraction failed. Exiting."
    exit 1
fi

filename="${zabbixarchive%.*}"
filename="${filename%.*}"
mv "$tmpdir/$filename" "$srcdir" >> "$logfile" 2>&1

cd "${srcdir}/${filename}" >> "$logfile" 2>&1
log_colored "$YELLOW" "Patching source for 32-bit compatibility..."
sed -i 's/strconv.Atoi(strings.TrimSpace(line\[:len(line)-2\]))/strconv.ParseInt(strings.TrimSpace(line[:len(line)-2]),10,64)/' src/go/plugins/proc/procfs_linux.go >> "$logfile" 2>&1

log_colored "$YELLOW" "Configuring Zabbix Agent..."
./configure --enable-agent --prefix=/usr/local >> "$logfile" 2>&1
if ! make install >> "$logfile" 2>&1; then
    log_colored "$RED" "Installation failed. Exiting."
    exit 1
fi

log_colored "$YELLOW" "Configuring Zabbix Agent with server IP/hostname..."
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
