---
layout: post
title:  "Using an external USB device to serve as temporary backup folder for LXD"
date:  2022-01-16 13:08:50 -0300 
categories: english linux lxd
---

# Using an external USB device to serve as temporary backup folder for LXD 

It's not that uncommon that users face the "disk full" error when trying to backup a LXD container. This happens because lxd first creates a full copy of the container as an image before turning it into a .tar.gz file. 

So how to postpone this problem? One of the ways I've found is to have an external disk attached to the host and mount it as the backup folder for lxd. Let's see how this works in practise.

# Preparing the USB device

Connect to the usb device to your host and list the disks to get its path. 

```
sudo fdisk -l
```

You should get and output like /dev/sdX (mine was /dec/sda). Then let's wipe this disk and create a new ext4 partition. Do:

```
sudo fdisk /dev/sdX
```

Press d to delete a partition. My device only had one partition, but if you have more, fdisk may ask which one you want to remove. Here, we want to delete all partitions. 

After this press n to create a new partition. Since we want to use the entire disk, just leave all options default. Finally press w and Enter to write changes and exit. 

Then we create our ext4 partition with this command:

```
sudo mkfs.ext4 /dev/sdX1
```

This command may take a few minutes to finish, so get a cup of chocolate while you wait. ;)

# Mounting the new partition as LXD temporary backup folder

I'm considering here that you have installed lxd using snap. If your setup is different, the following paths will be different. Anyway, let's create a mountpoint for our partition and create two folders for our backups: one transient (where lxd will store the temporary copy) and one definitive (where the real backup will be).

Create the mountpoint:

```
sudo mkdir -p /media/lxdbackup
```

Now mount the partition there:

```
sudo mount /dev/sdX1 /media/lxdbackup
```

Create the two folders:

```
sudo mkdir /media/lxdbackup/transient
sudo mkdir /media/lxdbackup/definitive
```

Now we bind mount the transient folder to the temporary lxd backup path:

```
sudo mount --bind /media/lxdbackup/transient /var/snap/lxd/common/lxd/backups
sudo mount --bind /media/lxdbackup/transient /var/snap/lxd/common/lxd/images
```

Now we do a test to check if the backup is working:

```
sudo lxc snapshot YOUR_CONTAINER YOUR_SNAPSHOT_NAME
sudo lxc publish YOUR_CONTAINER/YOUR_SNAPSHOT_NAME --alias YOUR_ALIAS
sudo lxc image export YOUR_ALIAS /media/lxdbackup/definitive
sudo lxc image delete YOUR_ALIAS 
```

psst: while in progress you may list the files inside /media/lxdbackup/transient to check if the temporary file was created

After the process is done, you shoud have a .tar.gz file in /media/lxdbackup/definitive.

## Make it permanent

Finally, we make the mount persist after reboots. First, let's find the UUID for /dev/sdX1, run:

```
sudo blkid | grep /dev/sdX1
```

Copy the UUID.

Now we need to insert some lines in fstab, one for earch mount command we ran before. Let's first backup the file:

```
sudo cp /etc/fstab /etc/fstab.bak
```

Then adapt and past the following lines to your /etc/fstab file:

```
UUID="YOUR_UUID_HERE" /media/lxdbackup               ext4    defaults  0       0
/media/lxdbackup/transient /var/snap/lxd/common/lxd/backups none defaults,bind 0 0
/media/lxdbackup/transient /var/snap/lxd/common/lxd/images none defaults,bind 0 0"
```

Reboot and test if your mount was successfull. If yes, we're done!
