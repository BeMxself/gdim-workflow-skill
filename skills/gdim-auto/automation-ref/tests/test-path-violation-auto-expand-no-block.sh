#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_ROUND_SCRIPT="${SCRIPT_DIR}/../run-gdim-round.sh"

tmp_dir="$(mktemp -d)"
workflow_rel=".tmp-retry-switch-$$"
task_dir="${tmp_dir}/task"
output_file="${tmp_dir}/run.output"
mvn_counter_file="${tmp_dir}/mvn-test-count"
codex_counter_file="${tmp_dir}/codex-call-count"
workflow_abs="${PWD}/skills/${workflow_rel}/switch-flow"
disallowed_dir="${workflow_rel}/disallowed"
disallowed_abs="${PWD}/skills/${disallowed_dir}"

cleanup() {
  rm -rf "${tmp_dir}"
  rm -rf "${PWD}/skills/${workflow_rel}"
}
trap cleanup EXIT

mkdir -p "${tmp_dir}/bin" "${task_dir}/config" "${task_dir}/intents" "${task_dir}/state" "${task_dir}/logs"
mkdir -p "skills/${workflow_rel}/switch-flow"

cat >"${tmp_dir}/bin/mvn" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

goal="${1:-}"
counter_file="${GDIM_TEST_MVN_COUNTER_FILE:?}"

case "${goal}" in
  compile)
    exit 0
    ;;
  test)
    count=0
    if [ -f "${counter_file}" ]; then
      count="$(cat "${counter_file}")"
    fi
    count=$((count + 1))
    printf "%s" "${count}" >"${counter_file}"
    if [ "${count}" -eq 1 ]; then
      echo "simulated mvn test failure" >&2
      exit 1
    fi
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
EOF
chmod +x "${tmp_dir}/bin/mvn"

cat >"${tmp_dir}/bin/codex" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

counter_file="${GDIM_TEST_CODEX_COUNTER_FILE:?}"
workflow_dir="${GDIM_TEST_WORKFLOW_DIR:?}"
disallowed_dir="${GDIM_TEST_DISALLOWED_DIR:?}"

count=0
if [ -f "${counter_file}" ]; then
  count="$(cat "${counter_file}")"
fi
count=$((count + 1))
printf "%s" "${count}" >"${counter_file}"

cat >/dev/null

mkdir -p "${workflow_dir}"
touch "${workflow_dir}/00-scope.round1.md"
touch "${workflow_dir}/01-design.round1.md"
touch "${workflow_dir}/02-plan.round1.md"
touch "${workflow_dir}/03-summary.round1.md"
touch "${workflow_dir}/04-gap-analysis.round1.md"

if [ "${count}" -ge 2 ]; then
  mkdir -p "${disallowed_dir}"
  echo "outside" >"${disallowed_dir}/outside.txt"
fi

exit 0
EOF
chmod +x "${tmp_dir}/bin/codex"

cat >"${task_dir}/config/flows.json" <<JSON
{
  "project": "retry-switch",
  "workflow_dir": "${workflow_rel}",
  "design_doc": "docs/design/placeholder.md",
  "execution": { "runner": "codex" },
  "retry_limits": {
    "compile_failed": 2,
    "test_failed": 2,
    "malformed_output": 1
  },
  "flows": []
}
JSON

cat >"${task_dir}/intents/01-switch-flow.md" <<'MD'
# intent
MD

PATH="${tmp_dir}/bin:${PATH}" \
GDIM_HEARTBEAT_SECONDS=0 \
GDIM_TEST_MVN_COUNTER_FILE="${mvn_counter_file}" \
GDIM_TEST_CODEX_COUNTER_FILE="${codex_counter_file}" \
GDIM_TEST_WORKFLOW_DIR="${workflow_abs}" \
GDIM_TEST_DISALLOWED_DIR="${disallowed_abs}" \
  bash "${RUN_ROUND_SCRIPT}" \
    --flow-slug "switch-flow" \
    --max-rounds 1 \
    --workflow-dir "${workflow_rel}/switch-flow" \
    --intent-file "${task_dir}/intents/01-switch-flow.md" \
    --design-doc "docs/design/placeholder.md" \
    --modules "fake-module" \
    --allowed-paths "gdim-auto/,${workflow_rel}/switch-flow/" \
    --stage "B" \
    --task-dir "${task_dir}" \
    --skip-clean-check >"${output_file}" 2>&1 || true

if ! grep -q "Retry 1/2 for test_failed" "${output_file}"; then
  echo "expected first retry for test_failed"
  cat "${output_file}"
  exit 1
fi

if grep -q "Retry 2/2 for path_violation" "${output_file}"; then
  echo "unexpected second retry after failure type switched to path_violation"
  cat "${output_file}"
  exit 1
fi

if grep -q "Retry template not found" "${output_file}"; then
  echo "unexpected retry template error after failure type switch"
  cat "${output_file}"
  exit 1
fi

if ! grep -q "Auto-expanded allowed_paths for path_violation:" "${output_file}"; then
  echo "expected auto-expand message for path_violation"
  cat "${output_file}"
  exit 1
fi

if grep -q "Gate failure persists after .*path_violation.*marking BLOCKED" "${output_file}"; then
  echo "unexpected blocked on path_violation after auto-expand"
  cat "${output_file}"
  exit 1
fi

echo "PASS: path_violation auto-expands allowed paths and does not block"
