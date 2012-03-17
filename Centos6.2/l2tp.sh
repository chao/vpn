#!/bin/bash

backup_dir=~/backup


function backupFiles() {
	if [ ! -z "$backup_dir" ]
	then
		if [ ! -d $backup_dir ] 
		then
			mkdir $backup_dir
		fi
		\cp $1 $backup_dir
	fi
}

function disableSELINUX() {
	echo "0" > /selinux/enforce

	sed -e "s/SELINUX=enforcing/SELINUX=disabled/" /etc/sysconfig/selinux > /tmp/selinux
	backupFiles /etc/sysconfig/selinux
	cat /tmp/selinux > /etc/sysconfig/selinux
	rm /tmp/selinux
}

function installDependLibs() {
yum install -y iptables make gcc xmlto bison flex lsof vim-enhanced
yum install -y ppp gmp-devel 

RED_HAT=`lsb_release -a | grep "Red Hat" -`

if [ -z "$RED_HAT" ]; then
	echo "install libraries for CentOS"
	yum install -y libpcap-devel
else
	echo "install libraries for Red Hat"
	cd /var/tmp
	wget http://mirror.centos.org/centos/6/os/x86_64/Packages/libpcap-devel-1.0.0-6.20091201git117cb5.el6.x86_64.rpm
	rpm -ivh libpcap-devel-1.0.0-6.20091201git117cb5.el6.x86_64.rpm
fi

	cd /var/tmp
	version=2.6.37
	wget http://www.openswan.org/download/openswan-${version}.tar.gz
	tar zxvf openswan-${version}.tar.gz
	cd openswan-${version}
	make USE_OBJDIR=true  programs install
}

function installXl2tpd() {
	cd /var/tmp
	wget http://downloads.sourceforge.net/project/rp-l2tp/rp-l2tp/0.4/rp-l2tp-0.4.tar.gz
	tar zxvf rp-l2tp-0.4.tar.gz
	cd rp-l2tp-0.4
	./configure
	make
	cp handlers/l2tp-control /usr/local/sbin/
	mkdir /var/run/xl2tpd/
	ln -s /usr/local/sbin/l2tp-control /var/run/xl2tpd/l2tp-control

	cd /var/tmp
#	wget http://www.xelerance.com/wp-content/uploads/software/xl2tpd/xl2tpd-1.3.0.tar.gz
	version=1.3.1
	wget ftp://fsb.xelerance.com/xl2tpd/xl2tpd-$version.tar.gz
	tar xvfz xl2tpd-$version.tar.gz
	cd xl2tpd-$version
	make all install
	mkdir /etc/xl2tpd
}

function configIPSEC() {
backupFiles /etc/ipsec.conf
cat >/etc/ipsec.conf<<END
config setup
    nat_traversal=yes
    virtual_private=%v4:10.0.0.0/8,%v4:192.168.0.0/16,%v4:172.16.0.0/12
    oe=off
    protostack=netkey

conn L2TP-PSK-NAT
    rightsubnet=vhost:%priv
    also=L2TP-PSK-noNAT

conn L2TP-PSK-noNAT
    authby=secret
    pfs=no
    auto=add
    keyingtries=3
    rekey=no
    ikelifetime=8h
    keylife=1h
    type=transport
    left=%defaultroute
    leftprotoport=17/1701
    right=%any
    rightprotoport=17/%any
END

backupFiles /etc/ipsec.secrets
sed -i '/any: PSK/,+1d' /etc/ipsec.secrets
cat >>/etc/ipsec.secrets<<EOF
%any: PSK "$psk"
EOF

backupFiles /etc/sysctl.conf
sed -i 's/net.ipv4.ip_forward = 0/net.ipv4.ip_forward = 1/g' /etc/sysctl.conf
}

function restartIPSEC() {
sysctl -p

iptables --table nat --append POSTROUTING --jump MASQUERADE
service iptables save

for each in /proc/sys/net/ipv4/conf/*
do
echo 0 > $each/accept_redirects
echo 0 > $each/send_redirects
done
/etc/init.d/ipsec restart
ipsec verify
}

function ccnfigXl2tpd() {
cat >/etc/xl2tpd/xl2tpd.conf<<END
[global]
ipsec saref = no
[lns default]
ip range = 10.0.1.2-10.0.1.254
local ip = 10.0.1.1
refuse chap = yes
refuse pap = yes
require authentication = yes
ppp debug = yes
pppoptfile = /etc/ppp/options.xl2tpd
length bit = yes
END


cat >/etc/ppp/options.xl2tpd<<END
require-mschap-v2
ms-dns 8.8.8.8
ms-dns 8.8.4.4
asyncmap 0
auth
crtscts
lock
hide-password
modem
debug
name l2tpd
proxyarp
lcp-echo-interval 30
lcp-echo-failure 4
END
}

function ccnfigStartup() {
backupFiles /etc/rc.local
cat >>/etc/rc.local<<EOF
#xl2tpd begin
for each in /proc/sys/net/ipv4/conf/*
do
echo 0 > \$each/accept_redirects
echo 0 > \$each/send_redirects
done
/etc/init.d/ipsec restart
/usr/local/sbin/xl2tpd
#xl2tpd end
EOF
}

function colorString() {
	cstr="[1;33m$1[0;39m"
}

function ccnfigUser() {
backupFiles /etc/ppp/chap-secrets
filename=/etc/ppp/chap-secrets
sed -i '/l2tpd/,+1d' $filename
uname="user"
passwd="password"
colorString "user"
read -p "username: [default value is $cstr]" uname
if [ "$uname" = "" ]; then
	uname="user"
fi
colorString "password"
passwd=$cstr
colorString $uname
read -p "${cstr}'s password: [default value is $passwd]" passwd
if [ "$passwd" = "" ]; then
	passwd="password"
fi
until [ "$passwd" = "" ]; do 
cat >>$filename<<EOF
$uname l2tpd $passwd *
EOF
passwd=""
read -p "input next username: [return to finish]" uname
if [ ! "$uname" = "" ]; then
colorString $uname
read -p "${cstr}'s password:: " passwd
fi
done

}

serverip=`ifconfig|grep Bcast|awk -F: '{print $2}' | awk '{print $1}'`

colorString "nuoduosi.com"
psk=$cstr
read -p "Please input PSK [Default PSK: $psk]: " psk
if [ "$psk" = "" ]; then
	psk="nuoduosi.com"
fi


read -p "Backup path[return to skip]: " backup_dir
(disableSELINUX)
(installDependLibs)
(configIPSEC)
(restartIPSEC)
(installXl2tpd)
(ccnfigXl2tpd)
(ccnfigStartup)
(ccnfigUser)


printf "
L2TP Information
ServerIP:$serverip
username:user
password:password
PSK:$psk

Please reboot your server for testing.
"

