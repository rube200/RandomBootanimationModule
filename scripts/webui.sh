#!/system/bin/sh

PATH=/sbin:/system/bin:/system/xbin:/vendor/bin:$PATH
export PATH

MODDIR=${0%/*}/..
. "$MODDIR/scripts/lib.sh"
ksu_ensure_module_id || exit 1

MAX_UPLOAD_BYTES=$((64 * 1024 * 1024))
MAX_UPLOAD_B64_BYTES=$((MAX_UPLOAD_BYTES / 3 * 4))

b64_decode() {
  if base64 -d "$1" >"$2" 2>/dev/null; then
    return 0
  fi
  base64 --decode "$1" >"$2"
}

import_anim() {
  src="$1"
  label="$2"
  if [ -n "$label" ]; then
    label=$(printf '%s' "$label" | sed 's/[[:space:]]*$//')
  fi
  if [ -z "$label" ]; then
    label=$(anim_display_label "$(basename "$src")")
  fi
  anim_add "$src" "$label"
}

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

list_json() {
  anim_zip_paths | while IFS= read -r path; do
    if [ -z "$path" ]; then
      continue
    fi
    name=$(basename "$path")
    label=$(json_escape "$(anim_label_show "$name")")
    file=$(json_escape "$name")
    on=0
    if anim_enabled "$name"; then
      on=1
    fi
    printf '{"file":"%s","label":"%s","on":%s}\n' "$file" "$label" "$on"
  done
}

remove_anim() {
  name="$1"
  if ! anim_require_zip "$name"; then
    return 1
  fi
  rm -f "$ANIM_DIR/$name"
  anim_disabled_remove "$name"
  anim_label_set "$name" ""
}

set_enabled() {
  name="$1"
  on="$2"
  if ! anim_require_zip "$name"; then
    return 1
  fi
  if [ "$on" = 1 ]; then
    anim_disabled_remove "$name"
  elif [ "$on" = 0 ]; then
    anim_disabled_add "$name"
  else
    return 1
  fi
}

upload_session_dir() {
  token="$1"
  if [ "${#token}" -ne 32 ]; then
    return 1
  fi
  case "$token" in
    *[!0-9a-f]*) return 1 ;;
  esac
  printf '%s/%s' "$UPLOAD_BASE" "$token"
}

upload_abort() {
  if [ -n "$1" ]; then
    rm -rf "$1"
  fi
}

upload_base_ensure() {
  if [ -L "$UPLOAD_BASE" ] || { [ -e "$UPLOAD_BASE" ] && [ ! -d "$UPLOAD_BASE" ]; }; then
    if ! rm -rf "$UPLOAD_BASE"; then
      return 1
    fi
  fi
  if ! mkdir -p "$UPLOAD_BASE"; then
    return 1
  fi
  chmod 0700 "$UPLOAD_BASE" 2>/dev/null
}

if ! anim_ensure_dirs; then
  exit 1
fi

case "$1" in
  import-upload)
    token="$2"
    name="$3"
    label="$4"
    if ! dir=$(upload_session_dir "$token"); then
      printf 'Invalid upload session.\n' >&2
      exit 1
    fi
    if ! anim_safe_name "$name"; then
      upload_abort "$dir"
      printf 'Invalid upload name: %s\n' "$name" >&2
      exit 1
    fi
    staged="$dir/import.zip"
    b64="$dir/import.b64"
    if [ ! -f "$dir/.name" ]; then
      upload_abort "$dir"
      printf 'Upload session mismatch.\n' >&2
      exit 1
    fi
    if [ "$(cat "$dir/.name")" != "$name" ]; then
      upload_abort "$dir"
      printf 'Upload session mismatch.\n' >&2
      exit 1
    fi
    if [ ! -f "$b64" ]; then
      upload_abort "$dir"
      printf 'Upload data missing.\n' >&2
      exit 1
    fi
    if ! b64_decode "$b64" "$staged"; then
      upload_abort "$dir"
      printf 'Failed to decode uploaded file.\n' >&2
      exit 1
    fi
    library="$dir/$name"
    if ! cp -af "$staged" "$library"; then
      upload_abort "$dir"
      printf 'Failed to stage uploaded file.\n' >&2
      exit 1
    fi
    if ! import_anim "$library" "$label"; then
      upload_abort "$dir"
      exit 1
    fi
    upload_abort "$dir"
    ;;
  list)
    if anim_library_empty; then
      if [ -d "$MODDIR/BootAnimations" ]; then
        anim_seed_bundled
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
    anim_seed_bundled
    ;;
  toggle)
    if ! set_enabled "$2" "$3"; then
      printf 'Animation not found: %s\n' "$2" >&2
      exit 1
    fi
    ;;
  upload-append)
    token="$2"
    chunk="$3"
    if ! dir=$(upload_session_dir "$token"); then
      printf 'Upload session not started.\n' >&2
      exit 1
    fi
    if [ -z "$chunk" ]; then
      printf 'Upload session not started.\n' >&2
      exit 1
    fi
    if [ ! -f "$dir/.name" ]; then
      printf 'Upload session not started.\n' >&2
      exit 1
    fi
    printf '%s' "$chunk" >>"$dir/import.b64"
    size=$(wc -c <"$dir/import.b64" 2>/dev/null || echo 0)
    if [ "$size" -gt "$MAX_UPLOAD_B64_BYTES" ]; then
      upload_abort "$dir"
      printf 'Upload too large.\n' >&2
      exit 1
    fi
    ;;
  upload-reset)
    token="$2"
    name="$3"
    if ! dir=$(upload_session_dir "$token"); then
      printf 'Invalid upload session.\n' >&2
      exit 1
    fi
    if ! anim_safe_name "$name"; then
      printf 'Invalid upload name: %s\n' "$name" >&2
      exit 1
    fi
    upload_abort "$dir"
    if ! upload_base_ensure; then
      exit 1
    fi
    if ! mkdir -p "$dir"; then
      exit 1
    fi
    chmod 0700 "$dir" 2>/dev/null
    if ! printf '%s' "$name" >"$dir/.name"; then
      exit 1
    fi
    ;;
  *)
    exit 1
    ;;
esac
