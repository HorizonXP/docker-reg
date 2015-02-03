#!/bin/bash

NUM_ARGS=$#
ARGS=$@
VALID=$(( (($NUM_ARGS-1)) % 3))
EXIT_CODE=0

if [ -z "$ETCD_PORT_10000_TCP_ADDR" ] && [ -z "$ETCD_PORT_10000_TCP_PORT" ]; then
    CTL="etcdctl -C http://${COREOS_PRIVATE_IPV4}:4001"
else
    CTL="etcdctl -C http://${ETCD_PORT_10000_TCP_ADDR}:${ETCD_PORT_10000_TCP_PORT}"
fi

if [ $VALID -eq 0 ]; then
    j=0
    PREFIX=$1
    TRAP_CMD=""
    for (( i=1; i<$NUM_ARGS; i+=3 ))
    do
        MACH[j]=$((i+1))
        PORT[j]=$((i+2))
        SERV[j]=$((i+3))
        MACH[j]=${!MACH[j]}
        PORT[j]=${!PORT[j]}
        SERV[j]=${!SERV[j]}

        IP_PORT[j]=$(/usr/bin/docker port ${MACH[j]} ${PORT[j]})
        IP[j]=$(echo ${IP_PORT[j]} | awk -F':' '{print $1}')
        PORT[j]=$(echo ${IP_PORT[j]} | awk -F':' '{print $2}')
        MACH[j]=$(echo ${MACH[j]} | sed ':l s/\./_/;tl')

        KEY_IP_PORT[j]="$1/${SERV[j]}/ip_port/${MACH[j]}"
        KEY_IP[j]="$1/${SERV[j]}/ip/${MACH[j]}"
        KEY_PORT[j]="$1/${SERV[j]}/port/${MACH[j]}"
        TRAP_CMD="$TRAPCMD $CTL rm ${KEY_IP_PORT[j]}; $CTL rm ${KEY_IP[j]}; $CTL rm ${KEY_PORT[j]};"

        j=$((j+1))
    done
    echo "${KEY_IP_PORT[@]}, ${KEY_IP[@]}, ${KEY_PORT[@]}, $TRAP_CMD"

    trap "$TRAPCMD exit" SIGHUP SIGINT SIGTERM
    while [ 1 ]; do
        for (( i=0; i<j; i++ ))
        do
            $CTL --debug set "${KEY_IP_PORT[i]}" "${IP_PORT[i]}" --ttl 5
            $CTL --debug set "${KEY_IP[i]}" "${IP[i]}" --ttl 5
            $CTL --debug set "${KEY_PORT[i]}" "${PORT[i]}" --ttl 5
        done
      sleep 1
    done
else
    echo "Invalid number of arguments. Needs to be a multiple of 3 + 1, where the first argument is the prefix, and then every 3 arguments after are to define the unit file, the port, and the service name."
    EXIT_CODE=1
fi
exit $EXIT_CODE
