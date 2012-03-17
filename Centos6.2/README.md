# 准备工作

我们所使用的Centos是64位版的Centos 6.1。如果您使用的版本和我们不同，在安装的过程中可能会有所出入，请您注意。

## 更新升级系统

在开始安装L2TP之前，我们建议您将您的系统中的软件进行一次更新。您可以使用以下命令完成内容更新

    yum -y update
    yum -y upgrade

## 关闭SELinux

SELinux 是 2.6 版本的 Linux 内核中提供的强制访问控制 (MAC)系统。对于目前可用的 Linux 安全模块来说，SELinux 是功能最全面，而且测试最充分的，它是在 20 年的 MAC 研究基础上建立的。SELinux 在类型强制服务器中合并了多级安全性或一种可选的多类策略，并采用了基于角色的访问控制概念。但是为了方便起见，我们在本次安装中需要将SELinux关闭。

    echo "0" > /selinux/enforce

为了重启以后依然关闭SELinux，我们编辑/etc/sysconfig/selinux

设置

    SELINUX=disabled

## 配置Hostname

如果您在安装系统时没有正确的输入hostname，在安装完成后您依然可以通过编辑/etc/sysconfig/network来修改您的hostname。修改完成后内容如下：

    NETWORKING=yes
    HOSTNAME=your.domain.com

然后您需要在/etc/hosts中加入响应的纪录以方便将来快速的获得主机的IP。编辑/etc/hosts，增加以下内容：

    192.168.30.204 your.domain.com

请将192.168.30.204修改为您真实的IP，将your.domain.com修改为您的真实yu ming

在完成以上操作后您重启计算机后应该可以通过hostname -i”命令来获得您主机的IP。

## 安装所需要的工具

在开始进行L2TP服务的安装之前我们首先要将我们的编译代码时要使用的工具准备好。通过以下命令安装GCC，Make等工具。

    yum install -y iptables make gcc xmlto bison flex lsof vim-enhanced

# 安装L2TP

## 安装ppp和openswan

由于兼容性的问题openswan建议使用2.6.24版本。

    yum install -y ppp gmp-devel libpcap-devel

安装openswan:

    cd /var/tmp
    wget http://www.openswan.org/download/openswan-2.6.24.tar.gz
    tar zxvf openswan-2.6.24.tar.gz
    cd openswan-2.6.24
    make programs install

## 配置ipsec

修改/etc/ipsec.conf为以下内容：

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
        left=192.168.30.204
        leftprotoport=17/1701
        right=%any
        rightprotoport=17/%any

编辑/etc/ipsec.secrets为以下内容，其中YOURPSK为任何字符串。将来您需要使用该字符串作为共享密钥连接L2TP VPN。

    192.168.30.204 %any: PSK "YOURPSK"

## 修改包转发设置

执行以下命令以允许包转发



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

## 检查ipsec

重启ipsec后使用ipsec verify命令检查 ipsec是否正确。如果显示结果和下图一致则表示ipsec已经正确安装。

    service ipsec restart
    ipsec verify

![ipsec verify结果](http://substance-assets.s3.amazonaws.com/65/e7b226937efc960447fccb5856c680/ipsec.png)

## 安装xl2tp

下载和安装rp-l2tp，并且将编译以后的l2tp-control拷贝到xl2tpd服务目录中备用。

    cd /var/tmp
    wget http://downloads.sourceforge.net/project/rp-l2tp/rp-l2tp/0.4/rp-l2tp-0.4.tar.gz
    tar zxvf rp-l2tp-0.4.tar.gz
    cd rp-l2tp-0.4
    ./configure
    make
    cp handlers/l2tp-control /usr/local/sbin/
    mkdir /var/run/xl2tpd/
    ln -s /usr/local/sbin/l2tp-control /var/run/xl2tpd/l2tp-control

下载和安装xl2tp

    cd /var/tmp
    wget http://www.xelerance.com/wp-content/uploads/software/xl2tpd/xl2tpd-1.2.4.tar.gz
    tar zxvf xl2tpd-1.2.4.tar.gz
    cd xl2tpd-1.2.4
    make install
    mkdir /etc/xl2tpd

编辑/etc/xl2tpd/xl2tpd.conf，内容如下：

    [global]
    ipsec saref = yes
    [lns default]
    ip range = 10.0.1.2-10.0.1.254
    local ip = 10.0.1.1
    refuse chap = yes
    refuse pap = yes
    require authentication = yes
    ppp debug = yes
    pppoptfile = /etc/ppp/options.xl2tpd
    length bit = yes

编辑/etc/ppp/options.xl2tpd，内容如下：

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

增加用户，编辑/etc/ppp/chap-secrets

    username l2tpd password *
    
#防火墙

在完成L2TP VPN的安装后我们需要检查默认的防火墙设置：

    iptables -L
    
默认情况下，Centos中有一条拒绝所有INPUT和FORWARD的规则。我们需要将其删除。    

![iptables](http://tmp.transloadit.com.s3.amazonaws.com/bf1b894324811aab0344df39f4863db1)

我们需要将INPUT规则中的第5条和FORWARD中的第一条删除

    iptables -D FORWARD 1
    iptables -D INPUT 5
    service iptables save