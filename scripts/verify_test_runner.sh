#!/usr/bin/env bash

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

expect_probe_failure() {
    probe_name="$1"
    expected_pattern="$2"
    shift 2
    probe_output="$(mktemp "/tmp/taiwu-runner-${probe_name}.XXXXXX")"

    "${SCRIPT_DIR}/run_tests.sh" "$@" >"${probe_output}" 2>&1
    probe_status=$?
    if [ "${probe_status}" -eq 0 ]; then
        printf 'Runner probe %s unexpectedly returned success. Output: %s\n' "${probe_name}" "${probe_output}" >&2
        exit 1
    fi
    if ! grep -E -q "${expected_pattern}" "${probe_output}"; then
        printf 'Runner probe %s lacked the expected diagnostic. Output: %s\n' "${probe_name}" "${probe_output}" >&2
        exit 1
    fi
    printf 'Runner probe passed: %s produced a failing result.\n' "${probe_name}"
    printf 'Probe output: %s\n' "${probe_output}"
}

expect_probe_failure \
    missing-script \
    "FAIL missing-script-probe|Can.t load script|File not found" \
    _probe_missing_script

resource_probe_dir="$(mktemp -d /tmp/taiwu-missing-resource.XXXXXX)"
resource_probe_script="${resource_probe_dir}/missing_resource_probe.gd"
cp \
    "${REPOSITORY_ROOT}/combo_duel_vslice/tests/fixtures/missing_resource_probe.gd.txt" \
    "${resource_probe_script}"
expect_probe_failure \
    missing-resource \
    "FAIL missing-resource-probe|Could not preload resource|File.*not found|Parse Error" \
    _probe_missing_resource \
    "${resource_probe_script}"
