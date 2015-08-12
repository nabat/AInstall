#!/bin/sh

#######################################################
#   This script test how here doc cat is working      #
#######################################################

cat << 'EOF' > radiusd
#!/bin/bash
#
# radiusd       This shell script takes care of starting and stopping
#               freeradius.
#
# chkconfig: - 58 74
# description: radiusd is service access provider Daemon. \

### BEGIN INIT INFO
# Provides: radiusd
# Should-Start: radiusd
# Should-Stop: radiusd
# Short-Description: start and stop radiusd
# Description: radiusd is access provider service Daemon.
### END INIT INFO

# Source function library.
. /etc/init.d/functions

prog=/usr/local/freeradius/sbin/radiusd
lockfile=/var/lock/subsys/$prog

start() {
        # Start daemons.
        echo -n $"Starting $prog: "
        daemon $prog $OPTIONS
        RETVAL=$?
        echo
        [ $RETVAL -eq 0 ] && touch $lockfile
        return $RETVAL
}
stop() {
        [ "$EUID" != "0" ] && exit 4
        echo -n $"Shutting down $prog: "
        killproc $prog
        RETVAL=$?
        echo
        [ $RETVAL -eq 0 ] && rm -f $lockfile
        return $RETVAL
}
# See how we were called.
case "$1" in
  start)
        start
        ;;
  stop)
        stop
        ;;
  status)
        status $prog
        ;;
  restart|force-reload)
        stop
        start
        ;;
  try-restart|condrestart)
        if status $prog > /dev/null; then
            stop
            start
        fi
        ;;
  reload)
        exit 3
        ;;
  *)
        echo $"Usage: $0 {start|stop|status|restart|try-restart|force-reload}"
        exit 2
esac

EOF

cat radiusd | grep 'start|stop|status|restart|try-restart|force-reload';