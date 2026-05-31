# Contributing

## Repository structure

```
bin/        asdf plugin scripts (list-all, latest-stable, download, install, help.*)
lib/        shared shell helpers sourced by bin/ and the tests
test/        Bats unit tests for the pure helpers
justfile    developer command runner and quality gate
.github/    CI workflow
```

Design constraints live in `AGENTS.md` (root and per-subtree). Read those before
making changes; they are the source of truth for the conventions summarised here.

## Getting set up

1. Install [asdf](https://asdf-vm.com).
2. From the repository root, run `just bootstrap`. It adds the asdf plugins for
   the tools pinned in `.tool-versions` (`just`, `shellcheck`, `shfmt`, `bats`,
   `actionlint`) and runs `asdf install`.
3. Optionally `direnv allow` to load a local `.env` (only useful for a
   `GITHUB_API_TOKEN`).

If a tool is not reliably installable through asdf in your environment, install
it any other way (for example Homebrew: `brew install shellcheck shfmt bats-core
actionlint just`) — the dev tools are ordinary utilities and nothing about the
plugin requires them to come from asdf specifically.

## Shell style

- POSIX-compatible shell in `lib/`; Bash in `bin/`, kept compatible with macOS's
  Bash 3.2 (no Bash 4+ features).
- `set -euo pipefail`, quote every expansion, prefer simple over clever.
- No `sort -V`; use the numeric three-key sort already in `lib/`.
- Format with `just format` (`shfmt -i 2 -ci`) and lint with `just lint`
  (`shellcheck`). Both are quiet when clean.

## Running tests

```sh
just test         # Bats unit tests (offline; pure helpers only)
just plugin-test  # real `asdf plugin test` for the current platform
just check        # the full gate: format-check, lint, lint-actions, test, plugin-test
```

`just plugin-test` clones the committed repository, so commit your changes before
running it. It pins `2.8.1` on Linux (the last GitHub Linux build) and tests
`latest` on macOS.

## Adding a new OS/architecture

1. Add the mapping to `prusaslicer_normalize_os` / `prusaslicer_normalize_arch`
   in `lib/utils.sh`.
2. Add an ordered preference list to `prusaslicer_asset_patterns` for the new
   `os:arch`. Keep patterns narrow enough not to cross architectures.
3. Add fixture cases to `test/asset_selection.bats` using real asset names from
   the relevant releases, and platform cases to `test/platform.bats`.
4. Update the support table in `README.md` and `bin/help.overview`.

## Updating release parsing

Upstream asset naming changes between releases. When it does:

1. Inspect real release assets (the GitHub releases API for a `version_<x>` tag).
2. Adjust `prusaslicer_asset_patterns` and, if the tag scheme changed,
   `prusaslicer_release_tag` / the tag filter in `prusaslicer_list_all_versions`.
3. Update fixtures in `test/asset_selection.bats` to match the real names.
4. Never replace dynamic asset discovery with templated URLs; the embedded build
   timestamps make templating unreliable.

## Quality diagnostics: fail or silent

Every check in the normal quality gate either passes silently or fails with an
actionable message. Warning-only diagnostics are not allowed: make a finding fail
the build, or disable it with a documented reason. Do not mask failures with
`|| true`, blanket ignores, or redirection that hides the cause.

## Minimal-output policy

Quality-gate commands are quiet on success — no dependency trees, full test logs,
or banners. On failure they identify the failing check and the actionable error.

## Permissions allowlist

`.claude/settings.json` holds a conservative, allow-only permission list for
automated assistants working in this repo. It permits the `just` recipes and a
few narrow direct tools (`shellcheck`, `shfmt`, `bats`, `actionlint`, specific
`asdf`/`git` subcommands, safe inspection) — never broad shell access. There is
no deny list; anything not allowed simply prompts. Extend it by adding a narrow
rule for a specific `just` recipe or tool, not a broad wildcard.

## Pull request checklist

- [ ] `just check` passes locally.
- [ ] New or changed helpers have unit tests; fixtures use real upstream names.
- [ ] Platform mapping and asset selection remain covered.
- [ ] User-facing changes are reflected in `README.md` and the `help.*` scripts.
- [ ] Durable constraints are recorded in the nearest `AGENTS.md`.
- [ ] No secrets, no committed artifacts, no changes outside the plugin's remit.
