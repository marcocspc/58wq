---
layout: post
title:  "Reinstalling Proxmox on my Desktop"
date:  2022-12-04 14:44:24 -0300 
categories: english linux proxmox  
---

# Reinstalling Proxmox on my Desktop 

Sigh. My Desktop just got back home again. And, well, its hdd just got corrupted with all my vms, proxmox installation and games. That's nice. You can imagine how happy I am now.

Anyways, this post is about documenting the process to reinstall and share my pci express vga again. Let's do this!

Oh, and before anything, a quick description of my hardware, this will help me to understand what my pc was at this point in time:
Processor: i5 7400
Motherboard: H110M-HG4
RAM: 24GB
VGA: GTX 1060 6GB

## From the ground up

Since I was going to document everything from the beginning, I thought about writing stuff that happens *before* Proxmox installation. So what I did was to restore the factory defaults in my bios. Here I will be writing (and hopefully showing) the configuration I did in the bios setup step-by-step.

Ok, when I booted up no image was shown in the onboard hdmi output. This meant that the motherboard recognized my gtx 1060 as the default adapter. This meant I had to change this setting. This was the path:

- Press F2 while booting to enter setup;
- Once on this screen press F6 to go to advanced mode:
![]({{ site.baseurl }}/assets/images/proxmox-gpu-passthrough-tutorial/1.png)
- Then go to Advanced > Chipset Configuration:
![]({{ site.baseurl }}/assets/images/proxmox-gpu-passthrough-tutorial/2.png)
- Then change Primary Graphics Adapter from Pci Express to Onboard:
![]({{ site.baseurl }}/assets/images/proxmox-gpu-passthrough-tutorial/3.png)
- Then hit F10 to save and reset. Change the hdmi cable to the correct output port and go back again to the setup part and press F6.
- Let's fix system date, go to the bottom-right of the screen and click on the timestamp to set up the correct date:
![]({{ site.baseurl }}/assets/images/proxmox-gpu-passthrough-tutorial/4.png)
- Fix your time settings and click OK. Next, go to Advanced > Chipset Configuration and Check if VT-d is enabled (this is needed to do GPU passthrough later):
![]({{ site.baseurl }}/assets/images/proxmox-gpu-password-tutorial/5.png)
- Also check if your HDD is the default boot device. Go to Boot (top of the screen) and check if your HDD is the Boot Option #1:
![]({{ site.baseurl }}/assets/images/proxmox-gpu-password-tutorial/6.png)
- Go to Advanced > Chipset Configuration, scroll all the way down to the bottom of the page and check if Restore on AC/Power Loss settings it set to the desired option. In my case, I needed my desktop ON all the time, so I chose Power On:
![]({{ site.baseurl }}/assets/images/proxmox-gpu-password-tutorial/7.png)
- Check if Serial Port is enabled in Advanced > Super IO Configuration. This is useful if you need to connect to your desktop via serial interface, when you do not have a monitor available.
- Finally, go to Security and click on Supervisor Password to set a new password for your setup:
![]({{ site.baseurl }}/assets/images/proxmox-gpu-password-tutorial/8.png)
- Hit F10 so save and reset.

## Installing Proxmox

Before booting again, insert an USB flash device with Proxmox ISO setup on it. Then, while booting, press F11 to select USB boot (you will be prompted for the admin password): 
![]({{ site.baseurl }}/assets/images/proxmox-gpu-password-tutorial/9.png)
![]({{ site.baseurl }}/assets/images/proxmox-gpu-password-tutorial/10.png)

Once in Proxmox boot logo, select "Install Proxmox VE".
![]({{ site.baseurl }}/assets/images/proxmox-gpu-password-tutorial/11.png)

Click "I Agree" in the license screen (well, otherwise you won't be able to proceed with installation). Then you will be presented with a new screen where you will select the disk where Proxmox will be installed, check if this is really your option (if you need to change your partition setting, click on Option):
![]({{ site.baseurl }}/assets/images/proxmox-gpu-password-tutorial/12.png)

Then you will be presented to a language settings screen: choose your region, keyboard, etc. After this, set your root password in the next screen. Then set your proxmox server network settings:
![]({{ site.baseurl }}/assets/images/proxmox-gpu-passthrough-tutorial/13.png)

Finally review your settings in the last screen and hit Install! The installation will automatically reboot after it finishes. Please be patient.
![]({{ site.baseurl }}/assets/images/proxmox-gpu-passthrough-tutorial/14.png)

## The license annoyance

When the system reboots after installation, you will be prompted to login using your root user credentials. If you want to access your proxmox server through the network, you can already do this via SSH.

You can also get to the proxmox web interface by typing http://your.host.ip:8006/ in your web browser of choice. One thing, by the way, that annoys me, is the license nag that shows up every time I login via web. Let's take care of this then:

```
sed -Ezi.bak "s/(Ext.Msg.show\(\{\s+title: gettext\('No valid sub)/void\(\{ \/\/\1/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js && systemctl restart pveproxy.service
```

Change the sources.list entry to the community one (you can only use proxmox's official repository if you pay for the license). Copy and paste all lines at once:

```
cat << EOF > /etc/apt/sources.list.d/pve-community.list
# non production use updates
deb http://download.proxmox.com/debian/pve bullseye pve-no-subscription
EOF
```

Comment out the enterprise one:

```
sed -i '1 s/^/#/' /etc/apt/sources.list.d/pve-enterprise.list
```

Then update the repositories:

```
apt update
```

If desired, upgrade all packages:

```
apt upgrade -y
```

## Some useful packages

I installed these packages to make my life easier:

- Lynx - a command line browser. Sometimes I needed it.
- Docker and docker-compose - run containers of course
- Tmux - to leave some processes running in the background.
- Vim - my favorite text editor.
- Wireguard - my vpn of choice.
- Proxychains - bypass some wireguard problems.

To install these I ran:

```
apt install lynx docker.io docker-compose tmux vim wireguard proxychains4 -y
```

## GPU passthrough

This is basically a repetition of [Proxmox's official guide](https://pve.proxmox.com/wiki/Pci_passthrough), but highlighting the commands that worked out for me.

OK, first thing is to enable IOMMU, to do this, edit /etc/default/grub and add "intel_iommu=on" to GRUB_CMDLINE_LINUX_DEFAULT. After adding it, the line should look like this:

```
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on"
```

In one line:

```
cp /etc/default/grub /etc/default/grub.bak && sed -i '/GRUB_CMDLINE_LINUX_DEFAULT/c\GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on"' /etc/default/grub && cat /etc/default/grub
```

Update grub:

```
update-grub
```

Then reboot:

```
reboot
```

Once logged in again, check if iommu is indeed enabled:

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

Now let's enable the needed modules:

```
cp /etc/modules /etc/modules.bak && cat << EOF >> /etc/modules
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
EOF
```

Then reboot again. Once logged in, let's blacklist all nvidia drivers on the host (we also blacklist radeon here, just in case). This is needed to leave the video card alone so our VM can own it:

```
cat << EOF >> /etc/modprobe.d/gpublacklist.conf
blacklist radeon
blacklist nouveau
blacklist nvidia
EOF
```
Now go to the terminal on your host again and get your PCI Express VGA address, to do this run this command:

```
lspci -n -s 01:00
```

This was my output, for example:

```
01:00.0 0300: 10de:1c03 (rev a1)
01:00.1 0403: 10de:10f1 (rev a1)
```

We can see that my VGA has the address 10de:1c03 and its audio device has address 10de:10f1. Use these addresses in this command:

```
echo "options vfio-pci ids=10de:1c03,10de:10f1" > /etc/modprobe.d/vfio.conf
```

Once more, reboot. This should do it do the host, let's go to the VM.

## Testing GPU passthrough in a Ubuntu VM

Go to proxmox's web interface on your browser of choice and login as root. (address is https://your.host.ip:8006/)

After this, go to Your host > Local > ISO Images. Then click "Download from URL":
![]({{ site.baseurl }}/assets/images/proxmox-gpu-passthrough-tutorial/17.png)

Paste [Ubuntu ISO download link](https://releases.ubuntu.com/22.04.1/ubuntu-22.04.1-desktop-amd64.iso) into the "URL:" text field and click Query URL. Then click Download:
![]({{ site.baseurl }}/assets/images/proxmox-gpu-passthrough-tutorial/18.png)

You'll see an output windows, wait for the download to finish and then close it:
![]({{ site.baseurl }}/assets/images/proxmox-gpu-passthrough-tutorial/19.png)

Then right click your host in the left column and click "Create VM":
![]({{ site.baseurl }}/assets/images/proxmox-gpu-passthrough-tutorial/15.png)

Leave node and ID as default:
![]({{ site.baseurl }}/assets/images/proxmox-gpu-passthrough-tutorial/16.png)

Select the ISO you just downloaded:
![]({{ site.baseurl }}/assets/images/proxmox-gpu-passthrough-tutorial/20.png)

In the next screen set Graphic Card as Standard VGA, Machine as q35, Bios as OVMF (UEFI). The rest leave as default:
![]({{ site.baseurl }}/assets/images/proxmox-gpu-passthrough-tutorial/21.png)
(PSST.: In the image I selected SPICE, but later I realized it was not a good choice because it doesn't work well with novnc)

Select the disk size as desired:
![]({{ site.baseurl }}/assets/images/proxmox-gpu-passthrough-tutorial/22.png)

As well as the number of CPU cores:
![]({{ site.baseurl }}/assets/images/proxmox-gpu-passthrough-tutorial/23.png)

Also inform the amount of desired memory:
![]({{ site.baseurl }}/assets/images/proxmox-gpu-passthrough-tutorial/24.png)

You can leave network as default:
![]({{ site.baseurl }}/assets/images/proxmox-gpu-passthrough-tutorial/25.png)

Review, tick "Start after created" and Finish:
![]({{ site.baseurl }}/assets/images/proxmox-gpu-passthrough-tutorial/26.png)

Then click on your VM > Console to see the video output:
![]({{ site.baseurl }}/assets/images/proxmox-gpu-passthrough-tutorial/27.png)

Proceed with the installation as you would normally. After finishing the installation, when Ubuntu is asking to remove the installation media and press ENTER, we can shutdown it. Right-click you VM and select Stop:
![]({{ site.baseurl }}/assets/images/proxmox-gpu-passthrough-tutorial/28.png)

If you get some error like "can’t lock file ‘/var/lock/qemu-server/lock-xxx.conf’ -got timeout", do this in a terminal:

```
export VMID=100 #or your id
rm /run/lock/qemu-server/lock-$VMID.conf
qm unlock $VMID
```

Now, back to the web interface, go to Your VM > Hardware:
![]({{ site.baseurl }}/assets/images/proxmox-gpu-passthrough-tutorial/29.png)

Click on Add > PCI Device and this window should pop up:
![]({{ site.baseurl }}/assets/images/proxmox-gpu-passthrough-tutorial/30.png)
![]({{ site.baseurl }}/assets/images/proxmox-gpu-passthrough-tutorial/31.png)

Then click on the "Device:" dropdown list and select your PCI VGA, then click OK:
![]({{ site.baseurl }}/assets/images/proxmox-gpu-passthrough-tutorial/32.png)

Then you can power on your VM and go to its console again. Once booted up, login and open a terminal. Then type:

```
lspci | grep NVIDIA
```

You should see your adapter there:
![]({{ site.baseurl }}/assets/images/proxmox-gpu-passthrough-tutorial/34.png)

Now, before installing the driver, we need do disable secure boot. Reboot your Ubuntu by typing `reboot` into the terminal and, when proxmox logo appears, keep pressing Esc until you get to this screen, select device manager:
![]({{ site.baseurl }}/assets/images/proxmox-gpu-passthrough-tutorial/36.png)

Then Secure Boot Configuration:
![]({{ site.baseurl }}/assets/images/proxmox-gpu-passthrough-tutorial/37.png)

Then select Attemp Secure Boot and press Space to disable it and press F10 to save and reboot by pressing Esc and Continue in the first screen:
![]({{ site.baseurl }}/assets/images/proxmox-gpu-passthrough-tutorial/38.png)

Once Ubuntu boots again let's install the driver, type:

```
sudo apt search nvidia-driver
```

See the latest line? It contains a number, in my case it was 525:
![]({{ site.baseurl }}/assets/images/proxmox-gpu-passthrough-tutorial/35.png)

Then we install the driver 525 (this may take a while):

```
sudo apt install nvidia-driver-525 -y
```

Once the installation completes, shutdown the VM:

```
sudo shutdown -h now
```

Optional: Then go to Your VM > Hardware > Display:
![]({{ site.baseurl }}/assets/images/proxmox-gpu-passthrough-tutorial/39.png)

Optional: Select Default and press OK.
![]({{ site.baseurl }}/assets/images/proxmox-gpu-passthrough-tutorial/40.png)

Optional: This will make your VM stop outputting video to the NoVNC console and use the VGA HDMI/Displayport output, just in case you want to use a real monitor. If not, just ignore these optional steps.

And we are done for this! Wheeeew!

I hope next time I am able to connect to this PC using a serial port. But these are scenes for the next chapters!!!

## References

[Remove Proxmox Subscription Notice (Tested to 7.1-10)](https://johnscs.com/remove-proxmox51-subscription-notice/)
[Proxmox Update No Subscription Repository Configuration](https://www.virtualizationhowto.com/2022/08/proxmox-update-no-subscription-repository-configuration/)
[sed comment line number x to y from files](https://stackoverflow.com/questions/33684705/sed-comment-line-number-x-to-y-from-files)
[Pci passthrough](https://pve.proxmox.com/wiki/Pci_passthrough)
