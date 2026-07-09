#!/bin/bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "run as root: sudo ./install.sh <wireguard-iface> <path-to-wg-conf>" >&2
  exit 1
fi

IFACE="${1:?usage: install.sh <wireguard-iface> <path-to-wg-conf>}"
WG_CONF="${2:?usage: install.sh <wireguard-iface> <path-to-wg-conf>}"
TARGET_USER="${SUDO_USER:?run via sudo, not as root directly}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

command -v wg >/dev/null 2>&1 || echo "warning: 'wg' not found (wireguard-tools) — live endpoint tracking (issue #1 fix) needs it, falling back to hostname-only" >&2

ENDPOINT="$(grep -oP '^Endpoint\s*=\s*\K\S+' "$WG_CONF")"
[ -n "$ENDPOINT" ] || { echo "no Endpoint= line found in $WG_CONF" >&2; exit 1; }
ENDPOINT_HOST="${ENDPOINT%:*}"
ENDPOINT_PORT="${ENDPOINT##*:}"

install -d -m 755 /usr/local/libexec/gnome-vpn-killswitch
install -m 755 "$DIR/toggle" /usr/local/libexec/gnome-vpn-killswitch/toggle

install -d -m 755 /etc/gnome-vpn-killswitch
cat > /etc/gnome-vpn-killswitch/config <<EOF
VPN_IFACE=$IFACE
VPN_ENDPOINT_HOST=$ENDPOINT_HOST
VPN_ENDPOINT_PORT=$ENDPOINT_PORT
EOF
chmod 644 /etc/gnome-vpn-killswitch/config

install -m 644 "$DIR/com.github.sebischaefer.gnomevpnkillswitch.policy" \
  /usr/share/polkit-1/actions/com.github.sebischaefer.gnomevpnkillswitch.policy

sed "s/__USER__/$TARGET_USER/" "$DIR/49-gnome-vpn-killswitch.rules.template" \
  > /etc/polkit-1/rules.d/49-gnome-vpn-killswitch.rules
chmod 644 /etc/polkit-1/rules.d/49-gnome-vpn-killswitch.rules

install -d -m 755 /etc/NetworkManager/dispatcher.d
install -m 755 "$DIR/50-gnome-vpn-killswitch.dispatcher" \
  /etc/NetworkManager/dispatcher.d/50-gnome-vpn-killswitch
systemctl enable --now NetworkManager-dispatcher.service >/dev/null 2>&1 || true

echo "installed. try: pkexec /usr/local/libexec/gnome-vpn-killswitch/toggle on"
