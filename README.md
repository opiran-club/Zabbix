## [Zabbix Dashboard](https://opiran-club.github.io/Zabbix/index.html)

![image](https://github.com/user-attachments/assets/c269bd02-4c82-49a2-a354-1d699be0ed53)

###  ‼️ INSTRUCTION ‼️

#### 👉 Debian base

```
bash <(curl -s https://raw.githubusercontent.com/opiran-club/Zabbix/main/install/server.sh --ipv4)
```

[Zabbic official documents manual](https://www.zabbix.com/documentation/current/en/manual)

### Next update :
 - Zabbix agent (to connect other vm to zabbix server)
 - support for centos / almalinux

#
#
#### After finnish up installer Navigate to 
```
http://IP-ADDRESS/zabbix
```
or

```
https://DOMAIN/zabbix
```
#

### 1) click Next
![image](https://github.com/user-attachments/assets/ea3a0fda-a1f0-4314-bfe6-cc09262563ef)
#
### 2) click Next
![image](https://github.com/user-attachments/assets/6bd28102-237a-4be1-bc59-155d794baa1f)
#
### 3) type your password that you entered during setup
![image](https://github.com/user-attachments/assets/0135feae-9c36-4424-9b7d-c9efd555d70f)
#
### 4) type your desire name and select your timezone
![image](https://github.com/user-attachments/assets/51de5184-7063-4530-84ec-593ce53ad563)
#
### 5) click next
![image](https://github.com/user-attachments/assets/81c5869b-316c-4569-9899-ce56969ab405)
#
### 6) finnish
![image](https://github.com/user-attachments/assets/b8860cb0-e5e0-430f-a48d-1dff37b44da5)
#

## after finnishing setup , login the dashboard using 
#### 👉 username is:
```
Admin
```
#### 👉 password is:
```
zabbix
```
### go to users tab and change default password
### for reference document 👉 https://www.zabbix.com/documentation/current/en/manual/quickstart/login
#
-----------------------------------------------------------------------------------------
#
#
#
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

---------------------------------------------------------------------------------------------------------------------------------------

### Credits
 - credited by [OPIran](https://github.com/opiran-club)

### Contacts
 - Visit Me at [OPIran-Gap](https://t.me/opiran_official)
