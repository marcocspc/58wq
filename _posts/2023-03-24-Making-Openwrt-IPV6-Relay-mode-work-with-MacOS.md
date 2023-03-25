---
layout: post
title:  "Making Openwrt IPV6 Relay mode work with MacOS"
date:  2023-03-24 21:14:40 -0300 
categories: english linux openwrt
---

# Making Openwrt IPV6 Relay mode work with MacOS 

This is a quick guide to document how I've managed to make IPv6 work in OpenWRT WAN and a Macbook on Lan. 

I went to São Paulo this year while on vacations, when I've got to the hotel no surprise: Wi-Fi was, well, not good (to say it in a polite way). Anyway, I decided to share my phone's 4G connection to my devices, but when I tried to connect my Nintendo Switch, I've got some problems. 

Then I went to plan B and decided do hook my phone to the portable router I was carrying. Everything went OK until I needed USBWAN interface to get an IP address. According to the [official wiki page](https://openwrt.org/docs/guide-user/network/wan/smartphone.usb.tethering), when this happens one should reboot the router, reboot the iPhone, try reconnecting the cable, etc. But, oh god, I tried...

One day or two later (I've spent the entire week traveling), I've checked my Macbook IP address (while tethering my phone's internet via AP) and discovered that the device was getting an IPv6 address. Quickly, I went to my router, hooked my phone again and changed the protocol to DHCPv6 and kaboom the IP was there, but not internet on lan interface, though.

So I thought: why am I not getting internet if I //can// download packages, ping, etc from my router? That's exactly what I googled, which led me to [this discussion](https://forum.openwrt.org/t/ipv6-working-on-router-but-not-on-clients/79416). There, I've got to the [relay mode](https://openwrt.org/docs/guide-user/network/ipv6/configuration#ipv6_relay) needed by DHCP configuration on WAN to make things work in an IPv6 environment.

Before proceeding on how I've made this work, I would like to write a little about IPv4 vs IPv6 transition. At the time I wrote this, I really did not understand very well how the sixth version of the IP protocol worked. I thought that the newer version would talk nicely with v4, but that does not seem to be the case. It is so in a way that even if your clients on the lan network have IPv4, there is not an easy way for the router to "translate" the communication between the IPv6 WAN interface and the IPv4 LAN one.

I've discovered, while reading, that you really need the LAN interface to provide IPv6 addresses, but even by enabling that I wasn't able to communicate with the WAN interface. There is, indeed, a NAT6 protocol, but reading OpenWRT forums I've seen a lot of people mentioning that this is not a good idea because IPv6 doesn't work like that (even that thing I tried, but it also didn't work). The "relay mode" I've mentioned before is like an "address passthrough" from on your WAN interface to your LAN devices. This way, your devices will have ISP provisioned addresses. This, also, made me concerned about security, but since I was on vacations I just wanted to figure this out.

Following this, I've set DHCP options to enable relay mode. These were the DHCP settings that made everything work:


```
...
config dhcp 'lan'
        option interface 'lan'
        option start '100'
        option limit '150'
        option leasetime '12h'
        option dhcpv4 'server'
        option ra 'relay'
        option ndp 'relay'
        option dhcpv6 'relay'
        list ra_flags 'none'
...
config dhcp 'usbwan6'
        option interface 'usbwan6'
        option ignore '1'
        option dhcpv6 'relay'
        option ra 'relay'
        option ndp 'relay'
        option master '1'
...
```

Also, the "usbwan6" interface configuration:

```
config interface 'usbwan6'
        option device 'eth1'
        option proto 'dhcpv6'
        option reqaddress 'try'
        option reqprefix 'auto'
        option disabled '0'
```

But even with that things didn't work out and I almost gave up. There was one day of the trip, though, that my fiancé got sick and I had to spend the entire day in the hotel with her, this arranged me time to investigate this issue a little further. I remembered that [one of my readings](https://forum.openwrt.org/t/ipv6-working-on-router-but-not-on-clients/79416/13) an user mentioned that macOS didn't like relay mode, while in an Windows computer everything worked well.

I've tcpdumped the connection logs while trying to ping6 google.com on my mac. What I've discovered is that the ping was reaching google sites, the response getting to the router, but when it sent a "ICMP6, neighbor solicitation, length 32, who has" message to the Macbook, the computer didn't respond. According to [this issue's](https://github.com/openwrt/openwrt/issues/7561) author, what was need to do was to disable the ULA of the router. This was needed to make the router use the LLA when sending that "ICMP6, neighbor solicitation, length 32, who has" message, and macOS would answer the message accordingly, hence making the communication start to work. To do this I've commented two lines in the network configuration:

```
#config globals 'globals'
#	option ula_prefix 'fd27:70fa:5c1d::/48'
```

Then rebooted the router and everything started working. After so much work researching and testing, I was able to comfortably navigate the internet using my phone's plan in my macbook.
