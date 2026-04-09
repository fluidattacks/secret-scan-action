# Fluid Attacks Secrets Scan

Free, open-source action to search for hardcoded secrets on your GitHub repositories.
No account, API key, or registration required.

## Quick Start (2 minutes)

### Create the GitHub Actions workflow

Add the file `.github/workflows/fa-secrets.yml` to your repository:

```yaml
name: SECRET_SCAN
on:
  push:
  pull_request:
    types: [opened, synchronize, reopened]
  schedule:
    - cron: '0 8 * * 1'  # optional: weekly full scan every Monday at 8am

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          # Required: full history enables differential scanning
          # so only changed files are analyzed on branches and PRs
          fetch-depth: 0

      - uses: fluidattacks/secret-scan-action@main
        id: scan

      - name: Upload results to GitHub Security tab
        if: always()
        uses: github/codeql-action/upload-sarif@v4
        with:
          sarif_file: ${{ steps.scan.outputs.sarif_file }}
```

Commit the file, push, and the scan will run automatically. Results will appear in the **Security** tab of your repository under **Code scanning alerts**.

No configuration file is required. By default the action scans your entire repository and writes results to `.fluidattacks-secret-scan-results.sarif`.

## Prerequisites

- A GitHub repository (public or private).
- GitHub Actions enabled on the repository.
- A **Linux runner** (`ubuntu-latest` or equivalent) — the action requires Docker, which is only available on Linux-hosted runners.
- No account, token, or API key is needed. The action is 100% open source.

## How it works

### Default branch detection

The action automatically detects your repository's default branch by running `git remote show origin`. This means it works with any branch name — `main`, `master`, `trunk`, `develop`, or whatever your team uses.

### Scan types

The action determines the scan type based on context:

| Trigger | Scan type | What it analyzes |
|---|---|---|
| Push to default branch | Full scan | All files in the repository |
| Push to any other branch | Differential scan | Only files changed vs. default branch |
| Pull request | Differential scan | Only files changed vs. PR base branch |

Both differential scan modes compare against the full default branch (not just the previous commit), so even if a push contains multiple commits, all changes relative to the default branch are analyzed. This keeps your CI fast while ensuring nothing slips through.

### Why `fetch-depth: 0`?

The `actions/checkout` step uses `fetch-depth: 0` to download the full git history. This is necessary for the differential scan to compare your current changes against the PR base. Without it, the action would not have enough context to determine what changed.

## Viewing results

After the workflow runs, you can see the results in two places:

1. **GitHub Security tab** — Go to your repository → **Security** → **Code scanning alerts**. Each secret is reported as a vulnerability, which means it appears as an alert with details, severity, and the exact file and line where it was found.

2. **Pull request annotations** — On pull requests, the reports appear as inline annotations directly in the code diff, making them easy to review.

3. **SARIF file** — The raw results are also available as a SARIF file artifact if you need to process them with other tools.

## Configuration

The action optionally reads a `.fluidattacks.yaml` file at the root of your repository. Only the `sniffs` and `output` keys are used by this action.

```yaml
sniffs:
  include:
    - .          # paths to scan (default: entire repo)
  exclude:
    - tests/     # paths to skip

output:
  file_path: .fluidattacks-secret-scan-results.sarif
  format: SARIF
```

If `.fluidattacks.yaml` is absent or the keys are omitted, the action falls back to the defaults described below.

### `sniffs.include`

A list of paths (files or directories) to scan.

- **Full scan**: uses this list, defaulting to `.` (entire repository) if not set.
- **Differential scan**: always uses the list of changed files, regardless of this setting.

### `sniffs.exclude`

A list of paths to exclude from the scan. Applied in both full and differential modes.

### `output`

Controls the results file written to the repository workspace.

| Field | Default | Description |
|---|---|---|
| `file_path` | `.fluidattacks-secret-scan-results.sarif` | Path to the results file |
| `format` | `SARIF` | Output format (`SARIF` or `CSV`) |

## Action outputs

| Output | Description |
|---|---|
| `sarif_file` | Path to the SARIF results file |
| `vulnerabilities_found` | `true` if any vulnerabilities were detected, `false` otherwise |

You can use these outputs in subsequent workflow steps. For example:

```yaml
- name: Comment on PR
  if: steps.scan.outputs.vulnerabilities_found == 'true'
  run: echo "Vulnerabilities were found. Check the Security tab for details."
```

## Common scenarios

### Monorepo: scan only specific folders

If your repository contains multiple projects, you can limit the scan to specific directories:

```yaml
sniffs:
  include:
    - services/api/
    - services/web/
  exclude:
    - services/legacy/
```

### Export results as CSV

```yaml
output:
  file_path: results.csv
  format: CSV
```

## Troubleshooting

### The scan runs but no results appear in the Security tab

Make sure the "Upload SARIF" step is included in your workflow and uses `if: always()` so it runs even if the scan finds vulnerabilities.

### The differential scan analyzes all files instead of just changes

Verify that `fetch-depth: 0` is set in the `actions/checkout` step. Without full git history, the action cannot determine which files changed.

### The action doesn't detect my default branch

The action runs `git remote show origin` to detect the default branch. This requires `fetch-depth: 0` in the checkout step so the remote metadata is available. If detection fails, verify that the `origin` remote is correctly configured in your repository.

## More information

- [Source code on GitHub](https://github.com/fluidattacks/secret-scan-action)
- [Vulnerability database](https://db.fluidattacks.com)
- [Fluid Attacks documentation](https://docs.fluidattacks.com)
- [SARIF format specification](https://sarifweb.azurewebsites.net/)
