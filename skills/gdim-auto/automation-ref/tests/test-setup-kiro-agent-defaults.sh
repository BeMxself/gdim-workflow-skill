#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_SCRIPT="${SCRIPT_DIR}/../setup-kiro-agent.sh"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

bash "${SETUP_SCRIPT}" --project-root "${tmp_dir}" >/dev/null

opus_agent="${tmp_dir}/.kiro/agents/gdim-kiro-opus.json"
sonnet_agent="${tmp_dir}/.kiro/agents/gdim-kiro-sonnet.json"

[[ -f "${opus_agent}" ]] || { echo "expected opus agent file: ${opus_agent}"; exit 1; }
[[ -f "${sonnet_agent}" ]] || { echo "expected sonnet agent file: ${sonnet_agent}"; exit 1; }

opus_model="$(jq -r '.model // ""' "${opus_agent}")"
sonnet_model="$(jq -r '.model // ""' "${sonnet_agent}")"
[[ "${opus_model}" == "claude-opus-4.6" ]] || { echo "unexpected opus model: ${opus_model}"; exit 1; }
[[ "${sonnet_model}" == "claude-sonnet-4.6" ]] || { echo "unexpected sonnet model: ${sonnet_model}"; exit 1; }

opus_has_tools="$(jq -r '(.tools // []) | index("*") != null' "${opus_agent}")"
sonnet_has_tools="$(jq -r '(.tools // []) | index("*") != null' "${sonnet_agent}")"
[[ "${opus_has_tools}" == "true" ]] || { echo "opus agent must include wildcard tools"; exit 1; }
[[ "${sonnet_has_tools}" == "true" ]] || { echo "sonnet agent must include wildcard tools"; exit 1; }

opus_has_skill_resource="$(jq -r '(.resources // []) | index("skill://~/.kiro/skills/**/SKILL.md") != null' "${opus_agent}")"
sonnet_has_skill_resource="$(jq -r '(.resources // []) | index("skill://~/.kiro/skills/**/SKILL.md") != null' "${sonnet_agent}")"
[[ "${opus_has_skill_resource}" == "true" ]] || { echo "opus agent missing skill resource"; exit 1; }
[[ "${sonnet_has_skill_resource}" == "true" ]] || { echo "sonnet agent missing skill resource"; exit 1; }

echo "PASS: setup-kiro-agent defaults"
