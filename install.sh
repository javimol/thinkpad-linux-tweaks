#!/bin/bash
# install.sh: install selected tools from this repo.
#
# Usage: sudo ./install.sh <tool>...   (e.g. sudo ./install.sh gpu-toggle)
#        ./install.sh --list

set -euo pipefail

REPO_DIR=$(cd "$(dirname "$0")" && pwd)
PREFIX=${PREFIX:-/usr/local}

TOOLS="gpu-toggle gpu-toggle-auto fingerprint-lid shortcut-check"

install_gpu_toggle() {
  install -Dm755 "$REPO_DIR/generic/gpu-toggle" "$PREFIX/bin/gpu-toggle"
  echo "Installed $PREFIX/bin/gpu-toggle"
  if [ -d /etc/tlp.d ]; then
    install_gpu_toggle_tlp
  fi
}

# Boot service: pick intel or on-demand from the connected monitors
install_gpu_toggle_auto() {
  install_gpu_toggle
  sed "s#/usr/local/bin/#$PREFIX/bin/#" "$REPO_DIR/generic/gpu-toggle-auto.service" \
    > /etc/systemd/system/gpu-toggle-auto.service
  systemctl daemon-reload
  systemctl enable gpu-toggle-auto.service
  echo "Installed and enabled gpu-toggle-auto.service (runs at next boot)"
}

# TLP keeps every PCI device powered while on AC (RUNTIME_PM_ON_AC=on), which
# stops the NVIDIA GPU from powering off in intel mode. Exempt the GPU's
# functions and its PCIe port.
install_gpu_toggle_tlp() {
  local d gpu addrs="" conf=/etc/tlp.d/50-gpu-toggle.conf
  for d in /sys/bus/pci/devices/*; do
    if [ "$(cat "$d/vendor")" = "0x10de" ] && [[ "$(cat "$d/class")" == 0x03* ]]; then
      gpu=$(readlink -f "$d")
      break
    fi
  done
  if [ -z "${gpu:-}" ]; then
    echo "No NVIDIA GPU found; skipping $conf"
    return 0
  fi
  for d in "${gpu%.*}".* "$(dirname "$gpu")"; do
    addrs="$addrs ${d##*/0000:}"
  done
  cat > "$conf" <<CONF
# Written by thinkpad-linux-tweaks install.sh (gpu-toggle).
# Let the NVIDIA GPU and its PCIe port power off even on AC.
RUNTIME_PM_ENABLE="${addrs# }"
CONF
  echo "Installed $conf (RUNTIME_PM_ENABLE=\"${addrs# }\")"
  tlp start >/dev/null 2>&1 || true
}

# PAM profile: skip the fingerprint reader while the lid is closed. Replaces
# the stock fprintd profile, which it conflicts with.
install_fingerprint_lid() {
  install -Dm755 "$REPO_DIR/generic/lid-open" "$PREFIX/libexec/lid-open"
  sed "s#/usr/local/libexec/#$PREFIX/libexec/#" "$REPO_DIR/generic/fingerprint-lid.pam-config" \
    > /usr/share/pam-configs/fingerprint-lid
  pam-auth-update --disable fprintd
  pam-auth-update --enable fingerprint-lid
  echo "Installed $PREFIX/libexec/lid-open and enabled the fingerprint-lid PAM profile"
}

install_shortcut_check() {
  install -Dm755 "$REPO_DIR/generic/shortcut-check" "$PREFIX/bin/shortcut-check"
  echo "Installed $PREFIX/bin/shortcut-check (run it as your own user, not with sudo)"
}

if [ $# -eq 0 ] || [ "$1" = "--list" ]; then
  echo "Available tools: $TOOLS"
  echo "Usage: sudo $0 <tool>..."
  exit 0
fi

if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run with sudo." >&2
  exit 1
fi

for tool in "$@"; do
  case "$tool" in
    gpu-toggle) install_gpu_toggle ;;
    gpu-toggle-auto) install_gpu_toggle_auto ;;
    fingerprint-lid) install_fingerprint_lid ;;
    shortcut-check) install_shortcut_check ;;
    *) echo "Unknown tool: $tool (available: $TOOLS)" >&2; exit 1 ;;
  esac
done
