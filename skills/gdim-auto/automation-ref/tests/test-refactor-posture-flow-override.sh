#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_ROUND_SCRIPT="${SCRIPT_DIR}/../run-gdim-round.sh"

tmp_dir="$(mktemp -d)"
workflow_rel=".tmp-refactor-posture-$$"
task_dir="${tmp_dir}/task"
flow1_prompt_dir="${tmp_dir}/prompts-flow1"
flow2_prompt_dir="${tmp_dir}/prompts-flow2"
flow1_workflow_abs="${PWD}/skills/${workflow_rel}/balanced-flow"
flow2_workflow_abs="${PWD}/skills/${workflow_rel}/aggressive-flow"
design_doc_abs="${tmp_dir}/design.md"
counter_cmd='mkdir -p "$GDIM_PROMPT_CAPTURE_DIR" "$GDIM_TEST_WORKFLOW_DIR"; cat >"$GDIM_PROMPT_CAPTURE_DIR/${CURRENT_STAGE}.prompt.md"; cat >"$GDIM_TEST_WORKFLOW_DIR/00-scope-definition.round1.md" <<"MD"
# scope
MD
cat >"$GDIM_TEST_WORKFLOW_DIR/01-design.round1.md" <<"MD"
# design
MD
cat >"$GDIM_TEST_WORKFLOW_DIR/02-plan.round1.md" <<"MD"
# plan
MD
cat >"$GDIM_TEST_WORKFLOW_DIR/05-execution-summary.round1.md" <<"MD"
# summary
MD
cat >"$GDIM_TEST_WORKFLOW_DIR/03-gap-analysis.round1.md" <<"MD"
# gap
GDIM_EXIT_DECISION: CONTINUE
MD'

cleanup() {
  rm -rf "${tmp_dir}"
  rm -rf "${PWD}/skills/${workflow_rel}"
}
trap cleanup EXIT

mkdir -p "${task_dir}/config" "${task_dir}/intents" "${task_dir}/state" "${task_dir}/logs"
mkdir -p "${flow1_prompt_dir}" "${flow2_prompt_dir}"
mkdir -p "skills/${workflow_rel}/balanced-flow" "skills/${workflow_rel}/aggressive-flow"

cat >"${design_doc_abs}" <<'MD'
# design doc
MD

cat >"${task_dir}/config/flows.json" <<JSON
{
  "project": "refactor-posture",
  "workflow_dir": "${workflow_rel}",
  "design_doc": "${design_doc_abs}",
  "refactor_posture": "balanced",
  "retry_limits": {
    "compile_failed": 0,
    "test_failed": 0,
    "malformed_output": 0
  },
  "flows": [
    {
      "id": 1,
      "slug": "balanced-flow",
      "intent_file": "01-balanced-flow.md",
      "depends_on": [],
      "max_rounds": 1,
      "stage": "B",
      "modules": ["module-a"],
      "allowed_paths": ["module-a/"]
    },
    {
      "id": 2,
      "slug": "aggressive-flow",
      "intent_file": "02-aggressive-flow.md",
      "depends_on": [],
      "max_rounds": 1,
      "stage": "B",
      "refactor_posture": "aggressive",
      "modules": ["module-b"],
      "allowed_paths": ["module-b/"]
    }
  ]
}
JSON

cat >"${task_dir}/intents/01-balanced-flow.md" <<'MD'
# balanced
MD
cat >"${task_dir}/intents/02-aggressive-flow.md" <<'MD'
# aggressive
MD

set +e
GDIM_PROMPT_CAPTURE_DIR="${flow1_prompt_dir}" \
GDIM_TEST_WORKFLOW_DIR="${flow1_workflow_abs}" \
  bash "${RUN_ROUND_SCRIPT}" \
    --flow-slug "balanced-flow" \
    --max-rounds 1 \
    --workflow-dir "${workflow_rel}/balanced-flow" \
    --intent-file "${task_dir}/intents/01-balanced-flow.md" \
    --design-doc "${design_doc_abs}" \
    --modules "" \
    --allowed-paths "" \
    --stage "B" \
    --task-dir "${task_dir}" \
    --runner custom \
    --runner-cmd "${counter_cmd}" \
    --skip-clean-check >/dev/null 2>&1

GDIM_PROMPT_CAPTURE_DIR="${flow2_prompt_dir}" \
GDIM_TEST_WORKFLOW_DIR="${flow2_workflow_abs}" \
  bash "${RUN_ROUND_SCRIPT}" \
    --flow-slug "aggressive-flow" \
    --max-rounds 1 \
    --workflow-dir "${workflow_rel}/aggressive-flow" \
    --intent-file "${task_dir}/intents/02-aggressive-flow.md" \
    --design-doc "${design_doc_abs}" \
    --modules "" \
    --allowed-paths "" \
    --stage "B" \
    --task-dir "${task_dir}" \
    --runner custom \
    --runner-cmd "${counter_cmd}" \
    --skip-clean-check >/dev/null 2>&1
set -e

grep -q "重构姿态: balanced" "${flow1_prompt_dir}/design.prompt.md" || { echo "balanced flow did not inherit task-level balanced posture"; cat "${flow1_prompt_dir}/design.prompt.md"; exit 1; }
grep -q "重构姿态: aggressive" "${flow2_prompt_dir}/design.prompt.md" || { echo "aggressive flow did not apply flow-level override"; cat "${flow2_prompt_dir}/design.prompt.md"; exit 1; }

echo "PASS: flow-level refactor_posture overrides task default"
