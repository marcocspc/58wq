---
layout: post
title:  "Setting up my RP-WD009 with OpenWRT"
date:  2021-10-19 11:50:53 -0300 
categories: english linux
---

# Setting up my RP-WD009 with OpenWRT 

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
export MY_HOSTNAME="juno"
export MY_TIMEZONE="<-03>3" #america/fortaleza
export NTP_SERVER_A="a.ntp.br"
export NTP_SERVER_B="b.ntp.br"
export NTP_SERVER_C="c.ntp.br"
export WWAN_WIFI_NAME="shadow"
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
uci delete system.@system[0].hostname
uci delete system.@system[0].timezone
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
uci set wireless.default_radio0=wifi-iface
uci set wireless.default_radio0.device='radio0'
uci set wireless.default_radio0.network='lan'
uci set wireless.default_radio0.mode='ap'
uci set wireless.default_radio0.ssid=$MAIN_WIFI_NAME
uci set wireless.default_radio0.encryption='sae-mixed'
uci set wireless.default_radio0.ieee80211w='1'
uci set wireless.default_radio0.key=$MAIN_WIFI_PASSWORD
uci set wireless.default_radio1=wifi-iface
uci set wireless.default_radio1.device='radio1'
uci set wireless.default_radio1.network='lan'
uci set wireless.default_radio1.mode='ap'
uci set wireless.default_radio1.ssid=$MAIN_WIFI_NAME
uci set wireless.default_radio1.encryption='sae-mixed'
uci set wireless.default_radio1.ieee80211w='1'
uci set wireless.default_radio1.key=$MAIN_WIFI_PASSWORD
```

If you want to enable wifi now:

```
uci set wireless.radio0.disabled='0'
uci set wireless.radio1.disabled='0'
wifi
```

## Enable Guest Wifi

The [official OpenWRT guide](https://openwrt.org/docs/guide-user/network/wifi/guestwifi/configuration_command_line_interface) has already an excelent script that sets everything related to guest wifi for you. Here I make three adaptations: use my variables, set the password (the original script does not set any password) and make the wifi disabled by default (we enable it afterwards, like we did before with the main wifi).


```
# Configuration parameters
WIFI_DEV="$(uci get wireless.@wifi-iface[0].device)"

# Set up guest WLAN
uci delete network.guest_dev
uci set network.guest_dev=device
uci set network.guest_dev.type=bridge
uci set network.guest_dev.name=br-guest
uci delete network.guest
uci set network.guest=interface
uci set network.guest.proto=static
uci set network.guest.device=br-guest
uci set network.guest.ipaddr=192.10.11.0
uci set network.guest.netmask=255.255.255.0
uci commit network
uci delete wireless.guest
uci set wireless.guest=wifi-iface
uci set wireless.guest.device=$WIFI_DEV
uci set wireless.guest.mode=ap
uci set wireless.guest.network=guest
uci set wireless.guest.ssid=$GUEST_WIFI_NAME
uci set wireless.guest.key=$GUEST_WIFI_PASSWORD
uci set wireless.guest.encryption=none
uci set wireless.guest.disabled=1
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
wifi
```

## My indecision

I'm really undecided if I use this particular router with travelmate or not. For those uninitiated, travelmate is a fantastic tool for those who use portable routers. The software creates a sta interface (a wifi device capable of connecting to wireless APs and treat them as upstream wan) and manages wifi connections for you. When it cannot reach internet, it enables your wireless station so you can set up another wwan ap. 

This is needed due to the openwrt's nature of disabling your wireless lan if it cannot associate with a set up AP. I have an old rp-wd02 with only one 2.4Ghz radio, which remained off when it disconnected from upstream wifi, and I could not set it up again until I got an ethernet cable to connect to it. The problem was that it was not every time I had such cable. I used travelmate on this router, which fixed the problem, but it was a really tough load for this tiny router.

I fear the same could happen to my new rp-wd009. But it has a way stronger CPU which could handle the load. Beyond that, it has... BUTTONS! Yes, the router comes with four buttons: one to copy data from the sd card slot to a plugged usb device, one to turn on and off wifi and one reset and power buttons. My old rp-wd02 had only two buttons: power and reset. Power was not configurable, while reset was, but even if I did the nonsense of overwrite the reset button's default behavior, it was not an easy button to reach.

Anyway, apart from the reset and power buttons, those two other buttons I mentioned above (from the rp-wd009), are configurable. I mean, all four buttons might be configurable, but I'm not going to mess with the power and reset buttons. Those other two, I'm going to call them copy-button and wifikill-button, to make easier to me mention them as I write this.

I could, then, set up the wifikill-button to turn on and off the sta interface and always have the main wifi available when needed. This would vanish the need to use travelmate. On the other hand, travelmate has an excellent web interface for Luci, which makes a lot easier to connect to new aps. And it remembers the associated wifis, automatically connecting to them as they are available. But it also may keep turning off the wifi as it is not able to associate to multiple stations. It is a hard decision on which path to take, you know.

BUT! As I wrote this, I had an idea: WHY NOT BOTH? <insert meme here>. I could map the wifikill button to disable both the sta interface and travelmate, if those generated some kind of problem. Se here I go!

## Travelmate

Before setting the wifikill button, I'm going to install travelmate because it creates a custom wwan interface. In the past I've tried to modify this interface's name, but I never fully understood how travelmate set up its configurations and couldn't modify to make it work.

To install it, though, I need to set up a wwan interface manually, this is what I do here:

```
uci delete wireless.wwan_radio0
uci set wireless.wwan_radio0=wifi-iface
uci set wireless.wwan_radio0.device='radio0'
uci set wireless.wwan_radio0.network='wwan'
uci set wireless.wwan_radio0.mode='sta'
uci set wireless.wwan_radio0.ssid=$WWAN_WIFI_NAME
uci set wireless.wwan_radio0.encryption='psk2'
uci set wireless.wwan_radio0.key=$WWAN_WIFI_PASSWORD
uci delete network.wwan
uci set network.wwan=interface
uci set network.wwan.device=wlan0
uci set network.wwan.proto=dhcp
uci add_list firewall.@zone[1]='wwan'
```

Enable it:

```
uci set wireless.wwan_radio0.enabled=1
uci set wireless.radio0.disabled=0
/etc/init.d/networking restart
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

Now we can proceed and install travelmate:

```
opkg update
opkg install luci-app-travelmate
```

Now let's undo our wwan interface, so we can let travelmate do it's stuff:

```
uci delete wireless.wwan_radio0
uci delete network.wwan
/etc/init.d/networking restart
/etc/init.d/firewall restart
wifi
```

We go now to the web interface, so we can start the travelmate setup;

- Go to the default router IP (mine 192.168.1.1);
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

Now, finally let's go for the button!

## The wifikill button

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
