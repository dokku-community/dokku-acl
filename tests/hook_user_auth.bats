#!/usr/bin/env bats
load test_helper

APP=acl-test-app
APP_DIR="${DOKKU_ROOT:?}/$APP"
HOOK="${DOKKU_ROOT:?}/plugins/${PLUGIN_COMMAND_PREFIX:?}/user-auth"

# Test a subset of easy to check commands
ALLOWED_CMDS="apps:list certs:report help"
RESTRICTED_CMDS="domains:report events ls ps:report"
ALL_CMDS="$ALLOWED_CMDS $RESTRICTED_CMDS"

# Slightly more complicated: these commands require an app name as an argument
PER_APP_CMDS="config logs urls"

setup() {
  dokku apps:create acl-test-app >&2
}

teardown() {
  sudo -u dokku rm -rf "${APP_DIR:?}"
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
  sudo -u dokku mkdir -p $APP_DIR/acl
  sudo -u dokku touch $APP_DIR/acl/user1

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

@test "($PLUGIN_COMMAND_PREFIX:hook-user-auth) superuser and root can run any commands" {
  export DOKKU_ACL_USER_COMMANDS="$ALLOWED_CMDS"
  export DOKKU_ACL_PER_APP_COMMANDS="$PER_APP_CMDS"
  export DOKKU_SUPER_USER=admin

  for cmd in $ALL_CMDS; do
    run $HOOK dokku admin $cmd
    assert_success
  done

  for cmd in $ALL_CMDS; do
    run $HOOK root root $cmd
    assert_success
  done

  for cmd in $PER_APP_CMDS; do
    run $HOOK dokku admin $cmd acl-test-app
    assert_success
  done

  for cmd in $PER_APP_CMDS; do
    run $HOOK root root $cmd acl-test-app
    assert_success
  done
}
