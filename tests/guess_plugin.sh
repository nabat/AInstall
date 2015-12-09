#!/usr/bin/env bash
################################################################
#  Test for guess_plugin func
################################################################

#load library
. "../alib.sh";

get_os;

echo "Alib Loaded: ${ALIB_LOADED}";

echo "################################################";

echo "OS: ${OS}";
echo "OS_VERSION: ${OS_VERSION}";
echo "OS_NAME: ${OS_NAME}";
echo "MACH: ${MACH}";

echo "################################################";
echo;
guess_plugin(){
  get_os;
  #OS_Name
  PLUGIN_OS_NAME=`echo ${OS_NAME} | tr '[:upper:]' '[:lower:]'`;
#  echo ${PLUGIN_OS_NAME};

  #OS Major Version
	PLUGIN_OS_VERSION=`echo ${OS_VERSION} | grep -o -e '^[0-9]*'`;
#  echo ${PLUGIN_OS_VERSION};

  #OS Architecture
	PLUGIN_OS_ARCH=`echo ${MACH} | grep -o -e '[0-9][0-9]'`;
#  echo ${PLUGIN_OS_ARCH};

	PLUGIN_NAME="${PLUGIN_OS_NAME}_${PLUGIN_OS_VERSION}_x${PLUGIN_OS_ARCH}";
	echo ${PLUGIN_NAME};
	echo;
}

guess_plugin;


exit 0;
