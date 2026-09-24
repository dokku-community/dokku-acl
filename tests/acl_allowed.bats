#!/usr/bin/env bats

load 'test_helper'

setup() {
  APP="$(new_app_name)"
  APP2="$(new_app_name)"
  create_app "$APP"
  create_app "$APP2"
}

teardown() {
  clear_acl_properties
  cleanup_app "$APP"
  cleanup_app "$APP2"
  [ -n "${PRIVATE_DIR:-}" ] && rm -rf "$PRIVATE_DIR"
  return 0
}

@test "(acl:allowed) works from a working directory the dokku user cannot access" {
  dokku acl:add "$APP" user1
  PRIVATE_DIR="$(private_dir)"
  cd "$PRIVATE_DIR"
  run dokku acl:allowed user1
  cd - >/dev/null
  [ "$status" -eq 0 ]
  [ "$output" = "$APP" ]
}

@test "(acl:allowed) lists only the apps the user has access to" {
  dokku acl:add "$APP" user1
  dokku acl:add "$APP2" user2
  run dokku acl:allowed user1
  [ "$status" -eq 0 ]
  [ "$output" = "$APP" ]

  dokku acl:add "$APP2" user1
  run dokku acl:allowed user1
  [ "$status" -eq 0 ]
  [[ "$output" == *"$APP"* ]]
  [[ "$output" == *"$APP2"* ]]
}

@test "(acl:allowed) prints nothing for a user without access" {
  dokku acl:add "$APP" user1
  run dokku acl:allowed user2
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "(acl:allowed) lists every app for the super user" {
  set_acl_property super-user admin
  dokku acl:add "$APP" user1
  run dokku acl:allowed admin
  [ "$status" -eq 0 ]
  [[ "$output" == *"$APP"* ]]
  [[ "$output" == *"$APP2"* ]]
}

@test "(acl:allowed) lists every app for each of multiple super users" {
  set_acl_property super-user admin admin2
  dokku acl:add "$APP" user1
  for user in admin admin2; do
    run dokku acl:allowed "$user"
    [ "$status" -eq 0 ]
    [[ "$output" == *"$APP"* ]]
    [[ "$output" == *"$APP2"* ]]
  done

  run dokku acl:allowed user1
  [ "$status" -eq 0 ]
  [ "$output" = "$APP" ]
}

@test "(acl:allowed) fails without a username" {
  run dokku acl:allowed
  [ "$status" -ne 0 ]
  [[ "$output" == *"No username specified"* ]]
}

@test "(acl:allowed) refuses to run over ssh" {
  run fire_trigger NAME=user1 subcommands/allowed user1
  [ "$status" -ne 0 ]
  [[ "$output" == *"This command can only be run using the local dokku command on the target host"* ]]
}
