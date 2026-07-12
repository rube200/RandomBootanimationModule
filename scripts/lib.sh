#!/system/bin/sh

ANIM_DIR=/data/adb/bootanimations
ANIM_META="$ANIM_DIR/.meta"
ACTIVE_ZIP="$ANIM_META/active/bootanimation.zip"
OVERLAY_DEV_PATHS="/product/media /system/media /system/product/media"
overlay_msg=

anim_ensure_dirs() {
  if ! mkdir -p "$ANIM_DIR" "$ANIM_META/disabled" "$ANIM_META/labels" "$ANIM_META/active"; then
    return 1
  fi
  chown -R 0:0 "$ANIM_DIR" 2>/dev/null
  chmod 0755 "$ANIM_DIR" 2>/dev/null
  chmod 0700 "$ANIM_META" 2>/dev/null
  for path in "$ANIM_DIR"/*.zip "$ANIM_DIR"/*.ZIP; do
    if [ -f "$path" ]; then
      chmod 0644 "$path" 2>/dev/null
    fi
  done
}

anim_valid() {
  case "$1" in
    *.zip | *.ZIP) ;;
    *) return 1 ;;
  esac
}

anim_safe_name() {
  case "$1" in
    */* | *..*) return 1 ;;
  esac
  anim_valid "$1"
}

anim_is_zip_file() {
  sig=$(head -c 2 "$1" 2>/dev/null)
  [ "$sig" = "PK" ]
}

anim_display_label() {
  text="$1"
  text=$(printf '%s' "$text" | sed \
    -e 's/\.[Zz][Ii][Pp]$//' \
    -e 's/[[:space:]_]*[Bb][Oo][Oo][Tt][Aa][Nn][Ii][Mm][Aa][Tt][Ii][Oo][Nn][Ss]*$//' \
    -e 's/[[:space:]]*$//' \
    -e 's/_/ /g')
  if [ -z "$text" ]; then
    printf '%s' "$1"
  else
    printf '%s' "$text"
  fi
}

anim_zip_paths() {
  if [ ! -d "$ANIM_DIR" ]; then
    return 0
  fi
  find "$ANIM_DIR" -maxdepth 1 -type f \( -name '*.zip' -o -name '*.ZIP' \) -print 2>/dev/null \
    | LC_ALL=C sort
}

anim_library_empty() {
  path=$(anim_zip_paths | head -1)
  [ -z "$path" ]
}

anim_require_zip() {
  name="$1"
  if [ -z "$name" ]; then
    return 1
  fi
  if ! anim_safe_name "$name"; then
    return 1
  fi
  if [ ! -f "$ANIM_DIR/$name" ]; then
    return 1
  fi
}

anim_name_taken() {
  name="$1"
  lower=$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')
  for path in "$ANIM_DIR"/*.zip "$ANIM_DIR"/*.ZIP; do
    if [ ! -f "$path" ]; then
      continue
    fi
    base=$(basename "$path")
    if [ "$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')" = "$lower" ]; then
      return 0
    fi
  done
  return 1
}

anim_enabled() {
  [ ! -f "$ANIM_META/disabled/$1" ]
}

anim_add() {
  src="$1"
  label="$2"
  name=$(basename "$src")
  if ! anim_safe_name "$name"; then
    printf 'Invalid filename: %s\n' "$name" >&2
    return 1
  fi
  if [ ! -f "$src" ]; then
    printf 'File not found: %s\n' "$src" >&2
    return 1
  fi
  if ! anim_is_zip_file "$src"; then
    printf 'Not a zip file: %s\n' "$name" >&2
    return 1
  fi
  if anim_name_taken "$name"; then
    printf 'Already in library: %s\n' "$name" >&2
    return 1
  fi
  if ! cp -af "$src" "$ANIM_DIR/$name"; then
    printf 'Failed to copy into library.\n' >&2
    return 1
  fi
  chmod 0644 "$ANIM_DIR/$name" 2>/dev/null
  if [ -n "$label" ]; then
    printf '%s' "$label" >"$ANIM_META/labels/$name"
  fi
  printf '%s' "$name"
}

seed_bundled() {
  find "$MODDIR/BootAnimations" -maxdepth 1 -type f \( -name '*.zip' -o -name '*.ZIP' \) -print 2>/dev/null \
    | LC_ALL=C sort \
    | while IFS= read -r src; do
    if [ -z "$src" ]; then
      continue
    fi
    base=$(basename "$src")
    if [ -f "$ANIM_DIR/$base" ]; then
      rm -f "$ANIM_META/disabled/$base"
      continue
    fi
    anim_add "$src" "$(anim_display_label "$base")" >/dev/null
  done
}

anim_enabled_paths() {
  while IFS= read -r path; do
    if [ -z "$path" ]; then
      continue
    fi
    if anim_enabled "$(basename "$path")"; then
      printf '%s\n' "$path"
    fi
  done <<EOF
$(anim_zip_paths)
EOF
}

_overlay_selinux() {
  zip=$1
  ctx=
  for dev in $OVERLAY_DEV_PATHS; do
    ref="$dev/bootanimation.zip"
    if [ -f "$ref" ]; then
      line=$(ls -Z "$ref" 2>/dev/null)
      ctx=${line%% *}
      if [ -n "$ctx" ]; then
        break
      fi
    fi
  done
  if [ -z "$ctx" ]; then
    ctx=u:object_r:system_file:s0
  fi
  chcon "$ctx" "$zip" 2>/dev/null
}

_overlay_is_mounted() {
  dest=$1
  while IFS= read -r line; do
    rest=${line#* }
    mp=${rest%% *}
    if [ "$mp" = "$dest" ]; then
      return 0
    fi
  done < /proc/mounts 2>/dev/null
  return 1
}

_overlay_remount_rw_for_path() {
  path=$1
  for mnt in /oem /product /system /system_ext /vendor; do
    case "$path" in
      "$mnt" | "$mnt"/*)
        mount -o remount,rw "$mnt" 2>/dev/null
        return 0
        ;;
    esac
  done
  return 1
}

_overlay_ensure_dest_file() {
  dest=$1

  if [ -f "$dest" ]; then
    return 0
  fi

  if [ -L "$dest" ]; then
    if [ ! -e "$dest" ]; then
      log -t RandomBootanimation "bind skip broken symlink: $dest" 2>/dev/null
      return 1
    fi
  fi

  if touch "$dest" 2>/dev/null; then
    log -t RandomBootanimation "created mount point: $dest" 2>/dev/null
    return 0
  fi

  log -t RandomBootanimation "touch failed, remounting rw for $dest" 2>/dev/null
  _overlay_remount_rw_for_path "$dest"
  if touch "$dest" 2>/dev/null; then
    log -t RandomBootanimation "created mount point after remount: $dest" 2>/dev/null
    return 0
  fi

  log -t RandomBootanimation "bind skip cannot create: $dest" 2>/dev/null
  return 1
}

_overlay_bind_dest() {
  dest=$1
  parent=${dest%/*}

  if [ ! -d "$parent" ]; then
    log -t RandomBootanimation "bind skip no parent: $parent" 2>/dev/null
    return 1
  fi

  if ! _overlay_ensure_dest_file "$dest"; then
    return 1
  fi

  if _overlay_is_mounted "$dest"; then
    umount "$dest" 2>/dev/null
  fi

  if mount -o bind "$ACTIVE_ZIP" "$dest" 2>/dev/null; then
    log -t RandomBootanimation "bind ok: $dest" 2>/dev/null
    return 0
  fi

  log -t RandomBootanimation "bind failed: $dest" 2>/dev/null
  return 1
}

overlay_clear() {
  for dev in $OVERLAY_DEV_PATHS; do
    dest="$dev/bootanimation.zip"
    if _overlay_is_mounted "$dest"; then
      umount "$dest" 2>/dev/null
    fi
  done
  rm -f "$ACTIVE_ZIP"
}

# overlay_msg is read by post-fs-data.sh after overlay_apply.
# shellcheck disable=SC2034
overlay_apply() {
  has_dev=
  for dev in $OVERLAY_DEV_PATHS; do
    if [ -d "$dev" ]; then
      has_dev=1
      break
    fi
  done
  if [ -z "$has_dev" ]; then
    overlay_msg="no bootanimation path on this device"
    overlay_clear
    return 1
  fi

  enabled=$(anim_enabled_paths)
  if [ -z "$enabled" ]; then
    overlay_clear
    overlay_msg="no enabled bootanimations"
    return 1
  fi

  count=0
  while IFS= read -r path; do
    if [ -z "$path" ]; then
      continue
    fi
    count=$((count + 1))
  done <<EOF
$enabled
EOF

  pick=$(od -An -N2 -tu2 /dev/urandom 2>/dev/null | tr -d ' ')
  if [ -z "$pick" ]; then
    pick=$(date +%s)
  fi
  want=$((pick % count + 1))

  selected=
  idx=0
  while IFS= read -r path; do
    if [ -z "$path" ]; then
      continue
    fi
    idx=$((idx + 1))
    if [ "$idx" -eq "$want" ]; then
      selected=$path
      break
    fi
  done <<EOF
$enabled
EOF

  if [ -z "$selected" ]; then
    overlay_msg="failed to pick bootanimation"
    return 1
  fi

  overlay_clear
  if ! cp -af "$selected" "$ACTIVE_ZIP"; then
    overlay_msg="failed to stage $(basename "$selected")"
    return 1
  fi
  chmod 0644 "$ACTIVE_ZIP" 2>/dev/null
  _overlay_selinux "$ACTIVE_ZIP"

  ok=0
  for dev in $OVERLAY_DEV_PATHS; do
    if [ ! -d "$dev" ]; then
      continue
    fi
    if _overlay_bind_dest "$dev/bootanimation.zip"; then
      ok=1
    fi
  done

  if [ "$ok" -eq 0 ]; then
    overlay_clear
    overlay_msg="failed to bind-mount $(basename "$selected")"
    return 1
  fi

  overlay_msg="selected: $(basename "$selected")"
  return 0
}
