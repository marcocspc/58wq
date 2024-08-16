---
layout: post
title:  "Reinstalling Proxmox on my Desktop (again)"
date:  2024-01-20 20:07:23 -0300 
categories: english linux proxmox
---

# Reinstalling Proxmox on my Desktop (again) 

Finally, my i9 9900 arrived. Two years ago I've bought the Mortar B360M motherboard in order to "start to build my new PC". And, yeah, it took two years till I bought the new processor LOL.

I will be updating my previous documentation on [how I installed Proxmox on my host]({% post_url 2022-12-04-Reinstalling-Proxmox-on-my-Desktop %}) with new information. So, for those who read that (ha! Sometimes I tend to believe that someone else reads this b*llsh*t I write) please know that instead of referencing that text, I will be copying and pasting a lot from there.

As I did in that previous post, this is the current configuration of this Desktop:
Processor: i9 9900
Motherboard: Mortar B360M
RAM: 24GB
VGA: GTX 1060 6GB (Please forgive-me, I WILL buy a new GPU this year. I promise.)

## From dust to dust, from the ground up. All over again.

Here we go documenting what comes before installing Proxmox. This time around, thankfully, I have [PiKVM](https://pikvm.org) by my side. So my back will thank me for not having to stand-up and go to my desktop to do stuff (except that one time I'll need to insert the USB flash drive to install proxmox). Also, taking screenshots will be a lot easier.

Anyways, once I booted up the Desktop for the first time, I didn't get any image. I've spent two days to discover the following:

- I was using a bad power brick for my Orange Pi Zero, hence it couldn't power on the USB HDMI capture card (and I didn't test the desktop on a monitor. I know, I know...);
- I installed the GPU and I was using the motherboard's HDMI.

But that said and solved, I could go on and continue with the motherboard basic configuration.

First thing I should do was to enable Wake-on-Lan, since I'd be doing a lot of restarts and shutdowns during this process. On this motherboard, after getting to the main setup screen, I had to hit F7 to go to advanced mode. The next two screenshots shows this:

![]({{ site.baseurl }}../assets/images/mortar-b360m-proxmox/1.png)
![]({{ site.baseurl }}../assets/images/mortar-b360m-proxmox/2.png)

Then I had to go to Settings > Advanced > Wake Up Event Setup and enable "Resume By Onboard Intel Lan":

![]({{ site.baseurl }}../assets/images/mortar-b360m-proxmox/3.png)

After that I pressed Esc twice and, while under Settings again, I went into Boot and setted USB Key as the first boot option, since I was going to install Proxmox.

![]({{ site.baseurl }}../assets/images/mortar-b360m-proxmox/4.png)
![]({{ site.baseurl }}../assets/images/mortar-b360m-proxmox/5.png)

After that I pressed F10 and saved:

![]({{ site.baseurl }}../assets/images/mortar-b360m-proxmox/6.png)

The PC restarted but then I realized I needed to enable some settings in order to enable GPU passthrough in Proxmox. So after the BIOS setup screen was shown again, I went to OC Settings > CPU Features:

![]({{ site.baseurl }}../assets/images/mortar-b360m-proxmox/7.png)

And enabled intel VT-d Tech:

![]({{ site.baseurl }}../assets/images/mortar-b360m-proxmox/8.png)

Also, I changed the main graphics adapter to motherboard. I pressed Esc until I was on the main screen again and went to Settings > Avanced > Integrated Graphics Configuration and setted Initiate Graphics Adapter to IGD:

![]({{ site.baseurl }}../assets/images/mortar-b360m-proxmox/9.png)

I then pressed F10 and saved. After this I connected the HDMI cable to the motherboard in order to get image again. Also I had to manually shutdown and turn on the Desktop manually.

## Installing Proxmox

After I downloaded the most recent Proxmox ISO and loaded it on an USB Flash Drive with Balena Etcher, I inserted it on one of the two USB 2.0 ports in the motherboard IO. Since I've already set the USB Key as the first boot option, I've automatically got to the installer screen:

![]({{ site.baseurl }}../assets/images/mortar-b360m-proxmox/10.png)

I've chose the Grpahical Install option and waited it to load up until I got to this screen:

![]({{ site.baseurl }}../assets/images/mortar-b360m-proxmox/11.png)

I've read through until the end and pressed Enter to accept. I then was presented to this screen in which I pressed Enter since I had only on disk to choose from:

![]({{ site.baseurl }}../assets/images/mortar-b360m-proxmox/12.png)

Next screen was just to choose my region and timezone settings:

![]({{ site.baseurl }}../assets/images/mortar-b360m-proxmox/13.png)

Admin e-mail and password:

![]({{ site.baseurl }}../assets/images/mortar-b360m-proxmox/14.png)

Finally the next screen was to set the DNS name and IP settings:

![]({{ site.baseurl }}../assets/images/mortar-b360m-proxmox/15.png)

The next screen was just a summary. So no screenshot for that one.

## The license annoyance

When the system rebooted after installation, I was prompted to login using my root user credentials. I wanted to access my proxmox server through the network, so I did it via SSH.

I could also get to the proxmox web interface by typing http://your.host.ip:8006/ in my web browser. One thing, by the way, that ALWAYS annoys me, is the license nag that shows up every time I login via web. Let's take care of this then:

```
sed -Ezi.bak "s/(Ext.Msg.show\(\{\s+title: gettext\('No valid sub)/void\(\{ \/\/\1/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js && systemctl restart pveproxy.service
```

PS.: If Proxmox is still showing the nag, try accessing it via a private window. If it works it's just a cache issue.

I also change the sources.list entry to the community one (I can only use proxmox's official repository if I pay for the license):

```
cat << EOF > /etc/apt/sources.list.d/pve-community.list
# non production use updates
deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription
EOF
```

Commented out the enterprise one:

```
sed -i '1 s/^/#/' /etc/apt/sources.list.d/ceph.list
```

Then updated the repositories:

```
apt update
```

Upgraded the system:

```
apt upgrade -y
```

## Some useful packages

I installed these packages to make my life easier:

- Lynx - a command line browser. Sometimes I needed it.
- Docker and docker-compose - run containers of course
- Neovim - my favorite text editor
- Tmux - to run multiple terminals
- Mosh - to have a snappier connection when accessing my desktop from far away.
- htop - check CPU usage on terminal
- ethtool - enable wake-on-lan on linux

```
apt install lynx docker.io docker-compose tmux neovim mosh htop -y
```

## Wake-On-Lan

In order to enable wake-on-lan every reboot, I ran:

```
# on the proxmox host terminal:
crontab -l | { cat; echo "@reboot /usr/sbin/ethtool -s eno1 wol g"; } | crontab -
```

Also, I ran this to enable wake-on-lan immediately:

```
/usr/sbin/ethtool -s eno1 wol g
```

I've turned off and sent an wake on lan packet to test if it went well. It went, so I could keep going.

## GPU passthrough

This was basically a repetition of [Proxmox's official guide](https://pve.proxmox.com/wiki/Pci_passthrough), but highlighting the commands that worked out for me.

OK, first thing was to enable IOMMU, to do this, I edited /etc/default/grub and added "intel_iommu=on" to GRUB_CMDLINE_LINUX_DEFAULT. After adding it, the line looked like this:

```
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on"
```

In one line:

```
cp /etc/default/grub /etc/default/grub.bak && sed -i '/GRUB_CMDLINE_LINUX_DEFAULT/c\GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on"' /etc/default/grub && cat /etc/default/grub
```

Updated grub:

```
update-grub
```

Then rebooted:

```
reboot
```

Once logged in again, checked if iommu was indeed enabled:

```
dmesg | grep -e DMAR -e IOMMU
```

The output should look something like this:

```
...
[    0.042446] DMAR: IOMMU enabled
...
```

Then it worked. According to the original guide, if something went wrong, the output would be empty.

Next I enabled the needed modules:

```
cp /etc/modules /etc/modules.bak && cat << EOF >> /etc/modules
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
EOF
```

I created a blacklist of all nvidia drivers on the host (I also blacklisted radeon here, just in case). This was needed to leave the video card alone so my VM could own it:

```
cat << EOF >> /etc/modprobe.d/gpublacklist.conf
blacklist radeon
blacklist nouveau
blacklist nvidia
EOF
```

I had to get my PCI Express VGA address, to do this I ran this command:

```
lspci -n -s 01:00
```

This was my output, for example:

```
01:00.0 0300: 10de:1c03 (rev a1)
01:00.1 0403: 10de:10f1 (rev a1)
```

My VGA had the address 10de:1c03 and its audio device had the address 10de:10f1. I used these addresses in this command:

```
echo "options vfio-pci ids=10de:1c03,10de:10f1" > /etc/modprobe.d/vfio.conf
```

I rebooted. This was it for the passthrough on the host.

## Restoring the VMs

The only right move I did while upgrading this processor was backing up the old VMs I had. To restore them I connected my external HDD to my Desktop and mounted it in /mnt:

```
mount /dev/sda1 /mnt
```

Then I could restore all VMs:

```
qmrestore /mnt/dump/*100*.zst 100
qmrestore /mnt/dump/*101*.zst 101
```

This process lasted more than three hours. After that the VMs were restored successfully.
