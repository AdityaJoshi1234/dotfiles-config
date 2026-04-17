#!/bin/bash
while [ "$select" != "CANCEL" -a "$select" != "LOGOUT" -a "$select" != "POWEROFF" -a "$select" != "REBOOT" ];
do
	select=$(echo -e 'CANCEL\nLOGOUT\nPOWEROFF\nREBOOT' | dmenu -c -l 20 -fn "JetBrains MonoNL Nerd Font:style=Light:size=13") 
#		-p "You pressed the exit shortcut. Do you really want to exit i3?")
	[ -z "$select" ] && exit 0
done
[ "$select" = "CANCEL" ] && exit 0
[ "$select" = "LOGOUT" ] && i3-msg exit
[ "$select" = "POWEROFF" ] && /usr/bin/dbus-send --system --print-reply --dest="org.freedesktop.ConsoleKit" /org/freedesktop/ConsoleKit/Manager org.freedesktop.ConsoleKit.Manager.Stop
[ "$select" = "REBOOT" ] && /usr/bin/dbus-send --system --print-reply --dest="org.freedesktop.ConsoleKit" /org/freedesktop/ConsoleKit/Manager org.freedesktop.ConsoleKit.Manager.Restart
