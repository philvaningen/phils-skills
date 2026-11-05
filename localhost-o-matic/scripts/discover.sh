#!/usr/bin/env bash
# Read-only survey of a project and this machine, for local environment setup.
# Prints file names, versions, ports and env var NAMES. Never prints env values.
# Usage: bash discover.sh [project-dir]
set -u

ROOT="${1:-.}"
if ! cd "$ROOT" 2>/dev/null; then
  echo "ERROR: cannot enter $ROOT"
  exit 1
fi

section() { printf '\n== %s ==\n' "$1"; }

# find_named NAME... : matching files up to 3 levels deep, skipping generated dirs
find_named() {
  local expr=() name
  for name in "$@"; do
    [ "${#expr[@]}" -gt 0 ] && expr+=(-o)
    expr+=(-name "$name")
  done
  find . -maxdepth 3 \
    \( -name node_modules -o -name vendor -o -name .git -o -name .venv -o -name venv \
       -o -name dist -o -name build -o -name tmp -o -name target \) -prune \
    -o -type f \( "${expr[@]}" \) -print 2>/dev/null | sed 's|^\./||' | sort
}

# Prints: in-use, free or unknown, without needing elevated rights
port_state() {
  case "$1" in
    ''|*[!0-9]*) echo unknown; return ;;
  esac
  if command -v lsof >/dev/null 2>&1; then
    if lsof -nP -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1; then echo in-use; else echo free; fi
  else
    echo unknown
  fi
}

section "Project"
pwd
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  # Strip any credentials embedded in the remote URL
  echo "remote: $(git remote get-url origin 2>/dev/null | sed -E 's#//[^/@]+@#//#')"
  echo "branch: $(git branch --show-current 2>/dev/null)"
  echo "uncommitted files: $(git status --short 2>/dev/null | wc -l | tr -d ' ')"
else
  echo "not a git repository"
fi

section "Saved profile"
if [ -f .localhost-o-matic.yml ]; then
  cat .localhost-o-matic.yml
else
  echo "none"
fi

section "Stack files"
find_named Gemfile Gemfile.lock package.json yarn.lock pnpm-lock.yaml package-lock.json bun.lockb \
  pyproject.toml requirements.txt uv.lock poetry.lock Pipfile.lock manage.py go.mod Cargo.toml \
  composer.json mix.exs pom.xml build.gradle build.gradle.kts application.rb

section "Pinned versions"
for f in $(find_named .ruby-version .python-version .node-version .nvmrc .tool-versions .mise.toml mise.toml); do
  echo "--- $f"
  head -20 "$f"
done
for f in $(find_named package.json); do
  grep -A4 '"engines"' "$f" 2>/dev/null | sed "s|^|$f: |"
done

section "Compose services and published host ports"
for f in $(find_named docker-compose.yml docker-compose.yaml compose.yml compose.yaml); do
  echo "--- $f"
  awk '
    { match($0, /^[[:space:]]*/); lead = RLENGTH }
    /^services:/ { in_services = 1; indent = -1; next }
    /^[^[:space:]#]/ { in_services = 0 }
    !in_services || /^[[:space:]]*(#|$)/ { next }
    indent < 0 { indent = lead }
    lead == indent && /:[[:space:]]*(#.*)?$/ { svc = $1; sub(/:$/, "", svc); print "service " svc; next }
    /^[[:space:]]+-[[:space:]]*"?(\$\{[^}]*\}:|([0-9.]+:)?[0-9]+:)[0-9]+/ {
      p = $0; sub(/^[[:space:]]*-[[:space:]]*/, "", p); gsub(/["\047[:space:]]/, "", p); sub(/\/.*/, "", p)
      # ${VAR:-54320}:5432 publishes the default unless VAR is set
      if (sub(/\$\{[^}]*:-/, "", p)) sub(/\}/, "", p)
      print "  port " p
    }
    /^[[:space:]]+published:/ { p = $2; gsub(/["\047]/, "", p); print "  port " p ":container" }
  ' "$f" | while IFS= read -r line; do
    case "$line" in
      *port\ *)
        mapping="${line##* }"
        host="${mapping%:*}"; host="${host##*:}"
        echo "$line (host port $host: $(port_state "$host"))"
        ;;
      *) echo "$line" ;;
    esac
  done
done

section "Process files"
for f in $(find_named 'Procfile*'); do
  echo "--- $f"
  head -20 "$f"
done

section "Setup entry points"
find_named setup bootstrap setup.sh bootstrap.sh Makefile justfile Taskfile.yml Brewfile devcontainer.json
for f in $(find_named Makefile); do
  echo "--- targets in $f"
  grep -E '^[A-Za-z0-9_-]+:' "$f" | cut -d: -f1 | head -30
done
for f in $(find_named package.json); do
  if command -v python3 >/dev/null 2>&1; then
    echo "--- scripts in $f"
    python3 -I -c 'import json,sys; print("\n".join(json.load(open(sys.argv[1])).get("scripts",{})))' "$f" 2>/dev/null
  fi
done

section "Environment files (names only, values hidden)"
for f in $(find_named '.env*' 'application.yml.example' 'secrets.yml.example'); do
  case "$f" in
    *example*|*sample*|*template*|*dist*)
      echo "--- template $f"
      grep -E '^[[:space:]]*(export[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*[[:space:]]*[=:]' "$f" \
        | sed -E 's/^[[:space:]]*(export[[:space:]]+)?//; s/[[:space:]]*[=:].*//'
      ;;
    *)
      echo "--- exists, not read: $f"
      ;;
  esac
done

section "Database signals"
for f in $(find_named database.yml); do
  echo "$f: $(grep -hE '^[[:space:]]*adapter:' "$f" | sed -E 's/.*adapter:[[:space:]]*//' | sort -u | tr '\n' ' ')"
done
find_named schema.prisma alembic.ini schema.rb structure.sql seeds.rb

section "Docs worth reading"
for f in $(find_named 'README*' 'CONTRIBUTING*' 'DEVELOPMENT*' 'SETUP*' 'INSTALL*' 'AGENTS.md' 'CLAUDE.md'); do
  echo "--- $f"
  grep -nEi '^#{1,4} .*(install|setup|set up|getting started|prerequisite|develop|running|local)' "$f" | head -12
done

section "Local HTTPS signals"
find_named Caddyfile '*.test.crt' '*.localhost.crt' 'mkcert*'
[ -d "$HOME/.puma-dev" ] && echo "puma-dev configured on this machine"
command -v mkcert >/dev/null 2>&1 && echo "mkcert installed"

section "Machine"
echo "os: $(uname -s) $(uname -m)"
echo "shell: ${SHELL:-unknown}"
for tool in brew git docker mise asdf rbenv rvm pyenv nodenv fnm ruby bundle python3 uv poetry node npm yarn pnpm bun go cargo php java gh; do
  if command -v "$tool" >/dev/null 2>&1; then echo "$tool: $(command -v "$tool")"; else echo "$tool: missing"; fi
done
[ -s "$HOME/.nvm/nvm.sh" ] && echo "nvm: installed (loads from ~/.nvm/nvm.sh)"
if command -v docker >/dev/null 2>&1; then
  if docker info >/dev/null 2>&1; then echo "docker daemon: running"; else echo "docker daemon: not running"; fi
fi
exit 0
