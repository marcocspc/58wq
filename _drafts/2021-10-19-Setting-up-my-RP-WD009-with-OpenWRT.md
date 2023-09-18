---
layout: post
title:  "Setting up my RP-WD009 with OpenWRT"
date:  2021-10-19 11:50:53 -0300 
categories: english linux openwrt
---

# Setting up my Portable Router (RP-WD009) with OpenWRT 

I am not an anxious person. I mean, I've been waiting, like, an eternity for my RPWD009 to arrive (it was three weeks lol). Ok, I may be a bit excited, but today I got my portable router from Ravpower, and the first thing I did was to flash it with OpenWRT.

I should have done a backup first, but... Well, things went good, so no worries. Oh, and I have followed [this](https://openwrt.org/toh/ravpower/rp-wd009#oem_installation_using_the_tftp_method) to flash it, if you're curious how I did it.

Anyway, here I'll be taking notes about everything I do to modify the default configurations in the stock openwrt image. I'll document my efforts to the future, if I need somehow to do them again.

## First things first

Every time I boot openwrt for the first time, I do two things: set a root password and change some system settings. I do it via SSH, so the command to make the connection is:

```
ssh root@192.168.1.1
```

After this, I'd like to set some environment variables. Every guide I write, I do this to help me change configurations if needed in the future:

```
export MY_TIMEZONE="<-03>3" #america/fortaleza
export NTP_SERVER_A="a.ntp.br"
export NTP_SERVER_B="b.ntp.br"
export NTP_SERVER_C="c.ntp.br"
read -p "MY_HOSTNAME: " MY_HOSTNAME ;\
read -p "WWAN_WIFI_NAME: " WWAN_WIFI_NAME ;\
read -p "WWAN_WIFI_PASSWORD: " WWAN_WIFI_PASSWORD ;\
read -p "MAIN_WIFI_NAME: " MAIN_WIFI_NAME ;\
read -p "MAIN_WIFI_PASSWORD: " MAIN_WIFI_PASSWORD ;\
read -p "GUEST_WIFI_NAME: " GUEST_WIFI_NAME ;\
read -p "GUEST_WIFI_PASSWORD: " GUEST_WIFI_PASSWORD
```

psst: if you need to get timezone "codes" go [here](https://github.com/openwrt/luci/blob/master/modules/luci-base/luasrc/sys/zoneinfo/tzdata.lua).

Set password for root:

```
passwd
```

Set system name, timezone and ntp servers:

```
uci delete system.ntp.server
uci set system.@system[0].hostname="$MY_HOSTNAME"
uci set system.@system[0].timezone="$MY_TIMEZONE"
uci add_list system.ntp.server="$NTP_SERVER_A"
uci add_list system.ntp.server="$NTP_SERVER_B"
uci add_list system.ntp.server="$NTP_SERVER_C"
```

Apply changes:

```
/etc/init.d/system restart
```

This router, as many of the current generation of routers, have two wireless devices: one running in the 2.4GHz frequency and another one in the 5GHz frequency. The main wifi is set for these two radios:

```
uci delete wireless.default_radio0
uci delete wireless.default_radio1
# 2G
uci set wireless.default_radio0=wifi-iface
uci set wireless.default_radio0.device='radio0'
uci set wireless.default_radio0.network='lan'
uci set wireless.default_radio0.mode='ap'
uci set wireless.default_radio0.ssid=$MAIN_WIFI_NAME
uci set wireless.default_radio0.encryption='sae-mixed'
uci set wireless.default_radio0.ieee80211w='1'
uci set wireless.default_radio0.key=$MAIN_WIFI_PASSWORD
# 5G
uci set wireless.default_radio1=wifi-iface
uci set wireless.default_radio1.device='radio1'
uci set wireless.default_radio1.network='lan'
uci set wireless.default_radio1.mode='ap'
uci set wireless.default_radio1.ssid=$MAIN_WIFI_NAME-5g
uci set wireless.default_radio1.encryption='sae-mixed'
uci set wireless.default_radio1.ieee80211w='1'
uci set wireless.default_radio1.key=$MAIN_WIFI_PASSWORD
```

If you want to enable wifi now:

```
uci set wireless.radio0.disabled='0'
uci set wireless.radio1.disabled='0'
uci set wireless.radio0.enabled='1'
uci set wireless.radio1.enabled='1'
uci set wireless.default_radio0.disabled='0'
uci set wireless.default_radio1.disabled='0'
uci set wireless.default_radio0.enabled='1'
uci set wireless.default_radio1.enabled='1'
wifi
```

If your 5G wifi is not showing, and your 5G led is off, try:

- Check iwinfo: `iwinfo phy1 info`
- Check if wlan1 is showing under ip command: `ip a`
- Check if wlan1 link is up: `ip link set wlan1 up`
- Check if country code is enabled: `uci show wireless.radio1.country`
- If needed to set country code: `uci set wireless.radio1.country='BR'`

## Enable Guest Wifi

The [official OpenWRT guide](https://openwrt.org/docs/guide-user/network/wifi/guestwifi/configuration_command_line_interface) has already an excelent script that sets everything related to guest wifi for you. Here I make three adaptations: use my variables, set the password (the original script does not set any password) and make the wifi disabled by default (we enable it afterwards, like we did before with the main wifi).


```
# Configuration parameters
WIFI_DEV="$(uci get wireless.@wifi-iface[0].device)"
WIFI_DEV_5G="$(uci get wireless.@wifi-iface[3].device)"

# Set up guest WLAN
uci delete network.guest_dev
uci set network.guest_dev=device
uci set network.guest_dev.type=bridge
uci set network.guest_dev.name=br-guest
uci delete network.guest
uci set network.guest=interface
uci set network.guest.proto=static
uci set network.guest.device=br-guest
uci set network.guest.ipaddr=192.10.11.1
uci set network.guest.netmask=255.255.255.0
uci commit network
# 2G
uci delete wireless.guest
uci set wireless.guest=wifi-iface
uci set wireless.guest.device=$WIFI_DEV
uci set wireless.guest.mode=ap
uci set wireless.guest.network=guest
uci set wireless.guest.ssid=$GUEST_WIFI_NAME
uci set wireless.guest.key=$GUEST_WIFI_PASSWORD
uci set wireless.guest.encryption=psk2
uci set wireless.guest.disabled=1
# 5G
uci delete wireless.guest5g
uci set wireless.guest5g=wifi-iface
uci set wireless.guest5g.device=$WIFI_DEV_5G
uci set wireless.guest5g.mode=ap
uci set wireless.guest5g.network=guest
uci set wireless.guest5g.ssid=$GUEST_WIFI_NAME-5G
uci set wireless.guest5g.key=$GUEST_WIFI_PASSWORD
uci set wireless.guest5g.encryption=psk2
uci set wireless.guest5g.disabled=1
uci commit wireless
uci delete dhcp.guest
uci set dhcp.guest=dhcp
uci set dhcp.guest.interface=guest
uci set dhcp.guest.start=100
uci set dhcp.guest.limit=150
uci set dhcp.guest.leasetime=12h
uci commit dhcp
uci delete firewall.guest
uci set firewall.guest=zone
uci set firewall.guest.name=guest
uci set firewall.guest.network=guest
uci set firewall.guest.input=REJECT
uci set firewall.guest.output=ACCEPT
uci set firewall.guest.forward=REJECT
uci delete firewall.guest_wan
uci set firewall.guest_wan=forwarding
uci set firewall.guest_wan.src=guest
uci set firewall.guest_wan.dest=wan
uci delete firewall.guest_dns
uci set firewall.guest_dns=rule
uci set firewall.guest_dns.name=Allow-DNS-guest
uci set firewall.guest_dns.src=guest
uci set firewall.guest_dns.dest_port=53
uci add_list firewall.guest_dns.proto=tcp
uci add_list firewall.guest_dns.proto=udp
uci set firewall.guest_dns.target=ACCEPT
uci delete firewall.guest_dhcp
uci set firewall.guest_dhcp=rule
uci set firewall.guest_dhcp.name=Allow-DHCP-guest
uci set firewall.guest_dhcp.src=guest
uci set firewall.guest_dhcp.dest_port=67
uci set firewall.guest_dhcp.proto=udp
uci set firewall.guest_dhcp.family=ipv4
uci set firewall.guest_dhcp.target=ACCEPT
uci commit firewall
/etc/init.d/network reload
/etc/init.d/dnsmasq restart
/etc/init.d/firewall restart
```

If you want to enable the guest wifi now:

```
uci set wireless.guest.disabled=0
uci set wireless.guest5g.disabled=0
wifi
```

If your 5G wifi is not showing, and your 5G led is off, try:

- Check iwinfo: `iwinfo phy1 info`
- Check if wlan1 is showing under ip command: `ip a`
- Check if wlan1 link is up: `ip link set wlan1 up`
- Check if country code is enabled: `uci show wireless.radio1.country`
- If in need to set country code: `uci set wireless.radio1.country='BR'`

## Travelmate

I'm going to install travelmate because it really helps the portable router owner. It creates a custom WWAN interface and, in the past, I've tried to modify this interface's name, but I never fully understood how travelmate set up its configurations and couldn't modify to make it work. But the advantages this little guy gives us, like auto switching multiple hotspots or even reconnecting if the connection fails, are priceless.

To install it, though, I need first to set up a wwan interface manually, this is what I do here:

```
uci delete wireless.wwan_radio0
uci set wireless.wwan_radio0=wifi-iface
uci set wireless.wwan_radio0.device='radio0'
uci set wireless.wwan_radio0.network='wwan'
uci set wireless.wwan_radio0.mode='sta'
uci set wireless.wwan_radio0.ssid="$WWAN_WIFI_NAME"
uci set wireless.wwan_radio0.encryption='psk2'
uci set wireless.wwan_radio0.key="$WWAN_WIFI_PASSWORD"
uci delete network.wwan
uci set network.wwan=interface
uci set network.wwan.device=wlan0
uci set network.wwan.proto=dhcp
uci add_list firewall.@zone[1].network='wwan'
```

Enable it:

```
uci set wireless.wwan_radio0.enabled=1
uci set wireless.radio0.disabled=0
/etc/init.d/network restart
/etc/init.d/firewall restart
wifi
```

Test if it worked:

```
ping 8.8.8.8 -c 3
```

If the answer was something like:

```
PING 8.8.8.8 (8.8.8.8): 56 data bytes
64 bytes from 8.8.8.8: seq=0 ttl=118 time=55.201 ms
64 bytes from 8.8.8.8: seq=1 ttl=118 time=54.984 ms
64 bytes from 8.8.8.8: seq=2 ttl=118 time=55.824 ms
                                                  
--- 8.8.8.8 ping statistics ---
3 packets transmitted, 3 packets received, 0% packet loss
round-trip min/avg/max = 54.984/55.336/55.824 ms
```

IT WORKED!

If it didn't work, check if the radio is connected:

```
iwinfo 
```

Also, check your LAN IP address and see if it doesn't have any conflict with WWAN IP:

```
#check each route IP
ip route
/etc/init.d/network restart
```

To change you router LAN IP run this (you'll lose SSH connection):

```
uci set network.lan.ipaddr='YOUR.IP'
uci 
```

**IF** (and only if) you were able to connect again to your router, commit the changes:

```
uci commit
```

Now we can proceed and install travelmate:

```
opkg update
opkg install luci-app-travelmate
```

Now let's undo our wwan interface, so we can let travelmate do it's stuff:

```
uci delete wireless.wwan_radio0
uci delete network.wwan
/etc/init.d/network restart
/etc/init.d/firewall restart
wifi
```

We go now to the web interface, so we can start the travelmate setup;

- Go to your router IP;
- Login with root and your password;
- Go to Services -> Travelmate;
- Click on Interface Wizard;
- Leave everything as default and click on Save;
- Tick "Enabled";
- On "Radio Selection" choose "use first radio only (radio0)"
- Scroll down and click "Save & Apply";
- Now go to the tab "Wireless Stations";
- Click on the "Scan on radio0";
- Select your wifi, put the password (and the ssid if it's hidden);
- Leave everything else as default and click "Save";
- When back, click "Save & Apply" again;
- Go to the first tab again (Overview);
- Click on "Restart Interface";
- Wait until Status / Version gets to "connected", then you're good to go.

To test if everything is working, do the ping command again (on the ssh session):

```
ping 8.8.8.8 -c 3
```

Result should be:

```
PING 8.8.8.8 (8.8.8.8): 56 data bytes
64 bytes from 8.8.8.8: seq=0 ttl=118 time=55.201 ms
64 bytes from 8.8.8.8: seq=1 ttl=118 time=54.984 ms
64 bytes from 8.8.8.8: seq=2 ttl=118 time=55.824 ms
                                                  
--- 8.8.8.8 ping statistics ---
3 packets transmitted, 3 packets received, 0% packet loss
round-trip min/avg/max = 54.984/55.336/55.824 ms
```

This ends this section.

## Updating the firmware

To update the firmware, we can first check the latest stable release of OpenWRT:

```
curl -s "https://downloads.openwrt.org/releases/" | grep href | grep -v '(root)' | grep -v KeyCDN | grep -v faillogs | grep -v 'packages-' | sed s/'<\/a>.*'/''/ | sed s/'<tr><td class="n">'/''/ | cut -d'>' -f2 | grep -v '\-rc' | sort | tail -n1
```

Then compare to the installed version:

```
cat /etc/banner
```

If they are different, let's download the latest firmware:

```
export LATEST_VERSION=$(curl -s "https://downloads.openwrt.org/releases/" | grep href | grep -v '(root)' | grep -v KeyCDN | grep -v faillogs | grep -v 'packages-' | sed s/'<\/a>.*'/''/ | sed s/'<tr><td class="n">'/''/ | cut -d'>' -f2 | grep -v '\-rc' | sort | tail -n1)
)
wget -O /tmp/firmware.bin https://downloads.openwrt.org/releases/$LATEST_VERSION/targets/ramips/mt76x8/openwrt-$LATEST_VERSION-ramips-mt76x8-ravpower_rp-wd009-squashfs-sysupgrade.bin
```

**WARNING**: proceed only if you are sure to continue, since upgrades can make you lose all the configuration/installed packages.

To install the update keeping the configuration, run this command:

```
sysupgrade -v /tmp/firmware.bin
```

PS.: After running this command I had to reinstall travelmate. Luckily, trm_wwan was still enabled and I was able to `opkg update` and `opkg install travelmate` again.

## Ethernet USB

Maybe it's a driver issue, maybe it's just the driver itself. The thing is: RP-WD009 (at least in openwrt) won't work properly if the ethernet port is set to be WAN instead of LAN. The device simply won't get any IP from upstream DHCP, so even if I tried multiple times this wouldn't work.

But! I got a plan B, which would be to use an Ethernet USB. This chapter of this post will have the responsibility to cover this part.

The USB adapter a usually carry with me (to use with my Macbook Air) is the TP-Link UE300. According to [this link](https://forum.openwrt.org/t/solved-raspberry-pi-4-and-tp-link-ue300-usb-ethernet-dongle/56167) the package of this driver should be `kmod-usb-net-rtl8152`. To install it, we can proceed like this:

```
opkg update
opkg install kmod-usb-net-rtl8152
```

After the installation is complete, connect the adapter in the USB port and it should be shown as eth1:

```
ip a s dev eth1
```

Then we can proceed to create a br-wan bridge and use it as a wan interface:

```
uci set network.wan_bridge=device
uci set network.wan_bridge.type='bridge'
uci set network.wan_bridge.name='br-wan'
```

Now create the interface:

```
uci set network.wan=interface
uci set network.wan.proto='dhcp'
uci set network.wan.device='br-wan'
```

## Quick commands to switch ethernet port functionality

**WARNING**: before proceeding, make sure you are able to connect to the router via wi-fi. One wrong step and you'll need to reset the router completely. So be advised.

So, connect to the router via your LAN wi-fi and open a ssh connection to it again.

By default, the ethernet port work as a LAN port. Before switching it to WAN, we need to create the WAN interface. To do this, run these commands:

Now we create the wired wan interface:

```
uci set network.wan=interface
uci set network.wan.proto='dhcp'
```

Apply changes:

```
uci commit
/etc/init.d/network restart 
```

Now remove the ethernet port from LAN:

```
uci del network.@device[0].ports
```

Add this ethernet port to WAN:

```
uci set network.wan.device='eth0'
```

Apply changes:

```
uci commit
/etc/init.d/network restart 
```

Now connect the ethernet cable and check if you get any IP.

```
ip a s dev br-wan
```

## The "ethernet mode switcher" button

This is one of the advantages of using linux based systems on our devices: **RIDICULOUSLY HIGH CUSTOMIZATION LEVELS**. The RP-WD009 router comes with two push buttons. The objective here is to set one of them to alter the ethernet state in case we want to use it as a LAN or WAN port.

As [this openwrt guide shows](https://openwrt.org/docs/guide-user/hardware/hardware.button#hotplug_buttons) we should start by testing which button we want. But as this documentation of mine is specific to the rp-wd009, I already know which button I want to use. OpenWRT shows it under the "rfkill" label. So we are going to use it.

First of all, we need a script to enable/disable travelmate and it's interface when called. This is the one:

```
cat <<"EOF" > /usr/sbin/travelmate_onoff.sh
#!/bin/ash

disable() {
    #set all trm_uplink to disabled
    logger "Disabling all trm_uplink interfaces"
    for i in $(uci show wireless | grep trm_uplink | grep disabled | awk -F. '{print $2}') ; do
        uci set "wireless.$i.disabled=1"
    done
    #commit changes
    uci commit
    #stop travelmate
    logger "Stopping travelmate"
    /etc/init.d/travelmate stop
    #reset wifi
    logger "Resetting wifi"
    wifi
}

enable() {
    #Here we don't need to neither reenable trm_uplink
    #(because we cannot know which one was previously
    #enabled) or restart wifi. Leave those operations for
    #travelmate. 
    #So we just start travelmate
    logger "Starting travelmate"
    /etc/init.d/travelmate start 
}

main() {
    #Check if travelmate is enabled:
    if [ -f /tmp/trm_runtime.json ] && [[ "$(cat /tmp/trm_runtime.json)" != ""]] ; then
        logger "travelmate is enabled, disabling it"
        disable
    else
        logger "travelmate is disabled, enabling it"
        enable
    fi
}

main

EOF
```

Make this script executable:

```
chmod +x /usr/sbin/travelmate_onoff.sh
```

Now we set this script to be used by the wifikill-button. The system already has one script (/etc/rc.button/rfkill) that it invoked when wifikill is pressed, so we first get it out of the way (backing it up, of course):

```
mv /etc/rc.button/rfkill /etc/rc.button/rfkill.bak
```

To make our script work, we ask to hotplug.button, to run it. To do this we export the following code to the /etc/hotplug.d/button/buttons:

```
mkdir -p /etc/hotplug.d/button
cat << "EOF" >> /etc/hotplug.d/button/buttons
if [[ "${BUTTON}" == "rfkill" ]] && [[ "${ACTION}" == "released" ]] ; then
    /usr/sbin/travelmate_onoff.sh
fi
EOF
```

To test it, take a look at logread. You should see the sentences like "Travelmate enabled. disabling it":

```
#run this and try to press the button
logread -f -e "abled"
```

This should do for the wifikill-button. ;)

## The copy-button

I was not going to use the copy-button. But then I thought: the rp-wd009, like my old one, have only one ethernet port. It would be amazing if I could change it's state to wan or lan with the press of a... what? What? A BUTTON! That's right!

Before proceeding, batter make sure that both radios are enabled and the wifi is working, so we can set things up for the cable connection:

### TODO wifi não tava funcionando quando eu tentei conectar, ver isso hein
