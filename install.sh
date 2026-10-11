#!/bin/bash
# install.sh: install selected tools from this repo.
#
# Usage: sudo ./install.sh <tool>...   (e.g. sudo ./install.sh gpu-toggle)
#        ./install.sh --list

set -euo pipefail

REPO_DIR=$(cd "$(dirname "$0")" && pwd)
PREFIX=${PREFIX:-/usr/local}

TOOLS="gpu-toggle"

install_gpu_toggle() {
  install -Dm755 "$REPO_DIR/generic/gpu-toggle" "$PREFIX/bin/gpu-toggle"
  echo "Installed $PREFIX/bin/gpu-toggle"
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
    *) echo "Unknown tool: $tool (available: $TOOLS)" >&2; exit 1 ;;
  esac
done
