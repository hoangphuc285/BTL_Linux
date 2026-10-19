#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
require_root
umask 077

apt-get update -qq
apt-get install -y wireguard-tools qrencode

echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-wg.conf
sysctl --system > /dev/null

mkdir -p "$WG_DIR/clients"
cd "$WG_DIR"
[[ -f server_private.key ]] || { wg genkey | tee server_private.key | wg pubkey > server_public.key; }

WAN_IF=$(ip -4 route show default | awk '{print $5; exit}')

if [[ ! -f "$WG_CONF" ]]; then
  cat > "$WG_CONF" <<EOF
[Interface]
Address = $VPN_NET.1/24
ListenPort = $SERVER_PORT
PrivateKey = $(cat server_private.key)
PostUp   = iptables -t nat -A POSTROUTING -s $VPN_NET.0/24 -o $WAN_IF -j MASQUERADE
PostDown = iptables -t nat -D POSTROUTING -s $VPN_NET.0/24 -o $WAN_IF -j MASQUERADE
EOF
fi

[[ -f "$ENV_FILE" ]] || {
  set_env SERVER_ENDPOINT "$SERVER_ENDPOINT"
  set_env SERVER_PORT "$SERVER_PORT"
  set_env CLIENT_ALLOWED "$CLIENT_ALLOWED"
}

if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then
  ufw allow "$SERVER_PORT"/udp
fi

systemctl enable --now "wg-quick@$WG_IF"
echo "Xong. Giao diện $WG_IF đang chạy, cổng $SERVER_PORT/udp."
