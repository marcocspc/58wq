---
layout: post
title:  "Making the L4T Ubuntu on Switch reach its Ultimate Form"
date:  2021-12-24 16:58:57 UTC00 
categories: english linux ubuntu 
---

# Making the L4T Ubuntu on Switch reach its Ultimate Form 

I was using Android on my switch. I love that platform because it have turned my switch into a final portable streaming device, but I've met some problems along the way. First of all, I could not make the pro controller ZL and ZR buttons work on the xcloud app, so I thought I could circumvent this on Ubuntu. Second, I feel that I never have full control over the OS when using android. So I decided to return to L4T Ubuntu and create something that I could have full control.

Some points that I'd like to achieve:

1- Make L4T Ubuntu work with BTRFS (so I can make snapshots of the filesystem);
2- To have several ways of controlling it (via SSH, VNC over SSH, using the joycons, pro controller, etc);
3- Install the latest version of chromium with hardware accelaration and support for widevine, so I can watch netflix and other streaming services;
4- Install wireguard, so it will always be on my home network wherever I go.

Oh, and I won't stop using Android. Ubuntu will only replace my Android setup if it is able to connect to every streaming platform I already use.

## Export some variables

```
export BASEDIR=/home/marcocspc/Downloads
export UBUNTU_IMAGE_LINK=https://download.switchroot.org/ubuntu/switchroot-ubuntu-3.4.0-2021-07-23-v2.7z
export UBUNTU_COMPRESSED_FILENAME=$(basename $UBUNTU_IMAGE_LINK)
export SDCARD=/dev/sdb
export SDCARDPARTITION="$SDCARD"1
export SDCARDMOUNTDIRECTORY=/media/marcocspc/SWITCHROOT
export SDCARDBACKUPDIR="$BASEDIR"/backup
export HEKATE_LINK=https://github.com/CTCaer/hekate/releases/download/v5.6.5/hekate_ctcaer_5.6.5_Nyx_1.1.1.zip
export HEKATE_FILE=$(basename $HEKATE_LINK)
export HEKATE_DEST_FOLDER="$SDCARDMOUNTDIRECTORY"/argon
```

## Basic setup

First of all, have a Linux pc with an sd card reader. You will need to format the sd card as fat32 and copy Hekate and L4T Ubuntu files to there.

Mount the sd card:

```
sudo mkdir -p $SDCARDMOUNTDIRECTORY && sudo mount $SDCARDPARTITION $SDCARDMOUNTDIRECTORY
```

Download and copy the most recent version of hekate and copy it to the sd card.

```
cd $BASEDIR
wget $HEKATE_LINK
mkdir -p hekate && cd hekate
cp ../$HEKATE_FILE .
unzip $HEKATE_FILE
sudo rm $HEKATE_FILE
sudo mkdir -p $HEKATE_DEST_FOLDER
sudo cp -r *bin $HEKATE_DEST_FOLDER
sudo cp -r * $SDCARDMOUNTDIRECTORY
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
sudo mount $SDCARDPARTITION $SDCARDMOUNTDIRECTORY
```

Extract the downloaded file:

```
cd $BASEDIR
mkdir -p extract && cd extract
cp ../$UBUNTU_COMPRESSED_FILENAME .
7z x $UBUNTU_COMPRESSED_FILENAME
sudo rm $UBUNTU_COMPRESSED_FILENAME
```

Copy the two extracted folders to the sd card:

```
sudo umount $SDCARDPARTITION
sudo mount $SDCARDPARTITION $SDCARDMOUNTDIRECTORY
cd $BASEDIR/extract
sudo cp -r * $SDCARDMOUNTDIRECTORY
```

Then get the sd card into the switch and boot hekate again, once it loads tap (on the bottom of the screen) Nyx Options > Dump Joy-Con BT. This will make joy-con connecting/disconnecting from the switch a joy.

Then return to the home screen and go to Tools > Partition SD Card. Press OK and tap Flash Linux, then Continue. Once it finishes, press Delete Installation Files.

Next, launch Ubuntu so it can make its initial set up. Return to the home screen and go to More Configs > L4T Ubuntu Bionic. This will start Ubuntu installation, set it up as you would on any PC installation. You *WILL NEED* a keyboard during this process, to set up wi-fi and enter your username, etc. Put your switch in the dock, plug an USB keyboard and an external monitor to view the screen. You may also use a usb mouse, but you can quickly remove from the dock and touch the screen if you need to click on something. When you're done, get to the next chapter. 

## Make our life easier

When the switch boots into Ubuntu for the first time, connect to wi-fi. We need to install SSH so it is easier for us to set things up. I recommend the usage of a keyboard at this moment, it will make easier to type commands. But you can also do this using the on-screen keyboard. Anyway, press Ctrl-Alt-T to open a terminal and type:

```
sudo apt update
sudo apt install ssh -y
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
sudo apt install git jq python3-pip -y
pip3 install psutil —user
cd ~/Downloads
git clone https://github.com/fossfreedom/indicator-sysmonitor
cd indicator-sysmonitor
sudo make install 
```

To show the wifi ip unfortunately we have to go to the switch. First, launch indicator-sysmonitor by clicking on Ubuntu logo (top-left) and typing "indicator" on the search bar. The app should be the first listed. You will see that there is a text on the top menu bar showing the cpu and the memory usage, tap it, then click Preferences.

First check "Run at startup", and then go to the Advanced tab. Click on new. Put "wifiip" in the Sensor field, type something on the description and put "ip a s dev wlp1s0 | grep inet | head -1 | awk '{print $2 }'" in the Command field. Hit OK. Then go to "Customize Output and type: "wifi ip: {wifiip}. Hit save, that should do it.

## BTRFS All The Way!

OK, now to the BTRFS part. First we need to create one file and edit another so we avoid some errors before installing lvm2. First, login into the switch again via ssh. Run the following command to create and write the contents to /etc/initramfs-tools/conf.d/noresume.conf:

```
sudo bash -c "cat << EOF > /etc/initramfs-tools/conf.d/noresume.conf
# Disable resume (this system has no swap)
RESUME=none
EOF"
```

Then we need to edit /etc/fstab to use UUID instead of /dev/root. First backup it:

```
sudo cp /etc/fstab /etc/fstab.bak
```

Then get the UUID for the root partition:

```
sudo blkid | grep ext4
```

Copy the UUID, then edit fstab:

```
sudo vim /etc/fstab
```

Replace /dev/root with UUID=xxxxxxxxx (yes, without the quotes). Now we should be able to install BTRFS2:

```
sudo apt install lvm2 btrfs-progs -y
```

After this, we need to edit one last file. Backup it first:

```
sudo cp /boot/extlinux/extlinux.conf /boot/extlinux/extlinux.conf.bak
```

Then edit it:

```
sudo vim /boot/extlinux/extlinux.conf
```

Replace the line "INITRD /boot/initrd" with "INITRD /boot/initrd.img". Save and reboot the switch to check wether it still boots normally. If yes, shutdown the switch, we will take the sd card and use a linux pc to setup the lvm partition.

We are going to backup our setup so we can copy the files back later. You have three ways of proceeding to do this:

1- Copy the files to a safe location;
2- Make a full bit level dd backup;
3- Use fsarchiver to do a partition level backup.

Here I'm going to take the third approach. I like to do this way because I can ensure files and permissions are preserved and is also faster than dd. Anyway, you should do as follows, install fsarchiver and btrfs (for later use):

```
sudo apt install fsarchiver btrfs-progs -y
```

Then we make a backup of the entire disk:

```
sudo umount "$SDCARD"1 "$SDCARD"2
mkdir -p $SDCARDBACKUPDIR && cd $SDCARDBACKUPDIR
sudo fsarchiver -v savefs ./sdcard_backup_switch_ubuntu_$(date +%F).fsa "$SDCARD"1 "$SDCARD"2
```

With the backup in place, we can "convert" the filesystem. With fsarchiver this will be like a walk in the park, easy-peasy. Run the command below:

```
sudo fsarchiver -v restfs ./sdcard_backup_switch_ubuntu_$(date +%F).fsa id=1,dest="$SDCARD"2,uuid=$(uuidgen)
```

We need now to get the uuid of the $SDCARD2. Run:

```
sudo blkid
```

Note down (or copy) the UUID (not the UUID_SUB or PARTUUID). We are going to edit two files in the sd card so Ubuntu can boot again after the changes. Create two folders so we can mount the two partitions:

```
sudo mkdir -p /mnt/boot /mnt/ubuntu
sudo mount "$SDCARD"1 /mnt/boot
sudo mount "$SDCARD"2 /mnt/ubuntu
```

Edit fstab:

```
sudo vim /mnt/ubuntu/etc/fstab
```

Replace the UUID to the / mount with the UUID you copied above and ext4 with btrfs. Edit uenv.txt file:

```
sudo echo "rootfstype=btrfs" >> /mnt/boot/switchroot/ubuntu/uenv.txt
```

Now unmount the partitions:

```
sudo umount "$SDCARD"1 "$SDCARD"2
```

Remove the sd card from your PC, put back on the switch and boot into Ubuntu again.

## Creating the first BTRFS snapshot

Login again into your switch by using ssh:

```
ssh your-username@your-switch-ip
```

By restoring the partition using fsarchiver, we missed the subvolume creation part. We should use subvolumes to take full advantage of btrfs capalities (not only snapshots, but the hability, for example, of including other disks as part of ur partition if needed). Let's create a subvolume to boot into it:

```
sudo btrfs subvolume snapshot / /@
```

Now we get our subvolume id:

```
sudo btrfs subvolume list /
```

Output should be something like this:

```
ID 262 gen 96 top level 5 path @
```

The id in the example is 262. Set it to be the default one (remember to use YOUR subvolid):

```
sudo btrfs subvolume set-default 262 /
```

Reboot:

```
sudo reboot
```

SSH into the switch again and check if you booted into the subvolume:

```
sudo mount | grep mmcblk0p2
```

Output should show "/@":

```
/dev/mmcblk0p2 on / type btrfs (rw,noatime,ssd,space_cache,subvolid=262,subvol=/@)
```

If this is the case we can mount the root volume and delete the old files.

** WARNING ** : only proceed if everything is working like I described above. Because the following step will delete all files inside your system except the subvolume. You were advised.

```
sudo mount -o subvolid=0 /dev/mmcblk0p2 /mnt
```

Enter /mnt and remove everything except the snapshot:

```
cd /mnt
ls | grep -v @ | xargs sudo rm -rf
```

Reboot and check if the system is still working:

```
sudo reboot
```

You can follow these steps (except removing files from another volume) to create snapshots and rolling back to them if needed. To rollback to a snapshot you just need to change the default subvolume id using the command `btrfs subvolume set-default ID /` and reboot. To create a snapshot you run the first command of this topic `sudo btrfs subvolume snapshot / /SNAPSHOT_NAME`. 

Then we are done for the filesystem part.

## Control Ubuntu with joycons

To do this I will use L4T Ubuntu Megascript help. It is a life-saver for those who run L4T Ubuntu on their Switch. It has a lot of functions, which means it installs a lot of things. Unfortunately, this is not what I want. But since the script is open source, we can use only the part responsible to install the joycon-mouse, without taking much space or changing too much our setup. So, to install it, run this:

```
bash <( wget -O - https://raw.githubusercontent.com/cobalt2727/L4T-Megascript/master/scripts/joycon-mouse.sh )
```

It might throw a few errors related to some "userinput_func" function, but we can ignore them. Reboot and voilà the joycons are controlling the mouse. I will leave the default mapping here for documentation purposes:

Button  Key
B   Left Click
A   Right Click
X   Middle Mouse Button
L   Volume Down
R   Volume Up
ZR  Brightness Up
ZL  Brightness Down
D-PAD   Keyboard Arrow Keys
Screenshot  Turn the mouse off and on (leave off when playing games)
Home    Escape
+   Enter
-   Back
Right Stick Click   F5
Left Stick XY   Mouse XY
Right Stick XY  Scroll XY

## VNC Remote Access

Let's install x11vnc and turn it into a service so we can manage our switch graphically from another host. First install it:

```
sudo apt install x11vnc -y
```

Before proceeding, it is needed to understand one thing: in Ubuntu 18.04, there are two X displays available. One is for the gdm user, which shows the login screen, the other is for the logged user. Why it is so important to understand this? Because we will need two instances of x11vnc running, hence we will create two services. 

When connecting to VNC, you will need two client connections: first connect to port 5900 and login, then connect to port 5901 to see your desktop. 

Now let's create both services. For each block, copy and paste all lines at once:

```
sudo bash -c "cat << EOF > /etc/systemd/system/x11vnc-loginscreen.service 
[Unit]
Description=Start x11vnc at startup.
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/bin/x11vnc -display :0 -auth /run/user/120/gdm/Xauthority -forever -localhost -nopw   -noxdamage -repeat -rfbport 5900 -shared    -ncache 10 -ncache_cr
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF
"
```

```
sudo bash -c "cat << EOF > /etc/systemd/system/x11vnc-loggedin.service 
[Unit]
Description=Start x11vnc at startup, before login.
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/bin/x11vnc -display :1 -auth /run/user/1000/gdm/Xauthority -forever  -localhost    -noxdamage -repeat -nopw  -rfbport 5901 -shared    -ncache 10 -ncache_cr
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF
"
```

Now enable both services and reboot:

```
sudo systemctl enable x11vnc-loginscreen x11vnc-loggedin
sudo reboot
```

One observation: the -localhost flag means that x11vnc will only accept connections from 127.0.0.1, which means that you will only be able to connect via SSH tunnel (more secure). That's why I've set x11vnc to run without a password, since the service is already protected by SSH authentication.

Also, when connecting, remember to set two connections: one for port 5900 and one for 5901. Which are, respectively, for the login screen and the loggedin screen.

## Autoboot into Ubuntu

If wanted, you can set Hekate to autoboot into Ubuntu. Here's how to do it:

- Boot into Hekate;
- Go to options (top-right of the screen);
- Tap "Auto Boot";
- Select "L4T Ubuntu Bionic";
- Tap into "Save Options" (bottom of the screen).

You're done! You can shutdown or boot into Ubuntu again.

## Installing Steam Link

We will install Steam Link by using Box64. Since the Switch uses arm, we cannot install the streaming app directly. There *IS* a binary compiled for arm, but it depends on libraries that are present only on the Raspberry Pi OS. Believe me, I tried to circumvent this. So this time we are going to try Box64. To install it, first run this to install cmake:

```
sudo apt install cmake
```

Now run this:

```
cd $BASEDIR
git clone https://github.com/ptitSeb/box64 && cd box64
mkdir build && cd build
git checkout tags/v0.1.6 # you can check other tags by running `git tag`
cmake .. -DTEGRAX1=1 -DCMAKE_BUILD_TYPE=RelWithDebInfo
make -j4
sudo make install
```

The commands above will download box64, compile and install it. Then we need to restart systemd-binfmt to enable box64:

```
sudo systemctl restart systemd-binfmt
```

Now we install steam, first install some dependencies:

```
sudo apt install debconf libc6 libgl1-mesa-dri libgl1-mesa-glx libgpg-error0 libstdc++6 libudev1 libx11-6 libxinerama1 xz-utils 
```

Then get a link to download i386 steam [here](https://packages.ubuntu.com/bionic/i386/steam/download). Then download it using wget (the link below is just one example, it may not work):

```
cd $BASEDIR
wget http://mirrors.kernel.org/ubuntu/pool/multiverse/s/steam/steam_1.0.0.54+repack-5ubuntu1_i386.deb
```

Unpack it:

```
ar x steam_1.0.0.54+repack-5ubuntu1_i386.deb
tar xvf data.tar.xz
```

Copy data to /usr:

```
cd $BASEDIR
sudo cp -r ./usr/* /usr
```

## References

[Running Steamlink on Arch Linux ARM](https://zignar.net/2019/11/10/steamlink-on-archlinuxarm/)
[Enable remote VNC from the commandline?](https://askubuntu.com/questions/4474/enable-remote-vnc-from-the-commandline)
[VNC vino over SSH tunnel ONLY](https://askubuntu.com/questions/713497/vnc-vino-over-ssh-tunnel-only)
[LVNC vino over SSH tunnel ONLY4T MegaScript](https://github.com/cobalt2727/L4T-Megascript)
[Rollback root snapshot in BTRFS](https://unix.stackexchange.com/questions/622148/rollback-root-snapshot-in-btrfs)
[Where are my BTRFS subvolumes?](https://askubuntu.com/questions/1204802/where-are-my-btrfs-subvolumes)
[Can move my root partition to a btrfs subvolume?](https://forums.developer.nvidia.com/t/can-move-my-root-partition-to-a-btrfs-subvolume/179276)
