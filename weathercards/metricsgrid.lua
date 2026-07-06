local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local ImageWidget = require("ui/widget/imagewidget")
local OverlapGroup = require("ui/widget/overlapgroup")
local RightContainer = require("ui/widget/container/rightcontainer")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local _ = require("weather_i18n")

local Screen = Device.screen

-- Block 4: Grid Metrics — 2×2 grid of wind, humidity, UV index, pressure
return function(h)
    local self, data, cur, acw, gauges = h.self, h.data, h.cur, h.acw, h.gauges
    local scw = math.floor((acw - Screen:scaleBySize(6)) / 2)
    local pad = Screen:scaleBySize(10)
    local sh = Screen:scaleBySize(150)
    local bc = gauges.rgb(200, 200, 200)
    local bs = Screen:scaleBySize(1)
    local iw = scw - 2 * bs - 2 * pad

    local function scard(left, right)
        return FrameContainer:new {
            width = scw, height = sh,
            bordersize = bs, color = bc, radius = h.card_r,
            padding = pad, margin = 0,
            OverlapGroup:new {
                dimen = Geom:new { w = iw, h = sh - 2 * pad },
                left,
                RightContainer:new {
                    dimen = Geom:new { w = iw, h = sh - 2 * pad },
                    right,
                },
            },
        }
    end

    local function svg(t, v, u, s)
        local left = VerticalGroup:new { align = "left" }
        table.insert(left, TextWidget:new {
            text = t, face = Font:getFace("smallinfofont", 15),
            fgcolor = Blitbuffer.COLOR_DIM_GRAY,
        })
        table.insert(left, VerticalSpan:new { width = Screen:scaleBySize(2) })
        local vg = HorizontalGroup:new { align = "bottom" }
        table.insert(vg, TextWidget:new {
            text = v, face = Font:getFace("pgfont", 34), bold = true,
        })
        table.insert(vg, HorizontalSpan:new { width = Screen:scaleBySize(3) })
        table.insert(vg, TextWidget:new {
            text = u, face = Font:getFace("smallinfofont", 15),
            fgcolor = Blitbuffer.COLOR_DIM_GRAY,
        })
        table.insert(left, vg)
        table.insert(left, TextWidget:new {
            text = s, face = Font:getFace("smallinfofont", 16),
            fgcolor = Blitbuffer.COLOR_DIM_GRAY,
            max_width = iw,
        })
        return left
    end

    local r1 = HorizontalGroup:new { align = "center" }

    if cur.wind_speed then
        local ws = cur.wind_speed
        local wd
        if ws < 1 then
            wd = _("Calm")
        elseif ws < 12 then
            wd = _("Light air")
        elseif ws < 20 then
            wd = _("Gentle breeze")
        elseif ws < 29 then
            wd = _("Strong")
        elseif ws < 39 then
            wd = _("Very strong")
        else
            wd = _("Violent")
        end
        local dir_vi = cur.wind_label and _(cur.wind_label) or ""
        local wind_fwd_angle = {
            [1] = 135,
            [2] = 180,
            [3] = 225,
            [4] = 270,
            [5] = 315,
            [6] = 0,
            [7] = 45,
            [8] = 90
        }
        local wai = cur.wind_direction and math.floor((cur.wind_direction + 22.5) / 45) % 8 + 1 or 3
        local ri = CenterContainer:new {
            dimen = Geom:new { w = Screen:scaleBySize(48), h = sh - 2 * pad },
            ImageWidget:new {
                file = h.plugin_dir .. string.format("resources/arrow_%03d.svg", wind_fwd_angle[wai]),
                width = Screen:scaleBySize(36), height = Screen:scaleBySize(36),
                alpha = true, is_icon = true,
            },
        }
        table.insert(r1, scard(
            svg(_("Wind"), string.format("%.0f", cur.wind_speed), h.api.windUnitLabel(),
                wd .. " \u{2022} " .. _("From") .. " " .. dir_vi),
            ri
        ))
        table.insert(r1, HorizontalSpan:new { width = Screen:scaleBySize(6) })
    end

    if cur.humidity then
        local cw = Screen:scaleBySize(60)
        local ch = sh - 2 * pad
        local fs = Screen:scaleBySize(16)
        local bw = Screen:scaleBySize(26)
        local gap = Screen:scaleBySize(3)
        local top_y = Screen:scaleBySize(2)
        local bot_y = ch - fs - Screen:scaleBySize(2)
        local pill_top = top_y + fs + gap
        local pill_bot = bot_y - gap
        local bh = math.max(Screen:scaleBySize(2), pill_bot - pill_top)
        local fh = math.max(1, math.floor(bh * cur.humidity / 100))
        local br = math.floor(bw / 2)
        local pill_x = math.floor((cw - bw) / 2)
        local fill_top = pill_top + bh - fh
        local tri_size = Screen:scaleBySize(10)
        local ri = CenterContainer:new {
            dimen = Geom:new { w = cw, h = ch },
            OverlapGroup:new {
                dimen = Geom:new { w = cw, h = ch },
                CenterContainer:new {
                    dimen = Geom:new { w = cw, h = fs + 2 },
                    TextWidget:new { text = "100",
                        face = Font:getFace("smallinfofont", fs),
                        fgcolor = Blitbuffer.COLOR_DIM_GRAY },
                    overlap_offset = { 0, top_y },
                },
                FrameContainer:new {
                    width = bw, height = bh,
                    radius = br,
                    background = gauges.rgb(230, 230, 230),
                    bordersize = 0, padding = 0,
                    overlap_offset = { pill_x, pill_top },
                    HorizontalGroup:new { align = "center" },
                },
                FrameContainer:new {
                    width = bw, height = fh,
                    radius = br,
                    background = gauges.rgb(66, 133, 244),
                    bordersize = 0, padding = 0,
                    overlap_offset = { pill_x, fill_top },
                    HorizontalGroup:new { align = "center" },
                },
                CenterContainer:new {
                    dimen = Geom:new { w = cw, h = fs + 2 },
                    TextWidget:new { text = "0",
                        face = Font:getFace("smallinfofont", fs),
                        fgcolor = Blitbuffer.COLOR_DIM_GRAY },
                    overlap_offset = { 0, bot_y },
                },
                TextWidget:new {
                    text = "▶",
                    face = Font:getFace("smallinfofont", tri_size + 2),
                    fgcolor = gauges.rgb(66, 133, 244),
                    overlap_offset = { pill_x - Screen:scaleBySize(14),
                        fill_top - math.floor(tri_size * 0.2) },
                },
            },
        }
        table.insert(r1, scard(
            svg(_("Humidity"), string.format("%d", cur.humidity), "%",
                string.format("%s %d°", _("Dew point"), math.floor((cur.dew_point or 0) + 0.5))),
            ri
        ))
    end

    local r2 = HorizontalGroup:new { align = "center" }

    if data.daily and data.daily[1] and data.daily[1].uv_index then
        local uv = data.daily[1].uv_index
        local uvs = string.format("%d", math.floor(uv + 0.5))
        local r, g, b
        if uv <= 2 then
            r, g, b = 76, 175, 80
        elseif uv <= 5 then
            r, g, b = 255, 235, 59
        elseif uv <= 7 then
            r, g, b = 255, 152, 0
        else
            r, g, b = 244, 67, 54
        end
        local uv_ratio = math.min(uv, 11) / 11
        local cw = Screen:scaleBySize(64)
        local ch = sh - 2 * pad
        local gs = math.floor(ch * 0.6)
        local svg_str = gauges.uvGaugeSVG(uv_ratio, r, g, b)
        local bb = gauges.renderSVGFromString(svg_str, gs, gs)
        local gx = math.floor((cw - gs) / 2)
        local gy = math.floor((ch - gs) / 2)
        local ri = CenterContainer:new {
            dimen = Geom:new { w = cw, h = ch },
            OverlapGroup:new {
                dimen = Geom:new { w = cw, h = ch },
                ImageWidget:new {
                    image = bb,
                    width = gs, height = gs,
                    alpha = true, is_icon = true,
                    overlap_offset = { gx, gy },
                },
                TextWidget:new {
                    text = "0",
                    face = Font:getFace("smallinfofont", 14),
                    fgcolor = Blitbuffer.COLOR_DIM_GRAY,
                    overlap_offset = { math.floor(cw * 0.12), gy + gs - Screen:scaleBySize(10) },
                },
                TextWidget:new {
                    text = ">11",
                    face = Font:getFace("smallinfofont", 14),
                    fgcolor = Blitbuffer.COLOR_DIM_GRAY,
                    overlap_offset = { math.floor(cw * 0.72), gy + gs - Screen:scaleBySize(10) },
                },
            },
        }
        local left = VerticalGroup:new { align = "left" }
        table.insert(left, TextWidget:new {
            text = _("UV Index"), face = Font:getFace("smallinfofont", 15),
            fgcolor = Blitbuffer.COLOR_DIM_GRAY,
        })
        table.insert(left, VerticalSpan:new { width = Screen:scaleBySize(2) })
        table.insert(left, TextWidget:new {
            text = uvs, face = Font:getFace("pgfont", 34), bold = true,
        })
        table.insert(left, TextWidget:new {
            text = h.api.uvLabel(uv), face = Font:getFace("smallinfofont", 16),
            fgcolor = Blitbuffer.COLOR_DIM_GRAY,
        })
        table.insert(r2, scard(left, ri))
        table.insert(r2, HorizontalSpan:new { width = Screen:scaleBySize(6) })
    end

    if cur.pressure then
        local cw = Screen:scaleBySize(70)
        local ch = sh - 2 * pad
        local gs = math.floor(ch * 0.6)
        local pr = math.max(0, math.min(1, (cur.pressure - 940) / 120))
        local p_svg = gauges.pressureGaugeSVG(pr, 66, 133, 244)
        local bb = gauges.renderSVGFromString(p_svg, gs, gs)
        local gx = math.floor((cw - gs) / 2)
        local gy = math.floor((ch - gs) / 2)
        local ri = CenterContainer:new {
            dimen = Geom:new { w = cw, h = ch },
            OverlapGroup:new {
                dimen = Geom:new { w = cw, h = ch },
                ImageWidget:new {
                    image = bb,
                    width = gs, height = gs,
                    alpha = true, is_icon = true,
                    overlap_offset = { gx, gy },
                },
                TextWidget:new {
                    text = _("Low"),
                    face = Font:getFace("smallinfofont", 14),
                    fgcolor = Blitbuffer.COLOR_DIM_GRAY,
                    overlap_offset = { math.floor(cw * 0.12), gy + gs - Screen:scaleBySize(10) },
                },
                TextWidget:new {
                    text = _("High"),
                    face = Font:getFace("smallinfofont", 14),
                    fgcolor = Blitbuffer.COLOR_DIM_GRAY,
                    overlap_offset = { math.floor(cw * 0.72), gy + gs - Screen:scaleBySize(10) },
                },
            },
        }
        local left = VerticalGroup:new { align = "left" }
        table.insert(left, TextWidget:new {
            text = _("Pressure"), face = Font:getFace("smallinfofont", 15),
            fgcolor = Blitbuffer.COLOR_DIM_GRAY,
        })
        table.insert(left, VerticalSpan:new { width = Screen:scaleBySize(2) })
        local vg = HorizontalGroup:new { align = "bottom" }
        table.insert(vg, TextWidget:new {
            text = string.format("%.0f", h.api.pressureConvert(cur.pressure)),
            face = Font:getFace("pgfont", 34), bold = true,
        })
        table.insert(vg, HorizontalSpan:new { width = Screen:scaleBySize(3) })
        table.insert(vg, TextWidget:new {
            text = h.api.pressureUnitLabel(), face = Font:getFace("smallinfofont", 15),
            fgcolor = Blitbuffer.COLOR_DIM_GRAY,
        })
        table.insert(left, vg)
        table.insert(r2, scard(left, ri))
    end

    self:add(TextWidget:new {
        text = "", face = Font:getFace("infofont", 22), bold = true,
    })
    self:add(FrameContainer:new {
        bordersize = 0, padding = 0,
        padding_left = h.card_p, padding_right = h.card_p,
        radius = h.card_r,
        background = Blitbuffer.COLOR_WHITE,
        r1,
    })
    self:add(FrameContainer:new {
        bordersize = 0, padding = 0,
        padding_left = h.card_p, padding_right = h.card_p,
        radius = h.card_r,
        background = Blitbuffer.COLOR_WHITE,
        r2,
    })
end
