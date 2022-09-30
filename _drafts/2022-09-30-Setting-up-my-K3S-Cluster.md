---
layout: post
title:  "Setting up my K3S Cluster"
date:  2022-09-30 15:13:38 -0300 
categories: english linux kubernetes  
---

# Setting up my K3S Cluster 

I got my hands in a few Raspberries Pi recently. In one of them I have setup Open Media Vault, in the other three I've got K3S running using [this](https://www.padok.fr/en/blog/raspberry-kubernetes) guide. After that I've started reading about Kubernetes and how I could migrate from docker compose.

One thing that I've discovered is that I could use [Kompose](https://kompose.io/installation/) to convert my docker files to my new setup. Still, I've had some things that I could not understand.

First: how could I store my volumes? I've learned that Kubernetes should be stateless and that I should store files in a separate node, like my OMV (OpenMediaVault). On the other hand, I'd like to store the files in a distributed manner, in a way to achieve High Availability (HA) of services. 

Second: how could I have HA in multiple nodes? From what I've read, when a worker node stops working, another one takes its place and get the service up and running again. But the IP changes to this new worker node. That can cause a routing and DNS nightmare.

Then I've got to read [this guide]().
