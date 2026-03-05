#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REF_DIR="${SCRIPT_DIR}/.."

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

project_root="${tmp_dir}/project"
task_dir="${project_root}/task"
workflow_rel=".ai-workflows/test-cross-round-doc-updates"
workflow_abs="${project_root}/${workflow_rel}/cross-round-flow"
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
round="${CURRENT_ROUND:-1}"
stage="${CURRENT_STAGE:-}"
cat >/dev/null
mkdir -p "${workflow_dir}"

if [ "${stage}" = "final" ]; then
  cat >"${workflow_dir}/99-final-report.md" <<'MD'
# final report
MD
  exit 0
fi

if [ "${round}" = "1" ]; then
  cat >"${workflow_dir}/00-scope-definition.round1.md" <<'MD'
# scope r1
MD
  cat >"${workflow_dir}/01-design.round1.md" <<'MD'
# design r1
MD
  cat >"${workflow_dir}/02-plan.round1.md" <<'MD'
# plan r1
MD
  cat >"${workflow_dir}/05-execution-summary.round1.md" <<'MD'
# summary r1
MD
  cat >"${workflow_dir}/03-gap-analysis.round1.md" <<'MD'
# gap r1
GDIM_EXIT_DECISION: CONTINUE
MD
  exit 0
fi

# Round 2: intentionally modify round1 summary + create flow-local 00-intent.md
cat >"${workflow_dir}/00-intent.md" <<'MD'
# flow local intent copy
MD
cat >"${workflow_dir}/05-execution-summary.round1.md" <<'MD'
# summary r1 (updated in r2)
MD
cat >"${workflow_dir}/00-scope-definition.round2.md" <<'MD'
# scope r2
MD
cat >"${workflow_dir}/01-design.round2.md" <<'MD'
# design r2
MD
cat >"${workflow_dir}/02-plan.round2.md" <<'MD'
# plan r2
MD
cat >"${workflow_dir}/05-execution-summary.round2.md" <<'MD'
# summary r2
MD
cat >"${workflow_dir}/03-gap-analysis.round2.md" <<'MD'
# gap r2
GDIM_EXIT_DECISION: FINAL_REPORT
MD
exit 0
EOF
chmod +x "${tmp_dir}/bin/codex"

cat >"${task_dir}/config/flows.json" <<JSON
{
  "project": "cross-round-doc-updates",
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

cat >"${task_dir}/intents/01-cross-round-flow.md" <<'MD'
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
    --flow-slug "cross-round-flow" \
    --max-rounds 2 \
    --workflow-dir "${workflow_rel}/cross-round-flow" \
    --intent-file "${task_dir}/intents/01-cross-round-flow.md" \
    --design-doc "docs/design/placeholder.md" \
    --modules "" \
    --allowed-paths "${workflow_rel}/cross-round-flow/" \
    --stage "B" \
    --task-dir "${task_dir}" >"${output_file}" 2>&1
)
exit_code=$?
set -e

if [ "${exit_code}" -ne 0 ]; then
  echo "expected success, got ${exit_code}"
  cat "${output_file}"
  exit 1
fi

if [ -n "$(git -C "${project_root}" status --porcelain)" ]; then
  echo "expected clean workspace after cross-round doc updates"
  git -C "${project_root}" status --short
  cat "${output_file}"
  exit 1
fi

if ! git -C "${project_root}" ls-files --error-unmatch "${workflow_rel}/cross-round-flow/00-intent.md" >/dev/null 2>&1; then
  echo "expected flow-local 00-intent.md to be committed"
  git -C "${project_root}" ls-files
  exit 1
fi

echo "PASS: auto-commit captures cross-round flow doc updates and keeps workspace clean"
