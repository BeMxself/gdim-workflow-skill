#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REF_DIR="${SCRIPT_DIR}/.."

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

project_root="${tmp_dir}/project"
task_dir="${project_root}/task"
workflow_rel=".ai-workflows/test-retry-defaults"
workflow_abs="${project_root}/${workflow_rel}/retry-flow"
output_file="${tmp_dir}/run.output"
compile_count_file="${tmp_dir}/mvn-compile.count"
test_count_file="${tmp_dir}/mvn-test.count"

mkdir -p "${project_root}/automation/ai-coding" "${project_root}/docs/design" "${task_dir}/config" "${task_dir}/intents" "${task_dir}/state" "${task_dir}/logs"
cp "${REF_DIR}/run-gdim-round.sh" "${project_root}/automation/ai-coding/run-gdim-round.sh"
cp -R "${REF_DIR}/lib" "${project_root}/automation/ai-coding/"
cp -R "${REF_DIR}/templates" "${project_root}/automation/ai-coding/"
chmod +x "${project_root}/automation/ai-coding/run-gdim-round.sh"

cat >"${project_root}/docs/design/placeholder.md" <<'MD'
# placeholder
MD

mkdir -p "${tmp_dir}/bin"
cat >"${tmp_dir}/bin/codex" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

workflow_dir="${GDIM_TEST_WORKFLOW_DIR:?}"
stage="${CURRENT_STAGE:-}"

cat >/dev/null
mkdir -p "${workflow_dir}"

if [ "${stage}" = "final" ]; then
  cat >"${workflow_dir}/99-final-report.md" <<'MD'
# final report
MD
  exit 0
fi

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
**Decision**: Generate Final Report
GDIM_EXIT_DECISION: FINAL_REPORT
MD
exit 0
EOF
chmod +x "${tmp_dir}/bin/codex"

cat >"${tmp_dir}/bin/mvn" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

compile_count_file="${GDIM_TEST_MVN_COMPILE_COUNT_FILE:?}"
test_count_file="${GDIM_TEST_MVN_TEST_COUNT_FILE:?}"
goal="${1:-}"

inc_and_read() {
  local file="$1"
  local current=0
  if [ -f "$file" ]; then
    current="$(cat "$file")"
  fi
  current=$((current + 1))
  printf "%s" "$current" >"$file"
  printf "%s" "$current"
}

if [ "$goal" = "compile" ]; then
  n="$(inc_and_read "$compile_count_file")"
  if [ "$n" -eq 1 ]; then
    echo "[ERROR] synthetic compile failure #${n}" >&2
    exit 1
  fi
  exit 0
fi

if [ "$goal" = "test" ]; then
  compile_n=0
  if [ -f "$compile_count_file" ]; then
    compile_n="$(cat "$compile_count_file")"
  fi
  # Do not fail test while compile is still failing in the same validation pass.
  if [ "$compile_n" -lt 2 ]; then
    exit 0
  fi
  n="$(inc_and_read "$test_count_file")"
  if [ "$n" -eq 1 ]; then
    echo "[ERROR] synthetic test failure #${n}" >&2
    exit 1
  fi
  exit 0
fi

exit 0
EOF
chmod +x "${tmp_dir}/bin/mvn"

cat >"${task_dir}/config/flows.json" <<JSON
{
  "project": "retry-defaults",
  "workflow_dir": "${workflow_rel}",
  "design_doc": "docs/design/placeholder.md",
  "execution": { "runner": "codex" },
  "flows": []
}
JSON

cat >"${task_dir}/intents/01-retry-flow.md" <<'MD'
# intent
MD

cat >"${task_dir}/state/.gitignore" <<'EOF'
*
!.gitignore
EOF

cat >"${task_dir}/logs/.gitignore" <<'EOF'
*
!.gitignore
EOF

(
  cd "${project_root}"
  git init >/dev/null
  git config user.email "test@example.com"
  git config user.name "test-user"
  git add .
  git commit -m "init" >/dev/null
)

set +e
(
  cd "${project_root}"
  PATH="${tmp_dir}/bin:${PATH}" \
  GDIM_HEARTBEAT_SECONDS=0 \
  GDIM_TEST_WORKFLOW_DIR="${workflow_abs}" \
  GDIM_TEST_MVN_COMPILE_COUNT_FILE="${compile_count_file}" \
  GDIM_TEST_MVN_TEST_COUNT_FILE="${test_count_file}" \
  bash "automation/ai-coding/run-gdim-round.sh" \
    --flow-slug "retry-flow" \
    --max-rounds 1 \
    --workflow-dir "${workflow_rel}/retry-flow" \
    --intent-file "${task_dir}/intents/01-retry-flow.md" \
    --design-doc "docs/design/placeholder.md" \
    --modules "fake-module" \
    --allowed-paths "${workflow_rel}/retry-flow/" \
    --stage "B" \
    --task-dir "${task_dir}" >"${output_file}" 2>&1
)
exit_code=$?
set -e

if [ "${exit_code}" -ne 0 ]; then
  echo "expected success with compile+test retries, got ${exit_code}"
  cat "${output_file}"
  exit 1
fi

if ! grep -q "Retry 1/5 for compile_failed" "${output_file}"; then
  echo "expected compile retry to use default limit 5"
  cat "${output_file}"
  exit 1
fi

if ! grep -q "Retry 1/5 for test_failed" "${output_file}"; then
  echo "expected test retry to use default limit 5 and independent counting"
  cat "${output_file}"
  exit 1
fi

if grep -q "Retry 2/5 for test_failed" "${output_file}"; then
  echo "test retry counter should be independent from compile retry counter"
  cat "${output_file}"
  exit 1
fi

echo "PASS: retry defaults are 5 and retry counters are independent by failure type"
