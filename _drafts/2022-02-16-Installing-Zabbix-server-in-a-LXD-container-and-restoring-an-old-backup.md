---
layout: post
title:  "Installing Zabbix server in a LXD container and restoring an old backup"
date:  2022-02-16 23:17:01 -0300 
categories: english linux lxd
---

# Installing Zabbix server in a LXD container and restoring an old backup 

After getting my old Banana Pro to work again, by installing Armbian's Banana Pi M1 image on it, I decided to reinstall Zabbix and restore the backup I had before my other Raspberry failed. Oh, and just one explanation I should leave here just to document it: apparently, Banana Pi M1 driver is more stable than the one made specifically for the Banana Pro image, at least until now I've been having an experience a lot stabler using the M1 image.

Anyway, let's begin. As I always tell, all the commands here should be run on the lxd host, not in the container, but proceed as you wish.

## Variables

SSH into your host and export these variables, so it is easier to paste commands and adapt this guide to your context:

```
export CONTAINER=manaus
export IMAGE=ubuntu:20.04
```

## Creating the container

Run this:

```
lxc launch $IMAGE $CONTAINER
```

Upgrade all packages:

```
lxc exec $CONTAINER -- apt update
lxc exec $CONTAINER -- apt upgrade -y
```

## Installing Zabbix
