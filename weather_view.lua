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
local IconButton = require("ui/widget/iconbutton")
local InfoMessage = require("ui/widget/infomessage")
local Input = Device.input
local InputDialog = require("ui/widget/inputdialog")
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

local gap = Screen:scaleBySize(8)

local WeatherView = FocusManager:extend {
    name = "weatherview",
    lat = nil, lon = nil,
    temp_unit = "celsius",
    forecast_days = 7,
    location_name = nil,
    close_callback = nil,
    force_refresh = false,
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
    self:buildLayout()
    local cached = api.cacheLoad()
    if cached and not self.force_refresh then
        self:displayWeather(cached, true)
    else
        self:showLoading()
        UIManager:setDirty(self, function()
            return "ui", self.dimen
        end)
        self:fetchWeather()
    end
end

function WeatherView:onRefresh()
    local Trapper = require("ui/trapper")
    Trapper:wrap(function()
        if not Trapper:info(_("Refreshing...")) then return end
        self:fetchWeather()
        Trapper:clear()
    end)
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
        close_callback = function() self:onClose() end, show_parent = self,
    }

    local icon_sz = Screen:scaleBySize(24)
    local btn_pad = Screen:scaleBySize(11)

    -- Build search + save button group
    local search_btn = IconButton:new {
        icon = "appbar.search",
        width = icon_sz, height = icon_sz,
        padding = btn_pad, padding_bottom = icon_sz,
        callback = function() self:onSearchLocation() end,
        show_parent = self,
    }
    self.save_btn = IconButton:new {
        icon = "bookmark",
        width = icon_sz, height = icon_sz,
        padding = btn_pad, padding_bottom = icon_sz,
        enabled = false,
        callback = function()
            if not self.save_btn.enabled then return end
            local lat = self.lat
            local lon = self.lon
            if not lat or not lon then
                UIManager:show(InfoMessage:new { text = _("Location not set") })
                return
            end
            config.set("weather_latitude", lat)
            config.set("weather_longitude", lon)
            config.set("weather_location_name", self.location_name)
            UIManager:show(InfoMessage:new {
                text = string.format(_("Location saved: %.4f, %.4f"), lat, lon),
            })
            self.save_pending = false
            self.save_btn.enabled = false
            self.save_btn.image.dim = true
            UIManager:setDirty(self, "ui", self.dimen)
        end,
        show_parent = self,
    }
    self.save_btn.image.dim = true
    if self.save_pending then
        self.save_btn.enabled = true
        self.save_btn.image.dim = false
    end
    local refresh_btn = IconButton:new {
        icon = "cre.render.reload",
        width = icon_sz, height = icon_sz,
        padding = btn_pad, padding_bottom = icon_sz,
        callback = function() self:onRefresh() end,
        show_parent = self,
    }
    local left_group = HorizontalGroup:new {
        overlap_align = "left",
        search_btn, self.save_btn, refresh_btn,
    }
    table.insert(self.title_bar, 1, left_group)
    -- Push title right to clear all buttons
    if self.title_bar.inner_title_group then
        local hspan = self.title_bar.inner_title_group[1]
        if hspan then
            local btn_w = icon_sz + 2 * btn_pad
            hspan.width = hspan.width + 3 * btn_w
            self.title_bar.inner_title_group._size = nil
            self.title_bar.title_group._size = nil
            self.title_bar._size = nil
            -- Force recompute then clamp to full width
            self.title_bar:getSize()
            self.title_bar._size.w = math.max(self.title_bar._size.w, self.title_bar.width)
        end
    end
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
    local wind_unit = config.get("weather_wind_unit", "kmh")
    local precip_unit = config.get("weather_precip_unit", "mm")
    local data, err = api.fetch(self.lat, self.lon, self.temp_unit, self.forecast_days, wind_unit, precip_unit)
    if data then
        api.cacheSave(data)
        self:displayWeather(data, false)
        require("weather_statusline").updateCache(data, self.temp_unit)
    else
        local cached = api.cacheLoad()
        if cached then
            self:displayWeather(cached, true)
            require("weather_statusline").updateCache(cached, self.temp_unit)
        else
            self:displayError(err or _("Could not fetch weather data"))
        end
    end
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
                                self.lat = lat
                                self.lon = lon
                                self.location_name = loc_name
                                Trapper:info(string.format(_("Location set to %s"), loc_name))
                                self:enableSaveButton()
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
                                            self.lat = lat
                                            self.lon = lon
                                            self.location_name = label
                                            UIManager:close(dialog_sel)
                                            self:enableSaveButton()
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

function WeatherView:enableSaveButton()
    self.save_pending = true
    if not self.save_btn then return end
    self.save_btn.enabled = true
    self.save_btn.image.dim = false
    if self.dimen then
        UIManager:setDirty(self, "ui", self.dimen)
    end
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
