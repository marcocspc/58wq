---
layout: post
title:  "Making the L4T Ubuntu on Switch reach its Ultimate Form"
date:  2021-12-24 16:58:57 UTC00 
categories: english linux ubuntu 
---

# Making the L4T Ubuntu on Switch reach its Ultimate Form 

I was using Android on my switch. I love that platform because I have turned my switch into a final portable streaming platform, but I've met some problems along the way. First of all, I could not make the pro controller ZL and ZR buttons work on the xcloud app, so I thought I could circumvent this on Ubuntu. Second, I feel that I never have full control over the OS when using android. So I decided to return to L4T Ubuntu and create something that I could have full control.

Some points that I'd like to achieve:

1- Make L4T Ubuntu work with LVM (so I can make snapshots of the filesystem);
2- To have several ways of controlling it (via SSH, VNC over SSH, using the joycons, pro controller, etc);
3- Install the latest version of chromium with hardware accelaration and support for widevine, so I can watch netflix and other streaming services;
4- Install wireguard, so it will always be on my home network wherever I go.

Oh, and I won't stop using Android. Ubuntu will only replace my Android setup if it is able to connect to every streaming platform I already use.

## Export some variables

```
export UBUNTU_IMAGE_LINK=https://download.switchroot.org/ubuntu/switchroot-ubuntu-3.4.0-2021-07-23-v2.7z
export UBUNTU_COMPRESSED_FILENAME=(basename $UBUNTU_IMAGE_LINK)
export SDCARD=/deb/sdb
export SDCARDPARTITION="$SDCARD"1
export SDCARDMOUNTDIRECTORY=/media/marcocspc/SWITCHROOT
export SDCARDBACKUPDIR=/backup
export HEKATE_LINK=https://github.com/CTCaer/hekate/releases/download/v5.6.5/hekate_ctcaer_5.6.5_Nyx_1.1.1.zip
export HEKATE_FILE=$(basename $HEKATE_LINK)
export HEKATE_DEST_FOLDER="$SDCARDMOUNTDIRECTORY"/argon
export BASEDIR=/home/marcocspc/Downloads
```

## Basic setup

First of all, have a Linux pc with an sd card reader. You will need to format the sd card as fat32 and copy Hekate and L4T Ubuntu files to there.

Mount the sd card:

```
mount $SDCARDPARTITION $SDCARDMOUNTDIRECTORY
```

Download and copy the most recent version of hekate and copy it to the sd card.

```
cd $BASEDIR
wget $HEKATE_LINK
mkdir hekate && cd hekate
cp ../$HEKATE_FILE .
unzip $HEKATE_FILE
rm $HEKATE_FILE
mkdir -p $HEKATE_DEST_FOLDER
cp -r *bin $HEKATE_DEST_FOLDER
cp -r * $SDCARDMOUNTDIRECTORY
```

PS: If your rcm jig uses the argon folder remember to rename hekate_ctcaer_x.x.x.bin to payload.bin!
PS2: If you copied any file to the sd card other than the bootloader folder (for example, those who use the payload inside the argon folder), you will need to copy then again after doing the next step, since it deletes ALL FILES except the bootloader folder and everything inside it.

After copying everything to the sd card, eject it, insert it on the switch and boot hekate using your rcm jig. Once hekate is booted, go to (on the top of the screen) Tools > Partition SD Card. Click OK and slide the Linux (blue one) bar until the HOS Bar (the green one) marks about 7GiB of space. Then hit Next Step and Start. Wait until the countdown finish and press the POWER button to continue. This will format the sd card as the way it needs to be to receive Linux. Power off the switch and return the sd card to your PC.

Download L4t Ubuntu base image:

```
cd $BASEDIR
wget $UBUNTU_IMAGE_LINK
```

After the download is finished, mount the sd card again:

```
mount $SDCARDPARTITION $SDCARDMOUNTDIRECTORY
```

Extract the downloaded file:

```
cd $BASEDIR
mkdir extract && cd extract
cp ../$UBUNTU_COMPRESSED_FILENAME .
7z x $UBUNTU_COMPRESSED_FILENAME
rm $UBUNTU_COMPRESSED_FILENAME
```

Copy the two extracted folders to the sd card:

```
cd $BASEDIR/extract
cp -r * $SDCARDMOUNTDIRECTORY
```

Then get the sd card into the switch and boot hekate again, once it loads tap (on the bottom of the screen) Nyx Options > Dump Joy-Con BT. This will make joy-con connecting/disconnecting from the switch a joy.

Then return to the home screen and go to Tools > Partition SD Card. Press OK and tap Flash Linux, then Continue. Once it finishes, press Delete Installation Files.

Next, launch Ubuntu so it can make its initial set up. Return to the home screen and go to More Configs > L4T Ubuntu Bionic. This will start Ubuntu installation, set it up as you would on any PC installation. You *WILL NEED* a keyboard during this process, to set up wi-fi and enter your username, etc. Put your switch in the dock, plug an USB keyboard and an external monitor to view the screen. You may also use a usb mouse, but you can quickly remove from the dock and touch the screen if you need to click on something. When you're done, get to the next chapter. 

## LVM All The Way!

I've decided to use LVM because of its ability to create snapshots. I cannot count how many times I screwed my Ubuntu installation because of some minor change. This way I can roll back if anything gets out of order.

When the switch boots into Ubuntu for the first time, connect to wi-fi. We need to install SSH and LVM, so we can use those to access the switch remotely and configure the kernel to boot into lvm later. I recommend the usage of a keyboard at this moment, it will make easier to type commands.

```
sudo apt update
sudo apt install lvm2 ssh -y
```

After this, we get the switch IP:

```
ip a s dev wlp10
```

Then go to your desktop and connect to it:

```
ssh your-username@your-switch-ip
```

You will get a remote terminal. Let's install sysmonitor indicator to make it easy view the ip next time. Still from your desktop, do:

```
sudo apt install git jq -y
cd ~/Downloads
git clone https://github.com/fossfreedom/indicator-sysmonitor
cd indicator-sysmonitor
sudo make install 
cat << EOF > ~/.indicator-sysmonitor.json
{"custom_text": "cpu: {cpu} mem: {mem} wifi-ip: {ip-wifi}", "interval": 2.0, "on_startup": false, "sensors": {"cpu\\d*": ["Average CPU usage", true], "nvgpu": ["Nvidia GPU utilization", true], "mem": ["Physical memory in use.", true], "net": ["Network activity.", true], "netcomp": ["Network activity in Compact form.", true], "totalnet": ["Total Network activity.", true], "bat\\d*": ["Battery capacity.", true], "fs//.+": ["Available space in file system.", true], "swap": ["Average swap usage", true], "upordown": ["Display if your internet connection is up or down", true], "publiccountry": ["Display your public country", true], "publiccountryiso": ["Display your public country ISO code", true], "publicip": ["Display your public IP address", true], "cputemp": ["CPU temperature", true], "nvgputemp": ["Nvidia GPU Temperature", true], "ip-wifi": ["Shows SWITCH ip when connected to wifi.", "ip a s dev wlp1s0 | grep inet | head -1 | awk '{ print $2 }'"]}}
EOF
```

There was one last command that should solve the part of starting once you login. But it is needed to do it manually. Go to your switch and click on the Ubuntu icon (top left of the screen). Write Startup Applications and click on it once it shows up. Touch on Add, put the name "Indicator Sysmonitor" and put as command "/usr/bin/indicator-sysmonitor". Reboot the switch and login again to see if it works.

Then shutdown. Remove the sd card and bring back to your linux pc. Now we are going to backup our setup so we can install lvm and copy the files back. You have two ways of proceeding to do this:

1- Copy the files to a safe location;
2- Make a full bit level dd backup.

Here I'm going to take the second approach. I like to do this way because I can ensure files and permissions are preserved. Anyway, you should do as follows:

```
dd if=$SDCARD of=$SDCARDBACKUPDIR bs=4M
```

PS: If you want to see the progress of this command (it *will* take a while) install pv and put it in the middle: `dd if=$SDCARD bs=4M | pv | of=$SDCARDBACKUPDIR`.

With the backup in place, now we can reformat our sd card. Do it the way suits you more, the only thing you need to know is that you have to completely erase ubuntu partition (the second one) and replace it with an empty (non-formatted) partition. The LVM volume will be built on top of this partition, then we copy the files from the backup when done.

In my case, I've screwed things up and had to reformat the sd card entirely, so I'm going to tell how I did to get things done. But these steps should be similar to those who did not screw the sd card. Since I had a backup, it was easy to copy everything back and edit some files to make the system work again.

I've used gparted. So plug the sd card back to your linux pc and open the app. Then go to (some terms might not be the same since I'm translating from portuguese to english here) Device > New Partition Table. This will erase the entire device (which I needed because I had nuked the Ubuntu partition lol). Choose msdos format. 

Now with the blank scheme, right click and choose New. Create a new fat32 partition about 7GB long (7168 MB, there's a field for you to write that). Hit OK and create another partition, this one will be non-formatted and will use the remaining free space.

After the creation, right click the scond partition (the non-formatted one) and choose Manage Flags, tick lvm and confirm. That should do it for gparted. Close the application.

Now back to the terminal, now we go to lvm. LVM has a full hierarchy of device allocation which needs to be done. Since I will not spend time explaining it, think this way: we have the empty partition, to lvm it, we need to "mark" it as usable (turn it into a physical volume), then we make it part of a group and finally we create a logical volume which will be our device to be formatted by gparted again. OK, these are several layers, but in the end it will be worth it, trust me. Oh, and I'm assuming the fat32 partition to be /dev/sda1 and the ubuntu (LVM) partition to be /dev/sda2. Let's start by tainting the partition to be an lvm one:


```
sudo pvcreate /dev/sda2
```

Then we create the group:

```
sudo vgcreate vg0 /dev/sda2
```

Finally (for the lvm part), create the logical volume:

```
sudo lvcreate -n root -l 100%FREE vg0
```

PS: If you need to remove the volume do this: `sudo lvremove /dev/vg0/root`
PS2: To view everything use `sudo lvdisplay`

Now we create the ext4 partition:

```
sudo mkfs.ext4 /dev/vg0/root
```

Now we need to restore the backup, we will mount our image as a loop device and restore all the files. Then we will make some tweaks to make lvm work out of the box on the switch.

```
sudo losetup --partscan --find --show /path/to/backup.img
```

This will output /dev/loopX, use this on the next commands. First we make the folders where we are going to mount our partitions:

```
sudo mkdir /mnt/backup1 /mnt/backup2 /mnt/restore1 /mnt/restore2
```

Then mount the two partitions:

```
sudo mount /dev/loopXp1 /mnt/backup1
sudo mount /dev/loopXp2 /mnt/backup2
```

We also mount the sd card, to restor the files:

```
sudo mount /dev/sda1 /mnt/restore1
sudo mount /dev/vg0/root /mnt/restore2
```

Now restore all files:

```
sudo rsync -ah --progress /mnt/backup1/* /mnt/restore1
sudo rsync -ah --progress /mnt/backup2/* /mnt/restore2
```

TODO: 
HYPOTHESIS 1: There's a iniramfs inside sd/switchroot/ubuntu, this is what should be loaded by coreboot. So, by setting some kernel params, this initramfs should be able to load lvm. If not, I can try to generate a new one with support for it.
HYPOTHESIS 2: Apparently, l4t ubuntu uses a coreboot to boot the kernel that is in the /boot dir. But this dir is inside the lvm partition. So I think I need to make /boot on another partition and then change the kernel boot options to start lvm and boot mount the root partition.

Util: this link shows l4t boot process and talks avout extlinux.conf which may help setup where the partition ewill be. also shows how to geberate a new iniranfs. so maybe you should try lvm again before testing brtfs
