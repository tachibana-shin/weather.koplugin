local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local OverlapGroup = require("ui/widget/overlapgroup")
local RightContainer = require("ui/widget/container/rightcontainer")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local _ = require("weather_i18n")

local Screen = Device.screen

-- Alert cards — extreme temperature + precipitation warnings
local function addAlert(self, h, label, bg_color, icon_color, text_color, message)
    local cw, acw, card_r, card_p, gauges = h.cw, h.acw, h.card_r, h.card_p, h.gauges
    local cur = h.cur
    local is = Screen:scaleBySize(36)
    local ah = Screen:scaleBySize(60)
    local al_left = HorizontalGroup:new { align = "center" }
    table.insert(al_left, FrameContainer:new {
        width = is, height = is,
        background = icon_color, radius = is * 2 / 3,
        bordersize = 0, padding = 0,
        CenterContainer:new {
            dimen = Geom:new { w = is, h = is },
            TextWidget:new {
                text = "\u{26A0}", face = Font:getFace("smallinfofont", 22),
                fgcolor = Blitbuffer.COLOR_WHITE,
            },
        },
    })
    table.insert(al_left, HorizontalSpan:new { width = Screen:scaleBySize(10) })
    local at = VerticalGroup:new { align = "left" }
    table.insert(at, TextWidget:new {
        text = label, face = Font:getFace("infofont", 22),
        bold = true, fgcolor = Blitbuffer.COLOR_WHITE,
    })
    table.insert(at, TextWidget:new {
        text = message or cur.location_name,
        face = Font:getFace("smallinfofont", 15), fgcolor = text_color,
        max_width = acw - Screen:scaleBySize(70),
    })
    table.insert(al_left, at)
    self:add(FrameContainer:new {
        width = cw, height = Screen:scaleBySize(80),
        background = bg_color, radius = card_r,
        bordersize = 0, padding = card_p,
        OverlapGroup:new {
            dimen = Geom:new { w = acw, h = ah },
            al_left,
            RightContainer:new {
                dimen = Geom:new { w = acw, h = ah },
                CenterContainer:new {
                    dimen = Geom:new { w = Screen:scaleBySize(20), h = ah },
                    TextWidget:new {
                        text = ">", face = Font:getFace("infofont", 24),
                        fgcolor = Blitbuffer.COLOR_WHITE,
                    },
                },
            },
        },
    })
end

return function(h)
    local cur = h.cur
    if not cur.temperature then return end

    local temp_unit = h.self.temp_unit or "celsius"
    local hot_threshold = temp_unit == "fahrenheit" and 86 or 30
    local cold_threshold = temp_unit == "fahrenheit" and 32 or 0

    if (cur.heat_index and cur.heat_index >= hot_threshold) or cur.temperature >= hot_threshold then
        addAlert(h.self, h, _("Too hot"), h.gauges.rgb(180, 40, 40), h.gauges.rgb(220, 80, 80),
            h.gauges.rgb(255, 255, 255), string.format("%s %d°", _("Heat Index"), math.floor(cur.heat_index + 0.5)))
    end

    if cur.temperature <= cold_threshold or (cur.heat_index and cur.heat_index <= cold_threshold) then
        addAlert(h.self, h, _("Too cold"), h.gauges.rgb(40, 40, 180), h.gauges.rgb(80, 80, 220),
            h.gauges.rgb(255, 255, 255), string.format("%s %d°", _("Wind Chill"), math.floor(cur.wind_chill + 0.5)))
    end

    if cur.precip_prediction then
        local title = cur.precip_is_snow
            and _("Snow will continue in the next few hours")
            or _("Rain will continue in the next few hours")
        addAlert(h.self, h, title, h.gauges.rgb(80, 140, 200), h.gauges.rgb(60, 100, 180),
            h.gauges.rgb(255, 255, 255), cur.precip_prediction)
    end
end
