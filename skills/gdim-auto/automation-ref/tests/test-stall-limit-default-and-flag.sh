#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_ROUND_SCRIPT="${SCRIPT_DIR}/../run-gdim-round.sh"

tmp_dir="$(mktemp -d)"
workflow_rel=".tmp-stall-limit-$$"

cleanup() {
  rm -rf "${tmp_dir}"
  rm -rf "${PWD}/skills/${workflow_rel}"
}
trap cleanup EXIT

mkdir -p "${tmp_dir}/bin" "skills/${workflow_rel}"

cat >"${tmp_dir}/bin/codex" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cat >/dev/null
exit 0
EOF
chmod +x "${tmp_dir}/bin/codex"

prepare_round_files() {
  local workflow_abs="$1"
  local max_round="$2"
  local r=0
  mkdir -p "${workflow_abs}"
  for ((r=1; r<=max_round; r++)); do
    cat >"${workflow_abs}/00-scope-definition.round${r}.md" <<MD
# scope ${r}
MD
    cat >"${workflow_abs}/01-design.round${r}.md" <<MD
# design ${r}
MD
    cat >"${workflow_abs}/02-plan.round${r}.md" <<MD
# plan ${r}
MD
    cat >"${workflow_abs}/05-execution-summary.round${r}.md" <<MD
# summary ${r}
MD
    cat >"${workflow_abs}/03-gap-analysis.round${r}.md" <<MD
# Gap Analysis - Round ${r}

## 4. Exit Decision
**Decision**: Continue to Round $((r + 1))
GDIM_EXIT_DECISION: CONTINUE
MD
  done
}

run_case() {
  local case_name="$1"
  local extra_arg="$2"
  local expected_exit="$3"
  local expected_log="$4"
  local task_dir="${tmp_dir}/${case_name}/task"
  local output_file="${tmp_dir}/${case_name}/run.output"
  local workflow_abs="${PWD}/skills/${workflow_rel}/${case_name}-flow"

  mkdir -p "${task_dir}/config" "${task_dir}/intents" "${task_dir}/state" "${task_dir}/logs"
  prepare_round_files "${workflow_abs}" 5

  cat >"${task_dir}/config/flows.json" <<JSON
{
  "project": "${case_name}",
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

  cat >"${task_dir}/intents/01-${case_name}-flow.md" <<'MD'
# intent
MD

  set +e
  PATH="${tmp_dir}/bin:${PATH}" \
  GDIM_HEARTBEAT_SECONDS=0 \
    bash "${RUN_ROUND_SCRIPT}" \
      --flow-slug "${case_name}-flow" \
      --max-rounds 4 \
      --workflow-dir "${workflow_rel}/${case_name}-flow" \
      --intent-file "${task_dir}/intents/01-${case_name}-flow.md" \
      --design-doc "docs/design/placeholder.md" \
      --modules "" \
      --allowed-paths "" \
      --stage "B" \
      --task-dir "${task_dir}" \
      --skip-clean-check \
      ${extra_arg} >"${output_file}" 2>&1
  exit_code=$?
  set -e

  if [ "${exit_code}" -ne "${expected_exit}" ]; then
    echo "case=${case_name} expected exit=${expected_exit}, got=${exit_code}"
    cat "${output_file}"
    exit 1
  fi
  if ! grep -q "${expected_log}" "${output_file}"; then
    echo "case=${case_name} expected log not found: ${expected_log}"
    cat "${output_file}"
    exit 1
  fi
}

run_case "stall-default" "" 2 "Reached max rounds (4)"
run_case "stall-override" "--stall-limit 2" 3 "Stalled: 2 consecutive rounds with no progress"

echo "PASS: stall-limit default and flag override"
