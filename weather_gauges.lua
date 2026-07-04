local Blitbuffer = require("ffi/blitbuffer")
local Geom = require("ui/geometry")
local InputContainer = require("ui/widget/container/inputcontainer")
local Widget = require("ui/widget/widget")

local function renderSVGFromString(svg_str, w, h)
    local ok, cre = pcall(require, "document/credocument")
    if not ok then return end
    cre = cre:engineInit()
    local data, dw, dh = cre.renderImageData(svg_str, #svg_str, w, h)
    if not data then return end
    return Blitbuffer.new(dw, dh, Blitbuffer.TYPE_BBRGB32, data)
end

local function rgb(r, g, b)
    return Blitbuffer.colorFromString(string.format("#%02X%02X%02X", r, g, b))
end

local FitWidthContainer = InputContainer:extend {
    fw = 0,
}
function FitWidthContainer:getSize()
    local s = self[1]:getSize()
    return Geom:new { w = self.fw, h = s.h }
end
function FitWidthContainer:paintTo(bb, x, y)
    self[1]:paintTo(bb, x, y)
end

local function pressureGaugeSVG(ratio, r, g, b)
    local sr, sw = 44, 14
    local start_deg, end_deg, arc_deg = 150, 30, 240
    local sx = 50 + sr * math.cos(start_deg * math.pi / 180)
    local sy = 50 + sr * math.sin(start_deg * math.pi / 180)
    local ex = 50 + sr * math.cos(end_deg * math.pi / 180)
    local ey = 50 + sr * math.sin(end_deg * math.pi / 180)
    local fill_ratio = math.min(ratio, 1)
    local c = string.format("#%02x%02x%02x", r, g, b)
    local bg = string.format(
        '<path d="M %f %f A %d %d 0 1 1 %f %f" fill="none" stroke="#d0d0d0" stroke-width="%d" stroke-linecap="round"/>',
        sx, sy, sr, sr, ex, ey, sw)
    local fill = ""
    if fill_ratio > 0 then
        local fill_deg = start_deg + fill_ratio * arc_deg
        if fill_deg > 360 then fill_deg = fill_deg - 360 end
        local fx = 50 + sr * math.cos(fill_deg * math.pi / 180)
        local fy = 50 + sr * math.sin(fill_deg * math.pi / 180)
        local la = fill_ratio > 0.75 and 1 or 0
        fill = string.format(
            '<path d="M %f %f A %d %d 0 %d 1 %f %f" fill="none" stroke="%s" stroke-width="%d" stroke-linecap="round"/>',
            sx, sy, sr, sr, la, fx, fy, c, sw)
    end
    return '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="0 0 100 100">'
        .. bg .. fill .. '</svg>'
end

local function uvGaugeSVG(uv_ratio, r, g, b)
    local sr, sw = 44, 14
    local start_deg, end_deg, arc_deg = 150, 30, 240
    local sx = 50 + sr * math.cos(start_deg * math.pi / 180)
    local sy = 50 + sr * math.sin(start_deg * math.pi / 180)
    local ex = 50 + sr * math.cos(end_deg * math.pi / 180)
    local ey = 50 + sr * math.sin(end_deg * math.pi / 180)
    local pct = math.min(uv_ratio, 1)
    local c = string.format("#%02x%02x%02x", r, g, b)
    local bg = string.format(
        '<path d="M %f %f A %d %d 0 1 1 %f %f" fill="none" stroke="#d0d0d0" stroke-width="%d" stroke-linecap="round"/>',
        sx, sy, sr, sr, ex, ey, sw)
    local fill = ""
    if pct > 0 then
        local fill_deg = start_deg + pct * arc_deg
        if fill_deg > 360 then fill_deg = fill_deg - 360 end
        local fx = 50 + sr * math.cos(fill_deg * math.pi / 180)
        local fy = 50 + sr * math.sin(fill_deg * math.pi / 180)
        local la = pct > 0.75 and 1 or 0
        fill = string.format(
            '<path d="M %f %f A %d %d 0 %d 1 %f %f" fill="none" stroke="%s" stroke-width="%d" stroke-linecap="round"/>',
            sx, sy, sr, sr, la, fx, fy, c, sw)
    end
    return '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="0 0 100 100">'
        .. bg .. fill .. '</svg>'
end

local SunArc = Widget:extend {
    w = nil, h = nil,
    sunrise = "05:20", sunset = "18:43",
}

function SunArc:getSize()
    return { w = self.w, h = self.h }
end

function SunArc:paintTo(bb, x, y)
    local base = rgb(220, 220, 220)
    local fill = rgb(66, 133, 244)
    local dot = rgb(255, 200, 0)
    bb:paintRect(x, y + self.h - 2, self.w, 2, base)
    local now = os.date("*t")
    local now_m = now.hour * 60 + now.min
    local function pt(s)
        local hh, mm = s:match("(%d+):(%d+)")
        return hh and mm and tonumber(hh) * 60 + tonumber(mm) or 360
    end
    local sr = pt(self.sunrise)
    local ss = pt(self.sunset)
    local dl = ss - sr
    if dl <= 0 then dl = 720 end
    local prog = 0
    if now_m >= sr and now_m <= ss then
        prog = (now_m - sr) / dl
    elseif now_m > ss then
        prog = 1
    end
    local n = 40
    local px, py = nil, nil
    for i = 0, n do
        local t = i / n
        local cx = x + t * self.w
        local ay = 4 * t * (1 - t)
        local cy = y + self.h - 2 - ay * (self.h - 10)
        if px and py then
            bb:paintRect(math.floor(px), math.floor(py), math.ceil(cx - px) + 1, 2, fill)
        end
        px, py = cx, cy
    end
    if prog > 0 then
        for i = 0, math.floor(n * prog) do
            local t = i / n
            local cx = x + t * self.w
            local ay = 4 * t * (1 - t)
            local cy = y + self.h - 2 - ay * (self.h - 10)
            local fh = y + self.h - 2 - cy
            if fh > 0 then
                bb:paintRect(math.floor(cx), math.floor(cy),
                    math.max(1, math.ceil(self.w / n)), math.ceil(fh), fill)
            end
        end
    end
    if prog > 0 and prog < 1 then
        local dx = x + prog * self.w
        local ay = 4 * prog * (1 - prog)
        local dy = y + self.h - 2 - ay * (self.h - 10)
        bb:paintCircle(math.floor(dx), math.floor(dy), 4, fill)
        bb:paintCircle(math.floor(dx), math.floor(dy), 3, dot)
    end
end

return {
    renderSVGFromString = renderSVGFromString,
    rgb = rgb,
    FitWidthContainer = FitWidthContainer,
    pressureGaugeSVG = pressureGaugeSVG,
    uvGaugeSVG = uvGaugeSVG,
    SunArc = SunArc,
}
