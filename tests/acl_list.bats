#!/usr/bin/env bats

load 'test_helper'

setup() {
  APP="$(new_app_name)"
  APP2="$(new_app_name)"
  create_app "$APP"
  create_app "$APP2"
}

teardown() {
  cleanup_app "$APP"
  cleanup_app "$APP2"
}

@test "(acl:list) lists the users in an app acl" {
  dokku acl:add "$APP" user1
  run dokku acl:list "$APP"
  [ "$status" -eq 0 ]
  [ "$output" = "user1" ]

  dokku acl:add "$APP" user2
  run dokku acl:list "$APP"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "user1" ]
  [ "${lines[1]}" = "user2" ]
}

@test "(acl:list) prints nothing for an app without an acl" {
  run dokku acl:list "$APP"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "(acl:list) lists the acl of every app when no app is given" {
  dokku acl:add "$APP" user1
  dokku acl:add "$APP2" user2
  run dokku acl:list
  [ "$status" -eq 0 ]
  # the per-app headers are suppressed without a tty, so only the users show
  [[ "$output" == *"user1"* ]]
  [[ "$output" == *"user2"* ]]
}

@test "(acl:list) fails for an app that does not exist" {
  run dokku acl:list acltest-missing-app
  [ "$status" -ne 0 ]
  [[ "$output" == *"App acltest-missing-app does not exist"* ]]
}
