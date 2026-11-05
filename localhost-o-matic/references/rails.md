# Ruby and Rails

## Ruby version

Compare `.ruby-version` or `.tool-versions` with `ruby -v`. Install with the manager already present:

| Manager | Command, run in the project |
|---|---|
| mise | `mise install ruby` |
| asdf | `asdf install ruby` |
| rbenv | `rbenv install "$(cat .ruby-version)"` |
| rvm | `rvm install "$(cat .ruby-version)"` |

If none is present on macOS, recommend `brew install mise`.

**Macs often show the system Ruby 2.6.** That means the manager isn't active in this shell. Use a per-command prefix rather than changing the shell profile:

```bash
export PATH="$HOME/.local/share/mise/installs/ruby/$(cat .ruby-version)/bin:$PATH"
```

## Gems

- Prefer `bin/setup` if the project has one, after reading it.
- Run `bundle install` rather than trusting `bundle check`. It can give misleading results in non-interactive shells, and git-sourced gems may not be checked out. `bundle install` is safe to repeat.
- First runs can take 5 to 10 minutes.
- On Apple Silicon, if native extensions can't find OpenSSL:
  ```bash
  export LIBRARY_PATH="$LIBRARY_PATH:$(brew --prefix openssl)/lib"
  ```

| Failure | Fix |
|---|---|
| `mysql2` won't build | `brew install openssl zstd`, then retry |
| `nio4r` won't build | `bundle config build.nio4r --with-cflags="-std=c99"`, then retry |
| Permission errors on git-sourced gems | Check the SSH key can reach that host |

Install `foreman` with `gem install foreman` if a `Procfile` needs it and it isn't in the `Gemfile`.

## Database

Use `bin/rails db:prepare` when available, because it creates, loads and migrates as needed and is safe to repeat. Otherwise use the commands in the project's docs. Seeds can take several minutes, so warn first.

A quick connection check:

```bash
bin/rails runner "ActiveRecord::Base.connection.execute('SELECT 1')"
```

## Elasticsearch

If it's in the compose file, check `curl -s localhost:9200/_cluster/health`. Green or yellow is fine locally. Allow about 30 seconds for startup. On Apple Silicon, use an ARM64-compatible image. Check the project's rake tasks for index creation.

## Custom local domains

- Rails 6 and later reject unknown hostnames. For a custom domain or tunnel, add `config.hosts << "myapp.test"` to the development config, and flag this as a tracked file change.
- For puma-dev, `echo <port> > ~/.puma-dev/<name>` routes `https://<name>.test` to that port. Run `sudo puma-dev -setup` once, handing the command to the person, then `puma-dev -install -d test`.
- If puma-dev routing stops working, restart it with `pkill -HUP puma-dev`.
- For `OpenSSL::SSL::SSLError`, trust puma-dev's certificate authority. On macOS the person runs:
  ```bash
  sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "$HOME/Library/Application Support/io.puma.dev/cert.pem"
  ```
