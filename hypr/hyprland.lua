-- Active Hyprland 0.55+ Lua configuration.
-- The former hyprland.conf tree is intentionally kept as a fallback.

local colors = require("colors-wallust")
local main_mod = "SUPER"

-- Displays. Review these output names on different hardware.
hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "0x0", scale = 1 })
hl.monitor({ output = "eDP-1", mode = "preferred", position = "0x1080", scale = 1 })

-- Environment
hl.env("GTK_THEME", "Glassy-Originals-Gtk-Purple-Dark")
hl.env("QT_QPA_PLATFORMTHEME", "kde")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")

-- Core options
hl.config({
    input = {
        kb_layout = "us,dk",
        kb_variant = "",
        kb_model = "",
        kb_options = "caps:escape",
        numlock_by_default = false,
        follow_mouse = 1,
        mouse_refocus = false,
        sensitivity = 0,
        touchpad = {
            natural_scroll = true,
            scroll_factor = 1.0,
            disable_while_typing = false,
        },
    },
    general = {
        gaps_in = 2,
        gaps_out = 5,
        border_size = 2,
        col = {
            active_border = {
                colors = {
                    colors.wallpaper_border1,
                    colors.wallpaper_border2,
                    colors.wallpaper_border3,
                },
                angle = 90,
            },
            inactive_border = colors.background,
        },
        layout = "dwindle",
        resize_on_border = true,
    },
    decoration = {
        rounding = 10,
        active_opacity = 1.0,
        inactive_opacity = 0.9,
        fullscreen_opacity = 1.0,
        blur = {
            enabled = true,
            size = 8,
            passes = 2,
            new_optimizations = true,
            ignore_opacity = false,
            xray = false,
            noise = 0.03,
            contrast = 1.0,
            brightness = 1.0,
        },
        shadow = {
            enabled = true,
            range = 32,
            render_power = 2,
            color = "rgba(00000050)",
        },
    },
    binds = {
        workspace_back_and_forth = false,
        allow_workspace_cycles = true,
        pass_mouse_when_bound = false,
    },
    misc = {
        disable_hyprland_logo = true,
        disable_hyprland_guiutils_check = true,
        disable_splash_rendering = true,
        initial_workspace_tracking = 1,
        on_focus_under_fullscreen = 0,
        allow_session_lock_restore = true,
    },
    xwayland = {
        force_zero_scaling = true,
    },
    animations = {
        enabled = true,
    },
})

hl.device({
    name = "asuf1204:00-2808:0202-touchpad",
    enabled = false,
})

-- Configure dynamic-cursors only when hyprpm has successfully loaded it.
if hl.plugin.dynamic_cursors then
    hl.config({
        plugin = {
            dynamic_cursors = {
                enabled = true,
                mode = "tilt",
                shake = { enabled = false },
            },
        },
    })
end

-- This event only fires once when the compositor starts, so reloads do not
-- duplicate session services.
local autostart = {
    "hyprctl setcursor Bibata-Modern-Classic 23",
    "/usr/libexec/kf6/polkit-kde-authentication-agent-1",
    "/usr/libexec/pam_kwallet_init",
    "swaync",
    "/usr/libexec/DiscoverNotifier --check-delay 20",
    "~/.config/hypr/scripts/gtk.sh",
    "hypridle",
    "wl-paste --watch cliphist store",
    "~/.config/hypr/scripts/start_hyprsunset.sh",
    "~/.config/hypr/scripts/start_pyprland.sh",
    "~/.config/hypr/scripts/restore_wallpaper.sh",
    "hyprpm reload -n",
    "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP",
    "waybar",
}

hl.on("hyprland.start", function()
    for _, command in ipairs(autostart) do
        hl.exec_cmd(command)
    end
end)

for _, namespace in ipairs({ "rofi", "waybar", "swaync", "wlogout" }) do
    hl.layer_rule({ match = { namespace = namespace }, blur = true, ignore_alpha = 0 })
end

-- Window rules
hl.window_rule({ match = { class = "satty" }, float = true, center = true, animation = "fade" })
hl.window_rule({ match = { class = "Rofi" }, float = true, animation = "fade" })
hl.window_rule({ match = { class = "nautilus --new-window" }, float = true, animation = "fade" })
hl.window_rule({ match = { class = "org.kde.kcalc" }, float = true, center = true })
hl.window_rule({ match = { class = "firefox-developer-edition", title = "Picture-in-Picture" }, float = true, pin = true })
hl.window_rule({ match = { class = "nvim" }, border_size = 0 })
hl.window_rule({ match = { class = "kwrite" }, opacity = "0.97 0.92" })
hl.window_rule({ match = { class = "org.kde.kwrite" }, opacity = "0.97 0.92" })
hl.window_rule({ match = { class = "kmail" }, opacity = "0.97 0.92" })
hl.window_rule({ match = { class = "org.kde.kmail2" }, opacity = "0.97 0.92" })
hl.window_rule({ name = "vscode-max", match = { initial_class = "^(Code|code-url-handler)$" }, maximize = true })
hl.window_rule({
    name = "dontstarve-manual-fullscreen",
    match = { class = "^dontstarve_steam_x64$" },
    fullscreen = true,
    suppress_event = "fullscreen",
})

-- Animation curves and leaves
hl.curve("md3_decel", { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1 } } })
hl.curve("md3_accel", { type = "bezier", points = { { 0.3, 0 }, { 0.8, 0.15 } } })
hl.curve("overshot", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
hl.curve("menu_decel", { type = "bezier", points = { { 0.1, 1 }, { 0, 1 } } })
hl.curve("menu_accel", { type = "bezier", points = { { 0.38, 0.04 }, { 1, 0.07 } } })

hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.5, bezier = "overshot", style = "popin 80%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 4, bezier = "md3_accel", style = "popin 80%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 2.5, bezier = "md3_decel" })
hl.animation({ leaf = "border", enabled = true, speed = 3, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "md3_decel" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "menu_decel", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 2, bezier = "menu_accel", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 3, bezier = "menu_decel" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 3, bezier = "menu_accel" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4.5, bezier = "menu_decel", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4.5, bezier = "menu_decel", style = "slidevert" })

-- Keybindings
local function run(keys, command, options)
    hl.bind(keys, hl.dsp.exec_cmd(command), options)
end

run(main_mod .. " + RETURN", "kitty")
run(main_mod .. " + B", "flatpak run app.zen_browser.zen")
run(main_mod .. " + E", "dolphin")
run(main_mod .. " + W", "~/.config/hypr/scripts/cycle_wall.sh")
run(main_mod .. " + SPACE", "~/.config/waybar/scripts/keyboard_layout.sh toggle")

run(main_mod .. " + SHIFT + mouse_down", "hyprctl keyword cursor:zoom_factor $(awk \"BEGIN {print $(hyprctl getoption cursor:zoom_factor | grep 'float:' | awk '{print $2}') + 0.5}\")")
run(main_mod .. " + SHIFT + mouse_up", "hyprctl keyword cursor:zoom_factor $(awk \"BEGIN {print $(hyprctl getoption cursor:zoom_factor | grep 'float:' | awk '{print $2}') - 0.5}\")")
run(main_mod .. " + SHIFT + Z", "hyprctl keyword cursor:zoom_factor 1")

hl.bind(main_mod .. " + Q", hl.dsp.window.close(), { repeating = true })
run(main_mod .. " + SHIFT + Q", "hyprctl activewindow | grep pid | tr -d 'pid:' | xargs kill")
hl.bind(main_mod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(main_mod .. " + M", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
hl.bind(main_mod .. " + T", hl.dsp.window.float({ action = "toggle" }))
run(main_mod .. " + SHIFT + T", "hyprctl dispatch workspaceopt allfloat")
hl.bind(main_mod .. " + J", hl.dsp.layout("swapcol l"))

for _, direction in ipairs({ "left", "right", "up", "down" }) do
    hl.bind(main_mod .. " + " .. direction, hl.dsp.focus({ direction = direction }), { repeating = true })
end

hl.bind(main_mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(main_mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind(main_mod .. " + SHIFT + right", hl.dsp.window.resize({ x = 100, y = 0, relative = true }), { repeating = true })
hl.bind(main_mod .. " + SHIFT + left", hl.dsp.window.resize({ x = -100, y = 0, relative = true }), { repeating = true })
hl.bind(main_mod .. " + SHIFT + down", hl.dsp.window.resize({ x = 0, y = 100, relative = true }), { repeating = true })
hl.bind(main_mod .. " + SHIFT + up", hl.dsp.window.resize({ x = 0, y = -100, relative = true }), { repeating = true })

hl.bind(main_mod .. " + K", hl.dsp.layout("swapsplit"))
for _, direction in ipairs({ "left", "right", "up", "down" }) do
    hl.bind(main_mod .. " + ALT + " .. direction, hl.dsp.window.swap({ direction = direction }), { repeating = true })
end
hl.bind(main_mod .. " + CTRL + right", hl.dsp.layout("colresize +0.1"), { repeating = true })
hl.bind(main_mod .. " + CTRL + left", hl.dsp.layout("colresize -0.1"), { repeating = true })
hl.bind(main_mod .. " + P", hl.dsp.layout("promote"))
run(main_mod .. " + O", "flatpak run md.obsidian.Obsidian")
hl.bind("ALT + Tab", hl.dsp.window.cycle_next(), { repeating = true })
hl.bind("ALT + Tab", hl.dsp.window.bring_to_top(), { repeating = true })

run(main_mod .. " + CTRL + R", "hyprctl reload")
run(main_mod .. " + Print", "~/.config/hypr/scripts/screenshot_satty.sh")
run(main_mod .. " + SHIFT + Print", "~/.config/hypr/scripts/screenshot_full_save.sh")
run(main_mod .. " + CTRL + Print", "~/.config/hypr/scripts/screenshot_region_copy.sh")
run(main_mod .. " + SHIFT + C", "hyprpicker --autocopy --format hex --lowercase-hex")
run(main_mod .. " + L", "~/.config/hypr/scripts/lock.sh")
run(main_mod .. " + SHIFT + K", "kwrite")
run(main_mod .. " + SHIFT + M", "kmail")
run(main_mod .. " + SHIFT + B", "~/.config/hypr/scripts/waybar_restart.sh")
run(main_mod .. " + SUPER_L", "rofi -show drun -theme ~/.config/rofi/rounded-pink-dark")
run(main_mod .. " + A", "pypr toggle term")
run("SUPER + V", "cliphist list | rofi -dmenu -display-columns 2 | cliphist decode | wl-copy")
run(main_mod .. " + C", "code")
run(main_mod .. " + ESCAPE", "plasma-systemmonitor")
run(main_mod .. " + DELETE", "wlogout -b 3 -T 300 -B 300")
run("XF86PowerOff", "wlogout -b 3 -T 300 -B 300")
run(main_mod .. " + N", "swaync-client -t -sw")

for workspace = 1, 10 do
    local key = workspace % 10
    hl.bind(main_mod .. " + " .. key, hl.dsp.focus({ workspace = workspace }))
    hl.bind(main_mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = workspace, follow = false }))
end

run("XF86MonBrightnessUp", "brightnessctl -q s +5%")
run("XF86MonBrightnessDown", "brightnessctl -q s 5%-")
run("XF86AudioRaiseVolume", "wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+", { locked = true, repeating = true })
run("XF86AudioLowerVolume", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-", { locked = true, repeating = true })
run("XF86AudioMute", "pactl set-sink-mute @DEFAULT_SINK@ toggle")
run("XF86AudioPlay", "playerctl play-pause")
run("XF86AudioPause", "playerctl pause")
run("XF86AudioNext", "playerctl next")
run("XF86AudioPrev", "playerctl previous")
run("XF86AudioMicMute", "pactl set-source-mute @DEFAULT_SOURCE@ toggle")
run("XF86Calculator", "kcalc")
run("XF86ScreenSaver", "~/.config/hypr/scripts/lock.sh")
run("XF86Tools", "rofi -show drun -theme ~/.config/rofi/rounded-pink-dark")
run("code:238", "brightnessctl -d smc::kbd_backlight s +10")
run("code:237", "brightnessctl -d smc::kbd_backlight s 10-")
