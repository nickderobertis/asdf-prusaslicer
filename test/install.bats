#!/usr/bin/env bats
#
# Install-path behaviour that can be checked without downloading 100+ MB:
# artifact classification, artifact discovery in a download directory, and the
# release-tag mapping that drives every API call.

load test_helper

@test "artifact_kind classifies each supported extension" {
  run prusaslicer_artifact_kind PrusaSlicer-2.9.5.dmg
  [ "${output}" = "dmg" ]

  run prusaslicer_artifact_kind PrusaSlicer-2.8.1+linux-x64-GTK3.AppImage
  [ "${output}" = "appimage" ]

  run prusaslicer_artifact_kind PrusaSlicer-2.7.4+linux-arm64-GTK3.tar.bz2
  [ "${output}" = "tarball" ]
}

@test "artifact_kind rejects unsupported artifacts (e.g. Windows .zip)" {
  run prusaslicer_artifact_kind PrusaSlicer-2.9.5.zip
  [ "${status}" -ne 0 ]

  run prusaslicer_artifact_kind PrusaSlicer-2.9.5-setup.exe
  [ "${status}" -ne 0 ]
}

@test "locate_artifact finds an artifact in a download directory" {
  touch "${BATS_TEST_TMPDIR}/PrusaSlicer-2.8.1+linux-x64-GTK3.AppImage"
  run prusaslicer_locate_artifact "${BATS_TEST_TMPDIR}"
  [ "${status}" -eq 0 ]
  [ "${output}" = "${BATS_TEST_TMPDIR}/PrusaSlicer-2.8.1+linux-x64-GTK3.AppImage" ]
}

@test "locate_artifact prefers an installable kind over other files" {
  touch "${BATS_TEST_TMPDIR}/notes.txt"
  touch "${BATS_TEST_TMPDIR}/PrusaSlicer-2.9.5.dmg"
  run prusaslicer_locate_artifact "${BATS_TEST_TMPDIR}"
  [ "${status}" -eq 0 ]
  [ "${output}" = "${BATS_TEST_TMPDIR}/PrusaSlicer-2.9.5.dmg" ]
}

@test "locate_artifact fails on an empty or missing directory" {
  run prusaslicer_locate_artifact "${BATS_TEST_TMPDIR}"
  [ "${status}" -ne 0 ]

  run prusaslicer_locate_artifact "${BATS_TEST_TMPDIR}/does-not-exist"
  [ "${status}" -ne 0 ]

  run prusaslicer_locate_artifact ""
  [ "${status}" -ne 0 ]
}

@test "release_tag prefixes the upstream version scheme" {
  run prusaslicer_release_tag 2.9.5
  [ "${output}" = "version_2.9.5" ]
}
