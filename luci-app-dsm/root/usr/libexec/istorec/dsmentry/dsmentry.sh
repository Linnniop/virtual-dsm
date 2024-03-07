#!/usr/bin/env bash

br=dsm-br
vnet1=dsm-int
vnet2=dsm-ext
curl -H "Content-Type: application/json" -X POST \
	-d '{"br":"'$br'","vnet1":"'$vnet1'","vnet2":"'$vnet2'"}' \
	--fail --max-time 15 --unix-socket /var/run/vmease/daemon.sock \
	"http://localhost/api/vmease/create-br/"

ip addr flush dev eth0
ip addr add $DSMIP/$DSMMASK dev eth0
ip route add default via $DSMGATEWAY dev eth0

bash /run/entry.sh

