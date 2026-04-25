#!/system/bin/sh
# KernelSU Next set_perm_recursive passes unquoted paths to chown and breaks on
# filenames with spaces. SKIPUNZIP skips that; we extract and chown -R ourselves.
# shellcheck disable=SC2034
SKIPUNZIP=1

ui_print "- Extracting module files"
unzip -o "$ZIPFILE" -x 'META-INF/*' -d "$MODPATH" >&2

ui_print "- Setting permissions"
chown -R 0:0 "$MODPATH"
find "$MODPATH" -type d -exec chmod 0755 {} +
find "$MODPATH" -type f -exec chmod 0644 {} +
if command -v chcon >/dev/null 2>&1; then
  chcon -R u:object_r:system_file:s0 "$MODPATH" 2>/dev/null
fi
