local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Font = require("ui/font")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local _ = require("weather_i18n")

local Screen = Device.screen

-- Block 5: Sun Cycle — sunrise/sunset times with arc diagram
return function(h)
    local self, data = h.self, h.data
    if not (data.daily and data.daily[1]) then return end

    local d1 = data.daily[1]
    local srt = d1.sunrise and d1.sunrise:match("(%d%d:%d%d)") or "--:--"
    local sst = d1.sunset and d1.sunset:match("(%d%d:%d%d)") or "--:--"
    local left = VerticalGroup:new { align = "left" }
    table.insert(left, TextWidget:new {
        text = _("Sunrise"), face = Font:getFace("smallinfofont", 16),
        fgcolor = Blitbuffer.COLOR_DIM_GRAY,
    })
    table.insert(left, TextWidget:new {
        text = srt, face = Font:getFace("pgfont", 34), bold = true,
    })
    table.insert(left, VerticalSpan:new { width = Screen:scaleBySize(6) })
    table.insert(left, TextWidget:new {
        text = _("Sunset"), face = Font:getFace("smallinfofont", 16),
        fgcolor = Blitbuffer.COLOR_DIM_GRAY,
    })
    table.insert(left, TextWidget:new {
        text = sst, face = Font:getFace("pgfont", 34), bold = true,
    })
    local aw = Screen:scaleBySize(180)
    local ah = Screen:scaleBySize(80)
    local arc = h.gauges.SunArc:new {
        w = aw, h = ah, sunrise = srt, sunset = sst,
    }
    local body = HorizontalGroup:new { align = "center" }
    table.insert(body, left)
    table.insert(body, HorizontalSpan:new { width = Screen:scaleBySize(10) })
    table.insert(body, CenterContainer:new {
        dimen = Geom:new { w = aw + Screen:scaleBySize(20), h = ah + Screen:scaleBySize(20) },
        arc,
    })
    self:add(h.card(VerticalGroup:new {
        align = "left",
        TextWidget:new {
            text = _("Sunrise & Sunset"),
            face = Font:getFace("infofont", 22), bold = true,
        },
        VerticalSpan:new { width = Screen:scaleBySize(4) },
        body,
    }))
end
