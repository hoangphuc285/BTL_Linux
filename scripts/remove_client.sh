#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
require_root

NAME="${1:-}"
[[ "$NAME" =~ ^[a-zA-Z0-9_-]{1,32}$ ]] || { echo "Dùng: $0 <tên>"; exit 1; }
grep -q "^# BEGIN client $NAME$" "$WG_CONF" || { echo "Không tìm thấy client '$NAME'."; exit 1; }

backup_conf
sed -i "/^# BEGIN client $NAME\$/,/^# END client $NAME\$/d" "$WG_CONF"
rm -rf "$WG_DIR/clients/$NAME"
apply_conf
echo "Đã xóa client '$NAME'."
