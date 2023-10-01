---
layout: post
title:  "Flashing Archer C20 with OpenWRT for my father"
date:  2023-10-01 10:02:37 -0300 
categories: english linux openwrt  
---

# Flashing Archer C20 with OpenWRT for my father 

My father has been complaining a lot about his current router (which is indeed an Archer C20, but version 4), and I've decided to get a new one to him. His current router has a few issues with its wi-fi driver, and since I already installed an Archer C20 v5.0 in my mother-in-law's house and the result was very good, I've decided to take another of these models for my father. 

The problem is that the router I bought isn't exactly C20 V5.0, it is the V5.0(W). And this *make one hell of a difference*. Basically, this router has the same hardware as version 4, hence while writing this, I've not only bricked this brand new router a few times (because I was using openwrt image for the 5.0(EUR) version of this router), but I also suspect that it might present the same issues as my father's current router.

But in the name of science I'm going to try this device out. 

Also, another highlight that I want to write here is that since I've spent my entire Saturday trying to figure out how I would unbrick this device, I will leave the last section of this post to show how I unbricked it and restored the original firmware. Believe-me, there's a catch.

And finally, the main reason for this post is to document the flashing phase of this router. It is pretty common that these devices use tftp as one of the available flashing methods, and I always find myself googling for small tftp servers that I can run in one line command, just to serve OpenWRT's binary to a particular router.

## Downloading OpenWRT

According to [this page](https://wireslab.org/openwrt-tp-link-archer-c20-v5-0/), one must use Archer C20 V4.0 openwrt image when altering the firmware of this router. So [here](https://openwrt.org/toh/tp-link/archer_c20_v4) is the link to the current supported version of OpenWRT for version 4, which os OpenWRT 22.03.5. It can be downloaded it like this:

```
# wget can also be used, I on the other hand prefer aria2
aria2c -o openwrt-tftp-recovery.bin  -x 16 -s 16 https://downloads.openwrt.org/releases/22.03.5/targets/ramips/mt76x8/openwrt-22.03.5-ramips-mt76x8-tplink_archer-c20-v4-squashfs-tftp-recovery.bin
```

Now to the tftp part!

## Copying the file and running the tftp server

To serve the file via tftp, it must be put in a folder, preferably, alone. So the folder was created:

```
mkdir -p tftp
```

And the file was copied:

```
cp openwrt-tftp-recovery.bin tftp/tp_recovery.bin
```

The tftp server used in this process was ptftpd. It is written in Python and allow one to quick summon a tftp server inside a shell session. Before using ptftpd, of course, the software had to be installed and some network configuration made. How this was done, of course, will be shown later in this text. First, for the installation, a venv folder was created:

```
python3 -m venv ~/env/ptftpd
```

Then the virtual environment was activated:

```
source ~/env/ptftpd/bin/activate
```

And ptftpd installed:

```
pip install ptftpd
```

This should be it for the tftp server installation. But before running it, though, the network interface must be set up. On MacOS the IP was set up using this command:

```
sudo ifconfig en2 inet 192.168.0.66/24
```

As it is shown in the above command, the interface name was `en2`. This is a parameter used to run ptftpd. Sudo is required because it must run in a lower port:

```
sudo ptftpd -v -p 69 en2 ./tftp
```


The `./tftp` indicates what directory that ptftpd will use as root. The `-v` flag indicates ptftpd to be a little verbose, without it the server is completely silent.

## Flashing the router

With the server running, it is just a matter of turning on the router correctly. It has a woggle button on its back. If the router is already on, the button can be pressed to shutdown the router. After this, it should be turned on while pressing the reset button for 10 seconds, the device will start to flash itself once only the power and lan leds are on. **THE BUTTON MUST NOT BE RELEASED BEFORE THE ROUTER FINISHES DOWNLOADING THE FIRMWARE**. This is the output of ptftpd:

```
INFO(tftpd): Serving TFTP requests on en2/192.168.0.66:69 in ~/Downloads/tplink_project/tftp
INFO(tftpd): Serving file tp_recovery.bin to host 192.168.0.2...
INFO(tftpd): Transfer of file tp_recovery.bin completed.
```

Once the third line of the output above is shown, the reset button can be released. Also, the server can be stopped by hitting Ctrl + C in the terminal. In about 1 minute, the router should reset. It will remain with only its power led on (it may take some time, around 10 minutes or so). It will be done once the LAN led lights up again, the device will start serving DHCP leases on its LAN interface. To tell whether the process finished or not, change your interface configuration to DHCP client and connect a cable between your station and the router. If the IP received was of the rage 192.168.1.0/24, Luci Web Interface will be available at 192.168.1.1. 

To set the interface to DHCP using ipconfig (MacOS):

```
sudo ipconfig set en2 DHCP
```

At this point the router will be running OpenWRT.

## Bringing the Router back from the dead (unbricking TP-Link Archer C20 W)

Before finally getting this router to work, I bricked it a few times (twenty times, maybe? LOL). It was a lot of trial and error before finding the right way to do so. So this section is just to document it.

The gotcha part of this process is just to prepare the `tp_recory.bin` file the correct way. It happens that these recovery files from TP-Link differ from the official image just by removing the first 512 bytes from the binary. To proceed, of course, first it is needed to download the official stock firmware to TP-Link Archer C20 V5 (W). In this context, the work will be done in an empty directory, so it is advised to create one and enter it:

```
mkdir recovery-project && cd recovery-project
```

Download the official image:

```
aria2c -o archer-tp-link.rar -x 16 -s 16 "https://static.tp-link.com/2020/202006/20200605/Archer%20C20W_v5.rar"
```

Extract the binary and remove unwanted files:

```
#to install unrar on mac: brew install rar
unrar x archer-tp-link.rar
rm *.pdf *.zip
```

Rename the binary to `tp_original.bin`

```
mv Archer*/Archer*.bin tp_original.bin
```

Remove the folder and the `.rar` file:

```
rm -rf Archer*/ *.rar
```

Strip the first 512 bytes out:

```
# this takes a few seconds
dd if=tp_original.bin of=tp_recovery.bin bs=1 skip=512
```

Then the firmware is ready, refer to the TFTP section of this documentation to see how to flash the router using ptftpd, resetting the router to recovery mode, etc.

After the flashing is done, the router will reset and keep shining just the power led for a lot of minutes before starts working again.

Aaaaaand we're done!
