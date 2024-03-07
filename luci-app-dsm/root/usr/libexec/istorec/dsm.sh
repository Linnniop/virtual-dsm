#!/bin/sh
# Author Xiaobao(xiaobao@linkease.com)

ACTION=${1}
shift 1

do_install() {
  local port=`uci get dsm.@main[0].port 2>/dev/null`
  local ip=`uci get dsm.@main[0].ip 2>/dev/null`
  local ipmask=`uci get dsm.@main[0].ipmask 2>/dev/null`
  local gateway=`uci get dsm.@main[0].gateway 2>/dev/null`
  local ramsize=`uci get dsm.@main[0].ramsize 2>/dev/null`
  local disksize=`uci get dsm.@main[0].disksize 2>/dev/null`
  local cpucore=`uci get dsm.@main[0].cpucore 2>/dev/null`
  local gpu=`uci get dsm.@main[0].gpu 2>/dev/null`
  local image_name=`uci get dsm.@main[0].image_name 2>/dev/null`
  local storage_path=`uci get dsm.@main[0].storage_path 2>/dev/null`

  if [ -z "$storage_path" ]; then
    echo "storage path is empty!"
    exit 1
  fi
  if [ -z "$ip" ]; then
    echo "ip is empty!"
    exit 1
  fi
  if [ ! -e "/dev/kvm" ]; then
    echo "/dev/kvm not found"
    exit 1
  fi
  [ -z "$port" ] && port="5000"
  [ -z "$ramsize" ] && ramsize="2G"
  [ -z "$disksize" ] && disksize="40G"
  [ -z "$cpucore" ] && cpucore="2"
  [ -z "$image_name" ] && image_name="vdsm/virtual-dsm"
  echo "docker pull ${image_name}"
  docker pull ${image_name}
  docker rm -f dsm

  if [ "$macvlan" = "1" ]; then
    local macvlan=`docker network inspect dsm-net -f '{{.Name}}'`
    if [ ! "$macvlan" = "dsm-net" ]; then
      #local lan_dev=`echo $lan_status|jsonfilter -e 'jsonfilter -e '@["device"]'`
      docker network create -d macvlan --subnet=$ipmask --gateway=$gateway -o parent=br-lan dsm-net
    fi
  fi

  local cmd="docker run --restart=unless-stopped -d -h SynologyDSMServer \
    -p $port:5000 \
    -v \"$storage_path:/storage\" \
    -e DISK_SIZE=$disksize \
    -e RAM_SIZE=$ramsize \
    -e CPU_CORES=$cpucore \
    --dns=223.5.5.5 \
    --device /dev/kvm \
    --cap-add NET_ADMIN "

  if [ "$gpu" = "1" ]; then
    if [ -d /dev/dri ]; then
      cmd="$cmd\
      -e GPU=Y --device /dev/dri:/dev/dri "
    fi
  fi

  if [ "$macvlan" = "1" ]; then
      cmd="$cmd\
        --net=dsm-net --ip=$ip "
  fi

  local tz="`uci get system.@system[0].zonename | sed 's/ /_/g'`"
  [ -z "$tz" ] || cmd="$cmd -e TZ=$tz"

  cmd="$cmd -v /mnt:/mnt"
  mountpoint -q /mnt && cmd="$cmd:rslave"
  cmd="$cmd --stop-timeout 120 --name dsm \"$image_name\""

  echo "$cmd"
  eval "$cmd"
}

usage() {
  echo "usage: $0 sub-command"
  echo "where sub-command is one of:"
  echo "      install                Install the dsm"
  echo "      upgrade                Upgrade the dsm"
  echo "      rm/start/stop/restart  Remove/Start/Stop/Restart the dsm"
  echo "      status_port_ip         SynologyDSM status"
}

case ${ACTION} in
  "install")
    do_install
  ;;
  "upgrade")
    do_install
  ;;
  "rm")
    docker rm -f dsm
  ;;
  "start" | "stop" | "restart")
    docker ${ACTION} dsm
  ;;
  "status")
    docker ps --all -f 'name=dsm' --format '{{.State}}'
  ;;
  "port")
    docker ps --all -f 'name=dsm' --format '{{.Ports}}' | grep -om1 '0.0.0.0:[0-9]*->5000/tcp' | sed 's/0.0.0.0:\([0-9]*\)->.*/\1/'
  ;;
  "status_port_ip")
    running=`docker ps --all -f 'name=dsm' --format '{{.State}}'`
    if [ -z "$running" ]; then
      running="not_install"
    fi
    port=`docker ps --all -f 'name=dsm' --format '{{.Ports}}' | grep -om1 '0.0.0.0:[0-9]*->5000/tcp' | sed 's/0.0.0.0:\([0-9]*\)->.*/\1/'`
    if [ -z "$port" ]; then
      port="5000"
    fi
    ip=`uci get dsm.@main[0].ip 2>/dev/null`
    if [ -z "$ip" ]; then
      ip="127.0.0.1"
    fi
    dockerid=`docker inspect --format="{{.Id}}" dsm`
    echo "$running $port $ip $dockerid"
  ;;
  *)
    usage
    exit 1
  ;;
esac
