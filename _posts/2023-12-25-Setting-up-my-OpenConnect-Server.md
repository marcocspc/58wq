---
layout: post
title:  "Setting up my OpenConnect Server"
date:  2023-12-25 23:59:00 -0300 
categories: english vpn docker
---

# Setting up my OpenConnect Server 

In my testing, OpenConnect Server is a lot faster than Wireguard. The second is far easier to setup, but slower :(. So here I will be documenting the steps I took to configure my OpenConnect Server (ocserv).

In order to follow this document, I had to install docker and docker-compose, so please be advised.

## The Dockerfile and docker-compose files

First step was to generate a Dockerfile, this command should do it (copy and paste all lines at once):

```
cat << EOF > Dockerfile
FROM debian:12

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ocserv \
        gnutls-bin \
        iptables

CMD [ "/usr/sbin/ocserv" , "--foreground" ]
EOF
```

Second, create a docker-compose file:

```
cat << EOF > docker-compose.yaml
version: '3'
services:
  openconnect:
    container_name: openconnect-vpn
    build: .
    cap_add:
      - NET_ADMIN
    environment:
      - TZ="America/Fortaleza"
    volumes:
      - ${PWD}/ocserv-data:/etc/ocserv
      - ${PWD}/ocserv-data/certs:/etc/ocserv/ssl
    restart: unless-stopped
    devices:
      - /dev/net/tun:/dev/net/tun
    ports:
      - 8443:443/tcp
EOF
```

Then ask docker-compose to build the image:

```
docker-compose build
```

## Setting up OCServ in Docker with password based authentication

Now we need to generate a new configuration file to OpenConnect server. I'll be leaving one here with some basic configuration taken from mine, I'll be also stripping out all the comments from the file, in order to make it smaller. In order to understand which every option mean, [this is the official ocserv.conf documentation](https://ocserv.gitlab.io/www/manual.html).

```
mkdir -p ocserv-data && cat << EOF > ocserv-data/ocserv.conf
tcp-port = 443
run-as-user = nobody
run-as-group = daemon
socket-file = /var/run/ocserv-socket
server-cert = /etc/ocserv/ssl/server-cert.pem
server-key = /etc/ocserv/ssl/server-key.pem
ca-cert = /etc/ocserv/ssl/ca-cert.pem
isolate-workers = true
max-clients = 0
max-same-clients = 10
server-stats-reset-time = 604800
keepalive = 60
dpd = 90
mobile-dpd = 1800
switch-to-tcp-timeout = 25
try-mtu-discovery = false
cert-user-oid = 0.9.2342.19200300.100.1.1
compression = true
no-compress-limit = 256
tls-priorities = "NORMAL:%SERVER_PRECEDENCE:%COMPAT:-VERS-SSL3.0:-VERS-TLS1.0:-VERS-TLS1.1"
min-reauth-time = 300
max-ban-score = 80
ban-reset-time = 1200
cookie-timeout = 300
deny-roaming = false
rekey-time = 172800
rekey-method = ssl
connect-script = /etc/ocserv/connect.sh
disconnect-script = /etc/ocserv/disconnect.sh
use-occtl = true
pid-file = /var/run/ocserv.pid
device = vpns
predictable-ips = true
default-domain = example.com
ipv4-network = 192.168.1.0/24
ping-leases = false
tunnel-all-dns = true
dtls-legacy = false
auth = "plain[passwd=/etc/ocserv/ocpasswd]"
log-level = 3
route = default
dns = 1.1.1.1
EOF
```

As it is shown in the above configuration, there are a few files to be created. The first couple are the connection and disconnection scripts. These two are important because they can be used not only to echo messages into the container logs, but to run useful commands when a user comes in. In this particular case, a NAT rule is applied once a connection is made, so the client can have internet working, otherwise they would only be capable of communicating with IPs from the VPN range only. More on these scripts [can be found here](https://github.com/MarkusMcNugen/docker-openconnect/blob/master/ocserv/connect.sh) [and here](https://github.com/MarkusMcNugen/docker-openconnect/blob/master/ocserv/disconnect.sh).

So to the scripts creation:

```
cat << EOF > ocserv-data/connect.sh
#!/bin/bash

echo "\$(date) User \${USERNAME} Connected - Server: \${IP_REAL_LOCAL} VPN IP: \${IP_REMOTE}  Remote IP: \${IP_REAL} Device:\${DEVICE}"
echo "Running iptables MASQUERADE for User \${USERNAME} connected with VPN IP \${IP_REMOTE}"
iptables -t nat  -A POSTROUTING -s \${IP_REMOTE}/32 -o eth0 -j MASQUERADE
EOF
```

```
cat << EOF > ocserv-data/disconnect.sh
#!/bin/bash

echo "\$(date) User \${USERNAME} Disconnected - Bytes In: \${STATS_BYTES_IN} Bytes Out: \${STATS_BYTES_OUT} Duration:\${STATS_DURATION}"
EOF
```

Make the scripts executable:

```
chmod 750 ocserv-data/connect.sh ocserv-data/disconnect.sh
```

Now the certificates can be generated. These files are needed because [they are part of HTTPS specification](https://en.wikipedia.org/wiki/HTTPS#Difference_from_HTTP) and OCSERV works over that protocol. Fortunately, [the official OCSERV documentation](https://ocserv.gitlab.io/www/manual.html) has nice examples on how to do this. The first step is to generate the CA key and public certificates.

Generating the CA key:

```
docker-compose run openconnect certtool --generate-privkey --outfile /etc/ocserv/ssl/ca-key.pem 
```

Generating a template to create the CA certificate (it should be edited to match an specific context):

```
mkdir -p ./ocserv-data/certs && cat << EOF | sudo tee ./ocserv-data/certs/ca.tmpl
cn = "VPN CA"
organization = "MyOrganization"
serial = 007
expiration_days = -1
ca
signing_key
cert_signing_key
crl_signing_key
EOF
```

Generating a CA certificate:

```
docker-compose run openconnect certtool --generate-self-signed --load-privkey /etc/ocserv/ssl/ca-key.pem --template /etc/ocserv/ssl/ca.tmpl --outfile /etc/ocserv/ssl/ca-cert.pem
```

Now the server certificate can be generated. First the key:

```
docker-compose run openconnect certtool --generate-privkey --outfile /etc/ocserv/ssl/server-key.pem
```

The template:

```
mkdir -p ./ocserv-data/certs && cat << EOF | sudo tee ./ocserv-data/certs/server.tmpl
cn = "My server"
dns_name = "www.example.com"
organization = "MyCompany"
expiration_days = -1
signing_key
encryption_key #only if the generated key is an RSA one
tls_www_server
EOF
```

Finally, the certificate:

```
docker-compose run openconnect certtool --generate-certificate --load-privkey /etc/ocserv/ssl/server-key.pem --load-ca-certificate /etc/ocserv/ssl/ca-cert.pem --load-ca-privkey /etc/ocserv/ssl/ca-key.pem --template /etc/ocserv/ssl/server.tmpl --outfile /etc/ocserv/ssl/server-cert.pem
```

At this point, the VPN server should be ready to boot, but there is one last file needed: the password file. Since, for now, the server will be accepting only password based authentication, this file must be generated. This file generation and modification means that a new user must be added. So the next session will address this topic.

## Adding new users that will authenticate using a password

This is relatively simple. The following command can be run to add a new user:

```
docker-compose run openconnect ocpasswd -c /etc/ocserv/ocpasswd username
```

If the file doesn't exist, it will be generated.

## Running the server for the first time

Finally, the server can be started using the following command:

```
docker-compose up -d && docker-compose logs -f
```

The `docker-compose logs -f` is just to show the logs in real-time. If Ctrl-C is hit, the logs will stop being shown but the server will keep running.

## Enabling Certificate-Based Authentication

Since the server is already running properly, enabling certificate-based authentication on OCServ will be only a matter of generating the client certificate and enabling the configuration on ocserv settings.

In order to do this, according to [this guide](https://www.linuxbabe.com/ubuntu/certificate-authentication-openconnect-vpn-server-ocserv) the ocserv.conf file should be edited to alter the following line:

```
auth = "plain[passwd=/etc/ocserv/ocpasswd]"
```

To be:

```
enable-auth = "certificate"
auth = "plain[passwd=/etc/ocserv/ocpasswd]"
```

This shouldn't alter the way the server works now, because using these two entries will make the server accept both password and certificates as authentication methods.

Note: to keep using certificate authentication, the configuration file should keep "auth = plain (...)" line set, due to a bug certificate authentication won't work if "auth = certificate" is used.

After editing the configuration file, the server can be restarted:

```
docker-compose restart && docker-compose logs -f
```

## Adding users that will authenticate using certificates

It's almost the same process as generating the server certificate. A few environment variables can be used to help in this process. 

```
export SRV_CN="example.com" # the server common name, check server.tmpl file generated before to use the same here
export USERUID="johndoe" # the username 
export USERCN="John Doe" # the user... name 
```

First this user can be added to ocpasswd file (it doesn't need to have a password):

```
docker-compose exec openconnect ocpasswd -c /etc/ocserv/ocpasswd $USERUID
```

Then the template file can be then generated:

**Copy and paste all lines at once!**

```
sudo mkdir -p ./ocserv-data/certs/user-templates && cat << EOF | sudo tee ./ocserv-data/certs/user-templates/$USERUID.cfg
organization = "$SRV_CN"
cn = "$USERCN"
uid = "$USERUID"
expiration_days = -1
tls_www_client
signing_key
encryption_key
EOF
```

The user private key can be generated:

```
docker-compose exec openconnect certtool --generate-privkey --outfile /etc/ocserv/ssl/$USERUID-privkey.pem 
```

Finally the client certificate: 

```
docker-compose exec openconnect certtool --generate-certificate --load-privkey /etc/ocserv/ssl/$USERUID-privkey.pem --load-ca-certificate /etc/ocserv/ssl/ca-cert.pem --load-ca-privkey /etc/ocserv/ssl/ca-key.pem --template /etc/ocserv/ssl/user-templates/$USERUID.cfg --outfile /etc/ocserv/ssl/$USERUID-cert.pem
```

There are two paths now, if this certificate is going to be used in a iOS client, the following command can be used:

```
docker-compose exec openconnect certtool --to-p12 --load-certificate /etc/ocserv/ssl/$USERUID-cert.pem --load-privkey /etc/ocserv/ssl/$USERUID-privkey.pem --pkcs-cipher 3des-pkcs12 --hash SHA1 --outder --outfile /etc/ocserv/ssl/$USERUID.p12 
```

If not, this can be used:

```
docker-compose exec openconnect certtool --load-certificate /etc/ocserv/ssl/$USERUID-cert.pem --load-privkey /etc/ocserv/ssl/$USERUID-privkey.pem --pkcs-cipher aes-256 --to-p12 --outder --outfile /etc/ocserv/ssl/$USERUID.p12 
```

Finally, the `$USERUID.p12` file can be transferred to the client and imported. 

If needed, repeat these steps to add new clients.

## Revoking certificates 

#TODO this kind of certificate revogation is not working, try to do with connect.sh instead

To remove clients (prevent them from logging in the VPN again), the UID should be removed from the ocpasswd file and the certificate added to a Certificate Revocation List (CRL).

In order to do that, a CRL template must be generated:

```
cat << EOF | sudo tee ./ocserv-data/certs/crl.tmpl
crl_next_update = 365
crl_number = 1
EOF
```

Now the user certificate can be renamed:

```
sudo mv ./ocserv-data/certs/$USERUID-cert.pem ./ocserv-data/certs/$USERUID-cert.revoked.pem
```

Then it can be appended to the REVOKED PEM:

```
cat ./ocserv-data/certs/$USERUID-cert.revoked.pem | sudo tee -a ./ocserv-data/certs/revoked.pem
```

Next certtool is used to update the CRL pem file:

```
docker-compose exec openconnect certtool --generate-crl --load-ca-privkey /etc/ocserv/ssl/ca-key.pem --load-ca-certificate /etc/ocserv/ssl/ca-cert.pem --load-certificate /etc/ocserv/ssl/revoked.pem --template /etc/ocserv/ssl/crl.tmpl --outfile /etc/ocserv/ssl/crl.pem
```

Add the following line to `ocserv.conf`:

```
crl = /etc/ocserv/ssl/crl.pem
```

Finally restart ocserv:

``` 
docker-compose restart && docker-compose logs -f
```

## References

- [Set up Certificate Authentication in OpenConnect VPN Server (ocserv)](https://www.linuxbabe.com/ubuntu/certificate-authentication-openconnect-vpn-server-ocserv)
- [ocserv manual](https://ocserv.gitlab.io/www/manual.html)
