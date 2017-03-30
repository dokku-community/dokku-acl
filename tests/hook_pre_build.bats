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

@test "($PLUGIN_COMMAND_PREFIX:hook-pre-build) allows write access by default" {
  NAME=user1 run $HOOK $APP
  assert_success

  NAME=admin run $HOOK $APP
  assert_success
}

@test "($PLUGIN_COMMAND_PREFIX:hook-pre-build) allows only configured users" {
  sudo -u dokku mkdir -p $APP_DIR/acl
  sudo -u dokku touch $APP_DIR/acl/user1

  NAME=user1 run $HOOK $APP
  assert_success

  NAME=user2 run $HOOK $APP
  assert_failure "User user2 does not have permissions to modify this repository"

  NAME=admin run $HOOK $APP
  assert_failure "User admin does not have permissions to modify this repository"
}

@test "($PLUGIN_COMMAND_PREFIX:hook-pre-build) allows only superuser when enabled and no configured users" {
  export DOKKU_SUPER_USER=admin

  NAME=user1 run $HOOK $APP
  assert_failure "Only admin can modify a repository if the ACL is empty"

  NAME=admin run $HOOK $APP
  assert_success
}

@test "($PLUGIN_COMMAND_PREFIX:hook-pre-build) allows configured users plus superuser when enabled" {
  export DOKKU_SUPER_USER=admin
  sudo -u dokku mkdir -p $APP_DIR/acl
  sudo -u dokku touch $APP_DIR/acl/user1

  NAME=user1 run $HOOK $APP
  assert_success

  NAME=user2 run $HOOK $APP
  assert_failure "User user2 does not have permissions to modify this repository"

  NAME=admin run $HOOK $APP
  assert_success
}

@test "($PLUGIN_COMMAND_PREFIX:hook-pre-build) implements legacy command line behaviour by default" {
  unset NAME

  # No app ACL, no DOKKU_SUPER_USER -> success
  SSH_NAME=default run $HOOK $APP
  assert_success

  run $HOOK $APP
  assert_success

  # No app ACL, DOKKU_SUPER_USER set -> failure
  export DOKKU_SUPER_USER=admin

  SSH_NAME=default run $HOOK $APP
  assert_failure "It appears that you're running this command from the command line.  The \"dokku-acl\" plugin disables this by default for safety.  Please check the \"dokku-acl\" documentation for how to enable command line usage."

  run $HOOK $APP
  assert_failure "It appears that you're running this command from the command line.  The \"dokku-acl\" plugin disables this by default for safety.  Please check the \"dokku-acl\" documentation for how to enable command line usage."

  # App ACL exists, no DOKKU_SUPER_USER -> success
  unset DOKKU_SUPER_USER
  sudo -u dokku mkdir -p $APP_DIR/acl
  sudo -u dokku touch $APP_DIR/acl/user1

  SSH_NAME=default run $HOOK $APP
  assert_success

  run $HOOK $APP
  assert_success

  # App ACL exists, DOKKU_SUPER_USER set -> failure
  export DOKKU_SUPER_USER=admin

  SSH_NAME=default run $HOOK $APP
  assert_failure "It appears that you're running this command from the command line.  The \"dokku-acl\" plugin disables this by default for safety.  Please check the \"dokku-acl\" documentation for how to enable command line usage."

  run $HOOK $APP
  assert_failure "It appears that you're running this command from the command line.  The \"dokku-acl\" plugin disables this by default for safety.  Please check the \"dokku-acl\" documentation for how to enable command line usage."
}
