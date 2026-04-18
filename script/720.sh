#!/usr/bin/bash
notify-send -t 700 "Playing Video in 720p"
mpv --profile=720p --ytdl-raw-options=ignore-config=,sub-lang=en,write-auto-sub= $(xsel -bo)
