#!/bin/sh
#/usr/bin/env bash

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

guess_pac_man;