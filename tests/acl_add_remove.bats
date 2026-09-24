#!/usr/bin/env bats

load 'test_helper'

setup() {
  APP="$(new_app_name)"
  create_app "$APP"
}

teardown() {
  cleanup_app "$APP"
}

@test "(acl:add) adds a user to the app acl" {
  run dokku acl:add "$APP" user1
  [ "$status" -eq 0 ]
  $SUDO test -f "$(acl_file "$APP" user1)"
}

@test "(acl:add) fails with exit 2 when the user is already in the acl" {
  dokku acl:add "$APP" user1
  run dokku acl:add "$APP" user1
  [ "$status" -eq 2 ]
  [[ "$output" == *"User already has permissions to push to this repository"* ]]
  $SUDO test -f "$(acl_file "$APP" user1)"
}

@test "(acl:add) fails without a user" {
  run dokku acl:add "$APP"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Please specify a user name"* ]]
  $SUDO test ! -d "$(acl_dir "$APP")"
}

@test "(acl:add) fails for an app that does not exist" {
  run dokku acl:add acltest-missing-app user1
  [ "$status" -ne 0 ]
  [[ "$output" == *"App acltest-missing-app does not exist"* ]]
}

@test "(acl:add) refuses to run over ssh" {
  run fire_trigger NAME=user1 subcommands/add "$APP" user2
  [ "$status" -ne 0 ]
  [[ "$output" == *"$ACL_SSH_MODIFY_ERROR"* ]]
  $SUDO test ! -e "$(acl_file "$APP" user2)"
}

@test "(acl:remove) removes the user and the empty acl directory" {
  dokku acl:add "$APP" user1
  run dokku acl:remove "$APP" user1
  [ "$status" -eq 0 ]
  $SUDO test ! -e "$(acl_file "$APP" user1)"
  $SUDO test ! -d "$(acl_dir "$APP")"
}

@test "(acl:remove) keeps the acl directory while other users remain" {
  dokku acl:add "$APP" user1
  dokku acl:add "$APP" user2
  run dokku acl:remove "$APP" user1
  [ "$status" -eq 0 ]
  $SUDO test ! -e "$(acl_file "$APP" user1)"
  $SUDO test -f "$(acl_file "$APP" user2)"
}

@test "(acl:remove) succeeds when the user is not in the acl" {
  run dokku acl:remove "$APP" user1
  [ "$status" -eq 0 ]

  dokku acl:add "$APP" user2
  run dokku acl:remove "$APP" user1
  [ "$status" -eq 0 ]
  $SUDO test -f "$(acl_file "$APP" user2)"
}

@test "(acl:remove) fails without a user" {
  run dokku acl:remove "$APP"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Please specify a user name"* ]]
}

@test "(acl:remove) fails for an app that does not exist" {
  run dokku acl:remove acltest-missing-app user1
  [ "$status" -ne 0 ]
  [[ "$output" == *"App acltest-missing-app does not exist"* ]]
}

@test "(acl:remove) refuses to run over ssh" {
  dokku acl:add "$APP" user1
  run fire_trigger NAME=user1 subcommands/remove "$APP" user1
  [ "$status" -ne 0 ]
  [[ "$output" == *"$ACL_SSH_MODIFY_ERROR"* ]]
  $SUDO test -f "$(acl_file "$APP" user1)"
}

@test "(acl:add) rejects user names that escape the acl directory" {
  for user in . .. ../ENV user/other; do
    run dokku acl:add "$APP" "$user"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid user name: $user"* ]]
  done
  $SUDO test ! -d "$(acl_dir "$APP")"
  $SUDO test ! -e "/home/dokku/$APP/other"
}

@test "(acl:remove) rejects user names that escape the acl directory" {
  dokku acl:add "$APP" user1
  $SUDO touch "/home/dokku/$APP/ENV"
  for user in . .. ../ENV user1/other; do
    run dokku acl:remove "$APP" "$user"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid user name: $user"* ]]
  done
  $SUDO test -f "/home/dokku/$APP/ENV"
  $SUDO test -f "$(acl_file "$APP" user1)"
}
