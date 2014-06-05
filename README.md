ACL plugin for dokku
--------------------

Dokku: https://github.com/progrium/dokku

Installation
------------
```
git clone https://github.com/mlebkowski/dokku-acl /var/lib/dokku/plugins/acl
```

Commands
--------
```
$ dokku help
    acl:add <app> <user>      Allow user to push to this repository
    acl:info                  Show information on configuring this plugin
    acl:list <app>            Show list of users with access to repository
    acl:remove <app> <user>   Revoke users access to the repository
```

Usage
-----

There are no restrictions to pushing at first. After you create an app, use `dokku acl:add your-app your-user` to
restrict access for certain user. After an allowed user list is created for app, no other user will be able to push.

To remove the restrictions, remove all users from the ALC list. You can check it using `dokku acl:info`

You cannot modify the ACL list by ssh (`ssh target-host dokku acl:add …`), you have to do it using local command.

Defining users
--------------

Every user has their entry in `~dokku/.ssh/authorized_keys`. Use `$NAME` environment variable to define the username.
