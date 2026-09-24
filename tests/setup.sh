#!/usr/bin/env bash
# Run inside the dokku container. Installs the plugin from the bind-mounted
# /plugin-src tree.
set -euo pipefail

PLUGIN_SRC="${PLUGIN_SRC:-/plugin-src}"

log() { echo "-----> $*"; }

# Older dokku images ship without a healthcheck, so `docker compose up --wait`
# returns while the container init is still generating dhparam and before
# runit starts nginx. Every apps:destroy reloads nginx, so wait for it here.
log "Waiting for nginx to start"
for _ in $(seq 1 300); do
  if sv status nginx 2>/dev/null | grep -q '^run:'; then
    break
  fi
  sleep 1
done
if ! sv status nginx 2>/dev/null | grep -q '^run:'; then
  echo "nginx did not start within 300 seconds" >&2
  exit 1
fi

if dokku plugin:installed acl; then
  log "acl plugin already installed; uninstalling first"
  dokku plugin:uninstall acl
fi

# `dokku plugin:install` derives the destination directory name from the
# basename of the source URL, so stage the bind-mounted source at a path
# whose basename is `acl` before installing.
log "Staging plugin source at /tmp/acl"
rm -rf /tmp/acl
cp -r "${PLUGIN_SRC}" /tmp/acl
# the repo's tmp/ scratch dir (compose-mode host state) must not ship inside the plugin
rm -rf /tmp/acl/tmp

# `dokku plugin:install` git-clones the URL, which would install committed
# HEAD rather than the working tree. Re-init the staged copy as a fresh
# single-commit repo so local uncommitted changes are exercised too.
rm -rf /tmp/acl/.git
(
  cd /tmp/acl
  git init --quiet
  git add -A
  git -c user.name=acltest -c user.email=acltest@dokku.test commit --quiet --message "test snapshot"
)

log "Installing acl plugin from /tmp/acl"
dokku plugin:install "file:///tmp/acl"

log "Setup complete"
