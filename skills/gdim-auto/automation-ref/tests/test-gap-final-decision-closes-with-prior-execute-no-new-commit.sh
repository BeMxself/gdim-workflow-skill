#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_ROUND_SCRIPT="${SCRIPT_DIR}/../run-gdim-round.sh"

tmp_dir="$(mktemp -d)"
workflow_rel=".tmp-gap-final-prior-exec-$$"
task_dir="${tmp_dir}/task"
output_file="${tmp_dir}/run.output"
workflow_abs="${PWD}/skills/${workflow_rel}/gap-final-prior-flow"

cleanup() {
  rm -rf "${tmp_dir}"
  rm -rf "${PWD}/skills/${workflow_rel}"
}
trap cleanup EXIT

mkdir -p "${tmp_dir}/bin" "${task_dir}/config" "${task_dir}/intents" "${task_dir}/state/gap-final-prior-flow" "${task_dir}/logs"
mkdir -p "skills/${workflow_rel}/gap-final-prior-flow"

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
cat >"${workflow_dir}/00-scope-definition.round2.md" <<'MD'
# scope
MD
cat >"${workflow_dir}/01-design.round2.md" <<'MD'
# design
MD
cat >"${workflow_dir}/02-plan.round2.md" <<'MD'
# plan
MD
cat >"${workflow_dir}/05-execution-summary.round2.md" <<'MD'
# summary
MD
cat >"${workflow_dir}/03-gap-analysis.round2.md" <<'MD'
# Gap Analysis - Round 2

## 1. Round Gap (This Round's Deviations)
- 无新增偏差

## 2. Intent Coverage (Overall Progress)
**Coverage**: 100%

## 4. Exit Decision
- [x] No High Severity Gap in this round
- [x] Intent fully covered (100%)

**Decision**: Generate Final Report
MD
exit 0
EOF
chmod +x "${tmp_dir}/bin/codex"

cat >"${task_dir}/config/flows.json" <<JSON
{
  "project": "gap-final-prior",
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

cat >"${task_dir}/intents/01-gap-final-prior-flow.md" <<'MD'
# intent
MD

# Seed prior round execute progress to emulate earlier meaningful code round.
cat >"${task_dir}/state/gap-final-prior-flow/round-state.json" <<'JSON'
{
  "current_round": 2,
  "stall_count": 0,
  "phases": {
    "R1": {
      "scope": "passed",
      "design": "passed",
      "plan": "passed",
      "execute": "passed",
      "summary": "passed",
      "gap": "passed"
    }
  }
}
JSON

set +e
PATH="${tmp_dir}/bin:${PATH}" \
GDIM_HEARTBEAT_SECONDS=0 \
GDIM_TEST_WORKFLOW_DIR="${workflow_abs}" \
  bash "${RUN_ROUND_SCRIPT}" \
    --flow-slug "gap-final-prior-flow" \
    --max-rounds 2 \
    --workflow-dir "${workflow_rel}/gap-final-prior-flow" \
    --intent-file "${task_dir}/intents/01-gap-final-prior-flow.md" \
    --design-doc "docs/design/placeholder.md" \
    --modules "fake-module" \
    --allowed-paths "" \
    --stage "B" \
    --task-dir "${task_dir}" \
    --skip-clean-check >"${output_file}" 2>&1
exit_code=$?
set -e

if [ "${exit_code}" -ne 0 ]; then
  echo "expected exit code 0 with final decision + prior execute progress, got ${exit_code}"
  cat "${output_file}"
  exit 1
fi

if ! grep -q "accepting explicit final decision" "${output_file}"; then
  echo "expected final decision acceptance log when no new commit in current round"
  cat "${output_file}"
  exit 1
fi

echo "PASS: final decision closes with prior execute progress and no new commit"
