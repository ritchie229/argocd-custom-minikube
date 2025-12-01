#!/bin/bash

read -p "Pls specify the ServiceName: " SERVICENAME
read -p "Pls specify the NameSpace: " NAMESPACE
read -p "Pls specify the a Port for external access: " EXT_PORT

PORT=$(kubectl get svc -n $NAMESPACE $SERVICENAME -o jsonpath='{.spec.ports[0].nodePort}')
CLUSTER_IP=$(minikube ip --profile minihelm)

echo "===========REMOVING IP FORWARDING MAIN RULES==============="
iptables -t nat -D PREROUTING -p tcp --dport $EXT_PORT -j DNAT --to-destination $CLUSTER_IP:$PORT

echo "==============$CLUSTER_IP:$PORT CLOSED!!!=================="
iptables -t nat -L PREROUTING -n --line-numbers

