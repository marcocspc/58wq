---
layout: post
title:  "Running hardware accelerated XRDP in Docker on a nVidia host"
date:  2023-10-16 16:49:30 -0300 
categories: english linux docker
---

# Running hardware accelerated XRDP in Docker on a nVidia host 

UPDATE: the date of this post was 2023-09-24, but since I am updating it to reflect my recent discoveries, I'll update this post's date as well.

I've found [this github repository](https://github.com/linuxserver/docker-rdesktop) that has a nice xrdp docker container. I want to make the server up and running with hardware acceleration.

## Requirements

You must have a nVidia host with Docker, docker-compose and [nvidia container runtime](https://developer.nvidia.com/nvidia-container-runtime) installed.

## Running

After all the requirements are installed, we generate a new `docker-compose.yaml` file in the server, SSH to it and run:

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
      - NVIDIA_DRIVER_CAPABILITIES=all 
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

The username can also be updated:

```
docker-compose exec -it rdesktop usermod --login new_username abc
```

## GPU Acceleration

To have GPU acceleration inside the container, [virtualgl](https://virtualgl.org) should be installed. The downside to this is that to have any application running in the GPU virtualgl must be called, as it gonna be shown afterwards. Anyway, to begin with, a Dockerfile should be used in order to set this up. So it is necessary to generate a new `docker-compose.yaml`:

```
cat << EOF > docker-compose.yml
version: "3"
services:
  rdesktop:
    build: .
    container_name: rdesktop
    security_opt:
      - seccomp:unconfined #optional
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Fortaleza
      - NVIDIA_VISIBLE_DEVICES=all
      - NVIDIA_DRIVER_CAPABILITIES=all 
    volumes:
      - ./user_home:/config #optional
    ports:
      - 3389:3389
    runtime: nvidia
    shm_size: "4gb" #optional
    restart: unless-stopped
EOF
```

Since a Dockerfile is about to be generated to customize the image, some apps will be added as well (they are useful apps, like VLC):

```
cat << EOF > Dockerfile
FROM lscr.io/linuxserver/rdesktop:ubuntu-mate-version-c4fb4788

RUN apt-get update
RUN apt-get install -y vlc eom wget mesa-utils mate-desktop-environment-extras

RUN wget -O /virtualgl.deb https://sourceforge.net/projects/virtualgl/files/3.1/virtualgl_3.1_amd64.deb/download
RUN apt install -y /virtualgl.deb
RUN rm /virtualgl.deb
EOF
```

Then the image can be built:

```
docker-compose build
```

Finally the container can be run again:

```
docker-compose up -d
```

And the user can be updated:

```
docker-compose exec -it rdesktop passwd abc
docker-compose exec -it rdesktop usermod --login new_username abc
```

To run any application with hardware acceleration, run virtualgl like this:

```
vglrun -d /dev/dri/card0 application
```

For example, to run firefox:

```
vglrun -d /dev/dri/card0 firefox
```
