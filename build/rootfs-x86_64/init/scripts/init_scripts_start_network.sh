#!/bin/sh
# Basic network bring-up (example)
# Assumes busybox/ip is available
set -e
IFACE=${IFACE:-eth0}
echo "Bringing up $IFACE"
ip link set "$IFACE" up
udhcpc -i "$IFACE" -q || dhclient "$IFACE" || true
echo "Network started"