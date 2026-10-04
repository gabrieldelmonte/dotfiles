-- ui.lua — lock-screen UI drawn inside mpv (loaded by saver_video).
--
-- idle    : the video with a large clock, the date and an unlock hint.
-- active  : (while typing) blurred, dimmed video and a GNOME-style card:
--           avatar with your initial, your name, a rounded password field
--           with dots, and a message line ("Wrong password", …).
--
-- auth_card drives it with:  script-message lockui <state> <dots> <message>
-- states: idle | active | checking | ok

local state, dots, message = "idle", 0, ""
local last_update = mp.get_time()
local overlay = mp.create_osd_overlay("ass-events")

-- Display name from the passwd "full name" field, else the login name.
local name = os.getenv("USER") or "user"
do
    local f = io.popen("getent passwd " .. name)
    local line = f and f:read("*l") or ""
    if f then f:close() end
    local full = line:match("^[^:]*:[^:]*:[^:]*:[^:]*:([^:,]*)")
    if full and full ~= "" then name = full end
end
local initial = name:sub(1, 1):upper()

-- Colours: "#rrggbb" → ASS "&HBBGGRR&".
local function c(hex) return "&H" .. hex:sub(6, 7) .. hex:sub(4, 5) .. hex:sub(2, 3) .. "&" end
local WHITE, BLUE, RED, BLACK = c("#ffffff"), c("#1e66f5"), c("#f38ba8"), c("#000000")
local FONT = "Ubuntu Sans"
local HALO = "\\bord3\\3c&H000000&\\3a&HA0&\\blur6\\shad0"

local function text(x, y, size, color, str, extra)
    return string.format("{\\an5\\pos(%d,%d)\\fn%s\\fs%d\\c%s%s%s}%s",
        x, y, FONT, size, color, HALO, extra or "", str)
end

-- Vector shapes (ASS drawing mode).
local function circle(cx, cy, r)
    local k = 0.5523 * r
    return string.format(
        "m %d %d b %d %d %d %d %d %d b %d %d %d %d %d %d b %d %d %d %d %d %d b %d %d %d %d %d %d",
        cx - r, cy, cx - r, cy - k, cx - k, cy - r, cx, cy - r,
        cx + k, cy - r, cx + r, cy - k, cx + r, cy,
        cx + r, cy + k, cx + k, cy + r, cx, cy + r,
        cx - k, cy + r, cx - r, cy + k, cx - r, cy)
end

local function rrect(x, y, w, h, r)
    local k = 0.5523 * r
    return string.format(
        "m %d %d l %d %d b %d %d %d %d %d %d l %d %d b %d %d %d %d %d %d l %d %d b %d %d %d %d %d %d l %d %d b %d %d %d %d %d %d",
        x + r, y, x + w - r, y,
        x + w - r + k, y, x + w, y + r - k, x + w, y + r,
        x + w, y + h - r,
        x + w, y + h - r + k, x + w - r + k, y + h, x + w - r, y + h,
        x + r, y + h,
        x + r - k, y + h, x, y + h - r + k, x, y + h - r,
        x, y + r,
        x, y + r - k, x + r - k, y, x + r, y)
end

local function shape(path, fill, fill_alpha, border, border_color)
    return string.format("{\\an7\\pos(0,0)\\p1\\c%s\\1a%s\\bord%d\\3c%s\\3a&H00&\\shad0\\blur0.6}%s{\\p0}",
        fill, fill_alpha, border or 0, border_color or fill, path)
end

-- Blur the video while the card is shown (downscale → blur → upscale is cheap).
local blurred = false
local function set_blur(on)
    if on == blurred then return end
    blurred = on
    if on then
        mp.commandv("vf", "add", "@lockblur:lavfi=[scale=iw/4:-2,gblur=sigma=6,scale=iw*4:-2]")
    else
        mp.commandv("vf", "remove", "@lockblur")
    end
end

local function draw()
    local w, h = mp.get_osd_size()
    if not w or w == 0 then return end
    overlay.res_x, overlay.res_y = w, h
    local s = h / 1080
    local cx = math.floor(w / 2)
    local ev = {}

    if state == "idle" then
        local date = (os.date("%A, %d %B"):gsub(" 0", " "))   -- "Sunday, 4 October"
        ev[#ev + 1] = text(cx, math.floor(h * 0.34), math.floor(200 * s), WHITE, os.date("%H:%M"), "\\b0")
        ev[#ev + 1] = text(cx, math.floor(h * 0.34 + 135 * s), math.floor(52 * s), WHITE, date, "\\b0")
        ev[#ev + 1] = text(cx, math.floor(h - 50 * s), math.floor(28 * s), WHITE, "Press any key to unlock", "\\alpha&H30&")
    else
        -- Dim layer over the blurred video.
        ev[#ev + 1] = shape(string.format("m 0 0 l %d 0 l %d %d l 0 %d", w, w, h, h), BLACK, "&H90&")
        local ay = math.floor(h * 0.40)
        local r = math.floor(64 * s)
        ev[#ev + 1] = shape(circle(cx, ay, r), BLUE, "&H00&")
        ev[#ev + 1] = text(cx, ay, math.floor(60 * s), WHITE, initial, "\\b0\\bord0\\blur0")
        ev[#ev + 1] = text(cx, ay + math.floor(100 * s), math.floor(32 * s), WHITE, name, "\\b1")
        -- Password field.
        local fw, fh = math.floor(480 * s), math.floor(48 * s)
        local fx, fy = cx - math.floor(fw / 2), ay + math.floor(140 * s)
        local focused = state == "active"
        ev[#ev + 1] = shape(rrect(fx, fy, fw, fh, math.floor(fh / 2)), WHITE, "&HC4&",
            math.floor(2 * s), focused and BLUE or WHITE)
        local field
        if state == "checking" or state == "ok" then
            field = text(cx, fy + math.floor(fh / 2), math.floor(22 * s), WHITE,
                state == "ok" and "Unlocking…" or "Checking…", "\\bord0\\blur0\\alpha&H20&")
        elseif dots > 0 then
            -- Tightly spaced dots, capped so even a long password stays inside the field.
            field = text(cx, fy + math.floor(fh / 2), math.floor(22 * s), WHITE,
                string.rep("●", math.min(dots, 22)), "\\bord0\\blur0\\fsp" .. math.floor(4 * s))
        else
            field = text(cx, fy + math.floor(fh / 2), math.floor(22 * s), WHITE, "Password", "\\bord0\\blur0\\alpha&H60&")
        end
        ev[#ev + 1] = field
        if message ~= "" then
            ev[#ev + 1] = text(cx, fy + fh + math.floor(34 * s), math.floor(22 * s), RED, message, "\\b0")
        end
    end
    overlay.data = table.concat(ev, "\n")
    overlay:update()
end

mp.register_script_message("lockui", function(st, n, msg)
    state, dots, message = st or "idle", tonumber(n) or 0, msg or ""
    last_update = mp.get_time()
    set_blur(state ~= "idle")
    draw()
end)

-- Clock tick; and a safety net: back to idle if auth_card went silent.
mp.add_periodic_timer(1, function()
    if state ~= "idle" and mp.get_time() - last_update > 40 then
        state, dots, message = "idle", 0, ""
        set_blur(false)
    end
    draw()
end)
mp.observe_property("osd-dimensions", "native", draw)
draw()
