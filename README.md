# Phil's Skills

A collection of Claude skills by Phil Van Ingen. Each folder is one skill.

## Skills

| Skill | What it does |
|---|---|
| [localhost-o-matic](localhost-o-matic/) | Gets any project running on your own machine: it reads the repo, checks what's already installed, and walks through services, dependencies, database and startup. |
| [functional-test](functional-test/) | Tests a feature end-to-end in your web app — through the API and a real browser — after optionally deploying the branch to a dev environment. Refuses production, asks once before creating any test data, and writes a report you can paste into the PR. |
| [ci-failures](ci-failures/) | Pulls the failure logs from red GitHub Actions checks and explains what went wrong, using the GitHub CLI. |
| [shortlisted](shortlisted/) | Runs an organized, low-stress job search: a tracker for target companies, applications, networking and recruiting agencies, plus free Gmail scanning and follow-up drafts. |

## How to add a skill to Claude

1. Open the skill's folder and download the `.skill` file (click the file, then the download button).
2. In the Claude app, go to **Settings → Capabilities → Skills**.
3. Upload the `.skill` file and switch it on.

To use a skill in Claude Code instead, copy its folder into `~/.claude/skills/`.

Every skill here is free to use. None need paid accounts or paid data services.

## What's in each folder

- `SKILL.md` — the instructions Claude follows.
- `*.skill` — the same skill packaged for upload.
- `evals/` — test prompts used to check the skill while developing it. They aren't included in the `.skill` file.
- `scripts/` and `references/` — helper scripts and extra guides the skill loads when needed.
- `assets/` — files the skill uses, such as the page it builds. Any `.html` file here doubles as a preview: download it and open it in a browser to see it.
