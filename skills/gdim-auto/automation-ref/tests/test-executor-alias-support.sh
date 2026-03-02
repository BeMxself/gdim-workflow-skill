#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_FLOWS_SCRIPT="${SCRIPT_DIR}/../run-gdim-flows.sh"

tmp_dir="$(mktemp -d)"
workflow_rel=".tmp-gdim-executor-alias-$$"
task_dir="${tmp_dir}/task"
log_file="${tmp_dir}/run.log"

cleanup() {
  rm -rf "${tmp_dir}"
  rm -rf "${PWD}/${workflow_rel}"
}
trap cleanup EXIT

mkdir -p "${task_dir}/config" "${task_dir}/intents" "${task_dir}/state" "${task_dir}/logs"

cat >"${task_dir}/config/flows.json" <<JSON
{
  "project": "executor-alias",
  "workflow_dir": "${workflow_rel}",
  "design_doc": "docs/design/placeholder.md",
  "executor": "codex",
  "retry_limits": {
    "compile_failed": 1,
    "test_failed": 1,
    "malformed_output": 1
  },
  "flows": [
    {
      "id": 1,
      "slug": "alias-check",
      "intent_file": "01-alias-check.md",
      "depends_on": [],
      "max_rounds": 1,
      "stage": "B",
      "modules": ["module-a"],
      "allowed_paths": ["module-a/"]
    }
  ]
}
JSON

cat >"${task_dir}/intents/01-alias-check.md" <<'MD'
# intent
MD

bash "${RUN_FLOWS_SCRIPT}" --task-dir "${task_dir}" --dry-run >"${log_file}" 2>&1

if ! grep -q "runner=codex" "${log_file}"; then
  echo "expected runner=codex when top-level executor=codex is set"
  cat "${log_file}"
  exit 1
fi

echo "PASS: executor alias support"
