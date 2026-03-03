#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_ROUND_SCRIPT="${SCRIPT_DIR}/../run-gdim-round.sh"

tmp_dir="$(mktemp -d)"
workflow_rel=".tmp-skip-tests-$$"
task_dir="${tmp_dir}/task"
output_file="${tmp_dir}/run.output"
test_marker="${tmp_dir}/mvn-test-called"
workflow_abs="${PWD}/skills/${workflow_rel}/skip-tests-flow"

cleanup() {
  rm -rf "${tmp_dir}"
  rm -rf "${PWD}/skills/${workflow_rel}"
}
trap cleanup EXIT

mkdir -p "${tmp_dir}/bin" "${task_dir}/config" "${task_dir}/intents" "${task_dir}/state" "${task_dir}/logs"
mkdir -p "skills/${workflow_rel}/skip-tests-flow"

cat >"${tmp_dir}/bin/mvn" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

goal="${1:-}"
marker_file="${GDIM_TEST_MVN_TEST_MARKER:?}"

case "${goal}" in
  compile)
    exit 0
    ;;
  test)
    echo "called" >"${marker_file}"
    echo "mvn test should have been skipped" >&2
    exit 1
    ;;
  *)
    exit 0
    ;;
esac
EOF
chmod +x "${tmp_dir}/bin/mvn"

cat >"${tmp_dir}/bin/codex" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

workflow_dir="${GDIM_TEST_WORKFLOW_DIR:?}"
cat >/dev/null
mkdir -p "${workflow_dir}"
cat >"${workflow_dir}/00-scope.round1.md" <<'MD'
# scope
MD
cat >"${workflow_dir}/01-design.round1.md" <<'MD'
# design
MD
cat >"${workflow_dir}/02-plan.round1.md" <<'MD'
# plan
MD
cat >"${workflow_dir}/03-summary.round1.md" <<'MD'
# summary
MD
cat >"${workflow_dir}/04-gap-analysis.round1.md" <<'MD'
# Gap Analysis
Identified Gaps:
- G1-1 unresolved
MD
exit 0
EOF
chmod +x "${tmp_dir}/bin/codex"

cat >"${task_dir}/config/flows.json" <<JSON
{
  "project": "skip-tests",
  "workflow_dir": "${workflow_rel}",
  "design_doc": "docs/design/placeholder.md",
  "execution": { "runner": "codex" },
  "retry_limits": {
    "compile_failed": 0,
    "test_failed": 2,
    "malformed_output": 0
  },
  "flows": []
}
JSON

cat >"${task_dir}/intents/01-skip-tests-flow.md" <<'MD'
# intent
MD

PATH="${tmp_dir}/bin:${PATH}" \
GDIM_HEARTBEAT_SECONDS=0 \
GDIM_TEST_MVN_TEST_MARKER="${test_marker}" \
GDIM_TEST_WORKFLOW_DIR="${workflow_abs}" \
  bash "${RUN_ROUND_SCRIPT}" \
    --flow-slug "skip-tests-flow" \
    --max-rounds 1 \
    --workflow-dir "${workflow_rel}/skip-tests-flow" \
    --intent-file "${task_dir}/intents/01-skip-tests-flow.md" \
    --design-doc "docs/design/placeholder.md" \
    --modules "fake-module" \
    --allowed-paths "" \
    --stage "B" \
    --task-dir "${task_dir}" \
    --skip-clean-check \
    --skip-tests >"${output_file}" 2>&1 || true

if ! grep -q "Quality gates configured with --skip-tests" "${output_file}"; then
  echo "expected round log to indicate skip-tests mode"
  cat "${output_file}"
  exit 1
fi

if ! grep -q "\[SKIP\] mvn test (disabled by --skip-tests/GDIM_SKIP_TESTS)" "${output_file}"; then
  echo "expected validate result to skip mvn test gate"
  cat "${output_file}"
  exit 1
fi

if [ -f "${test_marker}" ]; then
  echo "mvn test was executed unexpectedly"
  cat "${output_file}"
  exit 1
fi

if grep -q "Retry .*test_failed" "${output_file}"; then
  echo "unexpected test_failed retry while tests are skipped"
  cat "${output_file}"
  exit 1
fi

echo "PASS: --skip-tests bypasses mvn test gate"
