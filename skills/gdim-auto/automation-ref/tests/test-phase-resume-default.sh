#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_ROUND_SCRIPT="${SCRIPT_DIR}/../run-gdim-round.sh"

tmp_dir="$(mktemp -d)"
workflow_rel=".tmp-phase-resume-$$"
task_dir="${tmp_dir}/task"
output_file="${tmp_dir}/run.output"

cleanup() {
  rm -rf "${tmp_dir}"
  rm -rf "${PWD}/${workflow_rel}"
}
trap cleanup EXIT

mkdir -p "${task_dir}/config" "${task_dir}/intents" "${task_dir}/state/phase-flow" "${task_dir}/logs"
mkdir -p "${workflow_rel}/phase-flow"

cat >"${task_dir}/config/flows.json" <<JSON
{
  "project": "phase-resume",
  "workflow_dir": "${workflow_rel}",
  "design_doc": "docs/design/placeholder.md",
  "execution": { "runner": "claude" },
  "retry_limits": {
    "compile_failed": 1,
    "test_failed": 1,
    "malformed_output": 1
  },
  "flows": [
    {
      "id": 1,
      "slug": "phase-flow",
      "intent_file": "01-phase-flow.md",
      "depends_on": [],
      "max_rounds": 1,
      "stage": "B",
      "modules": ["module-a"],
      "allowed_paths": ["module-a/"]
    }
  ]
}
JSON

cat >"${task_dir}/intents/01-phase-flow.md" <<'MD'
# intent
MD

cat >"${task_dir}/state/phase-flow/round-state.json" <<'JSON'
{
  "current_round": 1,
  "stall_count": 0,
  "phases": {
    "R1": {
      "scope": "passed",
      "design": "passed",
      "plan": "passed",
      "execute": "missing",
      "summary": "missing",
      "gap": "missing"
    }
  }
}
JSON

bash "${RUN_ROUND_SCRIPT}" \
  --flow-slug "phase-flow" \
  --max-rounds 1 \
  --workflow-dir "${workflow_rel}/phase-flow" \
  --intent-file "${task_dir}/intents/01-phase-flow.md" \
  --design-doc "docs/design/placeholder.md" \
  --modules "module-a" \
  --allowed-paths "module-a/" \
  --stage "B" \
  --task-dir "${task_dir}" \
  --dry-run >"${output_file}" 2>&1

if ! grep -q "Phase-resume checkpoint for R1: start from execute" "${output_file}"; then
  echo "expected phase-granular resume from execute"
  cat "${output_file}"
  exit 1
fi

echo "PASS: phase-granular resume default"
