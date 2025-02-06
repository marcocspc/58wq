---
layout: post
title:  "Setting up OneKVM on my Orange Pi Zero"
date:  2025-02-05 13:54:37 -0300 
categories: english linux armbian 
---

# Setting up OneKVM on my Orange Pi Zero 

To be honest, I already have [OneKVM](https://github.com/mofeng-git/One-KVM) working on my Orange Pi Zero. The thing is, I've done this setup on an 8GB SD card and I don't remember all the steps I performed in order to accomplish it. So, again, here's another post to document my endeavor.

BTW, it's important to contextualize what the heck OneKVM is. In the past, [mdevaev](https://github.com/mdevaev) revolutionized the network KVM space with [PiKVM](https://pikvm.org/), which was an open source software (still is) made to run on the Raspberry Pi that would offer KVM capabilities over the network. By the time, it was the cheapest solution that had this kind of feature, which would force the manufacturers to offer cheaper solutions.

Time went on and Raspberry lost the crown of "cheap and small PC" to other competitors. Also, here in Brazil due to our BRL losing a lot of value in the last years joined to the fact that we have A LOT of taxes on imported items, the tiny board is just unbuyable.

That's when China comes to the rescue, twice. First, there are other hardware manufacturers that offer alternatives to the overpriced board. [Orange Pi](https://orangepi.org) is one to mention, which is a viable solution in these times. Also, the PiKVM project has a problem that just annoys me: although open source, the software is tied to Raspberry in such a way that installing it on other boards becomes a pain in places difficult to reach.

The second time in which China comes to the rescue is the OneKVM project. It's a port of the PiKVM software made to run in docker, which already adds a layer of portability. It also supports Orange Pi Zero and a lot of other boards and small footprint PCs. The only thing with OneKVM is that its documentation is entirely written in Chinese, which adds some difficulty into the setup, but nothing that a Google Translate can't help with.

BTW that's one of the reasons to document this, I'd like to have some kind of setup documentation written in English for the folks that live on this side of the planet. I should be also making some pull requests in the future to add some localisation to the project as well, but that's a project for another time.

## Installing Armbian

First we download it:
```
wget https://dl.armbian.com/orangepizero/Bookworm_current_minimal -O armbian.img.xz
```

Here I'll be using the minimal version of Armbian, as I want to keep the installation footprint as small as possible.

After the download completes, the image can be written using the command below on Mac:
```
xzcat armbian.img.xz | sudo dd of=/dev/diskX status=progress
```

Where diskX is your SD card.

After the writing finishes. The SD Card can be inserted on Orange Pi. Give it a few minutes to boot up, as it will expand the partition and etc. To connect to it I just had to run the following command on my Mac (which was in the same network as the pi):
```
ssh root@orangepizero
```

The default password is 1234.

On the first login armbian is going to ask for the root password, a new user and this new user's password. On this doc, I'll be disabling root login and its password for security reasons, but you can leave it like this if you want.

After it finishes the first configuration, I exit the shell in order to have a new ssh session with the user I created. From now on all the commands that require super user privileges are going to use sudo.

```
ssh new_user@orangepizero
```

First thing I do is to fix the current date, as it's preventing me to apt-get update:
```
sudo date -s '2025-02-05 22:00:00'
```

Next I install a few programs that are useful here (including ntp to set the date automatically :P):
```
sudo apt-get update &&
sudo apt-get install -y \
             ntp \
             tmux \
             neovim \
             curl \
             docker.io \
             docker-compose \
             wget \
             network-manager
```

Then I edit the root password and add an exclamation mark in its place, this prevents root from logging in:
```
sudo nvim /etc/shadow
```

The root line becomes something like this:
```
root:!:20122:0:99999:7::: 
```

Next I also disable root login on SSH. This sed command does it:
```
sudo sed -i /etc/ssh/sshd_config -e 's/PermitRootLogin yes/PermitRootLogin no/'
```

Restart ssh:
```
sudo systemctl restart sshd
```

Add myself to the docker group:
```
sudo usermod -a $USER -G docker
```

Finally change the host name:
```
echo orangepizerokvm | sudo tee /etc/hostname
sudo sed -i /etc/hosts -e 's/orangepizero/orangepizerokvm/'
```

Reboot:
```
sudo reboot
```

## Preparations for OneKVM

It's needed to edit two things before installing and using OneKVM. First on the `/boot/armbianEnv.txt`, the following line must be changed from:
```
overlays=usbhost2 usbhost3 tve
```

To:
```
overlays=usbhost0 usbhost1 usbhost2 usbhost3 tve
```

This sed command does it:
```
sudo sed -i /boot/armbianEnv.txt -e 's/overlays=usbhost2 usbhost3 tve/overlays=usbhost0 usbhost1 usbhost2 usbhost3 tve/'
```

Next, the DTB must be edited to change the dr_mode to peripheral. First decompile the dtb:
```
sudo dtc -I dtb -O dts /boot/dtb/sun8i-h2-plus-orangepi-zero.dtb -o /boot/dtb/sun8i-h2-plus-orangepi-zero.dts
```

Change the dr_mode to peripheral (search for dr_mode and alter the string):
```
sudo nvim /boot/dtb/sun8i-h2-plus-orangepi-zero.dts
```
PS.: In my case it was already peripheral, but I'll leave it here because it maybe useful to me in the future.

Backup and replace the current dtb:
```
sudo cp /boot/dtb/sun8i-h2-plus-orangepi-zero.dtb /boot/dtb/sun8i-h2-plus-orangepi-zero.dtb.bak
sudo dtc -I dts -O dtb /boot/dtb/sun8i-h2-plus-orangepi-zero.dts -o /boot/dtb/sun8i-h2-plus-orangepi-zero.dtb
```

Reboot:
```
sudo reboot
```

## Installing OneKVM

Finally, to install OneKVM it's rather simple. Create a folder to the project:
```
mkdir -p ~/docker/onekvm && cd ~/docker/onekvm
```

Create a docker-compose file:
```
cat << EOF > docker-compose.yaml
services:
  onekvm:
    image: silentwind0/kvmd
    restart: always
    container_name: onekvm
    ports:
      - 8080:8080
      - 4430:4430
      - 5900:5900
      - 623:623
    volumes:
      - /dev:/dev
      - /sys/kernel/config:/sys/kernel/config
      - /lib/modules:/lib/modules:ro
      - ./msd:/var/lib/kvmd/msd
    environment:
      - OTG=1
    privileged: true
EOF
```

Finally run the container and look the logs:
```
docker-compose up -d && docker-compose logs -f
```

To access it, just type in the browser:
```
https://orangepizerokvm:4430/
```

You'll see that the interface is entirely in Chinese, but it can be put in english. Just below the 2FA input, there's a dropdown that says "简体中文", change that to "英语" and voilà!

BTW the default user and password is admin/admin.

## Connecting the little board to wifi

Just run this command and follow the prompts:
```
sudo nmtui
```

That's it!
