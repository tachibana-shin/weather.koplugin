local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InputContainer = require("ui/widget/container/inputcontainer")
local LeftContainer = require("ui/widget/container/leftcontainer")
local OverlapGroup = require("ui/widget/overlapgroup")
local RightContainer = require("ui/widget/container/rightcontainer")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local _ = require("weather_i18n")

local Screen = Device.screen
local function S(v) return Screen:scaleBySize(v) end
local function round(v) return v and math.floor(v + 0.5) or nil end

local function hg(align, items)
    local args = { align = align }
    for _, v in ipairs(items) do table.insert(args, v) end
    return HorizontalGroup:new(args)
end

return function(h)
    local self, data = h.self, h.data
    local aq = data.air_quality
    if not aq then return end
    local acw = h.acw

    local body = VerticalGroup:new { align = "left" }

    -- Main consolidated AQI — compact pill gauge
    if aq.aqi then
        local card_h = S(115)
        local aqi = round(aq.aqi)
        local label, r, g, b = h.api.aqiLabel(aq.aqi)
        local gauges = h.gauges

        local left = VerticalGroup:new { align = "left" }
        table.insert(left, TextWidget:new {
            text = _("Air Quality"),
            face = Font:getFace("infofont", 22), bold = true,
            fgcolor = Blitbuffer.COLOR_DIM_GRAY,
        })
        table.insert(left, VerticalSpan:new { width = S(4) })
        local vg = HorizontalGroup:new { align = "center" }
        table.insert(vg, TextWidget:new {
            text = tostring(aqi),
            face = Font:getFace("pgfont", 52), bold = true,
        })
        table.insert(vg, HorizontalSpan:new { width = S(8) })
        table.insert(vg, TextWidget:new {
            text = label,
            face = Font:getFace("infofont", 22), bold = true,
            fgcolor = Blitbuffer.COLOR_DIM_GRAY,
        })
        table.insert(left, vg)

        local cw = S(60)
        local ch = card_h - 2 * S(10)
        local bw = S(26)
        local gap = S(2)
        local pill_top = gap
        local pill_bot = ch - gap
        local bh = math.max(S(2), pill_bot - pill_top)
        local ratio = math.min(aqi / 100, 1)
        local fh = math.max(1, math.floor(ratio * bh))
        local br = math.floor(bw / 2)
        local pill_x = math.floor((cw - bw) / 2)
        local fill_top = pill_top + bh - fh
        local tri_size = S(12)
        local ri = CenterContainer:new {
            dimen = Geom:new { w = cw, h = ch },
            OverlapGroup:new {
                dimen = Geom:new { w = cw, h = ch },
                FrameContainer:new {
                    width = bw, height = bh, radius = br,
                    background = gauges.rgb(230, 230, 230),
                    bordersize = 0, padding = 0,
                    overlap_offset = { pill_x, pill_top },
                    HorizontalGroup:new { align = "center" },
                },
                FrameContainer:new {
                    width = bw, height = fh, radius = br,
                    background = gauges.rgb(r, g, b),
                    bordersize = 0, padding = 0,
                    overlap_offset = { pill_x, fill_top },
                    HorizontalGroup:new { align = "center" },
                },
                TextWidget:new {
                    text = "▶",
                    face = Font:getFace("smallinfofont", tri_size + 2),
                    fgcolor = gauges.rgb(r, g, b),
                    overlap_offset = { pill_x - S(14),
                        fill_top - math.floor(tri_size * 0.2) },
                },
            },
        }
        table.insert(body, OverlapGroup:new {
            dimen = Geom:new { w = acw, h = card_h },
            LeftContainer:new {
                dimen = Geom:new { w = acw, h = card_h },
                left,
            },
            RightContainer:new {
                dimen = Geom:new { w = acw, h = card_h },
                ri,
            },
        })
    end

    -- Components + Pollutants + Pollen
    local comps = {
        { key = "pm2_5", name = "PM2.5" },
        { key = "pm10",  name = "PM10" },
        { key = "no2",   name = "NO₂" },
        { key = "o3",    name = "O₃" },
        { key = "so2",   name = "SO₂" },
    }
    local cd = aq.components
    local sorted = {}
    for _, c in ipairs(comps) do
        local d = cd and cd[c.key]
        if d and d.aqi then
            table.insert(sorted, { name = c.name, data = d })
        end
    end

    local has_comp = #sorted > 0
    local has_poll = false
    local has_pol = false
    local any_detail = false

    if has_comp then
        any_detail = true
        table.insert(body, VerticalSpan:new { width = S(6) })
        table.insert(body, TextWidget:new {
            text = _("EC AQI by pollutant"),
            face = Font:getFace("smallinfofont", 15),
            fgcolor = Blitbuffer.COLOR_DIM_GRAY,
        })
        table.insert(body, VerticalSpan:new { width = S(3) })
        local rows = { {}, {} }
        for i, s in ipairs(sorted) do
            local _, cr, cg, cb = h.api.aqiLabel(s.data.aqi)
            local ds = S(16)
            local e = HorizontalGroup:new { align = "center" }
            table.insert(e, TextWidget:new {
                text = s.name,
                face = Font:getFace("infofont", 17),
                fgcolor = Blitbuffer.COLOR_DIM_GRAY,
            })
            table.insert(e, HorizontalSpan:new { width = S(4) })
            table.insert(e, FrameContainer:new {
                width = ds, height = ds, radius = math.floor(ds / 2),
                background = h.gauges.rgb(cr, cg, cb),
                bordersize = 0, padding = 0,
                InputContainer:new { dimen = Geom:new { w = ds, h = ds } },
            })
            table.insert(e, HorizontalSpan:new { width = S(3) })
            table.insert(e, TextWidget:new {
                text = tostring(round(s.data.aqi)),
                face = Font:getFace("infofont", 17), bold = true,
            })
            local ri = i <= 3 and 1 or 2
            table.insert(rows[ri], e)
            if (ri == 1 and i < math.min(3, #sorted)) or (ri == 2 and i < #sorted) then
                table.insert(rows[ri], HorizontalSpan:new { width = S(6) })
            end
        end
        table.insert(body, VerticalSpan:new { width = S(6) })
        table.insert(body, hg("center", rows[1]))
        if #rows[2] > 0 then
            table.insert(body, VerticalSpan:new { width = S(3) })
            table.insert(body, hg("center", rows[2]))
        end
    end

    -- Extra pollutants
    local poll = aq.pollutants
    local poll_items = {
        { key = "co", name = "CO", fmt = function(v) return string.format("%.1f", v) end },
        { key = "dust", name = "Dust", fmt = function(v) return tostring(round(v)) end },
        { key = "ammonia", name = "NH₃", fmt = function(v) return string.format("%.1f", v) end },
        { key = "aerosol_optical_depth", name = "AOD", fmt = function(v) return string.format("%.2f", v) end },
    }
    local poll_row = {}
    for _, p in ipairs(poll_items) do
        local v = poll and poll[p.key]
        if v and type(v) == "number" then
            has_poll = true
            if #poll_row > 0 then
                table.insert(poll_row, HorizontalSpan:new { width = S(10) })
            end
            table.insert(poll_row, TextWidget:new {
                text = p.name,
                face = Font:getFace("infofont", 17),
                fgcolor = Blitbuffer.COLOR_DIM_GRAY,
            })
            table.insert(poll_row, HorizontalSpan:new { width = S(3) })
            table.insert(poll_row, TextWidget:new {
                text = p.fmt(v),
                face = Font:getFace("infofont", 17), bold = true,
            })
        end
    end

    if has_poll then
        any_detail = true
        if not has_comp then
            table.insert(body, VerticalSpan:new { width = S(6) })
        else
            table.insert(body, VerticalSpan:new { width = S(4) })
        end
        table.insert(body, TextWidget:new {
            text = _("Pollutants"),
            face = Font:getFace("infofont", 18), bold = true,
            fgcolor = Blitbuffer.COLOR_DIM_GRAY,
        })
        table.insert(body, VerticalSpan:new { width = S(4) })
        table.insert(body, hg("center", poll_row))
    end

    -- Pollen
    local pol = aq.pollen
    local pol_items = {
        { key = "alder", name = _("Alder") },
        { key = "birch", name = _("Birch") },
        { key = "grass", name = _("Grass") },
        { key = "mugwort", name = _("Mugwort") },
        { key = "olive", name = _("Olive") },
        { key = "ragweed", name = _("Ragweed") },
    }
    local pol_sorted = {}
    for _, p in ipairs(pol_items) do
        local v = pol and pol[p.key]
        if v and type(v) == "number" then
            table.insert(pol_sorted, { name = p.name, val = round(v) })
        end
    end
    if #pol_sorted > 0 then
        has_pol = true
        any_detail = true
        if not has_comp and not has_poll then
            table.insert(body, VerticalSpan:new { width = S(6) })
        else
            table.insert(body, VerticalSpan:new { width = S(4) })
        end
        table.insert(body, TextWidget:new {
            text = _("Pollen"),
            face = Font:getFace("infofont", 18), bold = true,
            fgcolor = Blitbuffer.COLOR_DIM_GRAY,
        })
        table.insert(body, VerticalSpan:new { width = S(4) })
        local pol_rows = { {}, {} }
        for i, p in ipairs(pol_sorted) do
            local e = HorizontalGroup:new { align = "center" }
            table.insert(e, TextWidget:new {
                text = p.name,
                face = Font:getFace("infofont", 17),
                fgcolor = Blitbuffer.COLOR_DIM_GRAY,
            })
            table.insert(e, HorizontalSpan:new { width = S(3) })
            table.insert(e, TextWidget:new {
                text = tostring(p.val),
                face = Font:getFace("infofont", 14), bold = true,
            })
            local ri = i <= 3 and 1 or 2
            table.insert(pol_rows[ri], e)
            if (ri == 1 and i < math.min(3, #pol_sorted)) or (ri == 2 and i < #pol_sorted) then
                table.insert(pol_rows[ri], HorizontalSpan:new { width = S(8) })
            end
        end
        table.insert(body, hg("center", pol_rows[1]))
        if #pol_rows[2] > 0 then
            table.insert(body, VerticalSpan:new { width = S(2) })
            table.insert(body, hg("center", pol_rows[2]))
        end
    end

    if any_detail or aq.aqi then
        self:add(h.card(body))
    end
end