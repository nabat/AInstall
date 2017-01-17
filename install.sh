#!/bin/sh
# ABillS Auto Programs Building
#
# Created By ABillS Team 2010-2016
#
#**************************************************************

VERSION=5.11
#ABILLS_VERSION="0.58"
ABILLS_VERSION="0.75"
VERSION_PREFIX=""

# LIB FUNCTION
BASEDIR=$(dirname $0)
${BASEDIR} ./alib.sh

TMPOPTIONSFILE="/tmp/abills.tmp"
CMD_LOG="/tmp/ports_builder_cmd.log"
BILLING_DIR='/usr/abills';
BASE_PWD=`pwd`;
COMMERCIAL_MODULES="Cards Paysys Ashield Maps Storage Iptv"
HOSTNAME=`hostname`
DEFAULT_HOSTNAME="aserver"
DIALOG=dialog
FETCH_FREE_DISTR=1;
PLUGINS_DIR="plugins"


#Get running user
ID=`id | sed 's/uid\=\([0-9]*\).*/\1/';`;
if [ "${ID}" != 0 ]; then
  echo "Program need root privileges!"
  exit;
fi;

WEB_SERVER_USER=www
INSTALL_IPCAD=1

GetVersionFromFile() {
  VERSION=`cat $1 | tr "\n" ' ' | sed s/.*VERSION.*=\ // `
}


#************************************************
# run before install
#************************************************
pre_install () {
 echo "default pre_install"
}


#************************************************
# run after install
#************************************************
post_install () {
 echo "deafult post_install"
}


#************************************************
#
#************************************************
show_dialog () {

 plugin=$1

 PLUGIN_OS=`cat ${PLUGINS_DIR}/${plugin_name} | grep '#OS'`;
 COMMENTS=`cat ${PLUGINS_DIR}/${plugin_name} | grep '#COMMENTS'`;
 DIALOG_TITLE="Options for ABillS ${PLUGIN_OS} ${COMMENTS}"

 OLD_IFS=${IFS};
 IFS=$'\n'

 #for line in `cat "${PLUGINS_DIR}/${plugin_name}" | grep '^#M'`; do
 while read line; do 

   if [ "${DEBUG}" != "" ]; then
     echo " >> ${line}"
   fi;

   NAME=`echo "${line}" | grep '^#M ' | awk -F: '{print $1 }'`
   if [ "$NAME" = "" ]; then
     continue;
   fi;

   NAME=`echo "${NAME}" | awk '{print $2 }'`
   DESCRIBE=`echo "${line}" | awk -F: '{print $2 }'`
   COMMAND=`echo "${line}" | awk -F: '{print $3 }'`
   vars=${vars}"${NAME} \"${DESCRIBE}\" on ";
 done < "${PLUGINS_DIR}/${plugin_name}";

 IFS=${OLD_IFS};

 ${DIALOG} --checklist "${DIALOG_TITLE}" 50 75 15 \
    ${vars}  \
    2>${TMPOPTIONSFILE}
}


#************************************************
# Run select program
#************************************************
get_program_info () {
  program_name=$1

  PROGRAM_LINE=`cat ${PLUGINS_DIR}/${plugin_name} | grep "\#M ${program_name}"`;
 
  NAME=`echo ${PROGRAM_LINE} | awk -F: '{print $1 }'`
  NAME=`echo ${NAME} | awk '{print $2 }'`
  DESCRIBE=`echo ${PROGRAM_LINE} | awk -F: '{print $2 }'`
  COMMAND=`echo ${PROGRAM_LINE} | awk -F: '{print $3 }'`

  if [ "${DEBUG}" != "" ]; then
    echo ">> ${PROGRAM_LINE}"
  fi;
}

#************************************************
# Apply fixes that will appear in new release
#************************************************
dirty_fixes (){
  # Fix sql.conf
  SQL_CONF_FILE="/usr/abills/misc/freeradius/v2/sql.conf";
  TEMP_FILE="/tmp/sql.conf";
  OLD_STRING="SELECT ip";
  NEW_STRING="SET sql_mode=''; SELECT ip";
  
  sed -e "s/${OLD_STRING}/${NEW_STRING}/" ${SQL_CONF_FILE} > ${TEMP_FILE};
  cat ${TEMP_FILE} > ${SQL_CONF_FILE};
  
  rm ${TEMP_FILE};
  
}
#************************************************
# Run select program
#************************************************
run_cmd () {

RESULT=`cat ${TMPOPTIONSFILE}`;

if [ "${RESULT}" = "" ]; then
  return;
fi;

# Read plugin definitions
. "${PLUGINS_DIR}/${plugin_name}"

#Make correct time
clear
echo "Synchronyzing time. Please wait few seconds";
mk_time;

pre_install;

for name in ${RESULT}; do
  name=`echo "${name}" | sed s/\"//g;`;

  echo "Install: ${name}";
  #run install
  get_program_info ${name}
  if [ "${DEBUG}" != "" ]; then
    echo "Name: ${NAME} Describe: ${DESCRIBE} Command: ${COMMAND}"
  fi;

  #result=`${COMMAND}`;

  ${COMMAND}
  cd ${CURRENT_DIR}
  
  if [ -d "/usr/abills/misc/${NAME}" ]; then
    AUTOCONF_PROGRAMS="${AUTOCONF_PROGRAMS} ${NAME} "
    #AUTOCONF_PROGRAMS_FLAGS="${AUTOCONF_PROGRAMS_FLAGS}"
  fi;

  echo "Result: ${result}"
done;
 
  #Make post install
  post_install;
  
  dirty_fixes;
 
  echo "Install finished"
}

#************************************************
#
#************************************************
run_plugin () {
  # Let user choose required software
  show_dialog "$1" ;
  
  # Run plugin defined subroutines to install chosen software
  run_cmd ;
}

#**********************************************************
# Check active services
#
# Anykey: PROCESS_LIST defined in global scope to redefine it in plugin
PROCESS_LIST="mysqld radiusd httpd flow-capture mpd named"
#**********************************************************
check_ps () {
RESULT="-------------------------------------------"
for ps_name in ${PROCESS_LIST}; do
  status="Not running";
  ps_status=`ps ax | grep ${ps_name} | grep -v "grep"`;

  if [ x"${ps_status}" != x ]; then
    status="Running";
  fi;

  RESULT="${RESULT}\n${ps_name} ${status}";
done;
}

#**********************************************************
# add resolv.conf
#**********************************************************
mk_resolve () {

CHECK_NAMESERVERS=`cat /etc/resolv.conf | grep server`;

if [ ! -f /etc/resolv.conf ]; then
  echo "nameserver 8.8.8.8" > /etc/resolv.conf 
  echo "Add 8.8.8.8 to  /etc/resolv.conf"
#Check resolv content
elif [ x"${CHECK_NAMESERVERS}" = x ]; then
  echo "nameserver 8.8.8.8" > /etc/resolv.conf 
fi;

#Add hosts
if [ "${OS}" = "FreeBSD" ]; then
  if [ x"${HOSTNAME}" = x ]; then 
    echo "${DEFAULT_HOSTNAME}." >> /etc/rc.conf
    HOSTNAME=${DEFAULT_HOSTNAME}
    hostname ${DEFAULT_HOSTNAME}
  fi;

  CHECK_HOSTS=`grep "${HOSTNAME}" /etc/hosts`

  IP=`ifconfig \`route -n get default | grep interface | tail -1 | awk '{ print $2 }'\` | grep "inet " | awk '{ print $2 }' | head -1`

  if [ x"${CHECK_HOSTS}" = x ]; then
    echo "${IP}  ${HOSTNAME}" >> /etc/hosts
  fi;

  BILLING_WEB_IP=${IP}
elif [ "${OS}" = "Linux" ] ; then
  IP=`ip route get 8.8.8.8 | grep dev | awk '{ print  $7 }'`;
  BILLING_WEB_IP=${IP}
fi;

}


#**********************************************************
# Set correct date time
#**********************************************************
mk_time () {

  CHECK_NTPDATE=`which ntpdate`;
  if [ "${CHECK_NTPDATE}" = "" ]; then
    _install ntpdate
  fi;

  ntpdate europe.pool.ntp.org
  echo "Time sync: " . `date`
}


#**********************************************************
# uninstall
#**********************************************************
_uninstall () {
  read -p  "Uninstall system? (y/n): " UNINSTALL;

  if [ x"${UNINSTALL}" != xy ]; then
    echo "Canceled";
    exit;
  fi;

  echo "Clear db"

  mysql -D mysql -u root -e "DELETE FROM user WHERE user='abills'; DELETE * FROM db WHERE user='abills'; DROP DATABASE abills;";

  echo "Remove abills dir"
  mv /usr/abills /usr/abills_;
}


#**********************************************************
#
#**********************************************************
_get_version () {

for program_name in $@; do
  if [ "${OS}" = "FreeBSD" ]; then
    test_program="pkg info"
  fi;

  RET=`${test_program} ${program_name}*`;

  if [ $? = 0 ]; then
    program_name=`echo "${program_name}" | sed s/\-/_/`;

    echo ${program_name};

    installed="${program_name}_install"
    eval "${installed}"="\(${RET}\)"
  fi;
done;

}

#*********************************************************
#  Install EPEL repository CentOS (RedHat)
#*********************************************************
install_epel () {
   _fetch epel-release-7-5.noarch.rpm http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm
   rpm -ivh epel-release-7-5.noarch.rpm

  ## RHEL/CentOS 6 32-Bit ##
  # wget http://download.fedoraproject.org/pub/epel/6/i386/epel-release-6-8.noarch.rpm
  # rpm -ivh epel-release-6-8.noarch.rpm

  ## RHEL/CentOS 6 64-Bit ##
  # wget http://download.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
  # rpm -ivh epel-release-6-8.noarch.rpm
}

#*****************************************
#
#make program definition
#*****************************************
mk_file_definition () {
echo "
WEB_SERVER_USER=${WEB_SERVER_USER}
MYSQLDUMP=${MYSQLDUMP}
GZIP=${GZIP}
APACHE_CONF_DIR=${APACHE_CONF_DIR}
RESTART_MYSQL=${RESTART_MYSQL}
RESTART_RADIUS=${RESTART_RADIUS}
RESTART_APACHE=${RESTART_APACHE}
RESTART_DHCP=${RESTART_DHCP}
PING=${PING}
" > /usr/abills/Abills/programs
}


#*****************************************
#
#*****************************************
nat_config () {

echo "Nat config"
${DIALOG} --msgbox "Benchmark\n" 20  52

}

#*****************************************
# ipn configure
#*****************************************
ipn_configure () {
  echo "Ipn Configure"

}

#*****************************************
#
#*****************************************
help () {
echo "
 ABillS Ports Builder (ver. ${VERSION})
  -d     Debug mode
  -V     Verbose mode
  -b     make benchmark
  -r     Rebuild packages
  -s     Make Source update
  -v     Show Version
  -y     Auto confirm action
  -u     Uninstall (abills mysql)
  -p     use plugin [plugin name]
  -h     This help
"
  exit;
}


#**********************************************************
# rstat statistic utilits
#**********************************************************
install_rstat() {

 cd ${BASEDIR}/src/

 git clone git@github.com:nabat/rstat.git

 cd rstat ;
 make install;

 cd ${CURRENT_DIR}
}

#**********************************************************
# FSBackup install
#**********************************************************
install_fsbackup() {

cd ${BASEDIR}/src/

url="http://www.opennet.ru/dev/fsbackup/src/fsbackup-1.2pl2.tar.gz"

_fetch fsbackup-1.2pl2.tar.gz http://www.opennet.ru/dev/fsbackup/src/fsbackup-1.2pl2.tar.gz

tar zxvf fsbackup-1.2pl2.tar.gz;
cd fsbackup-1.2pl2;
./install.pl;
mkdir /usr/local/fsbackup/archive;

echo "!/usr/local/fsbackup" >> /usr/local/fsbackup/cfg_example
cp /usr/local/fsbackup/create_backup.sh /usr/local/fsbackup/create_backup.sh_back
cat /usr/local/fsbackup/create_backup.sh_back | sed 's/config_files=\".*\"/config_files=\"cfg_example\"/' > /usr/local/fsbackup/create_backup.sh

check_fsbackup_cron=`grep create_backup /etc/crontab`
if [ x"${check_fsbackup_cron}" = x ]; then
  echo "18 4 * * * root /usr/local/fsbackup/create_backup.sh| mail -s \"`uname -n` backup report\" root" >> /etc/crontab
fi;

  cd ${CURRENT_DIR}
}

#**********************************************************
# Add System user
#**********************************************************
add_user() {
  USER_NAME=$1;
  ABILLS_SYSTEM_GROUP=abills
  GID=6000
  USER_ID=6000
  USER_SHELL=/bin/sh

echo "Adding system user '${USER_NAME}' for remote ipn control"

if [ x${OS} = xLinux ]; then
  if /usr/bin/id "${ABILLS_SYSTEM_GROUP}" 2>/dev/null; then
    echo "Group Exist";
    GID=`id abills | sed 's/.* gid=\([0-9]*\).*/\1/g'`
  else
    /usr/sbin/groupadd -g ${GID} ${ABILLS_SYSTEM_GROUP}
  fi;

  /usr/sbin/useradd -c "ABillS Remote user" -d /home/${USER_NAME} --shell ${USER_SHELL} -u ${USER_ID} -g ${GID} ${USER_NAME}
  mkdir /home/${USER_NAME}
  chown ${USER_NAME} /home/${USER_NAME}
else 
  if /usr/sbin/pw groupshow "${ABILLS_SYSTEM_GROUP}" 2>/dev/null; then
    echo "You already have a group \"${ABILLS_SYSTEM_GROUP}\", so I will use it."
  else
    if /usr/sbin/pw groupadd ${ABILLS_SYSTEM_GROUP} -g ${GID}; then
      echo "Added group \"${ABILLS_SYSTEM_GROUP}\"."
    else
      echo "Error: Adding group \"${ABILLS_SYSTEM_GROUP}\" failed..."
      echo "Please create it, and try again."
      read
    fi
  fi

  if /usr/sbin/pw user show "${USER_NAME}" 2>/dev/null; then
    echo "You already have a user \"${USER_NAME}\", so I will use it."
  else
    _add_cmd="/usr/sbin/pw useradd ${USER_NAME} -u ${USER_ID} -g ${ABILLS_SYSTEM_GROUP} -d /home/${USER_NAME} -s ${USER_SHELL} -w random -c \"ABillS Remote user\""
    PASSWORD=`eval ${_add_cmd}`

    if [ $? -eq 0 ]; then
      mkdir /home/${USER_NAME}
      chown -Rf ${USER_NAME} /home/${USER_NAME}
      echo "Added user \"${USER_NAME}\"."
      echo "Password: ${PASSWORD} "
      echo "Upload des certs to host: "
      echo "/usr/abills/misc/certs_create.sh ssh ${USER_NAME}"
    else
      echo "Error: Adding user \"${USER_NAME}\" failed..."
      echo "Please create it, and try again."
      read
    fi
  fi

fi;

}

#**********************************************************
#
#**********************************************************
mk_sysbench() {

is_sysbench=`which sysbench`;

if [ x"${is_sysbench}" = x ]; then
  if [ "${OS}" = Linux ]; then
    if [ "${OS_NAME}" = "CentOS" ]; then 
    rpm -ivh http://fedora.ip-connect.vn.ua/fedora-epel/7/$(arch)/e/epel-release-7-5.noarch.rpm  ;
    rpm -ivm sysbench-0.4.12-5.el6.x86_64.rpm;
    yum -y install fetch;
    fi;

    _install sysbench
  else 
    cd /usr/ports/benchmarks/sysbench && make && make install clean
  fi;
fi;

test_file_size=5G
echo "Making benchmark. Please wait..."

#CPU test
#sysbench --test=cpu --cpu-max-prime=5000 --num-threads=1 run | egrep 'total time:' | sed 's/[ ^t]* total time: [ ^t]*//' > cpu.sysbench
#sysbench --test=cpu --cpu-max-prime=5000 --num-threads=4 run | egrep 'total time:' | sed 's/[ ^t]* total time: [ ^t]*//' >> cpu.sysbench
#RAM test
#sysbench --test=memory --memory-total-size=1G --memory-access-mode=rnd --memory-oper=write run | egrep 'total time:' | sed 's/[ ^t]* total time: [ ^t]*//' > memory.sysbench
#sysbench --test=memory --memory-total-size=1G --memory-access-mode=rnd --memory-oper=read run | egrep 'total time:' | sed 's/[ ^t]* total time: [ ^t]*//' >> memory.sysbench
#HDD test
#sysbench --test=fileio --file-total-size=${test_file_size} prepare
#sysbench --test=fileio --file-total-size=${test_file_size} --file-test-mode=seqwr --max-time=0 run | egrep 'total time:' | sed 's/[ ^t]* total time: [ ^t]*//' > fileio.sysbench 
#sysbench --test=fileio --file-total-size=${test_file_size} --file-test-mode=seqrd --max-time=0 run | egrep 'total time:' | sed 's/[ ^t]* total time: [ ^t]*//' >> fileio.sysbench
#sysbench --test=fileio --file-total-size=${test_file_size} cleanup

#sysbench --test=threads

CPU1=`cat cpu.sysbench | head -1`
CPU2=`cat cpu.sysbench | tail -1`
echo "CPU one thread  : ${CPU1}"
echo "CPU multi thread: ${CPU2}"

MEM1=`cat memory.sysbench | head -1`
MEM2=`cat memory.sysbench | tail -1`
echo "Memory write: ${MEM1}"
echo "Memory read : ${MEM2}"

FILE1=`cat fileio.sysbench | head -1`
FILE2=`cat fileio.sysbench | tail -1`
echo "Filesystem write: ${FILE1}"
echo "Filesystem read : ${FILE2}"

if [ x"${OS}" = xLinux ]; then
  wget --no-check-certificate "https://support.abills.net.ua/sysbench.cgi?CPU_ONE=$CPU1&CPU_MULT=$CPU2&MEM_WR=$MEM1&MEM_RD=$MEM2&FILE_WR=$FILE1&FILE_RD=$FILE2";
else 
 fetch "https://support.abills.net.ua/sysbench.cgi?CPU_ONE=$CPU1&CPU_MULT=$CPU2&MEM_WR=$MEM1&MEM_RD=$MEM2&FILE_WR=$FILE1&FILE_RD=$FILE2";
fi;
#${DIALOG} --msgbox "Benchmark\n" 20  52

}


#**********************************************************
#
#diff --git a/drivers/ipoe/ipoe.c b/drivers/ipoe/ipoe.c
#index 1aafde6..59adf09 100644
#--- a/drivers/ipoe/ipoe.c
#+++ b/drivers/ipoe/ipoe.c
#@@ -32,6 +32,9 @@
# 
# #include "ipoe.h"
# 
#+#define u64_stats_fetch_begin_bh u64_stats_fetch_begin_irq
#+#define u64_stats_fetch_retry_bh u64_stats_fetch_retry_irq
#+
# #define BEGIN_UPDATE 1
# #define UPDATE 2
#**********************************************************
install_accel_ipoe() {

  echo "Accel IPoE start install";

  _install make cmake libcrypto++-dev libssl-dev libpcre3 libpcre3-dev git

  DKDIR="/usr/src/linux-headers-"`uname -r`

  if [ "${OS_NAME}" = "CentOS" ] ; then
  echo " !!!!!!!!!!!!!!!!!!!!!!! accel-IPoE not working in CentOS 7 !!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  sleep 3;
    _install kernel-headers kernel-devel
    DKDIR="/usr/src/kernels/"`ls /usr/src/kernels/`
  else 
    _install linux-headers-`uname -r` 
  fi;

 cmd="cd /usr/src/ ; pwd ";
 cmd="${cmd}; git clone git://git.code.sf.net/p/accel-ppp/code accel-ppp.git"
 cmd="${cmd}; mkdir accel-ppp-build"
 cmd="${cmd}; cd accel-ppp-build"
 cmd="${cmd}; cmake -DCMAKE_INSTALL_PREFIX=/usr/local -DKDIR=${DKDIR} -DRADIUS=TRUE -DSHAPER=TRUE -DLOG_PGSQL=FALSE -DBUILD_IPOE_DRIVER=TRUE ../accel-ppp.git"
 cmd="${cmd}; make"
 cmd="${cmd}; make install"

 if [ "${DEBUG}" != "" ]; then
   echo "${cmd}";
 fi;

 eval ${cmd}

 insmod /usr/src/accel-ppp-build/drivers/ipoe/driver/ipoe.ko

 ipoe_mod_check=`lsmod | grep ipoe`
 if [ "${ipoe_mod_check}" = "" ]; then
   echo "Accel IPoE NOT installed";
   exit;
 else
   echo "Accel IPoE installed";
 fi;

 cmd=""
}


#**********************************************************
#
#**********************************************************
install_accel_ppp() {

# Install radius client
if [ "${OS_NAME}" = Mandriva -o "${OS_NAME}" = ARCH ]; then 
  cmd="${BUILD_OPTIONS} freeradius-client;";
elif [ ${OS_NAME} = Fedora -o ${OS_NAME} = fedora -o ${OS_NAME} = CentOS ]; then 
  echo "install freeradius";
else
  cmd=${cmd}"${BUILD_OPTIONS} radiusclient1;";
fi;

if [ ${OS_NAME} = Mandriva -o ${OS_NAME} = Fedora ]; then
  echo "to install pptpd you need to download sources";
else 
  PKGS="bzip2 cmake libnl2-dev pptp-linux build-essential gawk"

  PPP_LIB_DIR="/usr/lib/pppd/2.4.6/";

  if [ "${OS_NAME}" = "ALTLinux" ]; then
    PKGS="${PKGS} libssl-devel libpcre-devel ppp-devel"
  elif [ "${OS_NAME}" = "CentOS" ]; then
    #wget http://apt.sw.be/redhat/el6/en/i386/rpmforge/RPMS/radiusclient-0.3.2-0.2.el6.rf.i686.rpm
    #rpm -ivh radiusclient-0.3.2-0.2.el6.rf.i686.rpm

    #rpm -Uvh http://pptpclient.sourceforge.net/yum/stable/rhel6/pptp-release-current.noarch.rpm
    PKGS="openssl-devel ppp ppp-devel pcre-devel pptp sudo bzip2 cmake"
    PPP_LIB_DIR="/usr/lib64/pppd/2.4.6";
  else
    PKGS="${PKGS}  sudo bzip2 cmake libssl-dev libpcre3-dev ppp-dev"
  fi;

  _install "${PKGS}"

  ACCEL_PPPP_VERSION='1.7.4' #1.9.0 #'1.7.3';
  echo "Installing  ACCEL-PPP ${ACCEL_PPPP_VERSION} "
  sleep 2;
  cmd="${cmd}cd /usr/src/; rm accel-ppp-${ACCEL_PPPP_VERSION}*;";
  cmd="${cmd}yum -y install bzip2 cmake;";
  cmd="${cmd}wget \"http://garr.dl.sourceforge.net/project/accel-ppp/accel-ppp-${ACCEL_PPPP_VERSION}.tar.bz2\";"
  cmd="${cmd}bzip2 -d accel-ppp-${ACCEL_PPPP_VERSION}.tar.bz2; tar xvf accel-ppp-${ACCEL_PPPP_VERSION}.tar;"
  cmd="${cmd}mkdir accel-ppp-build; cd accel-ppp-build; cmake -I/usr/include/pcre/ -DCMAKE_INSTALL_PREFIX=/usr/local -DRADIUS=TRUE ../accel-ppp-${ACCEL_PPPP_VERSION};"
  #cmd="${cmd}cd ../accel-ppp-${ACCEL_PPPP_VERSION}/pppd_plugin/;"
  #cmd="${cmd}sudo ./configure;"
  #echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!";
  #sleep 2;

  cmd="${cmd}make;"
  cmd="${cmd}make install;"
  cmd="${cmd}ln -s /usr/local/lib/pptp.so ${PPP_LIB_DIR};"
  cmd="${cmd}modprobe pptp;"
  cmd="${cmd}echo \"pptp\" >> /etc/modules;"
  cmd="${cmd}echo \"pppoe\" >> /etc/modules;"

  AUTOCONF_PROGRAMS="${AUTOCONF_PROGRAMS} accel_ppp "
  AUTOCONF_PROGRAMS_FLAGS="${AUTOCONF_PROGRAMS_FLAGS}"
fi;

#autostart
if [ "${OS}" = 'CentOS' ]; then

(cat <<EOF
#!/bin/bash

PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin"
DAEMON="accel-pppd"
DAEMON_BIN="$(which "${DAEMON}")"
DAEMON_ARGS="-d -c /etc/accel-ppp.conf"

parse_pid() {
    PID="$(ps -A | sed -n "/^[[:space:]]*\([0-9]*\)[[:space:]]*.*[[:space:]]*.*[[:space:]]*[^.]"${1}"$/s//\1/p" | head --lines=1)"

    if [ "${PID}" == "" ] || [ "${PID}" -eq "$$" ] ; then
        echo "0"
    else
        echo "${PID}"
    fi
}

start_daemon() {
    PID="$(parse_pid "${DAEMON}")"

    if [ "${PID}" == "0" ] ; then
        ${DAEMON_BIN} ${DAEMON_ARGS}
        echo "Starting "${DAEMON}" server: [ OK ]"
    else
        echo ""${DAEMON}" server already running with PID="${PID}"."
    fi
}

stop_daemon() {
    PID="$(parse_pid "${DAEMON}")"

    if [ "${PID}" == "0" ] ; then
        echo ""${DAEMON}" server not running."
    else
        kill -s TERM "${PID}"
        echo "Stopping "${DAEMON}" server: [ OK ]"
    fi
}

status_daemon() {
    PID="$(parse_pid "${DAEMON}")"

    if [ "${PID}" == "0" ] ; then
        echo ""${DAEMON}" server not running."
    else
        echo ""${DAEMON}" server already running with PID="${PID}"."
    fi
}

restart_daemon() {
    stop_daemon

    while [ "$(parse_pid "${DAEMON}")" != "0" ] ; do
        sleep 1
    done

    start_daemon
}

case "${1}" in
    start)
        start_daemon
    ;;

    stop)
        stop_daemon
    ;;
    restart)
        restart_daemon
    ;;

    status)
        status_daemon
    ;;
    *)
        echo "Usage: `basename $0` (start | stop | restart | status)"
        ;;
esac
EOF
) > /etc/init.d/accel-ppp


else
  echo ""
fi;


}

#**********************************************************
# install sudo 
#**********************************************************
install_sudo() {

read -p "Remote IPN server [y/n]: " LOCAL_IPN ;

if [ x${LOCAL_IPN} = xy ]; then
  LOCAL_IPN=1;
  IPN_CONTROL_USER=abills_admin
  add_user ${IPN_CONTROL_USER}
else
  IPN_CONTROL_USER=${WEB_SERVER_USER}
fi;


if [ x"${OS}" = xLinux ]; then
  #Check sudoers
  CHECK_SUDOERS=`grep ${IPN_CONTROL_USER} /etc/sudoers`;
  if [ x${CHECK_SUDOERS} != x ]; then
     echo "sudoers record alredy exists";
     return 0;
  fi;

  echo "
${IPN_CONTROL_USER}   ALL = NOPASSWD: /usr/abills/libexec/linkupdown
${IPN_CONTROL_USER}   ALL = NOPASSWD: /sbin/iptables
" >> /etc/sudoers

else 
  sub_cmd="cd ${PORTS_LOCATION}/security/sudo  ${BUILD_OPTIONS}"
  eval ${sub_cmd}

  #Check sudoers
  CHECK_SUDOERS=`grep ${IPN_CONTROL_USER} /usr/local/etc/sudoers`;
  if [ x"${CHECK_SUDOERS}" != x ]; then
     echo "sudoers record alredy exists";
     return 0;
  fi;

  echo "
${IPN_CONTROL_USER}   ALL = NOPASSWD: /usr/abills/libexec/linkupdown
${IPN_CONTROL_USER}   ALL = NOPASSWD: /sbin/ipfw
${IPN_CONTROL_USER}   ALL = NOPASSWD: /sbin/ifconfig

" >> /usr/local/etc/sudoers
fi;
}

#**********************************************************
# Install ipn from source 
# Linux distr
#**********************************************************
install_ipn() {

  _fetch flow-tools-0.66.tar.gz ftp://ftp.eng.oar.net/pub/flow-tools/flow-tools-0.66.tar.gz
  tar zxvf flow-tools-0.66.tar.gz
  cd flow-tools-0.66
  ./configure
  make 
  make install

  if [ -d ${BILLING_DIR} ]; then
    ls -s ${BILLING_DIR}/Abills/modules/Ipn/traffic2sql ${BILLING_DIR}/libexec/
  fi;
}

#**********************************************************
#
#**********************************************************
install_ipcad() {

_install libpcap-dev;
#  if [ "${OS}" = "Ubuntu" -o "${OS}" = "Debian" -o "${OS}" = "CentOS"]; then

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
    _fetch ipcad-3.7.3.tar.gz http://lionet.info/soft/ipcad-3.7.3.tar.gz
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

  AUTOCONF_PROGRAMS="${AUTOCONF_PROGRAMS} ipcad"

  echo "/usr/local/bin/ipcad -d" >> /etc/rc.local
}

#**********************************************************
# Build freebsd kernel
#**********************************************************
freebsd_build_kernel () {

UNAME=`uname -a`;

KERNEL_FILE=`uname -a | awk '{ a=NF-1; b=NF; print $a"  "$b }' | sed 's/.*://' |sed 's/compile/conf/' | sed 's/\/usr\/obj//' | sed 's/\/\([a-zA-Z0-9_]*\)  \([a-z0-9]*\)/\/\2\/conf\/\1/'`

echo "====================================================="
echo " ${UNAME}                                            "
echo " ${KERNEL_FILE}                                      "
echo "====================================================="


read -p "Update source (y/n)?: " UPDATE_SRC;

if [ x"${UPDATE_SRC}" = xy ]; then
  #System source update
  #Subversion update
  _install subversion

  MAJOR_VERSION=`uname -r | awk -F\. '{ print $1 }'`
  svn co svn://svn.freebsd.org/base/stable/${MAJOR_VERSION} /usr/src
fi;

if [ ! -d /usr/src/sys ]; then
  echo "Kernel Source not found";
  echo "Please download it to /usr/src/sys/"

  sleep 5;
  return 0;
fi;

read -p "Build kernel (y/n)?: " KERNEL;

if [ x"${KERNEL}" = xy ]; then

#Kernel config
KERNEL_OPTIONS="
options         IPFIREWALL
options         IPFIREWALL_DEFAULT_TO_ACCEPT
options         DUMMYNET

options         NETGRAPH
options         NETGRAPH_PPPOE
options         NETGRAPH_IPFW
#options         IPFIREWALL_FORWARD
options         IPFIREWALL_NAT          #ipfw kernel nat support
options         LIBALIAS
options         HZ=1000
"

  if [ -f ${KERNEL_FILE} ]; then
    cp ${KERNEL_FILE} ${KERNEL_FILE}_ABILLS
    echo "#Abills options \n ${KERNEL_OPTIONS}" >>  ${KERNEL_FILE}_ABILLS
    cd /usr/src

    KERNEL_FILE=`echo ${KERNEL_FILE}_ABILLS | sed 's/\(.*\)\/\([a-zA-Z0-9\_]*\)$/\2/g'`;
    echo "make buildkernel KERNCONF=${KERNEL_FILE}"

    make buildkernel KERNCONF=${KERNEL_FILE}

    read -p "Install kernel ${KERNEL_FILE}? (y/n): " INSTALL_KERNEL;
    if [ x${INSTALL_KERNEL} = xy ]; then
      make installkernel KERNCONF=${KERNEL_FILE}
    fi;
  else 
    echo "Error: Can\'t find kernel";
  fi;

fi;

}


#**********************************************************
# Install Freeradius from source
# 
#**********************************************************
install_freeradius() {

FREERADIUS_VERSION="2.2.9"

  if [ -d /usr/local/freeradius/ ]; then
    echo "Radius exists: /usr/local/freeradius/";
    return 0 ;
  fi;

 _install make gmake gcc libmysqlclient-dev libmysqlclient16 libmysqlclient18 libgdbm3 libgdbm-dev libperl-dev

 PERL_LIB_DIRS="/usr/local/lib/perl5/5.20/mach/CORE/"

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

_fetch freeradius-server-${FREERADIUS_VERSION}.tar.gz ftp://ftp.freeradius.org/pub/freeradius/freeradius-server-${FREERADIUS_VERSION}.tar.gz

if [ ! -f freeradius-server-${FREERADIUS_VERSION}.tar.gz ]; then
  echo "Can't download freeradius. Please download and install manual";
  exit;
fi;

tar zxvf freeradius-server-${FREERADIUS_VERSION}.tar.gz

cd freeradius-server-${FREERADIUS_VERSION}
./configure --prefix=/usr/local/freeradius --with-rlm-perl-lib-dir=${PERL_LIB_DIR} --without-openssl --with-dhcp > 1
echo "./configure --prefix=/usr/local/freeradius --with-rlm-perl-lib-dir=${PERL_LIB_DIR} --without-openssl --with-dhcp " > configure_abills
make && make install

ln -s /usr/local/freeradius/sbin/radiusd /usr/sbin/radiusd

#Add user
groupadd ${RADIUS_SERVER_USER}
useradd -g ${RADIUS_SERVER_USER} -s /bash/bash ${RADIUS_SERVER_USER}
chown -R ${RADIUS_SERVER_USER}:${RADIUS_SERVER_USER} /usr/local/freeradius/etc/raddb

}



#**********************************************************
# Build freebsd programs
#**********************************************************
freebsd_build () {
echo -e '\a \a \a';

FILE_PING='/sbin/ping';

PORTS_LOCATION="/usr/ports/"
DIALOG_TITLE="ABillS Installation"
DIALOG_TITLE="${DIALOG_TITLE} Server: ${OS} ${OS_VERSION} ${MACH}";
if [ x${DEBUG} != x ] ; then
  DIALOG_TITLE=${DIALOG_TITLE}" (DEBUG MODE)";
fi

pre_install

if [ x"${BENCHMARK}" != x ]; then
  mk_sysbench;
  exit;
fi;

PKG_TOOL=pkg_info
PKG_ADD=pkg

if [ -f /usr/sbin/pkg_add ]; then
  #new version PKG tools
  if [ ! -f /usr/sbin/pkg -a ! -f /usr/local/sbin/pkg ]; then

    if [ -d /usr/ports/ports-mgmt/pkg ]; then
      cd /usr/ports/ports-mgmt/pkg && make && make install
    else 
      pkg_add -r pkg
    fi;

    PKG_INFO=`pkg info | head`;

    if [ x"${PKG_INFO}" = x ]; then
      /usr/local/sbin/pkg2ng

      CHECK_PKGNG=`grep WITH_PKGNG /etc/make.conf`;
      if [ x"${CHECK_PKGNG}" = x"" ]; then
        echo 'WITH_PKGNG=yes' >> /etc/make.conf
      fi;

      PKG_TOOL="pkg info"
    fi;
  fi;
fi

${DIALOG} --checklist "${DIALOG_TITLE}" 50 75 15 billing "Billing Server"  off \
     nas    "Nas server"  off  \
     2>${TMPOPTIONSFILE}

RESULT=`cat ${TMPOPTIONSFILE}`;

if [ "${RESULT}" = "" ]; then
  exit;
fi;

echo -e '\a\a\a\a\a'

vim_install=`${PKG_TOOL}  | grep vim | awk -F- '{ print $2 }' | sed 's/ .*//'`;
if [ x != x${vim_install} ]; then
  vim_install="(installed)"
fi;

bash_install=`${PKG_TOOL}  | grep bash | awk -F- '{ print $2 }' | sed 's/ .*//'`;
if [ x != x${bash_install} ]; then
  bash_install="(installed)"
fi;

mysql_install=`${PKG_TOOL}  | grep mysql-server | awk -F- '{ print $3 }' | sed 's/ .*//' `;
if [ x != x${mysql_install} ]; then
  mysql_install="(installed ${mysql_install})"
fi;

apache_install=`${PKG_TOOL} | grep apache | awk -F- '{ print $2 }' | sed 's/ .*//' `;
if [ x != x${apache_install} ]; then
  apache_install="(installed ${apache_install})"
fi;

freeradius_install=`${PKG_TOOL} | grep freeradius | awk -F- '{ print $2 }' | sed 's/ .*//' `;
if [ x != x${freeradius_install} ]; then
  freeradius_install="(installed ${freeradius_install})"
fi;

for name in ${RESULT}; do
  name=`echo "${name}" | sed s/\"//g;`;

  if [ "${name}" = "billing" ]; then

    DIALOG_TITLE="Options for ABillS FreeBSD ports"

    ${DIALOG} --checklist "${DIALOG_TITLE}" 50 75 15 update "Source Update"  on \
     mysql56      "Mysql Server ${mysql_install}"  on \
     apache22     "Apache  ${apache_install}" on \
     Perl_Modules "Perl modules" on \
     freeradius   "FreeRADIUS ${freeradius_install}" on\
     DHCP         "ISC DHCP Server" on\
     Mail         "Mail Server" off \
     MRTG         "Mrtg"  on \
     IPN          "IPN" off\
     fsbackup     "fsbackup" off\
     Build_Kernel "Build kernel" off\
     PERL_SPEEDY  "Speed_CGI" off\
     Utils        "bash,vim,tmux,monit" on\
    2>${TMPOPTIONSFILE}
    RESULT=`cat ${TMPOPTIONSFILE}`;
  fi;

  if [ "${name}" = "nas" ]; then
    mpd_install=`${PKG_TOOL} | grep mpd | awk -F- '{ print $2 }' | sed 's/ .*//' `;
    if [ x != x${mpd_install} ]; then
      mpd_install="(installed ${mpd_install})"
    fi;

    DIALOG_TITLE="NAS Server Options"

    ${DIALOG} --checklist "${DIALOG_TITLE}" 50 75 15 update "Source Update"  on \
     Perl_Modules   "Perl modules" on \
     DHCP           "ISC DHCP Server" on\
     IPN            "IPN (IPoE)" off\
     mpd            "Mpd (VPN/PPPoE) ${mpd_install}"      off\
     fsbackup       fsbackup off\
     Build_Kernel   "Build kernel" off\
     MRTG           "Mrtg"  on \
     Utils          "bash,vim,tmux,monit" on\
    2>${TMPOPTIONSFILE}
    RESULT=${RESULT}" "`cat ${TMPOPTIONSFILE}`;

    # Add gatewayenable
    check_gate=`cat /etc/rc.conf | grep gateway_enable`;
    if [ x"${check_gate}" = x ]; then
      echo "gateway_enable=\"YES\"" >> /etc/rc.conf
    fi;
  fi;
done;

if [ w${REBUILD} != w ]; then
  BUILD_OPTIONS=" && make clean config && make && make deinstall && make install "
else
  BUILD_OPTIONS=" && make && make install ";
fi;

#Checklibtools
#
LIBTOOL__EXIST=`which libtool`;
if [ x"${LIBTOOL__EXIST}" != x ]; then
  LIBTOOL_VERSION=`libtool --version | head -1| awk '{ print $4 }' | sed 's/\.//g'`

  if [ "${LIBTOOL_VERSION}" -lt 2400 ]; then
    RESULT="libtool "${RESULT}
  fi;
fi;

for name in ${RESULT}; do
  name=`echo "${name}" | sed s/\"//g;`;
  echo "Program: ${name}";
  cmd="";

  #System and ports update
  if [ "${name}" = "update" ] ; then
    #System update
    # freebsd-update
    #ports update
    cmd="${cmd}portsnap fetch;"
    cmd="${cmd}portsnap extract;"
    cmd="${cmd}portsnap update;"

    #Build perl 5.18 on new systems
    PERL_EXIST=`${PKG_TOOL} | grep perl-|awk '{print $1}'`;
    if [ x"${PERL_EXIST}" = x ]; then
      cd /usr/ports/lang/perl5.18 && make && make install clean
    fi;
  fi;

  if [ "${name}" = "libtool" ] ; then
    if [ -d /usr/ports//ports-mgmt/portupgrade ]; then
      cmd="cd ${PORTS_LOCATION}/ports-mgmt/portupgrade ${BUILD_OPTIONS};";
      cmd="${cmd}portupgrade libtool"
    fi;
  fi;

  if [ "${name}" = "apache22" ]; then
    cmd="cd ${PORTS_LOCATION}/www/apache22 ${BUILD_OPTIONS};";
    AUTOCONF_PROGRAMS="apache"
  fi;

  if [ "${name}" = "Utils" ]; then
    cmd="cd ${PORTS_LOCATION}/shells/bash  ${BUILD_OPTIONS};";
    cmd="${cmd}cd ${PORTS_LOCATION}/editors/vim-lite ${BUILD_OPTIONS};";
    cmd="${cmd}cd ${PORTS_LOCATION}/sysutils/tmux ${BUILD_OPTIONS};"; 
  fi;

  if [ "${name}" = "mysql56" ]; then
    cmd="cd ${PORTS_LOCATION}/databases/mysql56-server ${BUILD_OPTIONS};";
  fi;

  if [ "${name}" = "freeradius" ]; then
    cmd="cd ${PORTS_LOCATION}/net/freeradius2 ${BUILD_OPTIONS};";
    AUTOCONF_PROGRAMS="${AUTOCONF_PROGRAMS} freeradius"
  fi;

  if [ "${name}" = "DHCP" ]; then
    if [ -d ${PORTS_LOCATION}/net/isc-dhcp31-server ]; then
      cmd="cd ${PORTS_LOCATION}/net/isc-dhcp31-server ${BUILD_OPTIONS};";
    else
      cmd="cd ${PORTS_LOCATION}/net/isc-dhcp33-server ${BUILD_OPTIONS};";
    fi;

    install_sudo
    AUTOCONF_PROGRAMS="${AUTOCONF_PROGRAMS} dhcp"
  fi;

  if [ "${name}" = "Perl_Modules" ]; then
    cmd="cd ${PORTS_LOCATION}/security/p5-Digest-MD4 ${BUILD_OPTIONS};";
    cmd=${cmd}"cd ${PORTS_LOCATION}/security/p5-Digest-MD5 ${BUILD_OPTIONS};";
    cmd=${cmd}"cd ${PORTS_LOCATION}/security/p5-Digest-SHA1 ${BUILD_OPTIONS};";
    cmd="${cmd} cd ${PORTS_LOCATION}/databases/p5-DBD-mysql ${BUILD_OPTIONS};";
    cmd="${cmd} cd ${PORTS_LOCATION}/textproc/p5-PDF-API2 ${BUILD_OPTIONS};";
    cmd="${cmd} cd ${PORTS_LOCATION}/devel/p5-Time-HiRes ${BUILD_OPTIONS};";
    cmd="${cmd} cd ${PORTS_LOCATION}/textproc/p5-XML-Simple/ ${BUILD_OPTIONS};";
    cmd="${cmd} cd ${PORTS_LOCATION}/databases/p5-RRD-Simple/ ${BUILD_OPTIONS};";
    cmd="${cmd} cd ${PORTS_LOCATION}/textproc/p5-Spreadsheet-WriteExcel ${BUILD_OPTIONS};";
  fi;

  if [ "${name}" = "Mail" ]; then
    cmd="cd ${PORTS_LOCATION}/security/cyrus-sasl2 ${BUILD_OPTIONS};";
    cmd=${cmd}"cd ${PORTS_LOCATION}/mail/postfix27 ${BUILD_OPTIONS};"; 
    cmd=${cmd}"cd ${PORTS_LOCATION}/mail/maildrop && make WITH_AUTHLIB=yes MAILDROP_TRUSTED_USERS=vmail MAILDROP_SUID=1005 MAILDROP_SGID=1005 && make install;";
    cmd=${cmd}"cd ${PORTS_LOCATION}/security/courier-authlib-base ${BUILD_OPTIONS};"
    cmd=${cmd}"cd ${PORTS_LOCATION}/security/courier-authlib ${BUILD_OPTIONS};"
    cmd=${cmd}"cd ${PORTS_LOCATION}/mail/courier-imap ${BUILD_OPTIONS} ;"
    cmd=${cmd}"cd ${PORTS_LOCATION}/mail/p5-Mail-SpamAssassin/ ${BUILD_OPTIONS} ;"
    cmd=${cmd}"cd ${PORTS_LOCATION}/security/clamav ${BUILD_OPTIONS};"
    cmd=${cmd}"cd ${PORTS_LOCATION}/security/amavisd-new ${BUILD_OPTIONS};"
    cmd=${cmd}"cd ${PORTS_LOCATION}/mail/squirrelmail ${BUILD_OPTIONS};"

    #Check apache php support
    APACHE_CONFIG='/usr/local/etc/apache22/httpd.conf'
    check_php_conf=`grep 'x-httpd-php' ${APACHE_CONFIG}`
    if [ w${check_php_conf} = w ]; then
      read -p "Can\'t find php in apache config add it? (y/n): " PHP_CONF;
      if [ w${PHP_CONF} = wy ]; then
        echo "AddType application/x-httpd-php .php" >> ${APACHE_CONFIG}
      fi;
    fi;
 
    PHP_INDEX=`grep index.php ${APACHE_CONFIG}`;
    if [ x"${PHP_INDEX}" = x ]; then
      cp ${APACHE_CONFIG} ${APACHE_CONFIG}_bak
      cat ${APACHE_CONFIG}_bak | sed 's/DirectoryIndex index.html/DirectoryIndex index.html index.php/' > ${APACHE_CONFIG}
    fi;

    AUTOCONF_PROGRAMS="${AUTOCONF_PROGRAMS} postfix"
    AUTOCONF_PROGRAMS_FLAGS="${AUTOCONF_PROGRAMS_FLAGS} AMAVIS=1 CLAMAV=1"
  fi;

  if [ "${name}" = "MRTG" ]; then
    cmd="cd ${PORTS_LOCATION}/net-mgmt/mrtg ${BUILD_OPTIONS};";
    install_rstat;
    AUTOCONF_PROGRAMS="${AUTOCONF_PROGRAMS} mrtg"
  fi;

  if [ "${name}" = "fsbackup" ]; then
    install_fsbackup
  fi;

  if [ "${name}" = "IPN" ]; then
    cmd="cd ${PORTS_LOCATION}/net-mgmt/flow-tools ${BUILD_OPTIONS};";
    if [ x${INSTALL_IPCAD} = x1 ]; then
      cmd=${cmd}"cd ${PORTS_LOCATION}/net-mgmt/ipcad ${BUILD_OPTIONS};";
      AUTOCONF_PROGRAMS="${AUTOCONF_PROGRAMS} ipcad"
    fi;

    install_sudo
    AUTOCONF_PROGRAMS="${AUTOCONF_PROGRAMS} flow-tools"

    if [ -d ${BILLING_DIR} ]; then
      ls -s ${BILLING_DIR}/Abills/modules/Ipn/traffic2sql ${BILLING_DIR}/libexec/
    fi;
  fi;

  if [ "${name}" = "PERL_SPEEDY" ]; then
     mkdir src
     cd src
     fetch http://daemoninc.com/SpeedyCGI/CGI-SpeedyCGI-2.22.tar.gz
     tar zxvf CGI-SpeedyCGI-2.22.tar.gz
     cd CGI-SpeedyCGI-2.22
     perl Makefile.PL
     make
     make install
  fi;

  if [ "${name}" = "mpd" ]; then
    cmd="cd ${PORTS_LOCATION}/net/mpd5 ${BUILD_OPTIONS};";
    AUTOCONF_PROGRAMS="${AUTOCONF_PROGRAMS} mpd"
    AUTOCONF_PROGRAMS_FLAGS="${AUTOCONF_PROGRAMS_FLAGS} MPD5=1"
  fi;

  if [ "${name}" = "Build_Kernel" ]; then
    freebsd_build_kernel
  fi;

  if [ w${VERBOSE} != w ]; then
    echo ${cmd}
  else
    eval ${cmd}
    if [ w${DEBUG} != w ]; then
      echo ${cmd} >> ${CMD_LOG}
    fi;
  fi;

  AUTOCONF_PROGRAMS="${AUTOCONF_PROGRAMS} freebsd"

done
}


#**********************************************************
# Build freebsd programs
#**********************************************************
freebsd_build2 () {
echo -e '\a \a \a';

FILE_PING='/sbin/ping';

DIALOG_TITLE="ABillS Installation"
DIALOG_TITLE="${DIALOG_TITLE} Server: ${OS} ${OS_VERSION} ${MACH}";
if [ x${DEBUG} != x ] ; then
  DIALOG_TITLE=${DIALOG_TITLE}" (DEBUG MODE)";
fi

RESULT=`grep 'WITHOUT="X11"' /etc/make.conf`;
if [ "${RESUL}" = "" ]; then
  #echo 'WITHOUT_X11=yes' >> /etc/make.conf
  echo 'WITHOUT="X11"' >> /etc/make.conf
  echo 'WITHOUT_GUI=yes' >> /etc/make.conf
fi;

if [ x"${BENCHMARK}" != x ]; then
  mk_sysbench;
  exit;
fi;

PKG_TOOL="pkg info"
PKG_ADD="pkg"

${DIALOG} --checklist "${DIALOG_TITLE}" 50 75 15 billing "Billing Server"  off \
     nas    "Nas server"  off  \
     2>${TMPOPTIONSFILE}

RESULT=`cat ${TMPOPTIONSFILE}`;

if [ "${RESULT}" = "" ]; then
  exit;
fi;

echo -e '\a\a\a\a\a'

_get_version apache mysql-server freeradius

for name in ${RESULT}; do
  name=`echo "${name}" | sed s/\"//g;`;

  if [ "${name}" = "billing" ]; then

    DIALOG_TITLE="Options for ABillS FreeBSD ports"

    ${DIALOG} --checklist "${DIALOG_TITLE}" 50 75 15 update "Source Update"  on \
     mysql56      "Mysql Server ${mysql_server_install}"  on \
     apache22     "Apache  ${apache_install}" on \
     Perl_Modules "Perl modules" on \
     freeradius   "FreeRADIUS ${freeradius_install}" on\
     DHCP         "ISC DHCP Server" on\
     Mail         "Mail Server" off \
     MRTG         "Mrtg"  on \
     IPN          "IPN" off\
     fsbackup     "fsbackup" off\
     Build_Kernel "Build kernel" off\
     PERL_SPEEDY  "Speed_CGI" off\
     Utils        "bash,vim,tmux,monit" on\
    2>${TMPOPTIONSFILE}
    RESULT=`cat ${TMPOPTIONSFILE}`;
  fi;

  if [ "${name}" = "nas" ]; then
    _get_version mpd

    DIALOG_TITLE="NAS Server Options"

    ${DIALOG} --checklist "${DIALOG_TITLE}" 50 75 15 update "Source Update"  on \
     Perl_Modules   "Perl modules" on \
     DHCP           "ISC DHCP Server" on\
     IPN            "IPN (IPoE)" off\
     mpd            "Mpd (VPN/PPPoE) ${mpd_install}"      off\
     fsbackup       fsbackup off\
     Build_Kernel   "Build kernel" off\
     MRTG           "Mrtg"  on \
     Utils          "bash,vim,tmux,monit" on\
    2>${TMPOPTIONSFILE}
    RESULT=${RESULT}" "`cat ${TMPOPTIONSFILE}`;

    # Add gatewayenable
    check_gate=`cat /etc/rc.conf | grep gateway_enable`;
    if [ x"${check_gate}" = x ]; then
      echo "gateway_enable=\"YES\"" >> /etc/rc.conf
    fi;

  fi;
done;

if [ w${REBUILD} != w ]; then
  BUILD_OPTIONS="${PKG_ADD} remove"
else
  BUILD_OPTIONS="${PKG_ADD} install -y ";
fi;

#Checklibtools
#
LIBTOOL__EXIST=`which libtool`;
if [ x"${LIBTOOL__EXIST}" != x ]; then
  LIBTOOL_VERSION=`libtool --version | head -1| awk '{ print $4 }' | sed 's/\.//g'`

  if [ "${LIBTOOL_VERSION}" -lt 2400 ]; then
    RESULT="libtool "${RESULT}
  fi;
fi;

for name in ${RESULT}; do
  name=`echo "${name}" | sed s/\"//g;`;
  echo "Program: ${name}";
  cmd="";

  #System and ports update
  if [ "${name}" = "update" ] ; then
    #System update
    # freebsd-update
    #ports update

    ${PKG_ADD} upgrade
  fi;

  if [ "${name}" = "apache22" ]; then
    _install apache22
    AUTOCONF_PROGRAMS="${AUTOCONF_PROGRAMS} apache"
  fi;

  if [ "${name}" = "Utils" ]; then
    _install bash vim-lite tmux git
  fi;

  if [ "${name}" = "mysql56" ]; then
    _install mysql56-server
    RESTART_MYSQL=/usr/local/etc/rc.d/mysql-server
  fi;

  if [ "${name}" = "freeradius" ]; then
    _install freeradius
    AUTOCONF_PROGRAMS="${AUTOCONF_PROGRAMS} freeradius"
  fi;

  if [ "${name}" = "DHCP" ]; then
    _install isc-dhcp43-server

    install_sudo
    AUTOCONF_PROGRAMS="${AUTOCONF_PROGRAMS} dhcp"
  fi;

  if [ "${name}" = "Perl_Modules" ]; then
    _install p5-Digest-MD4 p5-Digest-MD5 p5-Digest-SHA1 p5-DBD-mysql p5-PDF-API2 \
      p5-Time-HiRes \
      p5-XML-Simple \
      p5-RRD-Simple \
      p5-Spreadsheet-WriteExcel
  fi;

  if [ "${name}" = "Mail" ]; then
    cmd="cd ${PORTS_LOCATION}/security/cyrus-sasl2 ${BUILD_OPTIONS};";
    cmd=${cmd}"cd ${PORTS_LOCATION}/mail/postfix27 ${BUILD_OPTIONS};"; 
    cmd=${cmd}"cd ${PORTS_LOCATION}/mail/maildrop && make WITH_AUTHLIB=yes MAILDROP_TRUSTED_USERS=vmail MAILDROP_SUID=1005 MAILDROP_SGID=1005 && make install;";
    cmd=${cmd}"cd ${PORTS_LOCATION}/security/courier-authlib-base ${BUILD_OPTIONS};"
    cmd=${cmd}"cd ${PORTS_LOCATION}/security/courier-authlib ${BUILD_OPTIONS};"
    cmd=${cmd}"cd ${PORTS_LOCATION}/mail/courier-imap ${BUILD_OPTIONS} ;"
    cmd=${cmd}"cd ${PORTS_LOCATION}/mail/p5-Mail-SpamAssassin/ ${BUILD_OPTIONS} ;"
    cmd=${cmd}"cd ${PORTS_LOCATION}/security/clamav ${BUILD_OPTIONS};"
    cmd=${cmd}"cd ${PORTS_LOCATION}/security/amavisd-new ${BUILD_OPTIONS};"
    cmd=${cmd}"cd ${PORTS_LOCATION}/mail/squirrelmail ${BUILD_OPTIONS};"

    #Check apache php support
    APACHE_CONFIG='/usr/local/etc/apache22/httpd.conf'
    check_php_conf=`grep 'x-httpd-php' ${APACHE_CONFIG}`
    if [ w${check_php_conf} = w ]; then
      read -p "Can\'t find php in apache config add it? (y/n): " PHP_CONF;
      if [ w${PHP_CONF} = wy ]; then
        echo "AddType application/x-httpd-php .php" >> ${APACHE_CONFIG}
      fi;
    fi;
 
    PHP_INDEX=`grep index.php ${APACHE_CONFIG}`;
    if [ x"${PHP_INDEX}" = x ]; then
      cp ${APACHE_CONFIG} ${APACHE_CONFIG}_bak
      cat ${APACHE_CONFIG}_bak | sed 's/DirectoryIndex index.html/DirectoryIndex index.html index.php/' > ${APACHE_CONFIG}
    fi;

    AUTOCONF_PROGRAMS="${AUTOCONF_PROGRAMS} postfix"
    AUTOCONF_PROGRAMS_FLAGS="${AUTOCONF_PROGRAMS_FLAGS} AMAVIS=1 CLAMAV=1"
  fi;

  if [ "${name}" = "MRTG" ]; then
    _install mrtg;
    install_rstat;
    AUTOCONF_PROGRAMS="${AUTOCONF_PROGRAMS} mrtg"
  fi;

  if [ "${name}" = "fsbackup" ]; then
    install_fsbackup
  fi;

  if [ "${name}" = "IPN" ]; then
    _install flow-tools;
    if [ x${INSTALL_IPCAD} = x1 ]; then
      _install ipcad
      AUTOCONF_PROGRAMS="${AUTOCONF_PROGRAMS} ipcad freebsd"
    fi;

    install_sudo

    AUTOCONF_PROGRAMS="${AUTOCONF_PROGRAMS} flow-tools"

    if [ -d ${BILLING_DIR} ]; then
      ls -s ${BILLING_DIR}/Abills/modules/Ipn/traffic2sql ${BILLING_DIR}/libexec/
    fi;
  fi;

  if [ "${name}" = "PERL_SPEEDY" ]; then
     mkdir src
     cd src
     fetch http://daemoninc.com/SpeedyCGI/CGI-SpeedyCGI-2.22.tar.gz
     tar zxvf CGI-SpeedyCGI-2.22.tar.gz
     cd CGI-SpeedyCGI-2.22
     perl Makefile.PL
     make
     make install
  fi;

  if [ "${name}" = "mpd" ]; then
    _install mpd5
    AUTOCONF_PROGRAMS="${AUTOCONF_PROGRAMS} mpd freebsd"
    AUTOCONF_PROGRAMS_FLAGS="${AUTOCONF_PROGRAMS_FLAGS} MPD5=1"
  fi;

  if [ "${name}" = "Build_Kernel" ]; then
    freebsd_build_kernel
  fi;
done

#Add perl symlink
if [ ! -f /usr/bin/perl  ]; then

  ln -s  /usr/local/bin/perl  /usr/bin/perl

  echo "Sym link"

exit;

fi;
}


#**********************************************************
#
#**********************************************************
install_dhcp () {

 # Dhcplog
 echo "local7.*                        /var/log/dhcpd.log" >> /etc/rsyslog.conf
 touch /var/log/dhcpd.log
 #Anton: added another autostart params
 if [ "${OS}" = 'Debian' ]; then
  echo "*****************************debian*********************************";
  sleep 2;
  fi;
 /etc/init.d/rsyslog restart

 # ln -s /usr/abills/Abills/Dhcphosts/dhcp_log2db.pl /usr/abills/libexec/dhcp_log2db.pl
 # echo "tail -F /var/log/dhcpd.log | /usr/abills/libexec/dhcp_log2db.pl" >> /etc/rc.local

 chown ${WEB_SERVER_USER} /etc/dhcp/dhcpd.conf
 echo "${WEB_SERVER_USER} ALL = NOPASSWD: /etc/init.d/isc-dhcp-server" >> /etc/sudoers
}

#**********************************************************
#
#**********************************************************
ipn_post_install () {
 ln -s /usr/abills/Abills/Dhcphosts/dhcp_log2db.pl /usr/abills/libexec/dhcp_log2db.pl
 echo "tail -F /var/log/dhcpd.log | /usr/abills/libexec/dhcp_log2db.pl" >> /etc/rc.local
}

#**********************************************************
# Load abills DB
#**********************************************************
load_db () {
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!";
echo "!!!!!           Loading DB                       !!!";
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!";
mysql --default-character-set=utf8 -e 'use mysql; \
GRANT ALL ON abills.* TO `abills`@localhost IDENTIFIED BY "sqlpassword";  \
CREATE DATABASE abills DEFAULT CHARACTER SET utf8 COLLATE  utf8_general_ci; \
flush privileges; \
quit';

cd /usr/abills/db/
mysql --default-character-set=utf8 -D abills < abills.sql

echo "loaded";
}

#**********************************************************
# Linux program builder
#**********************************************************
linux_build () {

read -p "OS Linux \"${OS_NAME}\" version \"${OS_VERSION}\" kernel \"${KERNEL}\" is it correct (y/n)?: " RESPONSE

if [ "$RESPONSE" = n ] ; then
  read -p "choose the correct name from the list ( Mandriva, openSUSE, Ubuntu, Debian, CentOS, Fedora, ARCH, slackware ): " OS_NAME
  echo ""
  echo ${OS_NAME}
else
  echo ""; #You did not make a valid selection!"
fi;

OPTIONS="update Update  on
    mysql   Mysql   off
    apache       Apache  off
    Perl_Modules perl_modules off
    freeradius   FreeRADIUS off
    DHCP         DHCP  off
    MRTG         Mrtg  off
    IPN          IPN_collector off
    ACCEL-PPP    accel-ppp    off
    ACCEL-IPoE   accel-ipoe off
    fsbackup     fsbackup  off
    mk_sysbench  mk_sysbench off
"

#    freeradius-client freeradius-client off
#    PPTP                    PPTP            off
#    PPTPD             pptpd      off

#System defines
  WEB_SERVER_USER="www-data"
  RADIUS_SERVER_USER="freerad"
  RESTART_MYSQL=/etc/init.d/mysqld
  RESTART_RADIUS=/etc/init.d/freeradius
  RESTART_APACHE=/etc/init.d/apache2
  RESTART_DHCP=/etc/init.d/isc-dhcp-server
  APACHE_CONF_DIR=/etc/apache2/sites-enabled/
  FILE_PING='/bin/ping';

case "${OS_NAME}" in
  *buntu)
    if [ w${REBUILD} != w ]; then
      BUILD_OPTIONS=" sudo apt-get -y remove "
    else
      BUILD_OPTIONS=" sudo apt-get ${YES} install ";
    fi;

    UPDATE_CMD="_install update"
    _install dialog git make gcc vim bc wget

    PERL_MODULES="libdigest-sha-perl libdigest-md4-perl libdigest-md5-perl"
    ;;
  *ebian)
    RESTART_MYSQL=/etc/init.d/mysql
    RESTART_RADIUS=/etc/init.d/freeradius
    RESTART_APACHE=/etc/init.d/apache2

    if [ -f /etc/apt/apt.conf ]; then 
      if [ x`grep 'APT::Cache-Limit' /etc/apt/apt.conf` = x ]; then
        echo 'APT::Cache-Limit "50000000";' >> /etc/apt/apt.conf
      fi;
  elif [ -f /etc/apt/apt.conf.d ]; then
      if [ x`grep 'APT::Cache-Limit' /etc/apt/apt.conf.d` = x ]; then
        echo 'APT::Cache-Limit "50000000";' >> /etc/apt/apt.conf.d
      fi;
    fi;

    UPDATE_CMD="aptitude update"

    if [ w${REBUILD} != w ]; then
      BUILD_OPTIONS=" apt-get -y remove "
    else
      BUILD_OPTIONS=" apt-get -y install ";
    fi;
  # DEBIAN <7 libdigest-sha1-perl; DEBIAN >8 libdigest-sha-perl
  PERL_MODULES="libdigest-sha-perl libxml-simple-perl liburi-perl libdigest-md4-perl libdigest-md5-perl libdigest-sha1-perl"
    _install dialog cvs gcc vim make
  ;;
  ALTLinux)
    if [ w${REBUILD} != w ]; then
      BUILD_OPTIONS=" apt-get -y remove "
    else
      BUILD_OPTIONS=" apt-get -y install ";
    fi;

    _install dialog cvs gcc vim make wget aptitude perl-devel libperl-dev
  ;;
  *edora)
    if [ w${REBUILD} != w ]; then
      BUILD_OPTIONS=" yum -y remove "
    else
      BUILD_OPTIONS=" yum -y install ";
    fi;

    rpm -q dialog > /dev/null 2>&1
    if [ $? = '1' ]; then
      _install dialog
    fi;

    rpm -q cvs > /dev/null 2>&1
    if [ $? = '1' ]; then
      _install cvs
    fi;

    WEB_SERVER_USER=apache
    RADIUS_SERVER_USER=radiusd
    RESTART_MYSQL=/etc/init.d/mysql
    RESTART_RADIUS=/etc/rc.d/init.d/freeradius
    RESTART_APACHE="service httpd"

  ;;
  *penSUSE)
    WEB_SERVER_USER=wwwrun
    RADIUS_SERVER_USER=radiusd
    RESTART_MYSQL=/etc/init.d/mysql
    RESTART_RADIUS=/etc/init.d/freeradius
    RESTART_APACHE=/etc/init.d/apache

    if [ w${REBUILD} != w ]; then
      BUILD_OPTIONS=" zypper  remove "
    else
      BUILD_OPTIONS=" zypper  install ";
    fi;

    zypper se -i dialog > /dev/null 2>&1
    if [ $? = '0' ]; then
      ${BUILD_OPTIONS} dialog
    fi;

    zypper se -i cvs > /dev/null 2>&1
    if [ $? = '0' ]; then
       ${BUILD_OPTIONS} cvs
    fi;

    PERL_MODULES="perl-DBD-mysql perl-XML-Simple"
  ;;
  CentOS)
    UPDATE_CMD="yum -y update"

    if [ w${REBUILD} != w ]; then
      BUILD_OPTIONS=" yum -y remove "
    else
      BUILD_OPTIONS=" yum -y install ";
    fi;

    _install dialog cvs bc wget mod_ssl perl-DB_File openssl policycoreutils-python expat-devel expat;
  yum install perl-Time-HiRes -y
  yum install sudo -y
    PERL_MODULES="perl-DBD-mysql perl-XML-Simple " 

    semanage port -a -t http_port_t -p tcp 9443
  iptables -I INPUT -p tcp --dport 80 -m state --state NEW -j ACCEPT
    iptables -I INPUT -p tcp --dport 9443 -m state --state NEW -j ACCEPT
  service iptables save
  /etc/init.d/iptables restart

    WEB_SERVER_USER=apache
    RESTART_MYSQL=/etc/init.d/mysqld
    RESTART_RADIUS=/etc/init.d/freeradius
    RESTART_APACHE="/sbin/service httpd"
    APACHE_CONF_DIR=/etc/httpd/conf.d/
  ;;
  *andriva)
    rpm -qa | grep dialog > /dev/null 2>&1
    a=`echo $?`;
    if [ $a = 1 ];  then
      urpmi -a --auto dialog
    fi;

    rpm -qa | grep cvs > /dev/null 2>&1
    b=`echo $?`;
    if [ $b = 1 ]; then
      urpmi -a --auto cvs
    fi;

    if [ w${REBUILD} != w ]; then
      BUILD_OPTIONS=" urpme -a --auto  "
    else
      BUILD_OPTIONS=" urpmi -a --auto ";
    fi;
  ;;
  ARCH)
    pacman -Q dialog > /dev/null 2>&1
    a=`echo $?`;
    if [ $a = 1 ];  then
      pacman -S --noconfirm dialog
    fi;
    pacman -Q cvs > /dev/null 2>&1

    b=`echo $?`;
    if [ $b = 1 ]; then
      pacman -S --noconfirm cvs
    fi;

    if [ w${REBUILD} != w ]; then
      BUILD_OPTIONS=" pacman -R --noconfirm   "
    else
      BUILD_OPTIONS=" pacman -S --noconfirm   ";
    fi;
  ;;
  *entoo)
    if [ w${REBUILD} != w ]; then
      BUILD_OPTIONS=" emerge -pv  "
    else
      BUILD_OPTIONS=" emerge -pv  ";
    fi;

    _install dialog cvs bc
  ;;
  RedHat)
    WEB_SERVER_USER=apache
    RESTART_MYSQL=/etc/init.d/mysqld
    RESTART_RADIUS=/etc/init.d/radiusd
    RESTART_APACHE=/etc/init.d/httpd

    if [ w${REBUILD} != w ]; then
      BUILD_OPTIONS=" yum  remove "
    else
      BUILD_OPTIONS=" yum  install ";
    fi;

    _install dialog cvs perl-Time-HiRes git;
  ;;
  Slackware)
    WEB_SERVER_USER=apache
    RESTART_MYSQL=/etc/rc.d/rc.mysqld
    RESTART_RADIUS=/etc/rc.d/rc.radius
    RESTART_APACHE=/etc/rc.d/rc.httpd

    my is_slackpkg=`which slackpkg`;
    if [ "${is_slackpkg}" = "" ]; then
      _fetch slackpkg-2.82.0-noarch-2.tgz http://www.slackpkg.org/stable/slackpkg-2.82.0-noarch-2.tgz
      installpkg slackpkg-2.82.0-noarch-2.tgz
    fi;

    if [ w${REBUILD} != w ]; then
      BUILD_OPTIONS="slackpkg"
    else
      BUILD_OPTIONS="slackpkg"
    fi;
  ;;
  * ) 
    echo "OS: ${OS_NAME} Version: ${OS_VERSION}"
    echo "Unsupported Version"
    echo "Select Correct Version"
    OS_NAME=""
    return
  ;;
esac

if [ x"${BENCHMARTK}" != x ]; then
  mk_sysbench;
  exit;
fi;

DIALOG_TITLE="Options for ABillS LINUX";
DIALOG_TITLE=${DIALOG_TITLE}`echo ; uname -a`;
if [ w${DEBUG} != w ] ; then
  DIALOG_TITLE=${DIALOG_TITLE}' (DEBUG MODE)';
fi;

dialog --checklist "${DIALOG_TITLE}" 50 75 15 ${OPTIONS} 2>${TMPOPTIONSFILE}

RESULT=`cat ${TMPOPTIONSFILE}`;

if [ "${RESULT}" = "" ]; then
  exit;
fi;

for name in $RESULT; do
  name=`echo ${name} | sed 's/\"//g'`;
  echo "Program: ${name}";
  cmd="";

  if [ "${name}" = "update" -a "${UPDATE_CMD}" != "" ] ; then
    ${UPDATE_CMD}
  fi;

  if [ "${name}" = "apache" ]; then
    if [ "${OS_NAME}" = Mandriva ];  then 
      cmd=${cmd}"${BUILD_OPTIONS} apache-mpm-worker apache-mod_php; ";
    elif [ "${OS_NAME}" = ARCH ]; then 
      cmd=${cmd}"${BUILD_OPTIONS} apache php; "; 
    elif [ "${OS_NAME}" = Fedora -o ${OS_NAME} = fedora ];then 
      cmd=${cmd}"${BUILD_OPTIONS} httpd php; ";
    elif [ "${OS_NAME}" = "CentOS" ]; then 
      #load DATABASE. Should be where it have to be;
      load_db;
      cmd=${cmd}"${BUILD_OPTIONS} httpd mod_ssl php; ";
      #Anton: CentOS_VER 6
      cmd=${cmd}"chkconfig httpd on;"
      #Anton: CentOS VER 7
      #open firewall
      firewall-cmd --zone=public --add-port=9443/tcp --permanent
      firewall-cmd --reload
      cmd=${cmd}"systemctl enable httpd; systemctl start httpd;";
    elif [ "${OS_NAME}" = Debian ]; then
      load_db;
      cmd="${BUILD_OPTIONS} apache2; a2enmod ssl; a2enmod rewrite; a2enmod cgi;";
      update-rc.d apache2 defaults
      update-rc.d apache2 start 20 3 4 5
      cp /usr/abills/misc/apache/abills_httpd.conf /etc/apache2/sites-enabled/
    elif [ "${OS_NAME}" = Ubuntu ]; then
      load_db;
      cmd="${BUILD_OPTIONS} apache2; a2enmod ssl; a2enmod rewrite; a2enmod cgi;";
      update-rc.d apache2 defaults
      update-rc.d apache2 start 20 3 4 5
      cp /usr/abills/misc/apache/abills_httpd.conf /etc/apache2/sites-enabled/
    else
      cmd="${BUILD_OPTIONS} apache2; a2enmod ssl; a2enmod rewrite; a2enmod cgi;";
      update-rc.d apache2 defaults
      update-rc.d apache2 start 20 3 4 5

      #sudo ln -s /etc/apache2/mods-available/rewrite.load /etc/apache2/mods-enabled/rewrite.load;";
      #ALT LINUX
      #apt-get install apache2-mod_ssl
      #apt-get install apache2-rewrite
    fi;

    AUTOCONF_PROGRAMS="${AUTOCONF_PROGRAMS} apache";
  fi;

  #pptp
  if [ ${name} = "PPTP" ]; then
    if [ "${OS_NAME}" = ARCH -o "${OS_NAME}" = Fedora ]; then
      cmd="${BUILD_OPTIONS} ppp; ";
    elif [ "${OS_NAME}" = centos ];  then 
      cmd="${BUILD_OPTIONS} ppp; ";
    else
      cmd="${BUILD_OPTIONS} pptp-linux";
      pptp=`apt-cache show ppp |grep Version | awk '{print $2}' | cut -c 1-5`;
      if [ $pptp1="2.4.4" ]; then 
        for pkg in patch make gcc; do
          apt-get -y install ${pkg};
        done 

        mkdir ~/src/ && cd ~/src && wget ftp://ftp.samba.org/pub/ppp/ppp-2.4.4.tar.gz && wget http://bugs.gentoo.org/attachment.cgi?id=102981 -O radius-gigawords.patch;
        tar zxvf ppp-2.4.4.tar.gz && cd ppp-2.4.4 && patch -p1 -l < ../radius-gigawords.patch && ./configure --prefix=/usr && make && make install;
      fi;
    fi;
    #pptp=`yum info ppp |grep Version | awk '{print $3}' |uniq`;
  fi;

  #MYSQL
  if [ ${name} = "mysql" ]; then
    if [ "${OS_NAME}" = Mandriva ];  then 
      cmd=${cmd}"${BUILD_OPTIONS} MySQL;";
    elif [ "${OS_NAME}" = ARCH ]; then 
      cmd=${cmd}"${BUILD_OPTIONS} mysql; ";
    elif [ "${OS_NAME}" = SUSE ]; then 
      cmd=${cmd}"${BUILD_OPTIONS} mysql; ";
    elif [ "${OS_NAME}" = "CentOS"  ]; then
      CUR_VERSION=`echo "${OS_VERSION}" | sed 's/\(^[0-9]\)\.\([0-9]\).*/\1\\2/' `
      if [ "${CUR_VERSION}" -gt "69" ]; then
        cmd=${cmd}"${BUILD_OPTIONS} mariadb mariadb-devel mariadb-libs mariadb-server"
        cmd=${cmd}";systemctl enable mariadb; systemctl start mariadb;"
      fi;
    elif [ "${OS_NAME}" = "Ubuntu" ]; then
      cmd=${cmd}"${BUILD_OPTIONS} mysql-server; ";
      cmd=${cmd}"update-rc.d mysql defaults; "
      cmd=${cmd}"update-rc.d mysql start 20 3 4 5; "
    elif [ "${OS_NAME}" = "Debian" ]; then
      cmd=${cmd}"${BUILD_OPTIONS} mysql-server; ";
      cmd=${cmd}"systemctl enable mysql; "
    else
      cmd=${cmd}"${BUILD_OPTIONS} mysql-server;";
      cmd=${cmd}"chkconfig --levels 235 mysqld on";
    fi;
  fi;

  if [ "${name}" = "freeradius" ]; then
    install_freeradius;
  fi;

  if [ ${name} = "mk_sysbench" ]; then
    mk_sysbench ;
  fi;

  if [ ${name} = "DHCP" ]; then
    if [ "${OS_NAME}" = Debian ];  then 
      # ANTON: 7 version 
      cmd=${cmd}"${BUILD_OPTIONS} dhcp3-server;";
      # ANTON: 8 version 
      cmd=${cmd}"${BUILD_OPTIONS} isc-dhcp-server;";
     elif [ "${OS_NAME}" = CentOS ];  then
      cmd=${cmd}"${BUILD_OPTIONS} dhcp dhcp-libs;";
      install_dhcp;
#    elif [ x${OS_NAME} = xSlackware ]; then
#      install_dhcp
    else 
      cmd=${cmd}"${BUILD_OPTIONS} dhcp3-server;";
    fi;
    install_dhcp;
  fi;

  if [ ${name} = "Perl_Modules" ]; then
    if [ "${PERL_MODULES}" != "" ];  then
      cmd=${cmd}"${BUILD_OPTIONS} ${PERL_MODULES};"
    else 
      cmd=${cmd}"${BUILD_OPTIONS} libdbi-perl libdbd-mysql-perl libdigest-sha1-perl libdigest-md4-perl libcrypt-des-perl";
      cmd=${cmd}"${BUILD_OPTIONS} perl-XML-Simple perl-URI libpdf-api2-perl"
    fi;
  fi;

  #Check apache php support
  if [ ${name} = "MRTG" ]; then
    if [ x${OS_NAME} = xMandriva ]; then
      echo "install mrtg from sources";
    elif [ x${OS_NAME} = xSlackware ]; then
      wget --no-check-certificate https://bitbucket.org/pierrejoye/gd-libgd/get/GD_2_0_33.tar.gz
      tar zxvf GD_2_0_33.tar.gz
      cd pierrejoye-gd-libgd-5551f61978e3/src
      ./configure
      make 
      make install

      wget http://oss.oetiker.ch/mrtg/pub/mrtg-2.17.4.tar.gz
      tar zxvf  mrtg-2.17.4.tar.gz
      cd mrtg-2.17.4
      ./configure
      make
      make install
    else
      cmd="${BUILD_OPTIONS} mrtg wget;"
    fi;

    install_rstat;

    AUTOCONF_PROGRAMS="${AUTOCONF_PROGRAMS} mrtg"
  fi;

  if [ ${name} = "fsbackup" ]; then
    install_fsbackup ;
  fi;

  if [ ${name} = "IPN" ]; then
    if [ ${OS_NAME} = ARCH -o ${OS_NAME} = Slackware ]; then 
      echo "install from sources";
      install_ipn
    fi;

    #Anton : Custom build for CentOS;
    if [ ${OS_NAME} = "CentOS" ]; then
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!";
      echo "!!!    Installing EPEL repo                    !!!";
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!";
      install_epel;
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!";
      echo "!!!    Installing flow-tools                   !!!";
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!";

      yum -y install flow-tools-devel flow-tools
      mkdir /usr/abills/var/log/ipn/;
  # yum -y install gcc bzip2
    # cd /usr/src/
  # wget https://flow-tools.googlecode.com/files/flow-tools-0.68.5.1.tar.bz2
    # tar  -xjvf flow-tools-0.68.5.1.tar.bz2
    # cd flow-tools-0.68.5.1
    # ./configure
    # make && make install

      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!";
      echo "!!!            Installing ipcad                !!!";
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!";
      install_ipcad;
    else
      cmd=${cmd}"${BUILD_OPTIONS} flow-tools;";
      cmd=${cmd}"mkdir /usr/abills/var;";
      cmd=${cmd}"mkdir /usr/abills/var/log;";
      cmd=${cmd}"mkdir /usr/abills/var/log/ipn;";
      cmd=${cmd}"chown flowtools /usr/abills/var/log/ipn;";
    fi;

    if [ ${OS_NAME} = Mandriva -o ${OS_NAME} = Fedora ]; then
      echo "to install ipcad you need to download sources";
    elif [ ${OS_NAME} = debian -o ${OS_NAME} = Debian ]; then
      cmd=${cmd}"cat /usr/abills/misc/flow-tools/flow-capture.conf > /etc/flow-tools/flow-capture.conf;";
    elif [ ${OS_NAME} = debian -o ${OS_NAME} = Ubuntu ]; then
      cmd=${cmd}"cat /usr/abills/misc/flow-tools/flow-capture.conf > /etc/flow-tools/flow-capture.conf;";
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!";
      echo "!!!";
      echo "!!! install ipcad from source http://lionet.info/soft/ipcad-3.7.3.tar.gz";
      echo "!!!";
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!";
      install_ipcad ;
    else 
      cmd=${cmd}"${BUILD_OPTIONS} ipcad;";
    fi;

    install_sudo ;
  fi;
 
  #Accel-PPTP Build
  if [ "${name}" = "ACCEL-IPoE" ]; then
    install_accel_ipoe
  #Accel-PPTP Build
  elif [ "${name}" = "ACCEL-PPP" ]; then
    install_accel_ppp
  fi;

  #PPPoE
  if [ ${name} = "PPPoE" ]; then
    _install gcc binutils pppoe bzip2 cmake
    cd /usr/src
    wget http://www.roaringpenguin.com/files/download/rp-pppoe-3.10.tar.gz
    tar xvzf rp-pppoe-3.10.tar.gz
    cd rp-pppoe-3.10/src/
    ./configure --enable-plugin= /usr/lib/pppd/2.4.5/rp-pppoe.so
    make
    make install
  fi;

  if [ w"${VERBOSE}" != w ]; then
    echo ${cmd}
  else
    eval ${cmd}
    if [ x"${DEBUG}" != x ]; then
      echo ${cmd} >> ${CMD_LOG}
    fi;
  fi

  # Echo 
  if [ "${DEBUG}" != "" ]; then
     echo "Finished: ${name}";
     read -p "Contibue install. [y/n]" CONTINUE;
  fi;

done
}

#**********************************************************
#Make plugins
#**********************************************************
plugin_start () {

if [ "$1" != "" ]; then
  plugin_name=$1;
  if [ ! -f "${PLUGINS_DIR}/${plugin_name}" ]; then
    echo "plugin: '${plugin_name}' not exists";
    exit;
  fi;
 
  run_plugin "${plugin_name}";

  #port_install;

  if [ "${BILLING_WEB_IP}" = "" ]; then
    BILLING_WEB_IP="your.host"
  fi;

fi;

}

#**********************************************************
# Fetch free distro
#**********************************************************
fetch_free_distro () {

  if [ ! -d /usr/abills ]; then
    echo "Fetching ABillS ${ABILLS_VERSION}${VERSION_PREFIX}.\n May take some time that depends off your internet connection speed";
    if [ x"${TEST_DISTRO}" = x"" ]; then
      URL="http://downloads.sourceforge.net/project/abills/abills/${ABILLS_VERSION}/abills-${ABILLS_VERSION}${VERSION_PREFIX}.tgz"
    else
      URL="http://abills.net.ua/misc/abills_test.tgz";
    fi;
    _fetch abills-${ABILLS_VERSION}.tgz "${URL}";
    tar zxvf abills-${ABILLS_VERSION}.tgz -C /usr/
  else
     echo "ABillS exists at /usr/abills/"
  fi;
}

#**********************************************************
# Start tmux session
#**********************************************************
start_tmux_session() {

  _install tmux

  command -v tmux >/dev/null 2>&1 || ( echo >&2 "tmux is not installed."; return 1 )

  SESSION_NAME='INSTALL';
  tmux attach-session -t ${SESSION_NAME} || tmux new-session -n ${SESSION_NAME} -s ${SESSION_NAME} "./install.sh --in_tmux $* && echo -p 'Script has been ended. Press ENTER to exit'"
  
  sleep 2;
}

#**********************************************************
#
#**********************************************************
fetch_distro(){
  if [ "${FETCH_FREE_DISTR}"  != "" -a "${COM_DISTRO}" = "" ] ; then
    echo "===============================================================";
    fetch_free_distro;
  elif [ ! -d "${BILLING_DIR}" ]; then
    UPDATE_URL=http://abills.net.ua/misc/update.sh
    # make cvs/git update
    cd ${BASE_PWD}
    if [ ! -f update.sh ]; then
      _fetch update.sh "${UPDATE_URL}";
      chmod +x update.sh
    fi;
    if [ "${BASE_INSTALL_DIR}" != "" ]; then 
      KEY_DIR="-key ${BASE_INSTALL_DIR}"
    fi;

    ./update.sh -git ${KEY_DIR}
  fi;

  echo "${COM_DISTRO} xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
}


# Installation proccess
# Proccess command-line options
#
for _switch ; do
        case $_switch in
        -d)
                DEBUG=1
                shift
                ;;
        -V)     VERBOSE=1
                shift; shift
                ;;
        -f)     FETCH_FREE_DISTR=1;
                shift;
                ;;
        -com)   COM_DISTRO=1;
                shift;
                ;;
        -b)     BENCHMARK=1;
                shift;
                ;;
        -r)     REBUILD=1
                shift; shift
                ;;
        -s)     CVSUP=1;
                shift; shift
                ;;
        -v)
                echo ${VERSION}
                exit;
                ;;
        -y)     YES="-y";
                shift;
                ;;
        -u)     UNINSTALL=1;
                shift; shift
                ;;
        -p)     USE_PLUGIN=$2;
                shift; shift;
                ;;
        -h)
                help
                exit;
                shift; shift
                ;;
        -t)     start_tmux_session
                exit;
                shift; shift
                ;;
        --in_tmux)  IN_TMUX="true";
                    shift;
                    ;;
        --check_services) check_ps;
                          exit;
                          ;;
        --test)  TEST_DISTRO="true";
                shift;
                ;;
        esac
done


if [ x"${UNINSTALL}" != x ]; then
  _uninstall
  exit;
fi;

#Run program
#Get os
while [ "${OS_NAME}" = "" ]; do
  get_os
  mk_resolve

  #Make source dir

  if [ ! -d "${BASEDIR}/src/" ]; then
    mkdir "${BASEDIR}/src/"
  fi;

  if [ ! "${IN_TMUX}" ]; then
    start_tmux_session;
    exit 0;
  fi;

  #Show plugins
  #prepare dialog
  tempfile=temp.txt;
  dialog_title="OS: ${OS_NAME} ${OS_VERSION} ${OS_NUM} #I:${VERSION}";
  for plugin in ${PLUGINS_DIR}/*; do
    plugin_name="`cat ${plugin} | grep -e '#OS' | sed -e 's/[#]OS/''/' | sed -e 's/ //g'`";
#    echo "PLUGIN NAME: ${plugin_name}";
    plugin_val="`echo ${plugin} | sed -e 's/plugins[/]/''/'`";
#     echo ${plugin_val};
    plugins_list="${plugins_list}${plugin_val} ${plugin_name} ";
  done;

#  echo ${plugins_list};

  DIALOG_INSTALLED=`which dialog`;

  if [ x"" = x"${DIALOG_INSTALLED}" ]; then
    _install dialog;
  fi;

  #try to guess plugin
	guess_plugin;

	if [ "${use_plugin}" ]; then
	  USE_PLUGIN=${use_plugin};
  else
	  if [ "${PLUGIN_NAME}" ]; then
	    USE_PLUGIN=${PLUGIN_NAME}
	  else
	    dialog --title "${dialog_title}" --menu "Choose plugin" 40 40 10 ${plugins_list} 2>$tempfile;
      USE_PLUGIN=`cat $tempfile`;
      rm -f $tempfile;
	  fi
  fi;

  #  echo "Use plugin [enter for default plugin]: ";
  #Changed by AnyKey
  #  if [ "${USE_PLUGIN}" = "" ]; then
  #    read -p "Use plugin [Empty string for default plugin]: " USE_PLUGIN
  #  fi;

  if [ "${USE_PLUGIN}" != "" ]; then
    echo "Plugin: ${USE_PLUGIN}";
    fetch_distro;
    plugin_start ${USE_PLUGIN}
  elif [ "${OS}" = "Linux" ]; then
    linux_build
  else 
    freebsd_build
  fi;
done;

mk_file_definition

cd ${BILLING_DIR}/misc/
mkdir /usr/abills/var/ /usr/abills/var/log/

AUTOCONF_PROGRAMS=`echo ${AUTOCONF_PROGRAMS} | sed 's/ /,/g'`
echo "Autoconf: ${AUTOCONF_PROGRAMS}";

if [ x${WEB_SERVER_USER} = x ]; then
  WEB_SERVER_USER=www
fi;

echo "Autoconf programs: ${AUTOCONF_PROGRAMS}";

./autoconf PROGRAMS=${AUTOCONF_PROGRAMS} ${AUTOCONF_PROGRAMS_FLAGS} 

#if [ -x /usr/bin/chcon ]; then
#  chcon -R -t httpd_sys_content_t ${BILLING_DIR}/cgi-bin/index.cgi
#  chcon -R -t httpd_sys_content_t ${BILLING_DIR}/cgi-bin/admin/index.cgi 
#  chcon -R -t httpd_sys_content_t ${BILLING_DIR}/cgi-bin/graphics.cgi
#fi;

if [ x"${BILLING_WEB_IP}" = x ]; then
  BILLING_WEB_IP="your.host"
fi;

check_ps

${DIALOG} --msgbox "ABillS Install complete\n\nAdmin  Interface\n https://${BILLING_WEB_IP}:9443/admin/\n Login: abills\n Password: abills\n${RESULT}" 20  52
