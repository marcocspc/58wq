---
layout: post
title:  "Creating a dummy database for testing purposes"
date:  2024-04-21 17:35:28 -0300 
categories: english databases postgres 
---

# Creating a dummy database for testing purposes 

In my current job I'm in the process of writing a documentation about databases. In order to show some usage examples, I've thought of using a dataset with sample data.

## Requirements

So, in order to do this, I'd need to have installed docker and docker-compose.

## Downloading the CSV file

So, the most important phase of creating this dummy database would be to find a source. Luckily, [this repository on Github](https://github.com/MainakRepositor/Datasets) has a lot of files that can be used to fill the tables with records. Here I'd be using their [Anime Dataset](https://github.com/MainakRepositor/Datasets/blob/master/anime.csv), since it is from a topic that I like and has a ton of records.

In order to download it, I'd do the following:
```
wget https://raw.githubusercontent.com/MainakRepositor/Datasets/master/anime.csv
```

## Creating the PostgreSQL container specification

First, I'd need to create a `docker-compose.yaml` file:

```
cat << EOF > docker-compose.yaml
version: "3"

services:
  postgres:
    image: postgres
    volumes:
      - ./postgres-data:/var/lib/postgresql/data
      - ./postgres-init-scripts/:/docker-entrypoint-initdb.d
      - ./anime.csv:/anime.csv
    environment:
      - "POSTGRES_PASSWORD=<YourStrong@Passw0rd>"
EOF
```

In the file, I've defined a container that would store the database files inside a folder called `postgres-data`. It'd also have a init script that would create the only table in my database and mount the csv file.

Before starting the service, though, I'd need to generate the database creation script. To do this, I'd have to first read the headers by checking the first line in the CSV file:

```
head -1 anime.csv
```

Output:
```
anime_id,name,genre,type,episodes,rating,members
```

Based on that, this would be the creation script. I've had to create all the data types as varchar, because postgres wouldn't know how to deal with multiple 'NULL' types (such as an empty string or the word "Unknown"):
```
mkdir -p postgres-init-scripts && cat << EOF > postgres-init-scripts/create-database.sh
#!/bin/bash
set -e

createdb ANIMES

bash -c "psql -d ANIMES -v ON_ERROR_STOP=1 --username postgres <<-EOSQL

    CREATE TABLE animes (
        id SERIAL,
        name VARCHAR(100),
        genre VARCHAR(200),
        type VARCHAR(20),
        episodes VARCHAR(10),
        rating VARCHAR(10),
        MEMBERS VARCHAR(10),
        PRIMARY KEY (id)
    );

EOSQL"
EOF
```

Make the script executable:
```
chmod +x postgres-init-scripts/create-database.sh
```

Finally, create the container:
```
docker-compose up -d 
```

## Importing the data

In order to import the data, I'd have to get a psql shell in the container:

```
docker-compose exec postgres psql -d ANIMES -v ON_ERROR_STOP=1 --username postgres 
```

Then I could run the following command to import the data:
```
COPY animes(id,name,genre,type,episodes,rating,members)
FROM '/anime.csv'
DELIMITER ','
CSV HEADER;
```

The data was imported successfully. But I still needed to change the columns values to match their real type. Before, I've created every column as a char type, now I'd change some types to float and integer. But before that, I'd have to check a few rows to have some idea of the data types:

```
SELECT * FROM ANIMES LIMIT 10;
```

Output:
```
  id   |                           name                            |                            genre                             | type  | episodes | rating | members 
-------+-----------------------------------------------------------+--------------------------------------------------------------+-------+----------+--------+---------
 32281 | Kimi no Na wa.                                            | Drama, Romance, School, Supernatural                         | Movie | 1        | 9.37   | 200630
  5114 | Fullmetal Alchemist: Brotherhood                          | Action, Adventure, Drama, Fantasy, Magic, Military, Shounen  | TV    | 64       | 9.26   | 793665
 28977 | Gintama°                                                  | Action, Comedy, Historical, Parody, Samurai, Sci-Fi, Shounen | TV    | 51       | 9.25   | 114262
  9253 | Steins;Gate                                               | Sci-Fi, Thriller                                             | TV    | 24       | 9.17   | 673572
  9969 | Gintama&#039;                                             | Action, Comedy, Historical, Parody, Samurai, Sci-Fi, Shounen | TV    | 51       | 9.16   | 151266
 32935 | Haikyuu!!: Karasuno Koukou VS Shiratorizawa Gakuen Koukou | Comedy, Drama, School, Shounen, Sports                       | TV    | 10       | 9.15   | 93351
 11061 | Hunter x Hunter (2011)                                    | Action, Adventure, Shounen, Super Power                      | TV    | 148      | 9.13   | 425855
   820 | Ginga Eiyuu Densetsu                                      | Drama, Military, Sci-Fi, Space                               | OVA   | 110      | 9.11   | 80679
 15335 | Gintama Movie: Kanketsu-hen - Yorozuya yo Eien Nare       | Action, Comedy, Historical, Parody, Samurai, Sci-Fi, Shounen | Movie | 1        | 9.10   | 72534
 15417 | Gintama&#039;: Enchousen                                  | Action, Comedy, Historical, Parody, Samurai, Sci-Fi, Shounen | TV    | 13       | 9.11   | 81109
```

The columns `episodes` and `members` would be converted to `integer` and `rating` would be `real`. So to update each column, I'd have to do as follows.

1. For the `episodes` column:
```
ALTER TABLE animes
ALTER COLUMN episodes
TYPE integer
USING
    CASE episodes
        WHEN 'Unknown' THEN NULL
        WHEN '' THEN NULL
        ELSE episodes::integer
    END;
```

2. For the `rating` column:
```
ALTER TABLE animes
ALTER COLUMN rating
TYPE real
USING
    CASE rating
        WHEN '' THEN NULL
        ELSE rating::real
    END;
```

2. For the `members` column:
```
ALTER TABLE animes
ALTER COLUMN members
TYPE integer
USING
    CASE members
        WHEN '' THEN NULL
        ELSE members::integer
    END;
```

After these changes, the database would be ready for inserting new data, performing selects, etc.

And that's it!
