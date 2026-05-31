# shellcheck shell=bash
#
# Shared helpers for the asdf-prusaslicer plugin.
#
# This file is *sourced* by the bin/ scripts and the test suite. It defines
# functions only and performs no work at source time, so importing it is free
# of side effects and safe under `set -euo pipefail`.
#
# Two families of functions live here:
#   * Pure functions (platform mapping, version filtering, asset selection).
#     They never touch the network or the filesystem and are unit-tested.
#   * I/O boundary functions (GitHub API, downloads). Network access is
#     deliberately concentrated in a few clearly named functions so it is never
#     hidden inside an otherwise-pure helper.

# Upstream coordinates. PrusaSlicer is released by Prusa Research on GitHub.
PRUSASLICER_REPO="prusa3d/PrusaSlicer"
PRUSASLICER_GH_API="https://api.github.com/repos/${PRUSASLICER_REPO}"

# ---------------------------------------------------------------------------
# Errors
# ---------------------------------------------------------------------------

# Print a concise, actionable message and abort. Plugin scripts stay quiet on
# success; all human-facing diagnostics go to stderr through this helper.
fail() {
  printf 'asdf-prusaslicer: %s\n' "$*" >&2
  exit 1
}

# ---------------------------------------------------------------------------
# Platform mapping (pure)
# ---------------------------------------------------------------------------

# Map `uname -s` to the token PrusaSlicer uses in its asset names.
prusaslicer_normalize_os() {
  case "$1" in
    Darwin) printf 'macos\n' ;;
    Linux) printf 'linux\n' ;;
    *) return 1 ;;
  esac
}

# Map `uname -m` to the token PrusaSlicer uses in its asset names. The plugin
# only distinguishes the two architectures upstream actually ships binaries for.
prusaslicer_normalize_arch() {
  case "$1" in
    x86_64 | amd64) printf 'x64\n' ;;
    aarch64 | arm64) printf 'arm64\n' ;;
    *) return 1 ;;
  esac
}

prusaslicer_current_os() {
  prusaslicer_normalize_os "$(uname -s)"
}

prusaslicer_current_arch() {
  prusaslicer_normalize_arch "$(uname -m)"
}

# ---------------------------------------------------------------------------
# Version handling (pure)
# ---------------------------------------------------------------------------

# Upstream tags every release `version_<semver>`.
prusaslicer_release_tag() {
  printf 'version_%s\n' "$1"
}

# Keep only final stable releases. Prereleases are tagged with an `-alpha`,
# `-beta`, or `-rc` suffix (e.g. `2.9.5-rc1`); excluding anything that is not a
# bare MAJOR.MINOR.PATCH drops them without enumerating each channel.
prusaslicer_filter_stable() {
  grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' || true
}

# Sort dotted numeric versions ascending (newest last), reading from stdin.
# `sort -V` is intentionally avoided for portability; because stable versions
# are purely numeric MAJOR.MINOR.PATCH, a three-key numeric sort is exact.
prusaslicer_sort_versions() {
  sort -t. -k1,1n -k2,2n -k3,3n
}

# Pick the newest stable version from a list on stdin. The optional query is a
# leading regular expression, matching the asdf contract for bin/latest-stable:
# asdf passes it through, defaulting to "[0-9]" when the user gives none, and a
# prefix such as "2.8" yields the newest "2.8.x". Prints nothing and returns
# non-zero when there is no match.
prusaslicer_pick_latest() {
  _query="${1:-}"
  _sorted="$(prusaslicer_sort_versions)"
  [ -n "${_sorted}" ] || return 1
  if [ -n "${_query}" ]; then
    _result="$(printf '%s\n' "${_sorted}" | grep -E "^${_query}" | tail -n 1)"
  else
    _result="$(printf '%s\n' "${_sorted}" | tail -n 1)"
  fi
  # Signal "no match" independently of the caller's pipefail setting.
  [ -n "${_result}" ] || return 1
  printf '%s\n' "${_result}"
}

# ---------------------------------------------------------------------------
# Asset selection (pure)
# ---------------------------------------------------------------------------

# Emit the ordered list of extended regular expressions used to choose a release
# asset for a given platform, most-preferred first. Returns non-zero for an
# unsupported os/arch combination.
#
# Upstream asset names are inconsistent across releases (embedded build
# timestamps, `+macOS` vs `+MacOS`, GTK2/GTK3 variants, "newer/older distros"
# qualifiers), so selection is pattern-based rather than templated:
#   * macOS ships a single universal .dmg (no architecture in the name).
#   * Linux x86_64 ships AppImages (GTK3 preferred) through 2.8.1, with .tar.bz2
#     as a fallback for older releases.
#   * Linux arm64 ships only .tar.bz2, and only through 2.7.4.
prusaslicer_asset_patterns() {
  case "$1:$2" in
    macos:*)
      printf '%s\n' '/PrusaSlicer-[^/]*\.dmg$'
      ;;
    linux:x64)
      printf '%s\n' \
        '/PrusaSlicer-[^/]*linux-x64[^/]*newer-distros[^/]*GTK3[^/]*\.AppImage$' \
        '/PrusaSlicer-[^/]*linux-x64[^/]*GTK3[^/]*\.AppImage$' \
        '/PrusaSlicer-[^/]*linux-x64[^/]*\.AppImage$' \
        '/PrusaSlicer-[^/]*linux-x64[^/]*GTK3[^/]*\.tar\.bz2$' \
        '/PrusaSlicer-[^/]*linux-x64[^/]*\.tar\.bz2$'
      ;;
    linux:arm64)
      printf '%s\n' \
        '/PrusaSlicer-[^/]*linux-arm64[^/]*GTK3[^/]*\.tar\.bz2$' \
        '/PrusaSlicer-[^/]*linux-arm64[^/]*\.tar\.bz2$'
      ;;
    *)
      return 1
      ;;
  esac
}

# Choose the best asset URL for an os/arch from a newline-separated list on
# stdin. Tries each preference pattern in turn and prints the first match.
# Prints nothing and returns non-zero when no candidate fits.
prusaslicer_select_asset_url() {
  _os="$1"
  _arch="$2"
  _urls="$(cat)"
  _patterns="$(prusaslicer_asset_patterns "${_os}" "${_arch}")" || return 1

  # Iterate patterns without a pipeline so the early return escapes the function
  # rather than a subshell.
  _old_ifs="$IFS"
  IFS='
'
  set -f
  for _pat in ${_patterns}; do
    [ -n "${_pat}" ] || continue
    _match="$(printf '%s\n' "${_urls}" | grep -iE "${_pat}" | head -n 1)"
    if [ -n "${_match}" ]; then
      IFS="${_old_ifs}"
      set +f
      printf '%s\n' "${_match}"
      return 0
    fi
  done
  IFS="${_old_ifs}"
  set +f
  return 1
}

# Classify a downloaded artifact by filename so install can pick an installer.
# Prints `dmg`, `appimage`, or `tarball`; returns non-zero for anything else.
prusaslicer_artifact_kind() {
  case "$1" in
    *.dmg) printf 'dmg\n' ;;
    *.AppImage) printf 'appimage\n' ;;
    *.tar.bz2) printf 'tarball\n' ;;
    *) return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# Filesystem (no network)
# ---------------------------------------------------------------------------

# Find a previously downloaded artifact in a directory, preferring the kinds the
# installer understands. Prints the path or returns non-zero.
prusaslicer_locate_artifact() {
  _dir="$1"
  [ -n "${_dir}" ] && [ -d "${_dir}" ] || return 1
  for _ext in dmg AppImage tar.bz2; do
    _found="$(find "${_dir}" -maxdepth 1 -type f -name "*.${_ext}" 2>/dev/null | head -n 1)"
    if [ -n "${_found}" ]; then
      printf '%s\n' "${_found}"
      return 0
    fi
  done
  return 1
}

# ---------------------------------------------------------------------------
# I/O boundary: GitHub API and downloads (network)
# ---------------------------------------------------------------------------

# GET a path under the PrusaSlicer repo API. A token is used only when present;
# it is never required for normal public use. Both GITHUB_API_TOKEN (the asdf
# convention) and GITHUB_TOKEN are honoured.
prusaslicer_api_get() {
  _url="${PRUSASLICER_GH_API}$1"
  _token="${GITHUB_API_TOKEN:-${GITHUB_TOKEN:-}}"
  if [ -n "${_token}" ]; then
    curl -fsSL --retry 3 --connect-timeout 30 \
      -H 'Accept: application/vnd.github+json' \
      -H "Authorization: token ${_token}" \
      "${_url}"
  else
    curl -fsSL --retry 3 --connect-timeout 30 \
      -H 'Accept: application/vnd.github+json' \
      "${_url}"
  fi
}

# Print every installable stable version, newest last. Paginates the tags API
# (100 per page) until a short page is seen. Returns non-zero on network error.
prusaslicer_list_all_versions() {
  _page=1
  _all=""
  while [ "${_page}" -le 20 ]; do
    _body="$(prusaslicer_api_get "/tags?per_page=100&page=${_page}")" || return 1
    _names="$(printf '%s' "${_body}" |
      grep -oE '"name": *"version_[0-9][^"]*"' |
      sed -E 's/.*"version_([^"]+)".*/\1/' || true)"
    [ -n "${_names}" ] || break
    _all="${_all}${_names}
"
    _count="$(printf '%s' "${_body}" | grep -cE '"name": *"' || true)"
    [ "${_count}" -ge 100 ] 2>/dev/null || break
    _page=$((_page + 1))
  done
  [ -n "${_all}" ] || return 1
  printf '%s' "${_all}" | prusaslicer_filter_stable | prusaslicer_sort_versions
}

# List every downloadable asset URL for a specific version's release.
prusaslicer_list_asset_urls() {
  _tag="$(prusaslicer_release_tag "$1")"
  prusaslicer_api_get "/releases/tags/${_tag}" |
    grep -oE '"browser_download_url": *"[^"]*"' |
    sed -E 's/.*"(https[^"]*)".*/\1/'
}

# Resolve the single best asset URL for a version on a platform. Prints nothing
# and returns non-zero when the version provides no artifact for the platform.
prusaslicer_resolve_asset_url() {
  prusaslicer_list_asset_urls "$1" | prusaslicer_select_asset_url "$2" "$3"
}

# Download a URL to a destination atomically: write to a sidecar `.part` file
# and rename on success so a failed transfer never leaves a file that looks
# installed.
prusaslicer_download_to() {
  _url="$1"
  _dest="$2"
  _part="${_dest}.part"
  if ! curl -fsSL --retry 3 --connect-timeout 30 -o "${_part}" "${_url}"; then
    rm -f "${_part}"
    return 1
  fi
  mv -f "${_part}" "${_dest}"
}
