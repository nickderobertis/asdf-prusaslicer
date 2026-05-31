# lib/ — shared helpers

Subtree-specific constraints. Root `AGENTS.md` covers everything else.

- Sourced by `bin/` scripts and the tests. Define functions only; perform no
  work at source time so importing stays free of side effects under
  `set -euo pipefail`.
- Keep two families clearly separated:
  - Pure functions (platform mapping, version filtering/ordering/selection,
    asset selection, artifact classification, path discovery). No network, no
    surprising filesystem writes. These are what the unit tests exercise.
  - I/O boundary functions (GitHub API calls, downloads). Network access is
    concentrated in a few clearly named functions and never hidden inside an
    otherwise-pure helper.
- A pure function must not depend on the caller's shell options. Signal "no
  result" with an explicit non-zero return, not by relying on the caller having
  `pipefail` set.
- Asset selection is pattern-based by necessity (upstream names are
  inconsistent). Keep each preference list ordered most-preferred first, narrow
  enough not to cross architectures (e.g. never let `arm64` match `armv7l`), and
  covered by a fixture test when changed.
- Prefer the prefixed `prusaslicer_*` function names and leading-underscore
  locals already established here, to avoid clashing with the sourcing script.
