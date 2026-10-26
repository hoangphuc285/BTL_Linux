#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
require_root

CONF=/etc/dnsmasq.d/vpn.conf
HOSTS_FILE=/etc/dnsmasq.vpn.hosts
DOMAIN=$(grep -oP '^domain=\K.*' "$CONF")

usage() {
  echo "Dùng: $0 <lệnh>"
  echo "  forwarder <ip>      đổi DNS chuyển tiếp"
  echo "  add <tên> <ip>      thêm bản ghi (tên không kèm .$DOMAIN)"
  echo "  del <tên>           xóa bản ghi"
  echo "  list                liệt kê bản ghi"
  echo "  cache <số>          đổi kích thước cache"
  exit 1
}

valid_ip()   { [[ "$1" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] && ! grep -qE '(^|\.)(25[6-9]|2[6-9][0-9]|[3-9][0-9]{2})(\.|$)' <<<"$1"; }
valid_name() { [[ "$1" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]; }

# Kiểm tra cấu hình, lỗi thì khôi phục từ backup
apply_dns() {
  if dnsmasq --test >/dev/null 2>&1; then
    systemctl restart dnsmasq && echo "Đã áp dụng."
  else
    echo "Cấu hình lỗi, khôi phục bản backup."
    cp -a "$1" "$2"; systemctl restart dnsmasq; exit 1
  fi
}

CMD="${1:-}"; shift || true
case "$CMD" in
  forwarder)
    valid_ip "${1:-}" || { echo "IP không hợp lệ."; exit 1; }
    B="/tmp/vpn.conf.bak.$(date +%s)"; cp -a "$CONF" "$B"
    sed -i "s/^server=.*/server=$1/" "$CONF"
    apply_dns "$B" "$CONF" ;;
  add)
    valid_name "${1:-}" && valid_ip "${2:-}" || { echo "Tên hoặc IP không hợp lệ."; exit 1; }
    grep -qiE "(^|[[:space:]])$1\.$DOMAIN([[:space:]]|$)" "$HOSTS_FILE" && { echo "Bản ghi '$1' đã tồn tại."; exit 1; }
    B="$HOSTS_FILE.bak.$(date +%s)"; cp -a "$HOSTS_FILE" "$B"
    echo "$2 $1.$DOMAIN" >> "$HOSTS_FILE"
    apply_dns "$B" "$HOSTS_FILE" ;;
  del)
    valid_name "${1:-}" || { echo "Tên không hợp lệ."; exit 1; }
    grep -qiE "(^|[[:space:]])$1\.$DOMAIN([[:space:]]|$)" "$HOSTS_FILE" || { echo "Không có bản ghi '$1'."; exit 1; }
    B="$HOSTS_FILE.bak.$(date +%s)"; cp -a "$HOSTS_FILE" "$B"
    sed -i -E "/(^|[[:space:]])$1\.$DOMAIN([[:space:]]|$)/d" "$HOSTS_FILE"
    apply_dns "$B" "$HOSTS_FILE" ;;
  list)  column -t "$HOSTS_FILE" ;;
  cache)
    [[ "${1:-}" =~ ^[0-9]+$ && $1 -le 10000 ]] || { echo "Cache phải là số từ 0 đến 10000."; exit 1; }
    B="/tmp/vpn.conf.bak.$(date +%s)"; cp -a "$CONF" "$B"
    sed -i "s/^cache-size=.*/cache-size=$1/" "$CONF"
    apply_dns "$B" "$CONF" ;;
  *) usage ;;
esac
