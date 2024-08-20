## [Zabbix Server / Agent](https://opiran-club.github.io/Zabbix/)

###  ‼️ INSTRUCTION ‼️

#### 👉 With root user

```
bash <(curl -s https://raw.githubusercontent.com/opiran-club/Zabbix/main/install/server.sh --ipv4)
```

#### After finnish up installer Navigate to 
```
http(S)://IP-ADDRESS/zabbix
```
#### Login using Admin/zabbix and password which you pick during setup

#### To stop and start Zabbix server

```
service zabbix-server stop / service zabbix-server start
```

#### To stop and start MySQL server

```
service mysql stop / service mysql start
```

#### To stop and start agent service

```
service zabbix-agent stop / service zabbix-agent start
```

-----------------------------------------------------------------------------------------

### 👉 Install Agent on another server to connect to zabbix server

#### On menu pick zabbix agent


-----------------------------------------------------------------------------------------
### 👉 To change current database location (var/lib/zabbix)

#### On menu pick Database Migeration

-----------------------------------------------------------------------------------------
### 👉 To uninstall all packages (mysql / zabbix service )

#### On menu pick uninstall

---------------------------------------------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------------------------------------------

### Credits
 - credited by [OPIran](https://github.com/opiran-club)

### Contacts
 - Visit Me at [OPIran-Gap](https://t.me/opiran_official)
