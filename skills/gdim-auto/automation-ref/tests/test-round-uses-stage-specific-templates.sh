#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_ROUND_SCRIPT="${SCRIPT_DIR}/../run-gdim-round.sh"

tmp_dir="$(mktemp -d)"
workflow_rel=".tmp-stage-templates-$$"
task_dir="${tmp_dir}/task"
output_file="${tmp_dir}/run.output"
prompt_dir="${tmp_dir}/prompts"
workflow_abs="${PWD}/skills/${workflow_rel}/template-flow"

cleanup() {
  rm -rf "${tmp_dir}"
  rm -rf "${PWD}/skills/${workflow_rel}"
}
trap cleanup EXIT

mkdir -p "${tmp_dir}/bin" "${task_dir}/config" "${task_dir}/intents" "${task_dir}/state" "${task_dir}/logs" "${prompt_dir}"
mkdir -p "skills/${workflow_rel}/template-flow"

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
  "project": "stage-templates",
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

cat >"${task_dir}/intents/01-template-flow.md" <<'MD'
# intent
MD

PATH="${tmp_dir}/bin:${PATH}" GDIM_HEARTBEAT_SECONDS=0 \
  GDIM_TEST_WORKFLOW_DIR="${workflow_abs}" \
  GDIM_TEST_PROMPT_DIR="${prompt_dir}" \
  bash "${RUN_ROUND_SCRIPT}" \
    --flow-slug "template-flow" \
    --max-rounds 1 \
    --workflow-dir "${workflow_rel}/template-flow" \
    --intent-file "${task_dir}/intents/01-template-flow.md" \
    --design-doc "docs/design/placeholder.md" \
    --modules "" \
    --allowed-paths "" \
    --stage "B" \
    --task-dir "${task_dir}" \
    --skip-clean-check >"${output_file}" 2>&1 || true

for stage in scope design plan execute summary gap; do
  expected_title=""
  case "${stage}" in
    scope) expected_title="## Scope 阶段专用规则" ;;
    design) expected_title="## Design 阶段专用规则" ;;
    plan) expected_title="## Plan 阶段专用规则" ;;
    execute) expected_title="## Execute 阶段专用规则" ;;
    summary) expected_title="## Summary 阶段专用规则" ;;
    gap) expected_title="## Gap 阶段专用规则" ;;
  esac
  prompt_file="${prompt_dir}/${stage}.prompt.md"
  if [ ! -f "${prompt_file}" ]; then
    echo "expected prompt file for stage=${stage}: ${prompt_file}"
    cat "${output_file}"
    exit 1
  fi
  if ! grep -q "${expected_title}" "${prompt_file}"; then
    echo "expected stage-specific template marker missing for stage=${stage}"
    echo "needle: ${expected_title}"
    echo "--- prompt ---"
    cat "${prompt_file}"
    exit 1
  fi
done

echo "PASS: round uses stage-specific prompt templates"
