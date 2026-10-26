#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
require_root

DROPIN=/etc/ssh/sshd_config.d/10-hardening.conf
MGMT_NET="${MGMT_NET:-192.168.56.0/24}"
USER_NAME="${SUDO_USER:-root}"
USER_HOME=$(getent passwd "$USER_NAME" | cut -d: -f6)

usage() {
  echo "Dùng: $0 <lệnh>"
  echo "  init                    áp dụng cấu hình bảo mật cơ bản"
  echo "  port <số>               đổi cổng SSH"
  echo "  rootlogin <yes|no>      cho/không cho root đăng nhập"
  echo "  password <yes|no>       cho/không cho đăng nhập bằng mật khẩu"
  echo "  maxtries <số>           số lần thử mật khẩu tối đa"
  echo "  show                    hiển thị cấu hình đang hiệu lực"
  exit 1
}

# Đặt/sửa một chỉ thị trong file drop-in
set_directive() {
  touch "$DROPIN"
  if grep -qE "^$1 " "$DROPIN"; then sed -i "s|^$1 .*|$1 $2|" "$DROPIN"
  else echo "$1 $2" >> "$DROPIN"; fi
}

# Kiểm tra cú pháp rồi mới nạp lại; lỗi thì khôi phục
apply_ssh() {
  if sshd -t; then
    systemctl reload ssh && echo "Đã áp dụng. Hãy mở PHIÊN MỚI để thử trước khi đóng phiên cũ."
  else
    echo "Cấu hình lỗi, khôi phục backup."
    cp -a "$1" "$DROPIN"; exit 1
  fi
}

backup() { touch "$DROPIN"; BK="$DROPIN.bak.$(date +%s)"; cp -a "$DROPIN" "$BK"; }

CMD="${1:-}"; shift || true
case "$CMD" in
  init)
    backup
    set_directive PermitRootLogin no
    set_directive MaxAuthTries 3
    set_directive LoginGraceTime 30
    set_directive X11Forwarding no
    set_directive ClientAliveInterval 300
    set_directive ClientAliveCountMax 2
    apply_ssh "$BK" ;;
  rootlogin)
    [[ "${1:-}" =~ ^(yes|no)$ ]] || usage
    backup; set_directive PermitRootLogin "$1"; apply_ssh "$BK" ;;
  maxtries)
    [[ "${1:-}" =~ ^[1-9]$ ]] || { echo "Chọn số từ 1 đến 9."; exit 1; }
    backup; set_directive MaxAuthTries "$1"; apply_ssh "$BK" ;;
  password)
    [[ "${1:-}" =~ ^(yes|no)$ ]] || usage
    if [[ "$1" == "no" ]]; then
      [[ -s "$USER_HOME/.ssh/authorized_keys" ]] || {
        echo "TỪ CHỐI: $USER_NAME chưa có ~/.ssh/authorized_keys. Tắt mật khẩu bây giờ sẽ tự khóa bạn."; exit 1; }
    fi
    backup
    set_directive PasswordAuthentication "$1"
    set_directive KbdInteractiveAuthentication "$1"
    apply_ssh "$BK" ;;
  port)
    [[ "${1:-}" =~ ^[0-9]+$ && $1 -ge 22 && $1 -le 65535 ]] || { echo "Cổng phải từ 22 đến 65535."; exit 1; }
    OLD=$(sshd -T | awk '$1=="port"{print $2; exit}')
    backup; set_directive Port "$1"
    # Ubuntu có thể chạy SSH theo socket activation: khi đó cổng nằm ở ssh.socket
    if systemctl is-enabled --quiet ssh.socket 2>/dev/null; then
      mkdir -p /etc/systemd/system/ssh.socket.d
      printf '[Socket]\nListenStream=\nListenStream=%s\n' "$1" > /etc/systemd/system/ssh.socket.d/port.conf
      sshd -t || { cp -a "$BK" "$DROPIN"; exit 1; }
      systemctl daemon-reload && systemctl restart ssh.socket
    else
      apply_ssh "$BK"
    fi
    if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then
      ufw limit from "$MGMT_NET" to any port "$1" proto tcp
      ufw delete limit from "$MGMT_NET" to any port "$OLD" proto tcp 2>/dev/null || true
    fi
    echo "SSH nay nghe cổng $1. Thử: ssh -p $1 $USER_NAME@192.168.56.10" ;;
  show) sshd -T | grep -Ei '^(port|permitrootlogin|passwordauthentication|maxauthtries|logingracetime|x11forwarding|clientalive)' ;;
  *) usage ;;
esac
