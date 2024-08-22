#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'
destdir="/tmp"
logfile="$PWD/movedb.log"
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

echo -ne "${YELLOW}Please enter the destination directory (e.g. /var/lib/zabbix ${NC}" 
read -r destdir
if [ ! -d "$destdir" ]; then
    log_colored "$YELLOW" "Directory $destdir does not exist. Creating it now..."
    if mkdir -p "$destdir"; then
        log_colored "$GREEN" "Directory $destdir created successfully."
    else
        log_colored "$RED" "Failed to create directory $destdir. Exiting."
        exit 1
    fi
fi

log_colored "$YELLOW" "Stopping Zabbix Server and Agent..."
systemctl stop zabbix-server zabbix-agent >> "$logfile" 2>&1 || log_colored "$RED" "Failed to stop Zabbix services."

log_colored "$YELLOW" "Stopping MySQL..."
systemctl stop mysql >> "$logfile" 2>&1 || log_colored "$RED" "Failed to stop MySQL."

log_colored "$YELLOW" "Copying MySQL data directory to $destdir..."
if rsync -av /var/lib/mysql "$destdir" >> "$logfile" 2>&1; then
    log_colored "$GREEN" "MySQL data directory copied successfully."
else
    log_colored "$RED" "Failed to copy MySQL data directory."
    exit 1
fi

log_colored "$YELLOW" "Removing old MySQL data directory..."
if rm -rf /var/lib/mysql; then
    log_colored "$GREEN" "Old MySQL data directory removed successfully."
else
    log_colored "$RED" "Failed to remove old MySQL data directory."
    exit 1
fi

log_colored "$YELLOW" "Updating MySQL configuration for new data directory..."
if sed -i "s|^datadir\s*=.*|datadir = $destdir/mysql|g" /etc/mysql/mysql.conf.d/mysqld.cnf >> "$logfile" 2>&1; then
    log_colored "$GREEN" "MySQL configuration updated successfully."
else
    log_colored "$RED" "Failed to update MySQL configuration."
    exit 1
fi

log_colored "$YELLOW" "Starting MySQL..."
if systemctl start mysql >> "$logfile" 2>&1; then
    log_colored "$GREEN" "MySQL started successfully."
else
    log_colored "$RED" "Failed to start MySQL."
    exit 1
fi

log_colored "$YELLOW" "Starting Zabbix Server and Agent..."
if systemctl start zabbix-server zabbix-agent >> "$logfile" 2>&1; then
    log_colored "$GREEN" "Zabbix services started successfully."
else
    log_colored "$RED" "Failed to start Zabbix services."
    exit 1
fi

log_colored "$GREEN" "Database migration completed successfully."
