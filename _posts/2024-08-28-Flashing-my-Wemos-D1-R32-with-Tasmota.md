---
layout: post
title:  "Flashing my Wemos D1 R32 with Tasmota"
date:  2024-08-28 13:52:13 -0300 
categories: english iot tasmota
---

# Flashing my Wemos D1 R32 with Tasmota

I've bought a couple of Wemos D1 R32 from AliExpress. Every time I'm installing Tasmota on them, I kinda struggle to set the right parameters and etc. This time I'm going to take notes on how I did it.

## Download Tasmota

So, for this specific project, I'll be connecting the [AO2YYUW](https://wiki.dfrobot.com/_A02YYUW_Waterproof_Ultrasonic_Sensor_SKU_SEN0311) Ultrasonic Sensor to the Wemos Board, the idea here is to measure the water level in a tank. To do that, I'll need the [ESP32 specific version](https://github.com/arendst/Tasmota/releases/download/v14.2.0/tasmota32.factory.bin) of Tasmota. 

By the way, the specific version I'm mentioning here is the `tasmota32.factory.bin` file, which is the one that need to be used when flashing Tasmota for the first time.

If I was using an ESP8266 based board, the needed version would be [tasmota-sensors.bin](https://github.com/arendst/Tasmota/releases/), but the Tasmota ESP32 version already include sensor support. Let me download it then:

```
wget https://github.com/arendst/Tasmota/releases/download/v14.2.0/tasmota32.factory.bin
```

## Preparing the needed software

After the download is finished, I need to install the proper software to flash the binary.

For this, [Python 3](https://www.python.org/downloads/) will be needed:
```
brew install python3
```

Next, I can create a virtual environment:
```
python3 -m venv esptool
```

Activate it:
```
source ./esptool/bin/activate
```

Install the script:
```
pip3 install esptool
```

## Using the tool to flash the board

Normally, I would use a [USB-serial device converter](https://tasmota.github.io/docs/Getting-Started/#serial-programmer) to perform this operation, but the D1 R32 board has a serial programmer built-in, so to flash Tasmota I just need to connect the board to a USB port using a [micro USB cable](https://en.m.wikipedia.org/wiki/File:MicroB_USB_Plug.jpg).

After the connection, the device can be seen in `/dev/`:
```
ls /dev | grep usb
```

Output:
```
cu.usbserial-1420
tty.usbserial-1420
```

Finally I can flash the firmware:
```
esptool.py --port /dev/cu.usbserial-1420 write_flash 0x0 tasmota32.factory.bin
```

Output:
```
esptool.py v4.7.0
Serial port /dev/cu.usbserial-1420
Connecting....
Detecting chip type... Unsupported detection protocol, switching and trying again...
Connecting....
Detecting chip type... ESP32
Chip is ESP32-D0WD-V3 (revision v3.0)
Features: WiFi, BT, Dual Core, 240MHz, VRef calibration in efuse, Coding Scheme None
Crystal is 40MHz
MAC: e0:e2:e6:0b:4b:4c
Uploading stub...
Running stub...
Stub running...
Configuring flash size...
Flash will be erased from 0x00000000 to 0x001f4fff...
Compressed 2049264 bytes to 1298721...
Wrote 2049264 bytes (1298721 compressed) at 0x00000000 in 125.8 seconds (effective 130.4 kbit/s)...
Hash of data verified.

Leaving...
Hard resetting via RTS pin...
```

## Sensor Pinout

The pinout should be the following:

Red cable (sensor) <-> 5V (Wemos D1 R32)
Black cable (sensor) <-> Ground (Wemos D1 R32)
Yellow Cable (sensor) <-> Any IOX port (Wemos D1 R32) (Trigger)
White Cable (sensor) <-> Any IOX port (Wemos D1 R32) (Echo)

I can take note of the IOX ports and set them to SR04 Tri and SR04 echo on Tasmota Web UI, if it doesn't work I can invert them. For more information and images, here are some resources:

- [Bot n Roll page with pictures](https://www.botnroll.com/pt/sonares/4501-sensor-ultrasons-a02yyuw-prova-de-gua.html)
- [HC-SR04 ultrasonic ranging sensor — Tasmota](https://tasmota.github.io/docs/HC-SR04/#tasmota-settings)

## Connecting to Tasmota using Screen

Just in case, if I needed to connect to Tasmota using screen command, this was the one:
```
screen /dev/cu.usbserial-1420 115200
```

## Adding an antenna

One final step to complete the process is adding a Wifi Antenna. This is needed because without it the signal is very, very poor. Since this is more a hardware endeavor, I'll be linking the guide here: [How to add an external antenna to an ESP board](https://community.home-assistant.io/t/how-to-add-an-external-antenna-to-an-esp-board/131601F).

That should be it!!
