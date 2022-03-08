---
layout: post
title:  "Setting up Home Assistant so I can get home assisted"
date:  2022-03-07 21:10:44 -0300 
categories: english linux lxd  
---

# Setting up Home Assistant so I can get home assisted 

And finally came the day that I bought my first IoT gadget. It is a Broadlink RM4C Mini that I'm using to power on and off my old non-smart stuff. I'm already using alexa to control it, but not only it is limited to my smartphone as I don't have full control over it. So on this post I'm going to write what I did to set it up on a LXD + Docker setup.

## Some Exports

Some variables in case I return here some day:

```
export CONTAINER='example'
export IMAGE=ubuntu:20.04
export HOST_ARCH=$(dpkg --print-architecture)
export HOME_ASSISTANT_EXTERNAL_PORT=8123
export MY_TIME_ZONE=America/Fortaleza
```

## Creating the container

Launch the container:

```
lxc launch $IMAGE $CONTAINER
```

If desired, edit the container description:

```
lxc config edit $CONTAINER
```

Upgrade all packages:

```
lxc exec $CONTAINER -- apt update
lxc exec $CONTAINER -- apt upgrade -y
```

## Installing Docker

To install docker we must enable nesting, do this by running:

```
lxc stop $CONTAINER
lxc config set $CONTAINER security.nesting true
lxc start $CONTAINER
```

Install dependencies:

```
lxc exec $CONTAINER -- apt install -y ca-certificates curl gnupg lsb-release
```

Get docker's GPG key:

```
lxc exec $CONTAINER -- bash -c "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg"
```

Set up the repository:

```
export CONTAINER_RELEASE=$(lxc exec $CONTAINER -- lsb_release -cs)
lxc exec $CONTAINER -- bash -c "echo 'deb [arch=$HOST_ARCH signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $CONTAINER_RELEASE stable' | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null"
```

Update and install docker:

```
lxc exec $CONTAINER -- bash -c "apt update && apt install docker-ce docker-ce-cli containerd.io -y"
```

## Installing home assistant

Create a folder where your configuration will be stored:

```
lxc exec $CONTAINER -- mkdir -p /docker_binds/homeassistant/config
```

Now start the Docker container:

```
lxc exec $CONTAINER -- docker run -d --name homeassistant --restart=unless-stopped -e TZ=$MY_TIME_ZONE -v /docker_binds/homeassistant/config:/config -p $HOME_ASSISTANT_EXTERNAL_PORT:8123 ghcr.io/home-assistant/home-assistant:stable
```

Expose the container port:

```
lxc config device add $CONTAINER homeassistant8123 proxy listen=tcp:0.0.0.0:$HOME_ASSISTANT_EXTERNAL_PORT connect=tcp:172.17.0.1:$HOME_ASSISTANT_EXTERNAL_PORT
```

This should do it. The rest is all about going to the web interface and set up Home Assistant graphically. You may refer to the [official guide](https://www.home-assistant.io/getting-started/onboarding/) to see what to do next.

We're done!

## References
