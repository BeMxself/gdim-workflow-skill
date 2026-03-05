#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYNC_SCRIPT="${SCRIPT_DIR}/../sync-automation.sh"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

reference_dir="${tmp_dir}/reference"
target_dir="${tmp_dir}/target"
mkdir -p "${reference_dir}" "${target_dir}"

files=(
  "run-gdim-flows.sh"
  "run-gdim-round.sh"
  "setup-kiro-agent.sh"
  "lib/log.sh"
  "lib/state.sh"
  "lib/validate.sh"
  "lib/prompt-builder.sh"
  "lib/runner.sh"
  "templates/stages/scope.md.tpl"
  "templates/stages/design.md.tpl"
  "templates/stages/plan.md.tpl"
  "templates/stages/execute.md.tpl"
  "templates/stages/summary.md.tpl"
  "templates/stages/gap.md.tpl"
  "templates/retry/compile-failed.md"
  "templates/retry/test-failed.md"
  "templates/retry/malformed-output.md"
  "templates/retry/commit-missing.md"
)

for f in "${files[@]}"; do
  mkdir -p "${reference_dir}/$(dirname "$f")"
  printf '%s\n' "content-${f}" >"${reference_dir}/${f}"
done

output_file="${tmp_dir}/sync.output"
if bash "${SYNC_SCRIPT}" "${reference_dir}" "${target_dir}" >"${output_file}" 2>&1; then
  rc=0
else
  rc=$?
fi

if [[ "${rc}" -ne 0 ]]; then
  echo "expected missing files to be copied by default; got exit code ${rc}"
  cat "${output_file}"
  exit 1
fi

for f in "${files[@]}"; do
  if [[ ! -f "${target_dir}/${f}" ]]; then
    echo "expected copied file missing: ${f}"
    exit 1
  fi
done

if ! grep -q "\[COPY\]" "${output_file}"; then
  echo "expected [COPY] entries in sync output"
  cat "${output_file}"
  exit 1
fi

echo "PASS: sync copies missing files by default"
