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

log_colored "$YELLOW" "Stopping Zabbix Server..."
service zabbix-server stop >> "$logfile" 2>&1 || log_colored "$RED" "Failed to stop Zabbix Server."

log_colored "$YELLOW" "Stopping Zabbix Agent..."
service zabbix-agent stop >> "$logfile" 2>&1 || log_colored "$RED" "Failed to stop Zabbix Agent."

log_colored "$YELLOW" "Stopping MySQL..."
service mysql stop >> "$logfile" 2>&1 || log_colored "$RED" "Failed to stop MySQL."

log_colored "$YELLOW" "Copying MySQL data directory to $destdir..."
if sudo rsync -av /var/lib/mysql "$destdir" >> "$logfile" 2>&1; then
    log_colored "$GREEN" "MySQL data directory copied successfully."
else
    log_colored "$RED" "Failed to copy MySQL data directory."
    exit 1
fi

log_colored "$YELLOW" "Removing old MySQL data directory..."
if sudo rm -rf /var/lib/mysql; then
    log_colored "$GREEN" "Old MySQL data directory removed successfully."
else
    log_colored "$RED" "Failed to remove old MySQL data directory."
    exit 1
fi

log_colored "$YELLOW" "Updating MySQL configuration for new data directory..."
if sed -i "s|# datadir	= /var/lib/mysql|datadir	= $destdir/mysql|g" /etc/mysql/mysql.conf.d/mysqld.cnf >> "$logfile" 2>&1; then
    log_colored "$GREEN" "MySQL configuration updated successfully."
else
    log_colored "$RED" "Failed to update MySQL configuration."
    exit 1
fi

log_colored "$YELLOW" "Starting MySQL..."
if service mysql start >> "$logfile" 2>&1; then
    log_colored "$GREEN" "MySQL started successfully."
else
    log_colored "$RED" "Failed to start MySQL."
    exit 1
fi

log_colored "$YELLOW" "Starting Zabbix Server..."
if service zabbix-server start >> "$logfile" 2>&1; then
    log_colored "$GREEN" "Zabbix Server started successfully."
else
    log_colored "$RED" "Failed to start Zabbix Server."
    exit 1
fi

log_colored "$YELLOW" "Starting Zabbix Agent..."
if service zabbix-agent start >> "$logfile" 2>&1; then
    log_colored "$GREEN" "Zabbix Agent started successfully."
else
    log_colored "$RED" "Failed to start Zabbix Agent."
    exit 1
fi

log_colored "$GREEN" "Database migration completed successfully."
