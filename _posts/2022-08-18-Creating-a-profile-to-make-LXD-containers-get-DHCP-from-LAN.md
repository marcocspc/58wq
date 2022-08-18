---
layout: post
title:  "Creating a profile to make LXD containers get DHCP from LAN"
date:  2022-08-18 10:58:26 -0300 
categories: english linux lxd
---

# Creating a profile to make LXD containers get DHCP from LAN 

Every time I need to create a LXD container that need to be bridged with my lan network I have too google how to do it again. So I'm writing this small guide to document the way that I prefer.

## Variables

Adjust these variables to your environment. Copy and paste this on your command prompt to use them:

```
export EXTERNAL_IP_INTERFACE="eno1"
export CONTAINER_NAME="my_container"
```

## Creating a bridge:

For this to work you need to create a bridge and set your main ethernet adapter (commonly eth0, in my case it was eno1). Create the bridge:

```
sudo ip link add name br0 type bridge
sudo ip link set dev br0 up
sudo ip link set dev $EXTERNAL_IP_INTERFACE master br0
```

You can also paste these commands inside cron or a systemd script to make them run at every reboot.

## Creating the LXD Profile

Now create the profile:

```
lxc profile create bridgeprofile
```

Now set the desired configuration:

```
cat <<EOF | lxc profile edit bridgeprofile
config: {}
description: Bridged networking LXD profile
devices:
  eth0:
    name: eth0
    nictype: bridged
    parent: br0
    type: nic
name: bridgeprofile
used_by:
EOF
```

## Attaching the profile

Create the container and attach the profile to it:

```
lxc launch ubuntu:20.04 $CONTAINER_NAME
lxc profile assign $CONTAINER_NAME default,bridgeprofile
lxc restart $CONTAINER_NAME
```

Removing the profile from the container:

```
lxc stop $CONTAINER_NAME
lxc profile assign $CONTAINER_NAME default
lxc start $CONTAINER_NAME
```

Aaaand we're done!

## References

- [How to make your LXD containers get IP addresses from your LAN using a bridge](https://blog.simos.info/how-to-make-your-lxd-containers-get-ip-addresses-from-your-lan-using-a-bridge/)
- [How can I bridge two interfaces with ip/iproute2?](https://unix.stackexchange.com/questions/255484/how-can-i-bridge-two-interfaces-with-ip-iproute2)
