-- Loaded into mpv by services/AnimeHeaven.qml. When the episode closes (quit or end), writes where it stopped
-- to the file the shell watches, so it can resume there next time or count the episode as watched.
local opts = { file = "", key = "" }
require("mp.options").read_options(opts, "anime-progress")

mp.add_hook("on_unload", 50, function()
    local pos, dur = mp.get_property_number("time-pos"), mp.get_property_number("duration")
    if opts.file == "" or not pos or not dur then
        return
    end
    local f = io.open(opts.file, "w")
    if f then
        f:write(string.format('{"key":"%s","pos":%.1f,"dur":%.1f}', opts.key, pos, dur))
        f:close()
    end
end)
