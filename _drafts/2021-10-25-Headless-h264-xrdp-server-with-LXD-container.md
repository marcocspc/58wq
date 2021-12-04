---
layout: post
title:  "Headless h264 xrdp server with LXD container and NVidia Drivers"
date:  2021-10-25 20:58:18 -0300 
categories: english linux
---

# Headless h264 xrdp server with LXD container amd NVidia Drivers

Another adventure of mine: I wanted to free some space on my desk. It's a small one, so my desktop takes too much of it. I could move this pc to under the table, but there are a lot of cables and to organize things would take too much effort (yes, I am that kind of person). So what's the solution? All the way remote desktop! But there's a catch.

I've been looking for a remote desktop protocol that was able to use accelerated graphics to stream things using h264 protocol (or something like that). But xrdp and all sorts of vnc implementation didn't do that. Until I've found [this](https://github.com/neutrinolabs/xrdp/issues/1422) feature request and decided to try it out.

Let's go for another adventure!

## It's dangerous to go alone, use this:

We begin by creating a few environment variables to help with the following commands (and to be easier to adapt the commands to every context). 

```
export CONTAINER=marcocspcdesktop
export IMAGE=fedora/35/amd64
export IMAGE_SERVER=images
export USERNAME=marcocspc
export HOMEINCONTAINER=/home/marcocspc
export PROXYDEVICERDP=rdp3389
export PROXYDEVICERDPPORTHOST=3390
export PROXYDEVICERDPPORTCNT=3389
export NVIDIADRIVER_URL=https://us.download.nvidia.com/XFree86/Linux-x86_64/470.74/NVIDIA-Linux-x86_64-470.74.run
export NVIDIAINSTALLER=$(basename $NVIDIADRIVER_URL)
```

Now, we launch the container:

```
sudo lxc stop $CONTAINER ; sudo lxc rm $CONTAINER
sudo lxc launch $IMAGE_SERVER:$IMAGE $CONTAINER
```

## NVIDIA Drivers

I had to get nvidia drivers working inside lxc. To do that I needed to install the same drivers of my host inside the container. But I didn't remember the version I installed, so I had to run this command to discover it:

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
ls -l /dev/nvidia*
export CNT=$CONTAINER
for i in $(ls /dev/nvidia*); do sudo lxc config device add $CNT $(basename $i) disk source=$i path=$i ; done
sudo lxc config device add $CONTAINER mygpu gpu
```

Start the container again:

```
sudo lxc start $CONTAINER
```

Get the driver (answer Yes if the driver wants to override any config):

```
sudo lxc exec $CONTAINER -- bash -c "mkdir ~/downloads && cd downloads && dnf install aria2 -y && aria2c -x 16 -s 16 $NVIDIADRIVER_URL && chmod +x ./$NVIDIAINSTALLER && ./$NVIDIAINSTALLER --no-kernel-module"
```

## Fedora Gnome Desktop

We use Xfc4 desktop here, but feel free to apply the same principles to your dist of choice. We also install xrdp, since the hardware acceleration is given by xorgxrdp (which will be installed later).

```
sudo lxc exec $CONTAINER -- dnf groupinstall -y Xfce\ desktop
```

## H264 Hardware-Accelarated XRDP

Let's now install the hardware acceleration. To do this, first we need to install git and a few other dependencies:

```
sudo lxc exec $CONTAINER -- dnf install -y git patch gcc make autoconf libtool automake pkgconfig openssl-devel gettext file pam-devel libX11-devel libXfixes-devel libXrandr-devel libjpeg-devel fuse-devel flex bison gcc-c++ libxslt perl-libxml-perl xorg-x11-font-utils nasm xorg-x11-server-devel xrdp-devel mesa-* libdrm-devel libepoxy-devel
```

Now, let's now clone, build and install xrdp on the container:

```
sudo lxc exec $CONTAINER -- bash -c "git clone https://github.com/neutrinolabs/xrdp.git && cd xrdp && git checkout tags/v0.9.17"
sudo lxc exec $CONTAINER -- bash -c "cd xrdp && ./bootstrap && ./configure --enable-glamor  && make && make install"
```

Now, let's now clone, build and install xorgxrdp on the container:

```
sudo lxc exec $CONTAINER -- bash -c "git clone https://github.com/jsorg71/xorgxrdp/ --branch nvidia_hack --recursive"
sudo lxc exec $CONTAINER -- bash -c "cp -r /usr/include/libdrm/* xorgxrdp/"
sudo lxc exec $CONTAINER -- bash -c "for i in /usr/include/libdrm/* ln -s $i /usr/include/"
sudo lxc exec $CONTAINER -- bash -c "cd xorgxrdp && ./bootstrap && ./configure --enable-glamor --enable-rfxcodec --enable-mp3lame --enable-fdkaac --enable-opus --enable-pixman --enable-fuse --enable-jpeg --includedir=/usr/include/  && make && make install"
```

After the installation is done, we also need to make a few tweaks. First, get the PCI bus address of your video card:

```
sudo lxc exec $CONTAINER -- dnf install -y pciutils
sudo lxc exec $CONTAINER -- lspci | grep NVIDIA
```

Get the first two numbers of that ID. Like this [example](https://github.com/neutrinolabs/xrdp/issues/1029):

```
65:00.0 VGA compatible controller: NVIDIA Corporation GP104GL [Quadro P5000] (rev a1)
```

Here, the number you want is 65.

Then, convert that number to hexadecimal:

```
printf '%x\n' <NUMBER>
```

Edit /etc/X11/xrdp/xorg_nvidia.conf and, on line 38, replace the '2' with the number you got by running the command above.

```
sudo lxc exec $CONTAINER -- vi /etc/X11/xrdp/xorg_nvidia.conf
```

Also, edit /etc/xrdp/sesman.ini and change the line "param=xrdp/xorg.conf" to "param=xrdp/xorg_nvidia.conf":

```
sudo lxc exec $CONTAINER -- vi /etc/xrdp/sesman.ini
```

## Creating an user

Create the user and set the password for it:

```
sudo lxc exec $CONTAINER -- useradd "$USERNAME" -G wheel -m
sudo lxc exec $CONTAINER -- passwd "$USERNAME"
```

## Enabling RDP and exposing the container's port:

Enable xorg login on xrdp:

```
var=$(cat << EOF 
[Xorg]
name=Xorg
lib=libxup.so
username=ask
password=ask
ip=127.0.0.1
port=-1
code=20
EOF
)
sudo lxc exec $CONTAINER -- bash -c "echo '$var' >> /etc/xrdp/sesman.ini"
sudo lxc exec $CONTAINER -- bash -c "tail /etc/xrdp/sesman.ini"
```

Expose 3389 container's port:

```
sudo lxc config device add $CONTAINER $PROXYDEVICERDP proxy listen=tcp:0.0.0.0:$PROXYDEVICERDPPORTHOST connect=tcp:127.0.0.1:$PROXYDEVICERDPPORTCNT
```

Finally, enable xfce4-session for your user:

```
sudo lxc exec $CONTAINER -- touch "/home/$USERNAME/.xsession"
sudo lxc exec $CONTAINER -- bash -c "echo '/usr/bin/xfce4-session' >> /home/$USERNAME/.xsession"
sudo lxc exec $CONTAINER -- chown "$USERNAME:$USERNAME" "/home/$USERNAME/.xsession"
sudo lxc exec $CONTAINER -- chmod +x "/home/$USERNAME/.xsession"
sudo lxc exec $CONTAINER -- tail "/home/$USERNAME/.xsession"
sudo lxc exec $CONTAINER -- systemctl set-default graphical.target
sudo lxc exec $CONTAINER -- bash -c "systemctl enable xrdp"
sudo lxc restart $CONTAINER
```

Allow anyone to connect to RDP:

```
sudo lxc exec $CONTAINER -- touch "/etc/X11/Xwrapper.config"
sudo lxc exec $CONTAINER -- bash -c "echo 'allowed_users = anybody' >> /etc/X11/Xwrapper.config"
```

## Connecting

You can connect using Remmina and test it! It should work. Remember to set the connection to *Xorg* at the xrdp login dialog, otherwise you won't be using your gpu to render 3d graphics.

If you want to make sure you're using your gpu, run "glxspheres64". It will show you the renderer (should be different than llvm etc) and run at a lot of fps (mine was 4000 fps avg using gtx 1060).

Finally I will be able to get my desktop ou of my desk and get it to another room.

## DEBUG

If you need to debug, these commands should output you important logs:

```
sudo lxc exec $CONTAINER -- bash -c "less /var/log/xrdp.log"
sudo lxc exec $CONTAINER -- bash -c "less /var/log/xrdp-sesman.log"
sudo lxc exec $CONTAINER -- bash -c "cat /home/$USERNAME/.xorgxrdp.10.log"
```

