#!/bin/bash

yum install -y ppp iptables

cd /var/tmp
wget http://poptop.sourceforge.net/yum/stable/packages/pptpd-1.3.4-2.el6.x86_64.rpm
rpm -ivh pptpd-1.3.4-2.el6.x86_64.rpm

cat >>/etc/pptpd.conf<<EOF
localip 10.0.2.1
remoteip 10.0.2.2-100
EOF

sed -i "s/#ms-dns 10.0.0.1/ms-dns 8.8.8.8/g" /etc/ppp/options.pptpd
sed -i "s/#ms-dns 10.0.0.2/ms-dns 8.8.4.4/g" /etc/ppp/options.pptpd


cat >>/etc/ppp/chap-secrets<<EOF
user pptpd password *
EOF

sed -i 's/net.ipv4.ip_forward = 0/net.ipv4.ip_forward = 1/g' /etc/sysctl.conf
sed -i 's/net.ipv4.tcp_syncookies = 1/# net.ipv4.tcp_syncookies = 1/g' /etc/sysctl.conf
sysctl -p

iptables -t nat -A POSTROUTING -s 10.0.2.0/24 -o eth0 -j MASQUERADE
service iptables save

chkconfig pptpd on