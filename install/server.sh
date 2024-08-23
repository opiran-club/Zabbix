#!/bin/bash
 
CYAN="\e[96m"
GREEN="\e[92m"
YELLOW="\e[93m"
RED="\e[91m"
BLUE="\e[94m"
MAGENTA="\e[95m"
WHITE="\e[97m"
NC="\e[0m"
BOLD=$(tput bold)

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

log(){
    local msg="$1"
    local timestamp
    timestamp=$(date +"%m-%d-%Y %k:%M:%S")
    echo -e "${timestamp} $msg"
    echo "${timestamp} $(echo -e "$msg" | sed 's/\x1b\[[0-9;]*m//g')" >> "$logfile" 2>&1
}

log_colored (){
    local color="$1"
    local msg="$2"
    log "${color}${msg}${NC}"
}

preparation() {

. /etc/os-release
ARCH=$(dpkg --print-architecture)
OS="${ID}${VERSION_ID}"
if [ "$ARCH" == "arm64" ]; then
  ARCH_SUFFIX="-arm64"
else
  ARCH_SUFFIX=""
fi

ZABBIX_VERSION="7.0"
logfile="zabbix_installer.log"
    for pkg in jq nginx apache2 certbot; do
        if ! command -v $pkg &> /dev/null; then
            echo -e "${YELLOW}$pkg is not installed. Installing now...${NC}"
            apt-get install -y $pkg
        fi
    done

    if [[ "$ID" == "ubuntu" || "$ID" == "debian" ]]; then
        wget -N "https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/${ID}${ARCH_SUFFIX}/pool/main/z/zabbix-release/zabbix-release_${ZABBIX_VERSION}-2+${ID}${VERSION_ID}_all.deb"
        dpkg -i "zabbix-release_${ZABBIX_VERSION}-2+${ID}${VERSION_ID}_all.deb"
    else
        echo -e "${RED}Unsupported OS version.${NC}"
        exit 1
    fi

    apt-get update
    apt-get install -y apt-get install mysql-server zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent
}

zabbix_server() {
    preparation
    clear
    echo && echo
    location_info=$(curl -s "http://ipwho.is")
    public_ip=$(echo "$location_info" | jq -r .ip)
    location=$(echo "$location_info" | jq -r .country)

    current_timezone=$(timedatectl | grep "Time zone" | awk '{print $3}')

    while true; do
        echo -ne "${YELLOW}Enter your desired Database password: ${NC}" 
        read -r dbroot
        if [[ -z "$dbroot" ]]; then
            echo -e "${RED}Database password cannot be empty. Please try again.${NC}"
        else
            break
        fi
    done

    echo && echo
    echo -ne "${YELLOW}Do you have a subdomain/domain pointing to ${GREEN}$public_ip [choose Y] ${NC} ${YELLOW} or continue with ${GREEN}$public_ip [choose N]? (y/n): ${NC}" 
    read -r answer
    if [ "$answer" == "Yy" ]; then
        echo ""
        echo -ne "${YELLOW}Please enter your Domain/subdomain (hostname): ${NC}" 
        read -r hostname
        echo && echo
        echo -ne "${YELLOW}Do you want to install Zabbix with Nginx [choose Y] instead of Apache [choose N]? (y/n): ${NC}" 
        read -r USE_NGINX
        if [[ "$USE_NGINX" == "y" || "$USE_NGINX" == "Y" ]]; then
            apt purge apache2 -y
            apt install -y python3-certbot-nginx
            certbot --nginx -d "$hostname"
            apt-get install -y zabbix-nginx-conf
            apt remove -y zabbix-apache-conf
            sed -i "s/#        server_name/server_name $hostname;/g" /etc/zabbix/nginx.conf
            systemctl restart nginx php-fpm zabbix-server zabbix-agent
            systemctl enable nginx php-fpm zabbix-server zabbix-agent
            else
            apt purge nginx -y
            apt install -y python3-certbot-apache
            certbot --apache -d "$hostname"
            systemctl restart apache2 zabbix-server zabbix-agent
            systemctl enable apache2 zabbix-server zabbix-agent
            fi
    else
        apt purge nginx -y
        systemctl enable apache2 zabbix-server zabbix-agent
    fi
clear
echo && echo
echo -e "${YELLOW} Your database password is: ${GREEN} $dbroot ${NC}"
echo -e "${YELLOW} Your hostname : ${GREEN} $hostname ${NC}"
echo -e "${YELLOW} Your IP : ${GREEN} $public_ip ${NC}"
echo -e "${YELLOW} Your Location : ${GREEN} $location ${NC}"
echo && echo
    log_colored $YELLOW "Installing MySQL..."
    echo ""
    log_colored $YELLOW "Configuring MySQL..."
    mysql -uroot -p << EOF
CREATE DATABASE zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER 'zabbix'@'localhost' IDENTIFIED BY '$dbroot';
GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';
SET GLOBAL log_bin_trust_function_creators = 1;
EXIT
EOF

    log_colored $YELLOW "Importing initial schema and data..."
    echo ""
    zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -uzabbix -p zabbix
    echo ""
    mysql -uroot -p << EOF
SET GLOBAL log_bin_trust_function_creators = 0;
EXIT
EOF

    log_colored $YELLOW "Configuring Zabbix server"
    echo ""
    sed -i "s/# DBPassword=/DBPassword=$dbroot/" /etc/zabbix/zabbix_server.conf

    log_colored $YELLOW "Restarting Zabbix server and agent"
    echo ""
    systemctl restart zabbix-server zabbix-agent

    clear
    echo ""
    echo -e "    ${MAGENTA}Your ZABBIX server is set up successfully${NC}"
    printf "\e[93m+-------------------------------------+\e[0m\n" 
    echo ""
    log_colored $YELLOW "Installation completed. System needs to be restarted."
    echo ""
    echo -e "${MAGENTA}Please visit Zabbix at: ${GREEN}http://$public_ip/zabbix ${NC}"
    echo ""
    printf "\e[93m+-------------------------------------+\e[0m\n" 
    echo ""
    ask_reboot
}

uninstall() {
    echo && echo
    log_colored $YELLOW "Starting uninstallation process..."
    echo && echo
    log_colored $YELLOW "Stopping and disabling Zabbix services..."
    systemctl stop zabbix-server zabbix-agent >> "$logfile" 2>&1
    systemctl disable zabbix-server zabbix-agent >> "$logfile" 2>&1
    echo && echo
    log_colored $YELLOW "Removing Zabbix configuration and binaries..."
    rm -f /etc/systemd/system/zabbix-server.service >> "$logfile" 2>&1
    rm -f /etc/systemd/system/zabbix-agent.service >> "$logfile" 2>&1
    rm -rf /etc/zabbix /usr/share/zabbix /usr/local/sbin/zabbix_* >> "$logfile" 2>&1
    echo && echo
    log_colored $YELLOW "Removing MySQL..."
    systemctl stop mysql >> "$logfile" 2>&1
    systemctl disable mysql >> "$logfile" 2>&1
    apt-get remove --purge -y mysql-server mysql-client mysql-common >> "$logfile" 2>&1
    apt-get autoremove -y >> "$logfile" 2>&1
    apt-get autoclean >> "$logfile" 2>&1
    rm -rf /etc/mysql /var/lib/mysql /var/log/mysql* >> "$logfile" 2>&1
    echo && echo
    log_colored $YELLOW "Cleaning up temporary files..."
    rm -rf /tmp/zabbix-* >> "$logfile" 2>&1
    echo && echo
    clear
    echo && echo
    log_colored $YELLOW "Uninstallation completed."
    press_enter
}


while true; do
    clear
    tg_title="https://t.me/OPIran_Official"
    yt_title="youtube.com/@opiran-institute"
    clear
    logo
    echo -e "\e[93m╔═══════════════════════════════════════════════╗\e[0m"  
    echo -e "\e[93m║           \e[94mZABBIX INSTALLATION                 \e[93m║\e[0m"   
    echo -e "\e[93m╠═══════════════════════════════════════════════╣\e[0m"
    echo ""
    echo -e "${BLUE}   ${tg_title}   ${NC}"
    echo -e "${BLUE}   ${yt_title}   ${NC}"
    echo ""
    printf "${GREEN} Beta version ${NC}\n"
    echo -e "\e[93m+-----------------------------------------------+\e[0m" 
    echo ""
    printf "${GREEN} 1) ${NC} Zabbix Dashboard ${NC}\n"
    echo ""
    printf "${GREEN} 2) ${NC} Uninstall Zabbix ${NC}\n"
    echo ""
    printf "${GREEN} 3) ${NC} Changing database directory ${NC}\n"
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
            zabbix_server
            ;;
        2)
            clear
	    uninstall
            ;;
        3)
            clear
	    bash <(curl -s https://raw.githubusercontent.com/opiran-club/Zabbix/main/install/data_resync.sh --ipv4)
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
