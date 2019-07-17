#!/bin/bash

#title           : install_zabbix_proxy.sh
#description     : This script will install and configure Zabbix Proxy.
#author		     : Younis Amedi - ya@younisamedi.com
#date            : 16 JULY 2019
#version         : 1.0  (Beta)    
#usage		     : install_zabbix_proxy.sh
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

function installOnCENTOS() {

yum clean all  -y
rpm -Uvh https://repo.zabbix.com/zabbix/4.0/rhel/7/x86_64/zabbix-release-4.0-1.el7.noarch.rpm

yum -y install zabbix-proxy-mysql.x86_64 nc

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
apt install netcat -y
wget https://repo.zabbix.com/zabbix/4.0/raspbian/pool/main/z/zabbix-release/zabbix-release_4.0-2+stretch_all.deb
dpkg -i zabbix-release_4.0-2+stretch_all.deb -y
apt install -f 
dpkg -i zabbix-release_4.0-2+stretch_all.deb -y
apt update -y
apt upgrade -y
apt install zabbix-proxy-mysql mariadb-server mariadb-client -y
systemctl restart mariadb
systemctl enable mariadb
systemctl stop zabbix-proxy
systemctl enable zabbix-proxy
}

function installOnUBUNTU() {
wget https://repo.zabbix.com/zabbix/4.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_4.0-2+bionic_all.deb
dpkg -i zabbix-release_4.0-2+bionic_all.deb
apt update -y
apt install zabbix-proxy-mysql mariadb-server mariadb-client netcat -y
systemctl restart mariadb
systemctl enable mariadb
systemctl stop zabbix-proxy
systemctl enable zabbix-proxy
}

#!/bin/bash
if [[ `which yum` ]]; then
   IS_CENTOS=1
elif [[ `which apt` ]]; then
   IS_UBUNTU=1
elif [[ `which apt` ]]; then
   IS_RASPBIAN=1   
else
   IS_UNKNOWN=1
fi

### Debuging flags
#echo $IS_RHEL
#echo $IS_DEBIAN
#echo $IS_UNKNOWN

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
telnet ${SERVER_IP} 10051
exit
}

### Feed back message in Green
echo -e "Update: \e[92m - All packages have been installed! -\e[0m"
echo "-----------------------"

echo "Please enter the following information: "

### Get user inputs
function getUserINPUT() {

read -t 30 -p "What do you like to name this Proxy : " PROXY_NAME
read -t 30 -p "Zabbix Server IP you want to connect to : " SERVER_IP
read -t 30 -p "Create a database : " DB_NAME
read -t 30 -p "Create a user  : " DB_USER
read -t 30 -s -p "Choose a password : " USER_PASS

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
createDB

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
