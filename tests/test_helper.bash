#!/usr/bin/env bash
# Helpers for the dokku-acl bats suite. Sourced by every *.bats file.

# `SUDO` is empty in compose mode (bats already runs as root in the dokku
# container) and `sudo` in native mode (files under /home/dokku and
# /var/lib/dokku need elevation to create or modify).
SUDO="${SUDO:-}"

# Message the plugin prints when an ACL is modified over ssh.
ACL_SSH_MODIFY_ERROR="You can only modify ACL using local dokku command on target host"

new_app_name() {
  echo "acltest-${BATS_TEST_NUMBER:-0}-$(date +%s)-${RANDOM}"
}

create_app() {
  local app="$1"
  dokku apps:create "$app"
}

cleanup_app() {
  local app="$1"
  if dokku apps:exists "$app" >/dev/null 2>&1; then
    dokku --force apps:destroy "$app" >/dev/null 2>&1 || true
  fi
}

# Run the dokku CLI as root. The CLI records the invoking user as SSH_USER
# before re-executing itself as the dokku user, and the plugin's user-auth hook
# only lets root through unconditionally. In native mode bats runs as an
# unprivileged user, so any test that sets the *-commands acl properties must go
# through this wrapper or the hook would reject the test's own commands.
acl_cli() {
  $SUDO dokku "$@"
}

acl_dir() {
  echo "/home/dokku/$1/acl"
}

acl_file() {
  echo "$(acl_dir "$1")/$2"
}

# Global acl settings are stored as global properties of the acl plugin, e.g.
# `set_acl_property super-user admin admin2`. It goes through the CLI as root
# so it works even when the settings restrict the dokku user.
set_acl_property() {
  acl_cli acl:set --global "$@"
}

acl_properties_dir() {
  echo "/var/lib/dokku/config/acl/--global"
}

clear_acl_properties() {
  $SUDO rm -rf "$(acl_properties_dir)"
}

# Before global settings were properties, they were read from
# ~dokku/.dokkurc/acl, which the dokku CLI sources on every invocation. The
# install trigger imports them from there once, so this is only used by the
# migration tests. Each argument is written as one line of that file, e.g.
# `set_acl_config "export DOKKU_SUPER_USER=admin"`. The file must be readable
# by the dokku user or every dokku command fails.
acl_config_path() {
  echo "/home/dokku/.dokkurc/acl"
}

set_acl_config() {
  local path
  path="$(acl_config_path)"
  $SUDO mkdir -p "$(dirname "$path")"
  printf '%s\n' "$@" | $SUDO tee "$path" >/dev/null
  $SUDO chown -R dokku:dokku "$(dirname "$path")"
  $SUDO chmod 644 "$path"
}

clear_acl_config() {
  $SUDO rm -f "$(acl_config_path)"
}

# Create a directory only the invoking user can access and echo its path. Used
# to run the CLI from a working directory the dokku user cannot enter, as when
# an operator runs dokku from their own home directory. Callers should
# `rm -rf` the returned path in teardown.
private_dir() {
  local dir
  dir="$(mktemp -d)"
  chmod 700 "$dir"
  echo "$dir"
}

# The plugin only checks that a service's data directory exists, so a bare
# directory stands in for a real datastore plugin. It is owned by the dokku user
# so `dokku acl:add-service` can create the acl directory inside it.
service_root() {
  echo "/var/lib/dokku/services/$1"
}

service_dir() {
  echo "$(service_root "$1")/$2"
}

new_service_type() {
  echo "acltest${RANDOM}"
}

create_service() {
  local type="$1" service="$2"
  $SUDO mkdir -p "$(service_dir "$type" "$service")"
  $SUDO chown -R dokku:dokku "$(service_root "$type")"
}

cleanup_service_type() {
  local type="$1"
  [[ -n "$type" ]] || return 0
  $SUDO rm -rf "$(service_root "$type")"
}

# The bats suite never deploys or connects over ssh, so plugin triggers are
# invoked directly. dokku's CLI normally exports the plugin environment; the
# bats shell does not, so set it here. Paths are the standard install layout,
# identical in compose and native modes. The plugin's own trigger scripts are
# run (rather than `plugn trigger`, which fans out to every plugin) to keep
# each assertion scoped to acl. DOKKU_API_VERSION makes the plugin's `config`
# resolve core functions the way it does under the CLI.
dokku_plugin_env() {
  $SUDO env \
    DOKKU_ROOT=/home/dokku \
    DOKKU_LIB_ROOT=/var/lib/dokku \
    DOKKU_API_VERSION=1 \
    DOKKU_NOT_IMPLEMENTED_EXIT=10 \
    PLUGIN_PATH=/var/lib/dokku/plugins \
    PLUGIN_AVAILABLE_PATH=/var/lib/dokku/plugins/available \
    PLUGIN_ENABLED_PATH=/var/lib/dokku/plugins/enabled \
    PLUGIN_CORE_PATH=/var/lib/dokku/core-plugins \
    PLUGIN_CORE_AVAILABLE_PATH=/var/lib/dokku/core-plugins/available \
    "$@"
}

# Absolute path to an installed plugin trigger/subcommand script.
plugin_script() {
  echo "/var/lib/dokku/plugins/available/acl/$1"
}

# Run a plugin trigger or subcommand script directly (see dokku_plugin_env).
# Leading VAR=VALUE arguments are passed to the script's environment, which is
# how tests simulate an ssh user (`NAME=user1`) or the dokkurc variables the
# install trigger migrates (`DOKKU_SUPER_USER=admin`); they must be passed this
# way rather than exported because sudo drops the caller's environment in
# native mode. The first remaining argument is the script name under the
# installed plugin dir; the rest are passed through to it.
fire_trigger() {
  local env_overrides=()
  while [[ "${1:-}" == [A-Z_]*=* ]]; do
    env_overrides+=("$1")
    shift
  done
  local script="$1"
  shift
  dokku_plugin_env "${env_overrides[@]}" "$(plugin_script "$script")" "$@"
}
