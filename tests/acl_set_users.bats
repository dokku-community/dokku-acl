#!/usr/bin/env bats

load 'test_helper'

bats_require_minimum_version 1.5.0

setup() {
  APP="$(new_app_name)"
  create_app "$APP"
  TYPE="$(new_service_type)"
  SERVICE="svc-a"
  create_service "$TYPE" "$SERVICE"
}

teardown() {
  cleanup_app "$APP"
  cleanup_service_type "$TYPE"
}

@test "(acl:set-users) sets the users on an app without an acl" {
  run dokku acl:set-users "$APP" user1 user2
  [ "$status" -eq 0 ]
  $SUDO test -f "$(acl_file "$APP" user1)"
  $SUDO test -f "$(acl_file "$APP" user2)"

  run --separate-stderr dokku acl:list "$APP"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]
  [ "${lines[0]}" = "user1" ]
  [ "${lines[1]}" = "user2" ]
}

@test "(acl:set-users) replaces the existing users" {
  dokku acl:add "$APP" user1
  dokku acl:add "$APP" user2
  run dokku acl:set-users "$APP" user2 user3
  [ "$status" -eq 0 ]

  run --separate-stderr dokku acl:list "$APP"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]
  [ "${lines[0]}" = "user2" ]
  [ "${lines[1]}" = "user3" ]
}

@test "(acl:set-users) ignores repeated users" {
  run dokku acl:set-users "$APP" user1 user1
  [ "$status" -eq 0 ]

  run --separate-stderr dokku acl:list "$APP"
  [ "$status" -eq 0 ]
  [ "$output" = "user1" ]
}

@test "(acl:set-users) clears the acl when no users are given" {
  dokku acl:add "$APP" user1
  run dokku acl:set-users "$APP"
  [ "$status" -eq 0 ]
  $SUDO test ! -d "$(acl_dir "$APP")"
}

@test "(acl:set-users) leaves the acl untouched when any user name is invalid" {
  dokku acl:add "$APP" user1
  dokku acl:add "$APP" user2
  $SUDO touch "/home/dokku/$APP/ENV"
  for user in . .. ../ENV user/other; do
    run dokku acl:set-users "$APP" user3 "$user" user1
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid user name: $user"* ]]
  done

  run --separate-stderr dokku acl:list "$APP"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]
  [ "${lines[0]}" = "user1" ]
  [ "${lines[1]}" = "user2" ]
  $SUDO test -f "/home/dokku/$APP/ENV"
}

@test "(acl:set-users) fails for an app that does not exist" {
  run dokku acl:set-users acltest-missing-app user1
  [ "$status" -ne 0 ]
  [[ "$output" == *"App acltest-missing-app does not exist"* ]]
}

@test "(acl:set-users) refuses to run over ssh" {
  dokku acl:add "$APP" user1
  run fire_trigger NAME=user1 subcommands/set-users "$APP" user2
  [ "$status" -ne 0 ]
  [[ "$output" == *"$ACL_SSH_MODIFY_ERROR"* ]]
  $SUDO test -f "$(acl_file "$APP" user1)"
  $SUDO test ! -e "$(acl_file "$APP" user2)"
}

@test "(acl:set-service-users) sets the users on a service without an acl" {
  run dokku acl:set-service-users "$TYPE" "$SERVICE" user1 user2
  [ "$status" -eq 0 ]

  run --separate-stderr dokku acl:list-service "$TYPE" "$SERVICE"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]
  [ "${lines[0]}" = "user1" ]
  [ "${lines[1]}" = "user2" ]
}

@test "(acl:set-service-users) replaces the existing users" {
  dokku acl:add-service "$TYPE" "$SERVICE" user1
  dokku acl:add-service "$TYPE" "$SERVICE" user2
  run dokku acl:set-service-users "$TYPE" "$SERVICE" user2 user3
  [ "$status" -eq 0 ]

  run --separate-stderr dokku acl:list-service "$TYPE" "$SERVICE"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]
  [ "${lines[0]}" = "user2" ]
  [ "${lines[1]}" = "user3" ]
}

@test "(acl:set-service-users) clears the acl when no users are given" {
  dokku acl:add-service "$TYPE" "$SERVICE" user1
  run dokku acl:set-service-users "$TYPE" "$SERVICE"
  [ "$status" -eq 0 ]
  $SUDO test ! -d "$(service_dir "$TYPE" "$SERVICE")/acl"
}

@test "(acl:set-service-users) leaves the acl untouched when any user name is invalid" {
  dokku acl:add-service "$TYPE" "$SERVICE" user1
  $SUDO touch "$(service_dir "$TYPE" "$SERVICE")/data"
  for user in . .. ../data user/other; do
    run dokku acl:set-service-users "$TYPE" "$SERVICE" user2 "$user"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid user name: $user"* ]]
  done

  run --separate-stderr dokku acl:list-service "$TYPE" "$SERVICE"
  [ "$status" -eq 0 ]
  [ "$output" = "user1" ]
  $SUDO test -f "$(service_dir "$TYPE" "$SERVICE")/data"
}

@test "(acl:set-service-users) fails for a service that does not exist" {
  run dokku acl:set-service-users "$TYPE" missing user1
  [ "$status" -ne 0 ]
  [[ "$output" == *"Service missing of type $TYPE does not exist"* ]]
}

@test "(acl:set-service-users) refuses to run over ssh" {
  dokku acl:add-service "$TYPE" "$SERVICE" user1
  run fire_trigger NAME=user1 subcommands/set-service-users "$TYPE" "$SERVICE" user2
  [ "$status" -ne 0 ]
  [[ "$output" == *"$ACL_SSH_MODIFY_ERROR"* ]]
  $SUDO test -f "$(service_dir "$TYPE" "$SERVICE")/acl/user1"
  $SUDO test ! -e "$(service_dir "$TYPE" "$SERVICE")/acl/user2"
}
