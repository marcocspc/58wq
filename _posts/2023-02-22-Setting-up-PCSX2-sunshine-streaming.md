---
layout: post
title:  "Setting up PCSX2 sunshine streaming"
date:  2023-02-22 19:49:00 -0300 
categories: english linux docker
---

# Setting up PCSX2 sunshine streaming 

After I finally beaten TLOU2 (The Last of Us 2) I thought I was ready to play GoW (God of War) saga from beginning to end. One problem arisen, though: My PS4 did not have GoW 1 or 2 at its library, not even available via backwards compatibility or PS Plus or such (region lock, I guess, I live in Brazil). 

Then I decided to emulate it. But since I like to play in my switch a lot, I thought I could stream it from my headless server running Proxmox and a Debian VM. Since now we have an open source server for Moonlight, and Atmosphere (a custom rom for hacked switches) does have a moonlight client available, I decided to test this out.

Just a few notes on the host VM:

- I used a Debian 11 guest in a proxmox setup;
- While trying to run PCSX2 in the container, I've got some errors about a few instructions sets that are needed to run the emulator. This happened because I've set the CPU to qemu64 (or something like that) and PCSX2 wasn't able to recognize it. I've had to then turn off the VM and change the CPU to "host" and the emulator launched as expected;
- Also after getting SSH access to your VM, completely disable any screen, setting it to "none" in proxmox's settings. This is needed to make the containers user the correct VGA;
- You must disable secure boot (I've taken notes, they are later in the text), or the NVIDIA drivers won't be loaded at the VM startup;
- This VM uses a passed-through gtx 1060 NVIDIA gpu, so we need to make several tweaks in the code to make the containers work well with this setup.

Also, I should highlight that there are a lot of code copy and paste in certain moments of this tutorial. This means that I'll turn it into a github project later, this is just for documentation purposes for the future me to get things done the right way.

That said, let's keep going.

## Games on Whales

One set of containers that help achieving this is Games on Whales. The [project](https://github.com/games-on-whales/gow) aims to solve this problem by using a combination of Docker and Sunshine server (the open source moonlight server I mentioned before). The idea here was then to use PCSX2 to emulate PS2 games.

## Setting up the host

I've already had a Debian guest running in my proxmox. But I still needed to do some adjustments, since I have just installed it. So let's make this fine tuning.

First of all, I've had to install NVidia drivers. Make sure, first, that you have aria2 and wget installed:

```
apt install aria2 wget -y 
```

Then download the driver:

```
#You chan change this version as needed:
export NVIDIA_VERSION=525.60.13
aria2c -x 16 -s 16 https://http.download.nvidia.com/XFree86/Linux-x86_64/${NVIDIA_VERSION}/NVIDIA-Linux-x86_64-${NVIDIA_VERSION}.run
```

Install kernel headers:

```
apt-get install linux-headers-`uname -r` build-essential -y
```

Run the driver installation:

```
chmod +x ./NVIDIA-Linux-x86_64-${NVIDIA_VERSION}.run
./NVIDIA-Linux-x86_64-${NVIDIA_VERSION}.run
```

If the installation complains about signing the kernel module you can refuse. The kernel module loading may require you to disable secure boot. This was my case since I've got the following message:

```
"ERROR: The kernel module failed to load. Secure boot is enabled on this system, so this is likely because it was not signed by a key that is trusted by the kernel. Please try installing the driver again, and sign the kernel module when prompted to do so."
```

To do this, I needed to access the VM setup in proxmox console. Get there and reboot the VM, once you see the proxmox logo press Esc. Once in the blue/gray screen, go to Device Manager > Secure Boot Configuration > Attempt Secure Boot State and press space to disable it. Press F10 and save. Then press Esc until you can exit and reset.

Once you're the VM boots, SSH into the host and try to run the driver installer again. 

Also the driver installation may complain about nouveau and it will ask if you want to block it by adding some configuration files. Accept, reboot the VM and try to run the installer again. 

If the driver installation asks to add 32-bit libraries, accept.

If the driver installation asks to generate xorg configuration files, deny.

To check whether the driver is working or not after the installation process is finished, run:

```
nvidia-smi
```

If everything went accordingly, the output will be similar to this:

```
Tue Feb 21 19:07:04 2023       
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 525.60.13    Driver Version: 525.60.13    CUDA Version: 12.0     |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|                               |                      |               MIG M. |
|===============================+======================+======================|
|   0  NVIDIA GeForce ...  Off  | 00000000:06:10.0 Off |                  N/A |
| 16%   41C    P0    25W / 120W |      0MiB /  6144MiB |      1%      Default |
|                               |                      |                  N/A |
+-------------------------------+----------------------+----------------------+
                                                                               
+-----------------------------------------------------------------------------+
| Processes:                                                                  |
|  GPU   GI   CI        PID   Type   Process name                  GPU Memory |
|        ID   ID                                                   Usage      |
|=============================================================================|
|  No running processes found                                                 |
+-----------------------------------------------------------------------------+
```

Also, let's install NVidia Container Toolkit (needed to use GPU drivers inside the container). First, install curl:

```
apt install curl -y
```

Now we add the GPG key:

```
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg —dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
```

Then we create the apt source list file:

```
cat << "EOF" > /etc/apt/sources.list.d/nvidia-container-toolkit.list
deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://nvidia.github.io/libnvidia-container/stable/debian11/$(ARCH) /
EOF
```

Then finally we install it:

```
apt install -y nvidia-docker2
```

Reboot so changes can take effect!!

Before running Games on Whales, we still need to configure a virtual monitor, let's do this.

## Virtual Monitor

First of all, we need a custom edid.txt. To do this, paste all of the following lines in the terminal as root:

```
cat << EOF > /usr/share/X11/edid.txt
00 ff ff ff ff ff ff 00 1e 6d f5 56 71 ca 04 00 05 14 01 03 80 35 1e 78 0a ae c5 a2 57 4a 9c 25 12 50 54 21 08 00 b3 00 81 80 81 40 01 01 01 01 01 01 01 01 01 01 1a 36 80 a0 70 38 1f 40 30 20 35 00 13 2b 21 00 00 1a 02 3a 80 18 71 38 2d 40 58 2c 45 00 13 2b 21 00 00 1e 00 00 00 fd 00 38 3d 1e 53 0f 00 0a 20 20 20 20 20 20 00 00 00 fc 00 57 32 34 35 33 0a 20 20 20 20 20 20 20 01 3d 02 03 21 f1 4e 90 04 03 01 14 12 05 1f 10 13 00 00 00 00 23 09 07 07 83 01 00 00 65 03 0c 00 10 00 02 3a 80 18 71 38 2d 40 58 2c 45 00 13 2b 21 00 00 1e 01 1d 80 18 71 1c 16 20 58 2c 25 00 13 2b 21 00 00 9e 01 1d 00 72 51 d0 1e 20 6e 28 55 00 13 2b 21 00 00 1e 8c 0a d0 8a 20 e0 2d 10 10 3e 96 00 13 2b 21 00 00 18 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 26
EOF
```

We now add the edid.txt file to xorg-screen.conf. Again, paste all the lines below as root:

```
cat << EOF > /etc/X11/xorg-screen.conf
Section "Screen"
    Identifier     "Screen0"
    Device         "Device0"
    Monitor        "Monitor0"
    DefaultDepth    24
    Option         "AllowEmptyInitialConfiguration" "True"
    Option         "UseDisplayDevice" "DP-0"
    Option         "CustomEDID" "DP-0:/home/retro/edid.txt"
    Option         "ConnectedMonitor" "DP-0"
    SubSection     "Display"
        Depth       24
    EndSubSection
EndSection
EOF
```

Next, let's go to the docker part.

## Installing docker

Install docker using this command:

```
apt install docker.io -y
```

Install docker-compose:

```
wget -O /usr/bin/docker-compose https://github.com/docker/compose/releases/download/v2.15.0/docker-compose-linux-x86_64
chmod +x /usr/bin/docker-compose
```

## Install Games on Whales

First install git:

```
apt install git -y
```

Then clone the repository:

```
git clone https://github.com/games-on-whales/gow.git
```

Enter it:

```
cd gow
```

Edit some files to match our headless setup. First edit compose/headless.yml:

```
vim compose/platforms/headless.yml
```

Turn this section:

```
services:
  xorg:
    image: ghcr.io/games-on-whales/xorg:edge
    # Most people will probably prefer to pull the pre-built images, but if you
    # prefer to build yourself you can uncomment these lines
#   build:
#     context: ./images/xorg
#     args:
#       BASE_IMAGE: ${BUILD_BASE_IMAGE}
#       BASE_APP_IMAGE: ${BUILD_BASE_APP_IMAGE}
    runtime: ${DOCKER_RUNTIME}
    network_mode: ${UDEVD_NETWORK}
    privileged: true
    volumes:
      # Shared with Sunshine in order to get mouse and joypad working
      - /dev/input:/dev/input:ro
      - udev:/run/udev/:ro
      # The xorg socket, it'll be populated when up and running
      - ${XORG_SOCKET}:/tmp/.X11-unix
      # run-gow: xorg_driver
```

I've added three lines in the "volumes" key. The section should look like this after the alteration:

```
services:
  xorg:
    image: ghcr.io/games-on-whales/xorg:edge
    # Most people will probably prefer to pull the pre-built images, but if you
    # prefer to build yourself you can uncomment these lines
#   build:
#     context: ./images/xorg
#     args:
#       BASE_IMAGE: ${BUILD_BASE_IMAGE}
#       BASE_APP_IMAGE: ${BUILD_BASE_APP_IMAGE}
    runtime: ${DOCKER_RUNTIME}
    network_mode: ${UDEVD_NETWORK}
    privileged: true
    volumes:
      #added the system_bus_socket, the edid.txt and xorg-screen.conf volumes
      - /run/dbus/system_bus_socket:/run/dbus/system_bus_socket
      - /usr/share/X11/edid.txt:/home/retro/edid.txt:ro
      - /etc/X11/xorg-screen.conf:/usr/share/X11/xorg.conf.d/01-xorg-screen.conf:ro
      # Shared with Sunshine in order to get mouse and joypad working
      - /dev/input:/dev/input:ro
      - udev:/run/udev/:ro
      # The xorg socket, it'll be populated when up and running
      - ${XORG_SOCKET}:/tmp/.X11-unix
      # run-gow: xorg_driver
```

Also, in the same file, there's another section. And the system_bus_socket volume here too. This section should look like this before the change:

```
  # PulseAudio is used for streaming sound
  pulse:
    image: ghcr.io/games-on-whales/pulseaudio:edge
#   build:
#     context: ./images/pulseaudio
#     args:
#       BASE_IMAGE: ${BUILD_BASE_IMAGE}
#       BASE_APP_IMAGE: ${BUILD_BASE_APP_IMAGE}
    ipc: ${SHARED_IPC}
    volumes:
      - ${PULSE_SOCKET_HOST}:${PULSE_SOCKET_GUEST}
```

After:

```
  # PulseAudio is used for streaming sound
  pulse:
    image: ghcr.io/games-on-whales/pulseaudio:edge
#   build:
#     context: ./images/pulseaudio
#     args:
#       BASE_IMAGE: ${BUILD_BASE_IMAGE}
#       BASE_APP_IMAGE: ${BUILD_BASE_APP_IMAGE}
    ipc: ${SHARED_IPC}
    volumes:
      - ${PULSE_SOCKET_HOST}:${PULSE_SOCKET_GUEST}
      - /run/dbus/system_bus_socket:/run/dbus/system_bus_socket
```

Also we edit headless.env to match our setup:

```
vim env/headless.env
```

Change these lines to match you preferences. In my case, since I wanted to play on my switch, I changed the resolution to 720p. I've also changed the XORG_DISPLAY_PORT to DP-0. This is how it was before:

```
XORG_RESOLUTION=1920x1080
XORG_REFRESH_RATE=60
XORG_DISPLAY_PORT=HDMI-0
XORG_FORCE_RESOLUTION=false
```

After:

```
XORG_RESOLUTION=1280x720
XORG_REFRESH_RATE=60
XORG_DISPLAY_PORT=DP-0
XORG_FORCE_RESOLUTION=false
```

Make sure thar XORG_DISPLAY_PORT is set to DP-0!

Now we create a local_state folder:

```
mkdir local_state
```

Apply the needed permissions (for now, unfortunately, we need to 777 it):

```
chmod 777 local_state
```

Edit your user.env and set your timezone. 

```
vim user.env
```

Before the editing my file was like this:

```
local_state=./local_state

TIME_ZONE=Europe/London

PUID=1000
PGID=1000
```

After:

```
local_state=./local_state

TIME_ZONE=America/Fortaleza

PUID=1000
PGID=1000
```

To test it, we use retroarch container. Pull the container image:

```
./run-gow --gpu nvidia --platform headless --app retroarch pull
```

Run it:

```
./run-gow --gpu nvidia --platform headless --app retroarch up
```

At this point you can test if everything is working as expected. Go to https://your-vm-ip:47990/ to pair your device. You can follow [this guide](https://games-on-whales.github.io/gow/connecting.html) to know how to do this. Once you finished your testing, press Ctrl + C on your terminal to finish the containers.

Once tested, bring down the containers and remove them. This is needed because we are rebuilding images ahead:

```
./run-gow --gpu nvidia --platform headless --app retroarch down
docker container prune
```

## Creating a PCSX2 custom container in Games on Whales

Create a new folder called pcsx2:

```
mkdir images/pcsx2
```

Create a new folder called scripts:

```
mkdir images/pcsx2/scripts
```

Create a Dockerfile (paste all lines at once):

```
cat << "EOF" > images/pcsx2/Dockerfile
ARG BASE_APP_IMAGE

# hadolint ignore=DL3006
FROM ${BASE_APP_IMAGE}

ARG DEBIAN_FRONTEND=noninteractive
ARG REQUIRED_PACKAGES=" \
    vulkan-tools \
    software-properties-common \
    kmod \
    "

RUN apt-get update && \
    apt-get install $REQUIRED_PACKAGES -y

RUN add-apt-repository -y ppa:pcsx2-team/pcsx2-daily 

RUN apt-get update && \
    apt-get install -y pcsx2-unstable

ENV XDG_RUNTIME_DIR=/tmp/.X11-unix

COPY --chmod=777 scripts/startup.sh /opt/gow/startup-app.sh
COPY --chmod=777 scripts/ensure-nvidia-xorg-driver.sh /opt/gow/ensure-nvidia-xorg-driver.sh
COPY --chmod=777 scripts/99-glxinfo.sh /etc/cont-init.d/

#the script will only really run if on nvidia hosts, there's an if inside it
RUN /opt/gow/ensure-nvidia-xorg-driver.sh

ARG IMAGE_SOURCE
LABEL org.opencontainers.image.source $IMAGE_SOURCE
EOF
```

Create a startup script:

```
cat << "EOF" > images/pcsx2/scripts/startup.sh
#!/bin/bash
set -e

source /opt/gow/bash-lib/utils.sh

gow_log "Starting PCSX2"

CFG_DIR=$HOME/.config/PCSX2

exec /usr/bin/pcsx2-qt

EOF
```

Another thing I've discovered while trying to debug this is that glxinfo execution before (or after) PCSX2 is running inside its container allow it to run properly. Without this is would just show an "failed to create blabla context blabla" and fail to run the game. I discovered this because once I received this message, I would launch glxinfo to check whether I was using nvidia drivers or llvm pipe as OpenGL renderer. Anyway, after launching glxinfo I tried again and everytime the game would launch as normal LOL. So following the IT JUST WORKS (tm) I decided to include this command at container startup. To do this, we create a 99-glxinfo.sh script:

```
cat << "EOF" > images/pcsx2/scripts/99-glxinfo.sh
#!/bin/bash

set -e

source /opt/gow/bash-lib/utils.sh

if [ -z "$DISPLAY" ]; then
    gow_log "FATAL: No DISPLAY environment variable set.  No X."
    exit 13
fi

gow_log "Waiting for X server..."
# Taken from https://gist.github.com/tullmann/476cc71169295d5c3fe6
MAX=120 # About 120 seconds
CT=0
while ! xdpyinfo >/dev/null 2>&1; do
    sleep 1s
    CT=$(( CT + 1 ))
    if [ "$CT" -ge "$MAX" ]; then
        gow_log "FATAL: $0: Gave up waiting for X server $DISPLAY"
        exit 11
    fi
done

gow_log "running glxinfo, somehow this is needed to make pcsx2 work properly"
glxinfo > /dev/null
EOF
```

Create the ensure-nvidia-xorg-driver.sh script:


```
cat << "EOF" > images/pcsx2/scripts/ensure-nvidia-xorg-driver.sh
#!/bin/bash

NVIDIA_DRIVER_MOUNT_LOCATION=/nvidia/xorg
NVIDIA_PACKAGE_LOCATION=/usr/lib/x86_64-linux-gnu/nvidia/xorg

# If the user has requested to skip the check, do so
if [ "${SKIP_NVIDIA_DRIVER_CHECK:-0}" = "1" ]; then
    exit
fi

fail() {
    (
        if [ -n "${1:-}" ]; then
            echo "$1"
        fi
        echo "Xorg may fail to start; try mounting drivers from your host as a volume."
    ) >&2
    exit 1
}

# If there's an nvidia_drv.so in the mount location, or in the location where
# the xserver-xorg-video-nvidia package installs to, assume it's the right one
for d in $NVIDIA_DRIVER_MOUNT_LOCATION $NVIDIA_PACKAGE_LOCATION; do
    if [ -f "$d/nvidia_drv.so" ]; then
        echo "Found an existing nvidia_drv.so"
        exit
    fi
done

# Otherwise, try to download the correct package.
HOST_DRIVER_VERSION=$(sed -nE 's/.*Module[ \t]+([0-9]+(\.[0-9]+)*).*/\1/p' /proc/driver/nvidia/version)

if [ -z "$HOST_DRIVER_VERSION" ]; then
    echo "Could not find NVIDIA driver; skipping"
    exit 0
else
    echo "Looking for driver version $HOST_DRIVER_VERSION"
fi

download_pkg() {
    dl_url=$1
    dl_file=$2

    echo "Downloading $dl_url"

    if ! wget -q -nc --show-progress --progress=bar:force:noscroll -O "$dl_file" "$dl_url"; then
        echo "ERROR: Unable to download $dl_file"
        return 1
    fi
}

DOWNLOAD_URL=https://download.nvidia.com/XFree86/Linux-x86_64/$HOST_DRIVER_VERSION/NVIDIA-Linux-x86_64-$HOST_DRIVER_VERSION.run
DL_FILE=/tmp/nvidia-$HOST_DRIVER_VERSION.run
EXTRACT_LOC=/tmp/nvidia-drv

if [ ! -d $EXTRACT_LOC ]; then
    if ! download_pkg "$DOWNLOAD_URL" "$DL_FILE"; then
        echo "Couldn't download nvidia driver version $HOST_DRIVER_VERSION"
        exit 1
    fi

    chmod +x "$DL_FILE"
    $DL_FILE -x --target $EXTRACT_LOC
    $DL_FILE --accept-license --no-runlevel-check --no-questions --no-backup --ui=none --no-kernel-module --no-kernel-module-source --no-nouveau-check --no-nv
idia-modprobe
    rm "$DL_FILE"
fi

if [ ! -d $NVIDIA_DRIVER_MOUNT_LOCATION ]; then
    mkdir -p $NVIDIA_DRIVER_MOUNT_LOCATION
fi

cp "$EXTRACT_LOC/nvidia_drv.so" "$EXTRACT_LOC/libglxserver_nvidia.so.$HOST_DRIVER_VERSION" "$NVIDIA_DRIVER_MOUNT_LOCATION"

EOF
```

Create a pcsx2.yml in the apps folder:

```
cat << "EOF" > compose/apps/pcsx2.yml
#########################
# pcsx2.yml
#########################
#
# This container runs RetroArch

services:
  ####################
  pcsx2:
    build:
      context: ./images/pcsx2
      args:
        BASE_IMAGE: ${BUILD_BASE_IMAGE}
        BASE_APP_IMAGE: ${BUILD_BASE_APP_IMAGE}
    runtime: ${DOCKER_RUNTIME}
    privileged: true
    network_mode: ${UDEVD_NETWORK}
    volumes:
      # Followings are needed in order to get joystick support
      - /dev/input:/dev/input:ro
      - udev:/run/udev/:ro
      # Xorg socket in order to get the screen
      - ${XORG_SOCKET}:/tmp/.X11-unix
      # Pulse socket, audio
      - ${PULSE_SOCKET_HOST}:${PULSE_SOCKET_GUEST}
      # Home directory: retroarch games, downloads, cores etc
      - ${local_state}/:/home/retro/
      # some emulators need more than 64 MB of shared memory - see https://github.com/libretro/dolphin/issues/222
      # TODO: why shm_size doesn't work ??????
      - type: tmpfs
        target: /dev/shm
        tmpfs:
          size: ${SHM_SIZE}
    ipc: ${SHARED_IPC}  # Needed for MIT-SHM, removing this should cause a performance hit see https://github.com/jessfraz/dockerfiles/issues/359
    env_file:
      - config/common.env
      - config/xorg.env
      # run-gow: gpu_env

    environment:
      # Which devices does GoW need to be able to use? The docker user will be
      # added to the groups that own these devices, to help with permissions
      # issues
      # These values are the defaults, but you can add others if needed
      GOW_REQUIRED_DEVICES: /dev/uinput /dev/input/event* /dev/dri/* /dev/snd/*
EOF
```

OK! With this we have all the PCSX2 docker files and scripts in place. But there is still a few modifications to go. Unfortunately, while reading and trying to troubleshoot why the container wouldn't run with GPU acceleration, I've discoreved that the NVIDIA driver needed to be installed in both pcsx2 and xorg containers. In the xorg one there was already a script to do this, but this code did some magic extraction that, while made available the .so files needed by xorg to run, the software would still complain and fall back to software rendering. I was able to fix this by properly running the driver instllation binary inside the container at creation time. To do this, I needed to alter the ensure-nvidia-xorg-driver.sh script, so we can just repurpose the pcsx2 one:

```
cp images/pcsx2/scripts/ensure-nvidia-xorg-driver.sh images/xorg/scripts/ensure-nvidia-xorg-driver.sh
```

Still, to make this work, we need to edit xorg compose file to force rebuilding the image (instead of just pulling from dockerhub). To do this, we need to remove the line "image: (...)" and uncommenting the "build" lines inside headless.yml:

```
vim compose/platforms/headless.yml
```

Find this section:

```
...
services:                                                                                                                                                    
  xorg:                                       
    restart: always
    image: ghcr.io/games-on-whales/xorg:edge
    # Most people will probably prefer to pull the pre-built images, but if you
    # prefer to build yourself you can uncomment these lines
#   build:
#     context: ./images/xorg
#     args:
#       BASE_IMAGE: ${BUILD_BASE_IMAGE}
#       BASE_APP_IMAGE: ${BUILD_BASE_APP_IMAGE}
    runtime: ${DOCKER_RUNTIME}
...
```

And turn it into this:

```
...
services:
  xorg:
    restart: always
    # Most people will probably prefer to pull the pre-built images, but if you
    # prefer to build yourself you can uncomment these lines
    build:
      context: ./images/xorg
      args:
        BASE_IMAGE: ${BUILD_BASE_IMAGE}
        BASE_APP_IMAGE: ${BUILD_BASE_APP_IMAGE}
    runtime: ${DOCKER_RUNTIME}
...
```

Also edit xorg Dockerfile to include kmod as a required package:

```
vim images/xorg/Dockerfile
```

Find this section:

```
...
ARG REQUIRED_PACKAGES=" \
    wget \
    xserver-xorg-core xcvt xfonts-base x11-apps \
    x11-session-utils x11-utils x11-xfs-utils \
    x11-xserver-utils xauth x11-common \
    xz-utils unzip avahi-utils dbus \
    mesa-utils mesa-utils-extra \
    vulkan-tools \
    libgl1-mesa-glx libgl1-mesa-dri libglu1-mesa \
    xserver-xorg-video-all \
    xserver-xorg-input-libinput \
    jwm libxft2 libxext6 breeze-cursor-theme \
    "
...
```

And add kmod besides wget, like this:

```
...
ARG REQUIRED_PACKAGES=" \
    wget kmod \
    xserver-xorg-core xcvt xfonts-base x11-apps \
    x11-session-utils x11-utils x11-xfs-utils \
    x11-xserver-utils xauth x11-common \
    xz-utils unzip avahi-utils dbus \
    mesa-utils mesa-utils-extra \
    vulkan-tools \
    libgl1-mesa-glx libgl1-mesa-dri libglu1-mesa \
    xserver-xorg-video-all \
    xserver-xorg-input-libinput \
    jwm libxft2 libxext6 breeze-cursor-theme \
    "
...
```

Build the images using the command below:

```
./run-gow --gpu nvidia --platform headless --app pcsx2 build
```

To test (after the long process of image building), use:

```
./run-gow --gpu nvidia --platform headless --app pcsx2 up
```

If everything went right, you should see pcsx2 window shown in your moonlight client. Still we cannot play, yet. We need the bios and the games. Let's do this then.

After the test is done, stop the containers by pressing Ctrl + C.

## Putting bios and games in the right places

Finally let's put some bios and games. If you made the test from the section above, you'll see that PCSX2 already created its config files under ./local_store/.config/PCSX2.

All you need to do is to put your bios under ./local_store/.config/PCSX2/bios and your games in ./local_store/.config/PCSX2/games.

## Putting containers to always restart

Now the final touch is to edit a few files to make the service restart after we reboot the VM. We add `restart: always` in a few services in compose files. First, edit headless.yml:

```
vim compose/platforms/headless.yml
```

Here you will need to add `restart: always` under those three services (xorg, pulse and udevd). I'll only post the file after adding the key in all services. Here's the edited file:

```
#########################
# headless.yml
#########################
# This file contains services that are required if you want to run GoW in a
# headless environment (ie, on a host that does not have its own Xorg server)

services:
  xorg:
    restart: always
    image: ghcr.io/games-on-whales/xorg:edge
    # Most people will probably prefer to pull the pre-built images, but if you
    # prefer to build yourself you can uncomment these lines
#   build:
#     context: ./images/xorg
#     args:
#       BASE_IMAGE: ${BUILD_BASE_IMAGE}
#       BASE_APP_IMAGE: ${BUILD_BASE_APP_IMAGE}
    runtime: ${DOCKER_RUNTIME}
    network_mode: ${UDEVD_NETWORK}
    privileged: true
    volumes:
      - /usr/share/X11/edid.txt:/home/retro/edid.txt:ro
      - /etc/X11/xorg.conf:/usr/share/X11/xorg.conf.d/01-xorg-screen.conf:ro
      # Shared with Sunshine in order to get mouse and joypad working
      - /dev/input:/dev/input:ro
      - udev:/run/udev/:ro
      # The xorg socket, it'll be populated when up and running
      - ${XORG_SOCKET}:/tmp/.X11-unix
      # run-gow: xorg_driver

    ipc: ${XORG_IPC} # Needed for MIT-SHM, removing this should cause a performance hit see https://github.com/jessfraz/dockerfiles/issues/359

    env_file:
      - config/common.env
      - config/xorg.env
      # run-gow: gpu_env

    environment:
      RESOLUTION: ${XORG_RESOLUTION}
      CURRENT_OUTPUT: ${XORG_DISPLAY_PORT}
      REFRESH_RATE: ${XORG_REFRESH_RATE}
      FORCE_RESOLUTION: ${XORG_FORCE_RESOLUTION}

  # PulseAudio is used for streaming sound
  pulse:
    image: ghcr.io/games-on-whales/pulseaudio:edge
    restart: always
#   build:
#     context: ./images/pulseaudio
#     args:
#       BASE_IMAGE: ${BUILD_BASE_IMAGE}
#       BASE_APP_IMAGE: ${BUILD_BASE_APP_IMAGE}
    ipc: ${SHARED_IPC}
    volumes:
      - ${PULSE_SOCKET_HOST}:${PULSE_SOCKET_GUEST}
      - /run/dbus/system_bus_socket:/run/dbus/system_bus_socket

#####################
# We may not need udev, but some people have reported input issues without it;
# let's keep it around for now
  udevd:
    image: ghcr.io/games-on-whales/udevd:edge
    restart: always
#   build:
#     context: ./images/udevd
#     args:
#       BASE_IMAGE: ${BUILD_BASE_IMAGE}
#       BASE_APP_IMAGE: ${BUILD_BASE_APP_IMAGE}
#    # Setting network to host
#    # There must be a way to avoid this but I can't figure it out
#    # We need to be on the host network in order to get the PF_NETLINK socket
#    # You can listen to events even without that socket but Xorg and RetroArch will not pickup the devices
    network_mode: host
    privileged: true
    volumes:
      - udev:/run/udev/

####################
volumes:
  xorg: # This will hold the xorg socket file and it'll be shared between containers
  pulse: # This will hold the xorg socket
```

Do the same in pcsx2.yml:

```
vim compose/apps/pcsx2.yml
```

This is the file after adding `restart: always` in pcsx2 service:

```
#########################
# pcsx2.yml
#########################
#
# This container runs RetroArch

services:
  ####################
  pcsx2:
    restart: always
    build:
      context: ./images/pcsx2
      args:
        BASE_IMAGE: ${BUILD_BASE_IMAGE}
        BASE_APP_IMAGE: ${BUILD_BASE_APP_IMAGE}
    runtime: ${DOCKER_RUNTIME}
    privileged: true
    network_mode: ${UDEVD_NETWORK}
    volumes:
      # Followings are needed in order to get joystick support
      - /dev/input:/dev/input:ro
      - udev:/run/udev/:ro
      # Xorg socket in order to get the screen
      - ${XORG_SOCKET}:/tmp/.X11-unix
      # Pulse socket, audio
      - ${PULSE_SOCKET_HOST}:${PULSE_SOCKET_GUEST}
      # Home directory: retroarch games, downloads, cores etc
      - ${local_state}/:/home/retro/
      # some emulators need more than 64 MB of shared memory - see https://github.com/libretro/dolphin/issues/222
      # TODO: why shm_size doesn't work ??????
      - type: tmpfs
        target: /dev/shm
        tmpfs:
          size: ${SHM_SIZE}
    ipc: ${SHARED_IPC}  # Needed for MIT-SHM, removing this should cause a performance hit see https://github.com/jessfraz/dockerfiles/issues/359
    env_file:
      - config/common.env
      - config/xorg.env
      # run-gow: gpu_env

    environment:
      # Which devices does GoW need to be able to use? The docker user will be
      # added to the groups that own these devices, to help with permissions
      # issues
      # These values are the defaults, but you can add others if needed
      GOW_REQUIRED_DEVICES: /dev/uinput /dev/input/event* /dev/dri/* /dev/snd/*
```

Finally, edit sunshine.yml:

```
vim compose/streamers/sunshine.yml
```

You need to insert `restart: always` in the sunshine service:

```
version: "3"

services:
  ##########################################
  # There's a lot going on in this file; it's normal to get lost with all the
  # options and variables
  #
  # Before diving in, make sure to take a look at the documentation.  In
  # particular, it will be helpful to read the components-overview section
  # (https://games-on-whales.github.io/gow/components-overview.html)
  # in order to get a view on how the various components are tied together.
  ###################

  ####################
  # Sunshine is the heart of the streaming setup; it takes your desktop and
  # encodes it for delivery over the network
  sunshine:
    image: ghcr.io/games-on-whales/sunshine:edge
    restart: always
  # build:
  #   context: ./images/sunshine
  #   args:
  #     BASE_IMAGE: ${BUILD_BASE_IMAGE}
  #     BASE_APP_IMAGE: ${BUILD_BASE_APP_IMAGE}

    runtime: ${DOCKER_RUNTIME}
    ports:
      - 47984-47990:47984-47990/tcp
      - 48010:48010
      - 47998-48000:47998-48000/udp
    privileged: true
    volumes:
      # Xorg socket in order to get the screen
      - ${XORG_SOCKET}:/tmp/.X11-unix
      # Pulse socket, audio
      - ${PULSE_SOCKET_HOST}:${PULSE_SOCKET_GUEST}
      # Home directory: sunshine state + configs
      - ${local_state}/:/home/retro/
      # OPTIONAL: host dbus used by avahi in order to publish Sunshine for auto network discovery
      - ${DBUS}:/run/dbus:ro
    ipc: ${SHARED_IPC}  # Needed for MIT-SHM, removing this should cause a performance hit see https://github.com/jessfraz/dockerfiles/issues/359

    env_file:
      - config/common.env
      - config/xorg.env
      # run-gow: gpu_env

    environment:
      LOG_LEVEL: ${SUNSHINE_LOG_LEVEL}
      GOW_REQUIRED_DEVICES: /dev/uinput /dev/input/event* /dev/dri/*
      # Username and password for the web-ui at https://xxx.xxx.xxx.xxx:47990
      SUNSHINE_USER: ${SUNSHINE_USER}
      SUNSHINE_PASS: ${SUNSHINE_PASS}
      XDG_RUNTIME_DIR: /tmp/.X11-unix

volumes:
  udev:
``` 

To start Games on Whales in the background, run this command:

```
./run-gow --gpu nvidia --platform headless --app pcsx2 up -d
```

To stop the service, run this:

```
./run-gow --gpu nvidia --platform headless --app pcsx2 down -d
```

This should make Games on Whales restart after a reboot.

Reboot your VM and check if the service is back up on-line.

This should be it, WE'RE DONE!!!

## References

[https://linuxhint.com/nvidia-gpu-docker-containers-debian-11/#post-295282-_Toc125512693](https://linuxhint.com/nvidia-gpu-docker-containers-debian-11/#post-295282-_Toc125512693)
