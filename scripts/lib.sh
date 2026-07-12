#!/system/bin/sh

ANIM_DIR=/data/adb/bootanimations

ksu_ensure_module_id() {
  if [ -z "${MODDIR:-}" ] || [ ! -f "$MODDIR/module.prop" ]; then
    return 1
  fi
  export MODDIR
  if [ -z "${KSU_MODULE:-}" ]; then
    KSU_MODULE=$(grep '^id=' "$MODDIR/module.prop" | head -1 | cut -d= -f2-)
    [ -n "$KSU_MODULE" ] || return 1
  fi
  export KSU_MODULE
  return 0
}

ksu_cfg_get() {
  ksu_ensure_module_id || return 1
  ksud module config get "$1" 2>/dev/null
}

ksu_cfg_set() {
  ksu_ensure_module_id || return 1
  printf '%s' "$2" | ksud module config set "$1" --stdin
}

ksu_cfg_set_temp() {
  ksu_ensure_module_id || return 1
  printf '%s' "$2" | ksud module config set "$1" --temp --stdin
}

ksu_cfg_delete() {
  ksu_ensure_module_id || return 1
  ksud module config delete "$1" 2>/dev/null
}

anim_ensure_dirs() {
  if ! mkdir -p "$ANIM_DIR"; then
    return 1
  fi
  chown -R 0:0 "$ANIM_DIR" 2>/dev/null
  chmod 0755 "$ANIM_DIR" 2>/dev/null
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    chmod 0644 "$path" 2>/dev/null
  done <<EOF
$(anim_zip_paths)
EOF
}

anim_safe_name() {
  case "$1" in
    */* | *..*) return 1 ;;
  esac
  case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
    *.zip) return 0 ;;
    *) return 1 ;;
  esac
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
  find "$ANIM_DIR" -maxdepth 1 -type f -iname '*.zip' -print 2>/dev/null \
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
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    base=$(basename "$path")
    if [ "$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')" = "$lower" ]; then
      return 0
    fi
  done <<EOF
$(anim_zip_paths)
EOF
  return 1
}

_cfg_disabled_list() {
  ksu_cfg_get library.disabled
}

_cfg_labels_list() {
  ksu_cfg_get library.labels
}

_cfg_set_disabled_list() {
  if [ -z "$1" ]; then
    ksu_cfg_delete library.disabled
    return
  fi
  ksu_cfg_set library.disabled "$1"
}

_cfg_set_labels_list() {
  if [ -z "$1" ]; then
    ksu_cfg_delete library.labels
    return
  fi
  ksu_cfg_set library.labels "$1"
}

anim_enabled() {
  name="$1"
  list=$(_cfg_disabled_list)
  if [ -z "$list" ]; then
    return 0
  fi
  if printf '%s\n' "$list" | grep -Fxq "$name"; then
    return 1
  fi
  return 0
}

anim_label_get() {
  name="$1"
  list=$(_cfg_labels_list)
  if [ -z "$list" ]; then
    return 1
  fi
  line=$(printf '%s\n' "$list" | while IFS= read -r _line; do
    case "$_line" in
      "$name"=*) printf '%s' "$_line"; break ;;
    esac
  done)
  if [ -z "$line" ]; then
    return 1
  fi
  printf '%s' "${line#"$name="}"
}

anim_label_show() {
  name="$1"
  label=$(anim_label_get "$name")
  if [ -n "$label" ]; then
    printf '%s' "$label"
    return
  fi
  anim_display_label "$name"
}

anim_label_set() {
  name="$1"
  label="$2"
  list=$(_cfg_labels_list)
  out=
  found=0
  if [ -n "$list" ]; then
    while IFS= read -r line; do
      if [ -z "$line" ]; then
        continue
      fi
      case "$line" in
        "$name"=*)
          found=1
          if [ -n "$label" ]; then
            if [ -n "$out" ]; then
              out=$(printf '%s\n%s=%s' "$out" "$name" "$label")
            else
              out=$(printf '%s=%s' "$name" "$label")
            fi
          fi
          ;;
        *)
          if [ -n "$out" ]; then
            out=$(printf '%s\n%s' "$out" "$line")
          else
            out=$line
          fi
          ;;
      esac
    done <<EOF
$list
EOF
  fi
  if [ "$found" -eq 0 ] && [ -n "$label" ]; then
    if [ -n "$out" ]; then
      out=$(printf '%s\n%s=%s' "$out" "$name" "$label")
    else
      out=$(printf '%s=%s' "$name" "$label")
    fi
  fi
  _cfg_set_labels_list "$out"
}

anim_disabled_add() {
  name="$1"
  list=$(_cfg_disabled_list)
  if [ -n "$list" ] && printf '%s\n' "$list" | grep -Fxq "$name"; then
    return 0
  fi
  if [ -n "$list" ]; then
    list=$(printf '%s\n%s' "$list" "$name")
  else
    list=$name
  fi
  _cfg_set_disabled_list "$list"
}

anim_disabled_remove() {
  name="$1"
  list=$(_cfg_disabled_list)
  if [ -z "$list" ]; then
    return 0
  fi
  out=
  while IFS= read -r line; do
    if [ -z "$line" ] || [ "$line" = "$name" ]; then
      continue
    fi
    if [ -n "$out" ]; then
      out=$(printf '%s\n%s' "$out" "$line")
    else
      out=$line
    fi
  done <<EOF
$list
EOF
  _cfg_set_disabled_list "$out"
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
    anim_label_set "$name" "$label"
  fi
}
