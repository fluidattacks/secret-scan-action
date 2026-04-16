#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="/tmp/secret-scanner-config.yaml"
export FA_CONFIG="${GITHUB_WORKSPACE}/.fluidattacks.yaml"

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

cfg_include = ['.']
cfg_exclude = None
cfg_output = {'format': 'SARIF', 'file_path': '.fluidattacks-secret-scan-results.sarif'}

if os.path.isfile(fa_config_path):
    print(f'::notice::Reading config from {fa_config_path}')
    with open(fa_config_path) as f:
        fa_cfg = yaml.safe_load(f) or {}
    ss = fa_cfg.get('ss') or {}
    if 'include' in ss:
        cfg_include = ss['include']
    if 'exclude' in ss:
        cfg_exclude = ss['exclude']
    if fa_cfg.get('output'):
        cfg_output = fa_cfg['output']
else:
    print(f'::notice::No config file found at {fa_config_path}, using defaults')

config = {'namespace': namespace}
ss = {}

if mode == 'diff':
    ss['include'] = os.environ['CHANGED_FILES'].splitlines()
elif cfg_include is not None:
    ss['include'] = cfg_include

if cfg_exclude is not None:
    ss['exclude'] = cfg_exclude

if ss:
    config['ss'] = ss

config['output'] = cfg_output

with open('${CONFIG_FILE}', 'w') as f:
    yaml.dump(config, f, default_flow_style=False, sort_keys=False)
"
}

run_scan() {
  echo "::group::Generated configuration"
  cat "${CONFIG_FILE}"
  echo "::endgroup::"

  local exit_code=0
  docker run --rm \
    -v "${GITHUB_WORKSPACE}:/src" \
    -v "${CONFIG_FILE}:${CONFIG_FILE}:ro" \
    "ghcr.io/fluidattacks/ss:latest" \
    ss scan --config "${CONFIG_FILE}" || exit_code=$?

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
