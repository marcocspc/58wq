---
layout: post
title:  "Another kind of remote play: Steam Headless"
date:  2023-10-24 20:47:20 -0300 
categories: english linux streaming
---

# Another kind of remote play: Steam Headless 

This time Imma be trying to run games in my headless host by using the [steam headless image](https://github.com/Steam-Headless/docker-steam-headless/tree/master), so let's do this!

## Dependencies

As I always tell in these posts, you must have a nVidia host with Docker, docker-compose and [nvidia container runtime](https://developer.nvidia.com/nvidia-container-runtime) installed.

## Variables

A few variables to be set in the terminal you're going to use to keep the file generation commands below a little more environment free, so one needs to edit only the variables at this part of this post (copy and paste all lines at once in your terminal):

```
export STEAM_HOSTNAME="steam-headless"
export SUNSHINE_USER=admin
export TIMEZONE="America/Fortaleza"
export DISPLAY_SIZE_H=2560
export DISPLAY_SIZE_V=1080
read -p "SUNSHINE_PASS: " SUNSHINE_PASS;\
read -p "DEFAULT_USER_PASSWORD: " DEFAULT_USER_PASSWORD
```

## Needed files

I liked the steam headless project because that it apparently is simpler to set up than [games-on-whales](https://github.com/games-on-whales/gow) and it is safer since it doesn't run in a privileged container.

To configure steam headless, as any docker service, we need a `docker-compose.yaml` and an environment file. Let me begin with `docker-compose.yaml`:

```
cat << EOF > docker-compose.yaml
services:
  steam-headless:
    image: josh5/steam-headless:latest
    restart: unless-stopped
    runtime: nvidia
    shm_size: 2g
    ipc: shareable
    network_mode: host
    ulimits:
      nofile:
        soft: 1024
        hard: 524288
    cap_add:
      - NET_ADMIN
      - SYS_ADMIN
      - SYS_NICE
    security_opt:
      - seccomp:unconfined
      - apparmor:unconfined
    hostname: $STEAM_HOSTNAME
    extra_hosts:
      - "$STEAM_HOSTNAME:127.0.0.1"
    env_file: steam-headless.env
    devices:
      - /dev/fuse
      - /dev/uinput
    device_cgroup_rules:
      - 'c 13:* rmw'
    volumes:
      - ./user_home:/home/default/:rw
    #ports:
    #  - 8083:8083
    #  - 47984-47990:47984-47990/tcp
    #  - 48010:48010/tcp
    #  - 47998-48000:47998-48000/udp
    #  - 48010:48010/udp
EOF
```

Now we create the environment file:

```
cat << EOF > steam-headless.env
NAME='$STEAM_HOSTNAME'
TZ='$TIMEZONE'
USER_LOCALES='pt_BR.UTF-8 UTF-8'
DISPLAY=':55'
SHM_SIZE='2G'
DOCKER_RUNTIME='nvidia'

PUID='1000'
PGID='1000'
UMASK='000'
USER_PASSWORD='$DEFAULT_USER_PASSWORD'

MODE='primary'

DISPLAY_SIZEW=$DISPLAY_SIZE_H
DISPLAY_SIZEH=$DISPLAY_SIZE_V
DISPLAY_REFRESH=60

WEB_UI_MODE='vnc'
ENABLE_VNC_AUDIO='true'
PORT_NOVNC_WEB='8083'
NEKO_NAT1TO1=''

ENABLE_SUNSHINE='true'
SUNSHINE_USER=$SUNSHINE_USER
SUNSHINE_PASS='$SUNSHINE_PASS'

ENABLE_EVDEV_INPUTS='true'

NVIDIA_DRIVER_CAPABILITIES='all'
NVIDIA_VISIBLE_DEVICES='all'
EOF
```

After this, the container can be spin up by running:

```
docker-compose up -d
```

## Accessing the container

The web UI will be present at: http://your-host-ip:8083/. There you will find a novnc web server to connect to the container desktop, where you can start steam, etc.

Check [this guide](https://docs.lizardbyte.dev/projects/sunshine/en/latest/about/usage.html#usage) in order to know how to pair moonlight client to sunshine server.

This should be it!
