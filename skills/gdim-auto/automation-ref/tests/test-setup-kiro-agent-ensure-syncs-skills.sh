#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_SCRIPT="${SCRIPT_DIR}/../setup-kiro-agent.sh"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

fake_home="${tmp_dir}/home"
project_root="${tmp_dir}/project"
skills_source="${tmp_dir}/skills-source"

mkdir -p "${project_root}" \
  "${skills_source}/gdim" \
  "${skills_source}/gdim-scope" \
  "${skills_source}/gdim-design"

cat >"${skills_source}/gdim/SKILL.md" <<'MD'
# gdim
MD
cat >"${skills_source}/gdim-scope/SKILL.md" <<'MD'
# gdim-scope
MD
cat >"${skills_source}/gdim-design/SKILL.md" <<'MD'
# gdim-design
MD

HOME="${fake_home}" \
CODEX_HOME="${fake_home}/.codex" \
GDIM_SKILLS_SOURCE_DIR="${skills_source}" \
  bash "${SETUP_SCRIPT}" --project-root "${project_root}" --ensure >/dev/null

opus_agent="${project_root}/.kiro/agents/gdim-kiro-opus.json"
sonnet_agent="${project_root}/.kiro/agents/gdim-kiro-sonnet.json"
[[ -f "${opus_agent}" ]] || { echo "expected opus agent"; exit 1; }
[[ -f "${sonnet_agent}" ]] || { echo "expected sonnet agent"; exit 1; }

[[ -f "${fake_home}/.kiro/skills/gdim/SKILL.md" ]] || { echo "expected synced gdim skill"; exit 1; }
[[ -f "${fake_home}/.kiro/skills/gdim-scope/SKILL.md" ]] || { echo "expected synced gdim-scope skill"; exit 1; }
[[ -f "${fake_home}/.kiro/skills/gdim-design/SKILL.md" ]] || { echo "expected synced gdim-design skill"; exit 1; }

echo "PASS: setup-kiro-agent --ensure syncs gdim skills into ~/.kiro/skills"
