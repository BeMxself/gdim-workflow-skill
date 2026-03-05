#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_ROUND_SCRIPT="${SCRIPT_DIR}/../run-gdim-round.sh"

tmp_dir="$(mktemp -d)"
workflow_rel=".tmp-stage-sessions-$$"
task_dir="${tmp_dir}/task"
output_file="${tmp_dir}/run.output"
counter_file="${tmp_dir}/codex-call-count"
workflow_abs="${PWD}/skills/${workflow_rel}/stage-flow"

cleanup() {
  rm -rf "${tmp_dir}"
  rm -rf "${PWD}/skills/${workflow_rel}"
}
trap cleanup EXIT

mkdir -p "${tmp_dir}/bin" "${task_dir}/config" "${task_dir}/intents" "${task_dir}/state" "${task_dir}/logs"
mkdir -p "skills/${workflow_rel}/stage-flow"

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
cat >"${workflow_dir}/01-design.round1.md" <<'MD'
# design
MD
cat >"${workflow_dir}/02-plan.round1.md" <<'MD'
# plan
MD
cat >"${workflow_dir}/05-execution-summary.round1.md" <<'MD'
# summary
MD
cat >"${workflow_dir}/03-gap-analysis.round1.md" <<'MD'
# gap
GDIM_EXIT_DECISION: CONTINUE
MD

exit 0
EOF
chmod +x "${tmp_dir}/bin/codex"

cat >"${task_dir}/config/flows.json" <<JSON
{
  "project": "stage-sessions",
  "workflow_dir": "${workflow_rel}",
  "design_doc": "docs/design/placeholder.md",
  "execution": { "runner": "codex" },
  "retry_limits": {
    "compile_failed": 0,
    "test_failed": 0,
    "malformed_output": 0
  },
  "flows": []
}
JSON

cat >"${task_dir}/intents/01-stage-flow.md" <<'MD'
# intent
MD

PATH="${tmp_dir}/bin:${PATH}" GDIM_HEARTBEAT_SECONDS=0 \
  GDIM_TEST_CODEX_COUNTER_FILE="${counter_file}" \
  GDIM_TEST_WORKFLOW_DIR="${workflow_abs}" \
  bash "${RUN_ROUND_SCRIPT}" \
    --flow-slug "stage-flow" \
    --max-rounds 1 \
    --workflow-dir "${workflow_rel}/stage-flow" \
    --intent-file "${task_dir}/intents/01-stage-flow.md" \
    --design-doc "docs/design/placeholder.md" \
    --modules "" \
    --allowed-paths "" \
    --stage "B" \
    --task-dir "${task_dir}" \
    --skip-clean-check >"${output_file}" 2>&1 || true

call_count=0
if [ -f "${counter_file}" ]; then
  call_count="$(cat "${counter_file}")"
fi

if [ "${call_count}" -ne 6 ]; then
  echo "expected 6 runner sessions in one round (one per GDIM stage), got ${call_count}"
  cat "${output_file}"
  exit 1
fi

echo "PASS: one round runs one session per stage"
