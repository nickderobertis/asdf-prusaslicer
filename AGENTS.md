# Repository guide

Durable conventions and design constraints for this repository. Treat this file
as the source of truth; keep it current when constraints change.

## What this repository is

An [asdf](https://asdf-vm.com) plugin that installs official prebuilt
PrusaSlicer releases from GitHub and exposes the `prusa-slicer` executable. It is
a shell plugin, not a packaged application — there is no build artifact to ship
and no language runtime to embed.

## Architecture

- `bin/` — the asdf plugin scripts (the only entry points asdf calls).
- `lib/utils.sh` — shared helper functions sourced by `bin/` scripts and the
  tests. Split into pure functions and a small, explicit I/O boundary.
- `test/` — Bats unit tests for the pure helpers.
- `justfile` — the developer command runner and quality gate.

`bin/` scripts stay thin: argument/environment handling and orchestration. All
reusable logic — platform mapping, version parsing, asset selection, network
access — lives in `lib/utils.sh` so it can be unit-tested in isolation.

## asdf plugin script contract

- Implemented: `list-all`, `latest-stable`, `download`, `install`, and
  `help.*`. Others (`list-bin-paths`, `exec-env`, `uninstall`, legacy-file
  scripts, lifecycle hooks) are intentionally absent: the default behaviours are
  correct for a single self-contained executable under `<install>/bin`.
- asdf passes work through environment variables: `ASDF_INSTALL_TYPE`,
  `ASDF_INSTALL_VERSION`, `ASDF_INSTALL_PATH`, `ASDF_DOWNLOAD_PATH`. Read them;
  do not reconstruct paths by other means.
- Plugin scripts must never invoke `asdf` (no `asdf reshim`, no `asdf` lookups).
  asdf manages shims and reshimming itself.
- `bin/list-all` prints a single space-separated line, oldest first / newest
  last. `bin/latest-stable` prints exactly one version.
- `bin/` contains only the executable plugin scripts. `asdf plugin test` fails
  if *any* file under `bin/` is not executable, so never put documentation or
  data files there — keep subtree notes (like an `AGENTS.md`) out of `bin/`.
- Keep `bin/` scripts thin: read the asdf environment, orchestrate, and delegate
  real logic to `lib/utils.sh`. Source helpers with the same preamble in every
  script (`plugin_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"`, then
  `. "${plugin_dir}/lib/utils.sh"`). Success is quiet; diagnostics go to stderr
  via `fail`. `help.*` scripts are the exception and may print freely.
- `install` ends by running the installed executable (`prusa-slicer --help`) to
  confirm the install before returning.
- A non-empty `LICENSE` file must exist at the repository root; `asdf plugin
  test` fails without it.

## Shell style and portability

- Target POSIX-compatible shell in `lib/`. `bin/` scripts use Bash deliberately
  for `set -o pipefail` and reliable `${BASH_SOURCE[0]}` path resolution; keep
  them compatible with the Bash 3.2 that ships on macOS — no associative arrays,
  `mapfile`, `${var^^}`, or other Bash 4+ features.
- Run with `set -euo pipefail`. Quote every expansion. Prefer simple shell over
  clever shell.
- Do not use `sort -V`; it is unavailable or inconsistent across platforms.
  Stable versions are numeric `MAJOR.MINOR.PATCH`, so a three-key numeric
  `sort -t. -k1,1n -k2,2n -k3,3n` is exact and portable.
- Avoid non-portable flags. Prefer `bzip2 -dc | tar -xf -` over `tar -j`.
- Use safe temporary directories (`mktemp -d` under `$TMPDIR`); never hardcode a
  shared path. Clean up temporary files and mounts on every exit path.

## Dependencies

Keep runtime dependencies small and explicit: `bash`, `curl`, and standard text
utilities everywhere; `hdiutil` on macOS; `bzip2`/`tar` on Linux. Do not add new
tool dependencies without recording them in `bin/help.deps` and the README.

## Release and version parsing

- Versions come from the upstream GitHub tags API (`version_<semver>` tags),
  paginated. Asset URLs come from the GitHub releases API.
- Do not template download URLs. Upstream asset names are inconsistent across
  releases (embedded build timestamps, `+macOS` vs `+MacOS`, GTK2/GTK3 variants,
  "newer/older distros" qualifiers), so the matching asset is discovered from
  the release and chosen by ordered patterns. Keep the patterns narrow and
  covered by tests.
- When upstream data comes from GitHub, support `GITHUB_API_TOKEN` (and
  `GITHUB_TOKEN`) to raise the rate limit, but never require a token for public
  use, and never commit a real token.

## Stable vs prerelease

Only final `MAJOR.MINOR.PATCH` releases are installable. Prereleases
(`-alpha`/`-beta`/`-rc`) are excluded from both `list-all` and `latest-stable`.
This policy is intentional and documented in user-facing help.

## Platform availability

Upstream binary coverage on GitHub is uneven and capped: macOS ships a universal
`.dmg` for every release; Linux x86_64 ships an AppImage only through 2.8.1;
Linux arm64 ships a `.tar.bz2` only through 2.7.4. Newer Linux versions are
distributed via Flatpak, which this plugin intentionally does not use (it would
add a system dependency and could not honour exact-version installs). When a
requested version has no asset for the current platform, fail with guidance that
names the newest version installable there, not a bare "no build" error.

## Download and checksums

Upstream publishes no per-asset checksums, so none can be verified; this is
documented rather than worked around. Downloads use HTTPS, fail on any non-2xx
status (`curl -f`), and are written to a sidecar `.part` file renamed on success
so a failed transfer never leaves something that looks installed.

## Install-path safety

`bin/install` writes only inside `ASDF_INSTALL_PATH`, plus temporary files that
are always cleaned up. It must not modify shell startup files, install system
packages, or write anywhere else. The installed executable is verified to run
before the script returns (`prusa-slicer --help`; PrusaSlicer has no `--version`
flag and `--help` runs without a display).

A Linux install can still fail at that verification because the build links a
few system libraries it does not bundle (WebKitGTK/OpenGL), which load at process
start. When the loader reports a missing library, map the soname to the packages
that provide it across common distributions and fail with that exact install
command, so the requirement is discoverable from the error. The plugin reports
the command; it never installs the packages itself.

## Quality gate

`just check` is the full gate: format check, shell lint, workflow lint, unit
tests, and `asdf plugin test`. Continuous integration runs the same checks on
Linux and macOS.

## Fail-or-silent diagnostics

Every check in the normal quality gate must either pass silently or fail with an
actionable message. Warning-only diagnostics are not allowed in the gate: a
finding either fails the build or is disabled with a documented reason. Never
mask failures with `|| true`, blanket ignores, or output redirection that hides
the cause. (`|| true` is acceptable only to make a *successful* no-match path
deterministic, never to swallow a real error.)

## Minimal-output commands

Quality-gate commands are quiet on success. Do not print dependency trees, full
test logs, or banners on the success path. Plugin scripts print only what asdf
expects on success and send diagnostics to stderr on failure.

## Testing

- Unit tests cover the pure helpers: platform mapping, version
  parsing/filtering/ordering, latest-stable selection, asset-URL selection,
  artifact classification, and artifact discovery.
- Tests must not touch the network. Network functions are exercised by
  `asdf plugin test`, not by unit tests.
- Every helper added to `lib/` gets a test. Platform mapping and asset selection
  in particular stay covered, with fixtures drawn from real release data.

## Git state

Keep the working tree clean. Branch off `main` for changes; do not commit
downloaded artifacts (see `.gitignore`). `asdf plugin test` clones the committed
state, so commit before running it locally.

## Documentation and comments

Write for future maintainers and users, not as a record of how the code came to
be. Avoid first-person or session narration ("added", "we decided", "per the
prompt"). Comment surprising constraints and upstream quirks, not obvious shell
syntax.

## Where design constraints live

Encode every durable design constraint in the nearest applicable `AGENTS.md`:
root for repository-wide rules, a nested `AGENTS.md` for subtree-specific ones.
If a rule should guide future contributors, it belongs here — not only in a
commit message or an ephemeral discussion.

## Maintaining these files

`AGENTS.md` files stay platform-neutral, minimal, and high-signal: capture
non-obvious, durable constraints, not tutorials or restatements of the obvious.
They describe repository conventions only; they do not mention or configure any
specific tool or product. A nested `AGENTS.md` covers only what is specific to
its subtree and does not repeat root guidance. Each `AGENTS.md` has a sibling
`CLAUDE.md` symlink pointing to it; the symlink must never hold independent
content.
