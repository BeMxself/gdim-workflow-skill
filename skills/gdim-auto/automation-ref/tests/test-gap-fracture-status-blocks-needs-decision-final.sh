#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_ROUND_SCRIPT="${SCRIPT_DIR}/../run-gdim-round.sh"

tmp_dir="$(mktemp -d)"
workflow_rel=".tmp-gap-fracture-block-$$"
task_dir="${tmp_dir}/task"
output_file="${tmp_dir}/run.output"
final_counter_file="${tmp_dir}/final.count"
workflow_abs="${PWD}/skills/${workflow_rel}/balanced-fracture-flow"
shared_intent_abs="${PWD}/skills/${workflow_rel}/00-intent.md"

cleanup() {
  rm -rf "${tmp_dir}"
  rm -rf "${PWD}/skills/${workflow_rel}"
}
trap cleanup EXIT

mkdir -p "${tmp_dir}/bin" "${task_dir}/config" "${task_dir}/intents" "${task_dir}/state" "${task_dir}/logs"
mkdir -p "skills/${workflow_rel}/balanced-fracture-flow"

cat >"${shared_intent_abs}" <<'MD'
# shared intent
MD

cat >"${tmp_dir}/bin/codex" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

workflow_dir="${GDIM_TEST_WORKFLOW_DIR:?}"
final_counter_file="${GDIM_TEST_FINAL_COUNTER_FILE:?}"
stage="${CURRENT_STAGE:-unknown}"

mkdir -p "${workflow_dir}"

if [ "${stage}" = "final" ]; then
  count=0
  if [ -f "${final_counter_file}" ]; then
    count="$(cat "${final_counter_file}")"
  fi
  count=$((count + 1))
  printf "%s" "${count}" >"${final_counter_file}"
  cat >"${workflow_dir}/99-final-report.md" <<'MD'
# final report
MD
  exit 0
fi

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
GDIM_EXIT_DECISION: FINAL_REPORT
GDIM_REFACTOR_POSTURE: BALANCED
GDIM_FRACTURE_STATUS: NEEDS_DECISION
MD
exit 0
EOF
chmod +x "${tmp_dir}/bin/codex"

cat >"${task_dir}/config/flows.json" <<JSON
{
  "project": "gap-fracture-block",
  "workflow_dir": "${workflow_rel}",
  "design_doc": "docs/design/placeholder.md",
  "refactor_posture": "balanced",
  "execution": { "runner": "codex" },
  "retry_limits": {
    "compile_failed": 0,
    "test_failed": 0,
    "malformed_output": 0
  },
  "flows": [
    {
      "id": 1,
      "slug": "balanced-fracture-flow",
      "intent_file": "01-balanced-fracture-flow.md",
      "depends_on": [],
      "max_rounds": 1,
      "stage": "B",
      "modules": ["module-a"],
      "allowed_paths": ["module-a/"]
    }
  ]
}
JSON

intent_abs="${task_dir}/intents/01-balanced-fracture-flow.md"
cat >"${intent_abs}" <<'MD'
# flow intent
MD

set +e
PATH="${tmp_dir}/bin:${PATH}" \
GDIM_HEARTBEAT_SECONDS=0 \
GDIM_TEST_WORKFLOW_DIR="${workflow_abs}" \
GDIM_TEST_FINAL_COUNTER_FILE="${final_counter_file}" \
  bash "${RUN_ROUND_SCRIPT}" \
    --flow-slug "balanced-fracture-flow" \
    --max-rounds 1 \
    --workflow-dir "${workflow_rel}/balanced-fracture-flow" \
    --intent-file "${intent_abs}" \
    --design-doc "docs/design/placeholder.md" \
    --modules "" \
    --allowed-paths "" \
    --stage "B" \
    --task-dir "${task_dir}" \
    --skip-clean-check >"${output_file}" 2>&1
exit_code=$?
set -e

if [ "${exit_code}" -ne 1 ]; then
  echo "expected exit code 1 when fracture needs decision, got ${exit_code}"
  cat "${output_file}"
  exit 1
fi

if [ -f "${final_counter_file}" ]; then
  echo "final stage should not run when fracture needs decision"
  cat "${output_file}"
  exit 1
fi

grep -q "BLOCKED" "${output_file}" || { echo "expected blocked output"; cat "${output_file}"; exit 1; }

echo "PASS: fracture status blocks final closure regardless of posture"
