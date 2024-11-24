---
layout: post
title:  "Hosting Bookstack using docker-compose"
date:  2024-11-23 19:15:00 -0300 
categories: english linux bookstack
---

# Hosting Bookstack using docker-compose 

I'm about to migrate my network to a new router. As things are going to get more complicated in my house (I'll have a proper router as the edge of my network and my current OpenWRT Wi-Fi one is going to become an AP), I thought it was time to run my personal wiki and chose [Bookstack](https://github.com/BookStackApp/BookStack) for this.

## Variables

As always, here are a few variables that I use to customize the files:

```
export TZ="America/Fortaleza"
read -p "Insert the APP_URL: " APP_URL;\
read -p "Insert MARIADB_ROOT_PWD: " MARIADB_ROOT_PWD;\
read -p "Insert BOOKSTACK_MARIADBUSER_PWD: " BOOKSTACK_MARIADBUSER_PWD
```

OBS.: the APP_URL is something like:  "http://bookstack.server.local:6875"

## Needed files

Also, I'd have to craft a `docker-compose.yaml` and a `.env` to protect sensitive data.

First the `.env`:

```
cat << EOF > .env
DB_PASSWORD=$BOOKSTACK_MARIADBUSER_PWD
MARIADB_PASSWORD=$BOOKSTACK_MARIADBUSER_PWD
MARIADB_ROOT_PASSWORD=$MARIADB_ROOT_PWD
EOF
```

Finally, the `docker-compose.yaml`:

```
cat << EOF > docker-compose.yaml
services:
  mariadb:
    image: mariadb:latest
    restart: unless-stopped
    env_file: .env
    environment:
      - MARIADB_USER=bookstack
      - MARIADB_DATABASE=bookstack 
    volumes:
      - ./mariadb_data:/var/lib/mysql
    networks:
      bookstack_mariadb:
        aliases:
          - mariadb
    healthcheck: # needed because bookstack won't wait for the db to be fully initialized
      test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"] 
      timeout: 20s #this will make the startup hang a litte bit while docker wait the mariadb container to be ready, adjust the value as needed
      

  bookstack:
    image: lscr.io/linuxserver/bookstack:latest
    restart: unless-stopped
    env_file: .env
    depends_on: # needed because bookstack won't wait for the db to be fully initialized
      mariadb:
        condition: service_healthy
    environment:
      - APP_URL="$APP_URL"
      - APP_LANG="pt_BR" # check: https://www.bookstackapp.com/docs/admin/language-config/
      - PUID=1000
      - PGID=1000
      - TZ=America/Fortaleza
      - DB_HOST=mariadb
      - DB_PORT=3306
      - DB_USERNAME=bookstack
      - DB_DATABASE=bookstack
      - QUEUE_CONNECTION=database # needed to allow webhook sending aseynchronously, this will speed up page loading. see: https://www.bookstackapp.com/docs/admin/email-webhooks/#async-action-handling 
    volumes:
      - ./bookstack_data:/config
    ports:
      - 6875:80
    networks:
      bookstack_mariadb:
        aliases:
          - bookstack


networks:
  bookstack_mariadb:
EOF
```

Before running the APP, another variable must be set which is the `APP_KEY` variable. This is needed to encrypt things where needed inside the app, as described [here](https://github.com/BookStackApp/BookStack/blob/development/.env.example.complete). To do this, the following command can be issued:

```
docker run -it --rm --entrypoint /bin/bash lscr.io/linuxserver/bookstack:latest appkey 
```

The output of the above command must be copied and pasted into the `.env` file generated before. I tried echoing it directly, but due to the way that the base64 string is generated, it doesn't work. In the end, the .env file should be something like this:

```
DB_PASSWORD=xxx                                                             
MARIADB_PASSWORD=xxx                                                             
MARIADB_ROOT_PASSWORD=xxx                                                             
APP_KEY="xxx"
```

The double quotes must be only on the `APP_KEY` line, for the other variables they are optional.

Finally, bring up the service for the first time:
```
docker-compose up -d && docker-compose logs -f
```

The page should be ready in a few moments. The default user and password is "admin@admin.com" and "password".

That's it!
