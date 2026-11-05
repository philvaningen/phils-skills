---
name: ci-failures
description: >
  Fetch and display detailed CI failure logs for the current branch or a given PR number using the GitHub CLI (gh).
  Use this skill whenever CI is failing, a PR has red checks, tests are failing in GitHub Actions, or you need
  to diagnose what went wrong in CI before fixing code. Trigger phrases: "CI is failing", "fix the failing tests",
  "what's failing in CI", "why is CI red", "check CI errors", "gh run logs", "failing checks on this PR".
version: 1.0.0
---

## What this skill does

Retrieves the exact error output from failed GitHub Actions jobs so you can diagnose and fix the issue without
opening a browser.

## Prerequisites

- `gh` (GitHub CLI) must be installed and authenticated: `gh auth status`
- If not installed: `brew install gh && gh auth login`

## Steps

### 1. Find the PR and failed checks

```bash
# Get the PR number for the current branch (or use the one provided by the user)
PR=$(gh pr view --json number -q .number 2>/dev/null)

# List failed checks — extract run IDs from the detail URLs
# Use `bucket` (not `state`) so TIMED_OUT and ERROR jobs are included alongside FAILURE
gh pr checks "$PR" --json name,bucket,link \
  | python3 -c "
import json, sys, re
checks = json.load(sys.stdin)
failed = [c for c in checks if c['bucket'] == 'fail']
for c in failed:
    run_id = re.search(r'/runs/(\d+)/', c['link'])
    print(c['name'], '|', run_id.group(1) if run_id else 'unknown', '|', c['link'])
"
```

If no PR is open for the current branch, ask the user for a PR number or run URL.

### 2. Fetch the failed logs

For each unique run ID found above:

```bash
gh run view --log-failed <RUN_ID> 2>&1 | head -200
```

If a run has many parallel jobs (e.g. "RSpec / Worker N"), focus on the first 2–3 failed jobs — they usually share the same root cause.

To target a specific job:
```bash
# List failed jobs in the run
gh run view <RUN_ID> --json jobs -q '.jobs[] | select(.conclusion=="failure") | {name:.name, id:.databaseId}'

# Fetch logs for a specific job
gh run view <RUN_ID> --job <JOB_ID> --log-failed 2>&1 | head -200
```

### 3. Extract the signal

From the log output, identify:
- **The failing test or error message** — look for `FAILED`, `Error:`, `Failure/Error:`, `expected`, `NoMethodError`, `rspec`
- **The file and line number** causing the failure
- **Any setup/teardown errors** that may be masking the real issue

GitHub Actions logs contain timestamps and ANSI escape sequences — focus on lines with the actual failure message.

### 4. Report back

Summarise in 2–4 sentences:
- Which checks are failing
- The core error message and location
- Your diagnosis of the root cause

Then proceed to fix the issue.

## Tips

- **Parallel test runners**: Many repos shard tests across many workers. Multiple "Worker N" jobs failing with the same error usually means one test file is broken — not N different problems. Focus on one worker to find the root cause.
- **Log size**: `--log-failed` can be large. Pipe through `head -200` first; expand if the root cause isn't obvious.
- **Linting failures**: Code style checks (RuboCop, ESLint, Reviewdog, etc.) appear as separate check runs from test failures. Use `gh pr checks` output to distinguish them — they need different fixes.
- **Flaky tests**: If the failure looks unrelated to your change (timeouts, external service errors, race conditions), it may be a known flaky test — flag it to the team rather than spending time debugging.
