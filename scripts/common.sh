#!/usr/bin/env bash
set -euo pipefail

WG_IF="${WG_IF:-wg0}"
WG_DIR=/etc/wireguard
WG_CONF="$WG_DIR/$WG_IF.conf"
ENV_FILE="$WG_DIR/server.env"
VPN_NET="10.8.0"

# Giá trị mặc định, có thể bị ghi đè bởi server.env
SERVER_ENDPOINT="192.168.56.10"
SERVER_PORT="51820"
CLIENT_DNS=""
CLIENT_ALLOWED="10.8.0.0/24"
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

require_root() { [[ $EUID -eq 0 ]] || { echo "Hãy chạy bằng sudo." >&2; exit 1; }; }
backup_conf()  { cp -a "$WG_CONF" "$WG_CONF.bak.$(date +%Y%m%d-%H%M%S)"; }
apply_conf()   { wg syncconf "$WG_IF" <(wg-quick strip "$WG_IF"); }

set_env() {   # set_env KEY VALUE
  touch "$ENV_FILE"; chmod 600 "$ENV_FILE"
  if grep -q "^$1=" "$ENV_FILE"; then sed -i "s|^$1=.*|$1=\"$2\"|" "$ENV_FILE"
  else echo "$1=\"$2\"" >> "$ENV_FILE"; fi
}
