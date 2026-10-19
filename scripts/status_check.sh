#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
require_root

echo "Dịch vụ    : $(systemctl is-active "wg-quick@$WG_IF")"
echo "IP forward : $(sysctl -n net.ipv4.ip_forward)"
echo "Cổng nghe  : $(ss -ulnH | grep -c ":$SERVER_PORT ") (1 = đang nghe)"
echo "-----"
wg show "$WG_IF"
