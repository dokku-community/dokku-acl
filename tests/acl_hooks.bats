#!/usr/bin/env bats

load 'test_helper'

COMMAND_LINE_ERROR="It appears that you're running this command from the command line, which is disabled because the acl allow-command-line property is set to false.  Run 'sudo dokku acl:set --global allow-command-line true' to enable command line usage."

setup() {
  APP="$(new_app_name)"
  create_app "$APP"
}

teardown() {
  clear_acl_properties
  cleanup_app "$APP"
}

# pre-build receives the app as its second argument; pre-delete and
# pre-receive-app receive it as their first. Leading VAR=VALUE arguments are
# forwarded to the hook's environment.
fire_modify_hook() {
  local env_overrides=()
  while [[ "${1:-}" == [A-Z_]*=* ]]; do
    env_overrides+=("$1")
    shift
  done
  local hook="$1" app="$2"
  case "$hook" in
    pre-build) fire_trigger "${env_overrides[@]}" pre-build herokuish "$app" ;;
    pre-delete) fire_trigger "${env_overrides[@]}" pre-delete "$app" "" ;;
    pre-receive-app) fire_trigger "${env_overrides[@]}" pre-receive-app "$app" herokuish /tmp abc123 ;;
  esac
}

MODIFY_HOOKS="pre-build pre-delete pre-receive-app"

@test "(pre-build, pre-delete, pre-receive-app) allow any user when the acl is empty" {
  for hook in $MODIFY_HOOKS; do
    run fire_modify_hook NAME=user1 "$hook" "$APP"
    [ "$status" -eq 0 ]

    run fire_modify_hook NAME=admin "$hook" "$APP"
    [ "$status" -eq 0 ]
  done
}

@test "(pre-build, pre-delete, pre-receive-app) allow only users in the acl" {
  dokku acl:add "$APP" user1
  for hook in $MODIFY_HOOKS; do
    run fire_modify_hook NAME=user1 "$hook" "$APP"
    [ "$status" -eq 0 ]

    run fire_modify_hook NAME=user2 "$hook" "$APP"
    [ "$status" -eq 2 ]
    [ "$output" = "User user2 does not have permissions to modify this repository" ]

    run fire_modify_hook NAME=admin "$hook" "$APP"
    [ "$status" -eq 2 ]
    [ "$output" = "User admin does not have permissions to modify this repository" ]
  done
}

@test "(pre-build, pre-delete, pre-receive-app) allow only the super user when the acl is empty" {
  set_acl_property super-user admin
  for hook in $MODIFY_HOOKS; do
    run fire_modify_hook NAME=user1 "$hook" "$APP"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Only admin can modify a repository if the ACL is empty"* ]]

    run fire_modify_hook NAME=admin "$hook" "$APP"
    [ "$status" -eq 0 ]
  done
}

@test "(pre-build, pre-delete, pre-receive-app) allow users in the acl plus the super user" {
  set_acl_property super-user admin
  dokku acl:add "$APP" user1
  for hook in $MODIFY_HOOKS; do
    run fire_modify_hook NAME=user1 "$hook" "$APP"
    [ "$status" -eq 0 ]

    run fire_modify_hook NAME=user2 "$hook" "$APP"
    [ "$status" -eq 2 ]
    [ "$output" = "User user2 does not have permissions to modify this repository" ]

    run fire_modify_hook NAME=admin "$hook" "$APP"
    [ "$status" -eq 0 ]
  done
}

@test "(pre-build, pre-delete, pre-receive-app) allow each of multiple super users" {
  set_acl_property super-user admin admin2
  for hook in $MODIFY_HOOKS; do
    for user in admin admin2; do
      run fire_modify_hook NAME="$user" "$hook" "$APP"
      [ "$status" -eq 0 ]
    done

    for user in user1 adm; do
      run fire_modify_hook NAME="$user" "$hook" "$APP"
      [ "$status" -ne 0 ]
      [[ "$output" == *"Only admin, admin2 can modify a repository if the ACL is empty"* ]]
    done
  done

  dokku acl:add "$APP" user1
  for hook in $MODIFY_HOOKS; do
    for user in admin admin2 user1; do
      run fire_modify_hook NAME="$user" "$hook" "$APP"
      [ "$status" -eq 0 ]
    done

    run fire_modify_hook NAME=user2 "$hook" "$APP"
    [ "$status" -eq 2 ]
    [ "$output" = "User user2 does not have permissions to modify this repository" ]
  done
}

@test "(pre-build, pre-delete, pre-receive-app) allow command line usage by default" {
  for hook in $MODIFY_HOOKS; do
    run fire_modify_hook "$hook" "$APP"
    [ "$status" -eq 0 ]
    run fire_modify_hook SSH_NAME=default "$hook" "$APP"
    [ "$status" -eq 0 ]
  done

  set_acl_property super-user admin
  for hook in $MODIFY_HOOKS; do
    run fire_modify_hook "$hook" "$APP"
    [ "$status" -eq 0 ]
  done

  dokku acl:add "$APP" user1
  for hook in $MODIFY_HOOKS; do
    run fire_modify_hook "$hook" "$APP"
    [ "$status" -eq 0 ]
  done
}

@test "(pre-build, pre-delete, pre-receive-app) allow command line usage when allow-command-line is true" {
  set_acl_property allow-command-line true
  for hook in $MODIFY_HOOKS; do
    run fire_modify_hook "$hook" "$APP"
    [ "$status" -eq 0 ]
  done

  set_acl_property super-user admin
  for hook in $MODIFY_HOOKS; do
    run fire_modify_hook "$hook" "$APP"
    [ "$status" -eq 0 ]
  done

  dokku acl:add "$APP" user1
  for hook in $MODIFY_HOOKS; do
    run fire_modify_hook "$hook" "$APP"
    [ "$status" -eq 0 ]
  done
}

@test "(pre-build, pre-delete, pre-receive-app) refuse command line usage with a super user when allow-command-line is false" {
  set_acl_property allow-command-line false

  # no acl, no super user: allowed
  for hook in $MODIFY_HOOKS; do
    run fire_modify_hook "$hook" "$APP"
    [ "$status" -eq 0 ]
  done

  # acl, no super user: allowed
  acl_cli acl:add "$APP" user1
  for hook in $MODIFY_HOOKS; do
    run fire_modify_hook "$hook" "$APP"
    [ "$status" -eq 0 ]
  done

  # acl, super user set: refused
  set_acl_property super-user admin
  for hook in $MODIFY_HOOKS; do
    run fire_modify_hook "$hook" "$APP"
    [ "$status" -ne 0 ]
    [[ "$output" == *"$COMMAND_LINE_ERROR"* ]]
  done

  # no acl, super user set: refused
  acl_cli acl:remove "$APP" user1
  for hook in $MODIFY_HOOKS; do
    run fire_modify_hook "$hook" "$APP"
    [ "$status" -ne 0 ]
    [[ "$output" == *"$COMMAND_LINE_ERROR"* ]]
  done
}

@test "(pre-delete) apps:destroy works from the command line when a super user is set" {
  set_acl_property super-user admin
  run dokku --force apps:destroy "$APP"
  [ "$status" -eq 0 ]
  run dokku apps:exists "$APP"
  [ "$status" -ne 0 ]
}

@test "(pre-delete) apps:destroy is refused from the command line when allow-command-line is false" {
  set_acl_property super-user admin
  set_acl_property allow-command-line false
  run acl_cli --force apps:destroy "$APP"
  [ "$status" -ne 0 ]
  [[ "$output" == *"$COMMAND_LINE_ERROR"* ]]
  acl_cli apps:exists "$APP"
}
