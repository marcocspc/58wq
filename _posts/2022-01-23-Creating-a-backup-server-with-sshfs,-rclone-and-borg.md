---
layout: post
title:  "Creating a backup server with lxd, ssh, rclone and borg"
date:  2022-01-23 17:35:04 -0300 
categories: english linux backup
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
export BKPUSERNAME=borgbackup
export BORGSERVERIP=iss.shadow.local
export BORGSERVERPORT=2223
export RCLONEDOWNLOAD=https://downloads.rclone.org/rclone-current-linux-arm.zip
export RCLONEPKG=$(basename $RCLONEDOWNLOAD)
export SSHFSSERVERIP=192.168.0.15
export SSHFSSERVERPORT=2222
export SSHFSUSER=kibo
export SSHFSFOLDER=/home/$BKPUSERNAME/sshfsbackup
export CLIENT=lua
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

Now let's config rclone to automount our drive folder at boot. Create a systemd service file:

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
ExecStart=/usr/bin/rclone mount --daemon --allow-other googledrive:/ /home/$BKPUSERNAME/gdrivebackup
ExecStop=/bin/fusermount -u /home/$BKPUSERNAME/gdrivebackup
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
EOF"
```

Allow all users to use the "allow-other" flag (a reboot is needed):

```
sudo lxc exec $CONTAINER -- bash -c "echo user_allow_other >> /etc/fuse.conf"
sudo lxc restart $CONTAINER 
```

Enable and start the service:

```
sudo lxc exec $CONTAINER -- bash -c "systemctl enable rclonegdrive && systemctl start rclonegdrive"
```

## The sshfs folder

So, besides serving a drive folder to store the backups remotely, I can also have one folder mounted via sshfs. I also document this way of connecting to a remote server mainly because this will serve as my local backup, since my sshfs server is on my local network.

First, create a backup share on your server using [my tutorial](https://marcocspc.github.io/58wq/english/linux/lxd/2021/12/03/SSH-File-Server-on-a-LXD-Container.html) (remember to set an ssh key so you can mount your shared folder without password prompting and *make sure* that the location and permissions of authorized keys file respects the instructions on the tutorial). After this, we go and mount this shared folder in our backup directory. To do this, we need sshfs, so install this on your backup server:

```
sudo lxc exec $CONTAINER -- apt install sshfs
```

Now we create the folder where the ssh share will be mounted:

```
sudo lxc exec $CONTAINER -- mkdir -p /home/$BKPUSERNAME/sshfsbackup/
sudo lxc exec $CONTAINER -- chown -R $BKPUSERNAME:$BKPUSERNAME /home/$BKPUSERNAME/sshfsbackup
```

*Remember to create and authorize the ssh key of your backup server on the sshfs server.*
*Also check home permissions on the file server or you may encounter permission denied errors.*

Next, we test if the mount is working:

```
sudo lxc exec $CONTAINER -- sshfs  -p $SSHFSSERVERPORT -o allow_other,IdentityFile=/home/$BKPUSERNAME/.ssh/id_rsa $SSHFSUSER@$SSHFSSERVERIP:/ $SSHFSFOLDER
```

Then we need to make this permanent by adding a sshfs entry to /etc/fstab. Run this:

```
sudo lxc exec $CONTAINER -- cp /etc/fstab /etc/fstab.bak #in case something goes wrong
sudo lxc exec $CONTAINER -- echo "$SSHFSUSER@$SSHFSSERVERIP:/ $SSHFSFOLDER fuse.sshfs allow_other,_netdev,port=$SSHFSSERVERPORT,IdentityFile=/home/$BKPUSERNAME/.ssh/id_rsa,reconnect 0 0" >> /etc/fstab
```

Finally, with the folder mounted, create a folder inside it where we will store the backup. This is needed because of (again) the file permissions inside the sftp server:

```
sudo lxc exec $CONTAINER -- mkdir -p /home/$BKPUSERNAME/sshfsbackup/backups
```

## Borg Server

Setting up a borg server is as easy as adding a key to an ssh server. Because all the backup configuration is done in the client. The only thing we want to do is generate a key pair on the client, authorize it in the server, limit the folders the client may write to and edit some keepalive settings. Then we write a script in the client to backup to the repo we've setup.

So, let's go *in the client* and generate an ssh key pair. Run these *as root*:

```
ssh-keygen
```

Leave everything as default and get the public key:

```
cat /root/.ssh/id_rsa.pub
```


Copy the string (that starts at "ssh-rsa" and ends at "some-user@some-host"). Then let's go *to the server*. First, let's create the directories that the client will write its backup to:

```
sudo lxc exec $CONTAINER -- mkdir -p /home/$BKPUSERNAME/gdrivebackup/backups/$CLIENT
sudo lxc exec $CONTAINER -- mkdir -p /home/$BKPUSERNAME/sshfsbackup/backups/$CLIENT
```

Then we authorize (and LIMIT) the client to write in these two directories:

```
sudo lxc exec $CONTAINER -- mkdir -p /home/$BKPUSERNAME/.ssh
sudo lxc exec $CONTAINER -- bash -c "echo 'command=\"/usr/bin/borg serve --restrict-to-path /home/$BKPUSERNAME/gdrivebackup/backups/$CLIENT --restrict-to-path /home/$BKPUSERNAME/sshfsbackup/backups/$CLIENT\" <id_rsa.pub content here>' >> /home/$BKPUSERNAME/.ssh/authorized_keys"
```

Remember that id_rsa.pub content we copied above? Replace <id_rsa.pub content here> with it:

```
sudo lxc exec $CONTAINER -- vi /home/$BKPUSERNAME/.ssh/authorized_keys"
```

Fix permissions:

```
sudo lxc exec $CONTAINER -- chmod -R 700 /home/$BKPUSERNAME/.ssh
sudo lxc exec $CONTAINER -- chown -R $BKPUSERNAME:$BKPUSERNAME /home/$BKPUSERNAME/.ssh
```

Finally, make sure sshd installed and running, and expose your container ssh port:

```
sudo lxc exec $CONTAINER -- apt install ssh -y 
sudo lxc config device add $CONTAINER ssh2223 proxy listen=tcp:0.0.0.0:$BORGSERVERPORT connect=tcp:127.0.0.1:22
```

Now we can go to the client and init our backup repository. We need a password first, though. To do this we use openssl to help us. Let's install then *in the client as root*:

```
apt install openssl
```

Now generate a password. **Remember to store this password somewhere, in case you need to restore your backup, you will need this key!!!!!**

```
openssl rand -base64 32 > ~/.secret && cat .secret
```

Now, let's initialize our backup repository, we are still running commands in the client. First install borgbackup:

```
apt install borgbackup
```

Then we init both of our repositories:

```
BORG_REPO=ssh://$BKPUSERNAME@$BORGSERVERIP:$BORGSERVERPORT/~/gdrivebackup/backups/$CLIENT BORG_PASSPHRASE=$(cat ~/.secret) borg init -e repokey
BORG_REPO=ssh://$BKPUSERNAME@$BORGSERVERIP:$BORGSERVERPORT/~/sshfsbackup/backups/$CLIENT BORG_PASSPHRASE=$(cat ~/.secret) borg init -e repokey
```

Then we get our repository keys that ALSO need to be backuped in case these keys get lost or corrupted. This is also needed because we need our passphrase *AND* the keyfile to access our files when restoring them. Run this to get the keys:

```
borg key export ssh://$BKPUSERNAME@$BORGSERVERIP:$BORGSERVERPORT/~/gdrivebackup/backups/$CLIENT gdrive_$CLIENT.key
borg key export ssh://$BKPUSERNAME@$BORGSERVERIP:$BORGSERVERPORT/~/sshfsbackup/backups/$CLIENT sshfs_$CLIENT.key
```


Now we can create a backup to test if everything is working. Create a folder and a file inside that folder:

```
mkdir -p ~/testfolder
touch ~/testfolder/testfile.txt
```

Now let's test if we can backup our file to our borg server:

```
BORG_REPO=ssh://$BKPUSERNAME@$BORGSERVERIP:$BORGSERVERPORT/~/gdrivebackup/backups/$CLIENT BORG_PASSPHRASE=$(cat ~/.secret) borg create ::Test ~/testfolder
BORG_REPO=ssh://$BKPUSERNAME@$BORGSERVERIP:$BORGSERVERPORT/~/sshfsbackup/backups/$CLIENT BORG_PASSPHRASE=$(cat ~/.secret) borg create ::Test ~/testfolder
```

If your output was nothing, then it wen allright. You may also go to your server and list the files inside those directories and see if something was created there:

```
sudo lxc exec $CONTAINER -- ls -l /home/$BKPUSERNAME/gdrivebackup/backups/$CLIENT
sudo lxc exec $CONTAINER -- ls -l /home/$BKPUSERNAME/sshfsbackup/backups/$CLIENT
```

Your output maybe something like this:

```
-rw-r--r-- 1 borgbackup borgbackup    73 Jan 23 22:32 README
-rw-r--r-- 1 borgbackup borgbackup   700 Jan 23 22:33 config
drwxr-xr-x 1 borgbackup borgbackup     0 Jan 23 22:32 data
-rw-r--r-- 1 borgbackup borgbackup    52 Jan 23 23:03 hints.5
-rw-r--r-- 1 borgbackup borgbackup 41258 Jan 23 23:03 index.5
-rw-r--r-- 1 borgbackup borgbackup   190 Jan 23 23:03 integrity.5
-rw-r--r-- 1 borgbackup borgbackup    16 Jan 23 23:02 nonce
```

Now we know that our server is set up, running and working. We can now create our backup script. You can base yours on [this one](https://borgbackup.readthedocs.io/en/stable/quickstart.html#automating-backups) or on [my script](https://github.com/marcocspc/scripts/blob/master/linux/lxd_borg_backup.sh) if you are backuping lxc containers as I am. Anyway, I'm going to paste [borg official example](https://borgbackup.readthedocs.io/en/stable/quickstart.html#automating-backups) here just to *backup* it. Pun intended.

```
#!/bin/sh

# Setting this, so the repo does not need to be given on the commandline:
export BORG_REPO=ssh://username@example.com:2022/~/backup/main

# See the section "Passphrase notes" for more infos.
export BORG_PASSPHRASE='XYZl0ngandsecurepa_55_phrasea&&123'

# some helpers and error handling:
info() { printf "\n%s %s\n\n" "$( date )" "$*" >&2; }
trap 'echo $( date ) Backup interrupted >&2; exit 2' INT TERM

info "Starting backup"

# Backup the most important directories into an archive named after
# the machine this script is currently running on:

borg create                         \
    --verbose                       \
    --filter AME                    \
    --list                          \
    --stats                         \
    --show-rc                       \
    --compression lz4               \
    --exclude-caches                \
    --exclude '/home/*/.cache/*'    \
    --exclude '/var/tmp/*'          \
                                    \
    ::'{hostname}-{now}'            \
    /etc                            \
    /home                           \
    /root                           \
    /var                            \

backup_exit=$?

info "Pruning repository"

# Use the `prune` subcommand to maintain 7 daily, 4 weekly and 6 monthly
# archives of THIS machine. The '{hostname}-' prefix is very important to
# limit prune's operation to this machine's archives and not apply to
# other machines' archives also:

borg prune                          \
    --list                          \
    --prefix '{hostname}-'          \
    --show-rc                       \
    --keep-daily    7               \
    --keep-weekly   4               \
    --keep-monthly  6               \

prune_exit=$?

# use highest exit code as global exit code
global_exit=$(( backup_exit > prune_exit ? backup_exit : prune_exit ))

if [ ${global_exit} -eq 0 ]; then
    info "Backup and Prune finished successfully"
elif [ ${global_exit} -eq 1 ]; then
    info "Backup and/or Prune finished with warnings"
else
    info "Backup and/or Prune finished with errors"
fi

exit ${global_exit}
```

Finally, after editing your script make it executable `chmod +x script.sh` and register it to run once a week by adding the following line to `crontab -e`:

```
# Runs and 00h:01m every sunday
1 0 * * 6 <PATH_TO_YOUR_SCRIPT.sh>
```

PS.: remember to test it.

Aaaaand we're done!
