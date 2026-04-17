local utils = require 'mp.utils'

-- This function triggers when you stop a video or close mpv
mp.register_event("end-file", function()
    local url = mp.get_property("path")
    
    -- Safety check: if there's no path, or it's not a URL, stop here
    if url == nil or not (url:find("youtube.com") or url:find("youtu.be")) then
        return
    end

    mp.msg.info("Attempting to mark YouTube video as watched...")
    
    -- Run yt-dlp in the background so it doesn't freeze mpv on exit
    utils.subprocess_detached({
        args = {
            "yt-dlp", 
            "--cookies", "/home/aditya/.config/mpv/youtube-cookies.txt", 
            "--mark-watched", 
            "--simulate", 
            url
        }
    })
end)
