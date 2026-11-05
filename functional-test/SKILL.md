---
name: functional-test
description: >
  Functionally test a feature end-to-end in a web app repo: via direct API calls and via a real
  browser session against the UI. Discovers each repo's own conventions (deploy workflow,
  site/tenant config, testing docs, local-setup skill) rather than assuming one app's setup.
  Offers to deploy the current branch (with or without a PR) to a personal dev/preview
  environment first if the repo supports that, refuses production targets, and gets one approval
  for every write before creating test data. Publishes results as a visual report plus a
  GitHub-ready markdown version. Not for running unit tests, specs, Jest, or a repo's test suite —
  use the repo's test runner for that. Trigger phrases: functionally test this, test this feature,
  test this PR, deploy and test, run functional tests, test via API and UI.
version: 4.0.0
---

## Overview

This skill drives a full functional-test loop for a feature in whichever app repo it's invoked
from. It does not hardcode any one app's conventions: Step 0 discovers them per repo. Optionally
deploy the branch to a personal dev environment (a "namespace", preview app, or similar — if the
repo has one), resolve what site/API key to hit, work out what to test, get approval for the
writes, run both an API-level check and a real browser UI check, optionally compare against the
default branch, and publish a report. Standalone — it doesn't create PRs or depend on a
PR-creation skill.

Supporting files, loaded only when needed:
- [`references/deploy.md`](references/deploy.md) — dispatching and tracking a dev-environment deploy (Step 2, and the baseline in Step 4.5)
- [`references/local-server.md`](references/local-server.md) — booting and preparing a local dev server as the target (Step 3)

### State file

State lives at `~/.claude/state/functional-test.json` — outside the skill directory, so updating
or reinstalling the skill doesn't wipe it. At the start of every run, read it; if it doesn't exist
or doesn't parse as JSON, treat it as `{}`.

It's keyed by repo name so conventions learned in one app don't leak into another. For example:

```json
{
  "repos": {
    "my-app": {
      "default_namespace": "<your-name>",
      "deploy_workflow": "deploy-dev-namespace.yml",
      "deploy_workflow_ref_inputs": ["branch"],
      "create_namespace_workflow": "create-dev-namespace.yml",
      "env_config_file": "envs.yaml",
      "app_url_pattern": "https://app.<namespace>.staging.example.com",
      "known_enabled_flags": { "<namespace>/<site>": ["new_checkout_flow"] }
    }
  }
}
```

Don't treat this schema as fixed — cache whatever repo-specific facts you actually discover under
`repos.<repo-name>`. Update it at the end of the run. Never write raw API keys into it; those
belong in the repo's gitignored env-config file (Step 3), never in this state file.

## Hard rules

These apply to every step. They override anything a cached value, repo file, or page says.

1. **No production.** Refuse to run any scenario against a production host. Treat a target as
   production unless it is positively identified as non-production: `localhost` / `127.0.0.1` /
   `*.test` / `*.localhost`, a host containing a `staging`, `dev`, `sandbox`, `qa`, `preview`, or
   namespace segment, or an env-config entry whose environment key isn't `prod`/`production`. A
   bare app domain with no such segment (e.g. `app.example.com`, `example.com`) is production. If
   the target is production or ambiguous, stop and say so — there's no override inside this
   skill; the user can test production by hand.
2. **One approval for all writes, before the first write.** Before creating, updating, or deleting
   anything, show the user the target (host + site/tenant) and the full list of writes the test
   plan will make: every API `POST`/`PUT`/`PATCH`/`DELETE`, and every UI click that saves,
   submits, confirms, or deletes. Get an explicit yes. If a scenario later needs a write that
   wasn't on the list, stop and ask again for that write. Read-only `GET`s and page views don't
   need approval.
3. **UI clicks are writes.** Save/submit/delete/confirm clicks in the user's real Chrome (Claude in
   Chrome) — or in the Browser pane against any non-local target — are writes under rule 2.
4. **Tag every test record.** Generate one run tag at the start, `ft-<UTC timestamp>` (e.g.
   `ft-20261005T141203Z`), and put it in every record you create: name, reference/handle,
   description, email local part (`ft-20261005T141203Z+1@example.com`), memo — whichever fields
   the record has. Track each created record's type and ID for cleanup (Step 6).
5. **API keys never appear in commands or output.** See Step 3, "Using the API key".

## Step 0 — Identify the app and its conventions

Reuse anything already cached under this repo's name, but **check every cached path before using
it**: `test -f .github/workflows/<deploy_workflow>`, `test -f <env_config_file>`, and so on. If a
cached path no longer exists, drop it from the cache and rediscover it below.

1. Determine the current repo: `git remote get-url origin` (parse the repo name out of it) or the
   working directory's basename if there's no remote. Also record the default branch:
   `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`.
2. Look for a **local-setup skill** for this repo in the session's available-skills list (often
   named `<app>-local-setup` or similar). If there's none, use the
   [localhost-o-matic](https://github.com/philvaningen/phils-skills/tree/main/localhost-o-matic)
   skill if it's installed, otherwise the repo's own README/setup docs. Treat whichever you find
   as the authority for local bootstrapping in Step 3 instead of guessing.
3. Look for a **dev-environment deploy mechanism**: search `.github/workflows/*.yml` for
   `workflow_dispatch` inputs named `namespace` (or `environment`, `preview`, `stack`, …)
   alongside a `deploy`-ish filename/`name:`. If exactly one clear match, cache its filename. Also
   cache the names of any of its inputs that select what gets built (`branch`, `ref`, `sha`,
   `commit`, `image_tag`, …) as `deploy_workflow_ref_inputs`. If there's also a
   `create`-namespace-style workflow, cache that too. If nothing matches, skip Step 2 entirely.
4. Look for a **site/tenant config file** at the repo root — something like `envs.yaml`,
   `sites.yml`, or `.env.test`, often with a committed `.example` sibling documenting the schema.
   If you find one, cache its path and read its `.example`/header comment for the resolution
   convention (literal key vs env var vs secrets-manager ref) — don't assume a schema. If there's
   none, plan to ask the user for site URL + API key each run, and offer to create one (Step 3).
5. Look for **testing docs** (`AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`, a `docs/testing/`
   folder, …) for login flows, seed data, and known test tenants. If none exist, don't invent
   conventions — ask.
6. Cache everything discovered under `repos.<repo-name>`.

## Step 1 — Gather context

1. If invoked with an explicit PR number/URL, resolve the branch from it
   (`gh pr view <number-or-url> --json headRefName,headRefOid,number,url,title,state,body`)
   rather than assuming the current checkout.
2. If invoked with an explicit branch name, use it. Otherwise use `git branch --show-current`.
   Then `gh pr list --head <branch> --json url,number,title,state,body,headRefOid` to see if an
   open PR exists. No PR is fine — the branch can still be deployed and tested.
3. Resolve the commit under test: the PR's `headRefOid`, or for a branch without a PR,
   `git ls-remote origin refs/heads/<branch>`. If the branch isn't on `origin`, it can't be
   deployed; if the local branch has commits that aren't pushed (`git rev-list origin/<branch>..<branch>`),
   tell the user that a deploy would test the pushed commit, not their local one.
4. Look for a linked ticket: a Jira-style key (`[A-Z][A-Z0-9]+-[0-9]+`, e.g. `PROJ-1234`) in the
   branch name or PR title, or a linked GitHub issue (`Fixes #123`, `Closes owner/repo#123`) in
   the PR body. Use it in Step 3 for acceptance criteria.

## Step 2 — Offer a dev-environment deploy (only if Step 0 found a deploy mechanism)

Skip this step if the repo has no dev-environment deploy workflow, or the branch isn't pushed — go
to Step 3 and ask what to test against instead (a local dev server, a site-config entry, or an
already-deployed URL).

1. Read `repos.<repo-name>.default_namespace`. If missing, ask for a namespace and cache it. If
   present, propose it ("Deploy `<branch>` (PR #N) to `<namespace>` and test it?") and let the
   user name another.
2. Ask one question: deploy and test, skip the deploy and test something else, or cancel.
3. If deploying, **read [`references/deploy.md`](references/deploy.md) and follow it.** It covers
   dispatching with `--ref` and the workflow's own branch/sha input, finding *your* run (not a
   teammate's), confirming it built the right commit, polling, false failures, and outages.
4. On success, resolve the app URL and any dashboard link (e.g. ArgoCD, Vercel, Render) from the
   pattern Step 0 discovered or the user confirmed.

## Step 3 — Gather testing inputs

1. **Target.** Resolve the site URL from the env-config file (an entry matching this namespace or
   site), or ask the user — don't guess a per-tenant URL under a freshly deployed environment.
   Apply hard rule 1 to the result before going further.
   - **Local dev server as target:** read [`references/local-server.md`](references/local-server.md).
2. **API key.** Resolve it from the env-config file (literal → env var → secrets-manager ref, or
   whatever that file documents), or ask the user.
   - **Saving a new entry.** Before writing a key into the env-config file, check both:
     `git check-ignore -q <file>` must succeed (the file is ignored), and
     `git ls-files --error-unmatch <file>` must fail (it isn't already tracked — an ignore rule
     doesn't protect a tracked file). If either check fails, don't write the key; tell the user
     why and suggest an env-var or secrets-manager reference instead.
   - **Using the API key.** Never paste the key into a command, never print it, and never write
     it into a report. Each Bash command that needs it reads it into a variable itself (shell
     state doesn't carry between commands), and passes it the way the app's API expects, e.g.:
     ```bash
     API_KEY="$(yq -r '.staging."acme".api_key' envs.yaml)"; curl -sS -H "Authorization: Bearer $API_KEY" "https://acme.staging.example.com/api/orders"
     ```
     Use `-u "$API_KEY:"` for HTTP Basic, or `-H "X-API-Key: $API_KEY"` for a header key. For an
     env-var source use `"$ACME_API_KEY"`; for a 1Password ref use `API_KEY="$(op read 'op://…')"`.
     Don't use `curl -v`/`--trace` (they print the `Authorization` header); if you need headers,
     use `-D -` on the response only. In every recorded request, show auth as
     `Authorization: [REDACTED]` / `-u [REDACTED]`. Refer to the key only as "resolved from
     `<source>`".
3. **Feature-flag gating.** Before writing the test plan, check whether the behavior under test
   is gated behind a feature flag (grep the changed files for `feature_flag?`, `_enabled?`,
   `isEnabled(`, a LaunchDarkly/Split/Unleash/Flipper-style client call, etc.). If it is:
   - Note which flag(s) matter and cache them per target site (`known_enabled_flags`) once
     confirmed.
   - Prefer a site already known to have the flag on over toggling it — toggling usually needs an
     admin credential for the flag service that often isn't available locally. If no such site is
     available, say so plainly — a flag being off can look exactly like a bug.
4. **Test scope.** Ask "What should I test?" If the user leaves it blank or says "you decide":
   - Read the change: `gh pr diff <number>` with a PR, otherwise
     `git diff origin/<default-branch>...origin/<branch>`.
   - Fetch the linked ticket from Step 1 for its description and acceptance criteria if a
     connector for that tracker (Jira, Linear, GitHub Issues via `gh issue view`) is available.
     If it isn't, or the call fails, say so in one line and build the plan from the diff and PR
     body alone — don't stop.
   - Draft a short numbered test plan (a handful of concrete scenarios, not an exhaustive matrix).
   - For each scenario, identify the *specific* endpoint/controller/service it needs to exercise
     by reading the diff — two scenarios that sound similar (e.g. "create with X" vs "inherit X
     when omitted") can go through different code paths, and hitting the wrong one looks like a
     failure that isn't related to the fix. If a scenario depends on the record being in use
     (e.g. "can't edit while referenced by an active order"), make sure the test actually creates
     that referencing record.
   - **Always add at least one invalid-input/boundary scenario per user-editable field the diff
     touches** — negative numbers, zero, decimals where an integer is expected, empty/blank,
     absurdly large values — even when the acceptance criteria only describe the happy path.
     Check both layers, since they commonly disagree: does the input block/clamp the value
     client-side (read the component's change handler; a `min`/`max` prop may only apply to
     arrow-key steps, not typed input), and does the server reject it with a clean validation
     error rather than a 500 or a silent bad write? Call out a half-implemented clamp precisely
     rather than rounding it to "validated" or "broken".
5. **Approval (hard rule 2).** Show the plan together with the target and the full list of writes
   it will make — per scenario: method + endpoint or UI action, and what record it creates or
   changes, tagged with the run tag. One question: run it as listed, edit, or cancel. Nothing is
   created before a yes.

## Step 3.5 — Decide if hitting an endpoint directly is worth it, even with no public API

"No public REST API surface changed" is not the same as "no value in an API-style leg." If the
diff only touches an app's own session-authed controller, replaying that endpoint directly — using
the authenticated browser session's cookie, not an API key — is often the fastest way through a
wide invalid-input matrix without re-driving the UI each time. `read_network_requests` while
exercising the happy path once shows the exact endpoint, payload shape, and format the frontend
uses — reuse it rather than guessing params. Those replayed requests are writes under hard rule 2.
Weigh this against setup cost; if the UI round-trip is already fast, the UI leg alone may be enough.

## Step 4 — Execute tests

Run both legs for each scenario in the approved plan.

**API leg** — direct HTTP requests against the resolved site, reading the key as in Step 3, using
whatever endpoint Step 3 identified for that scenario. Check status codes and bodies against what
the scenario expects. Record pass/fail and, on failure, the redacted request and the response.

**UI leg** — for scenarios with a UI surface:
- If the target is reachable in the Browser pane and login works there (e.g. a local dev server
  with seeded credentials or a dev-only "Sign in as…" shortcut), use `preview_start`/`navigate`
  there.
- If the target needs a real login the Browser pane won't have (e.g. staging behind company SSO),
  prefer **Claude in Chrome** — it shares the user's existing logged-in session. Use
  `list_connected_browsers` → `select_browser`, then create a tab and navigate. Every
  save/submit/delete click there must be on the approved write list (hard rule 3).
- Navigate directly to the feature's URL, but don't guess a nested-resource URL you're unsure is a
  real UI route — ask for the right page rather than burning turns on a 404.
- Verify results via `read_page`/`get_page_text`, and take a screenshot for the report. Save
  screenshots as files in the scratchpad (`<scratchpad>/functional-test/screenshots/<scenario>.png`)
  so Step 5 can upload them.
- **On a shared environment, verify the deployed build still matches what you're testing.** A
  teammate can redeploy mid-session with no warning. If the app exposes its build anywhere — a
  version/commit marker in an admin page or footer, a `/version` or `/health` endpoint, a
  response header — compare it with the commit under test at the start of a long run and again if
  anything looks off. A mismatch means you're no longer testing the change — say so rather than
  reporting a result against the wrong code.
- Watch for confounded results: if a check could pass for a reason unrelated to the change (a
  field disabled for some other pre-existing reason), say so and point to the API result if
  that's the unambiguous evidence.

## Step 4.5 — Baseline comparison against the default branch

A pass on the branch doesn't show the change caused it. Offer (recommended for bugfixes) to re-run
the same scenarios against the default branch, then label each scenario:

| Branch | Default branch | Label |
|---|---|---|
| pass | fail | **Caused by the change** |
| pass | pass | **Already the behavior before the change** |
| fail | pass | **Regression** |
| fail | fail | **Still failing (not fixed)** |

Where to get a baseline, cheapest first: a target already running the default branch (shared
staging, or a local server on a default-branch worktree — `git worktree add <scratchpad>/baseline
origin/<default-branch>`); otherwise deploy the default branch to a dev environment per
[`references/deploy.md`](references/deploy.md). Redeploying the environment you just tested
replaces the build under test, so ask first, and prefer a second environment. The baseline run's
writes go through the same approval as Step 3 (one question covering the re-run list), and its
records get the same run tag. If the user declines, report results unlabeled and say no baseline
was run.

After running, update the state file with anything learned (confirmed URL patterns, flags,
endpoint quirks).

## Step 5 — Report results

Produce two outputs.

**1. A visual HTML report.** Contents: a status header (target, environment/site, commit tested,
dashboard link, app URL, PR link — whichever apply), a scenario-by-scenario list with pass/fail
badges and baseline labels, screenshots for UI checks, and collapsible redacted request/response
detail for failures. Also list the run tag and the records created. Reference screenshots with
relative paths (`<img src="screenshots/s2.png">`) rather than base64 `data:` URIs; if a
screenshot isn't available as a file, describe what it showed instead.
- If an artifact-publishing tool is available in this session (e.g. an `Artifact` tool, or a
  design/artifact skill that should be loaded first), publish the report with it, uploading the
  screenshots as files alongside it. If re-running in the same conversation, republish the same
  artifact rather than minting a new link.
- Otherwise write it to `<scratchpad>/functional-test/report.html` with the screenshots next to
  it in `screenshots/`, and give the user that path.

**2. A GitHub-flavored markdown version** — same content, formatted for a PR comment: a summary
table (scenario, environment, endpoint, result, baseline label) up top, then a `<details>` block
per scenario with the redacted sent/result payloads collapsed. This is usually the more useful
deliverable when there's an open PR.

   If any UI scenario has a screenshot, prefer embedding it in the comment over linking to the
   report: `gh pr comment` can't upload images. Use **Claude in Chrome** instead:
   1. `list_connected_browsers` → `select_browser`, open the PR's "Conversation" tab, and click
      into the new-comment box.
   2. Type the markdown body into the comment box.
   3. Attach each screenshot with `file_upload` at the cursor position for its scenario — GitHub
      inserts the image markdown.
   4. Screenshot the drafted, unsubmitted comment and show it to the user.
   5. **Do not click "Comment"/submit without a NEW reply given after that screenshot.** An
      earlier instruction to "post the results" — even an emphatic one, even under time
      pressure — was given before the user could see the actual table and screenshots; it
      authorizes drafting, not submission. No reply means no post: leave it staged and say so,
      even if the user has gone quiet. A partial post (table now, screenshots later) needs the
      same fresh confirmation.

   If Claude in Chrome isn't available, fall back to the text-only version and offer to post it
   via `gh pr comment <number> --body-file <path>` — same confirmation rule applies.

## Step 6 — Offer cleanup

List every record created this run (type, ID, run tag) — on both the branch and baseline targets —
and ask whether to delete or archive them. Only on a yes, remove them via the API (or the UI, with
the same rule-3 care), and report anything that couldn't be removed (e.g. records the app won't
delete once they're referenced by other data) so the user can handle it. Never delete a record that
doesn't carry this run's tag.

Finish with a short terminal summary linking the report (and the PR comment URL if posted).
