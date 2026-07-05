local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local config = require("weather_config")
local Device = require("device")
local Font = require("ui/font")
local Geom = require("ui/geometry")
local TextWidget = require("ui/widget/textwidget")
local _ = require("weather_i18n")

local Screen = Device.screen

local PROVIDER_NAMES = {
    openmeteo = "Open-Meteo",
    weatherapi = "WeatherAPI.com",
    iqair = "IQAir",
    tomorrowio = "Tomorrow.io",
    weatherbit = "Weatherbit",
}

-- Footer — credit line
return function(h)
    local self, cw = h.self, h.cw
    local provider = PROVIDER_NAMES[config.get("weather_provider", "openmeteo")] or "Open-Meteo"
    self:add(CenterContainer:new {
        dimen = Geom:new { w = cw, h = Screen:scaleBySize(32) },
        TextWidget:new {
            text = string.format(_("Powered by %s"), provider),
            face = Font:getFace("smallinfofont", 15),
            fgcolor = Blitbuffer.COLOR_DIM_GRAY,
        },
    })
end
