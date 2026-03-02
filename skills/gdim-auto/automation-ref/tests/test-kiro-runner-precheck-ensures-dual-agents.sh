#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER_LIB="${SCRIPT_DIR}/../lib/runner.sh"
SETUP_SCRIPT="${SCRIPT_DIR}/../setup-kiro-agent.sh"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

mkdir -p "${tmp_dir}/bin" "${tmp_dir}/project"

cat >"${tmp_dir}/bin/kiro-cli" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "${tmp_dir}/bin/kiro-cli"

export PATH="${tmp_dir}/bin:${PATH}"

# shellcheck disable=SC1090
source "${RUNNER_LIB}"

if ! ensure_runner_ready "kiro" "" "${tmp_dir}/project" "${SETUP_SCRIPT}" "gdim-kiro-opus" "sonnet"; then
  echo "expected kiro runner precheck success"
  exit 1
fi

opus_agent="${tmp_dir}/project/.kiro/agents/gdim-kiro-opus.json"
sonnet_agent="${tmp_dir}/project/.kiro/agents/gdim-kiro-sonnet.json"

[[ -f "${opus_agent}" ]] || { echo "missing opus agent"; exit 1; }
[[ -f "${sonnet_agent}" ]] || { echo "missing sonnet agent"; exit 1; }

echo "PASS: kiro runner precheck ensures dual agents"
