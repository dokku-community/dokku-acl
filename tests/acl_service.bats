#!/usr/bin/env bats

load 'test_helper'

bats_require_minimum_version 1.5.0

setup() {
  TYPE="$(new_service_type)"
  SERVICE="svc-a"
  SERVICE2="svc-b"
  create_service "$TYPE" "$SERVICE"
  create_service "$TYPE" "$SERVICE2"
}

teardown() {
  clear_acl_config
  cleanup_service_type "$TYPE"
  [ -n "${PRIVATE_DIR:-}" ] && rm -rf "$PRIVATE_DIR"
  return 0
}

@test "(acl:allowed-services) works from a working directory the dokku user cannot access" {
  dokku acl:add-service "$TYPE" "$SERVICE" user1
  PRIVATE_DIR="$(private_dir)"
  cd "$PRIVATE_DIR"
  run dokku acl:allowed-services "$TYPE" user1
  cd - >/dev/null
  [ "$status" -eq 0 ]
  [ "$output" = "$SERVICE" ]
}

@test "(acl:add-service) adds a user to the service acl" {
  run dokku acl:add-service "$TYPE" "$SERVICE" user1
  [ "$status" -eq 0 ]
  $SUDO test -f "$(service_dir "$TYPE" "$SERVICE")/acl/user1"
}

@test "(acl:add-service) fails with exit 2 when the user is already in the acl" {
  dokku acl:add-service "$TYPE" "$SERVICE" user1
  run dokku acl:add-service "$TYPE" "$SERVICE" user1
  [ "$status" -eq 2 ]
  [[ "$output" == *"User already has permissions"* ]]
}

@test "(acl:add-service) fails without a user" {
  run dokku acl:add-service "$TYPE" "$SERVICE"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Please specify a user name"* ]]
  $SUDO test ! -d "$(service_dir "$TYPE" "$SERVICE")/acl"
}

@test "(acl:add-service) fails for a service that does not exist" {
  run dokku acl:add-service "$TYPE" missing user1
  [ "$status" -ne 0 ]
  [[ "$output" == *"Service missing of type $TYPE does not exist"* ]]
}

@test "(acl:add-service) refuses to run over ssh" {
  run fire_trigger NAME=user1 subcommands/add-service "$TYPE" "$SERVICE" user2
  [ "$status" -ne 0 ]
  [[ "$output" == *"$ACL_SSH_MODIFY_ERROR"* ]]
  $SUDO test ! -e "$(service_dir "$TYPE" "$SERVICE")/acl/user2"
}

@test "(acl:remove-service) removes the user and the empty acl directory" {
  dokku acl:add-service "$TYPE" "$SERVICE" user1
  run dokku acl:remove-service "$TYPE" "$SERVICE" user1
  [ "$status" -eq 0 ]
  $SUDO test ! -d "$(service_dir "$TYPE" "$SERVICE")/acl"
}

@test "(acl:remove-service) keeps the acl directory while other users remain" {
  dokku acl:add-service "$TYPE" "$SERVICE" user1
  dokku acl:add-service "$TYPE" "$SERVICE" user2
  run dokku acl:remove-service "$TYPE" "$SERVICE" user1
  [ "$status" -eq 0 ]
  $SUDO test ! -e "$(service_dir "$TYPE" "$SERVICE")/acl/user1"
  $SUDO test -f "$(service_dir "$TYPE" "$SERVICE")/acl/user2"
}

@test "(acl:remove-service) fails without a user" {
  run dokku acl:remove-service "$TYPE" "$SERVICE"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Please specify a user name"* ]]
}

@test "(acl:remove-service) fails for a service that does not exist" {
  run dokku acl:remove-service "$TYPE" missing user1
  [ "$status" -ne 0 ]
  [[ "$output" == *"Service missing of type $TYPE does not exist"* ]]
}

@test "(acl:remove-service) refuses to run over ssh" {
  dokku acl:add-service "$TYPE" "$SERVICE" user1
  run fire_trigger NAME=user1 subcommands/remove-service "$TYPE" "$SERVICE" user1
  [ "$status" -ne 0 ]
  [[ "$output" == *"$ACL_SSH_MODIFY_ERROR"* ]]
  $SUDO test -f "$(service_dir "$TYPE" "$SERVICE")/acl/user1"
}

@test "(acl:list-service) lists the users in a service acl on stdout" {
  dokku acl:add-service "$TYPE" "$SERVICE" user1
  dokku acl:add-service "$TYPE" "$SERVICE" user2
  run --separate-stderr dokku acl:list-service "$TYPE" "$SERVICE"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "user1" ]
  [ "${lines[1]}" = "user2" ]
}

@test "(acl:list-service) prints nothing for a service without an acl" {
  run dokku acl:list-service "$TYPE" "$SERVICE"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "(acl:list-service) fails for a service that does not exist" {
  run dokku acl:list-service "$TYPE" missing
  [ "$status" -ne 0 ]
  [[ "$output" == *"Service missing of type $TYPE does not exist"* ]]
}

@test "(acl:allowed-services) lists only the services the user has access to" {
  dokku acl:add-service "$TYPE" "$SERVICE" user1
  dokku acl:add-service "$TYPE" "$SERVICE2" user2
  run dokku acl:allowed-services "$TYPE" user1
  [ "$status" -eq 0 ]
  [ "$output" = "$SERVICE" ]
}

@test "(acl:allowed-services) prints nothing for a user without access" {
  run dokku acl:allowed-services "$TYPE" user1
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "(acl:allowed-services) lists every service of the type for the super user" {
  set_acl_config "export DOKKU_SUPER_USER=admin"
  run dokku acl:allowed-services "$TYPE" admin
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$SERVICE" ]
  [ "${lines[1]}" = "$SERVICE2" ]
}

@test "(acl:allowed-services) lists every service of the type for each of multiple super users" {
  set_acl_config 'export DOKKU_SUPER_USER="admin admin2"'
  for user in admin admin2; do
    run dokku acl:allowed-services "$TYPE" "$user"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "$SERVICE" ]
    [ "${lines[1]}" = "$SERVICE2" ]
  done

  run dokku acl:allowed-services "$TYPE" user1
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "(acl:allowed-services) fails without a type or username" {
  run dokku acl:allowed-services
  [ "$status" -ne 0 ]
  [[ "$output" == *"No service type specified"* ]]

  run dokku acl:allowed-services "$TYPE"
  [ "$status" -ne 0 ]
  [[ "$output" == *"No username specified"* ]]
}

@test "(acl:allowed-services) fails when the service plugin is not installed" {
  run dokku acl:allowed-services acltest-missing-type user1
  [ "$status" -ne 0 ]
  [[ "$output" == *"acltest-missing-type service plugin not detected"* ]]
}

@test "(acl:allowed-services) refuses to run over ssh" {
  run fire_trigger NAME=user1 subcommands/allowed-services "$TYPE" user1
  [ "$status" -ne 0 ]
  [[ "$output" == *"This command can only be run using the local dokku command on the target host"* ]]
}
