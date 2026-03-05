#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_SCRIPT="${SCRIPT_DIR}/../setup-kiro-agent.sh"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

fake_home="${tmp_dir}/home"
project_root="${tmp_dir}/project"
copied_script="${project_root}/setup-kiro-agent.sh"
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

cp "${SETUP_SCRIPT}" "${copied_script}"
chmod +x "${copied_script}"

(
  cd "${project_root}"
  HOME="${fake_home}" \
    CODEX_HOME="${fake_home}/.codex" \
    bash "./setup-kiro-agent.sh" --ensure >/dev/null
)

[[ -f "${project_root}/.kiro/agents/gdim-kiro-opus.json" ]] || { echo "missing opus agent in copied-script project root"; exit 1; }
[[ -f "${project_root}/.kiro/agents/gdim-kiro-sonnet.json" ]] || { echo "missing sonnet agent in copied-script project root"; exit 1; }
[[ -f "${fake_home}/.kiro/skills/gdim/SKILL.md" ]] || { echo "missing synced gdim skill in HOME"; exit 1; }
[[ -f "${fake_home}/.kiro/skills/gdim-plan/SKILL.md" ]] || { echo "missing synced gdim-plan skill in HOME"; exit 1; }

[[ ! -f "${tmp_dir}/.kiro/agents/gdim-kiro-opus.json" ]] || { echo "unexpected opus agent outside project root"; exit 1; }
[[ ! -f "${project_root}/.kiro/skills/gdim/SKILL.md" ]] || { echo "unexpected project-local gdim skill copy"; exit 1; }

echo "PASS: copied setup-kiro-agent defaults project root to script directory"
