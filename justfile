# Developer command runner for the asdf-prusaslicer plugin.
#
# Every quality-gate recipe is quiet on success and prints only actionable
# output on failure. `just check` runs the full gate. See CONTRIBUTING.md.

# Do not echo recipe commands; keep the success path quiet. Tool output and
# failures (including just's own error line) are still shown.
set quiet := true

# Shell files passed to shellcheck. The bats suite is excluded: shellcheck and
# shfmt cannot parse `@test` syntax, and the tests are verified by running them.
shellcheck_files := "bin/list-all bin/latest-stable bin/download bin/install bin/help.overview bin/help.deps bin/help.config bin/help.links lib/utils.sh"

# Directories shfmt walks (it auto-detects shell files by extension/shebang).
shfmt_paths := "bin lib"

# shfmt is configured here, not via .editorconfig: this shfmt release does not
# honour the switch_case_indent editorconfig key. -i 2 = two-space indent,
# -ci = indent switch/case branches.
shfmt_flags := "-i 2 -ci"

# Show available recipes.
default:
    @just --list

# Install the developer tools pinned in .tool-versions (idempotent).
bootstrap:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v asdf >/dev/null 2>&1; then
      echo "asdf not found. Install asdf, or install the tools listed in .tool-versions another way (see CONTRIBUTING.md)." >&2
      exit 1
    fi
    while read -r tool _version; do
      [ -n "${tool}" ] || continue
      asdf plugin list 2>/dev/null | grep -qx "${tool}" || asdf plugin add "${tool}"
    done <.tool-versions
    asdf install

# Format shell scripts in place.
format:
    shfmt {{ shfmt_flags }} -w {{ shfmt_paths }}

# Fail if any shell script is not formatted; prints a diff on failure.
format-check:
    shfmt {{ shfmt_flags }} -d {{ shfmt_paths }}

# Lint shell scripts.
lint:
    shellcheck {{ shellcheck_files }}

# Apply the safe automatic fixes available (formatting).
lint-fix:
    shfmt {{ shfmt_flags }} -w {{ shfmt_paths }}

# Lint GitHub Actions workflows.
lint-actions:
    actionlint

# Run the shell unit tests.
test:
    bats --print-output-on-failure test

# Run the real asdf plugin integration test (Linux pins the last GitHub Linux build).
plugin-test:
    #!/usr/bin/env bash
    set -euo pipefail
    ref="$(git rev-parse --abbrev-ref HEAD)"
    case "$(uname -s)" in
      Linux) version="2.8.1" ;;
      *) version="latest" ;;
    esac
    asdf plugin test prusaslicer "${PWD}" "prusa-slicer --help" \
      --asdf-plugin-gitref "${ref}" --asdf-tool-version "${version}"

# Full quality gate: format check, shell lint, actions lint, unit tests, plugin test.
check: format-check lint lint-actions test plugin-test

# Remove local scratch produced by tests or interrupted downloads.
clean:
    rm -rf .direnv
    find . -type f -name '*.part' -delete

# Print resolved developer tool versions (inspection only).
deps:
    #!/usr/bin/env bash
    set -euo pipefail
    printf 'shellcheck %s\n' "$(shellcheck --version | sed -n 's/^version: //p')"
    printf 'shfmt      %s\n' "$(shfmt --version)"
    printf 'bats       %s\n' "$(bats --version | sed 's/^Bats //')"
    printf 'actionlint %s\n' "$(actionlint --version | head -n 1)"
    printf 'just       %s\n' "$(just --version | sed 's/^just //')"

# Inspect: list installable versions exactly as the plugin reports them.
debug-list:
    @./bin/list-all

# Inspect: resolve the latest stable version, optionally restricted to a prefix.
debug-latest *query:
    @./bin/latest-stable {{ query }}

# Inspect: print the asset URL the plugin would download for VERSION on this host.
debug-resolve version:
    #!/usr/bin/env bash
    set -euo pipefail
    . lib/utils.sh
    os="$(prusaslicer_current_os)"
    arch="$(prusaslicer_current_arch)"
    prusaslicer_resolve_asset_url "{{ version }}" "${os}" "${arch}"
