#!/usr/bin/bash
notify-send "Connecting To Shield-TV"
scrcpy -b 2000k --no-audio --tcpip=192.168.1.178
