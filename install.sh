git clone --depth 1 https://github.com/opiran-club/zabbix.git
cd /zabbix/install
./server.sh

# Navigate to http://hostname/zabbix

# Get DB password from script and finalize front end 
configuration

# Login using Admin/zabbix

# To stop and start Zabbix server

# sudo service zabbix-server stop
# sudo service zabbix-server start

# Install database
cd /zabbix/install

./mysql.sh

# to change mounts
sudo nano /etc/systemd/system/multi-user.target.wants/mysql.service
Add remote-fs.target to After
Add RequiresMountsFor=/your/mount/dir to [Unit] section
sudo systemctl daemon-reload

To stop and start MySQL server

sudo service mysql stop
sudo service mysql start
These changes can be removed during apt upgrade, so if you see mysql fail to start after reboot add service changes back in.

# Install Agent 
Install Zabbix Agent 2 script on client.
Make sure to change configuration to point to your Zabbix server before running. 
You can always configure manually should you forget. 
Upgrade is performed if existing install detected and configuration is saved to /usr/local/etc/zabbix_agent2.conf.bak

cd /zabbix/install

./agent.sh

sudo service zabbix-agent2 stop
sudo service zabbix-agent2 start
