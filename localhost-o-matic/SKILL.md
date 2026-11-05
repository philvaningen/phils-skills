---
name: localhost-o-matic
description: Use when someone wants to get an app or repo running on their own machine, set up a local dev environment, onboard to an unfamiliar codebase, or is stuck on local setup errors such as port conflicts, wrong runtime versions, failed dependency installs, or Docker services and databases that will not start. Trigger phrases include "run this locally", "set up this repo", "get this running on my laptop", "local setup", "localhost isn't working". Works for any stack. Not for deploying to servers or for production environments.
---

# Localhost-o-Matic

Get a project running locally by learning how it works from the repo itself, then doing only the steps this machine still needs. The person may not be an engineer, so explain each step in plain words.

## Start here

1. Find the project. If it isn't on this machine, ask for the clone URL and where to put it.
2. Survey it with the bundled read-only script. `<skill-dir>` is the folder holding this file:
   ```bash
   bash <skill-dir>/scripts/discover.sh /path/to/project
   ```
3. Read what the survey points to: setup sections of the docs, then `AGENTS.md` or `CLAUDE.md`, the compose file, the `Procfile`, and any setup script. The repo's own instructions outrank the defaults in this skill.
4. Read the stack guide for each stack you found:
   - Ruby or Rails: [references/rails.md](references/rails.md)
   - Python or Django: [references/python.md](references/python.md)
   - JavaScript or TypeScript: [references/node.md](references/node.md)
   - Any other stack: use its lockfile, version file and docs.
5. Show the person a short plan: the phases that apply, what is already done, and a rough time. Ask only for what the repo can't tell you. Then start.

If the survey shows a saved profile, use its commands and known problems first, and re-check anything that no longer matches the repo.

## Phases

Work through these in order and skip any that don't apply. In each phase, check the current state first, act only if needed, then report one line: phase name, pass or fail, and what you did. A failed phase blocks the phases that depend on it.

| Phase | Check | Act when needed |
|---|---|---|
| 1. Prerequisites | Survey's Machine section; `ssh -T git@github.com` if the repo clones over SSH | Give the install command for each missing tool. Recommend one option; respect tools already installed. |
| 2. Repo | Clone exists, current branch, uncommitted files | Clone, and initialise submodules if `.gitmodules` exists. Leave uncommitted work alone. |
| 3. Services | Compose services running and healthy, host ports free | Resolve conflicts (see below), `docker compose up -d`, then poll until ready using `pg_isready`, `redis-cli ping`, `mysqladmin ping` or a health URL. |
| 4. Runtimes | Installed versions against pinned versions | Install through the version manager already present. |
| 5. Dependencies | Lockfile installed | Install with the tool that owns the lockfile. Warn first if it takes over 30 seconds. |
| 6. Configuration | Env file exists; template's variable names are all set | Copy the template, then ask the person for any real secrets they need to fill in themselves. |
| 7. Database | Database reachable and schema loaded | Run the project's create, migrate and seed commands. Warn first if slow. |
| 8. Frontend | Assets build or dev server dependencies present | Run the project's install and build steps. |
| 9. Local HTTPS | Only if the project expects a custom local domain | Follow the project's setup; see the trust step under Safety. |
| 10. Start and verify | The app answers | Start it as the project documents, then request the URL. Any response from the app counts, including a redirect or 401. Check logs on a connection failure or 5xx. |

If a project has one idempotent setup script, such as `bin/setup`, read it, then run it instead of the phases it covers. A command that exits cleanly is proof enough; only run a separate check when you don't know the state.

## Port conflicts

Find what holds the port: `lsof -nP -iTCP:<port> -sTCP:LISTEN`.

1. If it's a leftover copy of this project, offer to stop it.
2. If it's another app the person may need, keep it running and move this project to a free port.
3. Prefer an env var or an untracked override such as `compose.override.yml`. Only edit tracked files if nothing else works, and say which files changed so they don't get committed by accident.
4. Update everything that points at the old port: database URLs, Redis URLs and app config.

## Safety

- **`sudo`:** give the person the exact command to run in their own terminal, explain any password prompt, and wait for them to confirm. This includes trusting a certificate.
- **Secrets:** let the person type secrets into the env file themselves. Report env vars by name only, and don't print the contents of real env files.
- **Scripts from the repo:** read a setup script before running it, and tell the person about anything surprising, like `curl | sh`, changes outside the project, or remote calls.
- **Local targets only:** before migrating or seeding, confirm the database host is local. If config points to a shared or production system, stop and ask.
- **Destructive commands:** dropping a database or running `docker compose down -v` needs a clear yes first, even when the data looks disposable.
- **Shell profile changes:** explain the line, get a yes, and say how to undo it. Offer a per-command `PATH` prefix as the alternative.
- **Certificates:** fix verification errors by trusting the local certificate. Keep verification turned on.

## When something fails

Read the actual error and find the root cause before retrying. Try one fix at a time. After two failed attempts at the same step, stop and show the person the error, what you tried, and your best guess.

If a Postgres or MySQL container exits straight away, check its logs for a data directory from an older major version. With a yes from the person, recreate the volume and reseed.

## Finishing

End with a summary table of every phase, followed by:

- the URL and the exact start command, one terminal per process
- test logins from seed data, only if the repo documents them
- how to stop the services, and how to reset the database
- anything skipped or not verified

Then offer to save what you learned to `.localhost-o-matic.yml` in the project, so the next run is faster. Write it only on a yes, and ask whether it should be committed or added to `.gitignore`. Store commands and known problems, and leave out secrets:

```yaml
start: [bin/rails server -p 3100, bin/sidekiq]
url: http://localhost:3100
services: [db, redis]
ports: {web: 3100, redis: 6380}
setup_notes:
  - Run bundle install even when bundle check passes; git-sourced gems can be missing.
```

## Connecting several apps

For projects that talk to each other, set up each one fully first and start them one at a time. Then use the docs of both to connect them, and verify with one real request or event from end to end.
