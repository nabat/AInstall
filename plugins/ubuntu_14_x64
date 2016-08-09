#OS Ubuntu 14_x64
#COMMENTS Ubuntu comments
#M update:upgrade:apt-get update
#M mysql:MySQL:_install mysql-server
#M apache:apache:_install_apache
#M perl_modules:Perl_modules:_install libexpat1 ssl-cert cvs libdbi-perl libdbd-mysql-perl libdigest-md4-perl libdigest-sha-perl libcrypt-des-perl libgdbm3 libgdbm-dev
#M freeradius:Freeradius_Server:_install_freeradius
#M DHCP:Dhcp_server:_install isc-dhcp43-server
#M flow-tools:Flow-tools,Ipcad:_install_ipn
#M mrtg:Mrtg,Rstat:_install_mrtg
#M accel_ppp:ACCEL-PPPoE:_install_accel_pppoe
#M FSbackup:FSbackup:install_fsbackup
#M Mail:Mail_server:install_mail
#M build_kernel:Build_Kernel:echo test
# perl_speedy 
#M utils:Utils:_install vim tmux bash git

# Variable

YES="-y"
BUILD_OPTIONS=" sudo apt-get ${YES} install "
MYSQLDUMP=/bin/gzip
GZIP=/usr/bin/mysqldump
WEB_SERVER_USER=www-data
APACHE_CONF_DIR=/etc/apache2/sites-enabled/
RESTART_MYSQL=/etc/init.d/mysql
RESTART_RADIUS=/usr/local/etc/rc.d/radiusd
RESTART_APACHE=/etc/init.d/apache2
RESTART_DHCP=/usr/local/etc/rc.d/isc-dhcp
PING=/sbin/ping

#Services to check after installation
PROCESS_LIST="mysqld radiusd apache2 flow-capture named"


#******************************************************************
#  PRE INSTALL
#******************************************************************
pre_install () {

	_install dialog nano gcc
  
  LEGACY_SQL_MODE_ENABLE="SET GLOBAL sql_mode = 'NO_ENGINE_SUBSTITUTION';SET SESSION sql_mode = 'NO_ENGINE_SUBSTITUTION';";
  find /usr/abills/db/ -type f | while read FILENAME; do
    sed -i "1 i${LEGACY_SQL_MODE_ENABLE}" ${FILENAME};
  done;
  
	CURRENT_DIR=`pwd`
}



#******************************************************************
# Apache2
#******************************************************************
_install_apache() {
	_install apache2 
	_install apache2-doc 
	_install apache2-utils 
	_install apache2-mpm-prefork
	a2enmod ssl
	a2enmod rewrite
	a2enmod suexec
	a2enmod include
	a2enmod cgid
	
	chown -Rf www-data:www-data /usr/abills/cgi-bin
	chown -Rf www-data:www-data /usr/abills/Abills/templates
	chown -Rf www-data:www-data /usr/abills/backup
	${RESTART_APACHE} restart
}
#*******************************************
#  Radius 
#*******************************************
_install_freeradius() {
	_install gcc make libmysqlclient-dev
  
	if [ -d /usr/local/freeradius/ ]; then
		echo "Radius exists: /usr/local/freeradius/";
		return 0 ;
	fi;
  
  PERL_LIB_DIRS="/usr/lib/ /usr/lib/i386-linux-gnu/ /usr/lib64/ /usr/lib/x86_64-linux-gnu/ /usr/lib64/perl5/CORE/ /usr/lib/perl5/5.10.0/x86_64-linux-thread-multi/CORE/ /usr/lib/perl5/CORE/"
  
	for dir in ${PERL_LIB_DIRS}; do
	if [ "${DEBUG}" = 1 ]; then
		echo "ls ${dir}/libperl* | head -1"  
	fi;

	PERL_LIB=`ls ${dir}/libperl* | head -1`;
	if [ x"${PERL_LIB}" != x ]; then
		PERL_LIB_DIR=${dir}
		if [ ! -f ${PERL_LIB_DIR}/libperl.so ]; then
		ln -s ${PERL_LIB} ${PERL_LIB_DIR}libperl.so
		fi;
	fi;
	done;


	if [ x"${PERL_LIB_DIR}" = x ]; then
		echo "Perl lib not found";
		exit;
	else
		echo "Perl lib: ${PERL_LIB_DIR}libperl.so"
	fi;

	FREERADIUS_VERSION="2.2.9"
	RADIUS_SERVER_USER="freerad"
 
	_fetch freeradius-server-${FREERADIUS_VERSION}.tar.gz ftp://ftp.freeradius.org/pub/freeradius/freeradius-server-${FREERADIUS_VERSION}.tar.gz

	if [ ! -f freeradius-server-${FREERADIUS_VERSION}.tar.gz ]; then
		echo "Can\'t download freeradius. PLease download and install it manual";
		exit;
	fi;

	tar zxvf freeradius-server-${FREERADIUS_VERSION}.tar.gz

	cd freeradius-server-${FREERADIUS_VERSION}
	./configure --prefix=/usr/local/freeradius --with-rlm-perl-lib-dir=${PERL_LIB_DIR} --without-openssl --with-dhcp > 1
	echo "./configure --prefix=/usr/local/freeradius --with-rlm-perl-lib-dir=${PERL_LIB_DIR} --without-openssl --with-dhcp " > configure_abills
	make && make install

  echo "" > /usr/local/freeradius/etc/raddb/clients.conf

	ln -s /usr/local/freeradius/sbin/radiusd /usr/sbin/radiusd

	#Add user
	groupadd ${RADIUS_SERVER_USER}
	useradd -g ${RADIUS_SERVER_USER} -s /bash/bash ${RADIUS_SERVER_USER}
	chown -R ${RADIUS_SERVER_USER}:${RADIUS_SERVER_USER} /usr/local/freeradius/etc/raddb
	echo "_________________________________________________________________"
	echo " RADIUS SCRIPT AUTOSTART"
	echo "_________________________________________________________________"
	cat << 'EOF' > /etc/init.d/radiusd
#!/bin/sh
#
# radiusd	Start the radius daemon.
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA
#
#    Copyright (C) 2001-2008 The FreeRADIUS Project http://www.freeradius.org
#   chkconfig: - 58 74
#   description: radiusd is service access provider Daemon.
### BEGIN INIT INFO
# Provides: radiusd
# Should-Start: radiusd
# Should-Stop: radiusd
# Short-Description: start and stop radiusd
# Description: radiusd is access provider service Daemon.
### END INIT INFO

prefix=/usr/local/freeradius
exec_prefix=${prefix}
sbindir=${exec_prefix}/sbin
localstatedir=/var
logdir=${localstatedir}/log/radius
rundir=/usr/local/freeradius/var/run/radiusd/
sysconfdir=${prefix}/etc
#
#  If you have issues with OpenSSL, uncomment these next lines.
#
#  Something similar may work for MySQL, and you may also
#  have to LD_PRELOAD libz.so
#
#LD_LIBRARY_PATH=
#LD_RUN_PATH=:
#LD_PRELOAD=libcrypto.so
export LD_LIBRARY_PATH LD_RUN_PATH LD_PRELOAD

RADIUSD=$sbindir/radiusd
RADDBDIR=${sysconfdir}/raddb
RADIUS_USER='freerad'
DESC="FreeRADIUS"

#
#  See 'man radiusd' for details on command-line options.
#
ARGS=""

test -f $RADIUSD || exit 0
test -f $RADDBDIR/radiusd.conf || exit 0

if [ ! -d $rundir ] ; then
    mkdir $rundir
    chown ${RADIUS_USER}:${RADIUS_USER} $rundir
    chmod 775 $rundir
fi

if [ ! -d $logdir ] ; then
    mkdir $logdir
    chown ${RADIUS_USER}:${RADIUS_USER} $logdir
    chmod 770 $logdir
    chmod g+s $logdir
fi

if [ ! -f $logdir/radius.log ]; then
        touch $logdir/radius.log
fi

chown ${RADIUS_USER}:${RADIUS_USER} $logdir/radius.log
chown -R ${RADIUS_USER}:${RADIUS_USER} /usr/local/freeradius/etc/raddb
chown -R ${RADIUS_USER}:${RADIUS_USER} ${rundir}
chmod 660 $logdir/radius.log

case "$1" in
  start)
	echo -n "Starting $DESC:"
	$RADIUSD $ARGS
	echo "radiusd"
	;;
  stop)
	[ -z "$2" ] && echo -n "Stopping $DESC: "
        [ -f $rundir/radiusd.pid ] && kill -TERM `cat $rundir/radiusd.pid`
	[ -z "$2" ] && echo "radiusd."
	;;
  reload|force-reload)
	echo "Reloading $DESC configuration files."
	[ -f $rundir/radiusd.pid ] && kill -HUP `cat $rundir/radiusd.pid`
	;;
  restart)
	sh $0 stop quiet
	sleep 3
	sh $0 start
	;;
  check)
	$RADIUSD -CX $ARGS
	exit $?
	;;
  *)
        echo "Usage: /etc/init.d/$RADIUS {start|stop|reload|restart|check}"
        exit 1
        stop
        ;;
  status)
        status \$prog
        ;;
  restart|force-reload)
        stop
        start
        ;;
  try-restart|condrestart)
        if status \$prog > /dev/null; then
            stop
            start
        fi
        ;;
  reload)
        exit 3
        ;;
  *)
        echo \$"Usage: \$0 {start|stop|status|restart|try-restart|force-reload}"
        exit 2
esac

EOF

	chmod +x /etc/init.d/radiusd
	update-rc.d radiusd defaults
	cd ${CURRENT_DIR}
}


#*******************************************
# Flow-tools + Ipcad
#*******************************************
_install_ipn() {

	_install flow-tools
	
	mkdir -p /usr/abills/var/log/ipn/
	
	echo "-S 5 -n 287 -N 0  -d 5 -w /usr/abills/var/log/ipn/  0/0/9996" > /etc/flow-tools/flow-capture.conf

	
	pdate-rc.d flow-capture defaults
	update-rc.d flow-capture enable
	echo '##################################################################################################'
	echo 'FLOWTOOLS INSTALLED ##################################################################################################'
	echo '##################################################################################################'


	_install libpcap-dev;

  
	echo '********************************************************************';
	echo '***        THIS SCRIPT APPLIES SOME FIXES TO BUILD IPCAD         ***';
	echo '********************************************************************';
  
	# will be installed in /usr/
	cd /usr/
  
	#remove if already extracted
	if [ -d /usr/ipcad-3.7.3 ]; then
		rm -rf ipcad-3.7.3
	fi;
  
	# do not download if present
	if [ -f "ipcad-3.7.3.tar.gz" ]; then
		echo "INFO: Already downloaded";
	else
		wget http://lionet.info/soft/ipcad-3.7.3.tar.gz
	fi;
  
	tar -xvzf ipcad-3.7.3.tar.gz
	cd ipcad-3.7.3
  
	LINE1_NUM=`grep -n 'HAVE_LINUX_NETLINK_H' headers.h | cut -d : -f 1`
	LINE2_NUM=$(( LINE1_NUM + 2 ));
  
	sed -i "${LINE2_NUM}d" headers.h;
	sed -i "${LINE1_NUM}d" headers.h;
  
	echo
  
	if [ `cat headers.h | grep 'HAVE_LINUX_NETLINK_H'` ]; then
		echo "INFO:  Error "
	else
		echo "INFO:  HAVE_LINUX_NETLINK_H Deleted";
	fi;
  
  
	sed -i "1i #include \"signal.h\"" main.c;
  
	echo
  
	sed -i "1i #include \"headers.h\"" pps.c;
	sed -i "1i #include \"signal.h\"" pps.c;
  
	echo "INFO: Added to pps.c"
    
	sed -i "1i #include \"signal.h\"" servers.h;
  
	echo "INFO: Added to servers.h"
  
	./configure && make && make install
  
	if [ -d  /var/ipcad/ ]; then
		echo "directory /var/ipcad/ exists";
	else
		mkdir /var/ipcad/;
	fi;
  

	cat << 'EOF' > /usr/local/etc/ipcad.conf
# Èíòåðôåéñû äëÿ ñáîðà ñòàòèñòèêè
interface eth0;
# äåòàëèçàöèÿ ïî ïîðòàì 
#capture-ports enable;

# Àãðåãèðîâàòü ïîðòû, óìåíüøàåò ðàçìåð áàçû äåòàëèçàöèè 
#aggregate 1024-65535    into 65535;     /* Aggregate wildly */
#aggregate 3128-3128     into 3128;      /* Protect these ports */
#aggregate 150-1023      into 1023;      /* General low range */

# Åêñïîðòèðîâàíèå ñòàòèñòèêè íà àäðåñ 127.0.0.1 ïîðò 9996
netflow export destination 127.0.0.1 9996;
netflow export version 5;       # NetFlow export format version {1|5}
netflow timeout active 30;      # Timeout when flow is active, in minutes
netflow timeout inactive 15;    # Flow inactivity timeout, in seconds
netflow engine-type 73;         # v5 engine_type; 73='I' for "IPCAD"
netflow engine-id 1;            # Useful to differentiate multiple ipcads.

dumpfile = ipcad.dump;
chroot = /var/ipcad/;
pidfile = ipcad.pid;  

rsh enable at 127.0.0.1;
memory_limit = 16m;

EOF
	cd ${CURRENT_DIR}
	echo '##################################################################################################'
	echo 'IPCAD INSTALLED ##################################################################################################'
	echo '##################################################################################################'
}

#************************************
# MRTG install
#************************************
_install_mrtg() {
	_install mrtg snmp 

	install_rstat

  echo "PATH"
	if [ ! -d /usr/abills/webreports/ ]; then
	  mkdir /usr/abills/webreports/
	fi;

	indexmaker /etc/mrtg/mrtg.cfg > /usr/abills/webreports/index.htm

	echo "*/5 * * * * env LANG=C /usr/bin/mrtg /etc/mrtg/mrtg.cfg" >> /etc/crontab
}

##**********************************************************
## FSBackup install
##**********************************************************
#_install_fsbackup() {
#	echo "FSBACKUP START INSTALL"
#	url="http://www.opennet.ru/dev/fsbackup/src/fsbackup-1.2pl2.tar.gz"
#
#	wget ${url}
#
#	tar zxvf fsbackup-1.2pl2.tar.gz;
#	cd fsbackup-1.2pl2;
#	./install.pl;
#	mkdir /usr/local/fsbackup/archive;
#
#	echo "!/usr/local/fsbackup" >> /usr/local/fsbackup/cfg_example
#	cp /usr/local/fsbackup/create_backup.sh /usr/local/fsbackup/create_backup.sh_back
#	cat /usr/local/fsbackup/create_backup.sh_back | sed 's/config_files=\".*\"/config_files=\"cfg_example\"/' > /usr/local/fsbackup/create_backup.sh
#
#	check_fsbackup_cron=`grep create_backup /etc/crontab`
#	if [ x"${check_fsbackup_cron}" = x ]; then
#		echo "18 4 * * * root /usr/local/fsbackup/create_backup.sh| mail -s \"`uname -n` backup report\" root" >> /etc/crontab
#	fi;
#	
#	cd ${CURRENT_DIR}
#}

#**********************************************************
# ACCEL-PPPoE install
#**********************************************************
_install_accel_pppoe() {

  _install bzip2 cmake libssl-dev libpcre3-dev

  echo
  echo "#############################################"
  echo "##  Installing  ACCEL-PPP ${ACCEL_PPPP_VERSION} "
  echo "#############################################"
  echo
  cd /usr/
  
  wget http://sourceforge.net/projects/accel-ppp/files/accel-ppp-1.7.4.tar.bz2
  tar -xjf accel-ppp-1.7.4.tar.bz2
  cd accel-ppp-1.7.4
  mkdir build
  cd build
  cmake -DBUILD_DRIVER=FALSE -DRADIUS=TRUE -DKDIR=/usr/src/linux-headers-`uname -r` -DCMAKE_INSTALL_PREFIX=/usr/local ..
  make
  make install
  
cat << 'EOF1' > /etc/accel-ppp.conf
[modules]
#path=/usr/local/lib/accel-ppp
log_file
#log_tcp
#log_pgsql
pptp
pppoe
#l2tp
auth_mschap_v2
#auth_mschap_v1
#auth_chap_md5
#auth_pap
radius
#ippool
sigchld
pppd_compat
shaper_tbf
#chap-secrets

[core]
log-error=/var/log/accel-ppp/core.log
thread-count=4

[ppp]
verbose=1
min-mtu=1000
mtu=1400
mru=1400
#ccp=0
#sid-case=upper
#check-ip=0
#single-session=replace
#mppe=require

[lcp]
echo-interval=30
echo-failure=3

[pptp]
echo-interval=30
verbose=1

[pppoe]
# íòåðôåéñû íà êîòîðûõ çàïóùåí pppoe ñåðâåð ( äîëæíû áûòü ñîîòâåòñòâåííî ïîäíßòû èíòåðôåéñû)
interface=eth1
interface=vlan2
interface=vlan3
interface=vlan4
#ac-name=xxx
#service-name=yyy
#pado-delay=0
#pado-delay=0,100:100,200:200,-1:500
#ifname-in-sid=called-sid
#tr101=1
verbose=1

#[l2tp]
#dictionary=/usr/local/share/accel-ppp/l2tp/dictionary
#hello-interval=60
#timeout=60
#rtimeout=5
#retransmit=5
#host-name=accel-ppp
#verbose=1

[dns]
dns1=10.0.0.10
#dns2=172.16.1.1

[radius]
dictionary=/usr/local/share/accel-ppp/radius/dictionary
nas-identifier=accel-ppp
nas-ip-address=127.0.0.1
gw-ip-address=10.0.0.10
auth-server=127.0.0.1:1812,secretpass
acct-server=127.0.0.1:1813,secretpass
dae-server=127.0.0.1:3799,secretpass
verbose=1
#timeout=3
#max-try=3
#acct-timeout=120
#acct-delay-time=0

[client-ip-range]
disable
#10.0.0.0/8 # êàçàòü äèàïàçîíû ðàçäàâàåìûå êëèåíòàì â (ïî DHCP èëè âðó÷íóþ). 
         # : îíè íå äîëæíû ïåðåñåêàòñß ñ ïóëàìè PPPOE èëè PPTP ñåðâåðà äîñòóïà.

#[ip-pool]
#gw-ip-address=192.168.0.1
#192.168.0.2-255
#192.168.1.1-255
#192.168.2.1-255
#192.168.3.1-255
#192.168.4.0/24

[log]
log-file=/var/log/accel-ppp/accel-ppp.log
log-emerg=/var/log/accel-ppp/emerg.log
log-fail-file=/var/log/accel-ppp/auth-fail.log
#log-debug=/dev/stdout
#log-tcp=127.0.0.1:3000
copy=1
#color=1
#per-user-dir=per_user
#per-session-dir=per_session
#per-session=1
level=3
#log-tcp=127.0.0.1:3000

#[log-pgsql]
#conninfo=user=log
#log-table=log

[pppd-compat]
#ip-pre-up=/etc/ppp/ip-pre-up
#ip-up=/etc/ppp/ip-up
#ip-down=/etc/ppp/ip-down
#ip-change=/etc/ppp/ip-change
radattr-prefix=/var/run/radattr
verbose=1

#[chap-secrets]
#gw-ip-address=192.168.100.1
#chap-secrets=/etc/ppp/chap-secrets

[tbf]
#attr=Filter-Id
#down-burst-factor=0.1
#up-burst-factor=1.0
#latency=50
attr-down=PPPD-Downstream-Speed-Limit
attr-up=PPPD-Upstream-Speed-Limit


[cli]
telnet=127.0.0.1:2000
#tcp=127.0.0.1:2001  
EOF1

cat << 'EOF2' >> /usr/local/share/accel-ppp/radius/dictionary
# Limit session traffic
ATTRIBUTE Session-Octets-Limit 227 integer
# What to assume as limit - 0 in+out, 1 in, 2 out, 3 max(in,out)
ATTRIBUTE Octets-Direction 228 integer
# Connection Speed Limit
ATTRIBUTE PPPD-Upstream-Speed-Limit 230 integer
ATTRIBUTE PPPD-Downstream-Speed-Limit 231 integer
ATTRIBUTE PPPD-Upstream-Speed-Limit-1 232 integer
ATTRIBUTE PPPD-Downstream-Speed-Limit-1 233 integer
ATTRIBUTE PPPD-Upstream-Speed-Limit-2 234 integer
ATTRIBUTE PPPD-Downstream-Speed-Limit-2 235 integer
ATTRIBUTE PPPD-Upstream-Speed-Limit-3 236 integer
ATTRIBUTE PPPD-Downstream-Speed-Limit-3 237 integer
ATTRIBUTE Acct-Interim-Interval 85 integer 
ATTRIBUTE Acct-Input-Gigawords    52      integer
ATTRIBUTE Acct-Output-Gigawords   53      integer 
EOF2
  
modprobe -r ip_gre

echo 'blacklist ip_gre' >> /etc/modprobe.d/blacklist.conf

echo 'pptp' >> /etc/modules
echo 'pppoe' >> /etc/modules

cat << 'EOF3' >> /usr/local/freeradius/etc/raddb/dictionary
# Limit session traffic
ATTRIBUTE Session-Octets-Limit 227 integer
# What to assume as limit - 0 in+out, 1 in, 2 out, 3 max(in,out)
ATTRIBUTE Octets-Direction 228 integer
# Connection Speed Limit
ATTRIBUTE PPPD-Upstream-Speed-Limit 230 integer
ATTRIBUTE PPPD-Downstream-Speed-Limit 231 integer
ATTRIBUTE PPPD-Upstream-Speed-Limit-1 232 integer
ATTRIBUTE PPPD-Downstream-Speed-Limit-1 233 integer
ATTRIBUTE PPPD-Upstream-Speed-Limit-2 234 integer
ATTRIBUTE PPPD-Downstream-Speed-Limit-2 235 integer
ATTRIBUTE PPPD-Upstream-Speed-Limit-3 236 integer
ATTRIBUTE PPPD-Downstream-Speed-Limit-3 237 integer
ATTRIBUTE Acct-Interim-Interval 85 integer 
ATTRIBUTE Acct-Input-Gigawords    52      integer
EOF3


	touch /etc/init.d/accel-ppp
	chmod +x /etc/init.d/accel-ppp
	
	cat << 'EOF4' >> /etc/init.d/accel-ppp
	#!/bin/sh
# /etc/init.d/accel-pppd: set up the accel-ppp server
### BEGIN INIT INFO
# Provides:          accel-ppp
# Required-Start:    $networking
# Required-Stop:     $networking
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
### END INIT INFO

set -e

PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/sbin;
ACCEL_PPTPD=`which accel-pppd`
. /lib/lsb/init-functions

if test -f /etc/default/accel-ppp; then
    . /etc/default/accel-ppp
fi

if [ -z $ACCEL_PPPTD_OPTS ]; then
  ACCEL_PPTPD_OPTS="-c /etc/accel-ppp.conf"
fi

case "$1" in
  start)
        log_daemon_msg "Starting accel-ppp server" "accel-pppd"
        if start-stop-daemon --start --quiet --oknodo --exec $ACCEL_PPTPD -- -d -p /var/run/accel-pppd.pid $ACCEL_PPTPD_OPTS; then
            log_end_msg 0
        else
            log_end_msg 1
        fi
  ;;
  restart)
        log_daemon_msg "Restarting accel-ppp server" "accel-pppd"
        start-stop-daemon --stop --quiet --oknodo --retry 180 --pidfile /var/run/accel-pppd.pid
        if start-stop-daemon --start --quiet --oknodo --exec $ACCEL_PPTPD -- -d -p /var/run/accel-pppd.pid $ACCEL_PPTPD_OPTS; then
            log_end_msg 0
        else
            log_end_msg 1
        fi
  ;;

  stop)
        log_daemon_msg "Stopping accel-ppp server" "accel-pppd"
        start-stop-daemon --stop --quiet --oknodo --retry 180 --pidfile /var/run/accel-pppd.pid
        log_end_msg 0
  ;;

  status)
    do_status
  ;;
  *)
    log_success_msg "Usage: /etc/init.d/accel-ppp {start|stop|status|restart}"
    exit 1
    ;;
esac

exit 0 
EOF4
	update-rc.d accel-ppp defaults
	update-rc.d accel-ppp enable
#accel-pppd  -p 'var/run/accel.pid' -c '/etc/accel-ppp.conf'

	cd ${CURRENT_DIR}

}


#******************************************************************
# Install main server
#******************************************************************
install_mail () {

  echo "Not supported yet"

}

#******************************************************************
#POST INSTALL
#******************************************************************
post_install () {
		cd /usr/abills/misc && ./perldeps.pl  apt-get -batch
		echo "Plugin finished";
	  read -p "press Enter to continue...";
}
