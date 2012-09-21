#!/bin/bash
#Date 20-Sep-2012
#Purpose Nagios Full installation with packages
#Author Sunil Sankar
tmpdir="$(dirname $0)"
echo ${tmpdir} | grep '^/' >/dev/null 2>&1
if [ X"$?" == X"0" ]; then
    export NAGIOSDIR="${tmpdir}"
else
    export NAGIOSDIR="$(pwd)"
fi
echo $NAGIOSDIR
# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
echo "This script must be run as root" 1>&2
exit 1
fi
PACKAGE="$NAGIOSDIR/rpms"
SOURCE=$NAGIOSDIR/source
cat << EOF > nagios.repo
[nagios]
name=Nagios Complete Installation with Packages
baseurl=file://$PACKAGE
enabled=1
gpgcheck=0
EOF
#cat nagios.repo
#Disabling all repo except the new one
cp nagios.repo /etc/yum.repos.d/
#yum --disablerepo=* --enablerepo=nagios list available
#Installation 
HOSTIPADDRESS=`ifconfig  | grep 'inet addr:'| grep -v '127.0.0.1' | cut -d: -f2 | awk '{ print $1}'`
NAGIOSPATH=/opt/nagios
ADDONS=/opt/nagios/addons
DOWNLOAD_DIR=$SOURCE
##Packages##
NAGIOSPACKAGE=nagios-3.4.1.tar.gz
NAGIOSPLUGIN=nagios-plugins-1.4.16
MKLIVE=mk-livestatus-1.2.0p2
MERLIN=merlin-v1.2.1
NINJA=ninja-v2.0.6
nagiosinstall () {
cd $DOWNLOAD_DIR
useradd nagios
/usr/sbin/groupadd nagcmd
/usr/sbin/usermod -a -G nagcmd nagios
/usr/sbin/usermod -a -G nagcmd apache
yum -y --disablerepo=* --enablerepo=nagios install httpd php net-snmp*  mysql-server libdbi-dbd-mysql libdbi-devel php-cli php-mysql gcc glibc glibc-common gd gd-devel openssl-devel perl-DBD-MySQL mysql-server mysql-devel php php-mysql php-gd php-ldap php-xml perl-DBI perl-DBD-MySQL perl-Config-IniFiles perl-rrdtool php-pear  make cairo-devel glib2-devel pango-devel openssl* rrdtool* php-gd gd gd-devel gd-progs wget MySQL-python gcc-c++ cairo-devel libxml2-devel pango-devel pango libpng-devel freetype freetype-devel libart_lgpl-devel perl-Crypt-DES perl-Digest-SHA1 perl-Digest-HMAC perl-Socket6 perl-IO-Socket-INET6 net-snmp net-snmp-libs php-snmp dmidecode lm_sensors perl-Net-SNMP net-snmp-perl fping graphviz cpp glib2-devel php-gd php-mysql php-snmp php-ldap php-date php-mail php-mail-mime php-net-smtp php-net-socket php5-xmlrpc php-mbstring php-posix postfix
tar -zxvf $NAGIOSPACKAGE
tar -zxvf $NAGIOSPLUGIN.tar.gz
cd nagios
./configure --with-command-group=nagcmd --prefix=$NAGIOSPATH
make all
make install; make install-init; make install-config; make install-commandmode; make install-webconf
echo "Copying Eventhandlers"
cp -R contrib/eventhandlers/ $NAGIOSPATH/libexec/
chown -R nagios:nagios /usr/local/nagios/libexec/eventhandlers
cd ..
cd 	$NAGIOSPLUGIN
./configure --with-nagios-user=nagios --with-nagios-group=nagios --prefix=$NAGIOSPATH
make && make install
chkconfig --add nagios
chkconfig --level 3 nagios on
chkconfig --level 3 httpd on	
htpasswd -s -b -c /opt/nagios/etc/htpasswd.users nagiosadmin nagiosadmin
echo /opt/nagios/bin/nagios -v /opt/nagios/etc/nagios.cfg > /sbin/nagioschk
chmod 755 /sbin/nagioschk
#For running commands from website
/usr/sbin/usermod -a -G nagcmd apache
chmod 775 /opt/nagios/var/rw
chmod g+s /opt/nagios/var/rw
/etc/init.d/httpd restart
/etc/init.d/nagios restart
echo "Nagios and Nagios Plugins installed successfully"
echo "Please access the Nagios Dashboard "
echo "http://$HOSTIPADDRESS/nagios"
echo "Please login with the following Credentials"
echo "USERNAME: nagiosadmin"
echo "PASSWORD: nagiosadmin"
}
livestatusinstall () {
cd $DOWNLOAD_DIR
tar -zxvf $MKLIVE.tar.gz
cd $MKLIVE
./configure --prefix=$ADDONS/livestatus
make && make install
sed -i '/file!!!/ a\broker_module=/opt/nagios/addons/livestatus/lib/mk-livestatus/livestatus.o /opt/nagios/var/rw/live' /opt/nagios/etc/nagios.cfg
/etc/init.d/nagios restart
}
##Merlin installation###
merlininstall () {
/etc/init.d/mysqld restart
cd $DOWNLOAD_DIR
tar -zxvf $MERLIN.tar.gz
cd $MERLIN
make
mysql -u root -e 'create database merlin'
mysql -u root -e "grant all privileges on merlin.* to merlin@localhost identified by 'merlin'"
mysql -u root -e 'flush privileges'
./install-merlin.sh --nagios-cfg=$NAGIOSPATH/etc/nagios.cfg --dest-dir=$NAGIOSPATH/addons/merlin
/etc/init.d/nagios restart
/etc/init.d/merlind restart
/etc/init.d/nagios restart
chkconfig  --level 3 mysqld on
chkconfig  --level 3 merlind on
sed -i '/merlin_dir/s&/opt/monitor/op5/merlin&/opt/nagios/addons/merlin&g' /usr/bin/mon
cd /usr/libexec/merlin/modules
sed -i 's&/opt/monitor/op5/merlin/&/opt/nagios/addons/merlin/&g' *.py
sed -i 's&/opt/monitor/bin/monitor&/opt/nagios/bin/nagios&g' *.py
cd /usr/libexec/merlin
sed -i 's&/opt/monitor&/opt/nagios&g' *.py
sed -i 's&/opt/nagios/op5&/opt/nagios/addons&g' *.py
sed -i 's&/opt/nagios/bin/monitor&/opt/nagios/bin/nagios&g' *.py
sed -i 's&/opt/nagios/addons/livestatus/livestatus.o&/opt/nagios/addons/livestatus/lib/mk-livestatus/livestatus.o&g' *.py
sed -i 's&/opt/monitor&/opt/nagios&g' *.sh
sed -i 's&/etc/init.d/monitor&/etc/init.d/nagios&g' *.sh
sed -i '/slay/d' stop.sh
sed -i 's/configtest/checkconfig/g' restart.sh
}

case "$1" in
'download')
echo "Downloading Application"
download
;;
'nagiosinstall')
echo "Installing application"
nagiosinstall
;;
'livestatusinstall')
echo "Installing LiveStatus Application"
livestatusinstall
;;
'merlininstall')
echo "Installing Merlin Application"
merlininstall
;;
*)
echo "Usage: $0 [download|nagiosinstall|livestatusinstall|merlininstall]"
;;
esac	

