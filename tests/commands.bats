#!/usr/bin/env bats
load test_helper

APP=acl-test-app
APP_DIR="${DOKKU_ROOT:?}/$APP"
HOOK="${DOKKU_ROOT:?}/plugins/${PLUGIN_COMMAND_PREFIX:?}/pre-build"

setup() {
  dokku apps:create acl-test-app >&2
  TMP=$(mktemp -d)
  export DOKKU_LIB_ROOT="$TMP"
  export DOKKU_LIB_PATH="$TMP"
  SERVICE_PATH="$DOKKU_LIB_ROOT/services/redis/acl-test-service"
  mkdir -p "$SERVICE_PATH"
}

teardown() {
  sudo -u $DOKKU_SYSTEM_USER rm -rf "${APP_DIR:?}"
  rm -rf "$TMP"
}

@test "($PLUGIN_COMMAND_PREFIX:add) can add a user to an ACL" {
  run dokku acl:add $APP user1
  assert_success
  echo exit $?

  [ -e "${APP_DIR}/acl/user1" ] || flunk "ACL file not created"
}

@test "($PLUGIN_COMMAND_PREFIX:add) adding user that already exists fails" {
  dokku acl:add $APP user1
  run dokku acl:add $APP user1
  assert_failure "User already has permissions to push to this repository"

  [ -e "${APP_DIR}/acl/user1" ] || flunk "ACL file disappeared somehow"
}

@test "($PLUGIN_COMMAND_PREFIX:remove) can remove a user from an ACL" {
  sudo -u $DOKKU_SYSTEM_USER mkdir -p $APP_DIR/acl
  sudo -u $DOKKU_SYSTEM_USER touch $APP_DIR/acl/user1

  run dokku acl:remove $APP user1
  assert_success

  [ ! -e "${APP_DIR}/acl/user1" ] || flunk "ACL file still exists"
}

@test "($PLUGIN_COMMAND_PREFIX:list) can list users in an ACL" {
  dokku acl:add $APP user1

  run dokku acl:list $APP
  assert_success "user1"

  dokku acl:add $APP user2

  run dokku acl:list $APP
  assert_success
  assert_equal ${lines[0]} "user1"
  assert_equal ${lines[1]} "user2"
}

@test "($PLUGIN_COMMAND_PREFIX:add) can add a user to a service ACL" {
  run dokku acl:add-service redis acl-test-service user1
  assert_success
  echo exit $?

  [ -e "$SERVICE_PATH/acl/user1" ] || flunk "ACL file not created"
}

@test "($PLUGIN_COMMAND_PREFIX:remove) can remove a user from a service ACL" {
  sudo -u "$DOKKU_SYSTEM_USER" mkdir -p "$SERVICE_PATH/acl"
  sudo -u "$DOKKU_SYSTEM_USER" touch "$SERVICE_PATH/acl/user1"

  run dokku acl:remove-service redis acl-test-service user1
  assert_success

  [ ! -e "$SERVICE_PATH/acl/user1" ] || flunk "ACL file still exists"
}

@test "($PLUGIN_COMMAND_PREFIX:list) can list users in a service ACL" {
  dokku acl:add-service redis acl-test-service user1

  run dokku acl:list-service redis acl-test-service
  assert_success "user1"

  dokku acl:add-service redis acl-test-service user2

  run dokku acl:list-service redis acl-test-service
  assert_success
  assert_equal ${lines[0]} "user1"
  assert_equal ${lines[1]} "user2"
}

@test "($PLUGIN_COMMAND_PREFIX:default) help information is shown by default" {
  if [[ $DOKKU_VERSION = 'v0.4.0' ]] ; then
    skip "Default commands weren't implemented for v0.4.0"
  fi

  run dokku acl:help
  help_output="$output"
  assert_success

  run dokku acl
  assert_success "$help_output"
}
