# Using a local dev server as the target

Used by Step 3 when the user wants to test against their own machine instead of a deployed
environment, and by Step 4.5 for a cheap baseline.

## 1. Defer to the repo's own setup

If Step 0 found a local-setup skill for this repo (or localhost-o-matic), use it to get the app
running and don't duplicate its work here. Otherwise follow the repo's README / `AGENTS.md` /
`CLAUDE.md` / `bin/setup` / `Procfile.dev` / compose file. Don't invent setup steps.

## 2. Is it already running?

Before starting anything, check the usual ports (from the repo's config, `Procfile`, `.env`, or
framework default — 3000, 4000, 5000, 5173, 8000, 8080):

```bash
lsof -nP -iTCP -sTCP:LISTEN | grep -E ':(3000|4000|5000|5173|8000|8080)\b'
```

If something is listening, confirm it's this repo (`lsof -p <pid>` shows its cwd) and on the
branch under test. A server started from another checkout or branch tests the wrong code.

## 3. Make sure it runs the code under test

- The checkout must be on the branch/commit from Step 1. If the user's main checkout is on another
  branch or has uncommitted work, don't switch it — use a worktree instead:
  `git worktree add <scratchpad>/ft-branch origin/<branch>` (and
  `git worktree add <scratchpad>/baseline origin/<default-branch>` for a baseline).
- A worktree needs its own install (`bundle install`, `npm ci`, …) and usually its own
  gitignored config files copied from the main checkout (`.env`, `config/*.local.*`, the env-config
  file). Copy them; never commit them.
- Two servers at once (branch + baseline) need different ports, and usually separate databases so
  test data from one doesn't confound the other.
- Run pending migrations for the branch. Migrations on the branch can make a shared local database
  unusable for the default branch afterwards — prefer a separate database for the worktree, and
  mention it to the user if you can't.
- Restart the server after switching branches or installing dependencies; dev-mode reloading
  doesn't cover new gems/packages, initializers, or env changes.

## 4. Start it

Use the Browser pane's `preview_start` with a `.claude/launch.json` entry when the app is a web
server you'll open in the pane — it manages the process and the port. Otherwise start it with the
repo's own command in the background and wait for the port to answer
(`curl -sS -o /dev/null -w '%{http_code}' http://localhost:<port>/`). Background jobs, queues, and
asset builders (Sidekiq, Celery, webpack/vite watchers) are often separate processes — start the
ones the scenarios depend on.

## 5. Test data, login and API keys

- Prefer the repo's seed data, fixtures, and documented test accounts. Run seed tasks only with the
  user's OK — they can wipe or duplicate local data.
- For the UI leg, use a dev-only sign-in shortcut or seeded test credentials from the repo's own
  seed/fixture files. Don't use the user's real credentials for any other service.
- For the API leg, create or read a local API key for a test site/user as the repo documents, and
  store it per Step 3's rules (ignored env-config file, never printed).
- Feature flags: locally they're often toggled through a console/rake task or an env var rather
  than the flag service; check how the repo does it, and include toggling it in the approved write
  list.

## 6. Afterwards

Leave servers the user already had running alone. Offer to stop servers and remove worktrees you
started (`git worktree remove <path>`), and mention any local database you migrated.
