---
layout: post
title:  "Moving my Proxmox server to an untrusted, natted network"
date:  2022-01-26 16:01:26 -0300 
categories: english linux proxmox 
---

# Moving my Proxmox server to an untrusted, natted network 

What happened? Well, I wanted to get my server to my brother's house. There, it would sit comfortable in his LAN. But as this server provides me some valuable services with sensitive data, I wanted to protect it as much as I could. I wanted to set up encryption on it's partitions, but that's gonna be in another episode.

Now, in this document, I want to focus on network security. So what are my objectives?

1. Connect this server to my lan by installing wireguard and setting up the VPN configuration;
2. Put vmbr0 to get IP via dhcp;
3. Put all VMs natted and forwarding the needed ports to wg0 (wireguard interface);
4. Block all connections to eth0 and vmbr0 using iptables.

## Installing Wireguard

If you (like me) does not have a license for proxmox, you need to enable the community repository to make this work. Edit /etc/apt/sources.list.d/pve-enterprise.list and comment out the following line:

```
deb https://enterprise.proxmox.com/debian/pve bullseye pve-enterprise
#should become:
#deb https://enterprise.proxmox.com/debian/pve bullseye pve-enterprise
```

Now, to enable community repository, uncomment the last line in /etc/apt/sources.list: 

```
#deb http://download.proxmox.com/debian/pve bullseye pve-no-subscription
#should become:
deb http://download.proxmox.com/debian/pve bullseye pve-no-subscription
```

Then update the repositories and install wireguard:

```
apt update && apt install wireguard
```

After this, put your client configuration in /etc/wireguard/wg0.conf and enable/start the service:

```
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0
```

## Put vmbr0 to get IP via DHCP

Since I'm going to access my server via wireguard, I don't need to worry about it's IP in my brother's network (neither should I bother him with this). So here I set vmbr0 to get its IP via DHCP. First, copy the old configuration so you can easily rollback if needed:

```
cp /etc/network/interfaces /etc/network/interfaces.bak
```

Now, delete the file and create a new one with the following contents:

```
auto lo
iface lo inet loopback

iface enp3s0 inet manual

#DHCP vmbr0
auto vmbr0
iface vmbr0 inet dhcp
	bridge-ports enp3s0
	bridge-stp off
	bridge-fd 0
```


## Make all VMs natted

Natting via Wireguard depends on how you have set up the interface in the client and on how you have set your server nat configuration. Check [here](https://gist.github.com/nealfennimore/92d571db63404e7ddfba660646ceaf0d) to see a quick how-to. Since we are already with wireguard working, I will focus here on how to create a second bridge to isolate the VMs from the main lan.

*Append* these lines to /etc/network/interfaces:

```
auto vmbr1
iface vmbr1 inet static
        address 192.168.1.1/24
        bridge-ports none
        bridge-stp off
        bridge-fd 0

        post-up echo 1 > /proc/sys/net/ipv4/ip_forward
        post-up iptables -t nat -A POSTROUTING -s '192.168.1.0/24' -o wg0 -j MASQUERADE
        post-down iptables -t nat -D POSTROUTING -s '192.168.1.0/24' -o wg0 -j MASQUERADE

```

*Make sure* that your wireguard interface has got the right name in the iptables command. As mine was not wg0, it wasn't working until I fixed the name.

Now on every VM you have, configure your IP to be in the same subnetwork as vmbr1. My Windows VM, for example, I have put the IP 192.168.1.2, netmask 255.255.255.0 and gateway to 192.168.1.1. As DNS I used my Wireguard server. Remember to set your NIC to use the vmbr1 bridge in your guest VM. 

For example, in Windows you can set the IP using the following command:

```
netsh interface ipv4 set address name="INTERFACE_NAME" static 192.168.1.2 255.255.255.0 192.168.1.1
netsh interface ipv4 set dns name="INTERFACE_NAME" static 8.8.8.8
```

## Block all connections on vmbr0

Just add this to vmbr0 interface configuration:

```
post-up iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
post-up iptables -A INPUT -i vmbr0 -j DROP
```

## Expose VM port

For every vm that needs a port exposed, run this command for tcp connections:

```
iptables -t nat -A PREROUTING -d YOUR-WIREGUARD-IP/32 -p tcp -m tcp --dport HOST-PORT -j DNAT --to-destination YOUR-VM-IP:YOUR-VM-PORT
```

For udp, run this:

```
iptables -t nat -A PREROUTING -d YOUR-WIREGUARD-IP/32 -p tcp -m tcp --dport HOST-PORT -j DNAT --to-destination YOUR-VM-IP:YOUR-VM-PORT
iptables -t nat -A PREROUTING -p udp -i YOUR-WIREGUARD-INTERFACE -d YOUR-WIREGUARD-IP --dport HOST-PORT -j DNAT --to-destination YOUR-VM-IP:YOUR-VM-PORT
```

And we're done!

## References

[TUTORIAL PVE 6.2 Private VM (NAT) network configuration setup](https://forum.proxmox.com/threads/pve-6-2-private-vm-nat-network-configuration-setup.71038/)
