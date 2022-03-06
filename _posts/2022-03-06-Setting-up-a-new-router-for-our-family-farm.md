---
layout: post
title:  "Setting up a new router for our family farm"
date:  2022-03-06 14:02:59 -0300 
categories: english linux openwrt  
---

# Setting up a new router for our family farm 

I've got in my hands a tp-link archer c20 and decided to use it as a replacement for the router used in my family farm. There, I already had an old tp-link tlwr842n v2 router, which obviously needed an upgrade. 

So, my objective with this post is to document the steps I used to install openwrt in the tp-link archer c20 and setting it up for the household at my family farm.

## Dependencies

You will need this to run this tutorial:
- dd
- wget
- python3 and pip

## Variables

I always like to start listing the variables that will store the data used in the commands run along this guide. This is much more practical because next time I read this, I can change only the variables present here and keep going and pasting the commands without worrying about the data.

It is strongly advised that these exports should be run on all terminals you're working with. Always come back here and copy and paste these commands again if you need to reboot or disconnect from one of these terminals. 

```
export BASEDIR="/path/where/all/the/project/data/will/be/stored"
#get the most recent link at https://www.tp-link.com/en/support/download/archer-c20/v1/#Firmware
export OFFICIALIMAGE_URL="https://static.tp-link.com/res/down/soft/Archer_C20_V1_151120.zip" 
#get the most recent link at https://openwrt.org/toh/tp-link/archer_c20_v1
export OPENWRTIMAGE_URL="https://downloads.openwrt.org/releases/21.02.2/targets/ramips/mt7620/openwrt-21.02.2-ramips-mt7620-tplink_archer-c20-v1-squashfs-sysupgrade.bin"
export OFFICIALIMAGE_FILENAME=$(basename $OFFICIALIMAGE_URL)
export OPENWRTIMAGE_FILENAME=$(basename $OPENWRTIMAGE_URL)
export ADMIN_WIFI_SSID=example_admin && read -p "Input $ADMIN_WIFI_SSID password: " ADMIN_WIFI_PASS && export MAIN_WIFI_SSID=example_common && read -p "Input $MAIN_WIFI_SSID password: " MAIN_WIFI_PASS
export ROUTER_HOSTNAME=example_hostname
#get timezone code at https://github.com/openwrt/luci/blob/master/modules/luci-base/luasrc/sys/zoneinfo/tzdata.lua
export ROUTER_TIMEZONE="<-03>3"
export NTP_SERVER_A="a.ntp.br"
export NTP_SERVER_B="b.ntp.br"
export NTP_SERVER_C="c.ntp.br"
# Mine's brazillian portuguese:
export ROUTER_LANGUAGE_CODE="pt-br"
export WIREGUARD_CLIENT_PRIVATE_KEY=""
export WIREGUARD_CLIENT_ADDRESS="10.0.0.2"
export WIREGUARD_SERVER_PUBLIC_KEY=""
export WIREGUARD_SERVER_PUBLIC_IP_ADDRESS=""
export WIREGUARD_SERVER_LISTEN_PORT="1195"
export WIREGUARD_ALLOWED_IPS="10.0.0.0/24"
```

## Installing openwrt on the archer c20

First step is to download the router's official firmware. This is needed because if the upgrade is done via the router's web interface, you will get an error regarding lzma decompression. If done via TFTP, you will soft brick your router to the point where it will be needed to flash the rom manually using an SPI programmer. 

Anyway, the following process is to combine the openwrt firmware with the official one, by getting the uboot partition inserted into an altered image. This will make the TFTP flashing process safer, since we are using the official uboot and avoiding any startup errors.

### Combining images

So let's first download the two images. Create and enter your base dir:

```
mkdir -p $BASEDIR && cd $BASEDIR
```

Download the official image:

```
wget $OFFICIALIMAGE_URL
```

Download openwrt image:

```
wget $OPENWRTIMAGE_URL
```

Extract the official image:

```
unzip $OFFICIALIMAGE_FILENAME
```

Get the official firmware file name and directory:

```
export OFFICIALIMAGE_FILENAME_UNZIPPED=$(ls "$(ls -d */)"| grep bin)
export OFFICIALIMAGE_FILENAME_DIR=$(ls -d */)
```

Extract uboot partition from official image:

```
dd if="$OFFICIALIMAGE_FILENAME_DIR$OFFICIALIMAGE_FILENAME_UNZIPPED" of=uboot.bin bs=512 count=256 skip=1
```

Combine uboot with openwrt image:

```
cat uboot.bin $OPENWRTIMAGE_FILENAME > ArcherC20V1_tp_recovery.bin
```

### Installing the firmware using TFTP method

Connect your desktop/notebook to you router (lan ports only) using an ethernet cable and configure your network to use static IP 192.168.0.66, netmask 255.255.255.0 and default gateway 192.168.0.1. Do not turn on the router now.

Now we will use Python's help to run a quick tftp server. Install virtualenv:

```
pip3 install virtualenv --user 
```

Now create a temporary folder to store the tftp server installation:

```
cd $BASEDIR
python3 -m virtualenv tftp
```

Activate the virtualenv:

```
source $BASEDIR/tftp/bin/activate
```

Install the tftp server:

```
pip install py3tftp
```

Run the server:

```
sudo $(which py3tftp) -p 69
```

Make sure the server is running in $BASEDIR. sudo is needed to use port 69. After everything is set, go to your router, hold the WPS/Reset button and turn it on and keep the button pressed for 10 seconds (or until the lock led lights up). You will see in the py3tftp log that you will receive a connection from 192.168.0.1. If this happens, do not turn off the router. It will take a few minutes to finish the installation, wait until the power led stops flashing and the lan led will start blinking, while the power led will be static. Stop py3tftp server by pressing Ctrl + C.

Change your ethernet setting to DHCP and access Luci web interface by going to 192.168.1.1 in your web browser of choice.

## Basic setup

Here I'm not going to set things using Luci web interface. Since I want to do things quick, I'll be using ssh. So login into your router:

```
ssh root@192.168.1.1
```

Go to the top of this tutorial and export the variables again in the ssh session. After this, set your root password:

```
passwd
```

Now set up your hostname and timezone:

```
uci set system.@system[0].hostname=$ROUTER_HOSTNAME
uci set system.@system[0].timezone=$ROUTER_TIMEZONE
uci delete system.ntp.server
uci add_list system.ntp.server=$NTP_SERVER_A
uci add_list system.ntp.server=$NTP_SERVER_B
uci add_list system.ntp.server=$NTP_SERVER_C
```

Apply changes:

```
uci commit
/etc/init.d/system restart
```

PS: date won't change until the router is connected to internet.

## Wi-Fi configuration

Here I create and admin Wi-Fi and a "common" Wi-Fi. To have access to the web interface and ssh service, one should connect to the admin wifi. The common wi-fi will be for everyone and will remain enabled by default.

Set up the admin Wi-Fi:

```
uci set wireless.default_radio0.ssid=$ADMIN_WIFI_SSID
uci set wireless.default_radio0.encryption='psk2'
uci set wireless.default_radio0.enabled='0'
uci set wireless.default_radio0.disabled='1'
uci set wireless.default_radio0.key=$ADMIN_WIFI_PASS
uci set wireless.default_radio1.ssid=$ADMIN_WIFI_SSID
uci set wireless.default_radio1.encryption='psk2'
uci set wireless.default_radio1.enabled='0'
uci set wireless.default_radio1.disabled='1'
uci set wireless.default_radio1.key=$ADMIN_WIFI_PASS
```

Set up the common wifi:

```
# Configuration parameters
WIFI_DEV="$(uci get wireless.@wifi-iface[0].device)"
WIFI_DEV5G="$(uci get wireless.@wifi-iface[1].device)"

# Set up common WLAN
uci set wireless.$WIFI_DEV.disabled=0
uci set wireless.$WIFI_DEV5G.disabled=0
uci set wireless.$WIFI_DEV.enabled=1
uci set wireless.$WIFI_DEV5G.enabled=1
uci delete network.common_dev
uci set network.common_dev=device
uci set network.common_dev.type=bridge
uci set network.common_dev.name=br-common
uci delete network.common
uci set network.common=interface
uci set network.common.proto=static
uci set network.common.device=br-common
uci set network.common.ipaddr=192.10.11.1
uci set network.common.netmask=255.255.255.0
uci commit network
uci delete wireless.common
uci set wireless.common0=wifi-iface
uci set wireless.common0.device=$WIFI_DEV
uci set wireless.common0.mode=ap
uci set wireless.common0.network=common
uci set wireless.common0.ssid=$MAIN_WIFI_SSID
uci set wireless.common0.key=$MAIN_WIFI_PASS
uci set wireless.common0.encryption=psk2
uci set wireless.common0.disabled=0
uci set wireless.common1=wifi-iface
uci set wireless.common1.device=$WIFI_DEV5G
uci set wireless.common1.mode=ap
uci set wireless.common1.network=common
uci set wireless.common1.ssid=$MAIN_WIFI_SSID
uci set wireless.common1.key=$MAIN_WIFI_PASS
uci set wireless.common1.encryption=psk2
uci set wireless.common1.encryption=none
uci set wireless.common1.disabled=0
uci commit wireless
uci delete dhcp.common
uci set dhcp.common=dhcp
uci set dhcp.common.interface=common
uci set dhcp.common.start=10
uci set dhcp.common.limit=250
uci set dhcp.common.leasetime=12h
uci commit dhcp
uci delete firewall.common
uci set firewall.common=zone
uci set firewall.common.name=common
uci set firewall.common.network=common
uci set firewall.common.input=REJECT
uci set firewall.common.output=ACCEPT
uci set firewall.common.forward=REJECT
uci delete firewall.common_wan
uci set firewall.common_wan=forwarding
uci set firewall.common_wan.src=common
uci set firewall.common_wan.dest=wan
uci delete firewall.common_dns
uci set firewall.common_dns=rule
uci set firewall.common_dns.name=Allow-DNS-common
uci set firewall.common_dns.src=common
uci set firewall.common_dns.dest_port=53
uci add_list firewall.common_dns.proto=tcp
uci add_list firewall.common_dns.proto=udp
uci set firewall.common_dns.target=ACCEPT
uci delete firewall.common_dhcp
uci set firewall.common_dhcp=rule
uci set firewall.common_dhcp.name=Allow-DHCP-common
uci set firewall.common_dhcp.src=common
uci set firewall.common_dhcp.dest_port=67
uci set firewall.common_dhcp.proto=udp
uci set firewall.common_dhcp.family=ipv4
uci set firewall.common_dhcp.target=ACCEPT
uci commit firewall
/etc/init.d/network reload
/etc/init.d/dnsmasq restart
/etc/init.d/firewall restart
```

If you want to enable the common wifi now:

```
uci set wireless.common.disabled=0
wifi
```

## Set up language

Connect the router to your lan by plugging an ethernet cable in the wan port. Do *NOT* disconnect it from your laptop/desktop now, we are still using the ssh session to set it up. Update the packages:

```
opkg update
```

Now install the basic language packages for Luci:

```
opkg install luci-i18n-base-$ROUTER_LANGUAGE_CODE luci-i18n-firewall-$ROUTER_LANGUAGE_CODE
```

## Set up wireguard

Update the packages:

```
opkg update
```

Install wireguard:

```
opkg install kmod-wireguard luci-i18n-wireguard-$ROUTER_LANGUAGE_CODE
```

Now set up wireguard:

```
uci set network.vpn=interface
uci set network.vpn.proto='wireguard'
uci set network.vpn.private_key=$WIREGUARD_CLIENT_PRIVATE_KEY
uci add_list network.vpn.addresses=$WIREGUARD_CLIENT_ADDRESS
uci set network.vpn.auto='1'
uci set network.wgserver=wireguard_vpn
uci set network.wgserver.public_key=$WIREGUARD_SERVER_PUBLIC_KEY
uci set network.wgserver.endpoint_host=$WIREGUARD_SERVER_PUBLIC_IP_ADDRESS
uci set network.wgserver.endpoint_port=$WIREGUARD_SERVER_LISTEN_PORT
uci set network.wgserver.route_allowed_ips='1'
uci set network.wgserver.persistent_keepalive='25'
uci add_list network.wgserver.allowed_ips=$WIREGUARD_ALLOWED_IPS
```

Apply changes:

```
uci commit
/etc/init.d/network restart
```

Enable wireguard watchdog to reconnect the vpn in case the connection fails. Edit the crontab:

```
crontab -e
```

Paste this line into it:

```
* * * * *   /usr/bin/wireguard_watchdog
```

Apply the changes:

```
/etc/init.d/cron restart
```

## The End

This should do it. Power off the router and you're good to go. By the time I've made this guide, the router used DHCP in the wan interface, so I did not change its settings. 

## References

[TP-Link Archer C20 v1](https://openwrt.org/toh/tp-link/archer_c20_v1)

