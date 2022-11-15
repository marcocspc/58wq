---
layout: post
title:  "A workaround for a Wireguard Nat problem"
date:  2022-11-15 10:39:14 -0300 
categories: english linux wireguard
---

# A workaround for a Wireguard Nat problem 

I'm using a server in faraway place (see my [post]() about putting a host of mine in my brother's house), this host is connected to my main network via wireguard. For some weird reason (that I wasn't been able to troubleshoot) this host cannot communicate to some sites. The ones I've tested so far are Github, Stack Overflow and Docker Hub. I was able, indeed, to workaround this by using an SSH tunnel and proxychains to run commands that needed access to these sites. So I'm documenting them here for future referral.

## Installing proxychains

Install proxychains on your host:

```
sudo apt update && sudo apt install proxychains4
```

If your host cannot update or install packages due to the same problem. You can use another machine to download the package and copy it over. On another machine:

```
sudo apt download proxychains4
```

Once downloaded copy it to your host (the command below is just an example, adapt it to your downloaded version and your host ip):

```
scp ./proxychains4_4.14-1_amd64.deb your-user@your.host.ip:~
```

Then you can install on the target by running (again, adapt the command to your context):

```
sudo apt install ./proxychains4_4.14-1_amd64.deb 
```

After proxychains is installed, you need to generate a config file to use it. Run this command to set it up (copy and pasting all lines at once):

```
mkdir -p ~/.proxychains && cat << EOF > ~/.proxychains/proxychains.conf
strict_chain
quiet_mode
proxy_dns
remote_dns_subnet 224
tcp_read_time_out 15000
tcp_connect_time_out 8000
localnet 127.0.0.0/255.0.0.0

[ProxyList]
socks4  127.0.0.1 8888
EOF
```

Before using proxychains, though, it is needed to create a tunnel to another host that is not suffering from these connection problems. Use ssh to do this:

```
ssh -D 127.0.0.1:8888 -N -f user@server
```

-D means a socks proxy
-N no command
-f background

Then you can use proxychains to run your command. For example:

```
proxychains sudo apt update
```

And we're done!
