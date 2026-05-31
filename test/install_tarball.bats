#!/usr/bin/env bats
#
# Integration coverage for the tarball install path (Linux arm64 / older
# releases). Unlike the .dmg and AppImage paths — which `asdf plugin test`
# exercises end to end in CI on macOS and Linux x86_64 — the .tar.bz2 path has
# no CI runner, so it is covered here against a synthetic artifact. The whole
# test is offline and host-independent: `bin/install` dispatches on the artifact
# kind, so a tarball drives `install_linux_tarball` on any platform.

load test_helper

# Build a .tar.bz2 shaped like a real Linux release (a top-level directory
# containing bin/prusa-slicer) into ASDF_DOWNLOAD_PATH. The stub binary answers
# --help so the install's own verification step passes.
make_tarball() {
  _dl="$1"
  _pkgname="PrusaSlicer-9.9.9+linux-x64-GTK3"
  _staging="${BATS_TEST_TMPDIR}/staging"
  mkdir -p "${_staging}/${_pkgname}/bin"
  cat >"${_staging}/${_pkgname}/bin/prusa-slicer" <<'STUB'
#!/usr/bin/env bash
if [ "$1" = "--help" ]; then
  echo "PrusaSlicer-9.9.9 based on Slic3r (with GUI support)"
  exit 0
fi
exit 2
STUB
  chmod +x "${_staging}/${_pkgname}/bin/prusa-slicer"
  mkdir -p "${_dl}"
  (cd "${_staging}" && tar -cf - "${_pkgname}" | bzip2 -c >"${_dl}/${_pkgname}.tar.bz2")
}

run_install() {
  env ASDF_INSTALL_TYPE=version ASDF_INSTALL_VERSION=9.9.9 \
    ASDF_INSTALL_PATH="$1" ASDF_DOWNLOAD_PATH="$2" \
    "${PLUGIN_ROOT}/bin/install"
}

@test "install unpacks a tarball, links the shim, and verifies it runs" {
  dl="${BATS_TEST_TMPDIR}/dl"
  inst="${BATS_TEST_TMPDIR}/inst"
  make_tarball "${dl}"

  run run_install "${inst}" "${dl}"
  [ "${status}" -eq 0 ]

  # The shim exists, is executable, and is a relative symlink into the unpacked
  # tree (so the install directory stays relocatable).
  [ -x "${inst}/bin/prusa-slicer" ]
  [ -L "${inst}/bin/prusa-slicer" ]
  [[ "$(readlink "${inst}/bin/prusa-slicer")" == ../* ]]

  # The shim actually runs.
  run "${inst}/bin/prusa-slicer" --help
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"PrusaSlicer-9.9.9"* ]]
}

@test "install writes nothing outside ASDF_INSTALL_PATH" {
  dl="${BATS_TEST_TMPDIR}/dl"
  inst="${BATS_TEST_TMPDIR}/inst"
  make_tarball "${dl}"

  run run_install "${inst}" "${dl}"
  [ "${status}" -eq 0 ]
  # The download directory still holds only the artifact (install did not unpack
  # into it or leave scratch behind).
  [ "$(find "${dl}" -type f | wc -l | tr -d ' ')" -eq 1 ]
}

@test "install fails clearly when the tarball lacks the executable" {
  dl="${BATS_TEST_TMPDIR}/dl"
  inst="${BATS_TEST_TMPDIR}/inst"
  mkdir -p "${dl}"
  # A well-formed tarball that does not contain a prusa-slicer binary.
  empty="${BATS_TEST_TMPDIR}/empty"
  mkdir -p "${empty}/PrusaSlicer-9.9.9/share"
  touch "${empty}/PrusaSlicer-9.9.9/share/readme"
  (cd "${empty}" && tar -cf - PrusaSlicer-9.9.9 | bzip2 -c >"${dl}/PrusaSlicer-9.9.9+linux-x64-GTK3.tar.bz2")

  run run_install "${inst}" "${dl}"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"no prusa-slicer executable"* ]]
}

@test "install fails clearly on a corrupt tarball" {
  dl="${BATS_TEST_TMPDIR}/dl"
  inst="${BATS_TEST_TMPDIR}/inst"
  mkdir -p "${dl}"
  printf 'not a real bzip2 archive' >"${dl}/PrusaSlicer-9.9.9+linux-x64-GTK3.tar.bz2"

  run run_install "${inst}" "${dl}"
  [ "${status}" -ne 0 ]
}
