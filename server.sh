#!/bin/bash
# MySQL root password
dbroot="rootZaq!2wsx"

# Zabbix user MySQL password
dbzabbix="zabbixZaq!2wsx"

# MySQL database monitoring user
monzabbix="monzabbixZaq!2wsx"

# Zabbix Server URL
zabbixurl="https://cdn.zabbix.com/zabbix/sources/stable/6.4/zabbix-6.4.10.tar.gz"

# Zabbix server archive name
zabbixarchive=$(basename "$zabbixurl")

# Where to put Zabbix source
srcdir="/usr/local/src"

# PHP timezone
phptz="America/New_York"

# Zabbix server configuration
zabbixconf="/usr/local/etc/zabbix_server.conf"

# Zabbix agent configuration
zabbixagentconf="/usr/local/etc/zabbix_agent2.conf"

# Temp directory for downloads, etc.
tmpdir=$(mktemp -d)

# stdout and stderr for commands logged
logfile="$PWD/install.log"
rm -f $logfile

# Simple logger
log() {
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "$timestamp $1"
    echo "$timestamp $1" >> "$logfile" 2>&1
}

# Clean up temp directory on exit
cleanup() {
    log "Removing temp directory $tmpdir"
    rm -rf "$tmpdir" >> "$logfile" 2>&1
}
trap cleanup EXIT

log "Setting up environment..."
if [ ! -f /etc/systemd/system/zabbix-server.service ]; then
    log "Installing MySQL..."
    sudo apt-get -y update >> "$logfile" 2>&1
    sudo apt-get -y install mysql-server mysql-client >> "$logfile" 2>&1

    log "Configuring MySQL..."
    sudo mysql --user=root <<_EOF_
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
_EOF_
else
    log "Stopping existing Zabbix services..."
    sudo systemctl stop zabbix-server >> "$logfile" 2>&1
    sudo systemctl stop zabbix-agent2 >> "$logfile" 2>&1

    log "Backing up existing configurations..."
    sudo mv "${zabbixconf}" "${zabbixconf}.bak"
    sudo mv "${zabbixagentconf}" "${zabbixagentconf}.bak"
fi

log "Detecting architecture..."
arch=$(uname -m)

# Define JDK download URL based on architecture
case "$arch" in
    armv7l)
        jdkurl="https://cdn.azul.com/zulu-embedded/bin/zulu17.46.19-ca-jdk17.0.9-linux_aarch32hf.tar.gz"
        javahome="/usr/lib/jvm/jdk17"
        ;;
    aarch64)
        jdkurl="https://cdn.azul.com/zulu/bin/zulu21.30.15-ca-jdk21.0.1-linux_aarch64.tar.gz"
        javahome="/usr/lib/jvm/jdk21"
        ;;
    i[3-6]86)
        jdkurl="https://cdn.azul.com/zulu/bin/zulu17.46.19-ca-fx-jdk17.0.9-linux_i686.tar.gz"
        javahome="/usr/lib/jvm/jdk17"
        ;;
    x86_64)
        jdkurl="https://cdn.azul.com/zulu/bin/zulu21.30.15-ca-fx-jdk21.0.1-linux_x64.tar.gz"
        javahome="/usr/lib/jvm/jdk21"
        ;;
    *)
        log "Unsupported architecture: $arch"
        exit 1
        ;;
esac

export JAVA_HOME="$javahome"
jdkarchive=$(basename "$jdkurl")

log "Installing Zulu Java JDK..."
wget -q --directory-prefix="$tmpdir" "$jdkurl" >> "$logfile" 2>&1
tar -xf "$tmpdir/$jdkarchive" -C "$tmpdir" >> "$logfile" 2>&1
sudo rm -rf "$javahome" >> "$logfile" 2>&1
filename="${jdkarchive%.tar.gz}"
sudo mkdir -p /usr/lib/jvm >> "$logfile" 2>&1
sudo mv "$tmpdir/$filename" "$javahome" >> "$logfile" 2>&1

sudo update-alternatives --install "/usr/bin/java" "java" "$javahome/bin/java" 1 >> "$logfile" 2>&1
sudo update-alternatives --install "/usr/bin/javac" "javac" "$javahome/bin/javac" 1 >> "$logfile" 2>&1

log "Setting JAVA_HOME in environment..."
if grep -q "JAVA_HOME" /etc/environment; then
    sudo sed -i '/JAVA_HOME/d' /etc/environment
fi
echo "JAVA_HOME=$javahome" | sudo tee -a /etc/environment >> "$logfile" 2>&1
source /etc/environment

log "Downloading and installing Zabbix..."
wget -q --directory-prefix="$tmpdir" "$zabbixurl" >> "$logfile" 2>&1
tar -xf "$tmpdir/$zabbixarchive" -C "$tmpdir" >> "$logfile" 2>&1
filename="${zabbixarchive%.tar.gz}"
sudo mv "$tmpdir/$filename" "$srcdir" >> "$logfile" 2>&1

if [ ! -f /etc/systemd/system/zabbix-server.service ]; then
    log "Importing Zabbix database schema..."
    cd "$srcdir/$filename/database/mysql" >> "$logfile" 2>&1
    sudo mysql -u zabbix -p"$dbzabbix" zabbix < schema.sql >> "$logfile" 2>&1
    sudo mysql -u zabbix -p"$dbzabbix" zabbix < images.sql >> "$logfile" 2>&1
    sudo mysql -u zabbix -p"$dbzabbix" zabbix < data.sql >> "$logfile" 2>&1

    sudo mysql --user=root <<_EOF_
SET GLOBAL log_bin_trust_function_creators = 0;
_EOF_

    log "Installing Apache and PHP..."
    sudo apt-get -y install fping apache2 php libapache2-mod-php php-cli php-mysql php-mbstring php-gd php-xml php-bcmath php-ldap mlocate >> "$logfile" 2>&1
    sudo updatedb >> "$logfile" 2>&1

    phpini=$(locate php.ini | head -n 1)
    sudo sed -i "s/max_execution_time = 30/max_execution_time = 300/g" "$phpini"
    sudo sed -i "s/memory_limit = 128M/memory_limit = 256M/g" "$phpini"
    sudo sed -i "s/post_max_size = 8M/post_max_size = 32M/g" "$phpini"
    sudo sed -i "s/max_input_time = 60/max_input_time = 300/g" "$phpini"
    sudo sed -i "s|;date.timezone =|date.timezone = $phptz|g" "$phpini"
    sudo systemctl restart apache2 >> "$logfile" 2>&1

    log "Installing Go and building Zabbix..."
    sudo add-apt-repository ppa:longsleep/golang-backports -y >> "$logfile" 2>&1
    sudo apt-get update >> "$logfile" 2>&1

    sudo apt-get -y install build-essential libmysqlclient-dev libssl-dev libsnmp-dev libevent-dev pkg-config golang-go >> "$logfile" 2>&1
    sudo apt-get -y install libopenipmi-dev libcurl4-openssl-dev libxml2-dev libssh2-1-dev libpcre3-dev >> "$logfile" 2>&1
    sudo apt-get -y install libldap2-dev libiksemel-dev libgnutls28-dev >> "$logfile" 2>&1

    cd "$srcdir/$filename" >> "$logfile" 2>&1

    log "Applying patches..."
    sed -i 's/strconv.Atoi(strings.TrimSpace(line\[:len(line)-2\]))/strconv.ParseInt(strings.TrimSpace(line[:len(line)-2]),10,64)/' src/go/plugins/proc/procfs_linux.go >> $logfile 2>&1
# Patch db.c to fix https://support.zabbix.com/si/jira.issueviews:issue-html/ZBX-23145/ZBX-23145
log "Patching db.c to prevent spamming log..."
sed -i '/MYSQL_OPT_RECONNECT/d' src/libs/zbxdb/db.c >> $logfile 2>&1
sed -i '/Cannot set MySQL reconnect option/d' src/libs/zbxdb/db.c >> $logfile 2>&1
# Cnange configuration options here
sudo -E ./configure --enable-server --enable-agent2 --enable-ipv6 --with-mysql --with-openssl --with-net-snmp --with-openipmi --with-libcurl --with-libxml2 --with-ssh2 --with-ldap --enable-java --prefix=/usr/local >> $logfile 2>&1
sudo -E make install >> $logfile 2>&1
# Configure Zabbix server
sudo -E chmod ug+s /usr/bin/fping
sudo -E chmod ug+s /usr/bin/fping6
sudo -E sed -i "s/# DBPassword=/DBPassword=$dbzabbix/g" "$zabbixconf" >> $logfile 2>&1
sudo -E sed -i "s|# FpingLocation=/usr/sbin/fping|FpingLocation=/usr/bin/fping|g" "$zabbixconf" >> $logfile 2>&1
sudo -E sed -i "s|# Fping6Location=/usr/sbin/fping6|Fping6Location=/usr/bin/fping6|g" "$zabbixconf" >> $logfile 2>&1
sudo -E sed -i "s/# StartPingers=1/StartPingers=10/g" "$zabbixconf" >> $logfile 2>&1

# Install Zabbix server service
if [ ! -f /etc/systemd/system/zabbix-server.service  ]; then
	log "Installing Zabbix Server Service..."
	sudo tee -a /etc/systemd/system/zabbix-server.service > /dev/null <<EOT
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

	sudo -E systemctl enable zabbix-server >> $logfile 2>&1

	# Install Zabbix agent 2 service
	log "Installing Zabbix Agent 2 Service..."
	sudo tee -a /etc/systemd/system/zabbix-agent2.service > /dev/null <<EOT
[Unit]
Description=Zabbix Agent 2
After=syslog.target network.target
 
[Service]
Type=simple
User=zabbix
ExecStart=/usr/local/sbin/zabbix_agent2 -c /usr/local/etc/zabbix_agent2.conf
RemainAfterExit=yes
PIDFile=/tmp/zabbix_agent2.pid
 
[Install]
WantedBy=multi-user.target
EOT

	sudo -E systemctl enable zabbix-agent2 >> $logfile 2>&1
else
	# Remove front end	
	sudo -E rm -rf /var/www/html/zabbix
fi
# Installing Zabbix front end
log "Installing Zabbix PHP Front End..."
cd "${srcdir}/${filename}" >> $logfile 2>&1
sudo -E mv "${srcdir}/${filename}/ui" /var/www/html/zabbix >> $logfile 2>&1
sudo -E chown -R www-data:www-data /var/www/html/zabbix >> $logfile 2>&1
# Start up Zabbix
log "Starting Zabbix Server..."
sudo -E service zabbix-server start >> $logfile 2>&1
log "Starting Zabbix Agent 2..."
sudo -E service zabbix-agent2 start >> $logfile 2>&1
log "Removing temp dir $tmpdir"
rm -rf "$tmpdir" >> $logfile 2>&1
