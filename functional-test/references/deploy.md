# Deploying a branch to a dev environment

Used by Step 2 (deploy the branch under test) and Step 4.5 (deploy the default branch as a
baseline). Assumes Step 0 found a GitHub Actions workflow with a `workflow_dispatch` trigger and
cached it as `deploy_workflow`, plus the inputs that select what gets built as
`deploy_workflow_ref_inputs`.

## 1. Read the workflow before dispatching

Read `.github/workflows/<deploy_workflow>` and note:
- Every `workflow_dispatch` input, which are `required`, their `type`/`options`, and defaults.
- Which input names the target environment (`namespace`, `environment`, `preview`, …).
- Which input picks what gets built (`branch`, `ref`, `sha`, `image_tag`, …). Some workflows
  build whatever `--ref` the run was dispatched on and have no such input; some ignore `--ref` and
  build only from the input. Work out which from the job steps (`actions/checkout` with
  `ref: ${{ inputs.branch }}`, a `docker build` tag, etc.).
- Whether the environment must exist first. If the deploy fails on a missing environment and
  Step 0 cached a `create_namespace_workflow`, ask before running it — creating an environment
  can cost money or take a while.

If any required input's meaning is unclear, ask the user rather than guessing.

## 2. Dispatch

Dispatch on the branch under test **and** pass the branch/sha through the workflow's own input,
so it doesn't matter which of the two the workflow honours:

```bash
gh workflow run <deploy_workflow> --ref <branch> -f namespace=<namespace> -f branch=<branch>
```

Use the input names the workflow actually defines. For the baseline, use the default branch.
Note the UTC time just before dispatching — you need it to find the run.

## 3. Find *your* run

`gh workflow run` doesn't return a run ID, and teammates may dispatch the same workflow at the
same time. Wait a few seconds, then:

```bash
gh run list --workflow <deploy_workflow> --event workflow_dispatch --limit 10 \
  --json databaseId,headBranch,headSha,createdAt,status,conclusion,actor,displayTitle
```

Pick the run that was created after your dispatch time, has `headBranch` = the branch you
dispatched on, and `actor.login` = you (`gh api user -q .login`). If more than one matches, or
none appears after ~30 seconds, show the candidates and ask rather than tracking the wrong one.

## 4. Confirm it builds the right commit

Compare the run's `headSha` (or the sha its build step logs, if the workflow builds from an input)
with the commit under test from Step 1. If they differ — usually because the branch moved after
Step 1, or because the workflow built from a different input — stop and say so.

## 5. Wait for it

Watch it in the background rather than polling in a tight loop:

```bash
gh run watch <run-id> --exit-status --interval 30
```

Run that in the background and wait to be notified; deploys commonly take 5–20 minutes. If the
workflow kicks off a downstream deploy (ArgoCD sync, Helm release, a second workflow), the run
finishing green may only mean the image was pushed — check the app is actually serving the new
build (Step 4's build-marker check) before testing.

## 6. When it fails

Read the failing step's log: `gh run view <run-id> --log-failed`. Then sort the failure:

- **False failure** — a flaky step, a post-deploy notification or cleanup step, or a timeout on a
  step after the app was already deployed. Check whether the app is up and serving the right
  commit; if it is, say what failed and carry on.
- **Infrastructure outage** — runners unavailable, registry/cluster unreachable, GitHub Actions
  incident (`gh api https://www.githubstatus.com/api/v2/status.json` or the status page). Don't
  retry in a loop; tell the user and offer to test against a local server or an existing
  environment instead.
- **Real build failure** — compile errors, failing image build, migration errors. Report the
  relevant log lines and stop; the branch needs fixing before it can be tested.

Offer one retry for anything that looks transient; ask before retrying a second time.

## 7. After a successful deploy

Resolve the app URL from the cached `app_url_pattern` (or ask, then cache it) and any dashboard
link the workflow prints in its summary/logs. Cache anything newly learned (input names, URL
pattern, typical duration) under `repos.<repo-name>` in the state file.
