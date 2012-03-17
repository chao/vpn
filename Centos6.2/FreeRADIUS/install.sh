#!/bin/bash


#http://www.fallday.org/archives/703
function installFreeRadius() {
cd /var/tmp
wget -c ftp://ftp.freeradius.org/pub/freeradius/freeradius-server-2.1.12.tar.gz
tar zxf freeradius-server-2.1.12.tar.gz
cd freeradius-server-2.1.12
./configure
make && make install

sed -i "s/#[ \t]*\$INCLUDE sql\.conf/\t\$INCLUDE sql.conf/g" /usr/local/etc/raddb/radiusd.conf

mysql -u root --password=$mysqlpass -e "CREATE USER 'radius'@'localhost' IDENTIFIED BY '$mysqlpass';"
mysql -u root --password=$mysqlpass -e "CREATE DATABASE IF NOT EXISTS radius;"
mysql -u root --password=$mysqlpass -e "GRANT ALL PRIVILEGES ON radius.* TO radius@localhost;"

cd /usr/local/etc/raddb/sql/mysql
sed -i 's/radpass/nuoduosi\.com/g' admin.sql
sed -i 's/radpass/nuoduosi\.com/g' /usr/local/etc/raddb/sql.conf

#mysql -u root --password=$mysqlpass < admin.sql
mysql -u root --password=$mysqlpass radius < ippool.sql
mysql -u root --password=$mysqlpass radius < schema.sql
mysql -u root --password=$mysqlpass radius < wimax.sql
mysql -u root --password=$mysqlpass radius < cui.sql
mysql -u root --password=$mysqlpass radius < nas.sql

sed -i "s/#readclients/readclients/g" /usr/local/etc/raddb/sql.conf

cat >>/usr/local/etc/raddb/sql/mysql/dialup.conf<<END
  simul_count_query = "SELECT COUNT(*) \\
                     FROM ${acct_table1} \\
                     WHERE username = '%{SQL-User-Name}' \\
                     AND acctstoptime IS NULL"
END
}

function patchRadiusConf() {
patch -p 0 < patch.default  
patch -p 0 < patch.inner-tunnel
cp /usr/local/sbin/rc.radiusd /etc/init.d/radiusd
#start radius server after system booted
cat >>/etc/rc.local<<EOF
/etc/init.d/radiusd start
EOF

}

function installRadiusClient() {
cd /var/tmp
wget -c ftp://ftp.freeradius.org/pub/freeradius/freeradius-client-1.1.6.tar.gz
tar -zxf freeradius-client-1.1.6.tar.gz
cd freeradius-client-1.1.6
./configure
make && make install

cat >>/usr/local/etc/radiusclient/servers<<END
localhost nuoduosi.com
END

sed -i "s/^[ \t]*secret[ \f\t\v]*=[^\r]*$/\tsecret = nuoduosi\.com/g" /usr/local/etc/raddb/clients.conf
sed -i 's/ipaddr\ =\ 127\.0\.0\.1/ipaddr\ =\ $serverip /g' /usr/local/etc/raddb/clients.conf

cd /var/tmp
wget -c http://small-script.googlecode.com/files/dictionary.microsoft
mv ./dictionary.microsoft /usr/local/etc/radiusclient/

cat >>/usr/local/etc/radiusclient/dictionary<<EOF
INCLUDE /usr/local/etc/radiusclient/dictionary.sip
INCLUDE /usr/local/etc/radiusclient/dictionary.ascend
INCLUDE /usr/local/etc/radiusclient/dictionary.merit
INCLUDE /usr/local/etc/radiusclient/dictionary.compat
INCLUDE /usr/local/etc/radiusclient/dictionary.microsoft
EOF
}

function configL2TP() {
#for l2tp

cat >>/etc/ppp/options.xl2tpd<<EOF
plugin /usr/lib64/pppd/2.4.5/radius.so
radius-config-file /usr/local/etc/radiusclient/radiusclient.conf
EOF
}

function configSQL() {
cd /var/tmp
cat >init.sql<<END
INSERT INTO radcheck (username,attribute,op,VALUE) VALUES ('demo','Cleartext-Password',':=','demo');
INSERT INTO radusergroup (username,groupname) VALUES ('demo','VIP1');
INSERT INTO radgroupcheck (groupname,attribute,op,VALUE) VALUES ('normal','Simultaneous-Use',':=','1');

INSERT INTO radgroupreply (groupname,attribute,op,VALUE) VALUES ('VIP1','Auth-Type',':=','Local');
INSERT INTO radgroupreply (groupname,attribute,op,VALUE) VALUES ('VIP1','Service-Type',':=','Framed-User');
INSERT INTO radgroupreply (groupname,attribute,op,VALUE) VALUES ('VIP1','Framed-Protocol',':=','PPP');
INSERT INTO radgroupreply (groupname,attribute,op,VALUE) VALUES ('VIP1','Framed-MTU',':=','1500');
INSERT INTO radgroupreply (groupname,attribute,op,VALUE) VALUES ('VIP1','Framed-Compression',':=','Van-Jacobson-TCP-IP');
END

mysql -u root --password=$mysqlpass radius < init.sql
}

function configPPTP() {
#for pptp
sed -i 's/logwtmp/\#logwtmp/g' /etc/pptpd.conf
sed -i 's/radius_deadtime/\#radius_deadtime/g' /usr/local/etc/radiusclient/radiusclient.conf
sed -i 's/bindaddr/\#bindaddr/g' /usr/local/etc/radiusclient/radiusclient.conf

cat >>/etc/ppp/options.pptpd<<EOF
plugin /usr/lib64/pppd/2.4.5/radius.so
radius-config-file /usr/local/etc/radiusclient/radiusclient.conf
EOF
}

function installPamRadius() {
cd /var/tmp
wget -c ftp://ftp.freeradius.org/pub/radius/pam_radius-1.3.17.tar.gz
tar zxvf pam_radius-1.3.17.tar.gz
cd pam_radius-1.3.17
make
cp pam_radius_auth.so /lib/security/

mkdir /etc/raddb
chown root /etc/raddb/
chown root /etc/raddb
cp pam_radius_auth.conf /etc/raddb/server
chmod go-rwx /etc/raddb
chmod go-rwx /etc/raddb/server
sed -i 's/127.0.0.1\\tsecret/$serverip:1812\\t$mysqlpass/g' /etc/raddb/server 
}

function configSSH() {
patch -p 0 < sshd.patch
}

function startService() {
/etc/init.d/radiusd start
/etc/init.d/sshd restart
/etc/init.d/pptpd restart-kill
}

mysqlpass="nuoduosi.com"
read -p "Please input MySQL root password [Default: nuoduosi.com]: " mysqlpass
if [ "$mysqlpass" = "" ]; then
	mysqlpass="nuoduosi.com"
fi
serverip=`ifconfig|grep Bcast|awk -F: '{print $2}' | awk '{print $1}'`



(installFreeRadius)
(patchRadiusConf)
(installRadiusClient)
(configSQL)
(configL2TP)
(configPPTP)
(installPamRadius)
(configSSH)
(startService)


exit
#cd /var/tmp
#wget http://mirrors.163.com/centos/6.2/os/x86_64/Packages/freeradius-2.1.10-5.el6.x86_64.rpm
#wget http://mirrors.163.com/centos/6.2/os/x86_64/Packages/freeradius-mysql-2.1.10-5.el6.x86_64.rpm
#wget http://mirrors.163.com/centos/6.2/os/x86_64/Packages/freeradius-utils-2.1.10-5.el6.x86_64.rpm
#rpm -ivh freeradius-2.1.10-5.el6.x86_64.rpm
#rpm -ivh freeradius-mysql-2.1.10-5.el6.x86_64.rpm
#rpm -ivh freeradius-utils-2.1.10-5.el6.x86_64.rpm

#cd /var/tmp
#wget ftp://ftp.samba.org/pub/ppp/ppp-2.4.5.tar.gz
#tar zxvf ppp-2.4.5.tar.gz
#cp -R ppp-2.4.5/pppd/plugins/radius/etc/ /usr/local/etc/radiusclient


#sed -i "s/#[ \t]*\$INCLUDE sql\/mysql\/counter\.conf/\t\$INCLUDE sql\/mysql\/counter\.conf/g" /etc/raddb/radiusd.conf

