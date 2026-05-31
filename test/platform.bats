#!/usr/bin/env bats
#
# Platform mapping must stay explicit and covered: every OS/architecture name
# the plugin claims to understand is asserted here, along with the rejection of
# unsupported ones.

load test_helper

@test "normalize_os maps Darwin to macos" {
  run prusaslicer_normalize_os Darwin
  [ "${status}" -eq 0 ]
  [ "${output}" = "macos" ]
}

@test "normalize_os maps Linux to linux" {
  run prusaslicer_normalize_os Linux
  [ "${status}" -eq 0 ]
  [ "${output}" = "linux" ]
}

@test "normalize_os rejects unsupported systems" {
  run prusaslicer_normalize_os MINGW64_NT
  [ "${status}" -ne 0 ]
  [ -z "${output}" ]
}

@test "normalize_arch maps x86_64 and amd64 to x64" {
  run prusaslicer_normalize_arch x86_64
  [ "${status}" -eq 0 ]
  [ "${output}" = "x64" ]

  run prusaslicer_normalize_arch amd64
  [ "${status}" -eq 0 ]
  [ "${output}" = "x64" ]
}

@test "normalize_arch maps aarch64 and arm64 to arm64" {
  run prusaslicer_normalize_arch aarch64
  [ "${status}" -eq 0 ]
  [ "${output}" = "arm64" ]

  run prusaslicer_normalize_arch arm64
  [ "${status}" -eq 0 ]
  [ "${output}" = "arm64" ]
}

@test "normalize_arch rejects unsupported architectures" {
  run prusaslicer_normalize_arch armv7l
  [ "${status}" -ne 0 ]
  [ -z "${output}" ]

  run prusaslicer_normalize_arch i386
  [ "${status}" -ne 0 ]
}
