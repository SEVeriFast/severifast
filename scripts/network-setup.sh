#!/bin/bash

NET_DEV="tap0"

HOST_IFACE=$(ip route | grep '^default' | awk '{ print $5 }')
MTU=$(ip addr | grep -m 1 eno8303 | awk '{ print $5 }')
sudo ip tuntap add ${NET_DEV} mode tap
sudo ip addr add 172.16.0.1/24 dev ${NET_DEV}
sudo ip link set ${NET_DEV} up
sudo ip link set dev ${NET_DEV} mtu ${MTU}
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward > /dev/null
sudo iptables -t nat -A POSTROUTING -o "$HOST_IFACE" -j MASQUERADE
sudo iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i ${NET_DEV} -o ${HOST_IFACE} -j ACCEPT

# set init for doing attestation
sudo nginx -s stop > /dev/null 2>&1
sudo nginx > /dev/null 2>&1

