---
layout: post
title:  "Installing Zabbix server in a LXD container and nested Docker"
date:  2022-03-07 19:48:57 -0300 
categories: english linux lxd
---

# Installing Zabbix server in a LXD container and nested Docker 

After getting my old Banana Pro to work again, by installing Armbian's Banana Pi M1 image on it, I decided to install Zabbix. Oh, and just one explanation I should leave here just to document it: apparently, Banana Pi M1 driver is more stable than the one made specifically for the Banana Pro image, at least until now I've been having an experience a lot stabler using the M1 image.

Anyway, let's begin. As I always tell, all the commands here should be run on the lxd host, not in the container, but proceed as you wish.

## Variables

SSH into your host and export these variables, so it is easier to paste commands and adapt this guide to your context:

```
export CONTAINER=example
export IMAGE=ubuntu:20.04
export HOST_ARCH=$(dpkg --print-architecture)
export POSTGRES_PASS='p4ssw0rd'
export TIMEZONE="America/Fortaleza"
export ZABBIXWEBUIEXTERNALPORT=44443
export ZABBIXEXTERNALPORT=10051
```

## Creating the container

Run this:

```
lxc launch $IMAGE $CONTAINER
```

Upgrade all packages:

```
lxc exec $CONTAINER -- apt update
lxc exec $CONTAINER -- apt upgrade -y
```

Change the container description (if desired):

```
lxc config edit $CONTAINER
```

Change the way lxc list the containers to these four columns: Name, State, IPV4 and Description:

```
lxc alias add list "list -c ns4d"
```

## Installing Zabbix

I will install Zabbix using docker (yeah, a container running inside a container). I was afraid to do this before, because to run docker inside a lxd container, you must enable a security feature called "security.nesting", my fear was that this would create a serious security flaw, but that doesn't seem to be the case.

According to [this](https://discuss.linuxcontainers.org/t/what-does-security-nesting-true/7156) question in linux containers forum, nested containers in lxd should only represent security concerns if one is running privileged containers. As this is not the case, we can use docker inside lxd by setting security.nesting to true.

But why on earth use docker inside lxd? As I always point out, lxd makes managing containers easier by organizing information and filesystem in a better way. On the other hand, the community around docker is enormous and there are a lot of ready-to-go solutions stored in images at dockerhub. So why not use the best of both worlds by nesting them?

So, as we already have our container running, now we are going to install docker inside it. First we must enable nesting, do this by running:

```
lxc stop $CONTAINER
lxc config set $CONTAINER security.nesting true
lxc start $CONTAINER
```

Now let's adapt the [official docker instructions](https://docs.docker.com/engine/install/ubuntu/) to run on our container. Install dependencies:

```
lxc exec $CONTAINER -- apt install -y ca-certificates curl gnupg lsb-release
```

Get docker's GPG key:

```
lxc exec $CONTAINER -- bash -c "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg"
```

Set up the repository:

```
export CONTAINER_RELEASE=$(lxc exec $CONTAINER -- lsb_release -cs)
lxc exec $CONTAINER -- bash -c "echo 'deb [arch=$HOST_ARCH signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $CONTAINER_RELEASE stable' | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null"
```

Update and install docker:

```
lxc exec $CONTAINER -- bash -c "apt update && apt install docker-ce docker-ce-cli containerd.io -y"
```

To install zabbix, first we need to run a database container, to do this, create a directory to store the DB files inside the container:

```
lxc exec $CONTAINER -- mkdir -p /docker_binds/database/data
```

Now start the database container:

```
lxc exec $CONTAINER -- docker run -d --name postgres-zabbix --restart unless-stopped -p 5432:5432 -v /docker_binds/database/data:/var/lib/postgresql/data/ -e PGDATA=/var/lib/postgresql/data/pgdata -e POSTGRES_PASSWORD=$POSTGRES_PASS -e POSTGRES_DB=zabbix -e POSTGRES_USER=zabbix postgres:14.2-alpine
```

Now to the Zabbix server container. Run this to get it running:

```
lxc exec $CONTAINER -- docker run -d --name zabbix-server --restart always -p 10051:10051 -e DB_SERVER_HOST="172.17.0.1" -e POSTGRES_USER="zabbix" -e POSTGRES_PASSWORD=$POSTGRES_PASS zabbix/zabbix-server-pgsql:trunk-alpine
```

And finally for the web-ui. First we create some self-signed certificates. Create a directory to store them:

```
lxc exec $CONTAINER -- sudo mkdir -p /etc/ssl/private
```

Generate the certificates:

```
lxc exec $CONTAINER -- openssl req -x509 -sha256 -nodes -days 1825 -newkey rsa:2048 -keyout /etc/ssl/private/ssl.key -out /etc/ssl/private/ssl.crt
lxc exec $CONTAINER -- openssl dhparam -out /etc/ssl/private/dhparam.pem 2048
```

Fix permissions:

```
lxc exec $CONTAINER -- chown root:root /etc/ssl/private/ssl.key
lxc exec $CONTAINER -- chown root:root /etc/ssl/private/ssl.crt
lxc exec $CONTAINER -- chown root:root /etc/ssl/private/dhparam.pem
lxc exec $CONTAINER -- chmod 644 /etc/ssl/private/ssl.key
lxc exec $CONTAINER -- chmod 644 /etc/ssl/private/ssl.crt
lxc exec $CONTAINER -- chmod 644 /etc/ssl/private/dhparam.pem
```

Finally run the WebUI container:

```
lxc exec $CONTAINER -- docker run -d --name zabbix-web --restart always -p 80:8080 -p 443:8443 -v /etc/ssl/private:/etc/ssl/nginx -e DB_SERVER_HOST="172.17.0.1" -e POSTGRES_USER="zabbix" -e POSTGRES_PASSWORD=$POSTGRES_PASS -e ZBX_SERVER_HOST="172.17.0.1" -e PHP_TZ=$TIMEZONE zabbix/zabbix-web-nginx-pgsql:alpine-trunk
```

## Finalizing

Expose zabbix ports to access the webui and allow clients to connect to it:

```
lxc config device add $CONTAINER zabbixwebui proxy listen=tcp:0.0.0.0:$ZABBIXWEBUIEXTERNALPORT connect=tcp:172.17.0.1:443
lxc config device add $CONTAINER zabbixserver proxy listen=tcp:0.0.0.0:$ZABBIXEXTERNALPORT connect=tcp:172.17.0.1:10051
```

Now you should be able to access your zabbix server at https://host.dns:44443/.

And we're done!

## References

[What does security.nesting=true?](https://discuss.linuxcontainers.org/t/what-does-security-nesting-true/7156)
[Install Docker Engine on Ubuntu](https://docs.docker.com/engine/install/ubuntu/)
[Instalando o Zabbix via Docker](https://blog.aeciopires.com/zabbix-docker/)
[How to Generate a Self-Signed Certificate and Private Key using OpenSSL](https://helpcenter.gsx.com/hc/en-us/articles/115015960428-How-to-Generate-a-Self-Signed-Certificate-and-Private-Key-using-OpenSSL)
[Best location to keep SSL certificates and private keys on Ubuntu servers?](https://serverfault.com/questions/259302/best-location-to-keep-ssl-certificates-and-private-keys-on-ubuntu-servers)
