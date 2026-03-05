#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_ROUND_SCRIPT="${SCRIPT_DIR}/../run-gdim-round.sh"

tmp_dir="$(mktemp -d)"
workflow_rel=".tmp-gap-final-modules-$$"
task_dir="${tmp_dir}/task"
output_file="${tmp_dir}/run.output"
workflow_abs="${PWD}/skills/${workflow_rel}/gap-final-modules-flow"

cleanup() {
  rm -rf "${tmp_dir}"
  rm -rf "${PWD}/skills/${workflow_rel}"
}
trap cleanup EXIT

mkdir -p "${tmp_dir}/bin" "${task_dir}/config" "${task_dir}/intents" "${task_dir}/state" "${task_dir}/logs"
mkdir -p "skills/${workflow_rel}/gap-final-modules-flow"

cat >"${tmp_dir}/bin/mvn" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
chmod +x "${tmp_dir}/bin/mvn"

cat >"${tmp_dir}/bin/codex" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

workflow_dir="${GDIM_TEST_WORKFLOW_DIR:?}"
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
# Gap Analysis - Round 1

## 1. Round Gap (This Round's Deviations)
- 无新增偏差

## 2. Intent Coverage (Overall Progress)
**Coverage**: 100%

## 4. Exit Decision
- [x] No High Severity Gap in this round
- [x] Intent fully covered (100%)

**Decision**: Generate Final Report
GDIM_EXIT_DECISION: FINAL_REPORT
MD
exit 0
EOF
chmod +x "${tmp_dir}/bin/codex"

cat >"${task_dir}/config/flows.json" <<JSON
{
  "project": "gap-final-modules",
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

cat >"${task_dir}/intents/01-gap-final-modules-flow.md" <<'MD'
# intent
MD

set +e
PATH="${tmp_dir}/bin:${PATH}" \
GDIM_HEARTBEAT_SECONDS=0 \
GDIM_TEST_WORKFLOW_DIR="${workflow_abs}" \
  bash "${RUN_ROUND_SCRIPT}" \
    --flow-slug "gap-final-modules-flow" \
    --max-rounds 1 \
    --workflow-dir "${workflow_rel}/gap-final-modules-flow" \
    --intent-file "${task_dir}/intents/01-gap-final-modules-flow.md" \
    --design-doc "docs/design/placeholder.md" \
    --modules "fake-module" \
    --allowed-paths "" \
    --stage "B" \
    --task-dir "${task_dir}" \
    --skip-clean-check >"${output_file}" 2>&1
exit_code=$?
set -e

if [ "${exit_code}" -ne 0 ]; then
  echo "expected exit code 0 for FINAL_REPORT with no commit and modules, got ${exit_code}"
  cat "${output_file}"
  exit 1
fi

if ! grep -q "accepting explicit final decision" "${output_file}"; then
  echo "expected explicit final decision acceptance log"
  cat "${output_file}"
  exit 1
fi

echo "PASS: final decision closes without commit even when modules configured"
