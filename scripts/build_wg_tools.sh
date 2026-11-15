#!/usr/bin/env bash
set -euo pipefail

SRC_DIR="${SRC_DIR:-$HOME/wg-project/opensource/wireguard-tools}"
REPO_URL="${REPO_URL:-https://git.zx2c4.com/wireguard-tools}"
PREFIX=/usr/local

usage() { echo "Dùng: $0 <deps|fetch|build|install|uninstall|verify>"; exit 1; }

case "${1:-}" in
  deps)
    sudo apt-get update -qq
    sudo apt-get install -y build-essential git pkg-config ;;
  fetch)
    mkdir -p "$(dirname "$SRC_DIR")"
    if [[ -d "$SRC_DIR/.git" ]]; then git -C "$SRC_DIR" status --short
    else git clone "$REPO_URL" "$SRC_DIR"; fi
    git -C "$SRC_DIR" log -1 --format='Commit: %h  %ad  %s' --date=short ;;
  build)
    (cd "$SRC_DIR/src" && make clean && make -j"$(nproc)")
    ls -l "$SRC_DIR/src/wg" ;;
  install)
    # Chỉ cài binary 'wg' vào /usr/local, không động tới wg-quick của hệ thống
    sudo make -C "$SRC_DIR/src" install PREFIX="$PREFIX" \
         WITH_WGQUICK=no WITH_SYSTEMDUNITS=no WITH_BASHCOMPLETION=no
    hash -r
    which -a wg ;;
  uninstall)
    sudo rm -f "$PREFIX/bin/wg" "$PREFIX/share/man/man8/wg.8"
    hash -r
    which -a wg ;;
  verify)
    echo "wg đang dùng : $(command -v wg)"
    wg --version
    file "$(command -v wg)" | cut -c1-120
    sha256sum /usr/bin/wg "$PREFIX/bin/wg" 2>/dev/null || true ;;
  *) usage ;;
esac
