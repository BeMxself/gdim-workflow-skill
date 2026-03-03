#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_ROUND_SCRIPT="${SCRIPT_DIR}/../run-gdim-round.sh"

tmp_dir="$(mktemp -d)"
workflow_rel=".tmp-gap-keyword-$$"
task_dir="${tmp_dir}/task"
output_file="${tmp_dir}/run.output"
workflow_abs="${PWD}/skills/${workflow_rel}/gap-keyword-flow"

cleanup() {
  rm -rf "${tmp_dir}"
  rm -rf "${PWD}/skills/${workflow_rel}"
}
trap cleanup EXIT

mkdir -p "${tmp_dir}/bin" "${task_dir}/config" "${task_dir}/intents" "${task_dir}/state" "${task_dir}/logs"
mkdir -p "skills/${workflow_rel}/gap-keyword-flow"

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

## 1. Round Gap

### GAP-01: compile gate issue (BLOCKED)
| Field | Content |
|-------|---------|
| Severity | High |
| Status | BLOCKED |

## 4. Exit Decision

- [x] High Severity Gap exists
- [ ] Intent fully covered (100%)

**Decision**: Continue to Round 2
GDIM_EXIT_DECISION: CONTINUE
MD
exit 0
EOF
chmod +x "${tmp_dir}/bin/codex"

cat >"${task_dir}/config/flows.json" <<JSON
{
  "project": "gap-keyword",
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

cat >"${task_dir}/intents/01-gap-keyword-flow.md" <<'MD'
# intent
MD

set +e
PATH="${tmp_dir}/bin:${PATH}" \
GDIM_HEARTBEAT_SECONDS=0 \
GDIM_TEST_WORKFLOW_DIR="${workflow_abs}" \
  bash "${RUN_ROUND_SCRIPT}" \
    --flow-slug "gap-keyword-flow" \
    --max-rounds 1 \
    --workflow-dir "${workflow_rel}/gap-keyword-flow" \
    --intent-file "${task_dir}/intents/01-gap-keyword-flow.md" \
    --design-doc "docs/design/placeholder.md" \
    --modules "" \
    --allowed-paths "" \
    --stage "B" \
    --task-dir "${task_dir}" \
    --skip-clean-check >"${output_file}" 2>&1
exit_code=$?
set -e

if [ "${exit_code}" -eq 1 ]; then
  echo "unexpected blocked exit caused by BLOCKED keyword in gap body"
  cat "${output_file}"
  exit 1
fi

if ! grep -q "Reached max rounds (1)" "${output_file}"; then
  echo "expected normal max-rounds exit path instead of blocked"
  cat "${output_file}"
  exit 1
fi

if grep -q "BLOCKED detected in gap analysis" "${output_file}"; then
  echo "unexpected blocked detection from gap keyword"
  cat "${output_file}"
  exit 1
fi

echo "PASS: gap keyword BLOCKED does not force block when exit decision is Continue"
