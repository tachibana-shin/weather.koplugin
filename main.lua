local ButtonDialog = require("ui/widget/buttondialog")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")
local Trapper = require("ui/trapper")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("weather_i18n")
local config = require("weather_config")
local Dispatcher = require("dispatcher")

local Weather = WidgetContainer:extend {
    name = "weather",
    is_doc_only = false,
}

function Weather:init()
    self.ui.menu:registerToMainMenu(self)

    Dispatcher:registerAction("weather_open", {
        category = "none",
        event = "WeatherOpen",
        title = _("Open Weather"),
        general = true,
    })
end

local broadcastEventOrigin = UIManager.broadcastEvent
function UIManager:broadcastEvent(event, ...)
    broadcastEventOrigin(self, event, ...)
    if Weather[event.handler] then
        Weather[event.handler](Weather)
    end
    if event.handler == "onZenUIReady" then
        UIManager.broadcastEvent = broadcastEventOrigin
    end
end

function Weather:onZenUIReady()
    if not _G.__ZEN_UI_REGISTER_STATUS_ITEM then return end
    require("weather_statusline").registerZenUI()
end

function Weather:onWeatherOpen()
    self:openWeatherView()
end

function Weather:getCoords()
    local lat = config.get("weather_latitude")
    local lon = config.get("weather_longitude")
    if lat ~= nil and lon ~= nil then
        return tonumber(lat), tonumber(lon)
    end
    return nil, nil
end

function Weather:getTempUnit()
    return config.get("weather_temp_unit", "celsius")
end

function Weather:getForecastDays()
    return config.get("weather_forecast_days", 7)
end

function Weather:getLocationName()
    return config.get("weather_location_name")
end

function Weather:openWeatherView()
    local lat, lon = self:getCoords()
    if not lat or not lon then
        UIManager:show(InfoMessage:new {
            text = _("Please set your location first in Weather settings."),
        })
        return
    end
    local WeatherView = require("weather_view")
    UIManager:show(WeatherView:new {
        lat = lat,
        lon = lon,
        temp_unit = self:getTempUnit(),
        forecast_days = self:getForecastDays(),
        location_name = self:getLocationName(),
    })
end

function Weather:showLocationSettings()
    local cur_lat, cur_lon = self:getCoords()
    local default_text = cur_lat and cur_lon
        and string.format("%.4f, %.4f", cur_lat, cur_lon)
        or ""
    local dialog
    dialog = InputDialog:new {
        title = _("Set Location"),
        input = default_text,
        input_hint = _("Enter coordinates (lat, lon)"),
        buttons = {
            { {
                text = _("Save"),
                callback = function()
                    local text = dialog:getInputText()
                    local lat_str, lon_str = text:match("^%s*([+-]?[%d.]+)%s*[,;]%s*([+-]?[%d.]+)%s*$")
                    if lat_str and lon_str then
                        local lat = tonumber(lat_str)
                        local lon = tonumber(lon_str)
                        if lat and lon and lat >= -90 and lat <= 90 and lon >= -180 and lon <= 180 then
                            config.set("weather_latitude", lat)
                            config.set("weather_longitude", lon)
                            -- Detect location name via reverse lookup (optional)
                            self:detectLocationName(lat, lon)
                            UIManager:close(dialog)
                            UIManager:show(InfoMessage:new {
                                text = string.format(_("Location saved: %.4f, %.4f"), lat, lon),
                            })
                            return
                        end
                    end
                    UIManager:show(InfoMessage:new {
                        text = _("Invalid coordinates"),
                    })
                end,
            } },
            { {
                text = _("Auto Detect"),
                callback = function()
                    local msg = InfoMessage:new { text = _("Loading...") }
                    UIManager:show(msg)
                    local lat, lon, region, country
                    local err
                    local ok, http = pcall(require, "socket.http")
                    if not ok then
                        err = "no socket.http"
                    else
                        local body, code = http.request("http://ip-api.com/json/")
                        if code == 200 and body then
                            if not body:match('"status"%s*:%s*"success"') then
                                err = "api status not success"
                            else
                                local lat_s = body:match('"lat"%s*:%s*([%d.-]+)')
                                local lon_s = body:match('"lon"%s*:%s*([%d.-]+)')
                                if lat_s and lon_s then
                                    lat = tonumber(lat_s)
                                    lon = tonumber(lon_s)
                                    region = body:match('"regionName"%s*:%s*"([^"]*)"')
                                    country = body:match('"country"%s*:%s*"([^"]*)"')
                                else
                                    err = "no lat/lon in response"
                                end
                            end
                        else
                            err = "HTTP " .. tostring(code or "?") .. " " .. tostring((body or ""):sub(1, 200))
                        end
                    end
                    UIManager:close(msg)
                    if lat and lon then
                        local loc_str = string.format("%.4f, %.4f", lat, lon)
                        local location_name
                        if region and country then
                            location_name = region .. ", " .. country
                            loc_str = loc_str .. "\n" .. location_name
                        end
                        local confirm
                        confirm = ButtonDialog:new {
                            title = _("Confirm Location") .. "\n\n" .. loc_str,
                            buttons = { {
                                {
                                    text = _("Save"),
                                    callback = function()
                                        config.set("weather_latitude", lat)
                                        config.set("weather_longitude", lon)
                                        if location_name then
                                            config.set("weather_location_name", location_name)
                                        end
                                        UIManager:close(confirm)
                                        UIManager:close(dialog)
                                        UIManager:show(InfoMessage:new {
                                            text = string.format(_("Location saved: %.4f, %.4f"), lat, lon),
                                        })
                                    end,
                                },
                                {
                                    text = _("Cancel"),
                                    callback = function()
                                        UIManager:close(confirm)
                                    end,
                                },
                            } },
                        }
                        UIManager:show(confirm)
                    else
                        UIManager:show(InfoMessage:new {
                            text = _("Could not fetch weather data")
                                .. "\n\n" .. (err or "?"),
                        })
                    end
                end,
            } },
            { {
                text = _("Cancel"),
                callback = function()
                    UIManager:close(dialog)
                end,
            } },
        },
    }
    UIManager:show(dialog)
end

function Weather:detectLocationName(lat, lon)
    local ok, http = pcall(require, "socket.http")
    if not ok then return end
    local url = string.format(
        "https://geocoding-api.open-meteo.com/v1/search?name=%s,%s&count=1&language=en&format=json",
        tostring(lat), tostring(lon))
    local body, code = http.request(url)
    if code == 200 and body then
        local ok_json, JSON = pcall(require, "json")
        if ok_json then
            local ok_decode, data = pcall(JSON.decode, body)
            if ok_decode and data and data.results and #data.results > 0 then
                local result = data.results[1]
                local parts = {}
                if result.admin1 then table.insert(parts, result.admin1) end
                if result.country then table.insert(parts, result.country) end
                if #parts > 0 then
                    config.set("weather_location_name", table.concat(parts, ", "))
                end
            end
        end
    end
end

function Weather:showSettings()
    local dialog
    dialog = ButtonDialog:new {
        title = _("Weather Settings"),
        buttons = { {
            {
                text = _("Temperature Unit"),
                callback = function()
                    UIManager:close(dialog)
                    self:showTempUnitSettings()
                end,
            },
            {
                text = _("Forecast Days"),
                callback = function()
                    UIManager:close(dialog)
                    self:showForecastDaysSettings()
                end,
            },
            {
                text = _("Auto Refresh"),
                callback = function()
                    UIManager:close(dialog)
                    self:showAutoRefreshSettings()
                end,
            },
        }, {
            {
                text = _("Provider"),
                callback = function()
                    UIManager:close(dialog)
                    self:showProviderSettings()
                end,
            },
        }, {
            {
                text = _("Close"),
                callback = function()
                    UIManager:close(dialog)
                end,
            },
        } },
    }
    UIManager:show(dialog)
end

function Weather:showTempUnitSettings()
    local cur = self:getTempUnit()
    local dialog
    dialog = ButtonDialog:new {
        title = _("Temperature Unit"),
        buttons = {
            { {
                text = (cur == "celsius" and "● " or "  ") .. "°C",
                callback = function()
                    config.set("weather_temp_unit", "celsius")
                    UIManager:close(dialog)
                    UIManager:show(InfoMessage:new { text = "°C" })
                end,
            } },
            { {
                text = (cur == "fahrenheit" and "● " or "  ") .. "°F",
                callback = function()
                    config.set("weather_temp_unit", "fahrenheit")
                    UIManager:close(dialog)
                    UIManager:show(InfoMessage:new { text = "°F" })
                end,
            } },
            { {
                text = _("Back"),
                is_enter_default = true,
                callback = function()
                    UIManager:close(dialog)
                end,
            } },
        },
    }
    UIManager:show(dialog)
end

function Weather:showForecastDaysSettings()
    local cur = self:getForecastDays()
    local dialog
    dialog = ButtonDialog:new {
        title = _("Forecast Days"),
        buttons = {
            { {
                text = (cur == 3 and "● " or "  ") .. _("3 days"),
                callback = function()
                    config.set("weather_forecast_days", 3)
                    UIManager:close(dialog)
                    UIManager:show(InfoMessage:new { text = _("3 days") })
                end,
            } },
            { {
                text = (cur == 7 and "● " or "  ") .. _("7 days"),
                callback = function()
                    config.set("weather_forecast_days", 7)
                    UIManager:close(dialog)
                    UIManager:show(InfoMessage:new { text = _("7 days") })
                end,
            } },
            { {
                text = (cur == 14 and "● " or "  ") .. _("14 days"),
                callback = function()
                    config.set("weather_forecast_days", 14)
                    UIManager:close(dialog)
                    UIManager:show(InfoMessage:new { text = _("14 days") })
                end,
            } },
            { {
                text = _("Back"),
                is_enter_default = true,
                callback = function()
                    UIManager:close(dialog)
                end,
            } },
        },
    }
    UIManager:show(dialog)
end

function Weather:showAutoRefreshSettings()
    local cur = config.get("weather_refresh_interval", 0)
    local intervals = {
        { val = 0, label = _("Off") },
        { val = 15, label = _("15 min") },
        { val = 30, label = _("30 min") },
        { val = 60, label = _("1 hour") },
        { val = 120, label = _("2 hours") },
        { val = 180, label = _("3 hours") },
    }
    local dialog
    local buttons = {}
    for __, m in ipairs(intervals) do
        table.insert(buttons, { {
            text = (cur == m.val and "● " or "  ") .. m.label,
            callback = function()
                config.set("weather_refresh_interval", m.val)
                UIManager:close(dialog)
                UIManager:show(InfoMessage:new { text = m.label })
            end,
        } })
    end
    table.insert(buttons, { {
        text = _("Back"),
        is_enter_default = true,
        callback = function()
            UIManager:close(dialog)
        end,
    } })
    dialog = ButtonDialog:new {
        title = _("Auto Refresh"),
        buttons = buttons,
    }
    UIManager:show(dialog)
end

function Weather:showProviderSettings()
    local cur = config.get("weather_provider", "openmeteo")
    local dialog
    dialog = ButtonDialog:new {
        title = _("Weather Provider"),
        buttons = {
            { {
                text = (cur == "openmeteo" and "● " or "  ") .. "Open-Meteo",
                callback = function()
                    config.set("weather_provider", "openmeteo")
                    UIManager:close(dialog)
                end,
            } },
            { {
                text = (cur == "weatherapi" and "● " or "  ") .. "WeatherAPI.com",
                callback = function()
                    UIManager:close(dialog)
                    local key = config.get("weather_weatherapi_key", "")
                    if key and key ~= "" then
                        self:validateAndSwitch(key)
                    else
                        self:promptWeatherApiKey()
                    end
                end,
            } },
            { {
                text = _("Back"),
                is_enter_default = true,
                callback = function()
                    UIManager:close(dialog)
                end,
            } },
        },
    }
    UIManager:show(dialog)
end

function Weather:validateAndSwitch(key)
    Trapper:wrap(function()
        if not Trapper:info(_("Validating...")) then return end
        local ok, http = pcall(require, "socket.http")
        if not ok then
            Trapper:clear()
            UIManager:show(InfoMessage:new {
                text = _("HTTP module not available"),
            })
            return
        end
        local url = "https://api.weatherapi.com/v1/current.json?key="
            .. key .. "&q=auto:ip"
        local body, code = http.request(url)
        Trapper:clear()
        if code == 200 then
            config.set("weather_weatherapi_key", key)
            config.set("weather_provider", "weatherapi")
            UIManager:show(InfoMessage:new {
                text = _("WeatherAPI.com key validated"),
            })
        else
            UIManager:show(InfoMessage:new {
                text = _("Invalid API key") .. " (" .. tostring(code) .. ")",
            })
        end
    end)
end

function Weather:promptWeatherApiKey()
    local input_dialog
    input_dialog = InputDialog:new {
        title = _("WeatherAPI.com API Key"),
        input = "",
        buttons = {
            { {
                text = _("Save"),
                callback = function()
                    local key = input_dialog:getInputText()
                    UIManager:close(input_dialog)
                    self:validateAndSwitch(key)
                end,
            } },
            { {
                text = _("Cancel"),
                callback = function()
                    UIManager:close(input_dialog)
                end,
            } },
        },
    }
    UIManager:show(input_dialog)
end

function Weather:addToMainMenu(menu_items)
    menu_items.weather = {
        text = "\u{2600} " .. _("Weather"),
        sorting_hint = "tools",
        sub_item_table = {
            {
                text = "\u{2600} " .. _("Open Weather"),
                callback = function() self:openWeatherView() end,
            },
            {
                text = "\u{F013} " .. _("Settings"),
                keep_menu_open = true,
                callback = function() self:showSettings() end,
            },
            {
                text = "\u{F041} " .. _("Set Location"),
                keep_menu_open = true,
                callback = function() self:showLocationSettings() end,
            },
            {
                text = _("Status Line"),
                keep_menu_open = true,
                callback = function()
                    require("weather_statusline").showSettings()
                end,
            },
            {
                text = "\u{F059} " .. _("About"),
                keep_menu_open = true,
                callback = function()
                    local meta = require("weather_info")
                    local text = meta.fullname .. "\n\n"
                        .. _("Version") .. ": " .. (meta.version or "?") .. "\n"
                        .. (meta.description or "") .. "\n\n"
                        .. _("License") .. ": " .. (meta.license or "?") .. "\n"
                        .. _("Author") .. ": " .. (meta.author or "?") .. "\n\n"
                        .. (meta.url or "")
                    UIManager:show(InfoMessage:new { text = text })
                end,
            },
        },
    }
end

return Weather
