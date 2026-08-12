#!/system/bin/sh

MODDIR=${0%/*}
. "$MODDIR/scripts/lib.sh"

while IFS= read -r dest; do
  [ -n "$dest" ] || continue
  umount -l "$dest" 2>/dev/null
done <<EOF
$OVERLAY_DESTS
EOF

rm -f "$ANIM_DIR/.active/bootanimation.zip"
rm -rf "$UPLOAD_BASE"

exit 0
