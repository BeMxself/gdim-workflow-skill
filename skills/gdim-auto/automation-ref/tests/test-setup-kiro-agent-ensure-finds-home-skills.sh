#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_SCRIPT="${SCRIPT_DIR}/../setup-kiro-agent.sh"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

fake_home="${tmp_dir}/home"
project_root="${tmp_dir}/project"
source_root="${fake_home}/.codex/skills"

mkdir -p "${project_root}" \
  "${source_root}/gdim" \
  "${source_root}/gdim-plan"

cat >"${source_root}/gdim/SKILL.md" <<'MD'
# gdim
MD
cat >"${source_root}/gdim-plan/SKILL.md" <<'MD'
# gdim-plan
MD

HOME="${fake_home}" \
  CODEX_HOME="${fake_home}/.codex" \
  bash "${SETUP_SCRIPT}" --project-root "${project_root}" --ensure >/dev/null

[[ -f "${project_root}/.kiro/agents/gdim-kiro-opus.json" ]] || { echo "missing opus agent"; exit 1; }
[[ -f "${project_root}/.kiro/agents/gdim-kiro-sonnet.json" ]] || { echo "missing sonnet agent"; exit 1; }
[[ -f "${project_root}/.kiro/skills/gdim/SKILL.md" ]] || { echo "missing synced gdim skill from HOME"; exit 1; }
[[ -f "${project_root}/.kiro/skills/gdim-plan/SKILL.md" ]] || { echo "missing synced gdim-plan skill from HOME"; exit 1; }

echo "PASS: setup-kiro-agent --ensure finds and syncs HOME skills source"
