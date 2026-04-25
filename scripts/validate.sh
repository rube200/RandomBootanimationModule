#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

fail() { echo "Error: $*" >&2; exit 1; }

get() {
  local line
  line=$(grep "^${1}=" module.prop | head -1) || return 1
  echo "${line#"${1}"=}"
}

placeholder() {
  [[ "$1" == INJECTED || "$1" == PIPELINE || "$1" == CHANGEME || "$1" == *CHANGEME* ]]
}

warn() { echo "Warning: $*" >&2; }

check_css_file() {
  local f=$1
  check_text_file "$f"
  if grep -qiE '(@import[[:space:]]+url|url)[[:space:]]*\([[:space:]]*["'\'' ]*(https?:)?//' "$f"; then
    fail "$f: external resources are not allowed; use local files or inline styles"
  fi
}

check_file() {
  local f=${1#./}
  case $f in
    *.css) check_css_file "$f" ;;
    *.html) check_html_file "$f" ;;
    *.js) check_js_file "$f" ;;
    *.json) check_json_file "$f" ;;
    *.md | *.prop | *.sh) check_text_file "$f" ;;
    *) fail "Unexpected file type: $f" ;;
  esac
}

check_html_file() {
  local f=$1 dir ref resolved line
  check_text_file "$f"
  if grep -qiE '<(link[^>]*stylesheet[^>]*href|script[^>]+src)=[[:space:]]*["'\'' ]*(https?:)?//' "$f"; then
    fail "$f: external stylesheets and scripts are not allowed; use local files, a <style> block, or inline <script>"
  fi
  dir=$(dirname "$f")
  while IFS= read -r line; do
    [[ "$line" =~ (href|src)=[[:space:]]*[\"\']([^\"\']+)[\"\'] ]] || continue
    ref="${BASH_REMATCH[2]}"
    [[ "$ref" =~ ^(https?:)?// ]] && continue
    [[ "$ref" =~ ^(data:|#|javascript:) ]] && continue
    ref="${ref#./}"
    resolved="$dir/$ref"
    [ -f "$resolved" ] || fail "$f: referenced file not found: $ref"
  done < <(grep -ioE '<(link[^>]*stylesheet[^>]*href|script[^>]+src)=[^>]+>' "$f" 2>/dev/null || true)
}

check_js_file() {
  local f=$1
  check_text_file "$f"
  if grep -qiE '(import[[:space:]]+.*from[[:space:]]*|import[[:space:]]*\([[:space:]]*)["'\'' ]*(https?:)?//' "$f"; then
    fail "$f: external imports are not allowed; use local modules only"
  fi
}

check_json_file() {
  local f=$1
  check_text_file "$f"
  jq empty "$f" 2>/dev/null || fail "$f: invalid JSON"
}

check_text_file() {
  local f=$1
  if [ "$(head -c3 "$f" 2>/dev/null || true)" = $'\xef\xbb\xbf' ]; then
    fail "$f: UTF-8 BOM not allowed"
  fi
  if grep -q $'\r' "$f"; then
    fail "$f: CRLF line endings"
  fi
  local last
  last=$(tail -c1 "$f" 2>/dev/null || true)
  [ -z "$last" ] || [ "$last" = $'\n' ] || fail "$f: Missing final newline"
  if [[ "$f" != *.md ]] && grep -qE '[[:space:]]$' "$f"; then
    fail "$f: Trailing whitespace"
  fi
}

discover_text_files() {
  find . \( -path './.git' -o -path './build' \) -prune -o -type f \( \
    -name '*.css' -o \
    -name '*.html' -o \
    -name '*.js' -o \
    -name '*.json' -o \
    -name '*.md' -o \
    -name '*.prop' -o \
    -name '*.sh' \
  \) -print0 2>/dev/null | sort -z
}

validate_changelog() {
  local line
  while IFS= read -r line; do
    [[ "$line" =~ ^##\ \[(Unreleased|v[0-9A-Za-z._-]+)\]$ ]] \
      || fail "Invalid CHANGELOG section: $line (expected ## [Unreleased] or ## [vX.Y.Z])"
  done < <(grep -E '^## \[' CHANGELOG.md 2>/dev/null || true)

  if [ -n "${RELEASE_VERSION:-}" ]; then
    grep -qF "## [${RELEASE_VERSION}]" CHANGELOG.md \
      || fail "CHANGELOG.md missing section: ## [${RELEASE_VERSION}]"
  fi
}

validate_changelog_bullets() {
  local file=CHANGELOG.md in_section=0 prev='' line item first
  bullet_key() {
    printf '%s' "$1" | tr -d '`'
  }
  while IFS= read -r line; do
    case "$line" in
      "## ["*)
        in_section=1
        prev=
        ;;
      "- "*)
        if [ "$in_section" -eq 0 ]; then
          continue
        fi
        item=${line#- }
        if [ -n "$prev" ]; then
          first=$(printf '%s\n%s' "$(bullet_key "$prev")" "$(bullet_key "$item")" | LC_ALL=C sort | head -1)
          [ "$first" = "$(bullet_key "$prev")" ] \
            || fail "$file bullets not alphabetical (expected '$item' before '$prev')"
        fi
        prev=$item
        ;;
      *)
        if [ -z "$line" ]; then
          continue
        fi
        in_section=0
        prev=
        ;;
    esac
  done <"$file"
}

validate_cross_refs() {
  local mp_vc mp_version uj_vc uj_version
  uj_vc=$(jq -er '.versionCode' update.json)
  [ "$uj_vc" -gt 0 ] || return 0

  mp_version=$(get version)
  mp_vc=$(get versionCode)
  uj_version=$(jq -r '.version // ""' update.json)

  if ! placeholder "$mp_version" && [ "$mp_version" != "$uj_version" ]; then
    warn "module.prop version ($mp_version) differs from update.json ($uj_version)"
  fi
  if ! placeholder "$mp_vc" && [ "$mp_vc" != "$uj_vc" ]; then
    warn "module.prop versionCode ($mp_vc) differs from update.json ($uj_vc)"
  fi
}

validate_files() {
  local f base sc_files=()
  while IFS= read -r -d '' f; do
    base=${f#./}
    check_file "$base"
    [[ "$base" == *.sh ]] && sc_files+=("$base")
  done < <(discover_text_files)

  if [ ${#sc_files[@]} -eq 0 ]; then
    return 0
  fi
  command -v shellcheck >/dev/null || fail "Shellcheck not found"
  shellcheck "${sc_files[@]}"
}

validate_module_prop() {
  local k count id repo_lower uj vc
  for k in author description id name version versionCode; do
    count=$(grep -c "^${k}=" module.prop 2>/dev/null || true)
    [ "${count:-0}" -le 1 ] || fail "Duplicate $k in module.prop"
    [ -n "$(get "$k")" ] || fail "Missing $k in module.prop"
  done

  id=$(get id)
  if placeholder "$id"; then
    if [ -n "${REPO_NAME:-}" ]; then
      [[ "$REPO_NAME" =~ ^[a-zA-Z][a-zA-Z0-9._-]+$ ]] \
        || fail "Repo name '$REPO_NAME' is invalid for id=INJECTED (must match ^[a-zA-Z][a-zA-Z0-9._-]+$)"
      repo_lower=$(printf '%s' "$REPO_NAME" | tr '[:upper:]' '[:lower:]')
      if [ "$REPO_NAME" != "$repo_lower" ]; then
        warn "Repo name '$REPO_NAME' contains uppercase; lowercase module ids are conventional (set id= in module.prop to override)"
      fi
    fi
  else
    [[ "$id" =~ ^[a-zA-Z][a-zA-Z0-9._-]+$ ]] || fail "Invalid id '$id'"
  fi

  vc=$(get versionCode)
  if ! placeholder "$vc"; then
    [[ "$vc" =~ ^[0-9]+$ ]] || fail "Invalid versionCode '$vc'"
  fi

  uj=$(get updateJson)
  if [ -n "$uj" ] && ! placeholder "$uj"; then
    [[ "$uj" =~ ^https://raw\.githubusercontent\.com/[^/]+/[^/]+/.+/update\.json$ ]] \
      || fail "Invalid updateJson '$uj'"
    if [ -n "${DEFAULT_BRANCH:-}" ]; then
      [[ "$uj" == */"${DEFAULT_BRANCH}"/update.json ]] \
        || fail "updateJson must point to ${DEFAULT_BRANCH}/update.json"
    fi
  fi
}

validate_module_scripts() {
  if [ -f customize.sh ] && ! grep -q 'SKIPUNZIP' customize.sh; then
    warn "customize.sh: consider setting SKIPUNZIP (see KernelSU docs)"
  fi
  if [ -f service.sh ] && ! grep -q 'MODDIR' service.sh; then
    warn "service.sh: consider using MODDIR=\${0%/*} for paths"
  fi
}

validate_release() {
  local desc name
  [ -n "${RELEASE_VERSION:-}" ] || return 0

  [[ "$RELEASE_VERSION" =~ ^v[0-9A-Za-z._-]+$ ]] || fail "Invalid RELEASE_VERSION '$RELEASE_VERSION'"

  name=$(get name)
  desc=$(get description)
  if placeholder "$name"; then
    warn "module.prop name is still a placeholder"
  fi
  if placeholder "$desc"; then
    warn "module.prop description is still a placeholder"
  fi
}

validate_required_files() {
  local f
  for f in \
    BootAnimations/ATTRIBUTION.md \
    CHANGELOG.md \
    customize.sh \
    LICENSE \
    module.prop \
    post-fs-data.sh \
    scripts/lib.sh \
    scripts/webui.sh \
    uninstall.sh \
    update.json
  do
    [ -f "$f" ] || fail "Missing $f"
  done
}

validate_update_json() {
  local key uj_changelog uj_version uj_zip uj_vc
  command -v jq >/dev/null || fail "jq not found"

  for key in changelog version versionCode zipUrl; do
    jq -e ". | has(\"$key\")" update.json >/dev/null || fail "update.json missing key: $key"
  done

  uj_vc=$(jq -er '.versionCode | if type == "number" and (floor == .) then . else error("versionCode must be an integer") end' update.json)
  if [ "$uj_vc" -lt 0 ]; then
    fail "update.json versionCode must be >= 0"
  fi

  if [ "$uj_vc" -eq 0 ]; then
    return 0
  fi

  uj_version=$(jq -r '.version // ""' update.json)
  uj_zip=$(jq -r '.zipUrl // ""' update.json)
  uj_changelog=$(jq -r '.changelog // ""' update.json)
  [ -n "$uj_version" ] || fail "update.json missing version"
  [[ "$uj_zip" =~ ^https:// ]] || fail "update.json zipUrl must be an https URL"
  [[ "$uj_changelog" =~ ^https:// ]] || fail "update.json changelog must be an https URL"
}

validate_webroot() {
  if [ -d webroot ] && [ -n "$(find webroot -mindepth 1 -print -quit 2>/dev/null)" ]; then
    [ -f webroot/index.html ] || fail "webroot/ is non-empty but missing webroot/index.html"
  fi
}

validate_required_files
validate_module_prop
validate_update_json
validate_changelog
validate_changelog_bullets
validate_cross_refs
validate_files
validate_module_scripts
validate_release
validate_webroot

echo "Validation passed"
