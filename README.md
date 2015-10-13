# dokku-acl [![Build Status](https://img.shields.io/travis/mlebkowski/dokku-acl.svg?branch=master "Build Status")](https://travis-ci.org/mlebkowski/dokku-acl)

This plugin adds the ability to restrict push privileges for app to certain users.

## requirements

- dokku 0.4.0+
- docker 1.8.x

## installation

```shell
# on 0.3.x
cd /var/lib/dokku/plugins
git clone https://github.com/mlebkowski/dokku-acl.git acl
dokku plugins-install

# on 0.4.x
dokku plugin:install https://github.com/mlebkowski/dokku-acl.git acl
```

## commands

```shell
acl:add <app> <user>      Allow user to push to this repository
acl:info                  Show information on configuring this plugin
acl:list <app>            Show list of users with access to repository
acl:remove <app> <user>   Revoke users access to the repository
```

## usage

There are no restrictions to pushing at first. After you create an app, use `dokku acl:add your-app your-user` to
restrict access for certain user. After an allowed user list is created for app, no other user will be able to push.

To remove the restrictions, remove all users from the ALC list. You can check it using `dokku acl:info`

You cannot modify the ACL list by ssh (`ssh target-host dokku acl:add …`), you have to do it using local command.

### defining users

Every user has their entry in `~dokku/.ssh/authorized_keys`. Use `$NAME` environment variable to define the username.

### default behavior

By default every user can push to repositories and even create new ones. You can change that by creating an admin
user by defining `$DOKKU_SUPER_USER` env in `~dokku/.dokkurc/acl`:

```shell
export DOKKU_SUPER_USER=puck
```

If defined, this user is always allowed to push, and empty ACL is restricting access to all other users.
