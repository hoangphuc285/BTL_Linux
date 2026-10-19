#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
require_root
umask 077

NAME="${1:-}"
[[ "$NAME" =~ ^[a-zA-Z0-9_-]{1,32}$ ]] || { echo "Dùng: $0 <tên> [số_cuối_của_IP]"; exit 1; }
grep -q "^# BEGIN client $NAME$" "$WG_CONF" && { echo "Client '$NAME' đã tồn tại."; exit 1; }

# Chọn IP: do người dùng chỉ định hoặc tự lấy số trống đầu tiên từ .2
used=$(grep -oP "AllowedIPs = 10\.8\.0\.\K[0-9]+" "$WG_CONF" || true)
LAST="${2:-}"
if [[ -z "$LAST" ]]; then
  for i in $(seq 2 254); do
    grep -qx "$i" <<<"$used" || { LAST=$i; break; }
  done
fi
[[ -n "$LAST" ]] || { echo "Hết địa chỉ IP trống."; exit 1; }
grep -qx "$LAST" <<<"$used" && { echo "IP $VPN_NET.$LAST đã được dùng."; exit 1; }
IP="$VPN_NET.$LAST"

DIR="$WG_DIR/clients/$NAME"; mkdir -p "$DIR"; chmod 700 "$DIR"
wg genkey | tee "$DIR/private.key" | wg pubkey > "$DIR/public.key"
wg genpsk > "$DIR/preshared.key"

backup_conf
cat >> "$WG_CONF" <<EOF

# BEGIN client $NAME
[Peer]
PublicKey = $(cat "$DIR/public.key")
PresharedKey = $(cat "$DIR/preshared.key")
AllowedIPs = $IP/32
# END client $NAME
EOF

{
  echo "[Interface]"
  echo "Address = $IP/24"
  echo "PrivateKey = $(cat "$DIR/private.key")"
  [[ -n "$CLIENT_DNS" ]] && echo "DNS = $CLIENT_DNS"
  echo
  echo "[Peer]"
  echo "PublicKey = $(cat "$WG_DIR/server_public.key")"
  echo "PresharedKey = $(cat "$DIR/preshared.key")"
  echo "Endpoint = $SERVER_ENDPOINT:$SERVER_PORT"
  echo "AllowedIPs = $CLIENT_ALLOWED"
  echo "PersistentKeepalive = 25"
} > "$DIR/$NAME.conf"

apply_conf
echo "Đã tạo client '$NAME' ($IP). File cấu hình: $DIR/$NAME.conf"
command -v qrencode >/dev/null && qrencode -t ansiutf8 < "$DIR/$NAME.conf" || true
