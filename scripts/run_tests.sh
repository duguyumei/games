#!/usr/bin/env bash

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJECT_DIR="${REPOSITORY_ROOT}/combo_duel_vslice"
LOG_DIR="${TAIWU_TEST_LOG_DIR:-/tmp/taiwu-test-logs}"
LOG_PREFIX="${TAIWU_TEST_LOG_PREFIX:-}"
MODE="${1:-quick}"

case "${LOG_DIR}" in
    /tmp|/tmp/*) ;;
    *)
        printf 'ERROR: TAIWU_TEST_LOG_DIR must be under /tmp: %s\n' "${LOG_DIR}" >&2
        exit 2
        ;;
esac

if [ -n "${LOG_PREFIX}" ]; then
    case "${LOG_PREFIX}" in
        /tmp/*) ;;
        *)
            printf 'ERROR: TAIWU_TEST_LOG_PREFIX must be under /tmp: %s\n' "${LOG_PREFIX}" >&2
            exit 2
            ;;
    esac
fi

resolve_godot() {
    if [ -n "${GODOT_BIN:-}" ]; then
        printf '%s\n' "${GODOT_BIN}"
        return
    fi
    if command -v godot >/dev/null 2>&1; then
        command -v godot
        return
    fi
    if command -v godot4 >/dev/null 2>&1; then
        command -v godot4
        return
    fi
    if [ -x /Applications/Godot.app/Contents/MacOS/Godot ]; then
        printf '%s\n' /Applications/Godot.app/Contents/MacOS/Godot
        return
    fi
    return 1
}

GODOT_EXECUTABLE="$(resolve_godot || true)"
if [ -z "${GODOT_EXECUTABLE}" ] || [ ! -x "${GODOT_EXECUTABLE}" ]; then
    printf 'ERROR: Godot executable not found; set GODOT_BIN to an executable path.\n' >&2
    exit 2
fi

mkdir -p "${LOG_DIR}"

scan_diagnostics() {
    awk '
        /ERROR: Condition "ret != noErr" is true\. Returning: ""/ {
            pending_ca_error = $0
            next
        }
        pending_ca_error != "" {
            if ($0 ~ /at: get_system_ca_certificates/) {
                pending_ca_error = ""
                next
            }
            print pending_ca_error
            pending_ca_error = ""
        }
        /ERROR|Can.t load script|File not found/ { print }
        /ObjectDB instances leaked at exit|Resources still in use at exit|RID allocations leaked at exit/ { print }
        /orphan StringName|orphan NodePath|resource leak|leaked resource|exit phase/ { print }
        END {
            if (pending_ca_error != "") {
                print pending_ca_error
            }
        }
    ' "$@" | awk '!seen[$0]++'
}

PASSED=0
FAILED=0
SUMMARY_LINES=""
SUITE_SERIAL=0

verify_group_coverage() {
    main_expected="$(mktemp /tmp/taiwu-main-tests-expected.XXXXXX)"
    main_grouped="$(mktemp /tmp/taiwu-main-tests-grouped.XXXXXX)"
    technique_expected="$(mktemp /tmp/taiwu-technique-tests-expected.XXXXXX)"
    technique_grouped="$(mktemp /tmp/taiwu-technique-tests-grouped.XXXXXX)"

    awk '
        /^func _initialize/ { inside = 1; next }
        inside && /^func / { exit }
        inside { print }
    ' "${PROJECT_DIR}/tests/test_runner.gd" \
        | grep -o '_test_[[:alnum:]_]*' \
        | sort -u >"${main_expected}"
    grep -h -o '"_test_[[:alnum:]_]*"' \
        "${PROJECT_DIR}"/tests/groups/test_battle_*.gd \
        "${PROJECT_DIR}"/tests/groups/test_content_contracts.gd \
        "${PROJECT_DIR}"/tests/groups/test_determinism.gd \
        "${PROJECT_DIR}"/tests/groups/test_hand_math.gd \
        "${PROJECT_DIR}"/tests/groups/test_remote_ai.gd \
        "${PROJECT_DIR}"/tests/groups/test_run_map.gd \
        "${PROJECT_DIR}"/tests/groups/test_save_contracts.gd \
        "${PROJECT_DIR}"/tests/groups/test_ui_loading.gd \
        | tr -d '"' \
        | sort -u >"${main_grouped}"

    awk '
        /^func _initialize/ { inside = 1; next }
        inside && /^func / { exit }
        inside { print }
    ' "${PROJECT_DIR}/tests/test_technique_runtime.gd" \
        | grep -o '_test_[[:alnum:]_]*' \
        | sort -u >"${technique_expected}"
    grep -h -o '"_test_[[:alnum:]_]*"' \
        "${PROJECT_DIR}"/tests/groups/test_technique_*.gd \
        | tr -d '"' \
        | sort -u >"${technique_grouped}"

    coverage_failed=0
    if ! diff -u "${main_expected}" "${main_grouped}" >/dev/null; then
        printf 'ERROR: test_runner.gd and its grouped entries differ:\n' >&2
        diff -u "${main_expected}" "${main_grouped}" >&2 || true
        coverage_failed=1
    fi
    if ! diff -u "${technique_expected}" "${technique_grouped}" >/dev/null; then
        printf 'ERROR: test_technique_runtime.gd and its grouped entries differ:\n' >&2
        diff -u "${technique_expected}" "${technique_grouped}" >&2 || true
        coverage_failed=1
    fi
    if [ "${coverage_failed}" -ne 0 ]; then
        exit 2
    fi
}

run_suite() {
    suite_name="$1"
    script_path="$2"
    SUITE_SERIAL=$((SUITE_SERIAL + 1))
    if [ -n "${LOG_PREFIX}" ]; then
        godot_log="$(printf '%s-%s-%02d.log' \
            "${LOG_PREFIX}" "${suite_name}" "${SUITE_SERIAL}")"
    else
        godot_log="$(mktemp "${LOG_DIR}/taiwu-${suite_name}.XXXXXX")"
    fi
    stdout_log="${godot_log}.stdout"

    "${GODOT_EXECUTABLE}" \
        --headless \
        --log-file "${godot_log}" \
        --path "${PROJECT_DIR}" \
        --script "${script_path}" \
        -- \
        --launch-mode=test >"${stdout_log}" 2>&1
    exit_code=$?

    diagnostics="$(scan_diagnostics "${stdout_log}" "${godot_log}")"
    if [ "${exit_code}" -eq 0 ] && [ -z "${diagnostics}" ]; then
        PASSED=$((PASSED + 1))
        result_line="PASS ${suite_name} | log: ${godot_log}"
        printf '[PASS] %s\n' "${result_line}"
        pass_detail="$(grep -E 'PASS.*assertions|PROJECT LOAD PASS' "${stdout_log}" 2>/dev/null | tail -n 1 || true)"
        if [ -n "${pass_detail}" ]; then
            printf '       %s\n' "${pass_detail}"
        fi
    else
        FAILED=$((FAILED + 1))
        result_line="FAIL ${suite_name} (exit ${exit_code}) | log: ${godot_log} | stdout: ${stdout_log}"
        printf '[FAIL] %s\n' "${result_line}" >&2
        if [ -n "${diagnostics}" ]; then
            printf '%s\n' "${diagnostics}" | sed -n '1,30p' >&2
        else
            tail -n 30 "${stdout_log}" >&2
        fi
    fi
    SUMMARY_LINES="${SUMMARY_LINES}${result_line}\n"
}

run_quick() {
    run_suite project-load res://tests/test_project_load.gd
    run_suite runtime-profiles res://tests/test_runtime_profiles.gd
    run_suite content-pipeline res://tests/test_content_pipeline.gd
    run_suite content-contracts res://tests/groups/test_content_contracts.gd
    run_suite hand-math res://tests/groups/test_hand_math.gd
    run_suite technique-contracts res://tests/groups/test_technique_contracts.gd
    run_suite determinism res://tests/groups/test_determinism.gd
}

run_full() {
    run_quick
    run_suite save-contracts res://tests/groups/test_save_contracts.gd
    run_suite technique-runtime res://tests/groups/test_technique_runtime.gd
    run_suite battle-contracts res://tests/groups/test_battle_contracts.gd
    run_suite battle-rules res://tests/groups/test_battle_rules.gd
    run_suite run-map res://tests/groups/test_run_map.gd
    run_suite ui-loading res://tests/groups/test_ui_loading.gd
    for discovered_test in "${PROJECT_DIR}"/tests/test_*.gd; do
        discovered_name="$(basename "${discovered_test}" .gd)"
        case "${discovered_name}" in
            test_runner|test_technique_runtime|test_project_load|test_runtime_profiles|test_content_pipeline)
                continue
                ;;
        esac
        run_suite "${discovered_name#test_}" "res://tests/${discovered_name}.gd"
    done
}

run_ai() {
    run_suite remote-ai res://tests/groups/test_remote_ai.gd
}

case "${MODE}" in
    quick)
        verify_group_coverage
        run_quick
        ;;
    full)
        verify_group_coverage
        run_full
        ;;
    ai)
        verify_group_coverage
        run_ai
        ;;
    _probe_missing_script)
        run_suite missing-script-probe res://tests/__missing_script_probe__.gd
        ;;
    _probe_missing_resource)
        if [ "$#" -lt 2 ]; then
            printf 'ERROR: missing-resource probe requires an absolute script path.\n' >&2
            exit 2
        fi
        run_suite missing-resource-probe "$2"
        ;;
    *)
        printf 'Usage: %s [quick|full|ai]\n' "$0" >&2
        exit 2
        ;;
esac

printf '\nTest summary: %d passed, %d failed\n' "${PASSED}" "${FAILED}"
printf '%b' "${SUMMARY_LINES}"
printf 'Logs retained under: %s\n' "${LOG_DIR}"

if [ "${FAILED}" -ne 0 ]; then
    exit 1
fi
