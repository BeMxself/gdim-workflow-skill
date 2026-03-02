#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER_LIB="${SCRIPT_DIR}/../lib/runner.sh"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

mkdir -p "${tmp_dir}/bin" "${tmp_dir}/workdir"

cat >"${tmp_dir}/bin/codex" <<'EOF'
#!/usr/bin/env bash
echo "$*" >"${CODEX_ARGS_FILE}"
cat >/dev/null
exit 0
EOF

cat >"${tmp_dir}/bin/kiro-cli" <<'EOF'
#!/usr/bin/env bash
echo "$*" >"${KIRO_ARGS_FILE}"
exit 0
EOF

chmod +x "${tmp_dir}/bin/codex" "${tmp_dir}/bin/kiro-cli"

export PATH="${tmp_dir}/bin:${PATH}"
export CODEX_ARGS_FILE="${tmp_dir}/codex.args"
export KIRO_ARGS_FILE="${tmp_dir}/kiro.args"

prompt_file="${tmp_dir}/prompt.txt"
printf '%s\n' 'hello runner' >"${prompt_file}"

[ -f "${RUNNER_LIB}" ] || { echo "runner lib not found: ${RUNNER_LIB}"; exit 1; }

# shellcheck disable=SC1090
source "${RUNNER_LIB}"

run_runner "codex" "${prompt_file}" "${tmp_dir}/codex.log" "1" "${tmp_dir}/workdir" "" ""
if ! grep -q "exec -" "${CODEX_ARGS_FILE}"; then
  echo "expected codex built-in command"
  exit 1
fi

run_runner "kiro" "${prompt_file}" "${tmp_dir}/kiro.log" "1" "${tmp_dir}/workdir" "" "gdim-kiro-opus"
if ! grep -q -- "--agent gdim-kiro-opus" "${KIRO_ARGS_FILE}"; then
  echo "expected kiro built-in command with selected agent"
  exit 1
fi

run_runner "custom" "${prompt_file}" "${tmp_dir}/custom.log" "1" "${tmp_dir}/workdir" "cat >/dev/null; printf 'custom-ok\n' >>\"${tmp_dir}/custom.marker\"" ""
if ! grep -q "custom-ok" "${tmp_dir}/custom.marker"; then
  echo "expected custom runner command execution"
  exit 1
fi

echo "PASS: runner supports multiple executors"
