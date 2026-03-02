#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_ROUND_SCRIPT="${SCRIPT_DIR}/../run-gdim-round.sh"

tmp_dir="$(mktemp -d)"
workflow_rel=".tmp-state-events-$$"
task_dir="${tmp_dir}/task"
output_file="${tmp_dir}/run.output"
state_file="${task_dir}/state/event-flow/round-state.json"

cleanup() {
  rm -rf "${tmp_dir}"
  rm -rf "${PWD}/skills/${workflow_rel}"
}
trap cleanup EXIT

mkdir -p "${tmp_dir}/bin" "${task_dir}/config" "${task_dir}/intents" "${task_dir}/state" "${task_dir}/logs"
mkdir -p "skills/${workflow_rel}/event-flow"

cat >"${tmp_dir}/bin/codex" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
exit 0
EOF
chmod +x "${tmp_dir}/bin/codex"

cat >"${task_dir}/config/flows.json" <<JSON
{
  "project": "state-events",
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

cat >"${task_dir}/intents/01-event-flow.md" <<'MD'
# intent
MD

PATH="${tmp_dir}/bin:${PATH}" GDIM_HEARTBEAT_SECONDS=0 \
  bash "${RUN_ROUND_SCRIPT}" \
    --flow-slug "event-flow" \
    --max-rounds 1 \
    --workflow-dir "${workflow_rel}/event-flow" \
    --intent-file "${task_dir}/intents/01-event-flow.md" \
    --design-doc "docs/design/placeholder.md" \
    --modules "" \
    --allowed-paths "" \
    --stage "B" \
    --task-dir "${task_dir}" \
    --skip-clean-check >"${output_file}" 2>&1 || true

if [ ! -f "${state_file}" ]; then
  echo "expected round-state file: ${state_file}"
  cat "${output_file}"
  exit 1
fi

if ! jq -e '.events | length >= 5' "${state_file}" >/dev/null 2>&1; then
  echo "expected granular events in round-state.json"
  cat "${state_file}"
  exit 1
fi

for event_name in round_started runner_invoking runner_completed quality_gates_started quality_gates_finished round_blocked; do
  if ! jq -e --arg e "${event_name}" '.events[] | select(.event == $e)' "${state_file}" >/dev/null 2>&1; then
    echo "expected event: ${event_name}"
    cat "${state_file}"
    exit 1
  fi
done

echo "PASS: round-state records granular progress events"
