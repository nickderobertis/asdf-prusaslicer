#!/usr/bin/env bats
#
# Download-URL construction. Fixtures are the *real* asset lists of three
# representative releases, chosen to cover every quirk the selector must handle:
#   * 2.9.5 - macOS/Windows only, no architecture in the .dmg name, no Linux.
#   * 2.8.1 - last Linux x86_64 AppImage, with "newer/older distros" variants.
#   * 2.7.4 - the richest set: arm64 + armv7l + x64, GTK2 + GTK3, AppImage + tar.
#
# The selector must prefer GTK3 over GTK2, prefer the "newer distros" AppImage,
# never confuse armv7l with arm64/x64, and refuse unsupported combinations.

load test_helper

BASE="https://github.com/prusa3d/PrusaSlicer/releases/download"

assets_2_9_5() {
  printf '%s\n' \
    "${BASE}/version_2.9.5/PrusaSlicer-2.9.5-setup.exe" \
    "${BASE}/version_2.9.5/PrusaSlicer-2.9.5.dmg" \
    "${BASE}/version_2.9.5/PrusaSlicer-2.9.5.zip"
}

assets_2_8_1() {
  printf '%s\n' \
    "${BASE}/version_2.8.1/PrusaSlicer-2.8.1+linux-x64-newer-distros-GTK3-202409181416.AppImage" \
    "${BASE}/version_2.8.1/PrusaSlicer-2.8.1+linux-x64-older-distros-GTK3-202409181354.AppImage" \
    "${BASE}/version_2.8.1/PrusaSlicer-2.8.1+macOS-universal-202409181403.dmg" \
    "${BASE}/version_2.8.1/PrusaSlicer-2.8.1+win64-202409181359.zip"
}

assets_2_7_4() {
  printf '%s\n' \
    "${BASE}/version_2.7.4/PrusaSlicer-2.7.4+linux-arm64-GTK3-202404050952.tar.bz2" \
    "${BASE}/version_2.7.4/PrusaSlicer-2.7.4+linux-armv7l-GTK2-202404050928.AppImage" \
    "${BASE}/version_2.7.4/PrusaSlicer-2.7.4+linux-armv7l-GTK2-202404050928.tar.bz2" \
    "${BASE}/version_2.7.4/PrusaSlicer-2.7.4+linux-x64-GTK2-202404050940.AppImage" \
    "${BASE}/version_2.7.4/PrusaSlicer-2.7.4+linux-x64-GTK2-202404050940.tar.bz2" \
    "${BASE}/version_2.7.4/PrusaSlicer-2.7.4+linux-x64-GTK3-202404050928.AppImage" \
    "${BASE}/version_2.7.4/PrusaSlicer-2.7.4+linux-x64-GTK3-202404050928.tar.bz2" \
    "${BASE}/version_2.7.4/PrusaSlicer-2.7.4+macOS-universal-202404050934.dmg" \
    "${BASE}/version_2.7.4/PrusaSlicer-2.7.4+win64-202404050928.zip"
}

select_from() { printf '%s\n' "$2" | prusaslicer_select_asset_url "$3" "$4"; }

# --- macOS: always the single universal .dmg ------------------------------

@test "macOS selects the .dmg even when it has no arch in the name (2.9.5)" {
  run select_from _ "$(assets_2_9_5)" macos arm64
  [ "${status}" -eq 0 ]
  [ "${output}" = "${BASE}/version_2.9.5/PrusaSlicer-2.9.5.dmg" ]
}

@test "macOS selects the universal .dmg (2.7.4), same pick for both arches" {
  run select_from _ "$(assets_2_7_4)" macos x64
  [ "${status}" -eq 0 ]
  [ "${output}" = "${BASE}/version_2.7.4/PrusaSlicer-2.7.4+macOS-universal-202404050934.dmg" ]

  run select_from _ "$(assets_2_7_4)" macos arm64
  [ "${output}" = "${BASE}/version_2.7.4/PrusaSlicer-2.7.4+macOS-universal-202404050934.dmg" ]
}

# --- Linux x86_64 ---------------------------------------------------------

@test "Linux x64 prefers the newer-distros GTK3 AppImage (2.8.1)" {
  run select_from _ "$(assets_2_8_1)" linux x64
  [ "${status}" -eq 0 ]
  [ "${output}" = "${BASE}/version_2.8.1/PrusaSlicer-2.8.1+linux-x64-newer-distros-GTK3-202409181416.AppImage" ]
}

@test "Linux x64 prefers GTK3 over GTK2 and ignores armv7l (2.7.4)" {
  run select_from _ "$(assets_2_7_4)" linux x64
  [ "${status}" -eq 0 ]
  [ "${output}" = "${BASE}/version_2.7.4/PrusaSlicer-2.7.4+linux-x64-GTK3-202404050928.AppImage" ]
}

@test "Linux x64 has no artifact in macOS/Windows-only releases (2.9.5)" {
  run select_from _ "$(assets_2_9_5)" linux x64
  [ "${status}" -ne 0 ]
  [ -z "${output}" ]
}

# --- Linux arm64 ----------------------------------------------------------

@test "Linux arm64 selects the arm64 tarball and never armv7l (2.7.4)" {
  run select_from _ "$(assets_2_7_4)" linux arm64
  [ "${status}" -eq 0 ]
  [ "${output}" = "${BASE}/version_2.7.4/PrusaSlicer-2.7.4+linux-arm64-GTK3-202404050952.tar.bz2" ]
}

@test "Linux arm64 has no artifact once upstream dropped it (2.8.1)" {
  run select_from _ "$(assets_2_8_1)" linux arm64
  [ "${status}" -ne 0 ]
  [ -z "${output}" ]
}

# --- Unsupported platforms ------------------------------------------------

@test "asset_patterns rejects an unsupported os/arch combination" {
  run prusaslicer_asset_patterns windows x64
  [ "${status}" -ne 0 ]

  run prusaslicer_asset_patterns linux riscv64
  [ "${status}" -ne 0 ]
}

@test "select_asset_url fails for an unsupported platform" {
  run select_from _ "$(assets_2_9_5)" windows x64
  [ "${status}" -ne 0 ]
  [ -z "${output}" ]
}

# --- Unavailable-version guidance -----------------------------------------
# When a version has no asset for the platform, the failure must explain the
# upstream cap and name the newest installable version, not just say "no build".

@test "unavailable_advice explains the Linux x86_64 cap at 2.8.1" {
  run prusaslicer_unavailable_advice 2.9.5 linux x64
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"2.9.5"* ]]
  [[ "${output}" == *"2.8.1 is the newest version installable here"* ]]
  [[ "${output}" == *"Flatpak"* ]]
  [[ "${output}" == *"asdf list all prusaslicer"* ]]
}

@test "unavailable_advice explains the Linux arm64 cap at 2.7.4" {
  run prusaslicer_unavailable_advice 2.8.1 linux arm64
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"2.7.4"* ]]
  [[ "${output}" == *"newest version installable here"* ]]
}

@test "unavailable_advice falls back for other platforms" {
  run prusaslicer_unavailable_advice 9.9.9 macos arm64
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"9.9.9"* ]]
  [[ "${output}" == *"asdf list all prusaslicer"* ]]
}
