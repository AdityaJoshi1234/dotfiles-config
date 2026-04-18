#!/bin/sh

# The key pressed is passed as the first argument
key="$1"

case "$key" in
    # Bind to 'd' (Triggered in sxiv via Ctrl+x d)
    "d")
        # tr converts newlines to null characters to safely handle filenames with spaces
        # xargs -0 reads the null-separated list and passes it to dragon-drop
        tr '\n' '\0' | xargs -0 dragon-drop -a &
        ;;
        
    # You can add other keybindings here
    # "c")
    #     tr '\n' '\0' | xargs -0 xclip -selection clipboard -t image/png -i &
    #     ;;
esac
