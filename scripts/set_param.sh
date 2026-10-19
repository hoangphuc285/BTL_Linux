#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
require_root

KEY="${1:-}"; VAL="${2:-}"
[[ -n "$KEY" && -n "$VAL" ]] || { echo "Dùng: $0 <port|mtu|endpoint|dns> <giá trị>"; exit 1; }

case "$KEY" in
  port)
    [[ "$VAL" =~ ^[0-9]+$ && $VAL -ge 1024 && $VAL -le 65535 ]] || { echo "Cổng phải từ 1024 đến 65535."; exit 1; }
    backup_conf
    sed -i "s/^ListenPort.*/ListenPort = $VAL/" "$WG_CONF"
    if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then
      ufw delete allow "$SERVER_PORT"/udp 2>/dev/null || true
      ufw allow "$VAL"/udp
    fi
    set_env SERVER_PORT "$VAL"
    systemctl restart "wg-quick@$WG_IF"
    echo "Đã đổi cổng sang $VAL. Hãy sửa Endpoint trong cấu hình các client hiện có." ;;
  mtu)
    [[ "$VAL" =~ ^[0-9]+$ && $VAL -ge 1280 && $VAL -le 1500 ]] || { echo "MTU phải từ 1280 đến 1500."; exit 1; }
    backup_conf
    if grep -q "^MTU" "$WG_CONF"; then sed -i "s/^MTU.*/MTU = $VAL/" "$WG_CONF"
    else sed -i "/^Address/a MTU = $VAL" "$WG_CONF"; fi
    systemctl restart "wg-quick@$WG_IF"
    echo "Đã đặt MTU = $VAL." ;;
  endpoint) set_env SERVER_ENDPOINT "$VAL"; echo "Client tạo MỚI sẽ dùng Endpoint $VAL." ;;
  dns)      set_env CLIENT_DNS "$VAL";      echo "Client tạo MỚI sẽ dùng DNS $VAL." ;;
  *) echo "Tham số không hợp lệ."; exit 1 ;;
esac
