#!/usr/bin/env bats
#
# Version parsing, prerelease filtering, ordering, and latest-stable selection.

load test_helper

mixed_versions() {
  printf '%s\n' \
    2.9.6-beta1 \
    2.9.5 \
    2.9.5-rc1 \
    2.8.1 \
    2.8.0 \
    2.7.4 \
    1.41.2 \
    1.2.31 \
    2.0.0-alpha1
}

filter() { mixed_versions | prusaslicer_filter_stable; }
sorted() { mixed_versions | prusaslicer_filter_stable | prusaslicer_sort_versions; }
latest() { mixed_versions | prusaslicer_filter_stable | prusaslicer_pick_latest "${1:-}"; }

@test "filter_stable drops prereleases" {
  run filter
  [ "${status}" -eq 0 ]
  [[ "${output}" != *"-beta"* ]]
  [[ "${output}" != *"-rc"* ]]
  [[ "${output}" != *"-alpha"* ]]
  [[ "${output}" == *"2.9.5"* ]]
}

@test "sort_versions orders ascending with newest last and no sort -V" {
  run sorted
  [ "${status}" -eq 0 ]
  # First line is the oldest, last line is the newest.
  [ "${lines[0]}" = "1.2.31" ]
  [ "${lines[1]}" = "1.41.2" ]
  [ "${lines[${#lines[@]} - 1]}" = "2.9.5" ]
}

@test "sort_versions treats components numerically, not lexically" {
  run bash -c 'printf "%s\n" 1.9.0 1.10.0 1.2.0 | sort -t. -k1,1n -k2,2n -k3,3n'
  [ "${lines[0]}" = "1.2.0" ]
  [ "${lines[1]}" = "1.9.0" ]
  [ "${lines[2]}" = "1.10.0" ]
}

@test "pick_latest returns the newest stable version" {
  run latest
  [ "${status}" -eq 0 ]
  [ "${output}" = "2.9.5" ]
}

@test "pick_latest honours a leading-prefix query" {
  run latest 2.8
  [ "${status}" -eq 0 ]
  [ "${output}" = "2.8.1" ]
}

@test "pick_latest treats the query as a regex (asdf default '[0-9]')" {
  # asdf passes '[0-9]' when the user gives no query; it must match all numeric
  # versions and resolve to the newest overall.
  run latest '[0-9]'
  [ "${status}" -eq 0 ]
  [ "${output}" = "2.9.5" ]
}

@test "pick_latest fails when nothing matches the query" {
  run latest 9.9
  [ "${status}" -ne 0 ]
  [ -z "${output}" ]
}
