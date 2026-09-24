#!/usr/bin/env bats

load 'test_helper'

# A subset of easy to check commands
ALLOWED_CMDS="apps:list certs:report help"
RESTRICTED_CMDS="domains:report events ls ps:report"
ALL_CMDS="$ALLOWED_CMDS $RESTRICTED_CMDS"

# These commands take an app and/or service name as an argument
PER_APP_CMDS="config logs urls"
PER_SERVICE_CMDS="redis:info redis:stop"
LINK_CMDS="redis:link redis:unlink"

setup() {
  APP="$(new_app_name)"
  create_app "$APP"
  TYPE=""
}

teardown() {
  clear_acl_properties
  cleanup_app "$APP"
  cleanup_service_type "$TYPE"
}

# user-auth receives the ssh user, the ssh key name and the dokku command line.
# Over ssh, dokku exports the key name as NAME, so it is set here to simulate an
# ssh user.
user_auth() {
  fire_trigger NAME="$3" "$@"
}

# Command line usage (cron jobs, systemd services, a shell on the server) does
# not set NAME, and dokku core authenticates it as the "default" user.
command_line_user_auth() {
  fire_trigger "$@"
}

# Run the dokku CLI as the dokku user, the way cron jobs and systemd services
# do. Leading VAR=VALUE arguments are set in the CLI's environment.
dokku_as_dokku_user() {
  sudo -u dokku "$@"
}

# Restrict every kind of command and set a super user.
set_all_restrictions() {
  set_acl_property user-commands "$ALLOWED_CMDS"
  set_acl_property per-app-commands "$PER_APP_CMDS"
  set_acl_property per-service-commands "$PER_SERVICE_CMDS"
  set_acl_property link-commands "$LINK_CMDS"
  set_acl_property super-user "$@"
}

# The per-service and link commands derive the service type from the command
# prefix, so these tests use a real `redis` type directory. It is removed in
# teardown and only created by tests that need it.
create_redis_service() {
  TYPE="redis"
  create_service redis "$1"
}

@test "(user-auth) allows all commands by default" {
  for cmd in $ALL_CMDS; do
    run user_auth user-auth dokku user1 "$cmd"
    [ "$status" -eq 0 ]
  done

  for cmd in $PER_APP_CMDS; do
    run user_auth user-auth dokku user1 "$cmd" "$APP"
    [ "$status" -eq 0 ]
  done
}

@test "(user-auth) allows only listed user commands" {
  set_acl_property user-commands "$ALLOWED_CMDS"
  for cmd in $ALLOWED_CMDS; do
    run user_auth user-auth dokku user1 "$cmd"
    [ "$status" -eq 0 ]
  done

  for cmd in $RESTRICTED_CMDS; do
    run user_auth user-auth dokku user1 "$cmd"
    [ "$status" -ne 0 ]
    [[ "$output" == *"User user1 does not have permissions to run $cmd"* ]]
  done
}

@test "(user-auth) allows per-app commands only for users in the app acl" {
  set_acl_property per-app-commands "$PER_APP_CMDS"
  dokku acl:add "$APP" user1

  for cmd in $PER_APP_CMDS; do
    run user_auth user-auth dokku user1 "$cmd" "$APP"
    [ "$status" -eq 0 ]

    run user_auth user-auth dokku user2 "$cmd" "$APP"
    [ "$status" -ne 0 ]
    [[ "$output" == *"User user2 does not have permissions to run $cmd on $APP, or $APP does not exist"* ]]
  done
}

@test "(user-auth) per-app commands accept the quoted app names git sends" {
  set_acl_property per-app-commands git-receive-pack
  dokku acl:add "$APP" user1

  for app_arg in "'$APP'" "/$APP" "'/$APP'"; do
    run user_auth user-auth dokku user1 git-receive-pack "$app_arg"
    [ "$status" -eq 0 ]

    run user_auth user-auth dokku user2 git-receive-pack "$app_arg"
    [ "$status" -ne 0 ]
    [[ "$output" == *"User user2 does not have permissions to run git-receive-pack on $APP"* ]]
  done
}

@test "(user-auth) per-app commands do not reveal if an app exists or not" {
  set_acl_property per-app-commands "$PER_APP_CMDS"
  for cmd in $PER_APP_CMDS; do
    run user_auth user-auth dokku user2 "$cmd" acltest-missing-app
    [ "$status" -ne 0 ]
    [[ "$output" == *"User user2 does not have permissions to run $cmd on acltest-missing-app, or acltest-missing-app does not exist"* ]]
  done
}

@test "(user-auth) per-app commands fail without an app" {
  set_acl_property per-app-commands "$PER_APP_CMDS"
  for cmd in $PER_APP_CMDS; do
    run user_auth user-auth dokku user2 "$cmd"
    [ "$status" -ne 0 ]
    [[ "$output" == *"An app name is required"* ]]
  done
}

@test "(user-auth) allows per-service commands only for users in the service acl" {
  set_acl_property per-service-commands "$PER_SERVICE_CMDS"
  create_redis_service acltest-service
  dokku acl:add-service redis acltest-service user1

  for cmd in $PER_SERVICE_CMDS; do
    run user_auth user-auth dokku user1 "$cmd" acltest-service
    [ "$status" -eq 0 ]

    run user_auth user-auth dokku user2 "$cmd" acltest-service
    [ "$status" -ne 0 ]
    [[ "$output" == *"User user2 does not have permissions to run $cmd on acltest-service, or acltest-service does not exist"* ]]
  done
}

@test "(user-auth) per-service commands do not reveal if a service exists or not" {
  set_acl_property per-service-commands "$PER_SERVICE_CMDS"
  for cmd in $PER_SERVICE_CMDS; do
    run user_auth user-auth dokku user1 "$cmd" acltest-missing-service
    [ "$status" -ne 0 ]
    [[ "$output" == *"User user1 does not have permissions to run $cmd on acltest-missing-service, or acltest-missing-service does not exist"* ]]
  done
}

@test "(user-auth) per-service commands fail without a service" {
  set_acl_property per-service-commands "$PER_SERVICE_CMDS"
  for cmd in $PER_SERVICE_CMDS; do
    run user_auth user-auth dokku user1 "$cmd"
    [ "$status" -ne 0 ]
    [[ "$output" == *"A service name is required"* ]]
  done
}

@test "(user-auth) allows link commands only for users in both the service and app acls" {
  set_acl_property link-commands "$LINK_CMDS"
  create_redis_service acltest-service
  dokku acl:add "$APP" user1
  dokku acl:add "$APP" user2
  dokku acl:add-service redis acltest-service user1
  dokku acl:add-service redis acltest-service user3

  for cmd in $LINK_CMDS; do
    run user_auth user-auth dokku user1 "$cmd" acltest-service "$APP"
    [ "$status" -eq 0 ]
  done

  for user in user2 user3 user4; do
    for cmd in $LINK_CMDS; do
      run user_auth user-auth dokku "$user" "$cmd" acltest-service "$APP"
      [ "$status" -ne 0 ]
      if [[ "$user" == user3 ]]; then
        [[ "$output" == *"User $user does not have permissions to run $cmd on $APP, or $APP does not exist"* ]]
      else
        [[ "$output" == *"User $user does not have permissions to run $cmd on acltest-service, or acltest-service does not exist"* ]]
      fi
    done
  done
}

@test "(user-auth) link commands fail without a service or app" {
  set_acl_property link-commands "$LINK_CMDS"
  for cmd in $LINK_CMDS; do
    run user_auth user-auth dokku user1 "$cmd"
    [ "$status" -ne 0 ]
    [[ "$output" == *"A service name is required"* ]]

    run user_auth user-auth dokku user1 "$cmd" acltest-service
    [ "$status" -ne 0 ]
    [[ "$output" == *"An app name is required"* ]]
  done
}

@test "(user-auth) the super user and root can run any command" {
  set_all_restrictions admin

  for cmd in $ALL_CMDS; do
    run user_auth user-auth dokku admin "$cmd"
    [ "$status" -eq 0 ]
    run user_auth user-auth root root "$cmd"
    [ "$status" -eq 0 ]
  done

  for cmd in $PER_APP_CMDS $PER_SERVICE_CMDS; do
    run user_auth user-auth dokku admin "$cmd" acltest-thing
    [ "$status" -eq 0 ]
    run user_auth user-auth root root "$cmd" acltest-thing
    [ "$status" -eq 0 ]
  done

  for cmd in $LINK_CMDS; do
    run user_auth user-auth dokku admin "$cmd" acltest-service "$APP"
    [ "$status" -eq 0 ]
    run user_auth user-auth root root "$cmd" acltest-service "$APP"
    [ "$status" -eq 0 ]
  done
}

@test "(user-auth) command line usage can run any command by default" {
  set_all_restrictions admin

  for value in "" true; do
    set_acl_property allow-command-line $value
    for cmd in $ALL_CMDS; do
      run command_line_user_auth user-auth dokku default "$cmd"
      [ "$status" -eq 0 ]
    done

    for cmd in $PER_APP_CMDS $PER_SERVICE_CMDS; do
      run command_line_user_auth user-auth dokku default "$cmd" acltest-thing
      [ "$status" -eq 0 ]
    done

    for cmd in $LINK_CMDS; do
      run command_line_user_auth user-auth dokku default "$cmd" acltest-service "$APP"
      [ "$status" -eq 0 ]
    done
  done
}

@test "(user-auth) command line usage is checked as the default user when allow-command-line is false" {
  set_acl_property user-commands "$ALLOWED_CMDS"
  set_acl_property allow-command-line false

  for cmd in $RESTRICTED_CMDS; do
    run command_line_user_auth user-auth dokku default "$cmd"
    [ "$status" -ne 0 ]
    [[ "$output" == *"User default does not have permissions to run $cmd"* ]]
  done

  for cmd in $ALLOWED_CMDS; do
    run command_line_user_auth user-auth dokku default "$cmd"
    [ "$status" -eq 0 ]
  done
}

@test "(user-auth) the dokku user can run restricted commands from the command line" {
  set_acl_property super-user admin
  set_acl_property user-commands help

  run dokku_as_dokku_user dokku apps:list
  [ "$status" -eq 0 ]
  [[ "$output" == *"$APP"* ]]

  run dokku_as_dokku_user NAME=user1 dokku apps:list
  [ "$status" -ne 0 ]
  [[ "$output" == *"User user1 does not have permissions to run apps:list"* ]]
}

@test "(user-auth) the dokku user cannot run restricted commands from the command line when allow-command-line is false" {
  set_acl_property super-user admin
  set_acl_property user-commands help
  set_acl_property allow-command-line false

  run dokku_as_dokku_user dokku apps:list
  [ "$status" -ne 0 ]
  [[ "$output" == *"User default does not have permissions to run apps:list"* ]]
}

@test "(user-auth) each of multiple super users can run any command" {
  set_acl_property user-commands "$ALLOWED_CMDS"
  set_acl_property per-app-commands "$PER_APP_CMDS"
  set_acl_property super-user admin admin2

  for user in admin admin2; do
    for cmd in $ALL_CMDS; do
      run user_auth user-auth dokku "$user" "$cmd"
      [ "$status" -eq 0 ]
    done

    for cmd in $PER_APP_CMDS; do
      run user_auth user-auth dokku "$user" "$cmd" "$APP"
      [ "$status" -eq 0 ]
    done
  done

  for user in user1 adm; do
    for cmd in $RESTRICTED_CMDS; do
      run user_auth user-auth dokku "$user" "$cmd"
      [ "$status" -ne 0 ]
      [[ "$output" == *"User $user does not have permissions to run $cmd"* ]]
    done
  done
}
