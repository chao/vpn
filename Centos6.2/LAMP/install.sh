#!/bin/bash

function installMySQL() {
  mysqlpass="nuoduosi.com"
  read -p "Please input MySQL root password [Default: nuoduosi.com]: " mysqlpass
  if [ "$mysqlpass" = "" ]; then
  	mysqlpass="nuoduosi.com"
  fi
  
  yum install -y mysql mysql-server
  
  chkconfig mysqld on
  service mysqld start
  
  mysqladmin -u root password $mysqlpass
}

#安装PHP MySQL Apache2
function installApache2() {
  yum remove -y php php-common httpd
  
  cd /var/tmp
  wget http://mirror.bjtu.edu.cn/apache/httpd/httpd-2.2.21.tar.gz
  tar zxvf httpd-2.2.21.tar.gz
  cd httpd-2.2.21
  
  ./configure \
  --prefix=/usr/local/apache2 \
  --enable-module=so \
  --enable-mods-shared=all \
  --enable-auth-digest \
  --enable-rewrite \
  --enable-so \
  --enable-ssl
  make
  make install
}

function installPHP() {
  yum install -y libjpeg-devel
  rpm -ivh http://pkgs.repoforge.org/libmcrypt/libmcrypt-2.5.7-1.2.el6.rf.x86_64.rpm
  rpm -ivh http://pkgs.repoforge.org/libmcrypt/libmcrypt-devel-2.5.7-1.2.el6.rf.x86_64.rpm
  
  cd /var/tmp/
  wget http://www.php.net/distributions/php-5.3.8.tar.gz
  tar zxvf php-5.3.8.tar.gz
  cd php-5.3.8
  
  ./configure \
  --with-apxs2=/usr/local/apache2/bin/apxs \
  --prefix=/usr/local/lib/php-5.3.8 \
  --with-pear=/usr/local/lib/php-5.3.8/pear \
  --with-config-file-path=/usr/local/lib/php-5.3.8/ini\
  --with-config-file-scan-dir=/usr/local/lib/php-5.3.8/ini.d \
  --enable-zend-multibyte \
  --enable-mbstring \
  --enable-mbregex \
  --with-gd=shared \
  --with-jpeg-dir \
  --with-png-dir \
  --with-zlib-dir \
  --with-curl \
  --with-freetype-dir \
  --enable-gd-jis-conv \
  --with-xsl \
  --with-mysql \
  --with-libdir=lib64 \
  --with-mysqli \
  --with-iconv \
  --enable-pdo=shared \
  --with-pdo-mysql=shared \
  --with-pdo-sqlite=shared \
  --with-sqlite=shared \
  --with-mcrypt 
  make
  \\cp -f /usr/local/apache2/build/libtool ./libtool
  make clean
  make install
}

function configureApache() {
cat >>/usr/local/apache2/conf/httpd.conf<<END
AddType application/x-httpd-php .php .phtml     
AddType application/x-httpd-php-source .phps
END

  iptables -A INPUT -p tcp --dport 80 -i ppp0 -j ACCEPT 
  iptables -A OUTPUT -p tcp --sport 80 -j ACCEPT
  service iptables save
  
  cat >/etc/init.d/httpd<<END
  #!/bin/bash
  #
  # Startup script for the Apache Web Server
  #
  # chkconfig: - 85 15
  # description: Apache is a World Wide Web server.  It is used to serve \
  #              HTML files and CGI.
  # processname: httpd
  # pidfile: /usr/local/apache2/logs/httpd.pid
  # config: /usr/local/apache2/conf/httpd.conf

  ### BEGIN INIT INFO
  # Provides: httpd
  # Required-Start: \$local_fs \$remote_fs \$network \$named
  # Required-Stop: \$local_fs \$remote_fs \$network
  # Should-Start: distcache
  # Short-Description: start and stop Apache HTTP Server
  # Description: The Apache HTTP Server is an extensible server 
  #  implementing the current HTTP standards.
  ### END INIT INFO

  # Source function library.
  . /etc/rc.d/init.d/functions

  if [ -f /etc/sysconfig/httpd ]; then
          . /etc/sysconfig/httpd
  fi

  # Start httpd in the C locale by default.
  HTTPD_LANG=\${HTTPD_LANG-"C"}

  # This will prevent initlog from swallowing up a pass-phrase prompt if
  # mod_ssl needs a pass-phrase from the user.
  INITLOG_ARGS=""


  # Path to the apachectl script, server binary, and short-form for messages.
  apachectl=/usr/local/apache2/bin/apachectl
  httpd=/usr/local/apache2/bin/httpd
  prog=httpd
  pidfile=/usr/local/apache2/logs/httpd.pid
  RETVAL=0

  # The semantics of these two functions differ from the way apachectl does
  # things -- attempting to start while running is a failure, and shutdown
  # when not running is also a failure.  So we just do it the way init scripts
  # are expected to behave here.
  start() {
          echo -n \$"Starting \$prog: "
          daemon \$httpd \$OPTIONS
          RETVAL=\$?
          echo
          [ \$RETVAL = 0 ] && touch /var/lock/subsys/httpd
          return \$RETVAL
  }
  stop() {
          echo -n \$"Stopping \$prog: "
          killproc \$httpd
          RETVAL=\$?
          echo
          [ \$RETVAL = 0 ] && rm -f /var/lock/subsys/httpd \$pid
  }
  reload() {
          echo -n \$"Reloading \$prog: "
          killproc \$httpd -HUP
          RETVAL=\$?
          echo
  }

  # See how we were called.
  case "\$1" in
    start)
          start
          ;;
    stop)
          stop
          ;;
    status)
          status \$httpd
          RETVAL=\$?
          ;;
    restart)
          stop
          start
          ;;
    condrestart)
          if [ -f \$pid ] ; then
                  stop
                  start
          fi
          ;;
    reload)
          reload
          ;;
    graceful|help|configtest|fullstatus)
          \$apachectl \$@
          RETVAL=\$?
          ;;
    *)
          echo \$"Usage: \$prog {start|stop|restart|condrestart|try-restart|force-reload|reload|status|fullstatus|graceful|help|configtest}"
          RETVAL=2
  esac

  exit \$RETVAL
END
  chmod a+x /etc/init.d/httpd
  
  chkconfig --add httpd
	chkconfig --level 2345 httpd on
	chkconfig --list
	
	service httpd start
}

function installPhpMyAdmin() {
  cd /var/tmp
  wget http://downloads.sourceforge.net/project/phpmyadmin/phpMyAdmin/3.4.8/phpMyAdmin-3.4.8-all-languages.tar.gz
  tar zxvf phpMyAdmin-3.4.8-all-languages.tar.gz
  mv phpMyAdmin-3.4.8-all-languages phpmyadmin
  mv phpmyadmin/ /var/www/
  
  sed -i "s/#Include\ conf\/extra\/httpd-vhosts/Include\ conf\/extra\/httpd-vhosts/g" /usr/local/apache2/conf/httpd.conf

  cat >/usr/local/apache2/conf/extra/httpd-vhosts.conf<<END
NameVirtualHost *:80
<VirtualHost *:80>
  ServerAdmin admin@server.com
  DocumentRoot /var/www/phpmyadmin
  ServerName phpmyadmin.server.com
  
  <Directory "/var/www/phpmyadmin/">
     Options Indexes FollowSymLinks MultiViews
     AllowOverride All 
     Order allow,deny
     allow from all
  </Directory>
  
  <IfModule dir_module>
      DirectoryIndex index.php
  </IfModule>
  # Logging
  ErrorLog logs/phpmyadmin.server.com-error_log
  CustomLog logs/phpmyadmin.server.com-access_log common
</VirtualHost>
END
  
  service httpd restart
  
  cd /var/www/phpmyadmin
  cp config.sample.inc.php config.inc.php
  sed -i "s/\$cfg\['blowfish_secret'\]\ =\ ''/\$cfg\['blowfish_secret'\]\ =\ 'nuoduosi.com'/g" config.inc.php
}

function patchHost() {
  cat >/etc/hosts<<END
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
127.0.0.1       as6.hnceri.com
END
}

(patchHost)
(installMySQL)
(installApache2)
(installPHP)
(configureApache)
(installPhpMyAdmin)

clear
echo "Remember to check your firewall!"

