#!/bin/bash
# -*-Shell-script-*-
#
#/**
# * Title    : multiple Memcached init script
# * Auther   : by Alex, Lee
# * Created  : 07-25-2018
# * Modified : 04-25-2019
# * E-mail   : cine0831@gmail.com
#**/
#
#set -e
#set -x

# Check that networking is up.
. /etc/sysconfig/network
  
if [ "$NETWORKING" = "no" ]
then
        exit 0
fi
  
usage() {
    echo "
Usage: ${0##*/} [options]
  
Examples:
    ${0##*/} {start|stop|restart|status} {11211|11212}
  
Description:
    type: memcached , TCP port: 11211
    type: memcached , TCP port: 11212
"
}
  
case "$2" in
    11211)
        # TCP 11211
        _PORT=11211
        _CACHESIZE=256
        ;;
  
    11212)
        # TCP 11212
        _PORT=11212
        _CACHESIZE=256
        ;;
    *)
        usage
        exit 1
        ;;
esac

# default memcached options 
_MEMCACHED="/home/memcached/bin/memcached"
_PID="/var/run/memcached/memcached_${_PORT}.pid"
_LOCK="/var/lock/subsys/memcached_${_PORT}"
_USER=memcached-s
_LISTEN=127.0.0.1
_MAXCONN=4096
_OPTIONS=""
_UDP=0
 
# custom memcached options
if [ -s /home/memcached/etc/memcached.conf ]; then
    . /home/memcached/etc/memcached.conf
fi

RETVAL=0
prog="memcached"
  
version () {
    if [ -f /usr/bin/lsb_release ]; then
        _ver=$(lsb_release -d | cut -d':' -f 2 | sed 's/^\s//g' | cut -d'(' -f 1 | cut -d'.' -f 1 | sed -e 's/^ *//g' -e 's/ *$//g')
    elif [ -f /etc/redhat-release ]; then
        _ver=$(cat /etc/redhat-release | cut -d'(' -f 1 | cut -d'.' -f 1 | sed -e 's/^ *//g' -e 's/ *$//g')
    fi

    # if CentOS 7
    if [ "CentOS Linux release 7" = "$_ver" ]; then
        echo ""
    else 
        # Source function library.
        . /etc/rc.d/init.d/functions
    fi
}

start () {
    echo -n $"Starting $prog: "
    if [ ! -d /var/run/memcached ]; then
        mkdir /var/run/memcached
    fi

    # insure that /var/run/memcached has proper permissions
    if [ "`stat -c %U /var/run/memcached`" != "$_USER" ]; then
        chown $_USER /var/run/memcached
    fi
  
    if [ "CentOS Linux release 7" = "$_ver" ]; then
        $_MEMCACHED -d -l $_LISTEN -p $_PORT -u $_USER -m $_CACHESIZE -c $_MAXCONN -P $_PID -U $_UDP $_OPTIONS
        echo "OK"
    else
        daemon $_MEMCACHED -d -l $_LISTEN -p $_PORT -u $_USER -m $_CACHESIZE -c $_MAXCONN -P $_PID -U $_UDP $_OPTIONS
    fi

    RETVAL=$?
    echo
    [ $RETVAL -eq 0 ] && touch ${_LOCK}
}
  
stop () {
    if [ ! -f $_PID ]; then
        exit 1
    fi
  
    echo -n $"Stopping $prog: "
    kill -9 `cat $_PID`
    echo "OK"

    RETVAL=$?
    echo
    if [ $RETVAL -eq 0 ]; then
        rm -f $_LOCK
        rm -f $_PID
    fi
}
  
restart () {
    stop
    start
}

status () {
    local i=$1
    local j=$2

    _process=$(ps aux | grep ${i} | grep ${j} | egrep -v 'bash|grep|/bin/sh' | awk '{print $2}')
    if [ -z "$_process" ]; then
        echo "memcached is not running..."
    else 
        echo "memcached (pid ${_process}) is running..."   
    fi
}
  
# See how we were called.
case "$1" in
    start)
        version
        start
        ;;
    stop)
        version
        stop
        ;;
    status)
        status "memcached" "$2"
        ;;
    restart)
        version
        restart
        ;;
    *)
        usage
        exit 1
esac
  
exit $?
