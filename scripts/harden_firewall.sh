#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
require_root

WAN_IF=$(ip -4 route show default | awk '{print $5; exit}')
MGMT_NET="${MGMT_NET:-192.168.56.0/24}"   # mạng được phép SSH

apt-get install -y ufw

ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw default deny routed
ufw limit from "$MGMT_NET" to any port 22 proto tcp   # SSH chỉ từ mạng quản trị, có giới hạn thử mật khẩu
ufw allow "$SERVER_PORT"/udp                          # cổng WireGuard
ufw route allow in on "$WG_IF" out on "$WAN_IF"       # client ra Internet
ufw route allow in on "$WG_IF" out on "$WG_IF"        # client <-> client
ufw --force enable

systemctl restart "wg-quick@$WG_IF"                   # nạp lại NAT trong PostUp
ufw status verbose
