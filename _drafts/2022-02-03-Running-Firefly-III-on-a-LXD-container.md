---
layout: post
title:  "Running Firefly III on a LXD container"
date:  2022-02-03 23:29:19 UTC00 
categories: cat1 cat2 cat3  
---

# Running Firefly III on a LXD container 

I always controlled my finance using google docs. Now it's time to use something fancier. So here I am going to document the process of installing Firefly III on a LXD container.

## Variables

I always like to use variables to make it easier to tweak things if I run the commands here on another context.

Also, it's nice to highlight that all the commands here are ran **on the LXD host**, not in the container per se.

```
export CONTAINER=tycho
export IMAGE=ubuntu:20.04
export CONTAINERIP=192.168.0.17
```

## First steps

Create your container:

```
sudo lxc launch $IMAGE $CONTAINER
```

Update the packages:

```
sudo lxc exec $CONTAINER -- apt update
sudo lxc exec $CONTAINER -- apt upgrade -y
```

## Sources

[Setup Firefly III Personal Finance Manager on Ubuntu 20.04 | 18.04](https://computingforgeeks.com/setup-firefly-personal-finance-manager-on-ubuntu/)
