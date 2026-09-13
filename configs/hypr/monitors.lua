-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 1

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))

-- Dell U2718Q (left) and LG ULTRAGEAR (right)
hl.monitor({ output = "HDMI-A-1", mode = "2560x1440@60", position = "0x0", scale = 1 })
hl.monitor({ output = "DP-1", mode = "2560x1440@165", position = "2560x0", scale = 1 })


