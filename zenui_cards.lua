local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local InputContainer = require("ui/widget/container/inputcontainer")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local _ = require("weather_i18n")

local api = require("weather_api")
local config = require("weather_config")
local Screen = Device.screen
local gauges = require("weather_gauges")
local plugin_dir = (debug.getinfo(1, "S").source or ""):match("@(.*/)") or ""

local function loadData()
    local data = api.cacheLoad()
    if not data or not data.current then return nil end
    return data
end

local function renderCard(modname, ctx, data, cw_override)
    local card_p = Screen:scaleBySize(6)
    local card_r = Screen:scaleBySize(24)
    local cw = cw_override or ctx.width
    local acw = cw - 2 * card_p

    local items = {}
    local self_stub = { add = function(_, w) table.insert(items, w) end }

    local h = {
        self = self_stub,
        data = data, cur = data.current,
        acw = acw, cw = cw,
        menu_ref = ctx.menu,
        card = function(content)
            return FrameContainer:new {
                width = cw, bordersize = 0, padding = card_p,
                background = Blitbuffer.COLOR_WHITE,
                radius = card_r, content,
            }
        end,
        card_r = card_r, card_p = card_p,
        gauges = gauges, api = api, plugin_dir = plugin_dir,
        cached = true, cache_age = 0,
    }

    local ok, mod = pcall(require, "weathercards/" .. modname)
    if ok then mod(h) end

    if #items == 0 then return nil end
    if #items == 1 then return items[1] end

    local vg = VerticalGroup:new { align = "left" }
    for __, w in ipairs(items) do
        table.insert(vg, w)
        table.insert(vg, VerticalSpan:new { width = Screen:scaleBySize(8) })
    end
    return vg
end


local CARDS = {
    now = {
        mod = "header", label = "Weather",
        size = { preferred_pct = 0.22, min_pct = 0.16, max_pct = 0.28 },
    },
    aqi = {
        mod = "airquality", label = "AQI",
        size = { preferred_pct = 0.35, min_pct = 0.25, max_pct = 0.45 },
    },
    daily = {
        mod = "dailyforecast", label = "Daily",
        size = { preferred_pct = 0.35, min_pct = 0.25, max_pct = 0.50 },
    },
    hourly = {
        mod = "hourlyforecast", label = "Hourly",
        size = { preferred_pct = 0.22, min_pct = 0.16, max_pct = 0.30 },
    },
    metrics = {
        mod = "metricsgrid", label = "Wind & Humidity",
        size = { preferred_pct = 0.28, min_pct = 0.20, max_pct = 0.35 },
    },
    sun = {
        mod = "suncycle", label = "Sun",
        size = { preferred_pct = 0.16, min_pct = 0.12, max_pct = 0.22 },
    },
    alert = {
        mod = "alert", label = "Alerts",
        size = { preferred_pct = 0.10, min_pct = 0.06, max_pct = 0.14 },
    },
    hourlydetail = {
        mod = "hourlydetail", label = "Hourly Detail",
        size = { preferred_pct = 0.30, min_pct = 0.20, max_pct = 0.40 },
    },
}

local function openWeather()
    local WeatherView = require("weather_view")
    local lat = config.get("weather_latitude")
    local lon = config.get("weather_longitude")
    local temp_unit = config.get("weather_temp_unit", "celsius")
    local forecast_days = config.get("weather_forecast_days", 7)
    local location_name = config.get("weather_location_name")
    if not lat or not lon then
        UIManager:show(require("ui/widget/infomessage"):new {
            text = _("Set a location first"),
        })
        return
    end
    local v = WeatherView:new {
        lat = tonumber(lat), lon = tonumber(lon),
        temp_unit = temp_unit, forecast_days = forecast_days,
        location_name = location_name,
        close_callback = function() end,
    }
    UIManager:show(v)
end

local registered = {}

local function register()
    local register_fn = rawget(_G, "__ZEN_UI_REGISTER_HOME_ITEM")
    if not register_fn then return end

    for id, opts in pairs(CARDS) do
        register_fn("weather." .. id, function(ctx)
            local data = loadData()
            if not data then
                return CenterContainer:new {
                    dimen = Geom:new { w = ctx.width, h = ctx.height },
                    TextWidget:new {
                        text = _("Weather"),
                        face = Font:getFace("infofont", 20),
                    },
                }
            end

            local widget = InputContainer:new {
                dimen = Geom:new { w = ctx.width, h = ctx.height },
            }
            function widget:handleEvent(event)
                if event.handler == "onGesture" and event.args and event.args[1] and event.args[1].ges then
                    local ges = event.args[1]
                    if ges.ges ~= "tap" then return false end
                    openWeather()
                    return true
                end
                return InputContainer.handleEvent(self, event)
            end

            local content = renderCard(opts.mod, ctx, data)
            if not content then
                return CenterContainer:new {
                    dimen = Geom:new { w = ctx.width, h = ctx.height },
                    TextWidget:new {
                        text = _("N/A"),
                        face = Font:getFace("infofont", 20),
                        fgcolor = Blitbuffer.COLOR_DIM_GRAY,
                    },
                }
            end

            widget[1] = content
            -- Report actual rendered content height so parent containers
            -- (and ScrollableContainer initState) see the true extent.
            function widget:getSize()
                local ch = self[1] and self[1].getSize and self[1]:getSize()
                return Geom:new{w = self.dimen.w, h = ch and ch.h or self.dimen.h}
            end
            return widget
        end, {
            label = opts.label,
            size = opts.size,
        })
        registered[id] = true
    end
end

local function unregister()
    local unregister_fn = rawget(_G, "__ZEN_UI_UNREGISTER_HOME_ITEM")
    if not unregister_fn then return end
    for id in pairs(registered) do
        unregister_fn("weather." .. id)
    end
    registered = {}
end

return {
    register = register,
    unregister = unregister,
}
