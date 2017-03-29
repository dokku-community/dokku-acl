#!/usr/bin/env bats
load test_helper

APP=acl-test-app
APP_DIR="${DOKKU_ROOT:?}/$APP"
HOOK="${DOKKU_ROOT:?}/plugins/${PLUGIN_COMMAND_PREFIX:?}/user-auth"

# Test a subset of easy to check commands
ALLOWED_CMDS="apps:list certs:report help"
RESTRICTED_CMDS="domains:report events ls ps:report"
ALL_CMDS="$ALLOWED_CMDS $RESTRICTED_CMDS"

@test "($PLUGIN_COMMAND_PREFIX:hook-user-auth) allows all commands by default" {
  for cmd in $ALL_CMDS; do
    run $HOOK dokku user1 $cmd
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

@test "($PLUGIN_COMMAND_PREFIX:hook-user-auth) superuser and root can run any commands" {
  export DOKKU_ACL_USER_COMMANDS="$ALLOWED_CMDS"
  export DOKKU_SUPER_USER=admin

  for cmd in $ALL_CMDS; do
    run $HOOK dokku admin $cmd
    assert_success
  done

  for cmd in $ALL_CMDS; do
    run $HOOK root root $cmd
    assert_success
  done
}
