---
layout: post
title:  "Setting up my OpenConnect Server"
date:  2023-09-10 21:07:25 -0300 
categories: english vpn docker
---

# Setting up my OpenConnect Server 

In my testing, OpenConnect Server is a lot faster than Wireguard. The second is far easier to setup, but slower :(. So here I will be documenting the steps I took to configure my OpenConnect Server (ocserv).

## The Dockerfile

First step was to generate a Dockerfile, this command should do it (copy and paste all lines at once):

```
cat << EOF > Dockerfile
FROM fedora:39

RUN dnf -y install ocserv
WORKDIR /etc/ocserv

ENTRYPOINT [/usr/sbin/ocserv, -c, ocserv.conf, -f]
EOF
```

Then build the image:

```
docker build . -t ocserv-docker
```

## Setting up OCServ in Docker with password based authentication

Now we need to copy the base configuration file from the image, to do that we create a temporary container and copy the file to a directory so we can make some modifications:

```
docker create --name temporary-container ocserv-docker
mkdir ocserv-data
docker cp temporary-container:/etc/ocserv/ocserv.conf ocserv-data/
docker rm temporary-container
```

```
version: '3'
services:
  openconnect:
    container_name: openconnect-vpn
    image: "archef2000/ocserv"
    environment:
      - TZ="America/Fortaleza"
    env_file: 
      - cert_config.env
      - vpn.env
    volumes:
      - ${PWD}/ocserv_data:/etc/ocserv
    restart: unless-stopped
    ports:
      - 4443:443/tcp
      - 4443:443/udp
```

Some highlights:
- I'm working on removing the `privileged: true` part of the container, I left that there to make it work since I was in a hurry;
- The `vpn.env` file contains has the following content:
```
DNS_SERVERS=1.1.1.1,1.0.0.1
```
- The `cert_config.env` file contains has the following content:
```
CA_CN="VPN CA"
CA_ORG=OCSERV
CA_DAYS=3650
SRV_CN=example.com
SRV_ORG=Home
SRV_DAYS=3650
```
- The files inside `ocserv_data` were generated automatically by the container on first run.

With that said, this was the command I used to run it:
```
docker compose up -d
```

And after the container was running, this was the command to generate a password:
```
docker exec -it $(docker-compose ps -q) ocpasswd <USERNAME>
```

This should create a user to use the VPN.


## Generating user certificates

According to [this guide](https://www.linuxbabe.com/ubuntu/certificate-authentication-openconnect-vpn-server-ocserv) we need to install `certtool` and generate our own ca certificate. Fortunately, the image `archef2000/ocserv`, used here, not only has the tool installed, as it generates the certificate at container's first boot. So no worries on this part.

The certificates are present, on the host, at `${PWD}/ocserv_data/certs` and, in the container, at `/etc/ocserv/certs`. That information is provided to clarify why the following commands will sometime uses the host directory or the container directory. That shouldn't be a problem, though, because all commands should be ran on host.

Ok, so the next step is to create a temporary config file that will be used to generate the client certificate. To do that, first let's create a few environment variables that will help us create that file:

```
export SRV_CN="example.com"
export USERUID="johndoe"
export USERCN="John Doe"
```

Now we generate the file:

**Copy and paste all lines at once!**

```
cat << EOF > ./$USERUID.cfg
# X.509 Certificate options
# The organization of the subject.
organization = "$SRV_CN"

# The common name of the certificate owner.
cn = "$USERCN"

# A user id of the certificate owner.
uid = "$USERUID"

# In how many days, counting from today, this certificate will expire. Use -1 if there is no expiration date.
expiration_days = 3650

# Whether this certificate will be used for a TLS server
tls_www_client

# Whether this certificate will be used to sign data
signing_key

# Whether this certificate will be used to encrypt data (needed
# in TLS RSA ciphersuites). Note that it is preferred to use different
# keys for encryption and signing.
encryption_key
EOF
```

Then we move the file to `ocserv_data` folder:

```
sudo mv $USERUID.cfg ocserv_data/
```

Generate a privkey:

```
docker-compose exec -it openconnect certtool --generate-privkey --outfile /etc/ocserv/certs/$USERUID-privkey.pem 
```

After that we can generate the client certificate. 

```
docker-compose exec -it openconnect certtool --generate-certificate --load-privkey /etc/ocserv/certs/$USERUID-privkey.pem --load-ca-certificate /etc/ocserv/certs/ca.pem --load-ca-privkey /etc/ocserv/certs/ca-key.pem --template /etc/ocserv/$USERUID.cfg --outfile /etc/ocserv/certs/$USERUID-cert.pem
```

There are two paths now, if this certificate is going to be used in a iOS client, run the following command:

```
docker-compose exec -it openconnect certtool --to-p12 --load-privkey /etc/ocserv/certs/$USERUID-privkey.pem --load-certificate /etc/ocserv/certs/$USERUID-cert.pem --pkcs-cipher 3des-pkcs12 --outfile /etc/ocserv/certs/$USERUID.p12 --outder
```

If not, run the following:

```
docker-compose exec -it openconnect certtool --to-p12 --load-privkey /etc/ocserv/certs/$USERUID-privkey.pem --load-certificate /etc/ocserv/certs/$USERUID-cert.pem --pkcs-cipher aes-256 --outfile /etc/ocserv/certs/$USERUID.p12 --outder
```

Now you can transfer the `$USERUID.p12` to your client and import it. *Do not* try to connect now, though, because we still need to enable the certificate based authentication.

If needed, repeat these steps to add new clients.

To remove clients, just edit the `./ocserv_data/ocpasswd` file and remove the line containing the username. You can also delete any certificate/key/p12 files of this user.

## Enabling certificate based authentication

In my setup, it was enabled only password authentication. Since I wanted to still have both enabled, in case certificate authentication could still fail, I'd do things slightly different. To enable BOTH, I would just need to add this to `vpn.env`:

```
echo "AUTH_METHOD=\"CERT,TEXT\"" >> vpn.env
```

Then restart the container:

```
docker-compose restart
```

TODO: enabling CERT in AUTH_METHOD crashes ocserv. I'm probably going to need a custom image.

## References

- [Set up Certificate Authentication in OpenConnect VPN Server (ocserv)](https://www.linuxbabe.com/ubuntu/certificate-authentication-openconnect-vpn-server-ocserv)
