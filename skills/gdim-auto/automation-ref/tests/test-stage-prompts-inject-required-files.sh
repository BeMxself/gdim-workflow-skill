#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_ROUND_SCRIPT="${SCRIPT_DIR}/../run-gdim-round.sh"

tmp_dir="$(mktemp -d)"
workflow_rel=".tmp-stage-required-inputs-$$"
task_dir="${tmp_dir}/task"
output_file="${tmp_dir}/run.output"
prompt_dir="${tmp_dir}/prompts"
workflow_abs="${PWD}/skills/${workflow_rel}/required-inputs-flow"
intent_abs="${task_dir}/intents/01-required-inputs-flow.md"
design_doc_abs="${tmp_dir}/reference-spec.md"

cleanup() {
  rm -rf "${tmp_dir}"
  rm -rf "${PWD}/skills/${workflow_rel}"
}
trap cleanup EXIT

mkdir -p "${tmp_dir}/bin" "${task_dir}/config" "${task_dir}/intents" "${task_dir}/state" "${task_dir}/logs" "${prompt_dir}"
mkdir -p "skills/${workflow_rel}/required-inputs-flow"

cat >"${tmp_dir}/bin/codex" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

workflow_dir="${GDIM_TEST_WORKFLOW_DIR:?}"
prompt_dir="${GDIM_TEST_PROMPT_DIR:?}"
stage="${CURRENT_STAGE:?}"

mkdir -p "${workflow_dir}" "${prompt_dir}"
cat >"${prompt_dir}/${stage}.prompt.md"

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
  "project": "stage-required-inputs",
  "workflow_dir": "${workflow_rel}",
  "design_doc": "${design_doc_abs}",
  "execution": { "runner": "codex" },
  "retry_limits": {
    "compile_failed": 0,
    "test_failed": 0,
    "malformed_output": 0
  },
  "flows": []
}
JSON

cat >"${intent_abs}" <<'MD'
# intent
MD

cat >"${design_doc_abs}" <<'MD'
# reference
MD

PATH="${tmp_dir}/bin:${PATH}" GDIM_HEARTBEAT_SECONDS=0 \
  GDIM_TEST_WORKFLOW_DIR="${workflow_abs}" \
  GDIM_TEST_PROMPT_DIR="${prompt_dir}" \
  bash "${RUN_ROUND_SCRIPT}" \
    --flow-slug "required-inputs-flow" \
    --max-rounds 1 \
    --workflow-dir "${workflow_rel}/required-inputs-flow" \
    --intent-file "${intent_abs}" \
    --design-doc "${design_doc_abs}" \
    --modules "" \
    --allowed-paths "" \
    --stage "B" \
    --task-dir "${task_dir}" \
    --skip-clean-check >"${output_file}" 2>&1 || true

scope_prompt="${prompt_dir}/scope.prompt.md"
design_prompt="${prompt_dir}/design.prompt.md"
plan_prompt="${prompt_dir}/plan.prompt.md"
execute_prompt="${prompt_dir}/execute.prompt.md"
summary_prompt="${prompt_dir}/summary.prompt.md"
gap_prompt="${prompt_dir}/gap.prompt.md"

for f in "${scope_prompt}" "${design_prompt}" "${plan_prompt}" "${execute_prompt}" "${summary_prompt}" "${gap_prompt}"; do
  [[ -f "$f" ]] || { echo "missing prompt file: $f"; cat "${output_file}"; exit 1; }
done

expected_scope_file="${workflow_rel}/required-inputs-flow/00-scope-definition.round1.md"
expected_design_file="${workflow_rel}/required-inputs-flow/01-design.round1.md"
expected_plan_file="${workflow_rel}/required-inputs-flow/02-plan.round1.md"
expected_summary_file="${workflow_rel}/required-inputs-flow/05-execution-summary.round1.md"
expected_shared_intent="${workflow_rel}/00-intent.md"

# Design stage must inject intent + scope + design source
grep -q "${expected_shared_intent}" "${design_prompt}" || { echo "design prompt missing shared intent"; cat "${design_prompt}"; exit 1; }
grep -q "${intent_abs}" "${design_prompt}" || { echo "design prompt missing flow intent"; cat "${design_prompt}"; exit 1; }
grep -q "${expected_scope_file}" "${design_prompt}" || { echo "design prompt missing scope file"; cat "${design_prompt}"; exit 1; }
grep -q "${design_doc_abs}" "${design_prompt}" || { echo "design prompt missing design source"; cat "${design_prompt}"; exit 1; }

# Plan stage must inject design file
grep -q "${expected_design_file}" "${plan_prompt}" || { echo "plan prompt missing design file"; cat "${plan_prompt}"; exit 1; }

# Execute stage must inject plan + design
grep -q "${expected_plan_file}" "${execute_prompt}" || { echo "execute prompt missing plan file"; cat "${execute_prompt}"; exit 1; }
grep -q "${expected_design_file}" "${execute_prompt}" || { echo "execute prompt missing design file"; cat "${execute_prompt}"; exit 1; }

# Summary stage must inject design + plan
grep -q "${expected_design_file}" "${summary_prompt}" || { echo "summary prompt missing design file"; cat "${summary_prompt}"; exit 1; }
grep -q "${expected_plan_file}" "${summary_prompt}" || { echo "summary prompt missing plan file"; cat "${summary_prompt}"; exit 1; }

# Gap stage must inject intent + design + summary
grep -q "${expected_shared_intent}" "${gap_prompt}" || { echo "gap prompt missing shared intent"; cat "${gap_prompt}"; exit 1; }
grep -q "${expected_design_file}" "${gap_prompt}" || { echo "gap prompt missing design file"; cat "${gap_prompt}"; exit 1; }
grep -q "${expected_summary_file}" "${gap_prompt}" || { echo "gap prompt missing summary file"; cat "${gap_prompt}"; exit 1; }

echo "PASS: stage prompts inject required GDIM files"
