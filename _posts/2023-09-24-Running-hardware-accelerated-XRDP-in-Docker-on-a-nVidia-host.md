---
layout: post
title:  "Running hardware accelerated XRDP in Docker on a nVidia host"
date:  2023-09-24 21:30:30 -0300 
categories: english linux docker
---

# Running hardware accelerated XRDP in Docker on a nVidia host 

I've found [this github repository](https://github.com/linuxserver/docker-rdesktop) that has a nice xrdp docker container. Unfortunately, the username is not configurable, but I'm leaving this to the next chapter of this. For now, I only want to make the server up and running with hardware acceleration.

## Requirements

You must have a nVidia host with Docker, docker-compose and [nvidia container runtime](https://developer.nvidia.com/nvidia-container-runtime) installed.

## Running

After all the requirements are installed, we generate a `docker-compose.yaml` file in the server, SSH to it and run:

```
cat << EOF > docker-compose.yml
version: "3"
services:
  rdesktop:
    image:  lscr.io/linuxserver/rdesktop:ubuntu-mate-version-c4fb4788
    container_name: rdesktop
    security_opt:
      - seccomp:unconfined #optional
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Fortaleza
      - NVIDIA_VISIBLE_DEVICES=all
    volumes:
      - ./user_home:/config #optional
    ports:
      - 3389:3389
    runtime: nvidia
    shm_size: "4gb" #optional
    restart: unless-stopped
EOF
```

After that run:

```
docker-compose up -d
```

Then alter the `abc` user password:

```
docker-compose exec -it rdesktop passwd abc
```

Unfortunately, Firefox will run without gpu acceleration, but the session runs smoothly and with sound. For the next step of this saga I will be trying to make the GPU work!

This should do it for now. We're done!!
