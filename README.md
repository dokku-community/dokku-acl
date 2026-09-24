# dokku-acl [![ci](https://github.com/dokku-community/dokku-acl/actions/workflows/ci.yml/badge.svg)](https://github.com/dokku-community/dokku-acl/actions/workflows/ci.yml)

*Access Control List management for Dokku.*

This plugin adds the ability to restrict dokku commands and push privileges
for apps to certain users, with the goal of allowing secure multi-tenant dokku
hosting. (See below for notes and limitations.)

## requirements

- dokku 0.35.0+
- docker 1.8.x

- An older version of this plugin works with dokku 0.3.x; the last version
  known to work is tagged as `for-dokku-0.3.x`.

## installation

```shell
dokku plugin:install https://github.com/dokku-community/dokku-acl.git acl
```

## commands

```shell
acl:add <app> <user>                  Allow <user> to access <app>
acl:allowed <user>                    List apps the user has access to
acl:list <app>                        Show list of users with access to <app>
acl:remove <app> <user>               Revoke <user>'s access to <app>
acl:report [<app>] [<flag>]           Displays an acl report for one or more apps
acl:set --global <key> [<value>...]   Set or clear a global acl property
acl:set-users <app> [<user>...]       Replace the list of users with access to <app>

acl:add-service <type> <service> <user>              Allow <user> to access <service> of type <type>
acl:allowed-services <type> <user>                   List services of type <type> that the user has access to
acl:list-service <type> <service>                    Show list of users with access to <service> of type <type>
acl:remove-service <type> <service> <user>           Revoke <user>'s access to <service> of type <type>
acl:set-service-users <type> <service> [<user>...]   Replace the list of users with access to <service> of type <type>
```

## usage

There are no restrictions to pushing at first. After you create an
app, use `dokku acl:add your-app your-user` to restrict access to that
user. After an allowed user list is created for app, no other users
will be able to push.

To remove the restrictions, remove all users from the ACL.

To declare the complete list of users in one call, use
`dokku acl:set-users your-app user1 user2` (or
`dokku acl:set-service-users <type> <service> user1 user2` for a
service). Any users not in the list are removed, and calling it with no
users clears the ACL. Every user name is validated before the ACL is
changed, so an invalid name leaves the existing list untouched.

You cannot modify the ACL list by ssh (`ssh target-host dokku acl:add …`); you have to do it using a local command.

### defining users

Every user has their entry in `~dokku/.ssh/authorized_keys`. Use
`$NAME` environment variable to define the username. If you add the user
using `dokku ssh-keys:add`, this will be done automatically for you.

### global settings

Settings that apply to every app and service are managed with
`dokku acl:set --global <key> <value>`. Lists are separated by spaces, and
can be passed either as separate arguments or as one quoted argument. Calling
`acl:set` without a value unsets the key. Like the other commands that modify
the ACL, `acl:set` cannot be run over ssh.

| key | default | description |
|-----|---------|-------------|
| `super-user` | none | users that can always push and can push to apps with empty ACLs |
| `allow-command-line` | `true` | whether commands run from the server's command line bypass the ACL |
| `user-commands` | none | commands any user can run |
| `per-app-commands` | none | commands a user can run on apps they have access to |
| `per-service-commands` | none | commands a user can run on services they have access to |
| `link-commands` | none | commands a user can run on a service and app they both have access to |

`dokku acl:report` shows the current value of each key.

### upgrading from dokkurc settings

Previous versions of this plugin read these settings from the
`DOKKU_SUPER_USER`, `DOKKU_ACL_ALLOW_COMMAND_LINE`, `DOKKU_ACL_USER_COMMANDS`,
`DOKKU_ACL_PER_APP_COMMANDS`, `DOKKU_ACL_PER_SERVICE_COMMANDS` and
`DOKKU_ACL_LINK_COMMANDS` variables in `~dokku/.dokkurc/acl`. When the plugin
is installed or updated, any of these variables that are set are imported once
into the matching key, unless the key is already set. After that, the
variables are no longer read, and `~dokku/.dokkurc/acl` can be removed. Use
`dokku acl:set` to make any further changes.

### configuring command line usage

By default, dokku commands work when run from the command line on the server.
This includes commands that modify an app (e.g. `apps:destroy`), and commands
run by cron jobs (e.g. letsencrypt auto-renewal or datastore backups) and
systemd services (e.g. `dokku-retire`). These commands are not subject to the
command restrictions below. If you want commands that modify an app to be
refused from the command line whenever a super user is set, even when run
as `root` or `dokku`, disable command line access:

```shell
dokku acl:set --global allow-command-line false
```

When command line access is disabled, commands run from the command line by
the `dokku` user are also subject to the command restrictions, and are checked
as the user `default`. Commands run as `root` are always allowed, so run
`sudo dokku acl:set --global allow-command-line true` to enable it again.

Previous versions of this plugin refused these commands by default when
`DOKKU_SUPER_USER` was set, unless `DOKKU_ACL_ALLOW_COMMAND_LINE` was defined.
If you depended on that behaviour, disable command line access as above when
upgrading.

### default behavior

By default every user can push to repositories and even create new ones. You
can change that by setting a super user:

```shell
dokku acl:set --global super-user puck
```

If set, this user is always allowed to push, and no other users are allowed to push to apps with empty ACLs.

To set more than one super user, pass every user:

```shell
dokku acl:set --global super-user puck ariel
```

`dokku acl:report` shows the value as it is set, e.g. `puck ariel`.

### command restrictions

By default, all users can run all dokku commands. To restrict the commands
available to non-admin users connecting over ssh, whitelist the desired
commands with `dokku acl:set --global`. The following lists of commands can be defined:
* Commands in `user-commands` can be run by any user at any time
* Commands in `per-app-commands` can be run on an app by any user
with permission to manage that app.
* Commands in `per-service-commands` can be run on any service by
any user with permission to manage that service.
* Commands in `link-commands` can be run by any user with permission
to manage both the service and the app being linked.

See the section on secure multi-tenancy for examples.

### read restrictions

By default, users can read (`git pull`, `git clone`, `git archive`)
from repositories, even when they aren't in the ACL. To prevent this,
add a per-app command restriction for `git-upload-pack` and
`git-upload-archive`.

### secure multi-tenancy

Dokku already provides good isolation functionality between apps: apps are
run in independent Docker containers, and all builds occur in Docker
containers too. This plugin aims to address the "missing link" needed for
secure multi-tenancy with Dokku: restricting access to apps and management
commands.

**Note that this plugin has not been extensively audited for security**, and
to our knowledge, neither has Dokku. Serious deficiencies may exist, and users
of this plugin are strongly advised
to perform their own security audit. If you encounter any issues or limitations
with this plugin, please log them as GitHub issues and we'll try and address
them. As usual with open source software there is **no warranty**. (Please
see LICENSE.txt for details.)

With that in mind, here are some recommendations on creating a secure
multi-tenancy setup with Dokku and this plugin:

1. Keep up to date with Dokku releases and with security updates for all
software on your servers, including Docker.

2. Restrict shell access to the server. Users should only be able to interact
with the machine via apps, and via restricted ssh. (If you manage users using
`dokku ssh-keys`, this will be done for you.)

3. Set a super user. This prevents pushing to apps with no ACL. To do
this, run:

```shell
dokku acl:set --global super-user super_user_name
```

4. Restrict user commands to the minimum set needed by your users, and be sure
the commands you allow meet your security requirements. The authors of this
plugin currently recommend allowing `help` and `version`. To do this, run:

```shell
dokku acl:set --global user-commands help version
```

5. Similarly, restrict per-app commands. The authors of this plugin
currently recommend allowing `logs`, `urls`, `ps:rebuild`,
`ps:restart`, `ps:stop`, `ps:start`, `git-upload-pack`, `git-upload-archive`,
`git-receive-pack`, `git-hook`.
To do this, run:

```shell
dokku acl:set --global per-app-commands logs urls ps:rebuild ps:restart ps:stop ps:start git-upload-pack git-upload-archive git-receive-pack git-hook
```

This will also prevent users from reading from app repos when they aren't in
the ACL, which is desireable for security. While apps _should_ be configured
using the environment, app developers often include secrets in their repos,
especially with closed source projects.
