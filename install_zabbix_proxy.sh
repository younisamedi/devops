#!/bin/bash

# Copyright (c) 2019 - Younis Amedi <ya@younisamedi.com>
# This script is licensed under GNU GPL version 2.0 or above
#=========================================================================================
#title           : install_zabbix_proxy.sh
#description     : This script will install and configure Zabbix Proxy.
#date            : 16 JULY 2019
#version         : 1.0  (Beta)    
#usage           : install_zabbix_proxy.sh
#notes           : Only applicable on CentOS7, Ubuntu18, and Raspbian9 or higher versions.
#bash_version    : 4.1.5(1)-release
#=========================================================================================

#############
############# START - Installing packages 1
#############

### Need to run as root
if [[ $EUID -ne 0 ]]; then
echo -e "\n  FAILED: You need to run this as root user.\n"
exit 1
fi

### Message to user:
echo -e "
This script will install Zabbix Proxy version 4.0. It's only applicable on the following OS distributions:

CentOS 7 
Ubuntu 18
Raspbian 10
"
read -r -p "Do you want to continue? [y/N] " response
echo ""
case "$response" in
    [yY][eE][sS]|[yY]) 
        echo "Please wait..."
        ;;
    *)
        exit 0
        ;;
esac


function installOnCENTOS() {

yum clean all  -y
rpm -Uvh https://repo.zabbix.com/zabbix/4.0/rhel/7/x86_64/zabbix-release-4.0-1.el7.noarch.rpm

yum -y install zabbix-proxy-mysql.x86_64 telnet

yum 

cat <<EOF > /etc/yum.repos.d/mariadb.repo
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.3/centos7-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF

yum -y install MariaDB-client.x86_64  MariaDB-server.x86_64

systemctl start mariadb
systemctl enable mariadb
systemctl enable zabbix-proxy

### Check SELinux status
selinuxenabled
if [ $? -ne 0 ]
then 
    echo "SELinux is disabled."
else
echo "Configuring SELinux to allow Zabbix Proxy to run" 
cd /usr/local/src
audit2allow -a -M sezabbix
semodule -i sezabbix.pp
systemctl restart zabbix-proxy
fi
}

function installOnRASPBIAN() {
update and upgrade
wget https://repo.zabbix.com/zabbix/4.0/raspbian/pool/main/z/zabbix-release/zabbix-release_4.0-2%2Bbuster_all.deb
dpkg -i zabbix-release_4.0-2+buster_all.deb
apt update -y
apt install mariadb-server -y
apt install zabbix-proxy-mysql telnet -y
systemctl restart mariadb
systemctl enable mariadb
systemctl stop zabbix-proxy
systemctl enable zabbix-proxy	
}

function installOnUBUNTU() {
wget https://repo.zabbix.com/zabbix/4.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_4.0-2+bionic_all.deb
dpkg -i zabbix-release_4.0-2+bionic_all.deb
apt update -y
apt-get install -y zabbix-proxy-mysql mariadb-server mariadb-client telnet
systemctl restart mariadb
systemctl enable mariadb
systemctl stop zabbix-proxy
systemctl enable zabbix-proxy
}

### Detect OS 1/2:
if [ -n "$(command -v lsb_release)" ]; then
	distroname=$(lsb_release -s -d)
elif [ -f "/etc/os-release" ]; then
	distroname=$(grep PRETTY_NAME /etc/os-release | sed 's/PRETTY_NAME=//g' | tr -d '="')
elif [ -f "/etc/debian_version" ]; then
	distroname="Debian $(cat /etc/debian_version)"
elif [ -f "/etc/redhat-release" ]; then
	distroname=$(cat /etc/redhat-release)
else
	distroname="$(uname -s) $(uname -r)"
fi
### Detect OS 2/2:
if [ "${distroname}" = "CentOS Linux 7 (Core)" ]; then
   IS_CENTOS=1
elif [ "${distroname}" = "Ubuntu 18.04.2 LTS" ]; then
   IS_UBUNTU=1
elif [ "${distroname}" = "Raspbian GNU/Linux 10 (buster)" ]; then
   IS_RASPBIAN=1   
else
   IS_UNKNOWN=1
   echo "This is a ${distroname} system and it's not supported."
   exit 2
fi

### Debug flags
##echo "this is centos ${IS_CENTOS}"
##echo "this is ubuntu ${IS_UBUNTU}"
##echo "this is raspbian ${IS_RASPBIAN}"
##echo "this is unknown ${IS_UNKNOWN}"

### Install packages:
if [[ "$IS_CENTOS" -eq "1" ]]; then
installOnCENTOS
echo "Zabbix Proxy installation is done." 
elif [[ "$IS_UBUNTU" -eq "1" ]]; then
installOnUBUNTU
echo "Zabbix Proxy installation is done." 
elif [[ "$IS_RASPBIAN" -eq "1" ]]; then
installOnRASPBIAN
echo "Zabbix Proxy installation is done." 
else
echo "Failed! - This script only runs on CentOS, Ubuntu, and Raspbian OS Distrubutions."
exit 2
fi

#############
############# END OF - Installing packages 1
#############
###--------------------------------------------
#############
############# START - Configuring Zabbix Proxy 
#############


### Testing port 10051 connection and restarting services
function startServices() {
systemctl restart mariadb
systemctl restart zabbix-proxy
echo "Installation is completed!"
echo "Testing port 10051 connection between Zabbix Server and Proxy, please wait..." 
exec echo 'exit' | telnet ${SERVER_IP} 10051
exit
}

### Feed back message in Green
echo -e "Update: \e[92m - All packages have been installed! -\e[0m"
echo "-----------------------"

echo "Please enter the following information: "

### Get user inputs
function getUserINPUT() {
	
echo -e "
Note: \e[92mDefault name for databases: zabbix_proxy  Default name for user:  zabbix   Default password: zabbix \e[0m \n"

read -p "What do you like to name this Proxy : " PROXY_NAME
read -p "Zabbix Server IP you want to connect to : " SERVER_IP
read -p "Create a database : " DB_NAME
read -p "Create a user  : " DB_USER
read -s -p "Choose a password : " USER_PASS

echo -e "Please review the information you entered: 

Proxy Name    : ${PROXY_NAME}
Server IP     : ${SERVER_IP}
Database Name : ${DB_NAME}
Username      : ${DB_USER}
Password      : ${USER_PASS}
"
}

### Call function
getUserINPUT

### Create a database for Zabbix Proxy
function createDB() {
MYSQL=`which mysql`
$MYSQL -e "create database ${DB_NAME} character set utf8 collate utf8_bin;"
$MYSQL -e "grant all privileges on ${DB_NAME}.* to ${DB_USER}@localhost identified by '${USER_PASS}';"
$MYSQL -e "FLUSH PRIVILEGES;"

### Set Zabbix database schema
zcat /usr/share/doc/zabbix-proxy-mysql*/schema.sql.gz | mysql ${DB_NAME}

### Set Zabbix Proxy config options
sed -ie "s/^Hostname=.*/Hostname=${PROXY_NAME}/g" /etc/zabbix/zabbix_proxy.conf
sed -ie "s/^Server=.*/Server=${SERVER_IP}/g" /etc/zabbix/zabbix_proxy.conf
sed -ie "s/^DBName=.*/DBName=${DB_NAME}/g" /etc/zabbix/zabbix_proxy.conf
sed -ie "s/^DBUser=.*/DBUser=${DB_USER}/g" /etc/zabbix/zabbix_proxy.conf
sed -ie "s/^# DBPassword=/DBPassword=${USER_PASS}/g" /etc/zabbix/zabbix_proxy.conf

### Calling "startServices" function
startServices

}

### Check if the inputs are correct before creating the database

while true
do
 read -r -p "Is the information correct? [Y/n] " input
 
 case $input in
     [yY][eE][sS]|[yY])
 
### call the createDB function
echo "Creating database and testing the connection... This may take a while, please wait." && createDB

exit 0

 ;;
     [nN][oO]|[nN])

echo "Please try again: "
getUserINPUT

        ;;
     *)
 echo "Invalid input... Type Y or n"
 ;;
 esac
done

#############
############# END OF - Configuring Zabbix Proxy 
#############
