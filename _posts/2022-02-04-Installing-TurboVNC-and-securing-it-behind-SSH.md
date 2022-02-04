---
layout: post
title:  "Installing TurboVNC and securing it behind SSH"
date:  2022-02-04 13:47:48 UTC00 
categories: english linux turbovnc
---

# Installing TurboVNC and securing it behind SSH 

I needed remote access to an Elementary OS host, this was my setup to have a remote access to it. A nice thing about TurboVNC is that it has encryption builtin, so you don't need to protect it via an SSH tunnel.

## Export Variables

Some variables to make this easier to work with:

```
export USERNAME="marcocspc"
```

## Setting up TurboVNC with Google Authenticator

First update packages list:

```
sudo apt update
```

Then install TurboVNC:

```
sudo apt install turbovnc
```

Also install required dependencies to configure google authenticator login:

```
sudo apt install libpam-oath oathtool twm
```

Then create a turbovnc file in pam.d (copy and paste all lines at once):

```
sudo bash -c "cat << EOF > /etc/pam.d/turbovnc
#%PAM-1.0
auth requisite pam_oath.so usersfile=/etc/users.oath
account include system-auth
password include system-auth
session include system-auth
EOF"
```

Fix permissions:

```
sudo chown root:root /etc/pam.d/turbovnc && sudo chmod 644 /etc/pam.d/turbovnc
```

Generate a key for your user. This key will be used in Google Authenticator to register password generation.

```
key=$(head -10 /dev/urandom | md5sum | cut -b 1-30)
sudo bash -c "echo 'HOTP/T30 $USERNAME - $key' >> /etc/users.oath"
```

Fix permissions again:

```
sudo chmod u+s /opt/TurboVNC/bin/Xvnc
```

Get the Base32 version of your key:

```
sudo oathtool --totp -v $key | grep Base32
```

With this key in hand, create a new account on your Google authenticator app by using manual entry. Every time you login to your VNC server, use the code provided by the google authenticator as password. After this, run the following to allow only encrypted connections to the VNC server:

```
sudo bash -c "echo 'permitted-security-types = TLSPlain, X509Plain' >> /etc/turbovncserver-security.conf "
```

Turn turbovnc into a service:

```
sudo bash -c "cat <<EOF > /etc/systemd/system/turbovnc.service
[Unit]
Description=TurboVNC Desktop

[Service]
Type=forking
User=$USERNAME
Group=$USERNAME
Environment=DISPLAY=:1
ExecStart=/opt/TurboVNC/bin/vncserver -vgl 
ExecStop=/opt/TurboVNC/bin/vncserver -kill :1

[Install]
WantedBy=multi-user.target
EOF"
```

** WARNING ** : Sometimes, your host might be already using the :1 display, so the ExecStop command above might not work. To circumvent this problem, run the command `/opt/TurboVNC/bin/vncserver -list` to check the display your server is running (remember to start it before with systemctl start). Then, with the correct display number you can fix the file above. Unfortunately there is no automated way to do this.

After this you may enable and start the service:

```
sudo systemctl enable turbovnc
sudo systemctl start turbovnc
```

Create a startup script for Pantheon (elementaryOS desktop manager):

```
cp /home/$USERNAME/.vnc/xstartup.turbovnc /home/$USERNAME/.vnc/xstartup.turbovnc.bak
bash -c "cat <<EOF > /home/$USERNAME/.vnc/xstartup.turbovnc
#!/bin/sh

io.elementary.wingpanel &
plank &
exec gala

EOF"
```

Make it executable:

```
chmod +x /home/$USERNAME/.vnc/xstartup.turbovnc
```

When connecting using your preferred VNC client, use your server IP, port 5901 (for display :1, for display :2, use 5902, and so on). Insert $USERNAME as user and your google authentication code as password. Try it out!

## Hints for iOS

If you're tying to connect in iOS (as was I), use bVNC pro as it is the only client that supports VeNCrypt on the system (it won't ask for a password, so you need to input the generated one from google authenticator in the connection config every time). 

If you do not want to use it, I recommend disabling all the encryption by replacing the line `ExecStart=/opt/TurboVNC/bin/vncserver -vgl` with `ExecStart=/opt/TurboVNC/bin/vncserver -vgl -securitytypes None` in `/etc/systemd/system/turbovnc.service`. This is needed because TurboVNC does not allow "None" to be used in the `/etc/turbovncserver-security.conf` file.

Also, I should recommend disabling direct connections from hosts and allowing only via SSH Tunnel. To do this, edit the same line from `/etc/systemd/system/turbovnc.service`, setting ExecStart to `ExecStart=/opt/TurboVNC/bin/vncserver -vgl -securitytypes None -localhost`. This will effectively only allow connections incoming from SSH tunnels.

It is also important to point out that I did NOT test this setup, so you should read the references below if anything goes wrong.

Aaaaaaaaaand we're done!!

## References

[User’s Guide for TurboVNC 2.2.7](https://rawcdn.githack.com/TurboVNC/turbovnc/2.2.7/doc/index.html#hd006005)
[Disable password for vnc #74](https://github.com/TurboVNC/turbovnc/issues/74)
[Using TurboVNC with Time-Based One-Time Passwords (TOTP)](https://turbovnc.org/Documentation/TOTP)
