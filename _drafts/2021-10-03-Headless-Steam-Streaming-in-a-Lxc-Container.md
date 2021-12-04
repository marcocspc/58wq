---
layout: post
title:  "Headless Steam Streaming in a Lxc Container"
date:  2021-10-03  9:29:53 -0300 
categories: english linux
---

# Headless Steam Streaming in a Lxc Container 

So I have a first generation Nintendo Switch. Lately, I've been testing android 10 on it (thank u guys from the homebrew community) and would like to play my  and steamsteam games at my living room. The console already runs all my streaming services, and having my games on it would make it reach it's final form hehehe.

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
export NVIDIADRIVER_URL=https://us.download.nvidia.com/XFree86/Linux-x86_64/470.74/NVIDIA-Linux-x86_64-470.74.run
export NVIDIAINSTALLER=$(basename $NVIDIADRIVER_URL)
export PROXYDEVICEVNCPROTO=tcp
export PROXYDEVICEVNCPORT=5900
export PROXYDEVICEVNC=vnc$PROXYDEVICEVNCPORT
export PROXYDEVICESTEAM1PROTO=tcp
export PROXYDEVICESTEAM1PORT=27036
export PROXYDEVICESTEAM1=steam1$PROXYDEVICESTEAM1PORT
export PROXYDEVICESTEAM2PROTO=$PROXYDEVICESTEAM1PROTO
export PROXYDEVICESTEAM2PORT=27037
export PROXYDEVICESTEAM2=steam2$PROXYDEVICESTEAM2PORT
export PROXYDEVICESTEAM3PROTO=udp
export PROXYDEVICESTEAM3PORT=27031
export PROXYDEVICESTEAM3=steam1$PROXYDEVICESTEAM3PORT
export PROXYDEVICESTEAM4PROTO=$PROXYDEVICESTEAM3PROTO
export PROXYDEVICESTEAM4PORT=27036
export PROXYDEVICESTEAM4=steam1$PROXYDEVICESTEAM4PORT
```

Now let's start a new container:

```
sudo lxc stop $CONTAINER && sudo lxc rm $CONTAINER
sudo lxc launch $IMAGE_SERVER:$IMAGE $CONTAINER
```

Then it is a good practice to update all packages inside the container (get a root terminal first on it):

```
sudo lxc exec $CONTAINER -- dnf -y update
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

Also add gpu to the container and give permissions to use it:

```
sudo lxc config device add $CONTAINER mygpu gpu
var=$(cat << EOF 
lxc.cgroup.devices.allow = c 226:* rwm
EOF
)
sudo lxc config set $CONTAINER raw.lxc "$var"
```

Start the container again:

```
sudo lxc start $CONTAINER
```

Get the driver in the container (answer OK and Yes to everything):

```
sudo lxc exec $CONTAINER -- bash -c "cd ~ && mkdir downloads"
sudo lxc exec $CONTAINER -- bash -c "cd downloads && dnf install aria2 -y && aria2c -x 16 -s 16 $NVIDIADRIVER_URL && chmod +x $NVIDIAINSTALLER && ./$NVIDIAINSTALLER --no-kernel-module"
```

After the installation is done, you may type this to check the driver version:

```
sudo lxc exec $CONTAINER -- nvidia-smi
...
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 460.32.03    Driver Version: 460.32.03    CUDA Version: 11.2     |
|-------------------------------+----------------------+----------------------+
...
```

Now we install sway, wayvnc and steam. First we need to enable RPM Fussion, and then install the softwares:

```
sudo lxc exec $CONTAINER -- dnf install -y fedora-workstation-repositories
sudo lxc exec $CONTAINER -- dnf install sway wayvnc steam -y --enablerepo=rpmfusion-nonfree-steam
```

To have audio on our stream (and even make some games run, since they won't if there is no audio output) we need to install pulseaudio. For some reason, Fedora 34 have some conflicts between pipewire and pulseaudio, so we remove the former and install the latter:

```
sudo lxc exec $CONTAINER -- dnf remove -y pipewire 
sudo lxc exec $CONTAINER -- dnf install -y pulseaudio pulseaudio-utils boost-program-options git meson make automake gcc gcc-c++ kernel-devel cmake pulseaudio-libs-devel
sudo lxc exec $CONTAINER -- bash -c "git clone https://github.com/cdemoulins/pamixer.git && cd pamixer && meson setup build && meson compile -C build && meson install -C build && cd .. && rm -rf pamixer"
```

Before we proceed, we should do some tests to see if everything is okay. Add your user and exit:

```
sudo lxc exec $CONTAINER -- useradd "$USERNAME" -m
sudo lxc exec $CONTAINER -- passwd "$USERNAME"
```

Add a proxy device so we can reach the vnc server and steam remote play. Streaming uses UDP ports 27031 and 27036 and TCP ports 27036 and 27037:

```
sudo lxc config device add $CONTAINER $PROXYDEVICEVNC proxy listen=$PROXYDEVICEVNCPROTO:0.0.0.0:$PROXYDEVICEVNCPORT connect=$PROXYDEVICEVNCPROTO:127.0.0.1:$PROXYDEVICEVNCPORT
sudo lxc config device add $CONTAINER $PROXYDEVICESTEAM1 proxy listen=PROXYDEVICESTEAM1PROTO:0.0.0.0:$PROXYDEVICESTEAM1PORT connect=$PROXYDEVICESTEAM1PROTO:127.0.0.1:$PROXYDEVICESTEAM1PORT
sudo lxc config device add $CONTAINER $PROXYDEVICESTEAM2 proxy listen=$PROXYDEVICESTEAM2PROTO:0.0.0.0:$PROXYDEVICESTEAM2PORT connect=$PROXYDEVICESTEAM2PROTO:127.0.0.1:$PROXYDEVICESTEAM2PORT
sudo lxc config device add $CONTAINER $PROXYDEVICESTEAM3 proxy listen=$PROXYDEVICESTEAM3PROTO:0.0.0.0:$PROXYDEVICESTEAM3PORT connect=$PROXYDEVICESTEAM3PROTO:127.0.0.1:$PROXYDEVICESTEAM3PORT
sudo lxc config device add $CONTAINER $PROXYDEVICESTEAM4 proxy listen=$PROXYDEVICESTEAM4PROTO:0.0.0.0:$PROXYDEVICESTEAM4PORT connect=$PROXYDEVICESTEAM4PROTO:127.0.0.1:$PROXYDEVICESTEAM4PORT
```

Add a ~/.tmp directory, so we can use to be the XDG_RUNTIME_DIR (I tried using /tmp, but had some permissions issues):

```
sudo lxc exec $CONTAINER -- mkdir -p /home/$USERNAME/.tmp
sudo lxc exec $CONTAINER -- chown -R $USERNAME:$USERNAME /home/$USERNAME/.tmp
```

Login into the container again, switch to your user and start sway and wayvnc to test if everything is okay. These two commands should be executed in different terminal sessions (two tabs in the terminal window). I'm going to split the commands for every tab:

- In the first tab:

```
sudo lxc exec $CONTAINER bash
su $USERNAME
#needed to have audio on the stream
mkdir -p ~/.config/sway
echo exec_always pulseaudio --start >> ~/.config/sway/config
echo exec_always pamixer -u >> ~/.config/sway/config
echo exec_always pamixer --set-volume 90 >> ~/.config/sway/config
echo exec_always /usr/bin/Xwayland :11 >> ~/.config/sway/config
echo exec_always DISPLAY=:11 steam /usr/bin/steam >> ~/.config/sway/config
echo output HEADLESS-1 resolution 1280x720 >> ~/.config/sway/config
XDG_SESSION_TYPE=wayland WAYLAND_DISPLAY=wayland-1 XDG_RUNTIME_DIR=/home/$USERNAME/.tmp WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 sway --my-next-gpu-wont-be-nvidia
```

- In the second tab:

```
sudo lxc exec $CONTAINER bash
su $USERNAME
mkdir -p ~/.config/sway
XDG_SESSION_TYPE=wayland WAYLAND_DISPLAY=wayland-1 XDG_RUNTIME_DIR=/home/$USERNAME/.tmp WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 wayvnc
```

You may connect no vnc on your server IP, login into steam and link an mobile steam link app. However, by now, I can't get any image except a black screen on my phone. Need to work on this. Anyway, next step is to turn everything into system services so I don't need to manually start all of this.

Turning sway into a system service:

```
sudo lxc exec $CONTAINER -- bash -c "cat <<EOF > /etc/systemd/system/sway.service
[Unit]
Description=Sway Desktop
After=sway.service

[Service]
User=$USERNAME
Group=$USERNAME
Environment=XDG_SESSION_TYPE=wayland
Environment=WAYLAND_DISPLAY=wayland-1
Environment=XDG_RUNTIME_DIR=/home/$USERNAME/.tmp
Environment=WLR_BACKENDS=headless
Environment=WLR_LIBINPUT_NO_DEVICES=1
Type=simple
ExecStart=/usr/bin/sway --my-next-gpu-wont-be-nvidia

[Install]
WantedBy=multi-user.target
EOF"
```

Now for wayvnc:

```
sudo lxc exec $CONTAINER -- bash -c "cat <<EOF > /etc/systemd/system/wayvnc.service
[Unit]
Description=Wayvnc Server
After=sway.service

[Service]
User=$USERNAME
Group=$USERNAME
Environment=XDG_SESSION_TYPE=wayland
Environment=WAYLAND_DISPLAY=wayland-1
Environment=XDG_RUNTIME_DIR=/home/$USERNAME/.tmp
Environment=WLR_BACKENDS=headless
Environment=WLR_LIBINPUT_NO_DEVICES=1
Type=simple
ExecStart=/usr/bin/wayvnc

[Install]
WantedBy=multi-user.target
EOF"
```

Now enable and start both services (don't forget do test them):

```
sudo lxc exec $CONTAINER -- systemctl enable sway
sudo lxc exec $CONTAINER -- systemctl enable wayvnc
sudo lxc exec $CONTAINER -- systemctl start sway
sudo lxc exec $CONTAINER -- systemctl start wayvnc
```

After testing, disable wayvnc. We don't need to remotely access our game server anytime soon. So, for sercurity reasons, we leave it disabled. But if needed, just repeat the commands above.

```
systemctl disable wayvnc
```

That's it for now. I hope I can fix that black screen issue soon.

## The Black Screen of Death

I solved the black screen of death by changing the contents of ~/.config/sway/config, based on what I saw [here](https://github.com/ValveSoftware/steam-for-linux/issues/6148). I already updated the lines above, where I write contents to the file.

Still need to fix audio and controller input.

# This won't be used in the final guide, but I'm going to leave here for documentation purposes whilst I don't finish this.

Ok, chapter two. I have tried again and again to use wayland, but as for now there are no guides to do it. Instead, I will try to use X11 with Archlinux, as it is described on [this](https://steamcommunity.com/sharedfiles/filedetails/?id=680514371) guide.

To begin with, I'm going to repeat the same commands as before. Starting with variables:

```
export CONTAINER=steamplay3
export IMAGE=archlinux/current/amd64
export IMAGE_SERVER=images
export USERNAME=marcocspc
export HOMEINCONTAINER=/home/marcocspc
```

Use these same variables inside the container:

```
sudo lxc exec $CONTAINER export CONTAINER=steamplay3
sudo lxc exec $CONTAINER export IMAGE=archlinux/current/amd64
sudo lxc exec $CONTAINER export IMAGE_SERVER=images
sudo lxc exec $CONTAINER export USERNAME=marcocspc
sudo lxc exec $CONTAINER export HOMEINCONTAINER=/home/marcocspc
```

For some reason, arch image has a bug that doesn't allow it to get an IP, hence disabling internet access. To circumvent this, do:

```
sudo lxc config set $CONTAINER security.nesting true
sudo lxc restart $CONTAINER
```

Update all packages inside the container (get a root terminal first on it):

```
sudo lxc shell $CONTAINER
pacman -Syu
```

The guide I was reading did not using containers. So I had to first get nvidia drivers working inside lxc, as decribed [here](https://theorangeone.net/posts/lxc-nvidia-gpu-passthrough/). To do that I needed to install the same drivers of my host inside the container. But I didn't remember the version I installed, so I had to run this command to discover it:

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

Let's mount nvidia stuff inside the container. Also we mount some tty and input devices as shown [here](https://discuss.linuxcontainers.org/t/xserver-inside-lxc-container/5022) and [here](https://forum.proxmox.com/threads/gpu-devices-passthrough.80248/) for running X later:

For the tty devices, try to find a high number by doing:

```
ls -l /dev/tty*
```

For example, on my setup I have found /dev/tty40, which is the one I use here:

```
export CNT=$CONTAINER
export DUMMY_TTY=/dev/tty40
for i in $(ls /dev/nvidia*); do sudo lxc config device add $CNT $(basename $i) disk source=$i path=$i ; done
for i in /dev/tty0 /dev/tty1 /dev/tty2 /dev/tty3 /dev/tty4 /dev/tty5 /dev/tty6 /dev/tty7 ; do sudo lxc config device add $CNT $(basename $i) unix-char source=$DUMMY_TTY path=$i ; done
for i in $(ls /dev/input/event*); do sudo lxc config device add $CNT $(basename $i) unix-char source=$i path=$i ; done
for i in $(ls /dev/input/mouse*); do sudo lxc config device add $CNT $(basename $i) unix-char source=$i path=$i ; done
for i in $(ls /dev/input/mice*); do sudo lxc config device add $CNT $(basename $i) unix-char source=$i path=$i ; done
```

Also, we need to set the permissions so the container can use all the mounted files. To do this, we add cgroup.device entries to the container configuration. As we added nvidia, tty and input/* devices, we do as follows:

```

```
var=$(cat << EOF 
lxc.cgroup.devices.allow = c 4:* rwm
lxc.cgroup.devices.allow = c 195:* rwm
lxc.cgroup.devices.allow = c 235:* rwm
lxc.cgroup.devices.allow = c 13:* rwm
EOF
)
sudo lxc config set $CONTAINER raw.lxc "$var"
```

*WARNING* the numbers were these on my context. There might be chance that yours are different. To find these numbers, issue the command below. They will be separated by commas, pay attention to the repeated numbers on each line and repeat the command above with wildcards. For example: in my setup, all /dev/input/event* started with 13, so I wrote 13:*.

```
for i in $(sudo lxc config device show $CONTAINER | grep source | awk '{print $2}') ; do ls -l $i ; done
```

Start the container again:

```
sudo lxc start $CONTAINER
sudo lxc shell $CONTAINER
```

Get the driver (in the container):

```
cd ~
mkdir downloads
cd downloads
pacman -S --noconfirm aria2
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

Now let's install the needed packages inside the container. First enable multilib:

```
vi /etc/pacman.conf
# Uncomment these lines: 
#[multilib]
#Include = /etc/pacman.d/mirrorlist
```

Upgrade the system:

```
pacman -Syyu --noconfirm
```

Now finally install the packages:

```
pacman -S --overwrite "*" --noconfirm xf86-input-libinput xorg-server xorg-apps xorg-xinit linux-headers ttf-liberation lib32-alsa-plugins lib32-curl pulseaudio pulseaudio-alsa pamixer xfwm4 xfce4-session xfdesktop lxterminal
```

"*"

Next step, according to the main guide, is to create Xwrapper.config and add the line allowed_users=anybody, so X can be started from an SSH session:

```
vi /etc/X11/Xwrapper.config
```

Add an user to play the games. Here I use the username from that environment variable:

```
useradd -m -g users -G video,storage,power -s /bin/bash $USERNAME
``` 

Set the password for this user:

```
passwd $USERNAME
```

Install steam:

```
pacman -S --noconfirm steam
```

On the original guide, monitor, mouse and keyboard are used to set up steam. Here I try to do it differently, we are using vnc to do it. First I'm going to try to create a "virtual monitor" so vnc can attach to. This is done the same way as in the guide. Edit /edid.txt and paste the following content:

```
vi /edid.txt
```

Content:

```
00 ff ff ff ff ff ff 00 1e 6d 39 58 37 f4 05 00 0c 15 01 03 80 30 1b 78 ea 33 31 a3 54 51 9e 27 11 50 54 a5 4b 00 71 4f 81 80 81 8f b3 00 01 01 01 01 01 01 01 01 02 3a 80 18 71 38 2d 40 58 2c 45 00 dd 0c 11 00 00 1e 00 00 00 fd 00 38 4b 1e 53 0f 00 0a 20 20 20 20 20 20 00 00 00 fc 00 45 32 32 31 31 0a 20 20 20 20 20 20 20 00 00 00 ff 00 31 31 32 4e 44 56 57 42 47 31 39 39 0a 00 38
```

Now edit /etc/X11/xorg.conf, find the section "Monitor" and add the following lines:

```
    Option "ConnectedMonitor""DFP-2"
    Option "CustomEDID""DFP-2:/edid.txt"
```

On the original guide, monitor, mouse and keyboard are used to set up steam. Here I try to do it differently, we are using vnc to do it. I've found a [question](https://unix.stackexchange.com/questions/597528/virtual-monitor-when-using-nvidia-graphics-for-vnc-based-second-monitor) on stackexchange pointing me to [this guide](https://docs.nvidia.com/grid/9.0/grid-vgpu-user-guide/index.html#installing-configuring-x11vnc-on-linux-server). Now we install x11vnc and set it up so we can see our monitor while xfce is running and we are capable of interacting with steam.

```
nvidia-xconfig --query-gpu-info
```

Example output:

```
...
GPU #0:
  Name      : GeForce GTX 1060 6GB
  UUID      : ########################################
  PCI BusID : PCI:1:0:0
...
```

It's the last line from this output what we want. Next, edit /etc/X11/xorg.conf:

```
vi /etc/X11/xorg.conf
```

Find the section "Device" and add the line:

```
...
Section "Device"
    Identifier "Device0"
    Driver "nvidia"
    VendorName "NVIDIA Corporation"
    BusID "YOURBUSID" # <-- add this line 
    Option "nopowerconnectorcheck" # <-- add this line 
    Option "ExactModeTimingsDVI" # <-- add this line 
EndSection
...
```

Also, find the section "Screen" and add this line:

```
...
    Option         "AllowEmptyInitialConfiguration""True" # <-- This line
    Option         "ConnectedMonitor""DFP" # <-- This line
    Option         "UseDisplayDevice""DFP-2" # <-- This line
...
```

Now we save the file and test if it's working:

```
startxfce4
```

If it worked, you will get some warnings, but xfce will keep running. Press Ctrl+C to cancell. Now let's install vnc server and expose the container port 5900.

To install x11vnc, run on the container:

```
pacman -S --noconfirm x11vnc
```

Following, run this on the *host*:

```
sudo lxc config device add $CONTAINER vnc5900 proxy listen=tcp:0.0.0.0:5900 connect=tcp:127.0.0.1:5900
```

#TODO test if x11vnc + startxfce4 is working
#TODO mount already existing steam library into the users homefolder

## Return from whence you came!

I hope this time I can do it all right, I tried several ways of doing this. First I tried to use [sway and wayvnc](https://not.just-paranoid.net/steam-streaming-on-a-headless-linux-machine-with-wayland/), without success. Secondly, I tried [headless X11](https://steamcommunity.com/sharedfiles/filedetails/?id=680514371), which didn't work also. But no effort is in vain. In the process of trying to make this work, I learned that Steam cannot get input from controllers while streaming from wayland, also that X11 won't work on a headless server without a monitor. But, after reading about accelerated remote desktops on linux, I saw about TurboVNC and VirtualGL. This promise here is that we can have such GPU acceleration under X11, as well as a desktop without a monitor. As Steam seems to use OpenGL for streaming the desktop independent if the desktop is using the GPU or not. So I decided to try TurboVNC + X11 to see if I can finally get a headless Steam streaming server running under LXD.

Oh, and the title of this section is all about returning to X11, even if Wayland is becoming standard lately. This happens because right now we are still in transition and Steam, as many other software, is still adapting to support the new graphical environment. So let's return to whence we came!

## The (final?) battle for the Steam streaming server!

As always, I will pin some environment variables so I can easily change settings in the future:

```
export CONTAINER=steamplay2
export IMAGE=fedora/35/amd64
export IMAGE_SERVER=images
export USERNAME=marcocspc
export HOMEINCONTAINER=/home/marcocspc
export NVIDIADRIVER_URL=https://us.download.nvidia.com/XFree86/Linux-x86_64/470.74/NVIDIA-Linux-x86_64-470.74.run
export NVIDIAINSTALLER=$(basename $NVIDIADRIVER_URL)
export TURBOVNC_URL="https://downloads.sourceforge.net/project/turbovnc/2.2.6/turbovnc-2.2.6.x86_64.rpm?ts=gAAAAABhgWwWlLTyekYm2oaCxilqf-h_X4I0v2zA3G1ThPT3Fdr2eps-ZZXAn2p7DPkVpC90ueBuB_3jtVYIHbnFRtjyBwszyA%3D%3D&r=https%3A%2F%2Fsourceforge.net%2Fprojects%2Fturbovnc%2Ffiles%2F2.2.6%2Fturbovnc-2.2.6.x86_64.rpm%2Fdownload"
export TURBOVNCINSTALLER=turbovnc-2.2.6.x86_64.rpm
export PROXYDEVICEVNCPROTO=tcp
export PROXYDEVICEVNCPORT=5900
export PROXYDEVICEVNC=vnc
export PROXYDEVICESTEAM1PROTO=tcp
export PROXYDEVICESTEAM1PORT=27036
export PROXYDEVICESTEAM1=steam1$PROXYDEVICESTEAM1PORT
export PROXYDEVICESTEAM2PROTO=$PROXYDEVICESTEAM1PROTO
export PROXYDEVICESTEAM2PORT=27037
export PROXYDEVICESTEAM2=steam2$PROXYDEVICESTEAM2PORT
export PROXYDEVICESTEAM3PROTO=udp
export PROXYDEVICESTEAM3PORT=27031
export PROXYDEVICESTEAM3=steam1$PROXYDEVICESTEAM3PORT
export PROXYDEVICESTEAM4PROTO=$PROXYDEVICESTEAM3PROTO
export PROXYDEVICESTEAM4PORT=27036
export PROXYDEVICESTEAM4=steam1$PROXYDEVICESTEAM4PORT
export MYTIMEZONE="America/Fortaleza"
```

Now let's start a new container:

```
sudo lxc stop $CONTAINER && sudo lxc rm $CONTAINER
sudo lxc launch $IMAGE_SERVER:$IMAGE $CONTAINER
```

Then it is a good practice to update all packages inside the container:

```
sudo lxc exec $CONTAINER -- dnf -y update
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

Also add gpu to the container and give permissions to use it:

```
sudo lxc config device add $CONTAINER mygpu gpu
var=$(cat << EOF 
lxc.cgroup.devices.allow = c 226:* rwm
EOF
)
sudo lxc config set $CONTAINER raw.lxc "$var"
```

Start the container again:

```
sudo lxc start $CONTAINER
```

Get the driver in the container (answer OK and Yes to everything):

```
sudo lxc exec $CONTAINER -- bash -c "cd ~ && mkdir downloads"
sudo lxc exec $CONTAINER -- bash -c "cd downloads && dnf install aria2 -y && aria2c -x 16 -s 16 $NVIDIADRIVER_URL && chmod +x $NVIDIAINSTALLER && ./$NVIDIAINSTALLER --no-kernel-module"
```

After the installation is done, you may type this to check the driver version:

```
sudo lxc exec $CONTAINER -- nvidia-smi
...
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 460.32.03    Driver Version: 460.32.03    CUDA Version: 11.2     |
|-------------------------------+----------------------+----------------------+
...
```

Install TurboVNC and Steam:

```
sudo lxc exec $CONTAINER -- bash -c "mkdir -p downloads && cd downloads && aria2c -x 16 -s 16 $TURBOVNC_URL && dnf install $TURBOVNCINSTALLER" 
sudo lxc exec $CONTAINER -- dnf install -y fedora-workstation-repositories
sudo lxc exec $CONTAINER -- dnf install VirtualGL steam perl xorg-x11-xauth xkbcomp -y --enablerepo=rpmfusion-nonfree-steam
```

### Set up TurboVNC

We will be following these steps:
1- Install a desktop environment
2- Create our user
3- Set up Google Authenticator to login on our server (this is optional, but I will do here because VNC is not *that* secure)
4- Set up our desktop environment
5- Create VNC service so it automatically launches when we start our container
6- Reboot the container and test if everything is working

Let's install Mate Desktop:

```
sudo lxc exec $CONTAINER -- bash -c "dnf group install -y mate-desktop-environment"
```

Create our user:

```
sudo lxc exec $CONTAINER -- useradd "$USERNAME" -m
sudo lxc exec $CONTAINER -- passwd "$USERNAME"
```

Set up Google Authenticator to login on our server:

```
sudo lxc exec $CONTAINER -- dnf install -y pam_oath oathtool xorg-x11-twm turbojpeg
var=$(cat << EOF 
#%PAM-1.0
auth requisite pam_oath.so usersfile=/etc/users.oath
account include system-auth
password include system-auth
session include system-auth
EOF
)
sudo lxc exec $CONTAINER -- bash -c "echo '$var' >> /etc/pam.d/turbovnc"
sudo lxc exec $CONTAINER -- chown root:root /etc/pam.d/turbovnc
sudo lxc exec $CONTAINER -- chmod 644 /etc/pam.d/turbovnc
```

Generate a secret key for your user:

```
key=$(head -10 /dev/urandom | md5sum | cut -b 1-30)
sudo lxc exec $CONTAINER -- bash -c "echo 'HOTP/T30 $USERNAME - $key' >> /etc/users.oath"
sudo lxc exec $CONTAINER -- chmod u+s /opt/TurboVNC/bin/Xvnc
```

Get the Base32 version of your key:

```
sudo lxc exec $CONTAINER -- oathtool --totp -v $key | grep Base32
```

With this key in hand, create a new account on your Google authenticator app by using manual entry. Every time you login to your VNC server, use the code provided by the google authenticator as password.

Set the timezone:

```
sudo lxc exec $CONTAINER -- timedatectl set-timezone $MYTIMEZONE
```

Create startup script to launch mate desktop when you login:

```
sudo lxc exec $CONTAINER -- bash -c "echo 'permitted-security-types = TLSPlain, X509Plain' >> /etc/turbovncserver-security.conf "
sudo lxc exec $CONTAINER -- mkdir -p /home/$USERNAME/.vnc 
sudo lxc exec $CONTAINER -- mkdir -p /home/$USERNAME/.tmp
sudo lxc exec $CONTAINER -- touch /home/$USERNAME/.vnc/xstartup.turbovnc
sudo lxc exec $CONTAINER -- cp /home/$USERNAME/.vnc/xstartup.turbovnc /home/$USERNAME/.vnc/xstartup.turbovnc.bak
var=$(cat << EOF 
#!/bin/sh

unset SESSION_MANAGER
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
XDG_SESSION_TYPE=x11;  export XDG_SESSION_TYPE
XDG_RUNTIME_DIR=/home/$USERNAME/.tmp; export XDG_RUNTIME_DIR
mate-session

EOF
)
sudo lxc exec $CONTAINER -- bash -c "echo '$var' > /home/$USERNAME/.vnc/xstartup.turbovnc"
sudo lxc exec $CONTAINER -- chown -R $USERNAME:$USERNAME /home/$USERNAME/.vnc
sudo lxc exec $CONTAINER -- chown -R $USERNAME:$USERNAME /home/$USERNAME/.tmp
```

Psst: you can also replace the entire xstartup.turbovnc content with just 'steam'. This will make just steam open when you boot the container ;). Do this: `sudo lxc exec $CONTAINER -- bash -c "echo 'steam' > /home/$USERNAME/.vnc/xstartup.turbovnc"`

Add a proxy device so we can reach the vnc server and steam remote play. Streaming uses UDP ports 27031 and 27036 and TCP ports 27036 and 27037:

```
x=0 ; while (( $x <= 10 )) ; do sudo lxc config device add $CONTAINER "$PROXYDEVICEVNC$(( $x + 5900 ))" proxy listen="$PROXYDEVICEVNCPROTO:0.0.0.0:$(( $x + $PROXYDEVICEVNCPORT ))" connect="$PROXYDEVICEVNCPROTO:127.0.0.1:$(( $x + $PROXYDEVICEVNCPORT))" ; x=$(( $x + 1)); done
sudo lxc config device add $CONTAINER $PROXYDEVICEVNC proxy listen=$PROXYDEVICEVNCPROTO:0.0.0.0:$PROXYDEVICEVNCPORT connect=$PROXYDEVICEVNCPROTO:127.0.0.1:$PROXYDEVICEVNCPORT
sudo lxc config device add $CONTAINER $PROXYDEVICESTEAM1 proxy listen=PROXYDEVICESTEAM1PROTO:0.0.0.0:$PROXYDEVICESTEAM1PORT connect=$PROXYDEVICESTEAM1PROTO:127.0.0.1:$PROXYDEVICESTEAM1PORT
sudo lxc config device add $CONTAINER $PROXYDEVICESTEAM2 proxy listen=$PROXYDEVICESTEAM2PROTO:0.0.0.0:$PROXYDEVICESTEAM2PORT connect=$PROXYDEVICESTEAM2PROTO:127.0.0.1:$PROXYDEVICESTEAM2PORT
sudo lxc config device add $CONTAINER $PROXYDEVICESTEAM3 proxy listen=$PROXYDEVICESTEAM3PROTO:0.0.0.0:$PROXYDEVICESTEAM3PORT connect=$PROXYDEVICESTEAM3PROTO:127.0.0.1:$PROXYDEVICESTEAM3PORT
sudo lxc config device add $CONTAINER $PROXYDEVICESTEAM4 proxy listen=$PROXYDEVICESTEAM4PROTO:0.0.0.0:$PROXYDEVICESTEAM4PORT connect=$PROXYDEVICESTEAM4PROTO:127.0.0.1:$PROXYDEVICESTEAM4PORT
```

Turn turbovnc into a service:

```
sudo lxc exec $CONTAINER -- bash -c "cat <<EOF > /etc/systemd/system/turbovnc.service
[Unit]
Description=TurboVNC Desktop
After=sway.service

[Service]
Type=forking
User=$USERNAME
Group=$USERNAME
Environment=XDG_RUNTIME_DIR=/home/$USERNAME/.tmp
Environment=DISPLAY=0:1
Environment=XDG_SESSION_TYPE=tty
Environment=XDG_SESSION_CLASS=user
Environment=XDG_SESSION_ID=c1
Environment=XDG_DATA_DIRS=/home/$USERNAME/.local/share/flatpak/exports/share:/root/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:/usr/local/share:/usr/share
ExecStart=/opt/TurboVNC/bin/vncserver -vgl 
ExecStop=/opt/TurboVNC/bin/vncserver -kill :1

[Install]
WantedBy=multi-user.target
EOF"
```

Enable the service and restart the container:

```
sudo lxc exec $CONTAINER -- systemctl enable turbovnc
sudo lxc restart $CONTAINER
```

When connecting using your preferred VNC client, use your server IP, port 5901. Insert $USERNAME as user and your google authentication code as password. Try it out!

### Almost there!

Now we only need to:
1- Install pulseaudio so we can have audio output
2- Set steam to start when container boots
3- Set security settings to make the container able to run proton games
4- Disable monitor shutdown
5- Reboot the container, login into steam and PLAY!

Install pulseaudio:

```
sudo lxc exec $CONTAINER -- dnf remove -y pipewire pipewire-pulseaudio
sudo lxc exec $CONTAINER -- dnf install -y pulseaudio pulseaudio-utils boost-program-options git meson make automake gcc gcc-c++ kernel-devel cmake pulseaudio-libs-devel boost-devel
sudo lxc exec $CONTAINER -- bash -c "git clone https://github.com/cdemoulins/pamixer.git && cd pamixer && meson setup build && meson compile -C build && meson install -C build && cd .. && rm -rf pamixer"
```

Now we set steam and pulseaudio to start with the container:

```
sudo lxc exec $CONTAINER -- mkdir -p /home/$USERNAME/.config/autostart/
sudo lxc exec $CONTAINER -- cp /usr/share/applications/steam.desktop /home/$USERNAME/.config/autostart/
sudo lxc exec $CONTAINER -- bash -c "cat <<EOF > /home/$USERNAME/.config/autostart/auto-start-pulseaudio.sh
#!/bin/sh
export XDG_RUNTIME_DIR=/home/$USERNAME/.tmp
export DISPLAY=0:1
export XDG_SESSION_TYPE=tty
export XDG_SESSION_CLASS=user
export XDG_SESSION_ID=c1
export XDG_DATA_DIRS=/home/$USERNAME/.local/share/flatpak/exports/share:/root/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:/usr/local/share:/usr/share
export $(dbus-launch)
pulseaudio
EOF"
sudo lxc exec $CONTAINER -- chown -R $USERNAME:$USERNAME /home/$USERNAME/.config/autostart/
sudo lxc exec $CONTAINER -- chmod -R 755 /home/$USERNAME/.config/autostart/
sudo lxc exec $CONTAINER -- bash -c "echo '/home/$USERNAME/.config/autostart/auto-start-pulseaudio.sh' >> /home/$USERNAME/.vnc/xstartup.turbovnc"
```

Prevent pulseaudio from exiting due to idleness:

```
sudo lxc exec $CONTAINER -- sed -i "s/load-module module-suspend-on-idle/#load-module module-suspend-on-idle/"/etc/pulse/default.pa"
sudo lxc exec $CONTAINER -- bash -c "echo 'exit-idle-time = -1' >> /etc/pulse/daemon.conf"
```

Now you should reboot the container and login into steam. To to that first you need to login into your vnc session. Use your favorite client, but make sure to use your desktop/server IP and port 5901. Remember that your password is the numbers from google authenticator. 

Remember to pair your steam link device and you're good to go. Install/setup your games and emulators and have fun!

## Trying with sunshine server

Constants:

```
export CONTAINER=steamplay3
export IMAGE=fedora/35/amd64
export IMAGE_SERVER=images
export USERNAME=marcocspc
export HOMEINCONTAINER=/home/marcocspc
export NVIDIADRIVER_URL=https://us.download.nvidia.com/XFree86/Linux-x86_64/470.74/NVIDIA-Linux-x86_64-470.74.run
export NVIDIAINSTALLER=$(basename $NVIDIADRIVER_URL)
export PROXYDEVICEVNCPROTO=tcp
export PROXYDEVICEVNCPORT=5900
export PROXYDEVICEVNC=vnc
export PROXYDEVICESTEAM1PROTO=tcp
export PROXYDEVICESTEAM1PORT=27036
export PROXYDEVICESTEAM1=steam1$PROXYDEVICESTEAM1PORT
export PROXYDEVICESTEAM2PROTO=$PROXYDEVICESTEAM1PROTO
export PROXYDEVICESTEAM2PORT=27037
export PROXYDEVICESTEAM2=steam2$PROXYDEVICESTEAM2PORT
export PROXYDEVICESTEAM3PROTO=udp
export PROXYDEVICESTEAM3PORT=27031
export PROXYDEVICESTEAM3=steam1$PROXYDEVICESTEAM3PORT
export PROXYDEVICESTEAM4PROTO=$PROXYDEVICESTEAM3PROTO
export PROXYDEVICESTEAM4PORT=27036
export PROXYDEVICESTEAM4=steam1$PROXYDEVICESTEAM4PORT
export MYTIMEZONE="America/Fortaleza"
```

Now let's start a new container:

```
sudo lxc stop $CONTAINER && sudo lxc rm $CONTAINER
sudo lxc launch $IMAGE_SERVER:$IMAGE $CONTAINER
```

Then it is a good practice to update all packages inside the container:

```
sudo lxc exec $CONTAINER -- dnf -y update
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

Also add gpu to the container and give permissions to use it:

```
sudo lxc config device add $CONTAINER mygpu gpu
```

Start the container again:

```
sudo lxc start $CONTAINER
```

Get the driver in the container (answer OK and Yes to everything):

```
sudo lxc exec $CONTAINER -- bash -c "cd ~ && mkdir downloads"
sudo lxc exec $CONTAINER -- bash -c "cd downloads && dnf install aria2 -y && aria2c -x 16 -s 16 $NVIDIADRIVER_URL && chmod +x $NVIDIAINSTALLER && ./$NVIDIAINSTALLER --no-kernel-module"
```

After the installation is done, you may type this to check the driver version:

```
sudo lxc exec $CONTAINER -- nvidia-smi
...
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 460.32.03    Driver Version: 460.32.03    CUDA Version: 11.2     |
|-------------------------------+----------------------+----------------------+
...
```

Install xorg-x11-drv-dummy. This allows the container to have monitor output without one:

```
sudo lxc exec $CONTAINER -- dnf install -y xorg-x11-drv-dummy
```

Install Xfce Desktop and Tiger VNC Server:

```
sudo lxc exec $CONTAINER -- dnf install -y tigervnc-server @xfce-desktop-environment
```

Install steam:

```
sudo lxc exec $CONTAINER -- dnf install -y fedora-workstation-repositories
sudo lxc exec $CONTAINER -- dnf install -y steam --enablerepo=rpmfusion-nonfree-steam
```

Add an user to play the games. Here I use the username from that environment variable:

```
sudo lxc exec $CONTAINER -- useradd -m -g users -G video -s /bin/bash $USERNAME
sudo lxc exec $CONTAINER -- passwd "$USERNAME"
``` 

Add proxy devices so we can access the container:

```
x=0 ; while (( $x <= 10 )) ; do sudo lxc config device add $CONTAINER "$PROXYDEVICEVNC$(( $x + 5900 ))" proxy listen="$PROXYDEVICEVNCPROTO:0.0.0.0:$(( $x + $PROXYDEVICEVNCPORT ))" connect="$PROXYDEVICEVNCPROTO:127.0.0.1:$(( $x + $PROXYDEVICEVNCPORT))" ; x=$(( $x + 1)); done
sudo lxc config device add $CONTAINER $PROXYDEVICEVNC proxy listen=$PROXYDEVICEVNCPROTO:0.0.0.0:$PROXYDEVICEVNCPORT connect=$PROXYDEVICEVNCPROTO:127.0.0.1:$PROXYDEVICEVNCPORT
sudo lxc config device add $CONTAINER $PROXYDEVICESTEAM1 proxy listen=$PROXYDEVICESTEAM1PROTO:0.0.0.0:$PROXYDEVICESTEAM1PORT connect=$PROXYDEVICESTEAM1PROTO:127.0.0.1:$PROXYDEVICESTEAM1PORT
sudo lxc config device add $CONTAINER $PROXYDEVICESTEAM2 proxy listen=$PROXYDEVICESTEAM2PROTO:0.0.0.0:$PROXYDEVICESTEAM2PORT connect=$PROXYDEVICESTEAM2PROTO:127.0.0.1:$PROXYDEVICESTEAM2PORT
sudo lxc config device add $CONTAINER $PROXYDEVICESTEAM3 proxy listen=$PROXYDEVICESTEAM3PROTO:0.0.0.0:$PROXYDEVICESTEAM3PORT connect=$PROXYDEVICESTEAM3PROTO:127.0.0.1:$PROXYDEVICESTEAM3PORT
sudo lxc config device add $CONTAINER $PROXYDEVICESTEAM4 proxy listen=$PROXYDEVICESTEAM4PROTO:0.0.0.0:$PROXYDEVICESTEAM4PORT connect=$PROXYDEVICESTEAM4PROTO:127.0.0.1:$PROXYDEVICESTEAM4PORT
```

Configure tigervnc:

```
sudo lxc exec $CONTAINER -- mkdir -p /home/$USERNAME/.tmp
sudo lxc exec $CONTAINER -- cp /home/$USERNAME/.vnc/xstartup /home/$USERNAME/.vnc/xstartup.bak
var=$(cat << EOF 
#!/bin/sh

unset SESSION_MANAGER
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
XDG_SESSION_TYPE=x11;  export XDG_SESSION_TYPE
XDG_RUNTIME_DIR=/home/$USERNAME/.tmp; export XDG_RUNTIME_DIR
xfce4-session

EOF
)
sudo lxc exec $CONTAINER -- bash -c "echo '$var'> /home/$USERNAME/.vnc/xstartup"
sudo lxc exec $CONTAINER -- chown -R $USERNAME:users /home/$USERNAME/.vnc
sudo lxc exec $CONTAINER -- chown -R $USERNAME:users /home/$USERNAME/.tmp
```

Allow steam to run protonge containers:

```
sudo lxc config set $CONTAINER security.nesting true
```

Restart the container:

```
sudo lxc restart $CONTAINER
```

## Trying with sway + steam pipewire

```
export CONTAINER=steamplay4
export IMAGE=fedora/35/amd64
export IMAGE_SERVER=images
export USERNAME=marcocspc
export NVIDIADRIVER_URL=https://us.download.nvidia.com/XFree86/Linux-x86_64/470.74/NVIDIA-Linux-x86_64-470.74.run
export NVIDIAINSTALLER=$(basename $NVIDIADRIVER_URL)
export PROXYDEVICEVNCPROTO=tcp
export PROXYDEVICEVNCPORT=5900
export PROXYDEVICEVNC=vnc$PROXYDEVICEVNCPORT
export PROXYDEVICESTEAM1PROTO=tcp
export PROXYDEVICESTEAM1PORT=27036
export PROXYDEVICESTEAM1=steam1$PROXYDEVICESTEAM1PORT
export PROXYDEVICESTEAM2PROTO=$PROXYDEVICESTEAM1PROTO
export PROXYDEVICESTEAM2PORT=27037
export PROXYDEVICESTEAM2=steam2$PROXYDEVICESTEAM2PORT
export PROXYDEVICESTEAM3PROTO=udp
export PROXYDEVICESTEAM3PORT=27031
export PROXYDEVICESTEAM3=steam1$PROXYDEVICESTEAM3PORT
export PROXYDEVICESTEAM4PROTO=$PROXYDEVICESTEAM3PROTO
export PROXYDEVICESTEAM4PORT=27036
export PROXYDEVICESTEAM4=steam1$PROXYDEVICESTEAM4PORT
```

Now let's start a new container:

```
sudo lxc stop $CONTAINER && sudo lxc rm $CONTAINER
sudo lxc launch $IMAGE_SERVER:$IMAGE $CONTAINER
```

Then it is a good practice to update all packages inside the container (get a root terminal first on it):

```
sudo lxc exec $CONTAINER -- dnf -y update
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

Also add gpu to the container and give permissions to use it:

```
sudo lxc config device add $CONTAINER mygpu gpu
var=$(cat << EOF 
lxc.cgroup.devices.allow = c 226:* rwm
EOF
)
sudo lxc config set $CONTAINER raw.lxc "$var"
```

Start the container again:

```
sudo lxc start $CONTAINER
```

Get the driver in the container (answer OK and Yes to everything):

```
sudo lxc exec $CONTAINER -- bash -c "cd ~ && mkdir downloads"
sudo lxc exec $CONTAINER -- bash -c "cd downloads && dnf install aria2 -y && aria2c -x 16 -s 16 $NVIDIADRIVER_URL && chmod +x $NVIDIAINSTALLER && ./$NVIDIAINSTALLER --no-kernel-module"
```

After the installation is done, you may type this to check the driver version:

```
sudo lxc exec $CONTAINER -- nvidia-smi
...
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 460.32.03    Driver Version: 460.32.03    CUDA Version: 11.2     |
|-------------------------------+----------------------+----------------------+
...
```

Now we install sway, wayvnc and steam:

```
sudo lxc exec $CONTAINER -- dnf install -y fedora-workstation-repositories
sudo lxc exec $CONTAINER -- dnf install sway wayvnc steam -y --enablerepo=rpmfusion-nonfree-steam
```

Prevent pulse audio from spawning:

```
sudo lxc exec $CONTAINER -- sed -i "s/; autospawn = no/autospawn = no/" /etc/pulse/client.conf
```


Before we proceed, we should do some tests to see if everything is okay. Add your user and exit:

```
sudo lxc exec $CONTAINER -- useradd "$USERNAME" -m
sudo lxc exec $CONTAINER -- passwd "$USERNAME"
```

Add a proxy device so we can reach the vnc server and steam remote play. Streaming uses UDP ports 27031 and 27036 and TCP ports 27036 and 27037:

```
sudo lxc config device add $CONTAINER $PROXYDEVICEVNC proxy listen=$PROXYDEVICEVNCPROTO:0.0.0.0:$PROXYDEVICEVNCPORT connect=$PROXYDEVICEVNCPROTO:127.0.0.1:$PROXYDEVICEVNCPORT
sudo lxc config device add $CONTAINER $PROXYDEVICESTEAM1 proxy listen=PROXYDEVICESTEAM1PROTO:0.0.0.0:$PROXYDEVICESTEAM1PORT connect=$PROXYDEVICESTEAM1PROTO:127.0.0.1:$PROXYDEVICESTEAM1PORT
sudo lxc config device add $CONTAINER $PROXYDEVICESTEAM2 proxy listen=$PROXYDEVICESTEAM2PROTO:0.0.0.0:$PROXYDEVICESTEAM2PORT connect=$PROXYDEVICESTEAM2PROTO:127.0.0.1:$PROXYDEVICESTEAM2PORT
sudo lxc config device add $CONTAINER $PROXYDEVICESTEAM3 proxy listen=$PROXYDEVICESTEAM3PROTO:0.0.0.0:$PROXYDEVICESTEAM3PORT connect=$PROXYDEVICESTEAM3PROTO:127.0.0.1:$PROXYDEVICESTEAM3PORT
sudo lxc config device add $CONTAINER $PROXYDEVICESTEAM4 proxy listen=$PROXYDEVICESTEAM4PROTO:0.0.0.0:$PROXYDEVICESTEAM4PORT connect=$PROXYDEVICESTEAM4PROTO:127.0.0.1:$PROXYDEVICESTEAM4PORT
```

Turning sway into a system service:

```
sudo lxc exec $CONTAINER -- bash -c "cat <<EOF > /etc/systemd/system/sway.service
[Unit]
Description=Sway Desktop
After=sway.service

[Service]
User=$USERNAME
Group=$USERNAME
Environment=XDG_SESSION_TYPE=wayland
Environment=WAYLAND_DISPLAY=wayland-1
Environment=XDG_RUNTIME_DIR=/home/$USERNAME/.tmp
Environment=WLR_BACKENDS=headless
Environment=WLR_LIBINPUT_NO_DEVICES=1
Type=simple
ExecStart=/usr/bin/sway --my-next-gpu-wont-be-nvidia

[Install]
WantedBy=multi-user.target
EOF"
```

Now for wayvnc:

```
sudo lxc exec $CONTAINER -- bash -c "cat <<EOF > /etc/systemd/system/wayvnc.service
[Unit]
Description=Wayvnc Server
After=sway.service

[Service]
User=$USERNAME
Group=$USERNAME
Environment=XDG_SESSION_TYPE=wayland
Environment=WAYLAND_DISPLAY=wayland-1
Environment=XDG_RUNTIME_DIR=/home/$USERNAME/.tmp
Environment=WLR_BACKENDS=headless
Environment=WLR_LIBINPUT_NO_DEVICES=1
Type=simple
ExecStart=/usr/bin/wayvnc

[Install]
WantedBy=multi-user.target
EOF"
```

Now enable and start both services (don't forget do test them):
XDG_SESSION_TYPE=wayland WAYLAND_DISPLAY=wayland-1 XDG_RUNTIME_DIR=/home/$USERNAME/.tmp WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 pipewire

```
sudo lxc exec $CONTAINER -- systemctl enable sway
sudo lxc exec $CONTAINER -- systemctl enable wayvnc
sudo lxc exec $CONTAINER -- systemctl start sway
sudo lxc exec $CONTAINER -- systemctl start wayvnc
```

Give access to nesting (needed to run proton steam games):

```
sudo lxc config set $CONTAINER security.nesting true
```

Set sway startup with steam:

```
sudo lxc exec $CONTAINER -- mkdir -p /home/$USERNAME/.tmp
sudo lxc exec $CONTAINER -- mkdir -p /home/$USERNAME/.config/sway
sudo lxc exec $CONTAINER -- bash -c "cat <<EOF > /home/$USERNAME/.config/sway/config
exec_always --no-startup-id pipewire
exec_always /usr/bin/steam -pipewire
output HEADLESS-1 resolution 1280x720
EOF"
sudo lxc exec $CONTAINER -- sudo chown -R $USERNAME:$USERNAME /home/$USERNAME/.tmp
sudo lxc exec $CONTAINER -- sudo chown -R $USERNAME:$USERNAME /home/$USERNAME/.config
```

Restart the container:

```
sudo lxc restart $CONTAINER
```

## Trying with sway, wayvnc and sunshine server 

```
export CONTAINER=steamplay5
export IMAGE=fedora/35/amd64
export IMAGE_SERVER=images
export USERNAME=marcocspc
export NVIDIADRIVER_URL=https://us.download.nvidia.com/XFree86/Linux-x86_64/470.74/NVIDIA-Linux-x86_64-470.74.run
export NVIDIAINSTALLER=$(basename $NVIDIADRIVER_URL)
export PROXYDEVICEVNCPROTO=tcp
export PROXYDEVICEVNCPORT=5900
export PROXYDEVICEVNC=vnc$PROXYDEVICEVNCPORT
export SUNSHINE_SERVER_PORT_1=47989
export SUNSHINE_SERVER_PORT_2=47990
export PROXYDEVICESUNSHINE1=sunshine$SUNSHINE_SERVER_PORT_1
export PROXYDEVICESUNSHINE2=sunshine$SUNSHINE_SERVER_PORT_2
```

Now let's start a new container:

```
sudo lxc stop $CONTAINER && sudo lxc rm $CONTAINER
sudo lxc launch $IMAGE_SERVER:$IMAGE $CONTAINER
```

Then it is a good practice to update all packages inside the container (get a root terminal first on it):

```
sudo lxc exec $CONTAINER -- dnf -y update
```

The guide I was reading did not using containers. So I had to first get nvidia drivers working inside lxd. To do that I needed to install the same drivers of my host inside the container. But I didn't remember the version I installed, so I had to run this command to discover it:

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

Also add gpu to the container and give permissions to use it:

```
sudo lxc config device add $CONTAINER mygpu gpu
var=$(cat << EOF 
lxc.cgroup.devices.allow = c 226:* rwm
*EOF
)
sudo lxc config set $CONTAINER raw.lxc "$var"
```

Start the container again:

```
sudo lxc start $CONTAINER
```

Get the driver in the container (answer OK and Yes to everything):

```
sudo lxc exec $CONTAINER -- bash -c "cd ~ && mkdir downloads"
sudo lxc exec $CONTAINER -- bash -c "cd downloads && dnf install aria2 -y && aria2c -x 16 -s 16 $NVIDIADRIVER_URL && chmod +x $NVIDIAINSTALLER && ./$NVIDIAINSTALLER --no-kernel-module"
```

After the installation is done, you may type this to check the driver version:

```
sudo lxc exec $CONTAINER -- nvidia-smi
...
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 460.32.03    Driver Version: 460.32.03    CUDA Version: 11.2     |
|-------------------------------+----------------------+----------------------+
...
```

Now we install steam, sway and wayvnc:

```
sudo lxc exec $CONTAINER -- dnf install -y fedora-workstation-repositories
sudo lxc exec $CONTAINER -- dnf install sway wayvnc steam -y --enablerepo=rpmfusion-nonfree-steam
```

Add your user and set a password:

```
sudo lxc exec $CONTAINER -- useradd "$USERNAME" -m
sudo lxc exec $CONTAINER -- passwd "$USERNAME"
```

Add a proxy device so we can reach the vnc server and steam remote play. Streaming uses UDP ports 27031 and 27036 and TCP ports 27036 and 27037:

```
sudo lxc config device add $CONTAINER $PROXYDEVICEVNC proxy listen=$PROXYDEVICEVNCPROTO:0.0.0.0:$PROXYDEVICEVNCPORT connect=$PROXYDEVICEVNCPROTO:127.0.0.1:$PROXYDEVICEVNCPORT
sudo lxc config device add $CONTAINER "$PROXYDEVICESUNSHINE1"tcp proxy listen=tcp:0.0.0.0:$SUNSHINE_SERVER_PORT_1 connect=tcp:127.0.0.1:$SUNSHINE_SERVER_PORT_1
sudo lxc config device add $CONTAINER "$PROXYDEVICESUNSHINE1"udp proxy listen=udp:0.0.0.0:$SUNSHINE_SERVER_PORT_1 connect=udp:127.0.0.1:$SUNSHINE_SERVER_PORT_1
sudo lxc config device add $CONTAINER "$PROXYDEVICESUNSHINE2"tcp proxy listen=tcp:0.0.0.0:$SUNSHINE_SERVER_PORT_2 connect=tcp:127.0.0.1:$SUNSHINE_SERVER_PORT_2
sudo lxc config device add $CONTAINER "$PROXYDEVICESUNSHINE2"udp proxy listen=udp:0.0.0.0:$SUNSHINE_SERVER_PORT_2 connect=udp:127.0.0.1:$SUNSHINE_SERVER_PORT_2
```

Turning sway into a system service:

```
sudo lxc exec $CONTAINER -- bash -c "cat <<EOF > /etc/systemd/system/sway.service
[Unit]
Description=Sway Desktop
After=sway.service

[Service]
ExecStartPre=/bin/sleep 30
User=$USERNAME
Group=$USERNAME
Environment=XDG_SESSION_TYPE=wayland
Environment=WAYLAND_DISPLAY=wayland-1
Environment=XDG_RUNTIME_DIR=/home/$USERNAME/.tmp
Environment=WLR_BACKENDS=headless
Environment=WLR_LIBINPUT_NO_DEVICES=1
Type=simple
ExecStart=/usr/bin/sway --my-next-gpu-wont-be-nvidia

[Install]
WantedBy=multi-user.target
EOF"
```

Now for wayvnc:

```
sudo lxc exec $CONTAINER -- bash -c "cat <<EOF > /etc/systemd/system/wayvnc.service
[Unit]
Description=Wayvnc Server
After=sway.service

[Service]
User=$USERNAME
Group=$USERNAME
Environment=XDG_SESSION_TYPE=wayland
Environment=WAYLAND_DISPLAY=wayland-1
Environment=XDG_RUNTIME_DIR=/home/$USERNAME/.tmp
Environment=WLR_BACKENDS=headless
Environment=WLR_LIBINPUT_NO_DEVICES=1
Type=simple
ExecStart=/usr/bin/wayvnc

[Install]
WantedBy=multi-user.target
EOF"
```

Now enable and start both services (don't forget do test them):

```
sudo lxc exec $CONTAINER -- systemctl enable sway
sudo lxc exec $CONTAINER -- systemctl enable wayvnc
sudo lxc exec $CONTAINER -- systemctl start sway
sudo lxc exec $CONTAINER -- systemctl start wayvnc
```

Give access to nesting (needed to run proton steam games):

```
sudo lxc config set $CONTAINER security.nesting true
```

To have audio on our stream (and even make some games run, since they won't if there is no audio output) we need to install pulseaudio. For some reason, Fedora 35 have some conflicts between pipewire and pulseaudio, so we remove the former and install the latter:

```
sudo lxc exec $CONTAINER -- dnf remove -y pipewire 
sudo lxc exec $CONTAINER -- dnf install -y pulseaudio pulseaudio-utils boost-program-options git meson make automake gcc gcc-c++ kernel-devel cmake pulseaudio-libs-devel
sudo lxc exec $CONTAINER -- bash -c "git clone https://github.com/cdemoulins/pamixer.git && cd pamixer && meson setup build && meson compile -C build && meson install -C build && cd .. && rm -rf pamixer"
```

Add a ~/.tmp directory, so we can use to be the XDG_RUNTIME_DIR (I tried using /tmp, but had some permissions issues):

```
sudo lxc exec $CONTAINER -- mkdir -p /home/$USERNAME/.tmp
sudo lxc exec $CONTAINER -- chown -R $USERNAME:$USERNAME /home/$USERNAME/.tmp
```

Install sunshine server dependencies:

```
sudo lxc exec $CONTAINER -- bash -c "dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-\$(rpm -E %fedora).noarch.rpm"
sudo lxc exec $CONTAINER -- dnf install -y openssl-devel ffmpeg-devel boost-devel boost-static opus-devel libevdev-devel libdrm-devel libcap-devel wayland-devel libXtst-devel libX11-devel libXrandr-devel libXfixes-devel libxcb-devel 
```

Download and build sunshine server:

```
sudo lxc exec $CONTAINER -- bash -c "git clone https://github.com/loki-47-6F-64/sunshine.git --recurse-submodules && cd sunshine && mkdir -p build && cd build && cmake -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++ .. && make -j \${nproc}"
```

Now we setup sunshine server. First, we need to add our user to the input group:

```
sudo lxc exec $CONTAINER -- usermod -a -G input $USERNAME
```

Create some udev rules:

```
sudo lxc exec $CONTAINER -- bash -c "echo 'KERNEL==\"uinput\", GROUP=\"input\", MODE=\"0660\"' > /etc/udev/rules.d/85-sunshine-input.rules"
```

Give sunshine to use KMS;

```
sudo lxc exec $CONTAINER -- setcap cap_sys_admin+p sunshine/build/sunshine
```

Add uinput to the container:

```
sudo lxc config device add $CONTAINER uinput unix-char source=/dev/uinput
```

Now you need to edit sunshine server configuration. The only thing I've changed was the resolution and fps settings. If you want to read everything and edit each setting, use the command below. If you want to use exactly the same settings as me, use the EOF command just after:

```
sudo lxc exec $CONTAINER -- vi sunshine/assets/sunshine.conf 
```

OR:

```
sudo lxc exec $CONTAINER -- bash -c "cat <<EOF >> sunshine/assets/sunshine.conf 

#### My Settings #####

fps = [10, 30, 60]
resolutions = [
    1280x720,
    1920x1080
]

EOF"
```

Now let's transfer sunshine to our user home and get permissions to run the app:

```
sudo lxc exec $CONTAINER -- chown -R $USERNAME:$USERNAME /root/sunshine
```



Set sway startup with pulseaudio, sunshine server and steam:

```
sudo lxc exec $CONTAINER -- mkdir -p /home/$USERNAME/.tmp
sudo lxc exec $CONTAINER -- mkdir -p /home/$USERNAME/.config/sway

sudo lxc exec $CONTAINER -- bash -c "cat <<EOF > /home/$USERNAME/.config/sway/config
exec_always pulseaudio --start
exec_always pamixer -u
exec_always pamixer --set-volume 90
exec_always /usr/bin/steam
exec_always /root/sunshine/build/sunshine
output HEADLESS-1 resolution 1280x720
EOF"

sudo lxc exec $CONTAINER -- chown -R $USERNAME:$USERNAME /home/$USERNAME/.config
sudo lxc exec $CONTAINER -- chown -R $USERNAME:$USERNAME /home/$USERNAME/.tmp
sudo lxc exec $CONTAINER -- chmod 777 /root
```

We also need to upgrade libglvnd using [this repo](https://github.com/NVIDIA/libglvnd) to avoid EGL ERRORS:

```
sudo lxc exec $CONTAINER -- dnf install libXext-devel libX11-devel meson ninja-build
sudo lxc exec $CONTAINER -- bash -c "git clone https://github.com/NVIDIA/libglvnd && cd libglvnd && meson builddir && ninja -C builddir && cd builddir && meson install"
```

Restart the container:

```
sudo lxc restart $CONTAINER
```
