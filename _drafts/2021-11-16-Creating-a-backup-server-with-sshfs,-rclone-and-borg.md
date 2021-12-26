---
layout: post
title:  "Creating a backup server with lxd, ssh, rclone and borg"
date:  2021-11-16 17:35:04 -0300 
categories: english linux
---

# Creating a backup server with lxd, ssh, rclone and borg 

In portuguese, when we finally start to do something we've been procrastinating, we say that "I finally drank shame on my face". In English it surely does not sound the same way as in portuguese, but in a single word it should mean "finally". And by finally I mean that I'm going to automate my backups using Borg.

At my job a already use BareOS to make these tasks, but it is a little too much for what I'm trying to accomplish here. BareOS/Bacula is a powerful tool, but too complex to manage, in my opinion. I want something simple, like rsync. But this one does not have support for encryption natively, so I've stumbled upon Borg recently. 

It looks like Borg is rsync with steroids. It supports encryption, backup checking and differential backups at block level (which means that it won't copy entirely big files over if they are changed, like rsync, just that part which was changed). I've decided, then, to try this one out.

## My Plan

My plan is to have another container serving directories as backup destinations to every backed container. Each container should have a user with access only to a chroot jail environment, where it could store it's encrypted backups.

I've thought about making all the backups from one container, but giving access to several files and folder from one location is not recommended, since if an attacker takes control of that instance, everything maybe ruined. So the idea is that from one container I run `bog serve` and from the clients I make scripts to backup that data.

With `borg serve` I can restrict the directory for each client using ssh keys authorization (that's why ssh is in the title). Also, I use rclone to create a second copy of that folder into the cloud. 

Oh, and I'm doing this on a lxd host. Every command should be ran in the host *NOT* in the containers.

## How to do it then?

I start by creating a container (see bellow) and following [this guide](https://borgbackup.readthedocs.io/en/stable/deployment/central-backup-server.html) to have a borg server running. But, before anything, let's export some variables to make our work easier:

```
export IMAGE=ubuntu:20.04
export CONTAINER=kibo
export CONTAINERTOBACKUP=apollo12
export BACKUPORIGIN=/etc/wireguard
export BKPUSERNAME=borgbackup
export RCLONEDOWNLOAD=https://downloads.rclone.org/rclone-current-linux-arm.zip
export RCLONEPKG=$(basename $RCLONEDOWNLOAD)
```

Create the backup server:

```
sudo lxc launch $IMAGE $CONTAINER
```

Update all the packages:

```
sudo lxc exec $CONTAINER -- bash -c "apt update && apt upgrade -y"
```

Install borg and unzip:

```
sudo lxc exec $CONTAINER -- apt install borgbackup unzip -y
```

Before proceeding it is highly recommended that the container has access to an external media to make the backups. Here I'm going to use rclone to mount an folder from my Drive. Let's install rclone:

```
sudo lxc exec $CONTAINER -- bash -c "mkdir -p downloads && cd downloads && wget $RCLONEDOWNLOAD && unzip $RCLONEPKG && cp rclone*/rclone /usr/bin && chown root:root /usr/bin/rclone && chmod 755 /usr/bin/rclone"
```

After this, we need to create a user to maintain the backups, do it as follows:

```
sudo lxc exec $CONTAINER -- useradd "$BKPUSERNAME" -m
```

Then let's create the backup folder and give permissions to our user:

```
sudo lxc exec $CONTAINER -- mkdir -p /home/$BKPUSERNAME/gdrivebackup/
sudo lxc exec $CONTAINER -- chown -R $BKPUSERNAME:$BKPUSERNAME /home/$BKPUSERNAME/gdrivebackup
```

Now we setup rclone to mount one of our Google Drive folder as a backup destination. Here I'm just going to leave the command, details on how to answer the questions can be found [here](https://rclone.org/drive/). Just one thing to keep in mind: there's a moment rclone will ask to open the url "http://127.0.0.1:53682/auth" on your browser. To make this work, we need to expose that port on our container. The following commands will do that and start rclone config. Oh, and don't forget to replace 127.0.0.1 with your host's ip when accessing the URL on your browser (you WILL NOT replace this address in the command below, only in the browser):

```
sudo lxc config device add $CONTAINER temprclone proxy listen=tcp:0.0.0.0:53682 connect=tcp:127.0.0.1:53682
sudo lxc exec $CONTAINER -- bash -c "su $BKPUSERNAME -c 'rclone config'"
```

Also, this guide considers that you named your remote as "googledrive".

Next remove the proxy device, as we won't need it anymore:

```
sudo lxc config device rm $CONTAINER temprclone 
```

Now mount let's config rclone to automount our drive folder at boot. Create a systemd service file:

```
sudo lxc exec $CONTAINER -- bash -c "cat <<EOF > /etc/systemd/system/rclonegdrive.service
[Unit]
Description=Google Drive Rclone Mount
AssertPathIsDirectory=/home/$BKPUSERNAME/gdrivebackup
After=network-online.target
Wants=network-online.target

[Service]
User=$BKPUSERNAME
Group=$BKPUSERNAME
Type=simple
ExecStart=/usr/bin/rclone mount --daemon googledrive:/ /home/$BKPUSERNAME/gdrivebackup
ExecStop=/bin/fusermount -u /home/$BKPUSERNAME/gdrivebackup
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
EOF"
```

Enable and start it:

```
sudo lxc exec $CONTAINER -- bash -c "systemctl enable rclonegdrive && systemctl start rclonegdrive"
```


