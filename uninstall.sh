#!/system/bin/sh

if ! cd "$(dirname "$0")"; then
  exit 0
fi
MODDIR=$(pwd)
. "$MODDIR/scripts/lib.sh"

overlay_clear
log -t RandomBootanimation "uninstall: overlay cleared"
exit 0
