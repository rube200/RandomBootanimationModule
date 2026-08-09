# Changelog

## [v1.1.1]

- HTML validation also flags external `<link>` (stylesheet/font), `<iframe>`, `<embed>`, and `<object>` references
- `MODDIR=` convention check now warns instead of fails, and covers `uninstall.sh` as well as `post-fs-data.sh`

## [v1.1.0]

- Bind overlay skips missing stock paths (no longer remounts or creates them)
- Disabled state and display labels stored in KernelSU module config
- Install aborts if extract or chown fails
- Manager description shows last selected animation via temp override
- Module id derived as kebab-case of the repository name at release
- Staged active zip path moved to `.active/bootanimation.zip`
- Validation requires matching overlay paths and kebab-case module id

## [v1.0.1]

- Log tag renamed to `RandomBootanimation` (was `random-bootanimation`)
- Module display name updated to Random Bootanimation Module
- README and WebUI titles updated for the repo rename
- Repository renamed to `RandomBootanimationModule`

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
