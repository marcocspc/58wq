---
layout: post
title:  "Remotely controlling my Heritage Virtuoso using a Raspberry Pi"
date:  2021-12-02  3:36:54 UTC00 
categories: english astronomy raspberry  
---

# Remotely controlling my Heritage Virtuoso using a Raspberry Pi 

So my newest project is to remotely control my telescope, which is a Heritage Virtuoso 114 fro Skywatcher, using a Raspberry Pi. 

Why though? Because the Raspberry can run a full Desktop, creating the possibility to use vnc or any remote desktop protocol to control it. With a webcam and the telescope itself connected to the board, I can sit and relax from a distance while I take my astropictures.

## The hardware

While googling about it, I've found some resources about connecting telescope mounts to the PC. Since the Raspberry as a full-blown one, I can use these. [One shows that]() some of these Alt Az mounts use a low voltage connection, which creates the necessity to use TLL serial connection. The much used RS232 cannot fit on these kind of connections because it has a voltage ratio of 12V, and my telescope uses 5V. Also, since the Raspberry has a USB port, I need a USB to TTL serial cable or adapter (there are cables which has the adapter built-in. 

Also, the other end of the cable must has a RJ12 connector. While researching I could not find the wiring specifically for my telescope, but [here]() I was able to find a manual that shows a schematics that might be compatible.

<!-- TODO: add the mentioned links -->
