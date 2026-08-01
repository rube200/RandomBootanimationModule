# Random Bootanimation Module

A **[KernelSU Next](https://github.com/KernelSU-Next/KernelSU-Next)** module that picks a random boot animation on every reboot.

Your library lives at `/data/adb/bootanimations`, outside the module directory, so it survives module updates and OTAs. Eight animations are bundled with the module, and the **WebUI** in KernelSU Next Manager lets you manage them without touching files manually.

## Features

- **8 bundled animations** in `BootAnimations/`
- **Auto-import** when your library is empty (first boot after install)
- **Display names** — `bootanimation` suffixes are stripped in the UI (e.g. `My Theme bootanimation.zip` → **My Theme**)
- **Persistent storage** at `/data/adb/bootanimations` (filenames can include spaces)
- **Random selection** on each boot from animations you have enabled
- **Manager status** — module description shows how many are enabled and which one was last applied
- **WebUI** — disable, enable, import, remove, restore defaults

## Requirements

- **[KernelSU Next](https://github.com/KernelSU-Next/KernelSU-Next)** with a working module install
- **KernelSU Next Manager** (for the WebUI)
- A stock **`bootanimation.zip`** already present on your ROM at one of the overlay paths (see below). Missing destinations are skipped; the module does not create them.

## Installation

1. Download the latest release zip from [GitHub Releases](https://github.com/rube200/RandomBootanimationModule/releases).
2. Open **KernelSU Next Manager** → **Modules** → install the zip.
3. Reboot.

If `/data/adb/bootanimations` is empty on first boot, bundled animations are imported automatically.

Module updates do not touch your zip library. Reinstalling or updating keeps your animations. Enabled/disabled state and labels live in KernelSU module config and persist with the module (they are cleared if you uninstall).

## WebUI

1. Open **KernelSU Next Manager**.
2. Go to **Modules** → **Random Bootanimation Module**.
3. Tap **WebUI**.

| Action | What it does |
|--------|----------------|
| **Import** | Pick a zip from the device file picker and add it to your library |
| **Refresh** | Reload the library list (also happens when you return to the page) |
| **Remove** | Delete an animation from your library |
| **Restore defaults** | Re-import missing bundled animations and re-enable bundled ones you disabled |
| **Toggle** | Include or exclude an animation from random selection |

**Import fields**

- **Name** — optional display name. Leave empty to derive one from the filename.
- **Zip file** — tap **Choose file…** to open the system file picker, then **Confirm**.

Disabled animations stay on disk but are never picked at boot. If every animation is disabled, the module clears its overlay and the stock boot animation is used.

Toggle and import changes take effect on the next reboot.

## Manual import

Copy any `.zip` file into the library folder with a root file manager or `adb`:

```text
/data/adb/bootanimations/My Theme bootanimation.zip
/data/adb/bootanimations/Another Animation.zip
```

Files keep their original filename. Manually added zips default to **enabled** and show up in the WebUI when you open or refresh it.

## How it works

```text
Install
  └─ customize.sh (SKIPUNZIP=1)
       ├─ Extract module files (abort on failure)
       └─ chown -R + chmod on module tree
            (workaround for KernelSU Next spaced-filename install bug)

Boot
  └─ post-fs-data.sh
       ├─ Create /data/adb/bootanimations if needed
       ├─ Seed bundled defaults when library is empty
       ├─ Pick one random enabled zip (enabled state from module config)
       ├─ Stage to .active/bootanimation.zip, then bind-mount over each
            existing ROM path (must succeed on at least one; missing
            destinations and broken symlinks are skipped)
       └─ Update Manager description with last selection (temp override)
```

The WebUI calls `scripts/webui.sh`, which reads the library folder and KernelSU module config.

### Overlay paths

Checked in alphabetical order. On most devices only one path is used (e.g. `/product/media/bootanimation.zip` on recent Xiaomi / HyperOS).

| Path |
|------|
| `/product/media/bootanimation.zip` |
| `/system/media/bootanimation.zip` |
| `/system/product/media/bootanimation.zip` |

Bind-mount must succeed on at least one path. Missing files and broken symlinks are skipped.

### Storage layout

```text
/data/adb/bootanimations/
  .active/      staged bootanimation.zip used as bind-mount source
  *.zip         your boot animation files (any filename; spaces OK)
```

Enabled/disabled state and display labels are stored in KernelSU module config (`library.disabled`, `library.labels`), not as files under the library folder.

### Bundled animations

Eight defaults ship in `BootAnimations/` from [mauam's Bootanimations collection on XDA](https://xdaforums.com/t/bootanimations-collection.3721978). Names and credits are in `BootAnimations/ATTRIBUTION.md` inside the module zip.

## Troubleshooting

| Symptom | What to check |
|---------|----------------|
| Animation unchanged after reboot | Run `logcat -d -s RandomBootanimation` — look for `bind ok:` on your ROM path. If you see `bind skip:` (missing), restore or recreate stock `bootanimation.zip` (below). On some ROMs bootanim reads the file before `post-fs-data` runs; that timing limit cannot be fixed in-module |
| `chown: unknown user/group` during install | Old module zip without `customize.sh`. Install a current release |
| Custom animation after disabling the module | Reboot once. Disabled modules skip `post-fs-data.sh`, so no new bind is applied |
| Import fails | File must be a valid `.zip`; name must not already exist in the library (case-insensitive) |
| Stock boot animation after install | Open WebUI → confirm at least one animation is enabled → reboot. Manager description should show a last selection after a successful boot |
| Toggles/labels reset after update from v1.0.x | Enabled state and labels moved from `.meta/` files to KernelSU module config; re-apply toggles in the WebUI |
| WebUI list is empty after install | Tap **Refresh**, or leave and reopen WebUI |
| WebUI shows an error | Open the page from KernelSU Next Manager (not an external browser) |

**Recreate a missing stock `bootanimation.zip`**

The module will not create this file for you. If bind logs show `bind skip:` for every path, recreate the mount point manually:

```sh
mount -o remount,rw /product
touch /product/media/bootanimation.zip
# or copy a stock zip from firmware / another device
mount -o remount,ro /product
```

Use `/system` or `/system/product` instead of `/product` if that is where your ROM keeps the file. Then reboot.

**Disable and uninstall**

- **Disable** — Reboot. The module no longer runs at boot, so stock boot animation is used.
- **Uninstall** — `uninstall.sh` umounts any active bind mounts and removes `.active/`. Your zip library at `/data/adb/bootanimations` is not deleted. Module config (toggles and labels) is cleared with the module.

## Debugging

Boot-time logs (`post-fs-data.sh`):

```sh
logcat -d -s RandomBootanimation
```

Look for `bind ok:`, `bind failed:`, `bind skip:`, or `selected:` lines. Module hook failures do not block boot — if bind-mount fails, the device falls back to the stock boot animation.

## Building and validation

```sh
bash scripts/validate.sh
```

Requires `jq` and `shellcheck`. Checks required module files, `module.prop`, placeholder `update.json`, WebUI assets (no external URLs), UTF-8 without BOM, LF line endings, and alphabetical changelog bullets.

Release builds run on GitHub Actions when a `v*` tag is pushed. The workflow fills in `update.json`, sets `module.prop` `id` to the kebab-case form of the repository name (e.g. `RandomBootanimationModule` → `random-bootanimation-module`), ships `LICENSE` in the module zip, and publishes the release. Until then, `update.json` uses `versionCode: 0` as a template; CI ignores that file on push so bot bumps do not re-trigger validation.

## Project layout

```text
.editorconfig                   LF / UTF-8 / final newline defaults
.gitattributes                  LF for text sources
BootAnimations/*.zip            bundled defaults (spaced filenames OK)
BootAnimations/ATTRIBUTION.md   credits for bundled animations
customize.sh                    install hook (SKIPUNZIP extract + chown -R; not kept on device)
LICENSE                         MIT license for module code (shipped in release zip)
module.prop                     module metadata
post-fs-data.sh                 boot-time selection and overlay
scripts/lib.sh                  shared library helpers and KernelSU config helpers
scripts/validate.sh             CI checks
scripts/webui.sh                WebUI backend
uninstall.sh                    umount overlays on module removal
update.json                     OTA metadata (placeholder until release; bot-updated)
webroot/index.html              KernelSU Next WebUI
```


## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## License

Module code is [MIT](LICENSE).

Bundled boot animation zips are from [mauam's XDA collection](https://xdaforums.com/t/bootanimations-collection.3721978) and are credited in `BootAnimations/ATTRIBUTION.md`. They are not relicensed under MIT.
