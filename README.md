# Fluid Attacks SECRET SCANNER

Free, open-source action to search for hardcoded secrets on your GitHub repositories.
No account, API key, or registration required.

## Quick Start (2 minutes)

You only need to do two things to start scanning your code for secrets:

### 1. Create the configuration file

Add a file called `.fa-secrets.yaml` in the root of your repository:

```yaml
language: EN
strict: true
output:
  file_path: results.sarif
  format: SARIF
sniffs:
  include:
    - .
```

That's it for configuration. This minimal setup will scan your entire repository.

### 2. Create the GitHub Actions workflow

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

      - uses: fluidattacks/secret-scan-action@latest
        id: scan

      - name: Upload results to GitHub Security tab
        if: always()
        uses: github/codeql-action/upload-sarif@v4
        with:
          sarif_file: ${{ steps.scan.outputs.sarif_file }}
```

Commit both files, push, and the scan will run automatically. Results will appear in the **Security** tab of your repository under **Code scanning alerts**.

## Prerequisites

- A GitHub repository (public or private).
- GitHub Actions enabled on the repository.
- No account, token, or API key is needed. The action is 100% open source.

## How it works

### Default branch detection

The action automatically detects your repository's default branch by running `git remote show origin`. This means it works with any branch name — `main`, `master`, `trunk`, `develop`, or whatever your team uses. You don't need to configure the branch name anywhere in `.fa-secrets.yaml`.

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

## Configuration reference

All settings go in `.fa-secrets.yaml` at the root of your repository.

## Action outputs

| Output | Description |
|---|---|
| `sarif_file` | Path to the SARIF results file (when format is `SARIF`) |
| `vulnerabilities_found` | `true` if any vulnerabilities were detected, `false` otherwise |

You can use these outputs in subsequent workflow steps. For example, to add a conditional step:

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

### Strict mode: block merges with vulnerabilities

Set `strict: true` to make the action fail when vulnerabilities are found. Combined with branch protection rules, this prevents vulnerable code from being merged:

```yaml
strict: true
```

Then, in your repository settings, enable **Require status checks to pass before merging** and select the SECRET_SCAN check.

### Export results as CSV

If you want a CSV report instead of (or in addition to) SARIF:

```yaml
output:
  file_path: results.csv
  format: CSV
```

## Troubleshooting

### The scan runs but no results appear in the Security tab

Make sure the "Upload SARIF" step is included in your workflow and uses `if: always()` so it runs even if the scan finds vulnerabilities with `strict: true`.

### The differential scan analyzes all files instead of just changes

Verify that `fetch-depth: 0` is set in the `actions/checkout` step. Without full git history, the action cannot determine which files changed.

### I don't have a `.fa-secrets.yaml` file

The action requires this configuration file. Without it, the action will fail. Use the minimal configuration shown in the Quick Start section to get started.

### The action doesn't detect my default branch

The action runs `git remote show origin` to detect the default branch. This requires `fetch-depth: 0` in the checkout step so the remote metadata is available. If detection fails, verify that the `origin` remote is correctly configured in your repository.

### The pipeline fails unexpectedly

If `strict: true` is set, the pipeline will fail whenever vulnerabilities are found. This is intentional. Set `strict: false` if you want the scan to report vulnerabilities without failing the pipeline.

## More information

- [Source code on GitHub](https://github.com/fluidattacks/secret-scan-action)
- [Vulnerability database](https://db.fluidattacks.com)
- [Fluid Attacks documentation](https://docs.fluidattacks.com)
- [SARIF format specification](https://sarifweb.azurewebsites.net/)
