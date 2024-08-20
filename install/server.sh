#!/bin/bash
# 
# Zabbix installer Bash Script
# Author: github.com/opiran-club
#
# For more information and updates, visit github.com/opiran-club and @opiran_official on telegram.
#
# Disclaimer:
# This script comes with no warranties or guarantees. Use it at your own risk.

CYAN="\e[96m"
GREEN="\e[92m"
YELLOW="\e[93m"
RED="\e[91m"
BLUE="\e[94m"
MAGENTA="\e[95m"
WHITE="\e[97m"
NC="\e[0m"
BOLD=$(tput bold)


if [ "$EUID" -ne 0 ]; then
echo -e "\n ${RED}This script must be run as root.${NC}"
exit 1
fi

press_enter() {
    echo -e "\n ${RED}Press Enter to continue... ${NC}"
    read
}

ask_reboot() {
echo ""
echo -e "\n ${YELLOW}Reboot now? (Recommended) ${GREEN}[y/n]${NC}"
echo ""
read reboot
case "$reboot" in
        [Yy]) 
        systemctl reboot
        ;;
        *) 
        return 
        ;;
    esac
exit
}

logo1="     ______    _______    __      _______        __      _____  ___   "
logo2="    /      \  |   __  \  |  \    /       \      /  \     \    \|   \  "
logo3="   /  ____  \ (  |__)  ) |   |  |         |    /    \    |.\   \    | "
logo4="  /  /    )  )|   ____/  |   |  |_____/   )   /' /\  \   |: \   \   | "
logo5=" (  (____/  / (   /      |.  |   //      /   //  __'  \  |.  \    \.| "
logo6="  \        / /    \      /\  |\ |:  __   \  /   /  \\   \ |    \    \| "
logo7="   \_____/ (_______)    (__\_|_)|__|  \___)(___/    \___)\___|\____\) "

logo() {
echo -e "${BLUE}${logo1:0:24}${RED}${logo1:24:19}${WHITE}${logo1:43:14}${GREEN}${logo1:57}${NC}"
echo -e "${BLUE}${logo2:0:24}${RED}${logo2:24:19}${WHITE}${logo2:43:14}${GREEN}${logo2:57}${NC}"
echo -e "${BLUE}${logo3:0:24}${RED}${logo3:24:19}${WHITE}${logo3:43:14}${GREEN}${logo3:57}${NC}"
echo -e "${BLUE}${logo4:0:24}${RED}${logo4:24:19}${WHITE}${logo4:43:14}${GREEN}${logo4:57}${NC}"
echo -e "${BLUE}${logo5:0:24}${RED}${logo5:24:19}${WHITE}${logo5:43:14}${GREEN}${logo5:57}${NC}"
echo -e "${BLUE}${logo6:0:24}${RED}${logo6:24:19}${WHITE}${logo6:43:14}${GREEN}${logo6:57}${NC}"
echo -e "${BLUE}${logo7:0:24}${RED}${logo7:24:19}${WHITE}${logo7:43:14}${GREEN}${logo7:57}${NC}"
}

ask_user_input() {
    echo -e "\n${RED} TIP !!${NC}"
    echo -e "${GREEN} You can use the same password for all the fields below.${NC}"
    echo && echo

    while true; do
        echo -ne "${YELLOW}Enter MySQL root password: ${NC}" 
        read -r dbroot
        if [[ -z "$dbroot" ]]; then
            echo -e "${RED}MySQL root password cannot be empty. Please try again.${NC}"
        else
            break
        fi
    done
    echo && echo

    while true; do
        echo -ne "${YELLOW}Enter Zabbix MySQL user password: ${NC}" 
        read -r dbzabbix
        if [[ -z "$dbzabbix" ]]; then
            echo -e "${RED}Zabbix MySQL user password cannot be empty. Please try again.${NC}"
        else
            break
        fi
    done
    echo && echo

    while true; do
        echo -ne "${YELLOW}Enter MySQL monitoring user password: ${NC}" 
        read -r monzabbix
        if [[ -z "$monzabbix" ]]; then
            echo -e "${RED}MySQL monitoring user password cannot be empty. Please try again.${NC}"
        else
            break
        fi
    done
    echo && echo

    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}jq is not installed. Installing now...${NC}"
        apt-get install -y jq
    fi

    location_info=$(curl -s "http://ipwho.is")
    public_ip=$(echo "$location_info" | jq -r .ip)
    location=$(echo "$location_info" | jq -r .country)

    current_timezone=$(timedatectl | grep "Time zone" | awk '{print $3}')
    printf "${YELLOW}Your current timezone is ${GREEN}%s${NC}\n" "$current_timezone"

    while true; do
        echo ""
        echo -ne "${YELLOW}Your location is ${GREEN}$location${YELLOW}. Press Enter to use the current timezone or enter a different PHP timezone (e.g., America/New_York):${NC} " 
        read -r phptz

        if [[ -z "$phptz" ]]; then
            phptz="$current_timezone"
            echo -e "${GREEN}Using the current timezone: ${NC}$phptz"
            break
        elif [[ "$phptz" =~ ^[A-Za-z]+/[A-Za-z_]+$ ]]; then
            echo -e "${GREEN}Using the specified timezone: ${NC}$phptz"
            break
        else
            echo -e "${RED}Invalid timezone format. Please try again.${NC}"
        fi
    done
}


log() {
    local message="$1"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "${YELLOW}$timestamp${GREEN} $message${NC}"
    echo "$timestamp $message" >> "$logfile" 2>&1
}

log_colored(){
    local color="$1"
    local msg="$2"
    log "${color}${msg}${NC}"
}

install_mysql() {
    clear
    echo ""
    log_colored "Installing MySQL..."
    echo ""
    apt-get -y update >> "$logfile" 2>&1
    apt-get -y install mysql-server mysql-client >> "$logfile" 2>&1
    log_colored "Configuring MySQL..."
mysql --user=root <<-EOF
SET GLOBAL log_bin_trust_function_creators = 1;
ALTER USER 'root'@'localhost' IDENTIFIED BY '${dbroot}';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
CREATE DATABASE zabbix CHARACTER SET UTF8 COLLATE UTF8_BIN;
CREATE USER 'zabbix'@'%' IDENTIFIED BY '${dbzabbix}';
GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'%';
CREATE USER 'zbx_monitor'@'%' IDENTIFIED BY '${monzabbix}';
GRANT USAGE, REPLICATION CLIENT, PROCESS, SHOW DATABASES, SHOW VIEW ON *.* TO 'zbx_monitor'@'%';
FLUSH PRIVILEGES;
EOF
}

install_java() {
    log_colored "Installing Zulu Java JDK..."
    if ! command -v wget &> /dev/null; then
        apt-get install -y wget
    fi
    if ! command -v tar &> /dev/null; then
        apt-get install -y tar
    fi
    wget -q --directory-prefix="$tmpdir" "$jdkurl" >> "$logfile" 2>&1
    tar -xf "$tmpdir/$jdkarchive" -C "$tmpdir" >> "$logfile" 2>&1
    rm -rf "$javahome" >> "$logfile" 2>&1
    mkdir -p /usr/lib/jvm >> "$logfile" 2>&1
    mv "$tmpdir/$filename" "$javahome" >> "$logfile" 2>&1

    update-alternatives --install "/usr/bin/java" "java" "$javahome/bin/java" 1 >> "$logfile" 2>&1
    update-alternatives --install "/usr/bin/javac" "javac" "$javahome/bin/javac" 1 >> "$logfile" 2>&1
}

install_zabbix() {
    log_colored "Downloading and installing Zabbix..."
    wget -q --directory-prefix="$tmpdir" "$zabbixurl" >> "$logfile" 2>&1
    tar -xf "$tmpdir/$zabbixarchive" -C "$tmpdir" >> "$logfile" 2>&1
     mv "$tmpdir/$filename" "$srcdir" >> "$logfile" 2>&1

    if [ ! -f /etc/systemd/system/zabbix-server.service ]; then
    log_colored "Importing Zabbix database schema..."
    cd "$srcdir/$filename/database/mysql" >> "$logfile" 2>&1
    mysql -u zabbix -p"$dbzabbix" zabbix < schema.sql >> "$logfile" 2>&1
    mysql -u zabbix -p"$dbzabbix" zabbix < images.sql >> "$logfile" 2>&1
    mysql -u zabbix -p"$dbzabbix" zabbix < data.sql >> "$logfile" 2>&1

mysql --user=root <<-EOF
SET GLOBAL log_bin_trust_function_creators = 0;
EOF

    install_php
    build_zabbix
    install_zabbix_services
    fi
}

install_php() {
    log_colored "Installing Apache and PHP..."
    apt-get -y install fping apache2 php libapache2-mod-php php-cli php-mysql php-mbstring php-gd php-xml php-bcmath php-ldap mlocate >> "$logfile" 2>&1
    updatedb >> "$logfile" 2>&1
    phpini=$(locate php.ini | head -n 1)
    sed -i "s/max_execution_time = 30/max_execution_time = 300/g" "$phpini"
    sed -i "s/memory_limit = 128M/memory_limit = 256M/g" "$phpini"
    sed -i "s/post_max_size = 8M/post_max_size = 32M/g" "$phpini"
    sed -i "s/max_input_time = 60/max_input_time = 300/g" "$phpini"
    sed -i "s|;date.timezone =|date.timezone = $phptz|g" "$phpini"
    systemctl restart apache2 >> "$logfile" 2>&1
}

build_zabbix() {
    log_colored "Building Zabbix..."
     add-apt-repository ppa:longsleep/golang-backports -y >> "$logfile" 2>&1
     apt-get update >> "$logfile" 2>&1

     apt-get -y install build-essential libmysqlclient-dev libssl-dev libsnmp-dev libevent-dev pkg-config golang-go >> "$logfile" 2>&1
     apt-get -y install libopenipmi-dev libcurl4-openssl-dev libxml2-dev libssh2-1-dev libpcre3-dev >> "$logfile" 2>&1
     apt-get -y install libldap2-dev libiksemel-dev libgnutls28-dev >> "$logfile" 2>&1

    cd "$srcdir/$filename" >> "$logfile" 2>&1

    log_colored "Applying patches..."
    sed -i 's/strconv.Atoi(strings.TrimSpace(line\[:len(line)-2\]))/strconv.ParseInt(strings.TrimSpace(line[:len(line)-2]),10,64)/' src/go/plugins/proc/procfs_linux.go >> $logfile 2>&1
    sed -i '/MYSQL_OPT_RECONNECT/d' src/libs/zbxdb/db.c >> $logfile 2>&1
    sed -i '/Cannot set MySQL reconnect option/d' src/libs/zbxdb/db.c >> $logfile 2>&1
    
     ./configure --enable-server --enable-agent2 --enable-ipv6 --with-mysql --with-openssl --with-net-snmp --with-openipmi --with-libcurl --with-libxml2 --with-ssh2 --with-ldap --enable-java --prefix=/usr/local >> $logfile 2>&1
     make install >> $logfile 2>&1

     chmod ug+s /usr/bin/fping
     chmod ug+s /usr/bin/fping6
     sed -i "s/# DBPassword=/DBPassword=$dbzabbix/g" "$zabbixconf" >> $logfile 2>&1
     sed -i "s|# FpingLocation=/usr/sbin/fping|FpingLocation=/usr/bin/fping|g" "$zabbixconf" >> $logfile 2>&1
     sed -i "s|# Fping6Location=/usr/sbin/fping6|Fping6Location=/usr/bin/fping6|g" "$zabbixconf" >> $logfile 2>&1
     sed -i "s/# StartPingers=1/StartPingers=10/g" "$zabbixconf" >> $logfile 2>&1
}

install_zabbix_services() {
    log_colored "Installing Zabbix Server Service..."
     tee /etc/systemd/system/zabbix-server.service > /dev/null <<EOT
[Unit]
Description=Zabbix Server
After=syslog.target network.target mysql.service

[Service]
Type=simple
User=zabbix
ExecStart=/usr/local/sbin/zabbix_server
ExecReload=/usr/local/sbin/zabbix_server -R config_cache_reload
RemainAfterExit=yes
PIDFile=/tmp/zabbix_server.pid

[Install]
WantedBy=multi-user.target
EOT

    systemctl enable zabbix-server >> $logfile 2>&1

    log_colored "Installing Zabbix Agent Service..."
     tee /etc/systemd/system/zabbix-agent.service > /dev/null <<EOT
[Unit]
Description=Zabbix Agent
After=syslog.target network.target

[Service]
Type=simple
User=zabbix
ExecStart=/usr/local/sbin/zabbix_agent
ExecReload=/usr/local/sbin/zabbix_agent -R config_cache_reload
RemainAfterExit=yes
PIDFile=/tmp/zabbix_agent.pid

[Install]
WantedBy=multi-user.target
EOT

    systemctl enable zabbix-agent >> $logfile 2>&1
}

finalize_installation() {
    log_colored "Installation completed. System needs to be restarted."
}

server() {
    ask_user_input
    logfile=/tmp/install_zabbix.log
    tmpdir=$(mktemp -d -t zabbix-XXXXXXXXXX)
    jdkurl="https://cdn.azul.com/zulu/bin/zulu19.32.13-ca-jdk19.0.4-linux_x64.tar.gz"
    jdkarchive=$(basename "$jdkurl")
    javahome="/usr/lib/jvm/zulu19.32.13-ca-jdk19.0.4-linux_x64"
    zabbixurl="https://cdn.zabbix.com/zabbix/sources/stable/6.0/zabbix-6.0.20.tar.gz"
    zabbixarchive=$(basename "$zabbixurl")
    srcdir="/usr/local/src"
    zabbixconf="/usr/local/etc/zabbix_server.conf"
    install_mysql
    install_java
    install_zabbix
    finalize_installation
    ask_reboot
}

uninstall() {
    log_colored "Starting uninstallation process..."
    log_colored "Removing Zabbix..."
    systemctl stop zabbix-server >> "$logfile" 2>&1
    systemctl stop zabbix-agent >> "$logfile" 2>&1
    systemctl disable zabbix-server >> "$logfile" 2>&1
    systemctl disable zabbix-agent >> "$logfile" 2>&1
    rm -f /etc/systemd/system/zabbix-server.service >> "$logfile" 2>&1
    rm -f /etc/systemd/system/zabbix-agent.service >> "$logfile" 2>&1
    rm -rf /usr/local/sbin/zabbix_server >> "$logfile" 2>&1
    rm -rf /usr/local/sbin/zabbix_agent >> "$logfile" 2>&1
    rm -rf /usr/local/etc/zabbix_server.conf >> "$logfile" 2>&1
    rm -rf /usr/local/src/zabbix* >> "$logfile" 2>&1
    rm -rf /usr/local/bin/zabbix* >> "$logfile" 2>&1
    log_colored "Removing MySQL..."
    systemctl stop mysql >> "$logfile" 2>&1
    systemctl disable mysql >> "$logfile" 2>&1
    apt-get remove --purge -y mysql-server mysql-client mysql-common >> "$logfile" 2>&1
    apt-get autoremove -y >> "$logfile" 2>&1
    apt-get autoclean >> "$logfile" 2>&1
    rm -rf /etc/mysql >> "$logfile" 2>&1
    rm -rf /var/lib/mysql >> "$logfile" 2>&1
    rm -rf /var/log/mysql >> "$logfile" 2>&1
    rm -rf /var/log/mysql* >> "$logfile" 2>&1
    rm -rf /var/lib/mysql* >> "$logfile" 2>&1
    log_colored "Removing Java..."
    update-alternatives --remove java /usr/lib/jvm/zulu*/bin/java >> "$logfile" 2>&1
    update-alternatives --remove javac /usr/lib/jvm/zulu*/bin/javac >> "$logfile" 2>&1
    rm -rf /usr/lib/jvm/zulu* >> "$logfile" 2>&1
    log_colored "Cleaning up temporary files..."
    rm -rf /tmp/zabbix-*
    log_colored "Uninstallation completed."
}

while true; do
    clear
    tg_title="https://t.me/OPIran_Official"
    yt_title="youtube.com/@opiran-institute"
    clear
    logo
    echo -e "\e[93m╔═══════════════════════════════════════════════╗\e[0m"  
    echo -e "\e[93m║         \e[94mZABBIX INSTALLATION                      \e[93m║\e[0m"   
    echo -e "\e[93m╠═══════════════════════════════════════════════╣\e[0m"
    echo ""
    echo -e "${BLUE}   ${tg_title}   ${NC}"
    echo -e "${BLUE}   ${yt_title}   ${NC}"
    echo ""
    echo -e "\e[93m+-----------------------------------------------+\e[0m" 
    echo ""
    printf "${GREEN} 1) ${NC} Zabbix (server+agent+Database) ${NC}\n"
    printf "${GREEN} 2) ${NC} Zabbix agent installer${NC}\n"
    echo ""
    printf "${GREEN} 3) ${NC} Database migeration${NC}\n"
    printf "${GREEN} 4) ${NC} Uninstall ${NC}\n"
    echo ""
    echo -e "\e[93m+-----------------------------------------------+\e[0m" 
    echo ""
    printf "${GREEN} E) ${NC} Exit the menu${NC}\n"
    echo ""
    echo -ne "${GREEN}Select an option: ${NC}"
    read -r choice

    case $choice in
        1)
            clear
            server
            ;;
        2)
	    clear
     	    bash <(curl -s https://raw.githubusercontent.com/opiran-club/Zabbix/main/install/agent.sh --ipv4)
            ;;
        3)
            clear
	    bash <(curl -s https://raw.githubusercontent.com/opiran-club/Zabbix/main/install/data_rsync.sh --ipv4)
            ;;
        4)
            clear
	    uninstall
            ;;
   
        E|e)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice. Please enter a valid option.${NC}"
            ;;
    esac

    echo -e "\n${RED}Press Enter to continue...${NC}"
    read -r
done
