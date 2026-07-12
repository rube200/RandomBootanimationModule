#!/system/bin/sh

if ! cd "$(dirname "$0")"; then
  exit 0
fi
MODDIR=$(pwd)
. "$MODDIR/scripts/lib.sh"

if ! anim_ensure_dirs; then
  log -t RandomBootanimation "failed to prepare $ANIM_DIR"
  overlay_clear
  exit 0
fi

if anim_library_empty; then
  if [ -d "$MODDIR/BootAnimations" ]; then
    seed_bundled
    if ! anim_library_empty; then
      log -t RandomBootanimation "imported bundled default bootanimations"
    fi
  fi
fi

overlay_apply
log -t RandomBootanimation "$overlay_msg"
exit 0
