---
layout: post
title:  "Setting up OneKVM on my Orange Pi Zero"
date:  2025-02-04 13:54:37 -0300 
categories: english linux armbian 
---

# Setting up OneKVM on my Orange Pi Zero 

To be honest, I already have [OneKVM](https://github.com/mofeng-git/One-KVM) working on my Orange Pi Zero. The thing is, I've done this setup on an 8GB SD card and I don't remember all the steps I performed in order to accomplish it. So, again, here's another post to document my endeavor.

BTW, it's important to contextualize what the heck OneKVM is. In the past, [mdevaev](https://github.com/mdevaev) revolutionized the network KVM space with [PiKVM](https://pikvm.org/), which was an open source software (still is) made to run on the Raspberry Pi that would offer KVM capabilities over the network. By the time, it was the cheapest solution that had this kind of feature, which would force the manufacturers to offer cheaper solutions.

Time went on and Raspberry lost the crown of "cheap and small PC" to other solutions. Also, here in Brazil due to our BRL losing a lot of value in the last years joined to the fact that we have A LOT of taxes on imported items, the tiny board is just unbuyable.

That's when China comes to the rescue, twice. First, there are other hardware manufacturers that offer solutions to the overpriced board. [Orange Pi](https://orangepi.org) is one to mention, which is a viable solution in these times. Also, the PiKVM project has a problem that just annoys me: although open source, the software is tied to Raspberry in such a way that installing it on other boards becomes a pain in places difficult to reach.

The second time in which China comes to the rescue is the OneKVM project. It's a port of the PiKVM software made to run in docker, which already adds a layer of portability. It also supports Orange Pi Zero and a lot of other boards and small footprint PCs. The only thing with OneKVM is that its documentation is entirely written in Chinese, which adds some difficulty into the setup, but nothing that a Google Translate can't help with.

BTW that's one of the reasons to document this, I'd like to have some kind of setup documentation written in English for the folks that live on this side of the planet. I should be also making some pull requests in the future to add some localisation to the project as well, but that's a project to the future.

## Installing Armbian

First we download it:
```
wget https://dl.armbian.com/orangepizero/Bookworm_current_minimal -O armbian.img.xz
```

Here I'll be using the minimal version of Armbian, as I want to keep the installation footprint as small as possible.

After the download completes, the image can be written using the command below on Mac:
```
xzcat armbian.img.xz | sudo dd of=/dev/diskX status=progress
```

Where diskX is your SD card.

