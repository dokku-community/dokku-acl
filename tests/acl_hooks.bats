#!/usr/bin/env bats

load 'test_helper'

command_line_error() {
  echo "It appears that you're running this command from the command line, which is disabled because DOKKU_ACL_ALLOW_COMMAND_LINE is set to \"$1\".  Unset it to enable command line usage."
}

setup() {
  APP="$(new_app_name)"
  create_app "$APP"
}

teardown() {
  clear_acl_config
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
  for hook in $MODIFY_HOOKS; do
    run fire_modify_hook NAME=user1 DOKKU_SUPER_USER=admin "$hook" "$APP"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Only admin can modify a repository if the ACL is empty"* ]]

    run fire_modify_hook NAME=admin DOKKU_SUPER_USER=admin "$hook" "$APP"
    [ "$status" -eq 0 ]
  done
}

@test "(pre-build, pre-delete, pre-receive-app) allow users in the acl plus the super user" {
  dokku acl:add "$APP" user1
  for hook in $MODIFY_HOOKS; do
    run fire_modify_hook NAME=user1 DOKKU_SUPER_USER=admin "$hook" "$APP"
    [ "$status" -eq 0 ]

    run fire_modify_hook NAME=user2 DOKKU_SUPER_USER=admin "$hook" "$APP"
    [ "$status" -eq 2 ]
    [ "$output" = "User user2 does not have permissions to modify this repository" ]

    run fire_modify_hook NAME=admin DOKKU_SUPER_USER=admin "$hook" "$APP"
    [ "$status" -eq 0 ]
  done
}

@test "(pre-build, pre-delete, pre-receive-app) allow command line usage by default" {
  for hook in $MODIFY_HOOKS; do
    run fire_modify_hook "$hook" "$APP"
    [ "$status" -eq 0 ]
    run fire_modify_hook SSH_NAME=default "$hook" "$APP"
    [ "$status" -eq 0 ]
    run fire_modify_hook DOKKU_SUPER_USER=admin "$hook" "$APP"
    [ "$status" -eq 0 ]
  done

  dokku acl:add "$APP" user1
  for hook in $MODIFY_HOOKS; do
    run fire_modify_hook "$hook" "$APP"
    [ "$status" -eq 0 ]
    run fire_modify_hook DOKKU_SUPER_USER=admin "$hook" "$APP"
    [ "$status" -eq 0 ]
  done
}

@test "(pre-build, pre-delete, pre-receive-app) allow command line usage when DOKKU_ACL_ALLOW_COMMAND_LINE is truthy" {
  for value in 1 true yes; do
    for hook in $MODIFY_HOOKS; do
      run fire_modify_hook DOKKU_ACL_ALLOW_COMMAND_LINE="$value" "$hook" "$APP"
      [ "$status" -eq 0 ]

      run fire_modify_hook DOKKU_ACL_ALLOW_COMMAND_LINE="$value" DOKKU_SUPER_USER=admin "$hook" "$APP"
      [ "$status" -eq 0 ]
    done
  done

  dokku acl:add "$APP" user1
  for value in 1 true yes; do
    for hook in $MODIFY_HOOKS; do
      run fire_modify_hook DOKKU_ACL_ALLOW_COMMAND_LINE="$value" "$hook" "$APP"
      [ "$status" -eq 0 ]

      run fire_modify_hook DOKKU_ACL_ALLOW_COMMAND_LINE="$value" DOKKU_SUPER_USER=admin "$hook" "$APP"
      [ "$status" -eq 0 ]
    done
  done
}

@test "(pre-build, pre-delete, pre-receive-app) refuse command line usage with a super user when DOKKU_ACL_ALLOW_COMMAND_LINE is falsy" {
  for value in 0 false FALSE no off; do
    for hook in $MODIFY_HOOKS; do
      # no acl, no super user: allowed
      run fire_modify_hook DOKKU_ACL_ALLOW_COMMAND_LINE="$value" "$hook" "$APP"
      [ "$status" -eq 0 ]

      # no acl, super user set: refused
      run fire_modify_hook DOKKU_ACL_ALLOW_COMMAND_LINE="$value" DOKKU_SUPER_USER=admin "$hook" "$APP"
      [ "$status" -ne 0 ]
      [[ "$output" == *"$(command_line_error "$value")"* ]]
    done
  done

  dokku acl:add "$APP" user1
  for value in 0 false FALSE no off; do
    for hook in $MODIFY_HOOKS; do
      # acl, no super user: allowed
      run fire_modify_hook DOKKU_ACL_ALLOW_COMMAND_LINE="$value" "$hook" "$APP"
      [ "$status" -eq 0 ]

      # acl, super user set: refused
      run fire_modify_hook DOKKU_ACL_ALLOW_COMMAND_LINE="$value" DOKKU_SUPER_USER=admin "$hook" "$APP"
      [ "$status" -ne 0 ]
      [[ "$output" == *"$(command_line_error "$value")"* ]]
    done
  done
}

@test "(pre-delete) apps:destroy works from the command line when a super user is set" {
  set_acl_config "export DOKKU_SUPER_USER=admin"
  run dokku --force apps:destroy "$APP"
  [ "$status" -eq 0 ]
  run dokku apps:exists "$APP"
  [ "$status" -ne 0 ]
}

@test "(pre-delete) apps:destroy is refused from the command line when DOKKU_ACL_ALLOW_COMMAND_LINE is disabled" {
  set_acl_config "export DOKKU_SUPER_USER=admin" "export DOKKU_ACL_ALLOW_COMMAND_LINE=0"
  run dokku --force apps:destroy "$APP"
  [ "$status" -ne 0 ]
  [[ "$output" == *"$(command_line_error 0)"* ]]
  dokku apps:exists "$APP"
}
