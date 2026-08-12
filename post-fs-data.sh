#!/system/bin/sh

MODDIR=${0%/*}
. "$MODDIR/scripts/lib.sh"
ksu_ensure_module_id || exit 0

ACTIVE="$ANIM_DIR/.active/bootanimation.zip"

rm -rf "$UPLOAD_BASE"

overlay_apply() {
  src="$1"
  if ! mkdir -p "$(dirname "$ACTIVE")"; then
    return 1
  fi
  if ! cp -af "$src" "$ACTIVE"; then
    return 1
  fi
  chmod 0644 "$ACTIVE" 2>/dev/null
  if command -v chcon >/dev/null 2>&1; then
    chcon u:object_r:system_file:s0 "$ACTIVE" 2>/dev/null
  fi

  ok=0
  while IFS= read -r dest; do
    [ -n "$dest" ] || continue
    if [ -L "$dest" ] && [ ! -e "$dest" ]; then
      log -t RandomBootanimation "bind skip: $dest (broken symlink)"
      continue
    fi
    if [ ! -f "$dest" ]; then
      log -t RandomBootanimation "bind skip: $dest (missing)"
      continue
    fi
    umount -l "$dest" 2>/dev/null
    if mount -o bind "$ACTIVE" "$dest" 2>/dev/null; then
      ok=1
      log -t RandomBootanimation "bind ok: $dest"
    else
      log -t RandomBootanimation "bind failed: $dest"
    fi
  done <<EOF
$OVERLAY_DESTS
EOF
  [ "$ok" -eq 1 ]
}

overlay_clear() {
  while IFS= read -r dest; do
    [ -n "$dest" ] || continue
    umount -l "$dest" 2>/dev/null
  done <<EOF
$OVERLAY_DESTS
EOF
  rm -f "$ACTIVE"
}

if ! anim_ensure_dirs; then
  log -t RandomBootanimation "failed to prepare $ANIM_DIR"
  overlay_clear
  exit 0
fi

if anim_library_empty; then
  if [ -d "$MODDIR/BootAnimations" ]; then
    anim_seed_bundled
  fi
fi

enabled=
count=0
while IFS= read -r path; do
  if [ -z "$path" ]; then
    continue
  fi
  if ! anim_enabled "$(basename "$path")"; then
    continue
  fi
  count=$((count + 1))
  if [ -n "$enabled" ]; then
    enabled=$(printf '%s\n%s' "$enabled" "$path")
  else
    enabled=$path
  fi
done <<EOF
$(anim_zip_paths)
EOF

if [ "$count" -eq 0 ]; then
  overlay_clear
  ksu_cfg_set_temp override.description "No animations enabled"
  log -t RandomBootanimation "no enabled bootanimations"
  exit 0
fi

pick=$(od -An -N2 -tu2 /dev/urandom 2>/dev/null | tr -d ' ')
if [ -z "$pick" ]; then
  pick=$(date +%s)
fi
n=$((pick % count + 1))

i=0
selected=
while IFS= read -r path; do
  if [ -z "$path" ]; then
    continue
  fi
  i=$((i + 1))
  if [ "$i" -eq "$n" ]; then
    selected=$path
    break
  fi
done <<EOF
$enabled
EOF

overlay_clear
if [ -z "$selected" ] || ! overlay_apply "$selected"; then
  ksu_cfg_set_temp override.description "Bind failed"
  log -t RandomBootanimation "failed to bind $(basename "${selected:-unknown}")"
  exit 0
fi

label=$(anim_label_show "$(basename "$selected")")
ksu_cfg_set_temp override.description "Random from $count enabled · last: $label"
log -t RandomBootanimation "selected: $(basename "$selected")"
exit 0
