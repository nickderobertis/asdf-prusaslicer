# test/ — Bats unit tests

Subtree-specific constraints. Root `AGENTS.md` covers everything else.

- Tests target the pure helpers in `lib/utils.sh` (loaded via `test_helper.bash`)
  and the install script's local behaviour driven with synthetic artifacts. They
  must run offline: never call the network or download a real release.
- Network and the .dmg/AppImage install paths are validated by `asdf plugin
  test`. The .tar.bz2 install path has no CI runner, so it is covered here with a
  synthetic tarball; keep that coverage when changing `install_linux_tarball`.
- Fixtures use real upstream asset lists from representative releases, chosen to
  exercise the awkward cases (macOS/Windows-only releases, GTK2 vs GTK3,
  arm64 vs armv7l, "newer/older distros" AppImages). Update them from real
  release data, not invented names, when upstream behaviour changes.
- `.bats` files are not linted by shellcheck or formatted by shfmt — both fail on
  `@test` syntax. Keep them to the repository's two-space indentation by hand;
  running the suite is their check.
- Add a test alongside every new helper, and a fixture case for any change to
  platform mapping or asset selection.
