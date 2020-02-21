# dokku-acl [![Build Status](https://img.shields.io/travis/dokku-community/dokku-acl.svg?branch=master "Build Status")](https://travis-ci.org/dokku-community/dokku-acl)

*Access Control List management for Dokku.*

This plugin adds the ability to restrict dokku commands and push privileges
for apps to certain users, with the goal of allowing secure multi-tenant dokku
hosting. (See below for notes and limitations.)

## requirements

- dokku 0.4.0+
- docker 1.8.x

- An older version of this plugin works with dokku 0.3.x; the last version
  known to work is tagged as `for-dokku-0.3.x`.

## installation

```shell
dokku plugin:install https://github.com/dokku-community/dokku-acl.git acl
```

## running tests locally

clone and build `dokku`:
```shell
git clone https://github.com/dokku/dokku.git
cd dokku; make go-build
```

Run tests:
```shell
DOKKU_ROOT="../path-to-dokku-dir" DOKKU_SYSTEM_USER=$USER make test
```

## commands

```shell
acl:add <app> <user>      Allow <user> to access <app>
acl:list <app>            Show list of users with access to <app>
acl:remove <app> <user>   Revoke <user>'s access to <app>

acl:add-service <type> <service> <user>      Allow <user> to access <service> of type <type>
acl:list-service <type> <service>            Show list of users with access to <service> of type <type>
acl:remove-service <type> <service> <user>   Revoke <user>'s access to <service> of type <type>
```

## usage

There are no restrictions to pushing at first. After you create an
app, use `dokku acl:add your-app your-user` to restrict access to that
user. After an allowed user list is created for app, no other users
will be able to push.

To remove the restrictions, remove all users from the ACL.

You cannot modify the ACL list by ssh (`ssh target-host dokku acl:add …`); you have to do it using a local command.

### defining users

Every user has their entry in `~dokku/.ssh/authorized_keys`. Use
`$NAME` environment variable to define the username. If you add the user
using `dokku ssh-keys:add`, this will be done automatically for you.

### configuring command line usage

By default, certain dokku commands (e.g. `app:destroy`) won't work when run
from the command line on the server, if `DOKKU_SUPER_USER` is set, even when
run as `root` or `dokku`. To avoid confusion, we recommend allowing command
line access by defining `DOKKU_ACL_ALLOW_COMMAND_LINE` in
`~dokku/.dokkurc/acl`:

```shell
export DOKKU_ACL_ALLOW_COMMAND_LINE=1
```

(The default behaviour exists to prevent security issues for users who were
depending on the legacy behaviour. We recommend that all users set the
variable above.)

### default behavior

By default every user can push to repositories and even create new ones. You can change that by creating an admin
user by defining `$DOKKU_SUPER_USER` env in `~dokku/.dokkurc/acl`:

```shell
export DOKKU_SUPER_USER=puck
```

If defined, this user is always allowed to push, and no other users are allowed to push to apps with empty ACLs.

### command restrictions

By default, all users can run all dokku commands. To restrict the commands
available to non-admin users, whitelist the desired commands in
`~dokku/.dokkurc/acl`. The following lists of commands can be defined:
* Commands in `$DOKKU_ACL_USER_COMMANDS` can be run by any user at any time
* Commands in `$DOKKU_ACL_PER_APP_COMMANDS` can be run on an app by any user
with permission to manage that app.
* Commands in `$DOKKU_ACL_PER_SERVICE_COMMANDS` can be run on any service by
any user with permission to manage that service.
* Commands in `$DOKKU_ACL_LINK_COMMANDS` can be run by any user with permission
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

3. Set a `DOKKU_SUPER_USER`. This prevents pushing to apps with no ACL. To do
this, add a line like the following to `~dokku/.dokkurc/acl`:

```shell
export DOKKU_SUPER_USER=super_user_name
```

4. Restrict user commands to the minimum set needed by your users, and be sure
the commands you allow meet your security requirements. The authors of this
plugin currently recommend allowing `help` and `version`. To do this, add
the following line to `~dokku/.dokkurc/acl`:

```shell
export DOKKU_ACL_USER_COMMANDS="help version"
```

5. Similarly, restrict per-app commands. The authors of this plugin
currently recommend allowing `logs`, `urls`, `ps:rebuild`,
`ps:restart`, `ps:stop`, `ps:start`, `git-upload-pack`, `git-upload-archive`,
`git-receive-pack`, `git-hook`.
To do this, add the following line to `~dokku/.dokkurc/acl`:

```shell
export DOKKU_ACL_PER_APP_COMMANDS="logs urls ps:rebuild ps:restart ps:stop ps:start git-upload-pack git-upload-archive"
```

This will also prevent users from reading from app repos when they aren't in
the ACL, which is desireable for security. While apps _should_ be configured
using the environment, app developers often include secrets in their repos,
especially with closed source projects.
