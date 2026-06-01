#!/usr/bin/env bats
#
# The Linux builds link system libraries they do not bundle (WebKitGTK, OpenGL).
# When one is absent the install verification fails with a dynamic-loader error;
# the plugin must turn that into an actionable package-install instruction rather
# than echo the raw error. These cover that translation offline.

load test_helper

@test "lib_package_hint maps WebKitGTK 4.1 to packages" {
  run prusaslicer_lib_package_hint libwebkit2gtk-4.1.so.0
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"libwebkit2gtk-4.1-0"* ]]
  [[ "${output}" == *"webkit2gtk4.1"* ]]
}

@test "lib_package_hint maps OpenGL sonames" {
  run prusaslicer_lib_package_hint libGL.so.1
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"libgl1"* ]]

  run prusaslicer_lib_package_hint libEGL.so.1
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"libegl1"* ]]
}

@test "lib_package_hint returns non-zero for an unknown library" {
  run prusaslicer_lib_package_hint libfoobar.so.9
  [ "${status}" -ne 0 ]
  [ -z "${output}" ]
}

@test "missing_lib_advice extracts the soname and names the package" {
  loader_error="prusa-slicer: error while loading shared libraries: libwebkit2gtk-4.1.so.0: cannot open shared object file: No such file or directory"
  run prusaslicer_missing_lib_advice <<<"${loader_error}"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"libwebkit2gtk-4.1.so.0"* ]]
  [[ "${output}" == *"libwebkit2gtk-4.1-0"* ]]
  [[ "${output}" == *"apt-get install"* ]]
}

@test "missing_lib_advice still advises for an unmapped soname" {
  loader_error="prusa-slicer: error while loading shared libraries: libmystery.so.2: cannot open shared object file"
  run prusaslicer_missing_lib_advice <<<"${loader_error}"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"libmystery.so.2"* ]]
  [[ "${output}" == *"install the package that provides this library"* ]]
}

@test "missing_lib_advice is silent for output with no loader error" {
  run prusaslicer_missing_lib_advice <<<"PrusaSlicer-2.8.1+linux based on Slic3r"
  [ "${status}" -ne 0 ]
  [ -z "${output}" ]
}
