#!/bin/bash

echo
lastup=$(</root/date.txt)
echo "last hosting user update : '$lastup'"

fid=$(exec mysql -u[DB_user] -h[DB_addr] -p[DB_passwd] -N -e "select ftp_id from [DB_name].[Table_name] where od_receipt_time > '$lastup'")

echo
echo ===========================================

# create user account

for i in $fid; do
useradd -d /host/"$i" $i
fpw=$(exec mysql -u[DB_user] -h[DB_addr] -p[DB_passwd] -N -e "select ftp_pw from [DB_name].[Table_name] where od_receipt_time > '$lastup' and ftp_id='$i'")
(echo "$fpw"; echo "$fpw") | passwd $i
echo "'$i' is added"
echo
echo -------------------------------------------
done;

# create dir and permission

for i in $fid; do
mkdir /host/"$i"/public_html
chown "$i":apache /host/"$i"
chown "$i":apache /host/"$i"/public_html
chmod g+rx /host/"$i"
done;

# create database

for i in $fid; do
dpw=$(exec mysql -u[DB_user] -h[DB_addr] -p[DB_passwd] -N -e "select db_pw from [DB_name].[Table_name] where od_receipt_time > '$lastup' and ftp_id='$i'")
(echo "create database $i;"; echo "grant all privileges on $i.* to '$i'@'%' identified by '$dpw';"; echo "flush privileges;"; echo "show grants for '$i'@'%';") | mysql -u[DB_user] -p[DB_passwd]
done;

# create quota

for i in $fid; do
pname=$(exec mysql -u[DB_user] -h[DB_addr] -p[DB_passwd] -N -e "select p_name from [DB_name].[Table_name] where od_receipt_time > '$lastup' and ftp_id='$i'")
edquota -p $pname $i
done;

repquota /host

# create virtualhost

for i in $fid; do
echo "" >> /etc/httpd/conf/httpd.conf
echo "<VirtualHost *:80>" >> /etc/httpd/conf/httpd.conf
echo "  ServerName $i.domain.com" >> /etc/httpd/conf/httpd.conf
echo "  DocumentRoot \"/host/$i/public_html\"" >> /etc/httpd/conf/httpd.conf
echo "  <Directory \"/host/$i/public_html\"" >> /etc/httpd/conf/httpd.conf
echo "    Require all granted" >> /etc/httpd/conf/httpd.conf
echo "    Options Indexes FollowSymLinks" >> /etc/httpd/conf/httpd.conf
echo "    AllowOverride All" >> /etc/httpd/conf/httpd.conf
echo "  </Directory>" >> /etc/httpd/conf/httpd.conf
echo "</VirtualHost>" >> /etc/httpd/conf/httpd.conf
done;

updatedate=$(date +"%Y-%m-%d %H:%M:%S")
echo $updatedate > /root/date.txt
echo "host user update all done : '$updatedate'"
httpd -k graceful
