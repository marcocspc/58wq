---
layout: post
title:  "Setting up Wake-On-Lan on my Proxmox Host"
date:  2023-01-14 19:05:29 -0300 
categories: english linux proxmox
---

# Setting up Wake-On-Lan on my Proxmox Host 

I needed to wake my host remotely, I wrote this to remember how I did this.

By the way, my motherboard was ASRock H110M-HG4

## Bios Setup

First thing I needed to do was to enter the bios and enable Wake-on-Lan there. Boot up the host and keep pressing F2 until you reach the bios screen:

![]({{ site.baseurl }}/assets/images/h110m-hg4-wake-on-lan-tutorial/1.png)

Then press F6 to go into advanced mode:

![]({{ site.baseurl }}/assets/images/h110m-hg4-wake-on-lan-tutorial/2.png)

Once there, go to Advanced > ACPI Configuration:

![]({{ site.baseurl }}/assets/images/h110m-hg4-wake-on-lan-tutorial/3.png)

Then enable "PCIE Devices Power On":

![]({{ site.baseurl }}/assets/images/h110m-hg4-wake-on-lan-tutorial/4.png)

Finally press F10 and save the configuration:

![]({{ site.baseurl }}/assets/images/h110m-hg4-wake-on-lan-tutorial/5.png)

The host will reboot into proxmox, once booted up SSH into it. We will use ethtool to enable Wake-on-lan every reboot. This is needed because if you shutdown the PC, the OS will somehow disable this feature. By running this command every reboot you will be able to turn on and shutdown remotely.

Install ethtool:

```
apt install ethtool -y
```

Enable wake-on-lan every reboot:

```
# on the proxmox host terminal:
crontab -l | { cat; echo "@reboot /usr/sbin/ethtool -s enp3s0 wol g"; } | crontab -
```

Make sure you reclaced enp3s0 with your interface name, sometimes its name can be eth0. Also, run this to enable wake-on-lan NOW:

```
/usr/sbin/ethtool -s enp3s0 wol g
```

Shutdown and send an wake on lan packet to test if it went well. If yes, we're done!
