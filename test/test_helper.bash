# Shared bootstrap for the plugin's unit tests.
#
# Sourced by every *.bats file via `load test_helper`. It makes the pure helper
# functions from lib/utils.sh available so they can be exercised in isolation,
# without any network access.

PLUGIN_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"

# shellcheck source=../lib/utils.sh
. "${PLUGIN_ROOT}/lib/utils.sh"
