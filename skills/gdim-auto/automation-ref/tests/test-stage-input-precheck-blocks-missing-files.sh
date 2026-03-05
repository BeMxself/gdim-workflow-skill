#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_ROUND_SCRIPT="${SCRIPT_DIR}/../run-gdim-round.sh"

tmp_dir="$(mktemp -d)"
workflow_rel=".tmp-stage-precheck-$$"
task_dir="${tmp_dir}/task"
output_file="${tmp_dir}/run.output"
counter_file="${tmp_dir}/codex-call-count"
workflow_abs="${PWD}/skills/${workflow_rel}/precheck-flow"
missing_design_source="${tmp_dir}/missing-design-source.md"

cleanup() {
  rm -rf "${tmp_dir}"
  rm -rf "${PWD}/skills/${workflow_rel}"
}
trap cleanup EXIT

mkdir -p "${tmp_dir}/bin" "${task_dir}/config" "${task_dir}/intents" "${task_dir}/state" "${task_dir}/logs"
mkdir -p "skills/${workflow_rel}/precheck-flow"

cat >"${tmp_dir}/bin/codex" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

counter_file="${GDIM_TEST_CODEX_COUNTER_FILE:?}"
workflow_dir="${GDIM_TEST_WORKFLOW_DIR:?}"

count=0
if [ -f "${counter_file}" ]; then
  count="$(cat "${counter_file}")"
fi
count=$((count + 1))
printf "%s" "${count}" >"${counter_file}"

cat >/dev/null
mkdir -p "${workflow_dir}"
cat >"${workflow_dir}/00-scope-definition.round1.md" <<'MD'
# scope
MD
exit 0
EOF
chmod +x "${tmp_dir}/bin/codex"

cat >"${task_dir}/config/flows.json" <<JSON
{
  "project": "stage-precheck",
  "workflow_dir": "${workflow_rel}",
  "design_doc": "${missing_design_source}",
  "execution": { "runner": "codex" },
  "retry_limits": {
    "compile_failed": 0,
    "test_failed": 0,
    "malformed_output": 0
  },
  "flows": []
}
JSON

cat >"${task_dir}/intents/01-precheck-flow.md" <<'MD'
# intent
MD

set +e
PATH="${tmp_dir}/bin:${PATH}" GDIM_HEARTBEAT_SECONDS=0 \
  GDIM_TEST_CODEX_COUNTER_FILE="${counter_file}" \
  GDIM_TEST_WORKFLOW_DIR="${workflow_abs}" \
  bash "${RUN_ROUND_SCRIPT}" \
    --flow-slug "precheck-flow" \
    --max-rounds 1 \
    --workflow-dir "${workflow_rel}/precheck-flow" \
    --intent-file "${task_dir}/intents/01-precheck-flow.md" \
    --design-doc "${missing_design_source}" \
    --modules "" \
    --allowed-paths "" \
    --stage "B" \
    --task-dir "${task_dir}" \
    --skip-clean-check >"${output_file}" 2>&1
exit_code=$?
set -e

if [ "${exit_code}" -ne 1 ]; then
  echo "expected BLOCKED exit code 1 when stage precheck fails, got ${exit_code}"
  cat "${output_file}"
  exit 1
fi

if ! grep -q "Missing required input files for stage=design" "${output_file}"; then
  echo "expected missing input precheck message for design stage"
  cat "${output_file}"
  exit 1
fi

call_count=0
if [ -f "${counter_file}" ]; then
  call_count="$(cat "${counter_file}")"
fi
if [ "${call_count}" -ne 1 ]; then
  echo "expected only scope stage runner call before design precheck blocked, got ${call_count}"
  cat "${output_file}"
  exit 1
fi

echo "PASS: stage input precheck blocks missing required files"
