# JavaScript and TypeScript

## Node version

Look in `.nvmrc`, `.node-version`, `.tool-versions` and `engines` in `package.json`. Install through the manager already present:

| Manager | Command, run in the project |
|---|---|
| mise | `mise install node` |
| asdf | `asdf install nodejs` |
| nodenv | `nodenv install`, then `nodenv rehash` if shims look broken |
| fnm | `fnm use --install-if-missing` |
| nvm | `nvm install && nvm use` |

nvm is a shell function, so `which nvm` finds nothing even when it's installed. Load it per command with `source ~/.nvm/nvm.sh`. If it's installed but new shells don't load it, offer to add this to the shell profile, following the shell profile rule in `SKILL.md`:

```bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
```

## Dependencies

Use the package manager that owns the lockfile, even if another is installed:

| Lockfile | Command |
|---|---|
| `pnpm-lock.yaml` | `pnpm install --frozen-lockfile` |
| `yarn.lock` | `yarn install` |
| `package-lock.json` | `npm ci` |
| `bun.lockb` | `bun install` |

If the manager is missing and `package.json` has a `packageManager` field, use `corepack enable` so the pinned version is used. Monorepos and apps with a `frontend/` folder may have more than one `package.json`, so check where the lockfile lives.

## Starting

Read the `scripts` list in `package.json`. `dev` is the usual choice, then `start`. Apps may spend 30 to 60 seconds on their first compile, so wait before treating an empty response as a failure.

Dev servers often bind to one address. If `localhost` fails, try `127.0.0.1`, and check the server's output for the URL it printed.

## Common failures

| Failure | Fix |
|---|---|
| `node: command not found` from version manager shims | Rehash or reinstall the pinned version |
| `node-gyp` build errors | Install Xcode Command Line Tools, and confirm the Node version matches the pinned one |
| `ERESOLVE` from npm | Check that the lockfile's tool and Node version match. Treat `--legacy-peer-deps` as a last resort, and say so if you use it |
| `EADDRINUSE` | See Port conflicts in `SKILL.md` |
