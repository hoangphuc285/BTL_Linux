#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
require_root

echo "Dịch vụ    : $(systemctl is-active "wg-quick@$WG_IF")"
echo "IP forward : $(sysctl -n net.ipv4.ip_forward)"
ss -ulnH | grep -q ":$SERVER_PORT " && echo "Cổng nghe  : $SERVER_PORT/udp (OK)" || echo "Cổng nghe  : KHÔNG nghe trên $SERVER_PORT/udp"
echo "-----"
wg show "$WG_IF"
