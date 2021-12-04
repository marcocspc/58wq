---
layout: post
title:  "SSH File Server on a LXD Container"
date:  2021-12-03 19:49:47 -0300 
categories: english linux lxd  
---

# SSH File Server on a LXD Container 

This one should be simple and quick. My idea is to create a Container which would share an external HDD through the network. This container is managed by LXD, so [this is the only software requirement](https://linuxcontainers.org/lxd/getting-started-cli/). 

Also each user should be able to see only it's own folder, so the home directory is mounted inside the external HDD.

## Getting started

First of all the external HDD should be connected to the host. All the commands listed below are ran on it, so no `lxc shell` around here, unless it's strictly necessary.

To make things easier for me, I like to export some environment variables, so when editing commands in the future, I need to alter only the head of this document.

```
export EXTERNAL_HDD_PARTITION=/dev/sda1
export EXTERNAL_HDD_DEVICE_NAME=hd500partition1
export CONTAINER=soyuz
export CLIENT_USER=marcocspc
export FILE_SERVER_PORT=2222
export IMAGE=fedora/35/armhf
export IMAGE_SERVER=images
export SSH_EXTERNAL_PORT=2222
export SSH_DEVICE_NAME=ssh$SSH_EXTERNAL_PORT
```

Let's launch the container:

```
sudo lxc stop $CONTAINER ; sudo lxc rm $CONTAINER
sudo lxc launch $IMAGE_SERVER:$IMAGE $CONTAINER
```

Mount the external hdd into /media/files and pass this directory to the container (we also enable shiftfs so the users inside the container can have write permissions on the mount):

```
sudo mkdir -p /media/files
sudo mount -t $EXTERNAL_HDD_PARTITION_FS $EXTERNAL_HDD_PARTITION /media/files
sudo snap set lxd shiftfs.enable=true
sudo systemctl reload snap.lxd.daemon
sudo systemctl restart snap.lxd.daemon
sudo lxc config device add $CONTAINER $EXTERNAL_HDD_DEVICE_NAME disk source=/media/files path=/mnt shift=true
```

If you get the "idmapping abilities are required but aren't supported on system" error, then you might be missing shiftfs kernel module. To fix this, follow [this guide](https://github.com/toby63/shiftfs-dkms/tree/k5.10#install) to install shiftfs (check your kernel version and select the right branch before installing).

Make the external hdd automatically mount after a reboot:

```
echo "$(sudo blkid | grep $EXTERNAL_HDD_PARTITION | awk {'print $2'}) /media/files  ext4    defaults,noatime  0       1" | sudo tee -a /etc/fstab
```

Add our user so we can have access to file share (we also create sftpgroup that will make the users belonging to this group have access to sftp):

```
sudo lxc exec $CONTAINER -- groupadd sftpgroup
sudo lxc exec $CONTAINER -- useradd "$CLIENT_USER" -G sftpgroup -m -s /sbin/nologin
sudo lxc exec $CONTAINER -- passwd "$CLIENT_USER"
```

Move all homes to /mnt, so we can make this external hdd the default home directory later:

```
sudo lxc exec $CONTAINER -- chown root:root /mnt
sudo lxc exec $CONTAINER -- mv /home/* /mnt
```

Now mount /mnt in home automatically at container startup:

```
sudo lxc exec $CONTAINER -- bash -c "echo '/mnt /home none bind' >> /etc/fstab" 
```

Fix permissions on /home so we can use sftp successfully:

```
sudo lxc exec $CONTAINER -- bash -c "for i in $(ls /home) ; do chown root:root /home/$i ; done"
sudo lxc exec $CONTAINER -- bash -c "for i in $(ls /home) ; do chmod 755 /home/$i ; done"
```

Install ssh server and enable it:

```
sudo lxc exec $CONTAINER -- dnf install openssh-server -y
sudo lxc exec $CONTAINER -- systemctl enable sshd
sudo lxc exec $CONTAINER -- systemctl start sshd
```

Before finally finishing, we need to lock each user to its home. Add the following lines to the ssh server config file:

```
sudo lxc exec $CONTAINER -- sed -i '\/usr\/libexec\/openssh\/sftp-server/c\#Subsystem sftp \/usr\/libexec\/openssh\/sftp-server' /etc/ssh/sshd_config
sudo lxc exec $CONTAINER -- bash -c "cat <<EOF >> /etc/ssh/sshd_config
Subsystem sftp /usr/lib/openssh/sftp-server
    Match Group sftpgroup
    ChrootDirectory %h
    ForceCommand internal-sftp
    X11Forwarding no
    AllowTcpForwarding no
EOF"
```

Redirect an external port to the container ssh port:

```
sudo lxc config device add $CONTAINER $SSH_DEVICE_NAME proxy listen=tcp:0.0.0.0:$SSH_EXTERNAL_PORT connect=tcp:127.0.0.1:22
```

Restart the container:

```
sudo lxc restart $CONTAINER
```

You should be able to connect via sftp on <HOST_IP>:$SSH_EXTERNAL_PORT, to mount an sftp filesystem on linux, you can use:

```
sudo sshfs -o allow_other,default_permissions,ssh_command='ssh -p $SSH_EXTERNAL_PORT' $CLIENT_USER@<HOST_IP>:/ /path/to/mount/dir
```

If needed, you can set permissions for your username on its home:

```
sudo lxc exec $CONTAINER -- chown -R $CLIENT_USER:$CLIENT_USER /mnt/$CLIENT_USER
```

And... We're done!
