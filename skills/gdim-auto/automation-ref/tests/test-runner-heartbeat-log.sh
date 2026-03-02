#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_ROUND_SCRIPT="${SCRIPT_DIR}/../run-gdim-round.sh"

tmp_dir="$(mktemp -d)"
workflow_rel=".tmp-gdim-heartbeat-$$"
task_dir="${tmp_dir}/task"
output_file="${tmp_dir}/run.output"

cleanup() {
  rm -rf "${tmp_dir}"
  rm -rf "${PWD}/${workflow_rel}"
}
trap cleanup EXIT

mkdir -p "${tmp_dir}/bin" "${task_dir}/config" "${task_dir}/intents" "${task_dir}/state" "${task_dir}/logs"
mkdir -p "${workflow_rel}/heartbeat-flow"

cat >"${tmp_dir}/bin/codex" <<'EOF'
#!/usr/bin/env bash
sleep 3
cat >/dev/null
exit 0
EOF
chmod +x "${tmp_dir}/bin/codex"

cat >"${task_dir}/config/flows.json" <<'JSON'
{
  "project": "heartbeat",
  "workflow_dir": ".tmp-gdim-heartbeat",
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

cat >"${task_dir}/intents/01-heartbeat.md" <<'MD'
# intent
MD

PATH="${tmp_dir}/bin:${PATH}" GDIM_HEARTBEAT_SECONDS=1 \
  bash "${RUN_ROUND_SCRIPT}" \
    --flow-slug "heartbeat-flow" \
    --max-rounds 1 \
    --workflow-dir "${workflow_rel}/heartbeat-flow" \
    --intent-file "${task_dir}/intents/01-heartbeat.md" \
    --design-doc "docs/design/placeholder.md" \
    --modules "" \
    --allowed-paths "" \
    --stage "B" \
    --task-dir "${task_dir}" \
    --skip-clean-check >"${output_file}" 2>&1 || true

if ! grep -q "Runner still running... elapsed=" "${output_file}"; then
  echo "expected runner heartbeat log while command is running"
  cat "${output_file}"
  exit 1
fi

echo "PASS: runner heartbeat log"
