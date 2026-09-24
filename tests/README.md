# Test suite

The bats suite exercises the plugin end-to-end inside a docker-compose stack: a derived dokku image with the plugin source bind-mounted at `/plugin-src`. Tests run inside the dokku container so they call `dokku ...` directly. Apps are created with `apps:create` but never deployed - every assertion is made against the files the plugin manages (`/home/dokku/<app>/acl/<user>` and `/var/lib/dokku/services/<type>/<service>/acl/<user>`) and against `dokku acl:*` output.

The hooks the plugin implements - `pre-build`, `pre-delete`, `pre-receive-app`, and `user-auth` - are exercised by invoking the plugin's own trigger scripts directly with the dokku plugin environment the CLI would normally export, so no deploy or ssh connection is required. Leading `VAR=VALUE` arguments to the `fire_trigger` helper set the hook's environment, which is how tests simulate an ssh user (`NAME=user1`) or the legacy dokkurc variables the `install` trigger migrates (`DOKKU_SUPER_USER=admin`). `user-auth` tests set `NAME` to the ssh key name to simulate an ssh user, and leave it unset to simulate command line usage such as cron jobs and systemd services. `pre-delete` is additionally exercised through a real `apps:destroy`, and `user-auth` through the CLI run as the dokku user with `sudo -u dokku`. Global settings are set with `dokku acl:set --global` through the `set_acl_property` helper and removed in teardown with `clear_acl_properties`, which deletes the plugin's global property directory under `/var/lib/dokku/config/acl`.

Service acls only require the service's data directory to exist, so the suite creates bare directories under `/var/lib/dokku/services` instead of installing a datastore plugin.

## Running the suite locally

From the repo root:

```shell
make test
```

That runs `lint` and `unit-tests` against an already-running stack; run `make setup` first to bring the stack up and install the plugin. Stack containers stay up between runs so subsequent invocations are fast. Use `make clean` to tear everything down and remove the host-side state directory at `tmp/acltest-host`.

Useful targets:

| Target | What it does |
|--------|--------------|
| `make setup` | Bring up the compose stack, install the plugin into the dokku container. |
| `make lint` | Run shellcheck against the plugin's bash files. |
| `make unit-tests` | Run the bats suite. |
| `make test` | `lint` then `unit-tests`. |
| `make logs` | Tail the last 200 lines of compose logs. |
| `make clean` | `docker compose down -v` and remove `tmp/acltest-host`. |

## Scoping a run to a single test

Pass `UNIT_TESTS=` to limit to one bats file:

```shell
make unit-tests UNIT_TESTS=acl_report.bats
```

Pass `UNIT_TESTS_FILTER=` (a regex matched against test names) to scope further:

```shell
make unit-tests UNIT_TESTS=acl_user_auth.bats UNIT_TESTS_FILTER='link'
```

`UNIT_TESTS_FILTER` works without `UNIT_TESTS` too - it'll filter across the whole suite.

## Picking a different dokku version

```shell
make test DOKKU_VERSION=0.35.0
```

Defaults to `latest`. Tear the stack down (`make clean`) before switching versions so the dokku container is rebuilt against the new tag.

## What gets printed

`make unit-tests` runs bats with `--timing` and `--print-output-on-failure`, so each line includes the per-test duration and any failing test dumps the captured `$output` automatically. No extra flags needed.

## Native mode

The same suite can also run against a Dokku installed directly on the host - the same path the plugin actually ships through. CI runs both modes in parallel; locally it's an opt-in path because `bootstrap.sh` is destructive (it installs Dokku, configures nginx, and creates a `dokku` system user). **Linux only**, and not safe to run on a workstation you care about - use a throwaway VM or a fresh container.

```shell
make setup-native
make unit-tests-native
make clean-native
```

| Target | What it does |
|--------|--------------|
| `make setup-native` | Bootstrap dokku via the upstream `bootstrap.sh`, install the plugin natively. |
| `make unit-tests-native` | Run the bats suite directly on the host against the native dokku install. Same `UNIT_TESTS` / `UNIT_TESTS_FILTER` knobs as `unit-tests`. |
| `make clean-native` | No-op - acl needs no supporting compose services. The native dokku install itself is left in place. |

`setup-native` honors `DOKKU_TAG` to install a specific Dokku release instead of master.

## Continuous integration

`.github/workflows/ci.yml` runs both the compose and native modes on every push to `master` and every pull request, across a matrix of dokku versions: 0.35.0 (the minimum supported version, and the first release that installs on Ubuntu 24.04) and the latest release. Two more workflows handle releases: `tagged-release.yaml` publishes a GitHub release when a tag is pushed, and `bump-version.yaml` is a manual dispatch that bumps `plugin.toml` and pushes a new tag (it requires a `GH_ACCESS_TOKEN` repo secret to push). `.github/dependabot.yaml` keeps the GitHub Actions used by these workflows up to date.
