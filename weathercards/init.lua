local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local FrameContainer = require("ui/widget/container/framecontainer")
local Size = require("ui/size")
local UIManager = require("ui/uimanager")

local api = require("weather_api")
local Screen = Device.screen
local plugin_dir = (debug.getinfo(1, "S").source or ""):match("@(.*/).*/") or ""

return function(WeatherView, gauges)
    local card_r = Screen:scaleBySize(24)
    local card_p = Screen:scaleBySize(10)

    local function card(content)
        return FrameContainer:new {
            width = Screen:getWidth() - 2 * Size.padding.default,
            bordersize = 0, padding = card_p,
            background = Blitbuffer.COLOR_WHITE,
            radius = card_r,
            content,
        }
    end

    function WeatherView:displayWeather(data, cached)
        if not data then return end
        self:buildLayout()
        if not data.current then return end
        local cur = data.current
        local sw = Screen:getWidth()
        local cw = sw - 2 * self.pad
        local acw = cw - 2 * card_p

        local cache_age = cached and api.cacheAge()

        local helpers = {
            self = self,
            data = data,
            cur = cur,
            acw = acw,
            cw = cw,
            card = card,
            card_r = card_r,
            card_p = card_p,
            gauges = gauges,
            api = api,
            plugin_dir = plugin_dir,
            cached = cached,
            cache_age = cache_age,
        }

        local blocks = {
            "header", "alert", "hourlyforecast", "dailyforecast",
            "airquality", "metricsgrid", "suncycle", "hourlydetail", "footer",
        }
        for _, name in ipairs(blocks) do
            require("weathercards/" .. name)(helpers)
        end

        self.cards:resetLayout()
        self.scroll:reset()
        UIManager:setDirty(self, function()
            return "ui", self.dimen
        end)
    end
end
