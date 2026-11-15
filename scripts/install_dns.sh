#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
require_root

DOMAIN="${DOMAIN:-vpn.lan}"
DNS_IP="$VPN_NET.1"
HOSTS_FILE=/etc/dnsmasq.vpn.hosts
CONF=/etc/dnsmasq.d/vpn.conf

apt-get update -qq
apt-get install -y dnsmasq dnsutils

# Cấu hình chính
cat > "$CONF" <<EOF
listen-address=$DNS_IP
bind-dynamic
no-resolv
server=1.1.1.1
domain=$DOMAIN
local=/$DOMAIN/
expand-hosts
addn-hosts=$HOSTS_FILE
cache-size=500
EOF

# File bản ghi nội bộ (không ghi đè nếu đã có)
if [[ ! -f "$HOSTS_FILE" ]]; then
  cat > "$HOSTS_FILE" <<EOF
$DNS_IP wg-server.$DOMAIN web.$DOMAIN
EOF
fi

# bind-dynamic: dnsmasq tự gắn vào 10.8.0.1 khi wg0 xuất hiện, nên không cần ràng buộc thứ tự với wg-quick

dnsmasq --test || { echo "Cấu hình dnsmasq lỗi."; exit 1; }

# Cho phép client VPN truy vấn DNS
if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then
  ufw allow in on "$WG_IF" to any port 53 proto udp
  ufw allow in on "$WG_IF" to any port 53 proto tcp
fi

set_env CLIENT_DNS "$DNS_IP"
systemctl enable dnsmasq
systemctl restart dnsmasq
echo "Xong. DNS nội bộ: $DNS_IP, miền: $DOMAIN"
