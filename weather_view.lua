local Blitbuffer = require("ffi/blitbuffer")
local ButtonDialog = require("ui/widget/buttondialog")
local CenterContainer = require("ui/widget/container/centercontainer")
local config = require("weather_config")
local Device = require("device")
local Font = require("ui/font")
local FocusManager = require("ui/widget/focusmanager")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local ImageWidget = require("ui/widget/imagewidget")
local InfoMessage = require("ui/widget/infomessage")
local Input = Device.input
local InputDialog = require("ui/widget/inputdialog")
local OverlapGroup = require("ui/widget/overlapgroup")
local Screen = Device.screen
local ScrollableContainer = require("ui/widget/container/scrollablecontainer")
local Size = require("ui/size")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local TitleBar = require("ui/widget/titlebar")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local api = require("weather_api")
local _ = require("weather_i18n")

local gauges = require("weather_gauges")

local plugin_dir = (debug.getinfo(1, "S").source or ""):match("@(.*/)") or ""

local gap = Screen:scaleBySize(8)

local WeatherView = FocusManager:extend {
    name = "weatherview",
    lat = nil, lon = nil,
    temp_unit = "celsius",
    forecast_days = 7,
    location_name = nil,
    close_callback = nil,
}

function WeatherView:init()
    local sw = Screen:getWidth()
    local sh = Screen:getHeight()
    self.dimen = Geom:new { x = 0, y = 0, w = sw, h = sh }
    self.covers_fullscreen = true
    if Device:hasKeys() then
        self.key_events.Close = { { Input.group.Back } }
    end
    if Device:isTouchDevice() then
        self.ges_events.Swipe = {
            GestureRange:new { ges = "swipe", range = self.dimen },
        }
    end
    self.pad = Size.padding.default
    self:showLoading()
    self:buildLayout()
    self:fetchWeather()
end

function WeatherView:showLoading()
    local sw = Screen:getWidth()
    self.main = VerticalGroup:new { align = "center" }
    table.insert(self.main, VerticalSpan:new { width = Screen:getHeight() / 3 })
    table.insert(self.main, CenterContainer:new {
        dimen = Geom:new { w = sw, h = Screen:scaleBySize(40) },
        TextWidget:new { text = _("Loading..."), face = Font:getFace("infofont", 24) },
    })
    self[1] = FrameContainer:new {
        width = sw, height = Screen:getHeight(),
        background = Blitbuffer.COLOR_WHITE,
        bordersize = 0, padding = 0,
        self.main,
    }
end

function WeatherView:buildLayout()
    local sw = Screen:getWidth()
    local sh = Screen:getHeight()
    self.title_bar = TitleBar:new {
        fullscreen = true, width = sw, align = "left",
        title = self.location_name or _("Weather"),
        left_icon = "appbar.search",
        left_icon_tap_callback = function() self:onSearchLocation() end,
        close_callback = function() self:onClose() end, show_parent = self,
    }
    self.cards = VerticalGroup:new { align = "left" }
    local content = VerticalGroup:new {
        align = "left", dimen = Geom:new { w = sw, h = sh },
    }
    table.insert(content, self.title_bar)
    self.scroll = ScrollableContainer:new {
        dimen = Geom:new { w = sw, h = sh - self.title_bar:getSize().h },
        scroll_bar_width = Screen:scaleBySize(4),
        swipe_full_view = false,
    }
    local sbw = self.scroll:getScrollbarWidth()
    self.scroll[1] = gauges.FitWidthContainer:new {
        fw = sw - sbw,
        FrameContainer:new {
            bordersize = 0, padding = 0,
            padding_left = self.pad, padding_right = self.pad,
            background = Blitbuffer.COLOR_WHITE,
            self.cards,
        },
    }
    self.scroll.show_parent = self
    table.insert(content, self.scroll)
    self[1] = FrameContainer:new {
        width = sw, height = sh,
        bordersize = 0, padding = 0,
        background = Blitbuffer.COLOR_WHITE,
        content,
    }
    self.cropping_widget = self.scroll
end

function WeatherView:add(w)
    table.insert(self.cards, w)
    table.insert(self.cards, VerticalSpan:new { width = gap })
end

require("weathercards/init")(WeatherView, gauges)

function WeatherView:fetchWeather()
    self:showLoading()
    UIManager:setDirty(self, function()
        return "ui", self.dimen
    end)
    if not self.lat or not self.lon then
        self:displayError(_("Location not set"))
        return
    end
    local data, err = api.fetch(self.lat, self.lon, self.temp_unit, self.forecast_days)
    if not data then
        self:displayError(err or _("Could not fetch weather data"))
        return
    end
    self:displayWeather(data)
end

function WeatherView:displayError(msg)
    self:buildLayout()
    local sw = Screen:getWidth()
    table.insert(self.cards, CenterContainer:new {
        dimen = Geom:new { w = sw, h = Screen:getHeight() / 2 },
        TextBoxWidget:new {
            text = msg, face = Font:getFace("infofont", 22),
            width = sw - 2 * self.pad,
        },
    })
    UIManager:setDirty(self, function()
        return "ui", self.dimen
    end)
end

function WeatherView:onSearchLocation()
    local dialog
    dialog = InputDialog:new {
        title = _("Search location"),
        input = "",
        input_hint = _("City name"),
        buttons = { {
            {
                text = _("Cancel"),
                id = "close",
                callback = function()
                    UIManager:close(dialog)
                end,
            },
            {
                text = _("Search"),
                is_enter_default = true,
                callback = function()
                    local query = dialog:getInputText()
                    if query == "" then
                        UIManager:show(InfoMessage:new { text = _("Please enter a city name") })
                        return
                    end
                    UIManager:close(dialog)
                    local Trapper = require("ui/trapper")
                    Trapper:wrap(function()
                        local ok, http = pcall(require, "socket.http")
                        if not ok then
                            Trapper:info(_("No network"))
                            return
                        end
                        if not Trapper:info(_("Searching...")) then return end
                        local function urlencode(s)
                            return s:gsub("([^%w%.%-])", function(c)
                                return string.format("%%%02X", string.byte(c))
                            end)
                        end
                        local url = string.format(
                            "https://geocoding-api.open-meteo.com/v1/search?name=%s&count=15&language=en&format=json",
                            urlencode(query))
                        http.TIMEOUT = 15
                        local body, code = http.request(url)
                        if code ~= 200 or not body then
                            Trapper:info(_("Search failed") .. " (" .. tostring(code or "?") .. ")")
                            return
                        end
                        if #body == 0 then
                            Trapper:info(_("Empty response"))
                            return
                        end
                        local ok_json, JSON = pcall(require, "json")
                        if not ok_json then
                            Trapper:info(_("Parse error"))
                            return
                        end
                        local ok_decode, data = pcall(JSON.decode, body)
                        if not ok_decode or type(data) ~= "table" then
                            Trapper:info(_("Parse error") .. " (" .. tostring(body):sub(1, 80) .. ")")
                            return
                        end
                        if not data.results or #data.results == 0 then
                            Trapper:info(_("City not found"))
                            return
                        end
                        if #data.results == 1 then
                            local function pickResult(r)
                                local lat = tonumber(r.latitude)
                                local lon = tonumber(r.longitude)
                                if not lat or not lon then
                                    Trapper:info(_("Invalid coordinates"))
                                    return
                                end
                                local parts = {}
                                if r.name then table.insert(parts, r.name) end
                                if r.admin1 then table.insert(parts, r.admin1) end
                                if r.country then table.insert(parts, r.country) end
                                local loc_name = #parts > 0 and table.concat(parts, ", ") or query
                                config.set("weather_latitude", lat)
                                config.set("weather_longitude", lon)
                                config.set("weather_location_name", loc_name)
                                self.lat = lat
                                self.lon = lon
                                self.location_name = loc_name
                                Trapper:info(string.format(_("Location set to %s"), loc_name))
                                self:fetchWeather()
                            end
                            pickResult(data.results[1])
                        else
                            Trapper:clear()
                            local dialog_sel
                            local buttons = {}
                            for i, r in ipairs(data.results) do
                                local parts = {}
                                if r.name then table.insert(parts, r.name) end
                                if r.admin1 then table.insert(parts, r.admin1) end
                                if r.country then table.insert(parts, r.country) end
                                local label = table.concat(parts, ", ")
                                table.insert(buttons, {{
                                    text = label,
                                    callback = function()
                                        local lat = tonumber(r.latitude)
                                        local lon = tonumber(r.longitude)
                                        if lat and lon then
                                            config.set("weather_latitude", lat)
                                            config.set("weather_longitude", lon)
                                            config.set("weather_location_name", label)
                                            self.lat = lat
                                            self.lon = lon
                                            self.location_name = label
                                            UIManager:close(dialog_sel)
                                            self:fetchWeather()
                                        end
                                    end,
                                }})
                                if i >= 20 then break end
                            end
                            table.insert(buttons, {{
                                text = _("Cancel"),
                                callback = function()
                                    UIManager:close(dialog_sel)
                                end,
                            }})
                            dialog_sel = ButtonDialog:new {
                                title = string.format(_("Locations for \"%s\""), query),
                                buttons = buttons,
                            }
                            UIManager:show(dialog_sel)
                        end
                    end)
                end,
            },
        } },
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

function WeatherView:onSwipe(_, ges_ev)
    if ges_ev.direction == "south" then
        self:onClose()
        return true
    elseif ges_ev.direction == "north" then
        self:fetchWeather()
        return true
    end
    return false
end

function WeatherView:onClose()
    UIManager:close(self)
    UIManager:setDirty(nil, "full")
    if self.close_callback then
        self.close_callback()
    end
    return true
end

return WeatherView
