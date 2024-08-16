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
uci del_list firewall.@zone[1].network="${VPN_IF}"
uci add_list firewall.@zone[1].network="${VPN_IF}"
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

According to [the official guide](https://openwrt.org/docs/guide-user/services/vpn/openconnect/client), the first step is to install the required packages. So here I go:

```
opkg update && \
opkg install openconnect openssl-util
```

Before continuing, I'll be also using some variables here:
```
export VPN_IF="vpn"
export VPN_SERV="SERVER_ADDRESS"
export VPN_PORT="4443"
export VPN_USER="USERNAME"
```

[The official guide](https://openwrt.org/docs/guide-user/services/vpn/openconnect/client) tells me to use a password to connect the router to the VPN. Fortunately, I've set my OpenConnect instance to authenticate using client certificates. To perform that kind of authentication, I'll need more information regarding where to store the client certificates. That can be found [here](https://github.com/openwrt/packages/blob/master/net/openconnect/README).

As it's written in the reference, the certificates should be present in the directory `/etc/openconnect/` with the following names:
```
/etc/openconnect/user-cert-vpn-$VPNIF.pem: The user certificate
/etc/openconnect/user-key-vpn-$VPNIF.pem: The user private key
```

As I need those certificates, I'll be using my [own guide](https://marcocspc.github.io/58wq/english/vpn/docker/2023/12/26/Setting-up-my-OpenConnect-Server.html) to add a new client to my vpn to authenticate the router, then I'll copy them to the portable device.

After adding the certificates to the proper folders, I need to get the server hash. To do that, I need to download the server certificate: 
```
openssl s_client -showcerts -connect ${VPN_SERV}:${VPN_PORT} < /dev/null > /tmp/server-cert.pem
```

Then I can get the server hash:
```
export VPN_HASH="pin-sha256:$(openssl x509 -in /tmp/server-cert.pem -pubkey -noout \
| openssl pkey -pubin -outform der \
| openssl dgst -sha256 -binary \
| openssl enc -base64)"
```

Next, set the basic configuration:
```
uci -q delete network.${VPN_IF}
uci set network.${VPN_IF}="interface"
uci set network.${VPN_IF}.proto="openconnect"
uci set network.${VPN_IF}.server="${VPN_SERV}"
uci set network.${VPN_IF}.port="${VPN_PORT}"
uci set network.${VPN_IF}.username="${VPN_USER}"
uci set network.${VPN_IF}.serverhash="${VPN_HASH}"
```

Add the VPN interface to WAN firewall rules:
```
uci del_list firewall.@zone[1].network="${VPN_IF}"
uci add_list firewall.@zone[1].network="${VPN_IF}"
```

Restart firewall and network services:
```
/etc/init.d/firewall restart
/etc/init.d/network restart
```

After this is done, the vpn connection will fail. A reboot is needed to make it work properly:
```
reboot
```

That should be it for openconnect.

By the way, to stop it:
```
uci set network.${VPN_IF}.disabled="1"
uci commit
/etc/init.d/network restart
```

## Adding a layer of security

Another thing I'd like to do is to block any access to my lan hosts on the server side. As the packets go through the VPN host, they are masqueraded by NAT, and by default the VPN server has the permission to access all lan services. 

In order to perform that, I need to use iptables and block all the connections. Let me do this on wireguard first.

### Blocking things on Wireguard (WIP NOT WORKING YET)

On `wg0.conf` I have a structure that looks like this:

```
(...)
PostUp = iptables -A rule 1
PostUp = iptables -A rule 2
(...)
PostDown = iptables -D rule 1
PostDown = iptables -D rule 2
(...)
```

These commands are executed in order, when the wg interface is brought up and down respectively. Also, the `-A` and `-D` flags means that each one are added and removed upon VPN start and stop.

What I need to do is to add a few PostUp lines that look like the following one:
```
iptables -A INPUT -s ROUTER_VPN_IP_ADDRESS/32 -d NETWORK_ADDRESS/NETMASK -j DROP
```

For instance, if I wanted to block all the connections to a 172.10.13.0/24 network, the following lines should be added to the file:

```
(...)
PostUp = iptables -A INPUT -s ROUTER_VPN_IP_ADDRESS/32 -d 172.10.13.0/24 -j DROP
(...)
PostDown = iptables -D INPUT -s ROUTER_VPN_IP_ADDRESS/32 -d 172.10.13.0/24 -j DROP
```

That should do it.
