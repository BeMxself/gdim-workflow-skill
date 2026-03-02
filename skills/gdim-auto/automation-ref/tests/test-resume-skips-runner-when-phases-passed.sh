#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_ROUND_SCRIPT="${SCRIPT_DIR}/../run-gdim-round.sh"

tmp_dir="$(mktemp -d)"
workflow_rel=".tmp-resume-skip-runner-$$"
task_dir="${tmp_dir}/task"
output_file="${tmp_dir}/run.output"
runner_called_file="${tmp_dir}/runner.called"
state_file="${task_dir}/state/resume-flow/round-state.json"

cleanup() {
  rm -rf "${tmp_dir}"
  rm -rf "${PWD}/skills/${workflow_rel}"
}
trap cleanup EXIT

mkdir -p "${tmp_dir}/bin" "${task_dir}/config" "${task_dir}/intents" "${task_dir}/state/resume-flow" "${task_dir}/logs"
mkdir -p "skills/${workflow_rel}/resume-flow"

cat >"${tmp_dir}/bin/codex" <<EOF
#!/usr/bin/env bash
echo called >"${runner_called_file}"
cat >/dev/null
exit 0
EOF
chmod +x "${tmp_dir}/bin/codex"

cat >"${task_dir}/config/flows.json" <<JSON
{
  "project": "resume-skip-runner",
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

cat >"${task_dir}/intents/01-resume-flow.md" <<'MD'
# intent
MD

cat >"${state_file}" <<'JSON'
{
  "current_round": 1,
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

PATH="${tmp_dir}/bin:${PATH}" GDIM_HEARTBEAT_SECONDS=0 \
  bash "${RUN_ROUND_SCRIPT}" \
    --flow-slug "resume-flow" \
    --max-rounds 1 \
    --workflow-dir "${workflow_rel}/resume-flow" \
    --intent-file "${task_dir}/intents/01-resume-flow.md" \
    --design-doc "docs/design/placeholder.md" \
    --modules "" \
    --allowed-paths "" \
    --stage "B" \
    --task-dir "${task_dir}" \
    --skip-clean-check >"${output_file}" 2>&1 || true

if ! grep -q "Skipping runner due phase checkpoint and resuming from quality gates" "${output_file}"; then
  echo "expected resume to skip runner when all phases are passed"
  cat "${output_file}"
  exit 1
fi

if [ -f "${runner_called_file}" ]; then
  echo "runner should not be invoked when resuming from quality gates"
  cat "${output_file}"
  exit 1
fi

if ! jq -e '.events[] | select(.event == "runner_skipped_by_resume")' "${state_file}" >/dev/null 2>&1; then
  echo "expected runner_skipped_by_resume event in round-state"
  cat "${state_file}"
  exit 1
fi

echo "PASS: resume skips runner when phases already passed"
