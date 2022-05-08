---
layout: post
title:  "Increasing the size of loop lxd loop device"
date:  2022-05-04 16:56:24 -0300 
categories: cat1 cat2 cat3  
---

# Increasing the size of loop lxd loop device 

So I had to wipe one of my raspberries after a power loss. The system got so corrupted that I did not find a way to recover it without reinstalling Raspberry Pi OS. One of the things I was able to do, though, was to backup all of my lxd containers before erasing everything. By the way, I might write a guide on how I did this, because even following [this](https://www.cyberciti.biz/faq/how-to-backup-and-restore-lxd-containers/) guide, there was some details (like mounting a USB drive to serve as an intermediary and final backup location) that I need to note down.

Anyway, when I reinstalled LXD on the new clean environment, I wanted to try out loop as a storage backend. But for some weird reason, which I can't remember, I set it up with only 5GB of storage size. It was not too long, then, that I needed to resize it. This is how I did it:

## Resizing the loop storage

Just one observation before proceeding: the commands shown here are for LXD installed via snap with the filesystem backend being btrfs, so to other contexts need adaptations.

To do this it is fairly simple. First, get your storage size:

```
lxc storage show default
```

Then stop LXD:

```
sudo systemctl stop snap.lxd.daemon
```

Resize the image (the file that represents your loop device). Also, run this as root:

```
SIZE=5 #Gigabytes
NEW_SIZE=7
AMOUNT_TO_GROW=$(( NEW_SIZE - SIZE ))
NEW_SIZE=7GB dd if=/dev/zero of=/var/snap/lxd/common/lxd/disks/default.img bs=$(( 1024 * 1024 )) count=$(( 1024 * $AMOUNT_TO_GROW )) seek=$SIZE
```

Restart LXD:

```
sudo systemctl start snap.lxd.daemon
```

Finally resize the btrfs filesystem:

```
sudo btrfs filesystem resize max /var/snap/lxd/common/lxd/storage-pools/default/
```

If you get a "command not found" error, install btrfs-tools:

```
sudo apt install btrfs-tools
```
