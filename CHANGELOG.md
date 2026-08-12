# Changelog

## [Unreleased]

- Import staging moved into the library at `.import/` from `/data/local/tmp`, which the shell user can write to
- Labels and filenames reject embedded newlines, which could forge module config entries
- Zip validation requires the full `PK\x03\x04` local file header, not a two-byte prefix
- Imports are capped at 64 MB
- Concurrent imports use isolated staging, so chunks can no longer interleave
- Boot clears any leftover import staging directory
- `uninstall.sh` also removes the import staging directory
- Overlay destinations defined once in `scripts/lib.sh`
- Release workflow passes context values through the environment instead of inlining `${{ }}` into shell
- CI workflow runs with least-privilege `contents: read` permissions

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
