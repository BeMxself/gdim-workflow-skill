#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_ROUND_SCRIPT="${SCRIPT_DIR}/../run-gdim-round.sh"

tmp_dir="$(mktemp -d)"
workflow_rel=".tmp-gap-final-stage-$$"
task_dir="${tmp_dir}/task"
output_file="${tmp_dir}/run.output"
final_prompt_file="${tmp_dir}/final.prompt.md"
final_counter_file="${tmp_dir}/final.count"
workflow_abs="${PWD}/skills/${workflow_rel}/final-stage-flow"
shared_intent_abs="${PWD}/skills/${workflow_rel}/00-intent.md"

cleanup() {
  rm -rf "${tmp_dir}"
  rm -rf "${PWD}/skills/${workflow_rel}"
}
trap cleanup EXIT

mkdir -p "${tmp_dir}/bin" "${task_dir}/config" "${task_dir}/intents" "${task_dir}/state" "${task_dir}/logs"
mkdir -p "skills/${workflow_rel}/final-stage-flow"

cat >"${shared_intent_abs}" <<'MD'
# shared intent
MD

cat >"${tmp_dir}/bin/codex" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

workflow_dir="${GDIM_TEST_WORKFLOW_DIR:?}"
final_prompt_file="${GDIM_TEST_FINAL_PROMPT_FILE:?}"
final_counter_file="${GDIM_TEST_FINAL_COUNTER_FILE:?}"
stage="${CURRENT_STAGE:-unknown}"

prompt="$(cat)"
mkdir -p "${workflow_dir}"

if [ "${stage}" = "final" ]; then
  printf "%s" "${prompt}" >"${final_prompt_file}"
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
MD
exit 0
EOF
chmod +x "${tmp_dir}/bin/codex"

cat >"${task_dir}/config/flows.json" <<JSON
{
  "project": "gap-final-stage",
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

intent_abs="${task_dir}/intents/01-final-stage-flow.md"
cat >"${intent_abs}" <<'MD'
# flow intent
MD

set +e
PATH="${tmp_dir}/bin:${PATH}" \
GDIM_HEARTBEAT_SECONDS=0 \
GDIM_TEST_WORKFLOW_DIR="${workflow_abs}" \
GDIM_TEST_FINAL_PROMPT_FILE="${final_prompt_file}" \
GDIM_TEST_FINAL_COUNTER_FILE="${final_counter_file}" \
  bash "${RUN_ROUND_SCRIPT}" \
    --flow-slug "final-stage-flow" \
    --max-rounds 1 \
    --workflow-dir "${workflow_rel}/final-stage-flow" \
    --intent-file "${intent_abs}" \
    --design-doc "docs/design/placeholder.md" \
    --modules "" \
    --allowed-paths "" \
    --stage "B" \
    --task-dir "${task_dir}" \
    --skip-clean-check >"${output_file}" 2>&1
exit_code=$?
set -e

if [ "${exit_code}" -ne 0 ]; then
  echo "expected exit code 0 when FINAL_REPORT triggers final stage, got ${exit_code}"
  cat "${output_file}"
  exit 1
fi

final_count=0
if [ -f "${final_counter_file}" ]; then
  final_count="$(cat "${final_counter_file}")"
fi
if [ "${final_count}" -ne 1 ]; then
  echo "expected gdim-final stage to run exactly once, got ${final_count}"
  cat "${output_file}"
  exit 1
fi

if [ ! -f "${final_prompt_file}" ]; then
  echo "missing final-stage prompt capture: ${final_prompt_file}"
  cat "${output_file}"
  exit 1
fi

gap_file="${workflow_abs}/03-gap-analysis.round1.md"

grep -q "/gdim-final" "${final_prompt_file}" || { echo "final prompt missing /gdim-final command"; cat "${final_prompt_file}"; exit 1; }
grep -q "${shared_intent_abs}" "${final_prompt_file}" || { echo "final prompt missing shared intent"; cat "${final_prompt_file}"; exit 1; }
grep -q "${intent_abs}" "${final_prompt_file}" || { echo "final prompt missing flow intent"; cat "${final_prompt_file}"; exit 1; }
grep -q "${gap_file}" "${final_prompt_file}" || { echo "final prompt missing gap file"; cat "${final_prompt_file}"; exit 1; }

if grep -q "00-scope-definition.round1.md" "${final_prompt_file}"; then
  echo "final prompt should not inject scope files"
  cat "${final_prompt_file}"
  exit 1
fi
if grep -q "01-design.round1.md" "${final_prompt_file}"; then
  echo "final prompt should not inject design files"
  cat "${final_prompt_file}"
  exit 1
fi
if grep -q "02-plan.round1.md" "${final_prompt_file}"; then
  echo "final prompt should not inject plan files"
  cat "${final_prompt_file}"
  exit 1
fi
if grep -q "05-execution-summary.round1.md" "${final_prompt_file}"; then
  echo "final prompt should not inject summary files"
  cat "${final_prompt_file}"
  exit 1
fi
if grep -q "04-execution-log.round1.md" "${final_prompt_file}"; then
  echo "final prompt should not inject execute-log files"
  cat "${final_prompt_file}"
  exit 1
fi

if [ ! -f "${workflow_abs}/99-final-report.md" ]; then
  echo "expected final stage to generate 99-final-report.md"
  cat "${output_file}"
  exit 1
fi

echo "PASS: FINAL_REPORT triggers gdim-final with intent+gap inputs"
