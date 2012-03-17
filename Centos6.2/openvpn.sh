#!/bin/bash

#http://sohonetwork.blogspot.com/2010/08/installing-openvpn-on-centos-55-x8664.html

TUN_TAP=`cat /dev/net/tun | grep "File descriptor in bad state" -`

if [ -z "$TUN_TAP" ]; then
	echo "You cannot install OpenVPN without TUN/TAP"
	exit
fi

yum install -y gcc make
yum install -y rpm-build
yum install -y autoconf.noarch
yum install -y zlib-devel
yum install -y pam-devel
yum install -y openssl-devel

cd /var/tmp
wget http://openvpn.net/release/lzo-1.08-4.rf.src.rpm
rpmbuild --rebuild lzo-1.08-4.rf.src.rpm
rpm -Uvh /usr/src/redhat/RPMS/x86_64/lzo-*.rpm

OS = `getconf LONG_BIT`
if [ "$OS" = "64" ]; then
  wget http://dag.wieers.com/rpm/packages/rpmforge-release/rpmforge-release-0.3.6-1.el5.rf.x86_64.rpm
  rpm -Uvh rpmforge-release-0.3.6-1.el5.rf.x86_64.rpm
else
  wget http://dag.wieers.com/rpm/packages/rpmforge-release/rpmforge-release-0.3.6-1.el5.rf.i386.rpm
  rpm -Uvh rpmforge-release-0.3.6-1.el5.rf.i386.rpm
fi

yum install -y openvpn

# create the certificate
cp -r /usr/share/doc/openvpn-2.2.0/easy-rsa/ /etc/openvpn/
cd /etc/openvpn/easy-rsa/2.0
chmod 755 *
source ./vars
./vars
./clean-all


local 74.82.170.179 #- change it with your server ip address
port 1234 #- change the port you want
proto udp #- protocol can be tcp or udp
dev tun
tun-mtu 1500
tun-mtu-extra 32
mssfix 1450
ca /etc/openvpn/easy-rsa/2.0/keys/ca.crt
cert /etc/openvpn/easy-rsa/2.0/keys/server.crt
key /etc/openvpn/easy-rsa/2.0/keys/server.key
dh /etc/openvpn/easy-rsa/2.0/keys/dh1024.pem
plugin /usr/share/openvpn/plugin/lib/openvpn-auth-pam.so /etc/pam.d/login
client-cert-not-required
username-as-common-name
server 10.8.0.0 255.255.255.0
push "redirect-gateway def1"
push "dhcp-option DNS 208.67.222.222"
push "dhcp-option DNS 4.2.2.1"
keepalive 5 30
comp-lzo
persist-key
persist-tun
status server-tcp.log
verb 3