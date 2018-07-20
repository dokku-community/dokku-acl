#!/usr/bin/env bats
load test_helper

APP=acl-test-app
APP_DIR="${DOKKU_ROOT:?}/$APP"
HOOK="${DOKKU_ROOT:?}/plugins/${PLUGIN_COMMAND_PREFIX:?}/user-auth"

# Test a subset of easy to check commands
ALLOWED_CMDS="apps:list certs:report help"
RESTRICTED_CMDS="domains:report events ls ps:report"
ALL_CMDS="$ALLOWED_CMDS $RESTRICTED_CMDS"

# Slightly more complicated: these commands require an app and/or service name as an argument
PER_APP_CMDS="config logs urls"
PER_SERVICE_CMDS="redis:info redis:stop"
LINK_CMDS="redis:link redis:unlink"

setup() {
  dokku apps:create acl-test-app >&2
  TMP=$(mktemp -d)
  export DOKKU_LIB_ROOT="$TMP"
}

teardown() {
  sudo -u $DOKKU_SYSTEM_USER rm -rf "${APP_DIR:?}"
  rm -rf "$TMP"
}

@test "($PLUGIN_COMMAND_PREFIX:hook-user-auth) allows all commands by default" {
  for cmd in $ALL_CMDS; do
    run $HOOK dokku user1 $cmd
    assert_success
  done

  for cmd in $PER_APP_CMDS; do
    run $HOOK dokku user1 $cmd acl-test-app
    assert_success
  done
}

@test "($PLUGIN_COMMAND_PREFIX:hook-user-auth) allows only whitelisted commands" {
  export DOKKU_ACL_USER_COMMANDS="$ALLOWED_CMDS"

  for cmd in $ALLOWED_CMDS; do
    run $HOOK dokku user1 $cmd
    assert_success
  done

  for cmd in $RESTRICTED_CMDS; do
    run $HOOK dokku user1 $cmd
    assert_failure "User user1 does not have permissions to run $cmd"
  done
}

@test "($PLUGIN_COMMAND_PREFIX:hook-user-auth) allows per-app commands only for users in the app ACL" {
  export DOKKU_ACL_PER_APP_COMMANDS="$PER_APP_CMDS"
  sudo -u $DOKKU_SYSTEM_USER mkdir -p $APP_DIR/acl
  sudo -u $DOKKU_SYSTEM_USER touch $APP_DIR/acl/user1

  for cmd in $PER_APP_CMDS; do
    run $HOOK dokku user1 $cmd acl-test-app
    assert_success
  done

  for cmd in $PER_APP_CMDS; do
    run $HOOK dokku user2 $cmd acl-test-app
    assert_failure "User user2 does not have permissions to run $cmd on acl-test-app, or acl-test-app does not exist"
  done
}

@test "($PLUGIN_COMMAND_PREFIX:hook-user-auth) per-app commands do not reveal if an app exists or not" {
  export DOKKU_ACL_PER_APP_COMMANDS="$PER_APP_CMDS"

  for cmd in $PER_APP_CMDS; do
    run $HOOK dokku user2 $cmd nonexistent-app
    assert_failure "User user2 does not have permissions to run $cmd on nonexistent-app, or nonexistent-app does not exist"
  done
}

@test "($PLUGIN_COMMAND_PREFIX:hook-user-auth) per-app commands fail if no app" {
  export DOKKU_ACL_PER_APP_COMMANDS="$PER_APP_CMDS"

  for cmd in $PER_APP_CMDS; do
    run $HOOK dokku user2 $cmd
    assert_failure "An app name is required"
  done
}

@test "($PLUGIN_COMMAND_PREFIX:hook-user-auth) allows per-service commands only for users in the service ACL" {
  export DOKKU_ACL_PER_SERVICE_COMMANDS="$PER_SERVICE_CMDS"
  local SERVICE_DIR="$DOKKU_LIB_ROOT/services/redis/acl-test-service"
  sudo -u $DOKKU_SYSTEM_USER mkdir -p $SERVICE_DIR/acl
  sudo -u $DOKKU_SYSTEM_USER touch $SERVICE_DIR/acl/user1

  for cmd in $PER_SERVICE_CMDS; do
    run $HOOK dokku user1 $cmd acl-test-service
    assert_success
  done

  for cmd in $PER_SERVICE_CMDS; do
    run $HOOK dokku user2 $cmd acl-test-service
    assert_failure "User user2 does not have permissions to run $cmd on acl-test-service, or acl-test-service does not exist"
  done
}

@test "($PLUGIN_COMMAND_PREFIX:hook-user-auth) allows link commands only for users in the service AND app ACLs" {
  sudo -u $DOKKU_SYSTEM_USER mkdir -p $APP_DIR/acl
  sudo -u $DOKKU_SYSTEM_USER touch $APP_DIR/acl/user1
  sudo -u $DOKKU_SYSTEM_USER touch $APP_DIR/acl/user2

  export DOKKU_ACL_LINK_COMMANDS="$LINK_CMDS"
  local SERVICE_DIR="$DOKKU_LIB_ROOT/services/redis/acl-test-service"
  sudo -u $DOKKU_SYSTEM_USER mkdir -p $SERVICE_DIR/acl
  sudo -u $DOKKU_SYSTEM_USER touch $SERVICE_DIR/acl/user1
  sudo -u $DOKKU_SYSTEM_USER touch $SERVICE_DIR/acl/user3

  for cmd in $LINK_CMDS; do
    run $HOOK dokku user1 $cmd acl-test-service acl-test-app
    assert_success
  done

  for user in user2 user3 user4; do
    for cmd in $LINK_CMDS; do
      run $HOOK dokku $user $cmd acl-test-service acl-test-app

      [[ "$user" = user3 ]] && type=app || type=service

      assert_failure "User $user does not have permissions to run $cmd on acl-test-$type, or acl-test-$type does not exist"
    done
  done
}

@test "($PLUGIN_COMMAND_PREFIX:hook-user-auth) superuser and root can run any commands" {
  export DOKKU_ACL_USER_COMMANDS="$ALLOWED_CMDS"
  export DOKKU_ACL_PER_APP_COMMANDS="$PER_APP_CMDS"
  export DOKKU_ACL_PER_SERVICE_COMMANDS="$PER_SERVICE_CMDS"
  export DOKKU_SUPER_USER=admin

  for cmd in $ALL_CMDS; do
    run $HOOK dokku admin $cmd
    assert_success
  done

  for cmd in $ALL_CMDS; do
    run $HOOK root root $cmd
    assert_success
  done

  for cmd in $PER_APP_CMDS $PER_SERVICE_CMDS; do
    run $HOOK dokku admin $cmd acl-test-thing
    assert_success
  done

  for cmd in $PER_APP_CMDS $PER_SERVICE_CMDS; do
    run $HOOK root root $cmd acl-test-thing
    assert_success
  done

  for cmd in $LINK_CMDS; do
    run $HOOK dokku admin $cmd acl-test-service acl-test-app
    assert_success
  done

  for cmd in $LINK_CMDS; do
    run $HOOK root root $cmd acl-test-service acl-test-app
    assert_success
  done
}
