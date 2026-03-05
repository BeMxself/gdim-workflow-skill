#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REF_DIR="${SCRIPT_DIR}/.."

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

project_root="${tmp_dir}/project"
task_dir="${project_root}/task"
workflow_rel=".ai-workflows/test-auto-commit"
workflow_abs="${project_root}/${workflow_rel}/auto-commit-flow"
output_file="${tmp_dir}/run.output"

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
**Decision**: Generate Final Report
GDIM_EXIT_DECISION: FINAL_REPORT
MD
exit 0
EOF
chmod +x "${tmp_dir}/bin/codex"

cat >"${task_dir}/config/flows.json" <<JSON
{
  "project": "auto-commit",
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

cat >"${task_dir}/intents/01-auto-commit-flow.md" <<'MD'
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
  bash "automation/ai-coding/run-gdim-round.sh" \
    --flow-slug "auto-commit-flow" \
    --max-rounds 1 \
    --workflow-dir "${workflow_rel}/auto-commit-flow" \
    --intent-file "${task_dir}/intents/01-auto-commit-flow.md" \
    --design-doc "docs/design/placeholder.md" \
    --modules "" \
    --allowed-paths "${workflow_rel}/auto-commit-flow/" \
    --stage "B" \
    --task-dir "${task_dir}" >"${output_file}" 2>&1
)
exit_code=$?
set -e

if [ "${exit_code}" -ne 0 ]; then
  echo "expected success with default auto-commit, got ${exit_code}"
  cat "${output_file}"
  exit 1
fi

if ! grep -q "Auto-committed GDIM docs" "${output_file}"; then
  echo "expected auto-commit log in output"
  cat "${output_file}"
  exit 1
fi

last_msg="$(git -C "${project_root}" log -1 --pretty=%s)"
if [[ "${last_msg}" != "gdim(auto-commit-flow): R1 docs checkpoint" ]]; then
  echo "unexpected last commit message: ${last_msg}"
  git -C "${project_root}" log --oneline -3
  exit 1
fi

echo "PASS: default auto-commit gdim docs"
