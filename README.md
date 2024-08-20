## Zabbix Server / Agent

```
bash <(curl -s https://raw.githubusercontent.com/opiran-club/Zabbix/main/install/server.sh --ipv4)
```

### After finnish up installer Navigate to 
```
http(S)://IP-ADDRESS/zabbix
```
### Login using Admin/zabbix and password which you pick during setup

### To stop and start Zabbix server

```
service zabbix-server stop / service zabbix-server start
```

### To stop and start MySQL server

```
service mysql stop / service mysql start
```

### To stop and start agent service

```
service zabbix-agent stop / service zabbix-agent start
```

-----------------------------------------------------------------------------------------

### Install Agent on client

# On menu pick zabbix agent

```
bash <(curl -s https://raw.githubusercontent.com/opiran-club/Zabbix/main/install/server.sh --ipv4)
```

-----------------------------------------------------------------------------------------
### Rolling back your database from backup in /var/lib

# On menu pick Rolling back database

```
bash <(curl -s https://raw.githubusercontent.com/opiran-club/Zabbix/main/install/server.sh --ipv4)
```
