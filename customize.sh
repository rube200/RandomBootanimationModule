#!/system/bin/sh
# shellcheck disable=SC2034
SKIPUNZIP=1

ui_print "- Extracting module files"
if ! unzip -o "$ZIPFILE" -x 'META-INF/*' -d "$MODPATH" >&2; then
  abort "Failed to extract module files"
fi

ui_print "- Setting permissions"
if ! chown -R 0:0 "$MODPATH"; then
  abort "Failed to set module ownership"
fi

find "$MODPATH" -type d -exec chmod 0755 {} +
find "$MODPATH" -type f -exec chmod 0644 {} +
if command -v chcon >/dev/null 2>&1; then
  chcon -R u:object_r:system_file:s0 "$MODPATH" 2>/dev/null
fi
