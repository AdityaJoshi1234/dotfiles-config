#!/usr/bin/bash
notify-send -t 700 "Playing Video in 1080p"
mpv --profile=1080p $(xsel -bo)

