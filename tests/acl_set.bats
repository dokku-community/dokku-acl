#!/usr/bin/env bats

load 'test_helper'

GLOBAL_KEYS="super-user allow-command-line user-commands per-app-commands per-service-commands link-commands"

setup() {
  APP="$(new_app_name)"
  create_app "$APP"
  clear_acl_properties
}

teardown() {
  clear_acl_properties
  clear_acl_config
  cleanup_app "$APP"
}

global_property() {
  acl_cli acl:report "$APP" "--acl-global-$1"
}

@test "(acl:set) sets each global property" {
  run set_acl_property super-user admin
  [ "$status" -eq 0 ]
  run set_acl_property allow-command-line false
  [ "$status" -eq 0 ]
  run set_acl_property user-commands help version
  [ "$status" -eq 0 ]
  run set_acl_property per-app-commands logs urls
  [ "$status" -eq 0 ]
  run set_acl_property per-service-commands redis:info
  [ "$status" -eq 0 ]
  run set_acl_property link-commands redis:link redis:unlink
  [ "$status" -eq 0 ]

  run global_property super-user
  [ "$output" = "admin" ]
  run global_property allow-command-line
  [ "$output" = "false" ]
  run global_property user-commands
  [ "$output" = "help version" ]
  run global_property per-app-commands
  [ "$output" = "logs urls" ]
  run global_property per-service-commands
  [ "$output" = "redis:info" ]
  run global_property link-commands
  [ "$output" = "redis:link redis:unlink" ]
}

@test "(acl:set) stores quoted and unquoted lists the same way" {
  set_acl_property user-commands help version
  run global_property user-commands
  [ "$output" = "help version" ]

  set_acl_property user-commands "help  version"
  run global_property user-commands
  [ "$output" = "help version" ]

  set_acl_property super-user " admin  admin2 "
  run global_property super-user
  [ "$output" = "admin admin2" ]
}

@test "(acl:set) accepts -g in place of --global" {
  run acl_cli acl:set -g super-user admin
  [ "$status" -eq 0 ]
  run global_property super-user
  [ "$output" = "admin" ]
}

@test "(acl:set) an empty value unsets the property" {
  for key in $GLOBAL_KEYS; do
    if [[ "$key" == "allow-command-line" ]]; then
      set_acl_property "$key" false
    else
      set_acl_property "$key" value
    fi

    run set_acl_property "$key"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Unsetting $key"* ]]
  done

  run global_property super-user
  [ -z "$output" ]
  run global_property user-commands
  [ -z "$output" ]
  run global_property allow-command-line
  [ "$output" = "true" ]
}

@test "(acl:set) requires --global" {
  run acl_cli acl:set
  [ "$status" -ne 0 ]
  [[ "$output" == *"please specify --global"* ]]

  run acl_cli acl:set super-user admin
  [ "$status" -ne 0 ]
  [[ "$output" == *"please specify --global"* ]]

  run acl_cli acl:set "$APP" super-user admin
  [ "$status" -ne 0 ]
  [[ "$output" == *"please specify --global"* ]]
}

@test "(acl:set) fails without a key or with an invalid key" {
  run acl_cli acl:set --global
  [ "$status" -ne 0 ]
  [[ "$output" == *"No key specified"* ]]

  for key in invalid-key dokkurc-migrated; do
    run acl_cli acl:set --global "$key" value
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid key specified, valid keys include: $GLOBAL_KEYS"* ]]
  done
}

@test "(acl:set) allow-command-line only accepts true or false" {
  for value in 0 1 yes no off TRUE "true false"; do
    run acl_cli acl:set --global allow-command-line $value
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid value for allow-command-line, valid values are: true, false"* ]]
  done

  run global_property allow-command-line
  [ "$output" = "true" ]
}

@test "(acl:set) super-user rejects invalid user names" {
  for user in . .. ../admin user/other; do
    run acl_cli acl:set --global super-user admin "$user"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid user name: $user"* ]]
  done

  run global_property super-user
  [ -z "$output" ]
}

@test "(acl:set) refuses to run over ssh" {
  run fire_trigger NAME=user1 subcommands/set --global super-user user1
  [ "$status" -ne 0 ]
  [[ "$output" == *"$ACL_SSH_MODIFY_ERROR"* ]]

  run global_property super-user
  [ -z "$output" ]
}

@test "(acl:set) the super user is enforced by the hooks" {
  set_acl_property super-user admin
  set_acl_property user-commands help

  run fire_trigger NAME=user1 pre-build herokuish "$APP"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Only admin can modify a repository if the ACL is empty"* ]]

  run fire_trigger NAME=admin pre-build herokuish "$APP"
  [ "$status" -eq 0 ]

  run fire_trigger NAME=user1 user-auth dokku user1 apps:list
  [ "$status" -ne 0 ]
  [[ "$output" == *"User user1 does not have permissions to run apps:list"* ]]

  run fire_trigger NAME=admin user-auth dokku admin apps:list
  [ "$status" -eq 0 ]
}

@test "(acl:set) the hooks fail closed when the properties cannot be read" {
  # a file where the property directory should be makes the store unreadable
  $SUDO mkdir -p "$(dirname "$(acl_properties_dir)")"
  $SUDO touch "$(acl_properties_dir)"

  run fire_trigger NAME=user1 user-auth dokku user1 apps:list
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unable to read the global acl properties"* ]]

  run fire_trigger NAME=user1 pre-build herokuish "$APP"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unable to read the global acl properties"* ]]
}

@test "(acl:set) the dokkurc variables have no effect on the hooks" {
  local env_overrides=(
    DOKKU_SUPER_USER=admin
    DOKKU_ACL_ALLOW_COMMAND_LINE=0
    DOKKU_ACL_USER_COMMANDS=help
    DOKKU_ACL_PER_APP_COMMANDS=logs
    DOKKU_ACL_PER_SERVICE_COMMANDS=redis:info
    DOKKU_ACL_LINK_COMMANDS=redis:link
  )

  run fire_trigger "${env_overrides[@]}" NAME=user1 pre-build herokuish "$APP"
  [ "$status" -eq 0 ]

  run fire_trigger "${env_overrides[@]}" pre-build herokuish "$APP"
  [ "$status" -eq 0 ]

  run fire_trigger "${env_overrides[@]}" NAME=user1 user-auth dokku user1 apps:list
  [ "$status" -eq 0 ]

  run global_property super-user
  [ -z "$output" ]
}

@test "(install, update) migrate the dokkurc variables into properties" {
  local env_overrides=(
    DOKKU_SUPER_USER="puck ariel"
    DOKKU_ACL_ALLOW_COMMAND_LINE=0
    DOKKU_ACL_USER_COMMANDS="help version"
    DOKKU_ACL_PER_APP_COMMANDS="logs urls"
    DOKKU_ACL_PER_SERVICE_COMMANDS=redis:info
    DOKKU_ACL_LINK_COMMANDS="redis:link redis:unlink"
  )

  for trigger in install update; do
    clear_acl_properties
    run fire_trigger "${env_overrides[@]}" "$trigger"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Migrated DOKKU_SUPER_USER to the acl super-user property"* ]]
    [[ "$output" == *"no longer read"* ]]

    run global_property super-user
    [ "$output" = "puck ariel" ]
    run global_property allow-command-line
    [ "$output" = "false" ]
    run global_property user-commands
    [ "$output" = "help version" ]
    run global_property per-app-commands
    [ "$output" = "logs urls" ]
    run global_property per-service-commands
    [ "$output" = "redis:info" ]
    run global_property link-commands
    [ "$output" = "redis:link redis:unlink" ]
    $SUDO test -f "$(acl_properties_dir)/dokkurc-migrated"
  done
}

@test "(install) migrates a truthy DOKKU_ACL_ALLOW_COMMAND_LINE as true" {
  run fire_trigger DOKKU_ACL_ALLOW_COMMAND_LINE=1 install
  [ "$status" -eq 0 ]
  run global_property allow-command-line
  [ "$output" = "true" ]
  $SUDO test -f "$(acl_properties_dir)/allow-command-line"
}

@test "(install) does not overwrite existing properties" {
  set_acl_property super-user admin

  run fire_trigger DOKKU_SUPER_USER=puck DOKKU_ACL_USER_COMMANDS=help install
  [ "$status" -eq 0 ]
  [[ "$output" != *"Migrated DOKKU_SUPER_USER"* ]]
  [[ "$output" == *"Migrated DOKKU_ACL_USER_COMMANDS to the acl user-commands property"* ]]

  run global_property super-user
  [ "$output" = "admin" ]
  run global_property user-commands
  [ "$output" = "help" ]
}

@test "(install) only migrates once" {
  run fire_trigger DOKKU_SUPER_USER=puck install
  [ "$status" -eq 0 ]
  set_acl_property super-user

  run fire_trigger DOKKU_SUPER_USER=puck install
  [ "$status" -eq 0 ]
  [[ "$output" != *"Migrated"* ]]

  run global_property super-user
  [ -z "$output" ]
}

@test "(install) does nothing without dokkurc variables" {
  run fire_trigger install
  [ "$status" -eq 0 ]
  [[ "$output" != *"Migrated"* ]]
  [[ "$output" != *"no longer read"* ]]
  $SUDO test -f "$(acl_properties_dir)/dokkurc-migrated"
}

@test "(install) migrates the dokkurc sourced by the dokku cli" {
  set_acl_config "export DOKKU_SUPER_USER=admin" 'export DOKKU_ACL_USER_COMMANDS="help version"'

  run acl_cli plugin:install
  [ "$status" -eq 0 ]

  run global_property super-user
  [ "$output" = "admin" ]
  run global_property user-commands
  [ "$output" = "help version" ]
}
