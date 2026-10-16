-- Read Wallust's shared palette. Hyprlock and the legacy configuration still
-- consume the .conf file, so both configuration formats use one source.
local palette = {
    background = "rgb(1C1C1B)",
    foreground = "rgb(F9F9F9)",
    color0 = "rgb(434242)",
    color1 = "rgb(705445)",
    color2 = "rgb(838383)",
    color3 = "rgb(CFA687)",
    color4 = "rgb(97BAA8)",
    color5 = "rgb(F2E497)",
    color6 = "rgb(EFEFEF)",
    color7 = "rgb(EEEFEF)",
    color8 = "rgb(A7A7A7)",
    wallpaper_dominant = "rgb(CEB38D)",
    wallpaper_border1 = "rgb(FEFEFC)",
    wallpaper_border2 = "rgb(F7ECD2)",
    wallpaper_border3 = "rgb(F0D4B0)",
}

local home = os.getenv("HOME")
local palette_file = home and (home .. "/.config/hypr/colors-wallust.conf")

if palette_file then
    local file = io.open(palette_file, "r")
    if file then
        for line in file:lines() do
            local name, hex = line:match("^%$([%w_]+)%s*=%s*rgb%((%x+)%)")
            if name and hex then
                palette[name] = "rgb(" .. hex .. ")"
            end
        end
        file:close()
    end
end

return palette
