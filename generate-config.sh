#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="/tmp/secret-scanner-config.yaml"
FA_CONFIG="${GITHUB_WORKSPACE}/.fluidattacks.yaml"

check_changed_files() {
  if [[ ${INPUT_MODE} == "diff" && -z "${CHANGED_FILES}" ]]; then
    echo "::notice::No files changed. Skipping scan."
    echo "skip=true" >> "${GITHUB_OUTPUT}"
    return 1
  fi
}

prepare_config() {
  python3 -c "
import yaml, os

fa_config_path = os.environ.get('FA_CONFIG', '')
mode = os.environ['INPUT_MODE']
namespace = os.environ['GITHUB_REPOSITORY']

cfg_include = ["."]
cfg_exclude = None
cfg_output = {'format': 'SARIF', 'file_path': '.fluidattacks-secret-scan-results.sarif'}

if os.path.isfile(fa_config_path):
    with open(fa_config_path) as f:
        fa_cfg = yaml.safe_load(f) or {}
    sniffs = fa_cfg.get('sniffs') or {}
    cfg_include = sniffs.get('include')
    cfg_exclude = sniffs.get('exclude')
    if fa_cfg.get('output'):
        cfg_output = fa_cfg['output']

config = {'namespace': namespace}
sniffs = {}

if mode == 'diff':
    sniffs['include'] = os.environ['CHANGED_FILES'].split()
elif cfg_include is not None:
    sniffs['include'] = cfg_include

if cfg_exclude is not None:
    sniffs['exclude'] = cfg_exclude

if sniffs:
    config['sniffs'] = sniffs

config['output'] = cfg_output

with open('${CONFIG_FILE}', 'w') as f:
    yaml.dump(config, f, default_flow_style=False, sort_keys=False)
" FA_CONFIG="${FA_CONFIG}"
}

run_scan() {
  echo "::group::Generated configuration"
  cat "${CONFIG_FILE}"
  echo "::endgroup::"

  local exit_code=0
  docker run --rm \
    -v "${GITHUB_WORKSPACE}:/src" \
    -v "${CONFIG_FILE}:${CONFIG_FILE}:ro" \
    "ghcr.io/fluidattacks/secret_scan:latest" \
    secrets scan --config "${CONFIG_FILE}" || exit_code=$?

  if [[ ${exit_code} -eq 0 ]]; then
    echo "vulnerabilities_found=false" >> "${GITHUB_OUTPUT}"
  elif [[ ${exit_code} -eq 1 ]]; then
    echo "vulnerabilities_found=true" >> "${GITHUB_OUTPUT}"
  else
    echo "::error::Scanner exited with code ${exit_code}"
    exit "${exit_code}"
  fi

  python3 -c "
import yaml, re
with open('${CONFIG_FILE}') as f:
    cfg = yaml.safe_load(f)
fmt = cfg.get('output', {}).get('format', '')
if fmt == 'SARIF':
    path = cfg['output']['file_path']
    sanitized = re.sub(r'[\r\n]', '', str(path))
    print('sarif_file=' + sanitized)
" >> "${GITHUB_OUTPUT}" 2> /dev/null || true
}

main() {
  if ! check_changed_files; then
    exit 0
  fi

  prepare_config
  echo "skip=false" >> "${GITHUB_OUTPUT}"
  run_scan
}

main
