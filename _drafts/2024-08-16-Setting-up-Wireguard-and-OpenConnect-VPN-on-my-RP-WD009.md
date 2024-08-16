---
layout: post
title:  "Setting up Wireguard and OpenConnect VPN on my RP-WD009"
date:  2024-08-16  0:24:29 UTC00 
categories: english linux openwrt  
---

# Setting up Wireguard and OpenConnect VPN on my RP-WD009 

I'm finally going on a trip to Peru. In order to secure my Wan connection when in the hotel, I'm going to setup two VPN clients: Wireguard and OpenConnect.

There are also some permissions that I'll be setting here: as me and my wife are going to be using my RP-WD009, I'd like to block any connections to my LAN and other VPN nodes on the server, so by the end I'm also be going to add that layer of security with iptables. 

## Wireguard

I'll be exporting some variables that will help me run the commands afterwards:

```
export VPN_IF="wg0"
export VPN_SERV="server.ip"
export VPN_PORT="server.vpn.port"
export VPN_ADDR="192.168.9.2/24"
export CLIENT_PRIVATE_KEY="your-key"
export SERVER_PUBLIC_KEY="server-key"
```

First, according to [this guide](https://openwrt.org/docs/guide-user/services/vpn/wireguard/client), install the needed packages:
```
opkg update
opkg install wireguard-tools
```


Then let me create the network:
```
uci -q delete network.${VPN_IF}
uci set network.${VPN_IF}="interface"
uci set network.${VPN_IF}.proto="wireguard"
uci set network.${VPN_IF}.private_key="${CLIENT_PRIVATE_KEY}"
uci set network.${VPN_IF}.mtu="1280"
uci add_list network.${VPN_IF}.addresses="${VPN_ADDR}"
```

Now I add the server:
```
uci -q delete network.wgserver
uci set network.wgserver="wireguard_${VPN_IF}"
uci set network.wgserver.public_key="${SERVER_PUBLIC_KEY}"
uci set network.wgserver.endpoint_host="${VPN_SERV}"
uci set network.wgserver.endpoint_port="${VPN_PORT}"
uci set network.wgserver.persistent_keepalive="25"
uci set network.wgserver.route_allowed_ips="1"
uci add_list network.wgserver.allowed_ips="0.0.0.0/0"
```

Finally I add wireguard interface to the Wan firewall:
```
uci del_list firewall.zone[1].network="${VPN_IF}"
uci add_list firewall.zone[1].network="${VPN_IF}"
```

Commit and apply changes:
```
uci commit
/etc/init.d/firewall restart
/etc/init.d/network restart
```

That's it for wireguard.

By the way, to stop it:
```
uci network.${VPN_IF}.disabled="1"
uci commit
/etc/init.d/network restart
```

## OpenConnect
