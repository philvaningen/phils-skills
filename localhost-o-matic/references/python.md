# Python and Django

## Choose the tool from the lockfile

| File | Install command |
|---|---|
| `uv.lock` | `uv sync`, plus `--group dev` if the project defines that group |
| `poetry.lock` | `poetry install` |
| `Pipfile.lock` | `pipenv install --dev` |
| `requirements*.txt` | `python3 -m venv .venv && .venv/bin/pip install -r requirements.txt` |

The project root may be a subfolder, so run these where the survey found the file.

`uv` downloads the pinned Python itself, so there's no need to install one first. Otherwise, install the version in `.python-version` through the manager already present. Use the project's virtualenv rather than system Python, either with `.venv/bin/python` or `uv run`.

Verify with an import of the main framework:

```bash
.venv/bin/python -c "import django; print(django.VERSION)"
```

## Django

1. Copy the env template if there is one, and let the person fill in secrets.
2. Confirm the database host is local, then run `python manage.py migrate`.
3. Load seed data if the docs describe it. Otherwise, offer to run `python manage.py createsuperuser`, which the person completes in their own terminal.
4. Start with `python manage.py runserver`. Add a port argument if 8000 is taken.

Check `ALLOWED_HOSTS` if a custom domain or tunnel returns a 400 error.

## Services

- Wait for Postgres with `pg_isready -h localhost -p <port>`, or run it through `docker exec` if the client tools aren't installed.
- Celery or RQ workers run as separate processes, so give each one its own terminal.
- For RabbitMQ, check the management UI on port 15672 if the compose file publishes it.

## Common failures

| Failure | Fix |
|---|---|
| `psycopg2` won't build | Use `psycopg2-binary` if the project allows it, or `brew install libpq` and put its `bin` on `PATH` |
| `zlib` or `_scproxy` errors while building Python | Install Xcode Command Line Tools with `xcode-select --install`, plus `brew install zlib openssl readline` |
| `mysqlclient` won't build | `brew install mysql-client pkg-config` and put its `bin` on `PATH` |
