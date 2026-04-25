# Changelog

## [v1.0.0]

- 8 bundled animations, auto-imported when the library is empty
- Bind-mount overlay; recreates missing stock files when possible
- Bundled animation credits in `BootAnimations/ATTRIBUTION.md`
- Case-insensitive duplicate detection for library imports
- Display names with automatic `bootanimation` suffix stripping
- Import upload validation (safe filenames, zip magic bytes, duplicate check in WebUI)
- Install workaround for KernelSU Next `chown` errors on spaced filenames
- `LICENSE` included in release zip (MIT for module code)
- Overlay paths (alphabetical): `/product/media`, `/system/media`, `/system/product/media`
- Persistent library at `/data/adb/bootanimations` (survives module updates)
- Random boot animation on each reboot from your enabled library
- Strict WebUI toggle values (`0` = off, `1` = on)
- WebUI to disable, enable, import, remove, and restore defaults
- `uninstall.sh` unmounts overlays when the module is removed
