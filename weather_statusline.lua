local ButtonDialog = require("ui/widget/buttondialog")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")
local UIManager = require("ui/uimanager")
local Event = require("ui/event")
local _ = require("weather_i18n")
local config = require("weather_config")
local api = require("weather_api")

local plugin_dir = (debug.getinfo(1, "S").source or ""):match("@(.*/)") or ""

local cache_data = nil
local cache_temp_unit = "celsius"

local ALL_FIELDS = {
    { key = "icon",          name = _("Icon"),           def_short = true,  def_long = true },
    { key = "temperature",   name = _("Temperature"),    def_short = true,  def_long = true },
    { key = "condition",     name = _("Condition"),      def_short = false, def_long = true },
    { key = "feels_like",    name = _("Feels Like"),     def_short = false, def_long = true },
    { key = "high_low",      name = _("High/Low"),       def_short = true,  def_long = true },
    { key = "humidity",      name = _("Humidity"),       def_short = false, def_long = true },
    { key = "wind",          name = _("Wind"),           def_short = false, def_long = true },
    { key = "uv_index",      name = _("UV Index"),       def_short = false, def_long = true },
    { key = "pressure",      name = _("Pressure"),       def_short = false, def_long = true },
    { key = "precip_chance", name = _("Precipitation"),  def_short = false, def_long = true },
    { key = "location",      name = _("Location"),       def_short = false, def_long = true },
    { key = "sunrise_set",   name = _("Sunrise/Sunset"), def_short = false, def_long = true },
    { key = "dew_point",     name = _("Dew Point"),      def_short = false, def_long = true },
}

local function tempSuffix()
    return cache_temp_unit == "fahrenheit" and "°F" or "°C"
end

local function updateCache(data, temp_unit)
    cache_data = data
    cache_temp_unit = temp_unit or config.get("weather_temp_unit", "celsius")
    if data and data.current then
        config.set("weather_statusline_cache", {
            current = data.current,
            daily = data.daily,
            temp_unit = cache_temp_unit,
        })
    end
end

local saved = config.get("weather_statusline_cache")
if saved and saved.current then
    cache_data = saved
    cache_temp_unit = saved.temp_unit or "celsius"
end

local function readOrder(name)
    local raw = config.get("weather_statusline_" .. name .. "_order")
    if raw and type(raw) == "table" and #raw > 0 then return raw end
    return nil
end

local function saveOrder(name, order)
    config.set("weather_statusline_" .. name .. "_order", order)
end

local function readToggles(name)
    local raw = config.get("weather_statusline_" .. name .. "_fields")
    if raw and type(raw) == "table" then return raw end
    return nil
end

local function saveToggles(name, toggles)
    config.set("weather_statusline_" .. name .. "_fields", toggles)
end

local function getOrder(name)
    local order = readOrder(name)
    if order then return order end
    order = {}
    for _, f in ipairs(ALL_FIELDS) do table.insert(order, f.key) end
    return order
end

local function getToggles(name)
    local toggles = readToggles(name)
    if toggles then return toggles end
    toggles = {}
    for _, f in ipairs(ALL_FIELDS) do toggles[f.key] = f["def_" .. name] end
    return toggles
end

local function countEnabled(toggles)
    local n = 0
    for _, v in pairs(toggles) do if v then n = n + 1 end end
    return n
end

local function getSeparator()
    local sep = config.get("weather_statusline_separator")
    if sep and type(sep) == "string" and sep ~= "" then return sep end
    return " · "
end

local ICON_SYMBOLS = {
    clear_day = "\u{2600}",
    clear_night = "\u{263D}",
    mostly_sunny = "\u{26C5}",
    mostly_clear_night = "\u{263D}",
    partly_cloudy_day = "\u{26C5}",
    partly_cloudy_night = "\u{263D}",
    cloudy = "\u{2601}",
    haze_fog_dust_smoke = "\u{2601}",
    drizzle = "\u{2602}",
    rain_with_cloudy = "\u{2602}",
    showers_rain = "\u{2602}",
    heavy_rain = "\u{2602}",
    cloudy_with_rain = "\u{2602}",
    mixed_rain_snow = "\u{2744}",
    icy = "\u{2744}",
    cloudy_with_snow = "\u{2744}",
    snow_with_cloudy = "\u{2744}",
    blizzard = "\u{2744}",
    flurries = "\u{2744}",
    scattered_showers_day = "\u{26C5}\u{2602}",
    scattered_showers_night = "\u{263D}\u{2602}",
    showers_snow = "\u{2744}",
    scattered_snow_showers_day = "\u{26C5}\u{2744}",
    scattered_snow_showers_night = "\u{263D}\u{2744}",
    isolated_thunderstorms = "\u{26C8}",
    isolated_scattered_thunderstorms_night = "\u{26C8}",
    sleet_hail = "\u{2744}",
    strong_thunderstorms = "\u{26C8}",
    very_hot = "\u{2600}",
    very_cold = "\u{2744}",
}

local function windLabel()
    return api.windUnitLabel()
end

local function pressureDisplay(hpa)
    return api.pressureDisplay(hpa)
end

local function compute()
    if not cache_data then return {} end
    local cur = cache_data.current
    local today = cache_data.daily and cache_data.daily[1]
    if not cur then return {} end

    local ts = tempSuffix()
    local fields = {}

    local icon = cur.weather_icon
    fields.icon = icon and (ICON_SYMBOLS[icon] or "\u{2753}")

    fields.temperature = cur.temperature and string.format("%.0f%s", cur.temperature, ts)
    fields.condition = cur.weather_text
    fields.feels_like = cur.apparent_temperature
        and string.format("%.0f%s", cur.apparent_temperature, ts)
    if today then
        local high = today.temp_max and string.format("%.0f", today.temp_max)
        local low = today.temp_min and string.format("%.0f", today.temp_min)
        if high and low then
            fields.high_low = string.format("↑%s%s ↓%s%s", high, ts, low, ts)
        elseif high then
            fields.high_low = string.format("↑%s%s", high, ts)
        end
    end
    fields.humidity = cur.humidity and string.format("%d%%", cur.humidity)
    if cur.wind_speed then
        local dir = cur.wind_label or ""
        fields.wind = string.format("%.0f %s %s", cur.wind_speed, windLabel(), dir)
    end
    fields.uv_index = today and today.uv_index and string.format("UV %g", today.uv_index)
    fields.pressure = pressureDisplay(cur.pressure)
    fields.precip_chance = today and today.precip_prob
        and string.format("%d%%", today.precip_prob)
    fields.location = config.get("weather_location_name")
    if today and today.sunrise then
        local rise = today.sunrise:match("%d%d:%d%d")
        local set = today.sunset and today.sunset:match("%d%d:%d%d")
        if rise and set then
            fields.sunrise_set = string.format("↑%s ↓%s", rise, set)
        end
    end
    fields.dew_point = cur.dew_point and string.format("%.0f%s", cur.dew_point, ts)

    return fields
end

local function buildText(name)
    local order = getOrder(name)
    local toggles = getToggles(name)
    local sep = getSeparator()
    local field_values = compute()
    local parts = {}
    for _, key in ipairs(order) do
        if toggles[key] and field_values[key] and field_values[key] ~= "" then
            table.insert(parts, field_values[key])
        end
    end
    return table.concat(parts, sep)
end

local function getShort()
    return buildText("short")
end

local function getLong()
    return buildText("long")
end

local _dialog_ref = nil
local showFieldSettings, showPreview

local function showSettings()
    local function buildDialog()
        local buttons = {}

        table.insert(buttons, { {
            text = _("Separator") .. ': "' .. getSeparator() .. '"',
            callback = function()
                local cur_sep = getSeparator()
                local dlg
                dlg = InputDialog:new {
                    title = _("Status Line Separator"),
                    input = cur_sep,
                    input_hint = " · ",
                    buttons = { {
                        {
                            text = _("Save"),
                            callback = function()
                                config.set("weather_statusline_separator", dlg:getInputText())
                                UIManager:close(dlg)
                                UIManager:close(_dialog_ref)
                                showSettings()
                            end,
                        },
                        {
                            text = _("Cancel"),
                            callback = function() UIManager:close(dlg) end,
                        },
                    } },
                }
                UIManager:show(dlg)
            end,
        } })

        local short_count = countEnabled(getToggles("short"))
        local long_count = countEnabled(getToggles("long"))
        table.insert(buttons, { {
            text = _("Short Fields") .. " (" .. short_count .. "/" .. #ALL_FIELDS .. ")",
            callback = function()
                UIManager:close(_dialog_ref)
                showFieldSettings("short")
            end,
        } })
        table.insert(buttons, { {
            text = _("Long Fields") .. " (" .. long_count .. "/" .. #ALL_FIELDS .. ")",
            callback = function()
                UIManager:close(_dialog_ref)
                showFieldSettings("long")
            end,
        } })

        table.insert(buttons, { {
            text = _("Units") .. " · " .. api.windUnitLabel() .. " / " .. config.get("weather_pressure_unit", "hPa") .. " / " .. config.get("weather_precip_unit", "mm"),
            callback = function()
                UIManager:close(_dialog_ref)
                showUnitsDialog()
            end,
        } })

        table.insert(buttons, { {
            text = _("Reset to Defaults"),
            callback = function()
                config.delete("weather_statusline_short_order")
                config.delete("weather_statusline_long_order")
                config.delete("weather_statusline_short_fields")
                config.delete("weather_statusline_long_fields")
                config.delete("weather_statusline_separator")
                UIManager:close(_dialog_ref)
                showSettings()
            end,
        } })

        table.insert(buttons, { {
            text = _("Preview"),
            keep_menu_open = true,
            callback = function() showPreview() end,
        } })

        table.insert(buttons, { {
            text = _("Close"),
            callback = function() UIManager:close(_dialog_ref) end,
        } })

        _dialog_ref = ButtonDialog:new {
            title = _("Weather Status Line Settings"),
            buttons = buttons,
        }
        UIManager:show(_dialog_ref)
    end
    buildDialog()
end

showFieldSettings = function(name)
    local order = getOrder(name)
    local toggles = getToggles(name)
    local name_upper = name == "short" and _("Short") or _("Long")

    local function buildFieldDialog()
        local buttons = {}
        for i, key in ipairs(order) do
            local field
            for _, f in ipairs(ALL_FIELDS) do
                if f.key == key then
                    field = f; break
                end
            end
            if not field then goto continue end
            local checked = toggles[key]
            local row = {
                {
                    text = (checked and "☑" or "☐") .. " " .. field.name,
                    callback = function()
                        toggles[key] = not toggles[key]
                        saveToggles(name, toggles)
                        UIManager:close(_dialog_ref)
                        showFieldSettings(name)
                    end,
                },
                {
                    text = "▲",
                    callback = function()
                        if i > 1 then
                            order[i], order[i - 1] = order[i - 1], order[i]
                            saveOrder(name, order)
                            UIManager:close(_dialog_ref)
                            showFieldSettings(name)
                        end
                    end,
                },
                {
                    text = "▼",
                    callback = function()
                        if i < #order then
                            order[i], order[i + 1] = order[i + 1], order[i]
                            saveOrder(name, order)
                            UIManager:close(_dialog_ref)
                            showFieldSettings(name)
                        end
                    end,
                },
            }
            table.insert(buttons, row)
            ::continue::
        end
        table.insert(buttons, { {
            text = _("Back"),
            callback = function()
                UIManager:close(_dialog_ref)
                showSettings()
            end,
        } })
        _dialog_ref = ButtonDialog:new {
            title = name_upper .. " " .. _("Fields"),
            buttons = buttons,
        }
        UIManager:show(_dialog_ref)
    end
    buildFieldDialog()
end

local function showUnitsDialog()
    local WIND_OPTS = { kmh = "km/h", ms = "m/s", mph = "mph", knots = "knots" }
    local PRESSURE_OPTS = { hPa = "hPa", inHg = "inHg", mmHg = "mmHg" }
    local PRECIP_OPTS = { mm = "mm", inch = _("inch") }

    local function radioGroup(opts, cur_key, on_select)
        local rows = {}
        for k, label in pairs(opts) do
            table.insert(rows, {
                text = (cur_key == k and "● " or "  ") .. label,
                callback = function()
                    on_select(k)
                end,
            })
        end
        return rows
    end

    local function saveAndBack(unit_type, value)
        config.set("weather_" .. unit_type .. "_unit", value)
        UIManager:close(_dialog_ref)
        showUnitsDialog()
    end

    local cur_wind = config.get("weather_wind_unit", "kmh")
    local cur_pressure = config.get("weather_pressure_unit", "hPa")
    local cur_precip = config.get("weather_precip_unit", "mm")

    local buttons = {}
    table.insert(buttons, { { text = _("Wind"), callback = function() end } })
    for k, label in pairs(WIND_OPTS) do
        table.insert(buttons, { {
            text = (cur_wind == k and "● " or "  ") .. label,
            callback = function()
                saveAndBack("wind", k)
            end,
        } })
    end
    table.insert(buttons, { { text = _("Pressure"), callback = function() end } })
    for k, label in pairs(PRESSURE_OPTS) do
        table.insert(buttons, { {
            text = (cur_pressure == k and "● " or "  ") .. label,
            callback = function()
                saveAndBack("pressure", k)
            end,
        } })
    end
    table.insert(buttons, { { text = _("Precipitation"), callback = function() end } })
    for k, label in pairs(PRECIP_OPTS) do
        table.insert(buttons, { {
            text = (cur_precip == k and "● " or "  ") .. label,
            callback = function()
                saveAndBack("precip", k)
            end,
        } })
    end
    table.insert(buttons, { {
        text = _("Back"),
        callback = function()
            UIManager:close(_dialog_ref)
            showSettings()
        end,
    } })

    _dialog_ref = ButtonDialog:new {
        title = _("Units"),
        buttons = buttons,
    }
    UIManager:show(_dialog_ref)
end

showPreview = function()
    if not cache_data then
        local lat = config.get("weather_latitude")
        local lon = config.get("weather_longitude")
        if not lat or not lon then
            UIManager:show(InfoMessage:new {
                text = _("No location set. Please set location first in Weather settings."),
            })
            return
        end
        local msg = InfoMessage:new { text = _("Loading...") }
        UIManager:show(msg)
        local temp_unit = config.get("weather_temp_unit", "celsius")
        local forecast_days = config.get("weather_forecast_days", 7)
        local wind_unit = config.get("weather_wind_unit", "kmh")
        local precip_unit = config.get("weather_precip_unit", "mm")
        local data, err = api.fetch(tonumber(lat), tonumber(lon), temp_unit, forecast_days, wind_unit, precip_unit)
        UIManager:close(msg)
        if not data then
            UIManager:show(InfoMessage:new {
                text = _("Could not fetch weather data") .. "\n\n" .. (err or "?"),
            })
            return
        end
        updateCache(data, temp_unit)
    end
    local short_str = getShort()
    local long_str = getLong()
    local text = _("Preview") .. "\n\n"
        .. _("Short") .. ":\n" .. short_str .. "\n\n"
        .. _("Long") .. ":\n" .. long_str
    UIManager:show(InfoMessage:new { text = text })
end

local FIELD_ICONS = {
    temperature = "mostly_sunny",
    feels_like = "mostly_clear_day",
    high_low = "mostly_clear_day",
    humidity = "drizzle",
    wind = "windy",
    uv_index = "sunny",
    pressure = "cloudy",
    precip_chance = "rain_with_cloudy",
    sunrise_set = "clear_day",
    dew_point = "icy",
}

local LABEL_ICONS = {
    icon = "\u{2600}",
    temperature = "\u{26C5}",
    condition = "",
    feels_like = "\u{26C5}",
    high_low = "\u{26C5}",
    humidity = "\u{2602}",
    wind = "\u{2601}",
    uv_index = "\u{2600}",
    pressure = "\u{2601}",
    precip_chance = "\u{2602}",
    location = "",
    sunrise_set = "\u{2600}",
    dew_point = "\u{2744}",
}

local function svg_path(name)
    return plugin_dir .. "resources/google-weather/set-4/" .. name .. ".svg"
end

local function tap_cb()
    UIManager:broadcastEvent(Event:new("WeatherOpen"))
end

local function registerZenUI()
    ---@diagnostic disable-next-line: undefined-field
    if not _G.__ZEN_UI_REGISTER_STATUS_ITEM then return end

    for __, field in ipairs(ALL_FIELDS) do
        local key = field.key
        local icon_prefix = LABEL_ICONS[key]
        local label = icon_prefix and icon_prefix ~= "" and icon_prefix .. " " .. field.name or field.name

        _G.__ZEN_UI_REGISTER_STATUS_ITEM("weather_" .. key, function()
            local vals = compute()
            local val = vals[key]
            if not val or val == "" then return nil end
            if key == "icon" then
                local icon_name = cache_data and cache_data.current and cache_data.current.weather_icon
                if icon_name then
                    return svg_path(icon_name), "", nil, true
                end
                return nil
            end
            local icon_name = FIELD_ICONS[key]
            if icon_name then
                return svg_path(icon_name), val, nil, true
            end
            return "", val, nil
        end, { label = label, side = "right", callback = tap_cb })
    end

    _G.__ZEN_UI_REGISTER_STATUS_ITEM("weather_status_short", function()
        local val = getShort()
        if not val or val == "" then return nil end
        return "", val, nil
    end, { label = _("Status (Short)"), side = "right", callback = tap_cb })

    _G.__ZEN_UI_REGISTER_STATUS_ITEM("weather_status_long", function()
        local val = getLong()
        if not val or val == "" then return nil end
        return "", val, nil
    end, { label = _("Status (Long)"), side = "right", callback = tap_cb })
end

return {
    getShort = getShort,
    getLong = getLong,
    showSettings = showSettings,
    updateCache = updateCache,
    compute = compute,
    ALL_FIELDS = ALL_FIELDS,
    registerZenUI = registerZenUI,
}
