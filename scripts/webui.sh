#!/system/bin/sh

PATH=/sbin:/system/bin:/system/xbin:/vendor/bin:$PATH
export PATH

if ! cd "$(dirname "$0")/.."; then
  exit 1
fi
MODDIR=$(pwd)
. "$MODDIR/scripts/lib.sh"

UPLOAD_DIR=/data/local/tmp/random-bootanim-import

json_escape() {
  _tab=$(printf '\t')
  _nl=$(printf '\n')
  _cr=$(printf '\r')
  printf '%s' "$1" | sed \
    -e 's/\\/\\\\/g' \
    -e 's/"/\\"/g' \
    -e "s/${_tab}/\\\\t/g" \
    -e "s/${_nl}/\\\\n/g" \
    -e "s/${_cr}/\\\\r/g"
}

label_show() {
  name="$1"
  if [ -f "$ANIM_META/labels/$name" ]; then
    label=$(tr -d '\n' <"$ANIM_META/labels/$name")
    if [ -n "$label" ]; then
      printf '%s' "$label"
      return
    fi
  fi
  anim_display_label "$name"
}

import_anim() {
  src="$1"
  label="$2"
  if [ ! -f "$src" ]; then
    printf 'File not found: %s\n' "$src" >&2
    return 1
  fi
  if [ -n "$label" ]; then
    label=$(printf '%s' "$label" | sed 's/[[:space:]]*$//')
  fi
  if [ -z "$label" ]; then
    label=$(anim_display_label "$(basename "$src")")
  fi
  anim_add "$src" "$label" >/dev/null
}

remove_anim() {
  name="$1"
  if ! anim_require_zip "$name"; then
    return 1
  fi
  rm -f "$ANIM_DIR/$name" "$ANIM_META/disabled/$name" "$ANIM_META/labels/$name"
}

set_enabled() {
  name="$1"
  on="$2"
  if ! anim_require_zip "$name"; then
    return 1
  fi
  if [ "$on" = 1 ]; then
    rm -f "$ANIM_META/disabled/$name"
  elif [ "$on" = 0 ]; then
    touch "$ANIM_META/disabled/$name"
  else
    return 1
  fi
}

list_json() {
  anim_zip_paths | while IFS= read -r path; do
    if [ -z "$path" ]; then
      continue
    fi
    name=$(basename "$path")
    label=$(json_escape "$(label_show "$name")")
    file=$(json_escape "$name")
    on=0
    if anim_enabled "$name"; then
      on=1
    fi
    printf '{"file":"%s","label":"%s","on":%s}\n' "$file" "$label" "$on"
  done
}

b64_decode() {
  if base64 -d "$1" >"$2" 2>/dev/null; then
    return 0
  fi
  base64 --decode "$1" >"$2"
}

upload_abort() {
  rm -rf "$UPLOAD_DIR"
}

if ! anim_ensure_dirs; then
  exit 1
fi

case "$1" in
  import-upload)
    name="$2"
    label="$3"
    if ! anim_safe_name "$name"; then
      upload_abort
      printf 'Invalid upload name: %s\n' "$name" >&2
      exit 1
    fi
    staged="$UPLOAD_DIR/import.zip"
    b64="$UPLOAD_DIR/import.b64"
    if [ ! -f "$UPLOAD_DIR/.name" ]; then
      upload_abort
      printf 'Upload session mismatch.\n' >&2
      exit 1
    fi
    if [ "$(cat "$UPLOAD_DIR/.name")" != "$name" ]; then
      upload_abort
      printf 'Upload session mismatch.\n' >&2
      exit 1
    fi
    if [ ! -f "$b64" ]; then
      upload_abort
      printf 'Upload data missing.\n' >&2
      exit 1
    fi
    if ! b64_decode "$b64" "$staged"; then
      upload_abort
      printf 'Failed to decode uploaded file.\n' >&2
      exit 1
    fi
    library="$UPLOAD_DIR/$name"
    if ! cp -af "$staged" "$library"; then
      upload_abort
      printf 'Failed to stage uploaded file.\n' >&2
      exit 1
    fi
    if ! import_anim "$library" "$label"; then
      upload_abort
      exit 1
    fi
    upload_abort
    ;;
  list)
    if anim_library_empty; then
      if [ -d "$MODDIR/BootAnimations" ]; then
        seed_bundled
      fi
    fi
    list_json
    ;;
  remove)
    if ! remove_anim "$2"; then
      printf 'Animation not found: %s\n' "$2" >&2
      exit 1
    fi
    ;;
  seed)
    if [ ! -d "$MODDIR/BootAnimations" ]; then
      exit 1
    fi
    seed_bundled
    ;;
  toggle)
    if ! set_enabled "$2" "$3"; then
      printf 'Animation not found: %s\n' "$2" >&2
      exit 1
    fi
    ;;
  upload-append)
    chunk="$2"
    if [ -z "$chunk" ]; then
      printf 'Upload session not started.\n' >&2
      exit 1
    fi
    if [ ! -f "$UPLOAD_DIR/.name" ]; then
      printf 'Upload session not started.\n' >&2
      exit 1
    fi
    printf '%s' "$chunk" >>"$UPLOAD_DIR/import.b64"
    ;;
  upload-reset)
    name="$2"
    if ! anim_safe_name "$name"; then
      printf 'Invalid upload name: %s\n' "$name" >&2
      exit 1
    fi
    upload_abort
    if ! mkdir -p "$UPLOAD_DIR"; then
      exit 1
    fi
    if ! printf '%s' "$name" >"$UPLOAD_DIR/.name"; then
      exit 1
    fi
    ;;
  *)
    exit 1
    ;;
esac
