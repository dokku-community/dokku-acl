#!/usr/bin/env bats

load 'test_helper'

@test "(acl) dokku acl prints the same help as acl:help" {
  run dokku acl:help
  [ "$status" -eq 0 ]
  local help_output="$output"
  [[ "$help_output" == *"usage"*"dokku acl[:COMMAND]"* ]]

  run dokku acl
  [ "$status" -eq 0 ]
  [ "$output" = "$help_output" ]
}

@test "(acl:help) lists every subcommand" {
  run dokku acl:help
  [ "$status" -eq 0 ]
  for subcommand in add add-service allowed allowed-services list list-service remove remove-service report set set-service-users set-users; do
    [[ "$output" == *"acl:${subcommand} "* ]]
  done
}

@test "(acl:help) shows the usage, arguments and example for a subcommand" {
  run dokku acl:help add
  [ "$status" -eq 0 ]
  [[ "$output" == *"dokku acl:add <app> <user>"* ]]
  [[ "$output" == *"allow <user> to push to <app>'s repository"* ]]
  [[ "$output" == *"a user to allow access"* ]]
  [[ "$output" == *"dokku acl:add lolipop admin"* ]]
}

@test "(acl:help) shows the corrected examples for the allowed subcommands" {
  run dokku acl:help allowed
  [ "$status" -eq 0 ]
  [[ "$output" == *"dokku acl:allowed admin"* ]]

  run dokku acl:help allowed-services
  [ "$status" -eq 0 ]
  [[ "$output" == *"dokku acl:allowed-services redis admin"* ]]
}

@test "(help) dokku help describes the acl plugin" {
  run dokku help
  [ "$status" -eq 0 ]
  [[ "$output" == *"acl"*"Manage access control lists for apps and services"* ]]
}

@test "(acl:help) shows the usage for the set-users subcommands" {
  run dokku acl:help set-users
  [ "$status" -eq 0 ]
  [[ "$output" == *"dokku acl:set-users <app> <user...>"* ]]
  [[ "$output" == *"dokku acl:set-users lolipop admin deploy"* ]]

  run dokku acl:help set-service-users
  [ "$status" -eq 0 ]
  [[ "$output" == *"dokku acl:set-service-users <service-type> <service> <user...>"* ]]
  [[ "$output" == *"dokku acl:set-service-users redis birds servuser admin"* ]]
}

@test "(acl:help) shows the usage for the set subcommand" {
  run dokku acl:help set
  [ "$status" -eq 0 ]
  [[ "$output" == *"dokku acl:set "*"--global"*"<key> <value...>"* ]]
  [[ "$output" == *"set or clear a global acl property"* ]]
  [[ "$output" == *"the property to set: super-user allow-command-line user-commands"* ]]
  [[ "$output" == *"leave empty to unset the key"* ]]
  [[ "$output" == *"dokku acl:set --global super-user admin"* ]]
  [[ "$output" == *"dokku acl:set --global user-commands help version"* ]]
}
