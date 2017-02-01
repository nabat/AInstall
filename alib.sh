
#ABillS Shell library
#
#**********************************************************
# Get OS 
# OS_NAME, OS_VERSION, OS_NUM
#**********************************************************

ALIB_LOADED="Loaded";

get_os () {

OS=`uname -s`
OS_VERSION=`uname -r`
MACH=`uname -m`
OS_NAME=""

if [ "${OS}" = "SunOS" ] ; then
  OS=Solaris
  ARCH=`uname -p`  
  OSSTR="${OS} ${OS_VERSION}(${ARCH} `uname -v`)"
elif [ "${OS}" = "AIX" ] ; then
  OSSTR="${OS} `oslevel` (`oslevel -r`)"
elif [ "${OS}" = "FreeBSD" ] ; then
  OS_NAME="FreeBSD";
  OS_NUM=`uname -r | awk -F\. '{ print $1 }'`
elif [ "${OS}" = "Linux" ] ; then
  #GetVersionFromFile
  KERNEL=`uname -r`
  if [ -f /etc/altlinux-release ]; then     
    OS_NAME=`cat /etc/altlinux-release | awk '{ print $1 $2 }'`
    OS_VERSION=`cat /etc/altlinux-release | awk '{ print $3 }'`
  #RedHat CentOS
  elif [ -f /etc/redhat-release ] ; then
    #OS_NAME='RedHat'
    OS_NAME=`cat /etc/redhat-release | awk '{ print $1 }'`
    PSUEDONAME=`cat /etc/redhat-release | sed s/.*\(// | sed s/\)//`
    OS_VERSION=`cat /etc/redhat-release | sed s/.*release\ // | sed s/\ .*//`
  elif [ -f /etc/SuSE-release ] ; then
    OS_NAME='openSUSE'
    #OS_NAME=`cat /etc/SuSE-release | tr "\n" ' '| sed s/VERSION.*//`
    OS_VERSION=`cat /etc/SuSE-release | grep 'VERSION' | tr "\n" ' ' | sed s/.*=\ //`
  elif [ -f /etc/mandrake-release ] ; then
    OS_NAME='Mandrake'
    PSUEDONAME=`cat /etc/mandrake-release | sed s/.*\(// | sed s/\)//`
    OS_VERSION=`cat /etc/mandrake-release | sed s/.*release\ // | sed s/\ .*//`
#  elif [ -f /etc/debian_version ] ; then
#    OS_NAME="Debian `cat /etc/debian_version`"
#    OS_VERSION=`cat /etc/issue | head -1 |awk '{ print $3 }'`
  elif [ -f /etc/slackware-version ]; then 
    OS_NAME=`cat /etc/slackware-version | awk '{ print $1 }'`
    OS_VERSION=`cat /etc/slackware-version | awk '{ print $2 }'`   
  elif [ -f /etc/gentoo-release ]; then
    OS_NAME=`cat /etc/os-release | grep "^NAME=" | awk -F= '{ print $2 }'`
    OS_VERSION=`cat /etc/gentoo-release`   
  else
    #Debian 
    OS_NAME=`cat /etc/issue| head -1 |awk '{ print $1 }'`
    OS_VERSION=`cat /etc/issue | head -1 |awk '{ print $3 }'`
  fi

  if [ -f /etc/UnitedLinux-release ] ; then
    OS_NAME="${OS_NAME}[`cat /etc/UnitedLinux-release | tr "\n" ' ' | sed s/VERSION.*//`]"
  fi

  if [ x"${OS_NAME}" = xUbuntu ]; then
    OS_VERSION=`cat /etc/issue|awk '{ print $2 }'`
  fi;
  #OSSTR="${OS} ${OS_NAME} ${OS_VERSION}(${PSUEDONAME} ${KERNEL} ${MACH})"
fi

}

#**********************************************************
# Anykey: Guess system package managers
#**********************************************************
guess_pac_man(){
  #Predefined list of well-known package managers;
  LIST="yum apt-get pkg pacman";

  for MANAGER in ${LIST}; do
    which ${MANAGER} &&  break;
  done

	if [ x'' != x${MANAGER} ]; then
	  BUILD_OPTIONS=" ${MANAGER} -y install";
	fi;
  echo "Package manager: ${MANAGER}";
}

#**********************************************************
# Anykey: Guess plugin to use
#**********************************************************
guess_plugin(){
  get_os;
  #OS_Name
  PLUGIN_OS_NAME=`echo ${OS_NAME} | tr '[:upper:]' '[:lower:]'`;
#  echo ${PLUGIN_OS_NAME};

  #OS Major Version
	PLUGIN_OS_VERSION=`echo ${OS_VERSION} | grep -o -e '^[0-9]*'`;
#  echo ${PLUGIN_OS_VERSION};

  #OS Architecture
	PLUGIN_OS_ARCH='86';
	ARCH64=`echo ${MACH} | grep -o -e '64'`;
 	if [ ${ARCH64} ]; then
	    PLUGIN_OS_ARCH='64';
	fi

	#if file exists
	if [ -f "plugins/${PLUGIN_OS_NAME}_${PLUGIN_OS_VERSION}_x${PLUGIN_OS_ARCH}" ]; then

	  PLUGIN_NAME="${PLUGIN_OS_NAME}_${PLUGIN_OS_VERSION}_x${PLUGIN_OS_ARCH}";

	  echo "Plugin guessed: ${PLUGIN_NAME}";

	else
	  	echo "Plugin guess failed";
	fi

}

#**********************************************************
# Install programs
#**********************************************************
_install () {

  for pkg in $@; do
    if [ "${OS_NAME}" = "CentOS" ]; then
      test_program="rpm -q"
      BUILD_OPTIONS='yum -y install'
    elif [ "${OS}" = "FreeBSD" ]; then
      if [ "${BUILD_OPTIONS}" = ""  ]; then
        BUILD_OPTIONS="pkg install -y"
	set ASSUME_ALWAYS_YES=YES
      fi;
      test_program="pkg info"
    else
      test_program="dpkg -s"
    fi;

    ${test_program} "${pkg}" > /dev/null 2>&1

    res=$?
    if [ "${BUILD_OPTIONS}" = "" ]; then
      if [ "${OS_NAME}" = "CentOS" ]; then
        BUILD_OPTIONS=" yum -y install ";
      else
        guess_pac_man;
        if [ x"${BUILD_OPTIONS}" = x"" ]; then
          echo "Not defined BUILD_OPTIONS params (Your system is currently not supported, or we can't found your package manager)";
          echo "You can open new issue at https://github.com/nabat/AInstall/issues/new";
          exit;
        else
          res=1;
        fi
      fi;
    fi;

    if [ "${res}" = 1 ]; then
      ${BUILD_OPTIONS} "${pkg}"
      echo "Pkg: ${BUILD_OPTIONS} ${pkg} ${res}";
    elif [ "${res}" = 127 -o ${res} = 70 ]; then
      ${BUILD_OPTIONS} "${pkg}"
      echo "Pkg: ${BUILD_OPTIONS} ${pkg} ${res}";
    else
      echo -n "  ${pkg}"
      if [ "${res}" = 0 ]; then
        echo " Installed";
      else 
        echo " ${res}"
      fi;
    fi; 
  done;

}


#**********************************************************
# fetch [output_file] [input_url]
#**********************************************************
_fetch () {

if [ "${OS}" = Linux ]; then
  #check wget 
  CHECK_WGET=`which wget`;

  if [ "${CHECK_WGET}" = "" ]; then
    _install wget
  fi;

  FETCH="wget -q -O"
  MD5="md5sum"
else 
  FETCH="fetch --no-verify-hostname --no-verify-peer -q -o "
  MD5="md5"
fi;

${FETCH} $1 $2

}
