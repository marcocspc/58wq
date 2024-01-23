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

