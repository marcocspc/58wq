---
layout: post
title:  "Headless Steam Streaming in a Lxc Container"
date:  2021-10-03  9:29:53 -0300 
categories: english linux
---

# Headless Steam Streaming in a Lxc Container 

# *STILL UNDER CONSTRUCTION*

Ok, this time I'm going to take notes, I promise. Like every guy that likes to set up things at home and automate some things with bash and python (OK, I may have been too specific here lol), I'm horrible at taking notes.

This leads to two main consequences: I must remember everything I do and keep practicing to keep this memory (muscle) strong.

The main problem is that, well, most of the time this doesn't happen. So, this time I am going to write everything I do while trying to make this work. It will be documented, which will facilitate things for me in the future. Maybe it can help someone also, but this possibility is very unlikely to happen, in my opinion.

## What is this all about

So I have a first generation Nintendo Switch. Lately, I've been testing android 10 on it (thank u guys from the homebrew community) and would like to play my steam games at my living room. The console already runs all my streaming services, and having my games on it would make it reach it's final form hehehe.

Anyway, this project is about running a lxc container on my desktop, with a headless virtual desktop (which I should be able to change the resolution to fit any screen I want to stream it to) and accelerated graphics. On [this](https://not.just-paranoid.net/steam-streaming-on-a-headless-linux-machine-with-wayland/) guide, I have found a starting point.

The thing is, while searching on the web about a how-to, everything I stumbled upon would use X as the window manager. But recently every distribution is migrating to wayland, and I would like to set this to work for the next couple of years. Beyond that, I'd also like to use Ubuntu as the OS of the container.

And why LXC and not docker? I love docker. But at my work I deal with VMs. Lxc is a stateful container, which remembers all the changes after reboots. This makes, for example, backups easier while also being really similar with what I work with. And for projects like this, every time I need to make a change, I have to rebuild the docker image, while with lxc I don't need to do this. Anyway, I think every container manager have their own context, I'm not saying to not use docker for this, I'm just explaining that I *prefer* lxc here, but would love if someone turned this into a docker image.

## Enough of mumbo-jumbo

Yes, I learned this "mumbo-jumbo" slang a few months ago and I feel sufficient encouraged to use it now, hehe. From here, I will be annotating everything I do while I try to make this work. I hope I can organize things up after finishing this.

This time I'm going to use variables, so I do not need to change every freaking line of code next time. Do this on the host:

```
export CONTAINER=steamplay
export IMAGE=fedora/35/amd64
export IMAGE_SERVER=images
export USERNAME=marcocspc
export HOMEINCONTAINER=/home/marcocspc
```

Now let's start a new container and do all the commands to create a Fedora container:

```
sudo lxc stop $CONTAINER && sudo lxc rm $CONTAINER
sudo lxc launch $IMAGE_SERVER:$IMAGE $CONTAINER
```

Then it is a good practice to update all packages inside the container (get a root terminal first on it):

```
sudo lxc exec $CONTAINER bash
dnf -y update
```

The guide I was reading did not using containers. So I had to first get nvidia drivers working inside lxc. To do that I needed to install the same drivers of my host inside the container. But I didn't remember the version I installed, so I had to run this command to discover it:

```
nvidia-smi
...
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 460.32.03    Driver Version: 460.32.03    CUDA Version: 11.2     |
|-------------------------------+----------------------+----------------------+
...
```

Shutdown the container:

```
sudo lxc stop $CONTAINER
```

Let's mount nvidia stuff inside the container:

```
ls  -l /dev/nvidia*
export CNT=$CONTAINER
for i in $(ls /dev/nvidia*); do sudo lxc config device add $CNT $(basename $i) disk source=$i path=$i ; done
```

Start the container again:

```
sudo lxc start $CONTAINER
sudo lxc exec $CONTAINER bash
```

Get the driver (in the container):

```
cd ~
mkdir downloads
cd downloads
dnf install aria2 -y
aria2c -x 16 -s 16 https://us.download.nvidia.com/XFree86/Linux-x86_64/460.32.03/NVIDIA-Linux-x86_64-460.32.03.run
chmod +x NVIDIA-Linux-x86_64-460.32.03.run
./NVIDIA-Linux-x86_64-460.32.03.run --no-kernel-module #accept any error and answer yes to any question
```

After the installation is done, you may type this to check the driver version:

```
# nvidia-smi
...
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 460.32.03    Driver Version: 460.32.03    CUDA Version: 11.2     |
|-------------------------------+----------------------+----------------------+
...
```

Now we install sway, wayvnc and steam. First we need to enable RPM Fussion, and then install the softwares:

```
dnf install https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
dnf install sway wayvnc steam -y
```


Before we proceed, we should do some tests to see if everything is okay. Add your user and exit:

```
adduser $USERNAME
exit
```

Add a proxy device so we can reach the vnc server and steam remote play. Streaming uses UDP ports 27031 and 27036 and TCP ports 27036 and 27037:

```
sudo lxc config device add $CONTAINER $PROXYDEVICEVNC proxy listen=tcp:0.0.0.0:$PROXYDEVICEVNCPORT connect=tcp:127.0.0.1:$PROXYDEVICEVNCPORT
sudo lxc config device add $CONTAINER $PROXYDEVICESTEAM1 proxy listen=udp:0.0.0.0:$PROXYDEVICESTEAM1PORT connect=udp:127.0.0.1:$PROXYDEVICESTEAM1PORT
sudo lxc config device add $CONTAINER $PROXYDEVICESTEAM2 proxy listen=udp:0.0.0.0:$PROXYDEVICESTEAM2PORT connect=udp:127.0.0.1:$PROXYDEVICESTEAM2PORT
sudo lxc config device add $CONTAINER $PROXYDEVICESTEAM3 proxy listen=tcp:0.0.0.0:$PROXYDEVICESTEAM3PORT connect=tcp:127.0.0.1:$PROXYDEVICESTEAM3PORT
sudo lxc config device add $CONTAINER $PROXYDEVICESTEAM4 proxy listen=tcp:0.0.0.0:$PROXYDEVICESTEAM4PORT connect=tcp:127.0.0.1:$PROXYDEVICESTEAM4PORT
```

Login into the container again, switch to your user and start sway and wayvnc to test if everything is okay. These two commands should be executed in different terminal sessions (two tabs in the terminal window). I'm going to split the commands for every tab:

- In the first tab:

```
sudo lxc exec $CONTAINER bash
su $USERNAME
echo exec_always /usr/bin/steam >> ~/.config/sway/config
echo output HEADLESS-1 resolution 1280x720 >> ~/.config/sway/config
XDG_SESSION_TYPE=wayland WAYLAND_DISPLAY=wayland-1 XDG_RUNTIME_DIR=/tmp WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 sway --my-next-gpu-wont-be-nvidia
```

- In the second tab:

```
sudo lxc exec $CONTAINER bash
su $USERNAME
mkdir -p ~/.config/sway
XDG_SESSION_TYPE=wayland WAYLAND_DISPLAY=wayland-1 XDG_RUNTIME_DIR=/tmp WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 wayvnc
```

You may connect no vnc on your server IP, login into steam and link an mobile steam link app. However, by now, I can't get any image except a black screen on my phone. Need to work on this. Anyway, next step is to turn everything into system services so I don't need to manually start all of this.

Turning sway into a system service:

```
cat <<EOF > /etc/systemd/system/sway.service
[Unit]
Description=Sway Desktop
After=sway.service

[Service]
User=$USERNAME
Group=$USERNAME
Environment=XDG_SESSION_TYPE=wayland
Environment=WAYLAND_DISPLAY=wayland-1
Environment=XDG_RUNTIME_DIR=/tmp
Environment=WLR_BACKENDS=headless
Environment=WLR_LIBINPUT_NO_DEVICES=1
Type=simple
ExecStart=/usr/bin/sway --my-next-gpu-wont-be-nvidia

[Install]
WantedBy=multi-user.target
EOF
```

Now for wayvnc:

```
cat <<EOF > /etc/systemd/system/wayvnc.service
[Unit]
Description=Wayvnc Server
After=sway.service

[Service]
User=$USERNAME
Group=$USERNAME
Environment=XDG_SESSION_TYPE=wayland
Environment=WAYLAND_DISPLAY=wayland-1
Environment=XDG_RUNTIME_DIR=/tmp
Environment=WLR_BACKENDS=headless
Environment=WLR_LIBINPUT_NO_DEVICES=1
Type=simple
ExecStart=/usr/bin/wayvnc

[Install]
WantedBy=multi-user.target
EOF
```

Now enable and start both services (don't forget do test them):

```
systemctl enable sway
systemctl enable wayvnc
systemctl start sway
systemctl start wayvnc
```

After testing, disable wayvnc. We don't need to remotely access our game server anytime soon. So, for sercurity reasons, we leave it disabled. But if needed, just repeat the commands above.

```
systemctl disable wayvnc
```

That's it for now. I hope I can fix that black screen issue soon.
