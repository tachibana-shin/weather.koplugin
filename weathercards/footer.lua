local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Font = require("ui/font")
local Geom = require("ui/geometry")
local TextWidget = require("ui/widget/textwidget")
local _ = require("weather_i18n")

local Screen = Device.screen

-- Footer — credit line
return function(h)
    local self, cw = h.self, h.cw
    self:add(CenterContainer:new {
        dimen = Geom:new { w = cw, h = Screen:scaleBySize(32) },
        TextWidget:new {
            text = _("Google Weather"), face = Font:getFace("smallinfofont", 15),
            fgcolor = Blitbuffer.COLOR_DIM_GRAY, underline = true,
        },
    })
end
