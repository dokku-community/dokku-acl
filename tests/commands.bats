#!/usr/bin/env bats
load test_helper

APP=acl-test-app
APP_DIR="${DOKKU_ROOT:?}/$APP"
HOOK="${DOKKU_ROOT:?}/plugins/${PLUGIN_COMMAND_PREFIX:?}/pre-build"

setup() {
  dokku apps:create acl-test-app >&2
}

teardown() {
  sudo -u dokku rm -rf "${APP_DIR:?}"
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
  sudo -u dokku mkdir -p $APP_DIR/acl
  sudo -u dokku touch $APP_DIR/acl/user1

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
