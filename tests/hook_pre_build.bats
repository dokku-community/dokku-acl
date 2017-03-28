#!/usr/bin/env bats
load test_helper

APP=acl-test-app
APP_DIR="${DOKKU_ROOT:?}/$APP"
HOOK="${DOKKU_ROOT:?}/plugins/${PLUGIN_COMMAND_PREFIX:?}/pre-build"

setup() {
  dokku apps:create acl-test-app >&2
}

teardown() {
  rm -rf "${APP_DIR:?}"
}

@test "($PLUGIN_COMMAND_PREFIX:hook) allows write access by default" {
  NAME=user1 run $HOOK $APP
  assert_success

  NAME=admin run $HOOK $APP
  assert_success
}

@test "($PLUGIN_COMMAND_PREFIX:hook) allows only configured users" {
  mkdir -p $APP_DIR/acl
  touch $APP_DIR/acl/user1

  NAME=user1 run $HOOK $APP
  assert_success

  NAME=user2 run $HOOK $APP
  assert_failure
  assert_output "User user2 does not have permissions to modify this repository"

  NAME=admin run $HOOK $APP
  assert_failure
  assert_output "User admin does not have permissions to modify this repository"
}

@test "($PLUGIN_COMMAND_PREFIX:hook) allows only superuser when enabled and no configured users" {
  export DOKKU_SUPER_USER=admin

  NAME=user1 run $HOOK $APP
  assert_output "Only admin can modify a repository if the ACL is empty"
  assert_failure

  NAME=admin run $HOOK $APP
  assert_success
}

@test "($PLUGIN_COMMAND_PREFIX:hook) allows configured users plus superuser when enabled" {
  export DOKKU_SUPER_USER=admin
  mkdir -p $APP_DIR/acl
  touch $APP_DIR/acl/user1

  NAME=user1 run $HOOK $APP
  assert_success

  NAME=user2 run $HOOK $APP
  assert_failure
  assert_output "User user2 does not have permissions to modify this repository"

  NAME=admin run $HOOK $APP
  assert_success
}
