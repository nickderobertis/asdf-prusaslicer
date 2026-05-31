# asdf-prusaslicer

An [asdf](https://asdf-vm.com) plugin for [PrusaSlicer](https://github.com/prusa3d/PrusaSlicer),
the open-source G-code generator and 3D printing slicer by Prusa Research.

The plugin installs official prebuilt releases from GitHub and exposes the
command-line executable as `prusa-slicer`.

## Supported platforms

| Platform | Architectures | Versions available | Artifact |
| --- | --- | --- | --- |
| macOS | Apple Silicon + Intel | all releases | universal `.dmg` |
| Linux | x86_64 | up to `2.8.1` | AppImage (extracted) |
| Linux | arm64 | up to `2.7.4` | `.tar.bz2` |

Upstream stopped publishing Linux binaries on GitHub after `2.8.1` and moved
Linux distribution to Flatpak, so `2.9.0` and newer can be installed through this
plugin on **macOS only**. Installing a newer version on Linux fails with a clear
message. Windows is not supported.

PrusaSlicer has no `--version` flag; verify an install with `prusa-slicer --help`.

## Requirements

- `asdf`, plus `bash` and `curl`.
- macOS: `hdiutil` (ships with macOS).
- Linux: `bzip2` and `tar` (for `.tar.bz2` releases).

## Install the plugin

```sh
asdf plugin add prusaslicer https://github.com/nickderobertis/asdf-prusaslicer.git
```

## Install PrusaSlicer

Latest stable:

```sh
asdf install prusaslicer latest
asdf set prusaslicer latest
```

A specific version (list what is installable first):

```sh
asdf list all prusaslicer
asdf install prusaslicer 2.8.1
asdf set prusaslicer 2.8.1
```

`asdf set` writes to `.tool-versions`. On older asdf versions use
`asdf local prusaslicer <version>` or `asdf global prusaslicer <version>`.

## Verify

```sh
prusa-slicer --help
```

The output begins with the PrusaSlicer build id. This works on a headless
machine; it does not open the graphical interface.

## GitHub API token (optional)

Listing versions and resolving downloads use the GitHub API, which allows 60
unauthenticated requests per hour. If you hit that limit, set a token:

```sh
export GITHUB_API_TOKEN=ghp_your_token_here
```

A token is never required for normal use. `GITHUB_TOKEN` is accepted as a
fallback.

## Troubleshooting

- **Unsupported platform / "no PrusaSlicer … build for …"** — the requested
  version has no artifact for your OS/architecture. On Linux this usually means
  the version is `2.9.0`+ (macOS-only on GitHub) or arm64 above `2.7.4`. Pick a
  supported version from `asdf list all prusaslicer`, or install PrusaSlicer for
  Linux via Flatpak.
- **GitHub API rate limit exceeded** — set `GITHUB_API_TOKEN` (see above).
- **Checksum mismatch** — upstream publishes no checksums, so the plugin does not
  verify one. A truncated download surfaces as a failed mount/extract; re-run
  `asdf install` to fetch again.
- **Missing build dependencies** — none: the plugin installs prebuilt binaries
  and never compiles from source.
- **`command not found: prusa-slicer` / stale shim** — ensure the version is
  selected (`asdf current prusaslicer`) and your shell has asdf's shims on
  `PATH`. Run `asdf reshim prusaslicer` if a shim is missing.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). In short:

1. Install `asdf`.
2. `git clone` this repository and `cd` into it.
3. `just bootstrap` — adds the asdf plugins for the pinned dev tools and runs
   `asdf install`.
4. `direnv allow` — optional; only loads a local `.env` for a `GITHUB_API_TOKEN`.
5. `just check` — run the full quality gate.

Daily development commands:

```sh
just format       # format shell scripts
just lint         # shellcheck
just test         # bats unit tests
just plugin-test  # real `asdf plugin test` for this platform
just check        # the full gate
```

## License

[MIT](LICENSE).
