#!/usr/bin/env bats

load 'test_helper'

setup() {
  APP="$(new_app_name)"
  create_app "$APP"
}

teardown() {
  clear_acl_config
  acl_cli --force apps:destroy "$APP" >/dev/null 2>&1 || true
}

@test "(acl:report) shows every field for an app" {
  dokku acl:add "$APP" user1
  run dokku acl:report "$APP"
  [ "$status" -eq 0 ]
  for field in "Acl allowed users" "Acl global allow command line" "Acl global super user" \
    "Acl global user commands" "Acl global per app commands" \
    "Acl global per service commands" "Acl global link commands"; do
    [[ "$output" == *"$field"* ]]
  done
  [[ "$output" == *"user1"* ]]
}

@test "(acl:report) reports every app when no app is given" {
  dokku acl:add "$APP" user1
  run dokku acl:report
  [ "$status" -eq 0 ]
  [[ "$output" == *"Acl allowed users"*"user1"* ]]
}

@test "(acl:report) --acl-allowed-users lists the users in the acl" {
  dokku acl:add "$APP" user2
  dokku acl:add "$APP" user1
  run dokku acl:report "$APP" --acl-allowed-users
  [ "$status" -eq 0 ]
  [ "$output" = "user1 user2" ]
}

@test "(acl:report) an info flag with no value prints nothing and succeeds" {
  run dokku acl:report "$APP" --acl-allowed-users
  [ "$status" -eq 0 ]
  [ -z "$output" ]

  run dokku acl:report "$APP" --acl-global-super-user
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "(acl:report) reports the global settings from the dokkurc" {
  set_acl_config \
    "export DOKKU_ACL_ALLOW_COMMAND_LINE=1" \
    "export DOKKU_SUPER_USER=admin" \
    'export DOKKU_ACL_USER_COMMANDS="help version"' \
    'export DOKKU_ACL_PER_APP_COMMANDS="logs urls"' \
    'export DOKKU_ACL_PER_SERVICE_COMMANDS="redis:info"' \
    'export DOKKU_ACL_LINK_COMMANDS="redis:link redis:unlink"'

  run acl_cli acl:report "$APP" --acl-global-allow-command-line
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]

  run acl_cli acl:report "$APP" --acl-global-super-user
  [ "$status" -eq 0 ]
  [ "$output" = "admin" ]

  run acl_cli acl:report "$APP" --acl-global-user-commands
  [ "$status" -eq 0 ]
  [ "$output" = "help version" ]

  run acl_cli acl:report "$APP" --acl-global-per-app-commands
  [ "$status" -eq 0 ]
  [ "$output" = "logs urls" ]

  run acl_cli acl:report "$APP" --acl-global-per-service-commands
  [ "$status" -eq 0 ]
  [ "$output" = "redis:info" ]

  run acl_cli acl:report "$APP" --acl-global-link-commands
  [ "$status" -eq 0 ]
  [ "$output" = "redis:link redis:unlink" ]
}

@test "(acl:report) fails on an invalid flag and lists the valid ones" {
  run dokku acl:report "$APP" --acl-invalid
  [ "$status" -ne 0 ]
  [[ "$output" == *"Invalid flag passed, valid flags:"* ]]
  [[ "$output" == *"--acl-allowed-users"* ]]
  [[ "$output" == *"--acl-global-link-commands"* ]]
}

@test "(acl:report) fails for an app that does not exist" {
  run dokku acl:report acltest-missing-app
  [ "$status" -ne 0 ]
  [[ "$output" == *"App acltest-missing-app does not exist"* ]]
}
