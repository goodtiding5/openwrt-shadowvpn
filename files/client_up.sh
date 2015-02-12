#!/bin/sh

# This script will be executed when client is up.
# All key value pairs in ShadowVPN config file will be passed to this script
# as environment variables, except password.

SHADOW_SERVER=10.7.0.1
SHADOW_CLIENT=10.7.0.2
SHADOW_MASK=255.255.255.0

PID=$(cat $pidfile 2>/dev/null)
loger() {
	echo "$(date '+%c') up.$1 ShadowVPN[$PID] $2"
}

# Configure IP address and MTU of VPN interface
ifconfig $intf $SHADOW_CLIENT netmask $SHADOW_MASK
ifconfig $intf mtu $mtu

# Get original default device and gateway
device=$(ip route show 0/0 | grep via | awk '{ print $5 }')
gateway=$(ip route show 0/0 | grep via | awk '{ print $3 }')
loger info "The default gateway: via $gateway dev $device"

# Get uci setting for routing mode and definition file
route_mode=$(uci get shadowvpn.@shadowvpn[-1].route_mode 2>/dev/null)
route_file=$(uci get shadowvpn.@shadowvpn[-1].route_file 2>/dev/null)

# Turn on NAT over VPN
iptables -t nat -A POSTROUTING -o $intf -j MASQUERADE
iptables -I FORWARD 1 -o $intf -j ACCEPT
iptables -I FORWARD 1 -i $intf -j ACCEPT
loger notice "Turn on NAT over $intf"

# Change routing table
ip route add $server via $gateway
if [ "$route_mode" != 2 ]; then
	ip route add 0.0.0.0/1 via $SHADOW_SERVER
	ip route add 128.0.0.0/1 via $SHADOW_SERVER
	loger notice "Default route changed to $SHADOW_SERVER"
	suf="via $gateway"
else
	suf="via $SHADOW_SERVER"
fi

# Load route rules
if [ "$route_mode" != 0 -a -f "$route_file" ]; then
	grep -E "^([0-9]{1,3}\.){3}[0-9]{1,3}" $route_file >/tmp/shadowvpn_routes
	sed -e "s/^/route add /" -e "s/$/ $suf/" /tmp/shadowvpn_routes | ip -batch -
	loger notice "Route rules have been loaded"
fi

loger info "Script $0 completed"
